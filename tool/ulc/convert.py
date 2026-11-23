#!/usr/bin/env python3
"""Reproducible converter: ULC question-bank PDFs -> assets/data/bank_<licence>.json.

Usage:
    python3 tool/ulc/convert.py --all
    python3 tool/ulc/convert.py --licence ppla [--licence spl ...]
    python3 tool/ulc/convert.py --eval-split      # hold-out accuracy of the PL/EN splitter

The PDFs are NOT stored in git: see tool/ulc/README.md and tool/ulc/sources.json.
The output is deterministic (no timestamps, sorted by id).
"""

import argparse
import hashlib
import html
import json
import math
import re
import sys
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent

SCHEMA = 2
LICENCES = ("ppla", "pplh", "spl", "bpl")

# Subject ids and quizLength (questions per exam). Mirrors lib/src/domain/catalog.dart
# (ExamSpec); the Dart test of step S5 cross-checks both tables.
QUIZ_LENGTH = {
    "air_law": 28,
    "communications": 12,
    "meteorology": 12,
    "navigation": 24,
    "performance_and_planning": 20,
    "aircraft_general_knowledge": 16,
    "human_performance": 12,
    "principles_of_flight": 16,
    "operational_procedures": 12,
}
SUBJECTS = tuple(QUIZ_LENGTH)

# Topic prefix (first part of NUMER) -> subject id. Mirrors catalog.topicPrefixToSubject.
TOPIC_TO_SUBJECT = {
    "PL010": "air_law",
    "PL099": "air_law",
    "PL100": "air_law",
    "PL102": "air_law",
    "PL020": "aircraft_general_knowledge",
    "PL021": "aircraft_general_knowledge",
    "PL024": "aircraft_general_knowledge",
    "PL025": "aircraft_general_knowledge",
    "PL030": "performance_and_planning",
    "PL040": "human_performance",
    "PL050": "meteorology",
    "PL060": "navigation",
    "PL070": "operational_procedures",
    "PL080": "principles_of_flight",
    "PL090": "communications",
}

NUMBER_RE = re.compile(r"^PL\d{3}-\d{4}$")
PDFPLUMBER_VERSION = "0.11.10"

# Legacy JSON files (pre-2024 data of the app), used only as a language lexicon for the
# PL/EN splitter and for the comparison section of the reports.
LEGACY_FILES = {
    "ppla": ("ppla-pl.json", "ppla-en.json"),
    "pplh": ("pplh-pl.json", "pplh-en.json"),
    "spl": ("plg-pl.json", None),
    "bpl": ("plfb-pl.json", None),
}


class ConvertError(Exception):
    pass


# --------------------------------------------------------------------------- text utils

_WS = re.compile(r"\s+")
_INVISIBLE = dict.fromkeys(map(ord, "​‌‍⁠﻿­"), None)


def clean_text(s):
    """Decode HTML entities, normalise unicode and whitespace."""
    if not isinstance(s, str):  # legacy data contains null / NaN cells
        return ""
    s = html.unescape(html.unescape(s))
    s = s.translate(_INVISIBLE).replace(" ", " ")
    s = unicodedata.normalize("NFC", s)
    return _WS.sub(" ", s).strip()


def join_lines(lines):
    """Join the wrapped lines of one PDF cell into a single string.

    ``lines`` keep the trailing space the PDF stores after a word-wrap. A line that does NOT end
    with a space was broken inside a word (or right after a hyphen) and is joined without one.
    """
    out = ""
    glue = ""
    for line in lines:
        text = line.strip()
        if not text:
            glue = " " if line else glue
            continue
        if out:
            sep = " " if (glue == " " or line[:1].isspace()) else ""
            out += sep
        out += text
        glue = " " if line[-1:].isspace() else ""
    return out


def normalize_number(raw):
    return re.sub(r"\s+", "", raw or "").upper()


def fold(s):
    """Aggressive normalisation for comparisons (not stored)."""
    s = unicodedata.normalize("NFKD", s.casefold())
    s = "".join(ch for ch in s if not unicodedata.combining(ch))
    return re.sub(r"[\W_]+", "", s)


def hash_text(pl_q, pl_answers):
    norm = [_WS.sub(" ", unicodedata.normalize("NFC", t)).strip().casefold() for t in ([pl_q] + pl_answers)]
    return hashlib.sha1("\n".join(norm).encode("utf-8")).hexdigest()[:6]


# --------------------------------------------------------------------------- sources


def load_sources(path=None):
    path = Path(path or HERE / "sources.json")
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def check_pdf(licence, spec, sources_dir):
    path = Path(sources_dir) / spec["file"]
    if not path.is_file():
        raise ConvertError(
            f"[{licence}] source PDF not found: {path}\n"
            f"  Download it manually (see tool/ulc/README.md, page: {spec.get('page_url', '?')}) "
            f"and put it into {sources_dir}. Expected SHA-256: {spec['sha256']}"
        )
    digest = sha256_file(path)
    if digest != spec["sha256"]:
        raise ConvertError(
            f"[{licence}] SHA-256 mismatch for {path}\n  expected {spec['sha256']}\n  actual   {digest}\n"
            "  The PDF is a different version. If this is intended, review the new file and update "
            "tool/ulc/sources.json."
        )
    return path


# --------------------------------------------------------------------------- PDF -> raw rows


def _cell_text(page, bbox, fallback):
    """Cell text with line breaks; every line keeps its trailing space (see join_lines)."""
    if bbox is None:
        return fallback
    # The trailing space of a wrapped line may stick out of the cell by ~2.5pt and would be cut off
    # by an exact crop; the neighbouring cell starts >5pt after the border, so +3.5pt is safe.
    x0, top, x1, bottom = bbox
    area = (x0, top, min(x1 + 3.5, float(page.width)), bottom)
    from pdfplumber.utils import cluster_objects

    chars = page.crop(area).chars
    lines = []
    for cluster in cluster_objects(chars, "doctop", 3):
        cluster = sorted(cluster, key=lambda ch: ch["x0"])
        lines.append("".join(ch["text"] for ch in cluster))
    text = "\n".join(lines)
    if re.sub(r"\s+", "", text) != re.sub(r"\s+", "", fallback):
        return fallback  # safety net: never trust own reconstruction over pdfplumber's
    return text


def extract_rows(pdf_path, sha, cache_dir):
    """Table rows of every page: [{"page": n, "cells": [7 str]}], with cell line breaks kept.

    Cached in cache_dir (keyed by the SHA-256 of the PDF, the pdfplumber version and the format).
    """
    cache = Path(cache_dir) / f"{sha}.pdfplumber-{PDFPLUMBER_VERSION}.v3.json"
    if cache.is_file():
        with open(cache, encoding="utf-8") as f:
            return json.load(f)
    try:
        import pdfplumber
    except ImportError as e:  # pragma: no cover
        raise ConvertError("pdfplumber is not installed: pip install -r tool/ulc/requirements.txt") from e
    rows = []
    with pdfplumber.open(str(pdf_path)) as pdf:
        for page_no, page in enumerate(pdf.pages, start=1):
            for table in page.find_tables():
                data = table.extract()
                for trow, r in zip(table.rows, data):
                    boxes = list(trow.cells)
                    cells = []
                    for i, c in enumerate(r):
                        c = c if c is not None else ""
                        box = boxes[i] if i < len(boxes) else None
                        cells.append(_cell_text(page, box, c))
                    rows.append({"page": page_no, "cells": cells})
    cache.parent.mkdir(parents=True, exist_ok=True)
    with open(cache, "w", encoding="utf-8") as f:
        json.dump(rows, f, ensure_ascii=False)
    return rows


# --------------------------------------------------------------------------- rows -> records


class Stats:
    def __init__(self):
        self.table_rows = 0
        self.header_rows = 0
        self.data_rows = 0
        self.merged_rows = 0
        self.discarded = []  # (page, number, reason)
        self.exact_duplicates = []  # (page, number)
        self.notes = []

    def discard(self, page, number, reason):
        self.discarded.append((page, number, reason))


def build_records(raw_rows, stats):
    """Group table rows into records; continuation rows (no L.p. and no NUMER) are merged.

    A record is {"page", "number_raw", "cells": [5 lists of lines]} (question + 4 answers).
    """
    records = []
    for row in raw_rows:
        stats.table_rows += 1
        cells = row["cells"]
        if len(cells) != 7:
            stats.data_rows += 1
            stats.discard(row["page"], "?", f"malformed table row ({len(cells)} columns instead of 7)")
            continue
        lp, number = cells[0].strip(), cells[1].strip()
        if lp == "L.p." and number == "NUMER":
            stats.header_rows += 1
            continue
        parts = [c.split("\n") for c in cells[2:7]]
        if not lp and not number:
            if not records:
                stats.data_rows += 1
                stats.discard(row["page"], "?", "continuation row without a preceding record")
                continue
            for dst, src in zip(records[-1]["cells"], parts):
                dst.extend(src)
            stats.merged_rows += 1
            continue
        stats.data_rows += 1
        records.append({"page": row["page"], "number_raw": number, "cells": parts})
    return records


# --------------------------------------------------------------------------- PL/EN splitter

_TOKEN_STRIP = ".,;:!?()[]{}\"'“”„«»‘’/\\*+=<>%"
_SENT_END = re.compile(r"[.?!:;…)\"”»]$")
_PL_CHARS = set("ąćęłńóśźżĄĆĘŁŃÓŚŹŻ")


def token_key(tok):
    t = tok.strip(_TOKEN_STRIP).casefold()
    return t if any(ch.isalpha() for ch in t) else ""


class Lexicon:
    """Word -> log-odds score (positive = Polish, negative = English) from legacy data."""

    def __init__(self, pl_counts, en_counts):
        self.scores = {}
        npl = sum(pl_counts.values()) or 1
        nen = sum(en_counts.values()) or 1
        for w in set(pl_counts) | set(en_counts):
            cp, ce = pl_counts.get(w, 0), en_counts.get(w, 0)
            if cp + ce < 2:
                continue
            s = math.log(((cp + 0.5) / npl) / ((ce + 0.5) / nen))
            self.scores[w] = max(-6.0, min(6.0, s))

    def score(self, tok):
        k = token_key(tok)
        if not k:
            return 0.0
        if len(k) <= 1:
            return 3.0 if k in _PL_CHARS else 0.0
        s = self.scores.get(k)
        if s is None:
            s = 0.0
        if any(ch in _PL_CHARS for ch in k):
            s = max(s, 3.0)
        return s

    @classmethod
    def from_texts(cls, pl_texts, en_texts):
        cp, ce = Counter(), Counter()
        for t in pl_texts:
            for tok in t.split():
                k = token_key(tok)
                if k:
                    cp[k] += 1
        for t in en_texts:
            for tok in t.split():
                k = token_key(tok)
                if k:
                    ce[k] += 1
        return cls(cp, ce)


def _legacy_cells(rec):
    return [rec.get(k, "") for k in ("PYTANIE", "ODP1", "ODP2", "ODP3", "ODP4")]


def load_legacy(legacy_dir, licence):
    pl_name, en_name = LEGACY_FILES[licence]
    out = {"pl": None, "en": None}
    for key, name in (("pl", pl_name), ("en", en_name)):
        if name and (Path(legacy_dir) / name).is_file():
            with open(Path(legacy_dir) / name, encoding="utf-8") as f:
                out[key] = json.load(f)
    return out


def split_legacy_en_cell(text):
    """Legacy 'PL\\nEN' cell -> (pl, en|None)."""
    if not isinstance(text, str):
        return "", None
    lines = [clean_text(x) for x in text.split("\n")]
    lines = [x for x in lines if x]
    if not lines:
        return "", None
    if len(lines) == 1:
        return lines[0], None
    return lines[0], " ".join(lines[1:])


def build_lexicon(legacy_dir, exclude=None):
    """Lexicon from all legacy data; ``exclude(idx)`` hides records (hold-out evaluation)."""
    pl_texts, en_texts = [], []
    for licence in LICENCES:
        data = load_legacy(legacy_dir, licence)
        if data["pl"]:
            for i, rec in enumerate(data["pl"]):
                if exclude and exclude(licence, "pl", i):
                    continue
                pl_texts.extend(clean_text(c) for c in _legacy_cells(rec))
        if data["en"]:
            for i, rec in enumerate(data["en"]):
                if exclude and exclude(licence, "en", i):
                    continue
                for c in _legacy_cells(rec):
                    pl, en = split_legacy_en_cell(c)
                    pl_texts.append(pl)
                    if en:
                        en_texts.append(en)
    if not en_texts:
        raise ConvertError(f"legacy data for the PL/EN lexicon not found in {legacy_dir}")
    return Lexicon.from_texts(pl_texts, en_texts)


# Parameters of the splitter (tuned on a hold-out of the legacy data, see --eval-split).
PARAMS = {
    "sent_end": 4.0,  # the Polish part ends with . ? ! : ; or a closing bracket/quote
    "punct_match": 3.0,  # both parts end with the same punctuation mark
    "lower_start": 2.5,  # English part would start with a lowercase letter
    "ratio": 3.0,  # penalty per unit of |ln(len_en / len_pl)| beyond RATIO_FREE
}
RATIO_FREE = 0.7


def split_pl_en(text, lex, params=None):
    """Split a mixed 'PL text EN text' cell.

    Returns (pl, en, margin). en is None when no English part was found. margin is the score
    advantage of the chosen split over the best split in which the boundary is moved by 2+ words
    (a small margin = ambiguous).
    """
    P = params or PARAMS
    toks = text.split(" ")
    n = len(toks)
    if n < 2:
        return text, None, 99.0
    s = [lex.score(t) for t in toks]
    pre = [0.0]
    for v in s:
        pre.append(pre[-1] + v)
    clen = [0]
    for t in toks:
        clen.append(clen[-1] + len(t) + 1)
    total = clen[n]
    vals = []
    for k in range(1, n + 1):  # k = number of Polish tokens
        v = pre[k] - (pre[n] - pre[k])
        if k < n:
            if _SENT_END.search(toks[k - 1]):
                v += P["sent_end"]
            first = toks[k][:1]
            if first.isalpha() and first.islower():
                v -= P["lower_start"]
            end_pl, end_en = toks[k - 1][-1:], toks[n - 1][-1:]
            if end_pl == end_en and not end_pl.isalnum():
                v += P["punct_match"]
            lp, le = clen[k], total - clen[k]
            dev = abs(math.log(le / lp)) - RATIO_FREE
            if dev > 0:
                v -= P["ratio"] * dev
        vals.append(v)
    best = max(range(n), key=lambda i: (vals[i], -i))
    others = [vals[i] for i in range(n) if abs(i - best) >= 2]
    margin = vals[best] - max(others) if others else 99.0
    k = best + 1
    if k >= n:
        return text, None, margin
    return " ".join(toks[:k]), " ".join(toks[k:]), margin


def has_letters(text):
    return any(ch.isalpha() for ch in text)


MIN_MARGIN = 2.0  # below this the split is considered unreliable


def split_cell(text, lex, params=None):
    """-> (pl, en, flag); flag in {"ok", "neutral", "no-en", "ambiguous"}."""
    if not has_letters(text):
        return text, text, "neutral"
    pl, en, margin = split_pl_en(text, lex, params)
    if en is None:
        return text, None, "no-en"
    if margin < MIN_MARGIN:
        return text, None, "ambiguous"
    return pl, en, "ok"


# --------------------------------------------------------------------------- records -> questions


def build_questions(records, spec, lex, stats):
    """Apply cleaning, PL/EN split, rejection and de-duplication. Returns (questions, info)."""
    bilingual = bool(spec.get("bilingual"))
    info = {"cell_flags": Counter(), "ambiguous_examples": [], "q_flags": Counter()}
    candidates = []
    for rec in records:
        page = rec["page"]
        number = normalize_number(rec["number_raw"])
        texts = [clean_text(join_lines(c)) for c in rec["cells"]]
        if not number:
            stats.discard(page, "(empty)", "empty NUMER")
            continue
        if not NUMBER_RE.match(number):
            stats.discard(page, rec["number_raw"], "invalid NUMER")
            continue
        if not texts[0]:
            stats.discard(page, number, "empty question")
            continue
        if not all(texts[1:]):
            stats.discard(page, number, "empty answer")
            continue
        prefix = number.split("-")[0]
        subject = TOPIC_TO_SUBJECT.get(prefix)
        if subject is None:
            stats.discard(page, number, f"unknown topic prefix {prefix}")
            continue
        cells = []
        flags = []
        for t in texts:
            if bilingual:
                pl, en, flag = split_cell(t, lex)
            else:
                pl, en, flag = t, None, "mono"
            cells.append({"pl": pl, "en": en})
            flags.append(flag)
            info["cell_flags"][flag] += 1
        candidates.append({"page": page, "number": number, "topic": prefix, "subject": subject,
                           "cells": cells, "flags": flags, "joined": texts})

    # exact duplicates: same NUMER and same Polish text of the question and of all answers
    seen = {}
    unique = []
    for c in candidates:
        key = (c["number"], tuple(x["pl"] for x in c["cells"]))
        if key in seen:
            stats.exact_duplicates.append((c["page"], c["number"]))
            prev = seen[key]
            if bilingual and prev["cells"][0]["en"] is None and c["cells"][0]["en"] is not None:
                # keep the variant that has English text
                unique[unique.index(prev)] = c
                seen[key] = c
            continue
        seen[key] = c
        unique.append(c)

    by_number = defaultdict(list)
    for c in unique:
        by_number[c["number"]].append(c)

    questions = []
    for number, group in by_number.items():
        ids = {}
        if len(group) == 1:
            ids[id(group[0])] = number
        else:
            used = Counter()
            for c in group:
                h = hash_text(c["cells"][0]["pl"], [c["cells"][1]["pl"]])
                used[h] += 1
            for c in group:
                h = hash_text(c["cells"][0]["pl"], [c["cells"][1]["pl"]])
                if used[h] > 1:  # same question and correct answer, different distractors
                    h = hash_text(c["cells"][0]["pl"], [x["pl"] for x in c["cells"][1:]])
                ids[id(c)] = f"{number}~{h}"
        for c in group:
            qid = ids[id(c)]
            questions.append({
                "id": qid,
                "number": number,
                "topic": c["topic"],
                "subject": c["subject"],
                "q": c["cells"][0],
                "a": c["cells"][1:],
                "correct": 0,
                "_page": c["page"],
                "_flags": c["flags"],
                "_joined": c["joined"],
            })
    if len({q["id"] for q in questions}) != len(questions):
        raise ConvertError("internal error: duplicate ids after hashing")
    questions.sort(key=lambda q: q["id"])
    return questions


def question_has_en(q):
    return q["q"]["en"] is not None


# --------------------------------------------------------------------------- output


def dumps_bank(licence, source, questions):
    head = json.dumps({"schema": SCHEMA, "licence": licence, "source": source}, ensure_ascii=False,
                      separators=(",", ":"))
    lines = []
    for q in questions:
        item = {k: q[k] for k in ("id", "number", "topic", "subject", "q", "a", "correct")}
        lines.append(json.dumps(item, ensure_ascii=False, separators=(",", ":")))
    # head ends with "}" -> reopen the object for the question list
    return head[:-1] + ',"questions":[\n' + ",\n".join(lines) + "\n]}\n"


# --------------------------------------------------------------------------- report


def short(text, n=110):
    return text if len(text) <= n else text[: n - 1] + "…"


def legacy_index(legacy_dir, licence):
    """Number -> list of (q_pl, correct_pl) of the previous project data."""
    data = load_legacy(legacy_dir, licence)
    src = data["pl"]
    if not src:
        return None
    idx = defaultdict(list)
    for rec in src:
        num = normalize_number(rec.get("NUMER", ""))
        idx[num].append((clean_text(rec.get("PYTANIE", "")), clean_text(rec.get("ODP1", ""))))
    return idx


def make_report(licence, spec, stats, questions, info, legacy_dir):
    L = []
    L.append(f"# Конвертация банка {licence.upper()}")
    L.append("")
    L.append(f"Источник: `{spec['file']}` (SHA-256 `{spec['sha256']}`, дата PDF {spec['date']}). "
             f"Страница ULC: {spec.get('page_url', '')}")
    L.append("")
    L.append("## Баланс строк")
    L.append("")
    discarded = stats.discarded
    dup = stats.exact_duplicates
    accepted = len(questions)
    L.append(f"- строк таблицы в PDF (всего): {stats.table_rows}")
    L.append(f"- из них заголовок таблицы: {stats.header_rows}")
    L.append(f"- строк-продолжений, склеенных с предыдущей записью (перенос между страницами): {stats.merged_rows}")
    L.append(f"- записей (строк с NUMER или L.p.): {stats.data_rows}")
    L.append(f"  - принято вопросов: {accepted}")
    L.append(f"  - отброшено как мусор: {len(discarded)}")
    L.append(f"  - отброшено как точные дубли (тот же NUMER и тот же текст): {len(dup)}")
    check = stats.header_rows + stats.merged_rows + accepted + len(discarded) + len(dup)
    L.append(f"- проверка: {stats.header_rows} + {stats.merged_rows} + {accepted} + {len(discarded)} + {len(dup)} "
             f"= {check}, строк в PDF = {stats.table_rows} -> {'сходится' if check == stats.table_rows else 'НЕ СХОДИТСЯ'}")
    L.append("")
    L.append("### Отброшенные записи")
    L.append("")
    if discarded:
        L.append("| стр. | NUMER | причина |")
        L.append("|---|---|---|")
        for page, number, reason in discarded:
            L.append(f"| {page} | {number} | {reason} |")
    else:
        L.append("нет")
    L.append("")
    L.append("### Точные дубли (оставлена первая запись)")
    L.append("")
    if dup:
        L.append(", ".join(f"{n} (стр. {p})" for p, n in dup))
    else:
        L.append("нет")
    L.append("")

    by_number = Counter(q["number"] for q in questions)
    multi = {n: c for n, c in by_number.items() if c > 1}
    L.append("## Варианты под одним NUMER")
    L.append("")
    L.append(f"- уникальных NUMER: {len(by_number)}")
    L.append(f"- NUMER с несколькими вариантами: {len(multi)} (вариантов в них: {sum(multi.values())}); "
             "все варианты сохранены, id = `NUMER~<hash6>`")
    L.append(f"- вопросов с id без суффикса: {sum(1 for q in questions if '~' not in q['id'])}")
    L.append("")

    L.append("## Предметы")
    L.append("")
    L.append("| предмет | вопросов | quizLength |")
    L.append("|---|---|---|")
    cnt = Counter(q["subject"] for q in questions)
    for sid in SUBJECTS:
        L.append(f"| {sid} | {cnt.get(sid, 0)} | {QUIZ_LENGTH[sid]} |")
    L.append("")
    L.append("Темы (префикс NUMER): " + ", ".join(
        f"{t}={c}" for t, c in sorted(Counter(q["topic"] for q in questions).items())))
    L.append("")

    if spec.get("bilingual"):
        with_en = sum(1 for q in questions if question_has_en(q))
        pct = 100.0 * with_en / len(questions) if questions else 0.0
        L.append("## Английский текст")
        L.append("")
        L.append(f"- вопросов с EN-текстом вопроса: {with_en} из {len(questions)} ({pct:.2f} %)")
        full_en = sum(1 for q in questions if question_has_en(q) and all(a["en"] is not None for a in q["a"]))
        L.append(f"- вопросов, у которых EN есть и у вопроса, и у всех 4 ответов: {full_en} "
                 f"({100.0 * full_en / len(questions):.2f} %)")
        cf = info["cell_flags"]
        L.append(f"- ячеек: разделено {cf['ok']}, без цифр/букв (одинаковы в PL и EN) {cf['neutral']}, "
                 f"EN не найден {cf['no-en']}, неоднозначно (оставлен полный текст в `pl`, `en = null`) {cf['ambiguous']}")
        L.append("")
        no_en = [q for q in questions if not question_has_en(q)]
        L.append(f"### Вопросы без EN-текста вопроса ({len(no_en)})")
        L.append("")
        for q in no_en[:40]:
            L.append(f"- `{q['id']}` (стр. {q['_page']}): {short(q['_joined'][0])}")
        if len(no_en) > 40:
            L.append(f"- … и ещё {len(no_en) - 40}")
        L.append("")
        if pct < 95.0:
            L.append("Доля EN ниже 95 %. Примеры (10) приведены выше; причина — см. README (разделение PL/EN эвристическое).")
            L.append("")
        L.append("### Примеры разделения (первые вопросы каждого предмета)")
        L.append("")
        shown = defaultdict(int)
        for q in questions:
            if shown[q["subject"]] < 1 and question_has_en(q):
                shown[q["subject"]] += 1
                L.append(f"- `{q['id']}`: PL «{short(q['q']['pl'], 90)}» / EN «{short(q['q']['en'], 90)}»")
        L.append("")
    else:
        L.append("## Английский текст")
        L.append("")
        L.append("Источник только польский: `en = null` у всех вопросов.")
        L.append("")

    L.append("## Сравнение с прежними данными проекта")
    L.append("")
    idx = legacy_index(legacy_dir, licence)
    if idx is None:
        L.append("Прежние данные не найдены, сравнение пропущено.")
    else:
        legacy_numbers = {n for n in idx if NUMBER_RE.match(n)}
        new_numbers = set(by_number)
        added = sorted(new_numbers - legacy_numbers)
        gone = sorted(legacy_numbers - new_numbers)
        by_num_q = defaultdict(list)
        for q in questions:
            by_num_q[q["number"]].append(q)
        changed_correct, changed_text = [], []
        for n in sorted(legacy_numbers & new_numbers):
            for lq, lc in idx[n]:
                lqf = fold(lq)
                same_q = [q for q in by_num_q[n] if fold(q["q"]["pl"]) == lqf]
                if not same_q:
                    if not any(fold(q["a"][0]["pl"]) == fold(lc) for q in by_num_q[n]):
                        changed_text.append(n)
                    continue
                if not any(fold(q["a"][0]["pl"]) == fold(lc) for q in same_q):
                    changed_correct.extend(q["id"] for q in same_q)
        L.append(f"- вопросов в прежних данных: {sum(len(v) for v in idx.values())} "
                 f"(уникальных NUMER: {len(legacy_numbers)}), в новом банке: {len(questions)} "
                 f"(уникальных NUMER: {len(new_numbers)})")
        L.append(f"- новых NUMER: {len(added)}")
        L.append(f"- исчезнувших NUMER: {len(gone)}")
        L.append(f"- NUMER, у которых прежний вопрос найден дословно, но **верный ответ изменился**: "
                 f"{len(set(changed_correct))}")
        L.append(f"- NUMER, у которых ни прежний вопрос, ни прежний верный ответ не найдены среди вариантов "
                 f"(текст переписан): {len(set(changed_text))}")
        L.append("")
        L.append("### Новые NUMER")
        L.append("")
        L.append(", ".join(added) if added else "нет")
        L.append("")
        L.append("### Исчезнувшие NUMER")
        L.append("")
        L.append(", ".join(gone) if gone else "нет")
        L.append("")
        L.append("### Изменённый верный ответ (id)")
        L.append("")
        L.append(", ".join(sorted(set(changed_correct))) if changed_correct else "нет")
        L.append("")
        L.append("### Текст вопроса переписан (NUMER)")
        L.append("")
        L.append(", ".join(sorted(set(changed_text))) if changed_text else "нет")
    L.append("")
    return "\n".join(L)


# --------------------------------------------------------------------------- driver


def convert(licence, sources, args, lex_cache):
    spec = sources["sources"][licence]
    pdf = check_pdf(licence, spec, args.sources_dir)
    rows = extract_rows(pdf, spec["sha256"], args.cache_dir)
    stats = Stats()
    records = build_records(rows, stats)
    lex = None
    if spec.get("bilingual"):
        if "lex" not in lex_cache:
            lex_cache["lex"] = build_lexicon(args.legacy_dir)
        lex = lex_cache["lex"]
    questions = build_questions(records, spec, lex, stats)
    # info is reconstructed from the questions to keep build_questions' signature small
    info = {"cell_flags": Counter(f for q in questions for f in q["_flags"])}
    # flags of dropped exact duplicates are not counted; fine for a report
    source = {"file": spec["file"], "sha256": spec["sha256"], "date": spec["date"], "kind": spec["kind"]}
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / f"bank_{licence}.json").write_text(dumps_bank(licence, source, questions), encoding="utf-8")
    report = make_report(licence, spec, stats, questions, info, args.legacy_dir)
    rep_dir = Path(args.reports_dir)
    rep_dir.mkdir(parents=True, exist_ok=True)
    (rep_dir / f"{licence}.md").write_text(report, encoding="utf-8")
    return len(questions), stats


# --------------------------------------------------------------------------- hold-out evaluation


def eval_split(args):
    """Accuracy of the splitter on legacy bilingual data with a hold-out lexicon."""
    import random  # only for the deterministic shuffle of hold-out indices

    for licence in ("ppla", "pplh"):
        data = load_legacy(args.legacy_dir, licence)
        en = data["en"]
        hold = {i for i in range(len(en)) if i % 2 == 1}
        lex = build_lexicon(args.legacy_dir, exclude=lambda lic, kind, i: kind == "en" and i in hold)
        total = ok = amb = wrong = 0
        wrong_samples = []
        for i in sorted(hold):
            for c in _legacy_cells(en[i]):
                pl, en_t = split_legacy_en_cell(c)
                if not en_t:
                    continue
                total += 1
                mixed = clean_text(pl + " " + en_t)
                gpl, gen, flag = split_cell(mixed, lex)
                if flag == "neutral":
                    ok += 1
                elif flag != "ok":
                    amb += 1
                elif gpl == pl and gen == en_t:
                    ok += 1
                else:
                    wrong += 1
                    if len(wrong_samples) < 8:
                        wrong_samples.append((pl, en_t, gpl, gen))
        print(f"{licence}: cells={total} correct={ok} ({100*ok/total:.2f}%) "
              f"fallback(unsplit)={amb} ({100*amb/total:.2f}%) WRONG-SPLIT={wrong} ({100*wrong/total:.2f}%)")
        for s in wrong_samples:
            print("   want:", short(s[0], 60), "|", short(s[1], 60))
            print("   got :", short(s[2], 60), "|", short(s[3] or "", 60))
    _ = random


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--all", action="store_true", help="convert all licences")
    ap.add_argument("--licence", action="append", choices=LICENCES, default=[])
    ap.add_argument("--sources", default=str(HERE / "sources.json"))
    ap.add_argument("--sources-dir", default=str(HERE / "sources"))
    ap.add_argument("--cache-dir", default=str(HERE / "cache"))
    ap.add_argument("--legacy-dir", default=str(HERE / "legacy"))
    ap.add_argument("--out-dir", default=str(REPO / "assets" / "data"))
    ap.add_argument("--reports-dir", default=str(HERE / "reports"))
    ap.add_argument("--eval-split", action="store_true", help="hold-out accuracy of the PL/EN splitter")
    args = ap.parse_args(argv)
    try:
        if args.eval_split:
            eval_split(args)
            return 0
        licences = list(LICENCES) if args.all else args.licence
        if not licences:
            ap.error("specify --all or --licence")
        sources = load_sources(args.sources)
        lex_cache = {}
        for lic in licences:
            n, _ = convert(lic, sources, args, lex_cache)
            print(f"{lic}: {n} questions")
    except ConvertError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
