#!/usr/bin/env python3
"""Учебные материалы: инвентаризация вопросов, сборка ассета, валидатор.

Подкоманды: inventory, build, validate, apply-review, report.
Только стандартная библиотека. Запуск: python3 -I tool/materials/materials.py <команда>.
Описание формата и жизненного цикла записи — в tool/materials/README.md.
"""
import argparse
import datetime
import hashlib
import json
import re
import sys
import unicodedata
from pathlib import Path

SUBJECT = "air_law"
LICENCES = ["ppla", "pplh", "spl", "bpl"]
STATUSES = ["none", "draft", "verified", "disputed", "unverified", "retired"]
PUBLISHED = ("verified", "disputed")
# unverified-запись без нормативного источника (решение владельца 24.11.2026): в приложение не попадает, пока её не проверит эксперт
BASES = ("no-source", "aip-missing", "outdated")
# outdated: вопрос опирается на отменённую норму; объяснения нет (text пуст), basisNote = что отменено и чем заменено;
# такая запись попадает в ассет отдельным списком "outdated" (приложение показывает пометку всем), см. README
INTERNAL_PREFIX = re.compile(r"^\s*[a-z][a-z0-9-]*:\s")   # "old-licence: ..." and similar machine categories must not reach the user
MAX_OUTDATED_NOTE = 300
VERDICT_STATUS_OK = {"verified": "PASS", "disputed": "DISPUTED"}
MAX_TEXT = 700
MAX_QUOTE = 300
ASSET_SCHEMA = 1


class Ctx:
    """Пути проекта; корень можно подменить (тесты, --root)."""

    def __init__(self, root):
        self.root = Path(root)
        self.banks = self.root / "assets" / "data"
        self.mat = self.root / "tool" / "materials"
        self.air = self.mat / "air_law"
        self.inventory = self.air / "inventory.json"
        self.topics = self.air / "topics.json"
        self.src_dir = self.air / "src"
        self.sum_dir = self.air / "summaries"
        self.ledger = self.air / "review_ledger.json"
        self.sources = self.mat / "sources.json"
        self.anchors = self.mat / "anchors"
        self.corpus = self.mat / "corpus"
        self.asset = self.root / "assets" / "materials" / "air_law.json"


# ---------------------------------------------------------------- ключ

_TAGS = re.compile(r"</?su[bp]\s*>", re.I)
_TAIL = re.compile(r"\s*/n\s*$", re.I)


def norm_cell(text):
    """Нормализация ячейки для отпечатка: NFC, без <sub>/<sup> и хвоста /n, пробелы, нижний регистр."""
    t = unicodedata.normalize("NFC", text or "")
    t = _TAGS.sub("", t)
    t = " ".join(t.split())
    t = _TAIL.sub("", t)
    return t.lower().strip()


def fingerprint(q_pl, correct_pl, wrong_pl):
    parts = [norm_cell(q_pl), norm_cell(correct_pl)] + sorted(norm_cell(w) for w in wrong_pl)
    return hashlib.sha1("\n".join(parts).encode("utf-8")).hexdigest()[:8]


def question_key(q):
    a = q["a"]
    c = q.get("correct", 0)
    correct = a[c]["pl"]
    wrong = [x["pl"] for i, x in enumerate(a) if i != c]
    return "%s#%s" % (q["number"], fingerprint(q["q"]["pl"], correct, wrong))


# ---------------------------------------------------------------- ввод-вывод

def read_json(path, default=None):
    p = Path(path)
    if not p.exists():
        return default
    with open(p, encoding="utf-8") as f:
        return json.load(f)


def write_text(path, text):
    p = Path(path)
    p.parent.mkdir(parents=True, exist_ok=True)
    with open(p, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def dump_lines(items):
    """Список объектов: по одному на строку, ключи в порядке вставки."""
    if not items:
        return "[]\n"
    body = ",\n".join(json.dumps(i, ensure_ascii=False, separators=(",", ":")) for i in items)
    return "[\n" + body + "\n]\n"


def dump_pretty(obj):
    return json.dumps(obj, ensure_ascii=False, indent=2, sort_keys=False) + "\n"


def dump_compact(obj):
    return json.dumps(obj, ensure_ascii=False, sort_keys=True, separators=(",", ":")) + "\n"


def load_bank_questions(ctx):
    """{licence: [question]} для предмета air_law."""
    out = {}
    for lic in LICENCES:
        data = read_json(ctx.banks / ("bank_%s.json" % lic))
        if data is None:
            continue
        out[lic] = [q for q in data["questions"] if q.get("subject") == SUBJECT]
    return out


# ---------------------------------------------------------------- инвентаризация

def is_raw_mixed(licence, q):
    """PPL(A)/(H), где разделение PL/EN не удалось: en = null у вопроса."""
    return licence in ("ppla", "pplh") and q["q"].get("en") is None


def build_inventory(ctx):
    banks = load_bank_questions(ctx)
    entries = {}
    for lic in LICENCES:
        for q in banks.get(lic, []):
            key = question_key(q)
            e = entries.get(key)
            if e is None:
                c = q.get("correct", 0)
                a_pl = [q["a"][c]["pl"]] + [x["pl"] for i, x in enumerate(q["a"]) if i != c]
                e = entries[key] = {
                    "key": key, "number": q["number"], "topicCode": q["topic"],
                    "licences": [], "ids": {}, "rawMixed": False,
                    "q_pl": q["q"]["pl"], "a_pl": a_pl,
                }
            if lic in e["ids"]:
                raise SystemExit("в банке %s два вопроса с ключом %s: %s и %s" % (lic, key, e["ids"][lic], q["id"]))
            e["licences"].append(lic)
            e["ids"][lic] = q["id"]
            e["rawMixed"] = e["rawMixed"] or is_raw_mixed(lic, q)
    return [entries[k] for k in sorted(entries)]


def cmd_inventory(ctx, args):
    inv = build_inventory(ctx)
    write_text(ctx.inventory, dump_lines(inv))
    total = sum(len(e["ids"]) for e in inv)
    print("inventory: %d ключей, %d вопросов -> %s" % (len(inv), total, ctx.inventory))
    if args.stats:
        print_stats(ctx, inv)
    return 0


def print_stats(ctx, inv):
    banks = load_bank_questions(ctx)
    print("\nВопросов air_law по лицензиям:")
    for lic in LICENCES:
        qs = banks.get(lic, [])
        tc = {}
        for q in qs:
            tc[q["topic"]] = tc.get(q["topic"], 0) + 1
        print("  %-5s %4d  %s" % (lic, len(qs), dict(sorted(tc.items()))))
    print("  всего %d" % sum(len(v) for v in banks.values()))
    print("Уникальных ключей: %d" % len(inv))
    by_n = {}
    for e in inv:
        by_n[len(e["licences"])] = by_n.get(len(e["licences"]), 0) + 1
    print("Ключей в N банках:", {n: by_n[n] for n in sorted(by_n)})
    pair = {}
    for e in inv:
        ls = e["licences"]
        for i in range(len(ls)):
            for j in range(i + 1, len(ls)):
                pair[(ls[i], ls[j])] = pair.get((ls[i], ls[j]), 0) + 1
    for (a, b), n in sorted(pair.items()):
        print("  пересечение %s & %s: %d" % (a, b, n))
    for lic in LICENCES:
        own = sum(1 for e in inv if e["licences"] == [lic])
        print("  только в %s: %d" % (lic, own))
    per_num = {}
    for e in inv:
        per_num.setdefault(e["number"], []).append(e)
    multi = {n: v for n, v in per_num.items() if len(v) > 1}
    print("NUMER всего: %d, с несколькими ключами: %d (ключей в них: %d)" % (
        len(per_num), len(multi), sum(len(v) for v in multi.values())))
    raw = [e for e in inv if e["rawMixed"]]
    print("rawMixed ключей: %d" % len(raw))
    twins_loose, twins_strict = 0, 0
    for e in raw:
        qn = norm_cell(e["q_pl"])
        loose = strict = False
        for t in per_num[e["number"]]:
            if t["key"] == e["key"] or t["rawMixed"]:
                continue
            tq = norm_cell(t["q_pl"])
            if tq and qn.startswith(tq[:40]):
                loose = True
                ta = norm_cell(t["a_pl"][0])
                if ta and norm_cell(e["a_pl"][0]).startswith(ta[:30]):
                    strict = True
        twins_loose += loose
        twins_strict += strict
    print("  из них с двойником того же NUMER (начало вопроса совпало): %d; и начало верного ответа совпало: %d" % (
        twins_loose, twins_strict))
    no_en = 0
    for e in inv:
        has_en = False
        for lic, qid in e["ids"].items():
            q = next(x for x in banks[lic] if x["id"] == qid)
            if q["q"].get("en"):
                has_en = True
        no_en += not has_en
    print("Ключей без английского текста в любом банке: %d" % no_en)
    only_ppl_no_en = sum(1 for e in inv if e["rawMixed"])
    print("Ключей, где PPL-вариант без разделённого EN (rawMixed): %d" % only_ppl_no_en)
    portions = -(-len(inv) // 40)
    print("Порций по 40 ключей: %d" % portions)
    print("Размер inventory.json: %d байт" % (ctx.inventory.stat().st_size if ctx.inventory.exists() else 0))


# ---------------------------------------------------------------- материалы: чтение

def load_src_records(ctx):
    """[(file_stem, record)] из src/*.json (порядок по имени файла)."""
    out = []
    if ctx.src_dir.is_dir():
        for p in sorted(ctx.src_dir.glob("*.json")):
            data = read_json(p, [])
            if not isinstance(data, list):
                raise SystemExit("%s: ожидается список записей" % p)
            out.extend((p.stem, r) for r in data)
    return out


def load_summaries(ctx):
    """[(topic_file_stem, path, data)]."""
    out = []
    if ctx.sum_dir.is_dir():
        for p in sorted(ctx.sum_dir.glob("*.json")):
            out.append((p.stem, p, read_json(p, {})))
    return out


def load_topics(ctx):
    data = read_json(ctx.topics)
    if data is None:
        return None
    return data["topics"] if isinstance(data, dict) else data


def load_sources(ctx):
    data = read_json(ctx.sources, [])
    if isinstance(data, dict):
        data = data.get("sources", [])
    return {s["id"]: s for s in data}


def src_available(src):
    """Источник скачан и есть в корпусе (status по умолчанию available)."""
    return src.get("status", "available") != "unavailable"


def src_quotable(src):
    """Цитаты хранятся только для источников с allowQuote (по умолчанию нет у aip/easa/icao/itu)."""
    default = src.get("kind") not in ("aip", "easa", "icao", "itu")
    return bool(src.get("allowQuote", default))


def refs_usable(rec, sources):
    """Все ссылки записи указывают на доступные источники (иначе запись не выдаётся)."""
    return all(r.get("src") in sources and src_available(sources[r["src"]]) for r in rec.get("refs") or [])


def content_sha(rec, kind):
    """Хеш проверяемого содержимого. Любая правка меняет его и снимает запись с выдачи."""
    if kind == "section":
        view = {k: rec.get(k) for k in ("heading", "body", "refs", "questionKeys")}
    else:
        view = {k: rec.get(k) for k in ("text", "refs", "disputeNote", "sameAs", "basis", "basisNote")}
    s = json.dumps(view, ensure_ascii=False, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(s.encode("utf-8")).hexdigest()[:16]


def is_published(rec, kind, ledger, id_):
    """Статус выдаваемый и хеш в журнале совпадает с текущим содержимым."""
    if rec.get("status") not in PUBLISHED:
        return False
    entry = ledger.get(id_)
    return (bool(entry) and entry.get("textSha") == content_sha(rec, kind)
            and entry.get("verdict") == VERDICT_STATUS_OK[rec["status"]])


# ---------------------------------------------------------------- локаторы и якоря

# номер: 67, 67fa, 156zd, 87[1], 87[1a] (надстрочный индекс в квадратных скобках, как в anchors)
_N = r"\d+(?:[a-z]{1,3}|\[\d+[a-z]{0,3}\][a-z]{0,3})?"
_L = r"\d+[a-z]?(?:\.\d+[a-z]?)*"  # номер строки таблицы / позиции: 1, 1.1, 3.14
# załącznik 6, załącznik 6 tabela 2, załącznik 6 tabela 2 część I, załącznik 6 tabela 2 część I pkt 3.14
LOC_STATUTE = re.compile(r"^((art\. |§ )%s( ust\. %s)?( pkt %s( lit\. [a-z]{1,2})?)?|załącznik \d+[a-z]?( tabela \d+)?( część [IVX]+[a-z]?)?( pkt %s)?)$"
                         % (_N, _N, _N, _L))
LOC_CONVENTION = re.compile(r"^(art\. %s( ust\. %s)?( lit\. [a-z])?|załącznik \d+( pkt \d+(\.\d+)*)?)$" % (_N, _N), re.I)
# правила: FCL.205.A, SERA.5005(b)(1)(i), MED.A.030, ORA.AeMC.215, M.A.201; Part 21/145/66/147: 21.A.3A, 145.A.30
LOC_EUPARA = re.compile(r"^([A-Z][A-Za-z]*([/-][A-Z][A-Za-z]*)?|\d{2,3})(\.[A-Za-z0-9]+)+(\([a-z0-9]+\))*$")
LOC_EUART = re.compile(r"^art\. %s( ust\. %s)?( pkt %s)?$" % (_N, _N, _N))
# приложения: załącznik, załącznik I, dodatek 3, załącznik I dodatek 3, любое из них + pkt L
LOC_EUANNEX = re.compile(r"^(?=załącznik|dodatek)(załącznik( [IVXLC]+)?)?( ?dodatek \d+)?( sekcja [IVX]+(\([a-z0-9]+\))*)?( pkt %s)?$" % _L)
# AIP Polska: ENR 1.2, ENR 1.2 pkt 3.1, GEN 2.2 CBA (skrót), ENR 5.2.1 TSA (definicja), ENR 1.4 klasa C
LOC_AIP = re.compile(r"^(GEN|ENR|AD) \d+(\.\d+)*( pkt \d+(\.\d+)*| klasa [A-G]| przypis \*{1,4}| [A-Z0-9][A-Z0-9/&.\-]{0,9}( \d{1,2})?)?$")
LOC_EASA = re.compile(r"^((AMC|GM|CS)\d* )?[A-Z][A-Za-z]*([/-][A-Z][A-Za-z]*)?(\.[A-Za-z0-9]+)+(\([a-z0-9]+\))*( \(\d\) SECTION \d+[A-Z]?| SECTION \d+[A-Z]?)?$")
# Article 2, Article 2(12), Article 2(129a), GM1 Article 2(12), Appendix 4, Appendix 1 pkt 1.2.1
# ICAO (Doc 7300 / Doc 4444): Article 5, Article 3 bis, Article 5(a); Chapter 5, Appendix 2, pkt 5.4.2.1, def Aerodrome control service
LOC_ICAO = re.compile(r"^(Article \d+( bis| ter| quater)?(\([a-z]\))?|Chapter \d+|Appendix \d+|pkt \d+(\.\d+)+|def [A-Z][^\n]{0,90})$")
# ITU Radio Regulations: Appendix 18, Appendix 18 channel 06, Appendix 18 channel AIS1, Appendix 18 note f
LOC_ITU = re.compile(r"^Appendix \d+( channel (\d{2,4}|AIS\d|ASM\d)| note [a-z]{1,2})?$")
# Polish ICAO Annex texts (Dz. Urz. ULC): rozdział 3, 3.1.2, 3.1.2 lit. a, definicja Faza alarmu, dodatek 1 pkt 2.1 lit. a,
# dodatek pkt 2.1 (an unnumbered Appendix), załącznik A, załącznik A pkt 2.1, załącznik A sekcja 19a, tabela 3-1, tabela A4-1,
# dodatek A pkt 2 (Annex 10), tabela A5-1-1, rysunek 5-25A (Doc 4444), dodatek 2 pole 7 (Doc 4444 flight plan item)
LOC_ICAO_PL = re.compile(r"^(obwieszczenie|przedmowa|rozdział \d+|\d+(\.\d+[a-z]?)+( lit\. [a-z])?|definicja [A-ZĄĆĘŁŃÓŚŹŻ][^\n]{0,120}|"
                         r"(dodatek( \d+| [A-Z])?|załącznik [A-Z])( (pkt|sekcja) %s( lit\. [a-z])?)?|"
                         r"tabela (?:[A-Z]\d{0,2}-)?\d{1,2}(?:[-.]\d{1,2}){0,2}|rysunek (?:A?\d{1,2}-)\d{1,3}[A-Z]?|dodatek 2 pole \d{1,2})$" % _L)
LOC_EASA_ART = re.compile(r"^((GM\d* )?Article \d+[a-z]?|Annex [IVX]+)(\([0-9a-z]+\))*$")
LOC_EASA_APP = re.compile(r"^Appendix \d+( pkt %s| to (AMC|GM)\d* [A-Z][A-Za-z]*(\.[A-Za-z0-9]+)+(\([a-z0-9]+\))*)?$" % _L)
FUTURE_MARK = "PRZYSZŁA REDAKCJA"


def loc_valid(kind, loc):
    if kind == "statute":
        return bool(LOC_STATUTE.match(loc))
    if kind == "convention":
        return bool(LOC_CONVENTION.match(loc))
    if kind == "eu_reg":
        return bool(LOC_EUART.match(loc) or LOC_EUPARA.match(loc) or LOC_EUANNEX.match(loc))
    if kind == "aip":
        return bool(LOC_AIP.match(loc))
    if kind == "icao":
        return bool(LOC_ICAO.match(loc))
    if kind == "itu":
        return bool(LOC_ITU.match(loc))
    if kind == "icao_pl":
        return bool(LOC_ICAO_PL.match(loc))
    if kind == "easa":
        return bool(LOC_EASA.match(loc) or LOC_EASA_ART.match(loc) or LOC_EASA_APP.match(loc))
    return False


def loc_parents(loc):
    """Родительские локаторы от ближнего к дальнему: 'art. 5 ust. 2 pkt 3' -> ['art. 5 ust. 2', 'art. 5']."""
    out = []
    cur = loc
    mi = re.match(r"^pkt (\d+(?:\.\d+)+)$", loc)
    if mi:   # ICAO Doc 4444: pkt 5.4.2.1 -> pkt 5.4.2 -> pkt 5.4 -> Chapter 5
        parts = mi.group(1).split(".")
        return ["pkt " + ".".join(parts[:n]) for n in range(len(parts) - 1, 1, -1)] + ["Chapter " + parts[0]]
    ms = re.match(r"^((?:AMC|GM)\d* .+?)(?: \(\d\))? SECTION \d+[A-Z]?$", loc)
    if ms:
        return [ms.group(1)] + loc_parents(ms.group(1))   # skill-test section of an AMC: its parent is the AMC block
    mi = re.match(r"^(Appendix \d+) (?:channel|note) \S+$", loc)
    if mi:
        return [mi.group(1)]
    if re.match(r"^def [A-Z]", loc):
        return ["Chapter 1"]
    mn = re.match(r"^(\d+(?:\.\d+[a-z]?)+)( lit\. [a-z])?$", loc)
    if mn:   # Polish ICAO Annex: 3.1.2 lit. a -> 3.1.2 -> 3.1 -> rozdział 3
        parts = mn.group(1).split(".")
        return ([mn.group(1)] if mn.group(2) else []) + \
            [".".join(parts[:n]) for n in range(len(parts) - 1, 1, -1)] + ["rozdział " + parts[0]]
    if loc.startswith("definicja "):
        return ["rozdział 1"]
    if re.match(r"^dodatek 2 pole \d+$", loc):
        return ["dodatek 2 pkt 2", "dodatek 2"]   # Doc 4444, item of the flight plan instructions
    if re.match(r"^Appendix \d+ to (?:AMC|GM)", loc):
        return []   # EASA "Appendix 1 to AMC1 SERA.6005(c)" is a block of its own
    mt = re.match(r"^((?:GEN|ENR|AD) \d+(?:\.\d+)*) (?:klasa [A-G]|przypis \*{1,4}|[A-Z0-9][A-Z0-9/&.\-]{0,9}(?: \d{1,2})?)$", loc)
    if mt:
        return [mt.group(1)]   # AIP abbreviation / definition / airspace class entry: its parent is the section
    ma = re.match(r"^((?:GEN|ENR|AD) \d+(?:\.\d+)*) pkt (\d+(?:\.\d+)*)$", loc)
    if ma:   # AIP: every dotted level is an anchor (pkt 3.1.2 -> pkt 3.1 -> pkt 3 -> section)
        parts = ma.group(2).split(".")
        return ["%s pkt %s" % (ma.group(1), ".".join(parts[:n])) for n in range(len(parts) - 1, 0, -1)] + [ma.group(1)]
    while True:
        m2 = re.match(r"^(.+)(\([a-z0-9]+\))$", cur)
        if m2:
            cur = m2.group(1)
        else:
            m = re.match(r"^(.*\S)\s+(pkt|ust\.|dodatek|część|tabela|sekcja|lit\.)\s+\S+$", cur)
            if not m:
                break
            cur = m.group(1)
        out.append(cur)
    return out


def norm_quote(text):
    t = unicodedata.normalize("NFC", text or "")
    for ch in "\u201c\u201d\u201e\u00ab\u00bb\u201f":
        t = t.replace(ch, '"')
    for ch in "\u2018\u2019\u201a\u2032":
        t = t.replace(ch, "'")
    for ch in "\u2010\u2011\u2012\u2013\u2014\u2212":
        t = t.replace(ch, "-")
    t = t.replace("\u00a0", " ").replace("\u00ad", "")
    return " ".join(t.split())


class AnchorStore:
    def __init__(self, ctx, use_corpus):
        self.ctx = ctx
        self.use_corpus = use_corpus
        self._anchors = {}
        self._corpus = {}

    def anchors(self, src):
        if src not in self._anchors:
            self._anchors[src] = read_json(self.ctx.anchors / ("%s.json" % src))
        return self._anchors[src]

    def corpus(self, src):
        if src not in self._corpus:
            p = self.ctx.corpus / ("%s.txt" % src)
            self._corpus[src] = p.read_text(encoding="utf-8") if p.exists() else None
        return self._corpus[src]

    def corpus_in_sync(self, src):
        """sha256 корпуса совпадает с textSha якорей (None, если проверять нечем)."""
        a = self.anchors(src)
        text = self.corpus(src)
        if a is None or text is None:
            return None
        return hashlib.sha256(text.encode("utf-8")).hexdigest() == a.get("textSha")

    def masked_text(self, src, s, e):
        """corpus[s:e] with the not-yet-binding (future-edition) ranges listed in anchors["future"] replaced by U+FFFC,
        so that a quote can match only text in force (also when it does not contain the marker itself)."""
        text = self.corpus(src)
        a = self.anchors(src) or {}
        out = []
        pos = s
        for fs, fe in sorted(a.get("future", [])):
            if fe <= s or fs >= e:
                continue
            fs, fe = max(fs, s), min(fe, e)
            if fs > pos:
                out.append(text[pos:fs])
            out.append("\ufffc")
            pos = fe
        out.append(text[pos:e])
        return "".join(out)

    def descendant_with_quote(self, src, loc, quote):
        """Самый узкий дочерний якорь loc, целиком содержащий quote (или None)."""
        a = self.anchors(src)
        text = self.corpus(src)
        if a is None or text is None:
            return None
        q = norm_quote(quote)
        best = None
        for k, (s, e) in a.get("anchors", {}).items():
            if k != loc and (k.startswith(loc + " ") or k.startswith(loc + "(")) and (best is None or e - s < best[1]):
                if q in norm_quote(self.masked_text(src, s, e)):
                    best = (k, e - s)
        return best[0] if best else None

    def anchor_text(self, src, loc):
        """Нормализованный текст якоря или None, если корпуса нет."""
        a = self.anchors(src)
        text = self.corpus(src)
        if a is None or text is None or loc not in a.get("anchors", {}):
            return None
        s, e = a["anchors"][loc]
        return norm_quote(self.masked_text(src, s, e))


# ---------------------------------------------------------------- предложения

_ABBR = ("art", "ust", "pkt", "np", "tzw", "itp", "itd", "poz", "nr", "lit", "ok", "godz", "tj", "tzn",
         "im", "r", "z", "dz", "u", "ww", "zm", "rozdz", "str", "ppl", "min", "max", "sp", "oraz", "wg", "m.in")
_ABBR_RE = re.compile(r"\b(%s)\." % "|".join(re.escape(a) for a in _ABBR), re.I)


def count_sentences(text):
    t = _ABBR_RE.sub(lambda m: m.group(1) + "\u0001", text.strip())
    t = re.sub(r"(\d)\.(\d)", "\\1\u0001\\2", t)
    parts = re.split(r"[.!?…]+[\"')»\]]*(?:\s+|$)", t)
    return len([p for p in parts if p.strip()])


# ---------------------------------------------------------------- валидатор

class Report:
    def __init__(self):
        self.errors = []
        self.warnings = []
        self.info = []

    def err(self, m):
        self.errors.append(m)

    def warn(self, m):
        self.warnings.append(m)


def check_refs(rep, label, rec, sources, store, status):
    refs = rec.get("refs") or []
    published = status in PUBLISHED
    has_basis = status == "unverified" and rec.get("basis") in BASES
    strict = published or has_basis       # unverified+basis: любые указанные refs проверяются как у опубликованных
    if published and not refs:
        rep.err("%s: у %s нет refs" % (label, status))
    for r in refs:
        src, loc = r.get("src"), r.get("loc") or ""
        quote = r.get("quote")
        if quote is not None and len(quote) > MAX_QUOTE:
            rep.err("%s: quote длиннее %d символов (%s)" % (label, MAX_QUOTE, loc))
        ok = True
        if strict:
            if src not in sources:
                rep.err("%s: src %r нет в sources.json" % (label, src))
                continue
            if not src_available(sources[src]):
                rep.err("%s: источник %s недоступен (status=unavailable), ссылка невозможна" % (label, src))
                continue
            if not loc_valid(sources[src].get("kind"), loc):
                rep.err("%s: loc %r не проходит грамматику вида %s" % (label, loc, sources[src].get("kind")))
                continue
            a = store.anchors(src)
            if a is None:
                rep.err("%s: нет tool/materials/anchors/%s.json" % (label, src))
                continue
            anchors = a.get("anchors", {})
            if loc not in anchors:
                rep.err("%s: якоря %r нет в anchors/%s.json" % (label, loc, src))
                continue
            for par in loc_parents(loc):
                if par not in anchors:
                    rep.err("%s: у якоря %r нет родительского %r в anchors/%s.json" % (label, loc, par, src))
                    ok = False
        if published and src in sources and src_quotable(sources[src]) and not quote:
            rep.err("%s: у источника %s цитаты разрешены, у verified/disputed quote обязателен (%s)" % (label, src, loc))
        if quote and src in sources and not src_quotable(sources[src]):
            rep.err("%s: у источника %s цитаты запрещены (allowQuote=false), quote не хранится" % (label, src))
            continue
        if quote and FUTURE_MARK in quote:
            rep.err("%s: quote содержит маркер будущей редакции (%s), цитировать можно только действующий текст" % (
                label, FUTURE_MARK))
            continue
        if (strict or status == "draft") and quote and ok and store.use_corpus and src in sources \
                and src_available(sources[src]):
            if store.corpus_in_sync(src) is False:
                rep.err("%s: textSha в anchors/%s.json не совпадает с corpus/%s.txt (пересоберите якоря: extract_corpus.py)" % (
                    label, src, src))
                continue
            at = store.anchor_text(src, loc)
            if at is None:
                if strict:
                    rep.err("%s: нет корпуса/якоря для проверки quote (%s, %s)" % (label, src, loc))
            elif norm_quote(quote) not in at:
                rep.err("%s: quote не найден в тексте якоря %s %s" % (label, src, loc))
            else:
                msec = re.match(r"^((?:GEN|ENR|AD) \d+(?:\.\d+)*)\b", loc)
                lang = ((store.anchors(src) or {}).get("langs") or {}).get(msec.group(1)) if msec else None
                if lang and lang != "pl":
                    rep.warn("%s: раздел %s источника %s не только польский (%s): цитируйте польскую колонку, для ENR 1.1 — "
                             "английский текст есть единственный" % (label, msec.group(1), src, lang))
                child = store.descendant_with_quote(src, loc, quote)
                if child:
                    rep.warn("%s: quote целиком лежит в более точном пункте %r, укажите его вместо %r" % (label, child, loc))


def validate_all(ctx, no_corpus=False, check_asset=False):
    rep = Report()
    inv_list = read_json(ctx.inventory)
    if inv_list is None:
        rep.err("нет %s: сначала `materials.py inventory`" % ctx.inventory)
        return rep
    inv = {e["key"]: e for e in inv_list}

    # 1. покрытие банков инвентарём
    fresh = {}
    for lic, qs in load_bank_questions(ctx).items():
        for q in qs:
            fresh[(lic, q["id"])] = question_key(q)
    have = {}
    for e in inv_list:
        for lic, qid in e["ids"].items():
            have[(lic, qid)] = e["key"]
    for k, key in sorted(fresh.items()):
        if k not in have:
            rep.err("вопрос %s/%s не покрыт inventory.json" % k)
        elif have[k] != key:
            rep.err("вопрос %s/%s: ключ в inventory.json устарел (%s != %s)" % (k + (have[k], key)))
    for k in sorted(set(have) - set(fresh)):
        rep.err("inventory.json: вопроса %s/%s нет в банках (устарел)" % k)

    sources = load_sources(ctx)
    ledger = read_json(ctx.ledger, {})
    store = AnchorStore(ctx, use_corpus=not no_corpus)
    if no_corpus:
        rep.warn("--no-corpus: проверка quote по корпусу пропущена")

    # 2-9. объяснения
    seen = {}
    records = load_src_records(ctx)
    basis_keys = {r.get("key"): r.get("basis") in BASES and r.get("status") == "unverified"
                  and not r.get("sameAs") for _, r in records if r.get("key")}
    new_without_record = set(inv)
    for stem, r in records:
        key = r.get("key")
        label = "src/%s.json %s" % (stem, key)
        status = r.get("status")
        if status not in STATUSES:
            rep.err("%s: статус %r вне списка" % (label, status))
            continue
        if key in seen:
            rep.err("%s: ключ уже есть в src/%s.json" % (label, seen[key]))
        seen[key] = stem
        if status == "retired":
            continue
        if key not in inv:
            cands = sorted(k for k in inv if k.split("#")[0] == str(key).split("#")[0])
            rep.err("%s: сирота (ключа нет в инвентаре)%s" % (
                label, "; кандидаты на перепроверку (тот же NUMER): " + ", ".join(cands) if cands else ""))
            continue
        new_without_record.discard(key)
        same = r.get("sameAs")
        if same and (r.get("basis") is not None or r.get("basisNote") is not None):
            rep.err("%s: sameAs нельзя сочетать с basis/basisNote" % label)
        if same:
            if same not in inv:
                rep.err("%s: sameAs на несуществующий ключ %s" % (label, same))
            elif same == key:
                rep.err("%s: sameAs указывает на себя" % label)
        else:
            basis = r.get("basis")
            if basis is not None or r.get("basisNote") is not None:
                if status != "unverified":
                    rep.err("%s: поля basis/basisNote допустимы только у unverified (статус %s)" % (label, status))
                elif basis not in BASES:
                    rep.err("%s: basis %r вне %s" % (label, basis, list(BASES)))
                elif not (r.get("basisNote") or "").strip():
                    rep.err("%s: у unverified с basis нет basisNote (причина)" % label)
                elif basis == "outdated":
                    if (r.get("text") or "").strip():
                        rep.err("%s: у basis=outdated text должен быть пустым (объяснения нет)" % label)
                    if len(r.get("basisNote")) > MAX_OUTDATED_NOTE:
                        rep.err("%s: basisNote длиннее %d символов" % (label, MAX_OUTDATED_NOTE))
            text = r.get("text") or ""
            for fld, val in (("text", text), ("basisNote", r.get("basisNote") or "")):
                if INTERNAL_PREFIX.match(val):
                    rep.err("%s: %s начинается со служебного префикса вида «xxx-yyy:» (%r); в ассет попадает как есть, уберите" % (
                        label, fld, val[:30]))
            if status in ("draft",) + PUBLISHED or (status == "unverified" and basis == "no-source") \
                    or (status == "unverified" and basis == "aip-missing" and text.strip()):
                n = count_sentences(text)
                if not text.strip():
                    rep.err("%s: пустой text" % label)
                elif n < 2 or n > 4:
                    rep.err("%s: %d предложений в тексте (нужно 2-4)" % (label, n))
                if len(text) > MAX_TEXT:
                    rep.err("%s: text длиннее %d символов" % (label, MAX_TEXT))
            check_refs(rep, label, r, sources, store, status)
        if status == "disputed" and not (r.get("disputeNote") or "").strip():
            rep.err("%s: у disputed нет disputeNote" % label)
        if status in PUBLISHED:
            entry = ledger.get(key)
            if not entry:
                rep.err("%s: нет записи в review_ledger.json" % label)
            elif entry.get("textSha") != content_sha(r, "explanation"):
                rep.err("%s: textSha в журнале не совпадает с текущим текстом (нужна повторная проверка)" % label)
            elif entry.get("verdict") != VERDICT_STATUS_OK[status]:
                rep.err("%s: статус %s не соответствует вердикту %s" % (label, status, entry.get("verdict")))
    for k, stem in seen.items():
        r = next(x for s, x in records if x.get("key") == k)
        if r.get("sameAs") in seen and r.get("sameAs") in inv:
            tgt = next(x for s, x in records if x.get("key") == r["sameAs"])
            if tgt.get("sameAs"):
                rep.err("%s: sameAs указывает на запись, которая сама sameAs" % k)

    # конспекты
    topics = load_topics(ctx)
    sections_by_topic = {}
    section_ids = {}
    for stem, path, data in load_summaries(ctx):
        label = "summaries/%s.json" % stem
        tid = data.get("topic")
        if tid != stem:
            rep.err("%s: поле topic=%r не совпадает с именем файла" % (label, tid))
        if topics is not None and tid not in {t["id"] for t in topics}:
            rep.err("%s: подтемы %r нет в topics.json" % (label, tid))
        for s in data.get("sections", []):
            sid = s.get("id")
            slabel = "%s %s" % (label, sid)
            status = s.get("status", data.get("status"))
            if status not in STATUSES:
                rep.err("%s: статус %r вне списка" % (slabel, status))
                continue
            if sid in section_ids:
                rep.err("%s: id раздела повторяется" % slabel)
            section_ids[sid] = stem
            if status == "retired":
                continue
            for qk in s.get("questionKeys", []):
                if qk not in inv:
                    rep.err("%s: questionKeys содержит ключ вне инвентаря: %s" % (slabel, qk))
            check_refs(rep, slabel, s, sources, store, status)
            if status in PUBLISHED:
                entry = ledger.get(sid)
                if not entry:
                    rep.err("%s: нет записи в review_ledger.json" % slabel)
                elif entry.get("textSha") != content_sha(s, "section"):
                    rep.err("%s: textSha в журнале не совпадает с текущим текстом" % slabel)
                elif entry.get("verdict") != VERDICT_STATUS_OK[status]:
                    rep.err("%s: статус %s не соответствует вердикту %s" % (slabel, status, entry.get("verdict")))
                sections_by_topic.setdefault(tid, []).append(s)
            if status == "disputed" and not (s.get("disputeNote") or "").strip():
                rep.err("%s: у disputed нет disputeNote" % slabel)

    # 10-11. подтемы
    if topics is not None:
        owner = {}
        ids = set()
        for t in topics:
            if t["id"] in ids:
                rep.err("topics.json: подтема %s повторяется" % t["id"])
            ids.add(t["id"])
            for k in t.get("order", []):
                if k not in inv:
                    rep.err("topics.json %s: ключа нет в инвентаре: %s" % (t["id"], k))
                if k in owner and owner[k] != t["id"]:
                    rep.err("topics.json: ключ %s в двух подтемах (%s, %s)" % (k, owner[k], t["id"]))
                elif k in owner:
                    rep.err("topics.json %s: ключ %s повторяется" % (t["id"], k))
                owner.setdefault(k, t["id"])
        missing = sorted(set(inv) - set(owner))
        if missing:
            rep.err("topics.json: %d ключей инвентаря не назначены ни в одну подтему (например %s)" % (
                len(missing), ", ".join(missing[:3])))
        for t in topics:
            if t.get("complete"):
                covered = set()
                for s in sections_by_topic.get(t["id"], []):
                    covered.update(s.get("questionKeys", []))
                exempt = {k for k, ok in basis_keys.items() if ok}   # только записи unverified с допустимым basis
                lost = [k for k in t.get("order", []) if k not in covered and k not in exempt]
                if lost:
                    rep.err("подтема %s complete, но %d ключей не входят в questionKeys проверенных разделов (например %s)" % (
                        t["id"], len(lost), lost[0]))

    rep.info.append("ключей в инвентаре: %d, без записи: %d, записей: %d" % (len(inv), len(new_without_record), len(records)))

    # nothing marked for the owner may reach the asset (the flags live in terms_note / internal_note only)
    try:
        flagged = [t for t in asset_strings(json.loads(build_asset_text(ctx))) if OWNER_FLAG in t]
    except SystemExit:
        flagged = []
    for t in flagged[:5]:
        rep.err("в ассет попала пометка для владельца «%s»: %s" % (OWNER_FLAG, t[:80]))

    # asset
    if check_asset:
        try:
            expected = build_asset_text(ctx)
        except SystemExit as e:
            rep.err("build: %s" % e)
            expected = None
        if expected is not None:
            if not ctx.asset.exists():
                rep.err("нет %s: выполните `materials.py build`" % ctx.asset)
            elif ctx.asset.read_bytes() != expected.encode("utf-8"):
                rep.err("%s не совпадает с результатом build" % ctx.asset)
    return rep


def cmd_validate(ctx, args):
    rep = validate_all(ctx, no_corpus=args.no_corpus, check_asset=args.check)
    for m in rep.info:
        print("info:", m)
    for m in rep.warnings:
        print("warning:", m)
    for m in rep.errors:
        print("ERROR:", m)
    print("validate: %d ошибок, %d предупреждений" % (len(rep.errors), len(rep.warnings)))
    return 1 if rep.errors else 0


# ---------------------------------------------------------------- сборка ассета

OWNER_FLAG = "ПРОВЕРИТЬ"


def clean_refs(refs):
    """Refs of the asset: only src and loc (no quotes); identical (src, loc) pairs of one list collapse into the first one."""
    out = []
    seen = set()
    for r in refs or []:
        pair = (r["src"], r["loc"])
        if pair not in seen:
            seen.add(pair)
            out.append({"src": r["src"], "loc": r["loc"]})
    return out


def capitalize_note(note):
    """The note of an outdated question starts with a capital letter (the sources write it in lower case)."""
    note = (note or "").strip()
    return note[:1].upper() + note[1:] if note[:1].islower() else note


def asset_strings(obj):
    if isinstance(obj, str):
        yield obj
    elif isinstance(obj, dict):
        for k, v in obj.items():
            yield k
            yield from asset_strings(v)
    elif isinstance(obj, list):
        for v in obj:
            yield from asset_strings(v)


def build_asset_text(ctx):
    inv_list = read_json(ctx.inventory)
    if inv_list is None:
        raise SystemExit("нет %s: сначала `materials.py inventory`" % ctx.inventory)
    ledger = read_json(ctx.ledger, {})
    sources = load_sources(ctx)
    topics = load_topics(ctx) or []

    explanations = {}
    records = {r["key"]: r for _, r in load_src_records(ctx) if r.get("key")}
    alias = {}
    for key, r in sorted(records.items()):
        if not is_published(r, "explanation", ledger, key) or not refs_usable(r, sources):
            continue
        if r.get("sameAs"):
            alias[key] = r["sameAs"]
            continue
        explanations[key] = {
            "status": r["status"], "text": r.get("text") or "",
            "refs": clean_refs(r.get("refs")), "disputeNote": r.get("disputeNote") or None,
        }
    alias = {k: v for k, v in alias.items() if v in explanations}
    outdated = {}
    for key, r in sorted(records.items()):
        if r.get("status") == "unverified" and r.get("basis") == "outdated" and not r.get("sameAs") \
                and not (r.get("text") or "").strip() and (r.get("basisNote") or "").strip() \
                and len(r["basisNote"]) <= MAX_OUTDATED_NOTE:
            outdated[key] = {"note": capitalize_note(r["basisNote"])}

    sections_by_topic = {}
    for stem, _, data in load_summaries(ctx):
        for s in data.get("sections", []):
            st = s.get("status", data.get("status"))
            probe = dict(s, status=st)
            if is_published(probe, "section", ledger, s.get("id")) and refs_usable(s, sources):
                sections_by_topic.setdefault(data.get("topic"), []).append({
                    "id": s["id"], "heading": s.get("heading", ""), "body": s.get("body", []),
                    "refs": clean_refs(s.get("refs")), "questionKeys": s.get("questionKeys", []),
                })
    section_keys = {k for secs in sections_by_topic.values() for s in secs for k in s["questionKeys"]}

    out_topics = []
    for t in topics:
        order = [k for k in t.get("order", []) if k in explanations or k in alias]
        secs = sections_by_topic.get(t["id"], [])
        if not order and not secs:
            continue
        out_topics.append({"id": t["id"], "title": t["title"], "order": order, "summary": {"sections": secs}})

    links = {lic: {} for lic in LICENCES}
    for e in inv_list:
        key = e["key"]
        target = key if key in explanations else alias.get(key)
        if target is None and key in outdated:
            target = key
        if target is None and key in section_keys:
            target = key
        if target is None:
            continue
        for lic, qid in e["ids"].items():
            links[lic][qid] = target

    used = set()
    for r in explanations.values():
        used.update(x["src"] for x in r["refs"])
    for secs in sections_by_topic.values():
        for s in secs:
            used.update(x["src"] for x in s["refs"])
    # "Stan prawny na": the NEWEST legal state among the cited sources (legalState, else the date the text was fetched as the
    # current one). The oldest date would mislead: an unchanged old act (EU 376/2014, consolidated 2018) says nothing
    # about how fresh the materials are.
    fetched = sorted((sources[s].get("legalState") or sources[s].get("fetched")) for s in used
                     if s in sources and (sources[s].get("legalState") or sources[s].get("fetched")))
    asset = {
        "schema": ASSET_SCHEMA, "subject": SUBJECT, "lang": "pl",
        "legalStateAsOf": fetched[-1] if fetched else None,
        "sources": {s: {"title": sources[s].get("title_pl", s), "version": sources[s].get("version"),
                        "kind": sources[s].get("kind")} for s in sorted(used) if s in sources},
        "topics": out_topics, "explanations": explanations, "outdated": outdated,
        "links": {lic: links[lic] for lic in LICENCES},
    }
    body = dump_compact(asset)
    asset["materialsVersion"] = hashlib.sha1(body.encode("utf-8")).hexdigest()[:8]
    return dump_compact(asset)


def cmd_build(ctx, args):
    text = build_asset_text(ctx)
    write_text(ctx.asset, text)
    data = json.loads(text)
    nl = sum(len(v) for v in data["links"].values())
    print("build: %s (%d байт): объяснений %d, подтем %d, ссылок links %d, version %s" % (
        ctx.asset, len(text.encode("utf-8")), len(data["explanations"]), len(data["topics"]), nl, data["materialsVersion"]))
    return 0


# ---------------------------------------------------------------- apply-review

VERDICTS = ("PASS", "FIX", "DISPUTED")


def cmd_apply_review(ctx, args):
    path = Path(args.file)
    m = re.match(r"^(.+?)\.r(\d+)\.editor\.json$", path.name)
    if not m:
        print("ERROR: имя файла должно быть <порция>.r<K>.editor.json, получено %s" % path.name)
        return 1
    portion, rnd = m.group(1), int(m.group(2))
    verdicts = read_json(path)
    if not isinstance(verdicts, list):
        print("ERROR: вердикты должны быть списком")
        return 1

    # индекс записей: объяснения и разделы
    files = {}  # path -> (kind, data)
    index = {}  # id -> (path, rec, kind)
    for p in sorted(ctx.src_dir.glob("*.json")) if ctx.src_dir.is_dir() else []:
        data = read_json(p, [])
        files[p] = ("src", data)
        for r in data:
            if r.get("key"):
                index[r["key"]] = (p, r, "explanation")
    for stem, p, data in load_summaries(ctx):
        files[p] = ("summary", data)
        for s in data.get("sections", []):
            if s.get("id"):
                index[s["id"]] = (p, s, "section")

    errors = []
    seen = set()
    for v in verdicts:
        k = v.get("key")
        if v.get("verdict") not in VERDICTS:
            errors.append("%s: вердикт %r вне %s" % (k, v.get("verdict"), VERDICTS))
        if k not in index:
            errors.append("%s: записи с таким ключом/id нет" % k)
        if k in seen:
            errors.append("%s: вердикт повторяется" % k)
        seen.add(k)
    if errors:
        for e in errors:
            print("ERROR:", e)
        return 1

    ledger = read_json(ctx.ledger, {})
    today = args.date or datetime.date.today().isoformat()
    for v in verdicts:
        k, verdict = v["key"], v["verdict"]
        p, rec, kind = index[k]
        if kind == "explanation" and rec.get("basis"):
            print("warning: %s: запись с basis=%s (без нормативного источника): вердикт %s проигнорирован, статус и журнал не менялись" % (
                k, rec.get("basis"), verdict))
            continue
        if verdict == "PASS":
            new = "verified"
        elif verdict == "DISPUTED":
            if (rec.get("disputeNote") or "").strip():
                new = "disputed"
            else:
                new = "unverified"
                print("warning: %s: DISPUTED без disputeNote -> unverified" % k)
        else:
            new = "draft" if rnd < 2 else "unverified"
        rec["status"] = new
        ledger[k] = {"portion": portion, "round": rnd, "verdict": verdict,
                     "textSha": content_sha(rec, kind), "date": today}
        if v.get("note"):
            ledger[k]["note"] = v["note"]
        print("%s: %s -> %s" % (k, verdict, new))
    for p, (kind, data) in files.items():
        write_text(p, dump_lines(data) if kind == "src" else dump_pretty(data))
    write_text(ctx.ledger, json.dumps(ledger, ensure_ascii=False, indent=1, sort_keys=True) + "\n")
    return 0


# ---------------------------------------------------------------- report

def cmd_report(ctx, args):
    inv = {e["key"]: e for e in (read_json(ctx.inventory) or [])}
    ledger = read_json(ctx.ledger, {})
    records = load_src_records(ctx)
    topics = load_topics(ctx) or []
    if args.src:
        print("Записи со ссылками на %s:" % args.src)
        for stem, r in records:
            if any(x.get("src") == args.src for x in r.get("refs") or []):
                print("  %s  %s  %s" % (stem, r.get("key"), r.get("status")))
        for stem, _, data in load_summaries(ctx):
            for s in data.get("sections", []):
                if any(x.get("src") == args.src for x in s.get("refs") or []):
                    print("  summaries/%s  %s  %s" % (stem, s.get("id"), s.get("status", data.get("status"))))
        return 0

    def tally(statuses):
        c = {s: 0 for s in STATUSES}
        c.update({"unverified/%s" % b: 0 for b in BASES})
        for s in statuses:
            c[s] += 1
        order = []
        for s in STATUSES:
            order.append(s)
            if s == "unverified":
                order.extend("unverified/%s" % b for b in BASES)
        return " ".join("%s=%d" % (s, c[s]) for s in order if c[s] or s in ("none", "draft", "verified", "disputed", "unverified"))

    def label(r):
        st = r.get("status")
        if st == "unverified" and r.get("basis") in BASES:
            return "unverified/%s" % r["basis"]
        return st

    have = {r["key"]: label(r) for _, r in records if r.get("key")}
    print("Объяснения (всего ключей %d): %s" % (len(inv), tally([have.get(k, "none") for k in inv])))
    sec_status = []
    for stem, _, data in load_summaries(ctx):
        sec_status += [s.get("status", data.get("status")) for s in data.get("sections", [])]
    print("Разделы конспектов (%d): %s" % (len(sec_status), tally(sec_status)))
    if topics:
        print("\nПо подтемам:")
        for t in topics:
            st = [have.get(k, "none") for k in t.get("order", [])]
            secs = []
            for stem, _, data in load_summaries(ctx):
                if data.get("topic") == t["id"]:
                    secs += [s.get("status", data.get("status")) for s in data.get("sections", [])]
            print("  %s (%d ключей)%s: %s | разделы: %s" % (
                t["id"], len(st), " complete" if t.get("complete") else "", tally(st), tally(secs) if secs else "-"))
    print("\nПо порциям (файлы src):")
    by_portion = {}
    for stem, r in records:
        by_portion.setdefault(stem, []).append(label(r))
    for p in sorted(by_portion):
        print("  %s (%d): %s" % (p, len(by_portion[p]), tally(by_portion[p])))
    print("\nДоля PASS в раунде 1 по журналу:")
    r1 = {}
    for k, e in ledger.items():
        if e.get("round") == 1:
            r1.setdefault(e.get("portion"), []).append(e.get("verdict"))
    if not r1:
        print("  журнал пуст")
    for p in sorted(r1):
        v = r1[p]
        passed = sum(1 for x in v if x == "PASS")
        print("  %s: PASS %d из %d (%.0f%%), FIX %d, DISPUTED %d" % (
            p, passed, len(v), 100.0 * passed / len(v), v.count("FIX"), v.count("DISPUTED")))
    return 0


# ---------------------------------------------------------------- CLI

def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--root", default=str(Path(__file__).resolve().parents[2]), help="корень проекта")
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("inventory", help="собрать tool/materials/air_law/inventory.json")
    p.add_argument("--stats", action="store_true", help="напечатать числа инвентаризации")
    sub.add_parser("build", help="собрать assets/materials/air_law.json")
    p = sub.add_parser("validate", help="проверить данные материалов")
    p.add_argument("--no-corpus", action="store_true", help="не сверять quote с корпусом")
    p.add_argument("--check", action="store_true", help="сверить ассет с результатом build")
    p = sub.add_parser("apply-review", help="применить вердикты editor")
    p.add_argument("file")
    p.add_argument("--date", help="дата в журнале (по умолчанию сегодня)")
    p = sub.add_parser("report", help="сводка по статусам")
    p.add_argument("--src", help="список записей со ссылками на источник")
    args = ap.parse_args(argv)
    ctx = Ctx(args.root)
    return {"inventory": cmd_inventory, "build": cmd_build, "validate": cmd_validate,
            "apply-review": cmd_apply_review, "report": cmd_report}[args.cmd](ctx, args)


if __name__ == "__main__":
    sys.exit(main())
