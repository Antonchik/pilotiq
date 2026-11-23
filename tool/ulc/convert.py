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
import difflib
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
    norm = [_WS.sub(" ", unicodedata.normalize("NFC", t)).strip() for t in ([pl_q] + pl_answers)]
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


def _without_stray_spaces(line_chars):
    """Drop invisible space glyphs that lie on top of a letter of the same line.

    Some cells contain overlapping zero-width spaces ("od s t r o m ego"); a real inter-word
    space only touches its neighbours (overlap < 0.5pt).
    """
    glyphs = [ch for ch in line_chars if not ch["text"].isspace()]
    kept = []
    for ch in line_chars:
        if ch["text"].isspace() and any(
                g["x0"] < ch["x1"] - 0.5 and g["x1"] > ch["x0"] + 0.5 for g in glyphs):
            continue
        kept.append(ch)
    return kept


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
        lines.append("".join(ch["text"] for ch in _without_stray_spaces(cluster)))
    text = "\n".join(lines)
    if re.sub(r"\s+", "", text) != re.sub(r"\s+", "", fallback):
        return fallback  # safety net: never trust own reconstruction over pdfplumber's
    return text


def extract_rows(pdf_path, sha, cache_dir):
    """Table rows of every page: [{"page": n, "cells": [7 str]}], with cell line breaks kept.

    Cached in cache_dir (keyed by the SHA-256 of the PDF, the pdfplumber version and the format).
    """
    cache = Path(cache_dir) / f"{sha}.pdfplumber-{PDFPLUMBER_VERSION}.v4.json"
    if cache.is_file():
        with open(cache, encoding="utf-8") as f:
            return json.load(f)
    try:
        import pdfplumber
    except ImportError as e:  # pragma: no cover
        raise ConvertError("pdfplumber is not installed: pip install -r tool/ulc/requirements.txt") from e
    if pdfplumber.__version__ != PDFPLUMBER_VERSION:
        print(f"warning: pdfplumber {pdfplumber.__version__} is installed, "
              f"{PDFPLUMBER_VERSION} is pinned; output may differ", file=sys.stderr)
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
        self.exact_duplicates = []  # (page, number, "exact"|"near"|"en", page of the kept variant)
        self.fallbacks = []  # (page, number, reasons): questions kept in source form (en = null)
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
        # words that are clearly Polish: frequent in the Polish data, (almost) absent from English text
        self.pl_words = {w for w, n in pl_counts.items()
                         if len(w) >= 4 and n >= 3 and en_counts.get(w, 0) * 10 < n}
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
    "sent_end": 8.0,  # the Polish part ends with . ? ! : ; or a closing bracket/quote
    "punct_match": 5.0,  # both parts end with the same punctuation mark
    "lower_start": 1.5,  # English part would start with a lowercase letter
    "ratio": 9.0,  # penalty per unit of |ln(len_en / len_pl)| beyond RATIO_FREE
}
RATIO_FREE = 0.7


_GLUE = re.compile(r"(?<=\S)[:.?!;](?=[A-Z][a-z])")


def _token_spans(text):
    """Whitespace-separated tokens as (start, end); a token glued across a sentence end
    ("przeleci:The") is split in two so that the boundary can fall inside it."""
    spans = []
    for m in re.finditer(r"\S+", text):
        start, end = m.span()
        cut = start
        for g in _GLUE.finditer(m.group()):
            spans.append((cut, start + g.end()))
            cut = start + g.end()
        spans.append((cut, end))
    return spans


def split_pl_en(text, lex, params=None):
    """Split a mixed 'PL text EN text' cell.

    Returns (pl, en, margin). en is None when no English part was found. margin is the score
    advantage of the chosen split over the best split in which the boundary is moved by 2+ words
    (a small margin = ambiguous).
    """
    P = params or PARAMS
    spans = _token_spans(text)
    toks = [text[a:b] for a, b in spans]
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
    while k < n - 1 and not any(ch.isalnum() for ch in toks[k]):
        k += 1  # a detached punctuation mark ("wiatr” .") belongs to the Polish part
    return text[: spans[k - 1][1]], text[spans[k][0]:], margin


def has_letters(text):
    return any(ch.isalpha() for ch in text)


MIN_MARGIN = 1.0  # below this the split is considered unreliable
# A Polish part without terminal punctuation is the typical shape of a split that cut the Polish
# text short (the tail ended up in the English part), so it needs a much larger margin.
NO_PUNCT_MIN_MARGIN = 8.0


def _core(text):
    """Comparison form of one half of a doubled cell: no spaces, no case, no edge separators."""
    return re.sub(r"\s+", "", text).strip(";,.").casefold()


def _tidy_half(text):
    text = re.sub(r"\s+([;,.])", r"\1", text.strip())
    return text.rstrip(" ;,")


def _identical_halves(text):
    """'1000 m 1000 m', '135° ; 135°;', '5 ; 5', '315°;315°;' -> (half, half): the same text in
    Polish and English. The halves must be equal ignoring spaces, case and ; , . at their edges."""
    if len(text) > 120 or len(text) < 3:
        return None
    for i in range(1, len(text)):
        if not (text[i] == " " or text[i - 1] in ";,."):
            continue
        if text[i:].lstrip()[:1] in (";", ",", "."):
            continue  # never cut right before a punctuation mark ("17 US gal . 17 US gal.")
        left, right = text[:i], text[i:]
        cl, cr = _core(left), _core(right)
        if cl and cl == cr and any(ch.isalnum() for ch in cl):
            return _tidy_half(left), _tidy_half(right.lstrip(" ;,."))
    return None


def _starts_with_repeat(en):
    """True if the first word of the English part (3+ letters) occurs again with the same case.

    Typical for a boundary placed too early: the tail of the Polish text ("... Area") is
    repeated by its own translation ("Area control"). Occurrences right after a sentence end do
    not count.
    """
    raw = en.split(" ")
    toks = [t.strip(_TOKEN_STRIP) for t in raw]
    first = toks[0]
    if len(first) < 3 or not first.isalpha():
        return False
    # a repeat at the start of a new sentence ("... : Overheating ...") is a legitimate translation
    return any(toks[i] == first and not _SENT_END.search(raw[i - 1]) for i in range(1, len(toks)))


def split_cell(text, lex, params=None):
    """-> (pl, en, flag); flag in {"ok", "twin", "neutral", "plain", "ambiguous"}.

    ok = split into Polish and English; twin = the same text repeated; neutral = no letters at all;
    plain = no English part found; ambiguous = unreliable split (the full text is returned in `pl`).
    """
    twin = _identical_halves(text)
    if twin:
        return twin[0], twin[1], "twin"
    if not has_letters(text):
        return text, text, "neutral"
    pl, en, margin = split_pl_en(text, lex, params)
    if en is None:
        return text, None, "plain"
    if margin < MIN_MARGIN or (pl[-1:].isalnum() and margin < NO_PUNCT_MIN_MARGIN):
        return text, None, "ambiguous"
    if _starts_with_repeat(en):
        return text, None, "ambiguous"
    return pl, en, "ok"


_EN_NAMES = {"góra", "górze", "góry", "górą"}  # Polish proper names that may occur in English text
_GLUED = re.compile(r"[a-ząćęłńóśźż][A-Z][a-z]{3,}")
_CAP_AFTER_DOT = re.compile(r"[.?!]\s?[A-Z]$")


def polish_in_english(en, lex):
    """A word with Polish diacritics or from the Polish vocabulary anywhere in the English part."""
    for tok in en.split(" "):
        key = token_key(tok)
        if not key or key in _EN_NAMES:
            continue
        if any(ch in _PL_CHARS for ch in key) or (key.isalpha() and len(key) >= 4 and key in lex.pl_words):
            return True
    return False


def boundary_looks_wrong(pl, en):
    """Typical symptoms of a boundary that cut the Polish text short or glued the languages."""
    if en[:1].islower() and pl.rstrip()[-1:] not in tuple(".?!:;"):
        return "EN starts in lower case after an unfinished Polish part"
    if _CAP_AFTER_DOT.search(pl):
        return "Polish part ends with a lone capital after a full stop"
    if _GLUED.search(pl):
        return "English word glued to the Polish text"
    return None


def digits(text):
    return "".join(ch for ch in text if ch.isdigit())


def starts_polish(en, lex):
    """True if the English part begins with a Polish word or with a punctuation mark."""
    if not en:
        return True
    if en[0] in ";,.:)":
        return True
    for tok in en.split(" ")[:2]:
        key = token_key(tok)
        if key and (any(ch in _PL_CHARS for ch in key) or key in lex.pl_words):
            return True
    return False


def plain_is_neutral(text, lex):
    """A cell without an English part that carries no Polish evidence ('1000 ft', 'VFR')."""
    for tok in text.split(" "):
        key = token_key(tok)
        if key and (any(ch in _PL_CHARS for ch in key) or key in lex.pl_words or lex.score(tok) >= 1.5):
            return False
    return True


def is_polish_text(text, lex):
    """Clear evidence of Polish: a diacritic, 'tak'/'nie', or a long word of the Polish vocabulary."""
    for tok in text.split(" "):
        key = token_key(tok)
        if any(ch in _PL_CHARS for ch in key) or key in ("tak", "nie"):
            return True
        if key.isalpha() and len(key) >= 5 and key in lex.pl_words:
            return True
    return False


def assess_question(texts, lex):
    """Process the five cells (question + 4 answers) of one record as ONE unit.

    Returns (cells, flags, reasons, raw_results). If anything is doubtful, every cell is returned in its source
    form (`pl` = full cell text, `en` = None) so that all answers look alike, and `reasons` says why.
    """
    results = [split_cell(t, lex) for t in texts]
    flags = [r[2] for r in results]
    reasons = []
    if flags[0] in ("plain", "ambiguous"):
        reasons.append("question: no reliable EN" if flags[0] == "ambiguous" else "question: no EN found")
    for k in range(1, 5):
        pl, en, flag = results[k]
        if flag == "ambiguous":
            reasons.append(f"a{k - 1}: ambiguous split")
        elif flag == "plain" and not plain_is_neutral(texts[k], lex):
            reasons.append(f"a{k - 1}: Polish-only cell")
    for k, (pl, en, flag) in enumerate(results):
        name = "question" if k == 0 else f"a{k - 1}"
        if flag == "twin" and is_polish_text(pl, lex):
            reasons.append(f"{name}: the 'English' text repeats the Polish text")
        if flag == "ok":
            if _identical_halves(pl):
                reasons.append(f"{name}: the Polish part is itself repeated")
            if starts_polish(en, lex) or polish_in_english(en, lex):
                reasons.append(f"{name}: EN starts with a Polish word or punctuation" if starts_polish(en, lex)
                               else f"{name}: Polish word inside the English part")
            bad = boundary_looks_wrong(pl, en)
            if bad:
                reasons.append(f"{name}: {bad}")
            if digits(pl) and digits(en) and digits(pl) != digits(en):
                reasons.append(f"{name}: numbers differ between PL and EN")
            elif digits(pl) and not digits(en) and (en[:1].islower() or len(en.split(" ")) <= 2 and len(pl.split(" ")) > 2):
                reasons.append(f"{name}: number only in PL and EN looks cut off")
    if "twin" in flags[1:] and any(f in ("neutral", "plain") for f in flags[1:]):
        reasons.append("answers: some doubled, some single")
    seen = {}
    for k in range(1, 5):
        if flags[k] in ("ok", "twin", "plain"):
            key = re.sub(r"\s+", "", results[k][0]).casefold()
            if key in seen and re.sub(r"\s+", "", texts[k]).casefold() != re.sub(r"\s+", "", texts[seen[key]]).casefold():
                reasons.append(f"a{seen[key] - 1}/a{k - 1}: equal Polish text from different source cells")
            seen.setdefault(key, k)
    if reasons:
        return [{"pl": t, "en": None} for t in texts], ["source"] * 5, reasons, results
    cells = []
    for k, ((pl, en, flag), t) in enumerate(zip(results, texts)):
        if flag in ("neutral", "plain"):
            en = pl  # no Polish evidence: the same text in both languages
        if k > 0:  # answers: a trailing ; or , is list punctuation of the source, dropped everywhere alike
            pl, en = pl.rstrip(" ;,"), en.rstrip(" ;,")
        cells.append({"pl": pl, "en": en})
    return cells, flags, reasons, results


# --------------------------------------------------------------------------- records -> questions


def en_defects(c):
    """Quality of a candidate (smaller is better) - used to choose between duplicates: first a
    variant that needed no fallback (EN numbers agree with PL, reliable split, ...), then fewer EN
    texts starting in lower case ("wwith ..."). Ties keep the first occurrence."""
    lower = sum(1 for x in c["cells"] if x["en"] and x["en"][:1].islower())
    return (len(c["reasons"]), lower)


def build_questions(records, spec, lex, stats):
    """Apply cleaning, PL/EN split, rejection and de-duplication. Returns the list of questions (sorted by id)."""
    bilingual = bool(spec.get("bilingual"))
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
        if bilingual:
            cells, flags, reasons, raw = assess_question(texts, lex)
            raw_pl = [r[0] for r in raw]
        else:
            cells = [{"pl": t, "en": None} for t in texts]
            flags, reasons, raw_pl = ["mono"] * 5, [], texts
        candidates.append({"order": len(candidates), "page": page, "number": number, "topic": prefix,
                           "subject": subject, "cells": cells, "flags": flags, "joined": texts,
                           "reasons": reasons, "raw_pl": raw_pl})

    # duplicates: same NUMER and the same Polish text of the question and of all answers,
    # ignoring case and whitespace ("200 m." == "200m.", "lotu ?" == "lotu?")
    # Two records are duplicates if the full text of their cells (before any PL/EN splitting) is equal
    # ignoring spaces and case, or - for translated banks - if their Polish parts are equal.
    parent = list(range(len(candidates)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    first_by_key = {}
    for i, c in enumerate(candidates):
        # comparison only (the output text is not changed): the source artifact "/n" at the end of a cell is ignored
        keys = [("joined", c["number"],
                 tuple(re.sub(r"/n$", "", re.sub(r"\s+", "", x).casefold()) for x in c["joined"]))]
        if bilingual:
            keys.append(("pl", c["number"], tuple(re.sub(r"\s+", "", x).casefold() for x in c["raw_pl"])))
        for key in keys:
            j = first_by_key.setdefault(key, i)
            if j != i:
                parent[find(i)] = find(j)
    groups = {}
    for i, c in enumerate(candidates):
        groups.setdefault(find(i), []).append(c)
    unique = []
    for group in sorted(groups.values(), key=lambda g: g[0]["order"]):
        chosen = min(group, key=en_defects) if bilingual else group[0]  # min() keeps the first on ties
        chosen["id_source"] = group[0]["joined"]  # id does not depend on the PL/EN splitter
        unique.append(chosen)
        for c in group:
            if c is not chosen:
                same = [re.sub(r"\s+", "", x).casefold() for x in c["joined"]] == \
                       [re.sub(r"\s+", "", x).casefold() for x in chosen["joined"]]
                if c["joined"] == chosen["joined"]:
                    kind = "exact"
                elif same:
                    kind = "near"
                else:
                    kind = "en"
                stats.exact_duplicates.append((c["page"], c["number"], kind, chosen["page"]))
        if chosen["reasons"]:
            stats.fallbacks.append((chosen["page"], chosen["number"], chosen["reasons"]))
    unique.sort(key=lambda c: c["order"])

    by_number = defaultdict(list)
    for c in unique:
        by_number[c["number"]].append(c)

    questions = []
    for number, group in by_number.items():
        ids = {}
        if len(group) == 1:
            ids[id(group[0])] = number
        else:
            short_hash = {id(c): hash_text(c["id_source"][0], [c["id_source"][1]]) for c in group}
            used = Counter(short_hash.values())
            for c in group:
                h = short_hash[id(c)]
                if used[h] > 1:  # same question and correct answer, different distractors
                    h = hash_text(c["id_source"][0], c["id_source"][1:])
                ids[id(c)] = f"{number}~{h}"
        for c in group:
            questions.append({
                "id": ids[id(c)],
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


def _same_digits(x, y):
    dx, dy = digits(x), digits(y)
    return dx == dy or dx == dy + dy or dy == dx + dx


def _same_text(x, y):
    """Prefix comparison: a new cell kept in source form also contains the English part, a previous
    cell may contain the Polish text twice; any difference in numbers makes the texts different."""
    fx, fy = fold(x), fold(y)
    return bool(fx) and bool(fy) and (fx.startswith(fy) or fy.startswith(fx)) and _same_digits(x, y)


def classify_legacy(legacy_q, legacy_correct, variants):
    """Compare one previous record with the new variants of the same NUMER.

    Returns (category, ids): empty_legacy | unchanged | typo | real | reworded_same_answer | rewritten.
    Any difference in numbers is a real change; a typo needs the same digits and >= 90 % similarity.
    """
    if not legacy_correct.strip():
        return "empty_legacy", []
    same_q = [q for q in variants if _same_text(q["q"]["pl"], legacy_q)]
    if not same_q:
        if any(_same_text(q["a"][0]["pl"], legacy_correct) for q in variants):
            return "reworded_same_answer", []
        return "rewritten", []
    if any(_same_text(q["a"][0]["pl"], legacy_correct) for q in same_q):
        return "unchanged", []
    best = max(same_q, key=lambda q: difflib.SequenceMatcher(None, fold(legacy_correct), fold(q["a"][0]["pl"])).ratio())
    ratio = difflib.SequenceMatcher(None, fold(legacy_correct), fold(best["a"][0]["pl"])).ratio()
    if ratio >= 0.9 and _same_digits(legacy_correct, best["a"][0]["pl"]):
        return "typo", [best["id"]]
    return "real", [q["id"] for q in same_q]


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
    L.append(f"  - схлопнуто как дубли (тот же NUMER и тот же польский текст без учёта пробелов и регистра): {len(dup)}"
             f" (дословных {sum(1 for d in dup if d[2] == 'exact')}, различающихся пробелами/регистром "
             f"{sum(1 for d in dup if d[2] == 'near')}, с разным английским текстом "
             f"{sum(1 for d in dup if d[2] == 'en')})")
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
    L.append("### Схлопнутые дубли")
    L.append("")
    L.append("Дубли: полный текст ячеек до разделения совпадает без учёта пробелов и регистра, либо совпадает польская часть. "
             "Из группы остаётся запись, у которой (1) не потребовался исходный вид (числа EN согласованы с PL, разделение "
             "надёжно), затем (2) меньше EN-текстов со строчной буквы в начале; при равенстве — первая по порядку. "
             "Остальные схлопываются.")
    L.append("")
    exact = [d for d in dup if d[2] == "exact"]
    near = [d for d in dup if d[2] == "near"]
    en_diff = [d for d in dup if d[2] == "en"]
    L.append(f"Дословные дубли (весь текст ячеек совпадает) ({len(exact)}): "
             + (", ".join(f"{n} (стр. {p})" for p, n, _, _ in exact) or "нет"))
    L.append("")
    L.append(f"Различаются только пробелами/регистром ({len(near)}), формат «NUMER: удалена стр. → оставлена стр.»: "
             + (", ".join(f"{n}: {p} → {k}" for p, n, _, k in near) or "нет"))
    L.append("")
    L.append(f"Польский текст тот же, **английский различается** ({len(en_diff)}); оставлен вариант, у которого EN согласован "
             f"с PL (числа, надёжное разделение), формат «NUMER: удалена стр. → оставлена стр.»: "
             + (", ".join(f"{n}: {p} → {k}" for p, n, _, k in en_diff) or "нет"))
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

    same = [q["id"] for q in questions if len({a["pl"] for a in q["a"]}) < 4]
    L.append("## Подозрительные записи источника")
    L.append("")
    L.append(f"- вопросы с одинаковыми текстами у нескольких ответов (оставлены как в источнике): "
             f"{', '.join(same) if same else 'нет'}")
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
        L.append(f"- ячеек: разделено на PL/EN {cf['ok']}, одинаковый текст в обоих языках (повтор или без букв) "
                 f"{cf['twin'] + cf['neutral'] + cf['plain']}")
        L.append(f"- вопросов оставлено в исходном виде (`en = null` у вопроса и у всех ответов, в `pl` полный текст ячеек) "
                 f"из-за сомнений в разделении: {len(stats.fallbacks)}")
        reasons = Counter(r.split(": ", 1)[1] if ": " in r else r for _, _, rs in stats.fallbacks for r in rs)
        for r, n in sorted(reasons.items(), key=lambda kv: (-kv[1], kv[0])):
            L.append(f"  - {r}: {n}")
        L.append("")
        L.append("### Вопросы в исходном виде (NUMER, стр., причины)")
        L.append("")
        for page, number, rs in stats.fallbacks:
            L.append(f"- {number} (стр. {page}): {'; '.join(rs)}")
        L.append("")
        no_en = [q for q in questions if not question_has_en(q)]
        L.append(f"### Вопросы без EN-текста вопроса ({len(no_en)})")
        L.append("")
        L.append(", ".join(f"`{q['id']}`" for q in no_en) or "нет")
        L.append("")
        if pct < 95.0:
            L.append("Доля EN ниже 95 %: все вопросы с малейшим сомнением в разделении PL/EN сознательно оставлены без EN "
                     "(лучше меньше EN, чем неверный EN); причины и полный список — выше.")
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
        cats = defaultdict(list)  # category -> [ids or numbers]
        total_legacy = 0
        for n in sorted(legacy_numbers & new_numbers):
            for lq, lc in idx[n]:
                total_legacy += 1
                cat, ids = classify_legacy(lq, lc, by_num_q[n])
                cats[cat].extend(ids if cat in ("real", "typo") else [n])
        L.append(f"- вопросов в прежних данных: {sum(len(v) for v in idx.values())} "
                 f"(уникальных NUMER: {len(legacy_numbers)}), в новом банке: {len(questions)} "
                 f"(уникальных NUMER: {len(new_numbers)})")
        L.append(f"- новых NUMER: {len(added)}")
        L.append(f"- исчезнувших NUMER: {len(gone)}")
        L.append(f"- прежних записей с NUMER, который есть и в новом банке: {total_legacy}; из них:")
        L.append(f"  - вопрос найден дословно, верный ответ тот же: {len(cats['unchanged'])}")
        L.append(f"  - вопрос найден дословно, верный ответ изменён только опечаткой/пунктуацией "
                 f"(сходство текста ≥ 90 %): {len(cats['typo'])}")
        L.append(f"  - вопрос найден дословно, **верный ответ реально другой** (id вариантов): {len(cats['real'])}")
        L.append(f"  - вопрос переформулирован, но прежний верный ответ есть среди ответов нового варианта: "
                 f"{len(cats['reworded_same_answer'])}")
        L.append(f"  - вопрос и верный ответ переписаны (сопоставить нельзя): {len(cats['rewritten'])}")
        L.append(f"  - прежний верный ответ был пустым (в прежних данных): {len(cats['empty_legacy'])}")
        L.append("")
        L.append("### Новые NUMER")
        L.append("")
        L.append(", ".join(added) if added else "нет")
        L.append("")
        L.append("### Исчезнувшие NUMER")
        L.append("")
        L.append(", ".join(gone) if gone else "нет")
        L.append("")
        L.append("### Верный ответ реально другой (id)")
        L.append("")
        L.append(", ".join(sorted(set(cats["real"]))) if cats["real"] else "нет")
        L.append("")
        L.append("### Верный ответ изменён опечаткой/пунктуацией (id)")
        L.append("")
        L.append(", ".join(sorted(set(cats["typo"]))) if cats["typo"] else "нет")
        L.append("")
        L.append("### Прежний верный ответ пустой (NUMER)")
        L.append("")
        L.append(", ".join(sorted(set(cats["empty_legacy"]))) if cats["empty_legacy"] else "нет")
        L.append("")
        L.append("### Вопрос и верный ответ переписаны (NUMER)")
        L.append("")
        L.append(", ".join(sorted(set(cats["rewritten"]))) if cats["rewritten"] else "нет")
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
    info = {"cell_flags": Counter(f for q in questions for f in q["_flags"])}
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
    """Accuracy of the splitter on legacy bilingual data with a hold-out lexicon.

    The lexicon is built from the even-numbered legacy records only and tested on the odd ones.
    The legacy split is itself noisy (it sometimes cut inside the Polish text); a result whose
    Polish part merely extends the legacy one is therefore counted as "legacy cut short".
    """
    for licence in ("ppla", "pplh"):
        en = load_legacy(args.legacy_dir, licence)["en"]
        hold = {i for i in range(len(en)) if i % 2 == 1}
        lex = build_lexicon(args.legacy_dir, exclude=lambda lic, kind, i: kind == "en" and i in hold)
        counts = Counter()
        wrong = []
        for i in sorted(hold):
            for cell in _legacy_cells(en[i]):
                pl, en_t = split_legacy_en_cell(cell)
                if not en_t:
                    continue
                gpl, gen, flag = split_cell(clean_text(pl + " " + en_t), lex)
                if flag in ("neutral", "twin"):
                    counts["neutral"] += 1
                elif flag != "ok":
                    counts["unsplit-fallback"] += 1
                elif (gpl, gen) == (pl, en_t):
                    counts["exact"] += 1
                elif gpl.startswith(pl):
                    counts["legacy-cut-short"] += 1
                else:
                    counts["DIFFERENT"] += 1
                    wrong.append((pl, en_t, gpl, gen))
        total = sum(counts.values())
        print(f"{licence}: cells={total} " + " ".join(f"{k}={v} ({100 * v / total:.2f}%)" for k, v in sorted(counts.items())))
        for w in wrong[:5]:
            print("   legacy:", short(w[0], 70), "|", short(w[1], 50))
            print("   ours  :", short(w[2], 70), "|", short(w[3] or "", 50))


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
