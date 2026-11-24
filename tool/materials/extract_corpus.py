#!/usr/bin/env python3
"""Deterministically extract plain text and locator anchors from the downloaded sources.

For every available source in sources.json this writes
  corpus/<id>.txt          normalised text (UTF-8, LF, one physical line per line) - git-ignored
  anchors/<id>.json        {"textSha": sha256(corpus bytes), "anchors": {"<loc>": [start, end]}} - committed

Offsets are Python str (code point) offsets into the text of corpus/<id>.txt, end exclusive.
Anchors hold no text. The same input always gives byte-identical output.

Usage:
  extract_corpus.py --all [--jobs N]
  extract_corpus.py --id ID [--id ID ...]

Locators (see plan "Общие соглашения"):
  statute / convention : art. N | art. N ust. N | art. N ust. N pkt N | art. N pkt N
                         (N as printed: 17a, 87[1], 87[1a], 156zd)
  eu_reg               : art. N | art. N ust. N | SERA.5005 | SERA.5005(a)(1) | FCL.205.A ...
  easa                 : SERA.5005 | SERA.5005(a)(1) | AMC1 SERA.5005(b) | GM1 FCL.205.A ...
  aip                  : GEN 1.2 | ENR 1.2 | ENR 1.2 pkt 2.1
"""
import argparse
import concurrent.futures
import hashlib
import html.parser
import json
import os
import re
import sys
import unicodedata

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_SOURCES_JSON = os.path.join(HERE, "sources.json")
DEFAULT_SOURCES_DIR = os.path.join(HERE, "sources")
DEFAULT_CORPUS_DIR = os.path.join(HERE, "corpus")
DEFAULT_ANCHORS_DIR = os.path.join(HERE, "anchors")

# EAR pages: header zone above this y (pt), footer zone below FOOTER_Y are cropped away.
EAR_HEADER_Y = 88
EAR_FOOTER_Y = 770
# Sejm statute PDFs: the body is set in 10 pt; footnotes and running headers in 9 pt and smaller;
# footnote reference marks (and the index of an article such as 87[1]) are superscripts below 8 pt.
SEJM_BODY_MIN_SIZE = 9.6
SEJM_SUPERSCRIPT_MAX = 8.0
# Marks text that belongs to a redaction which is not in force yet (see sejm_page_lines).
FUTURE_MARK = "\u27e6PRZYSZŁA REDAKCJA\u27e7"

_SPACES = re.compile(r"[ \t  -   ]+")
_CTRL = re.compile(r"[\x00-\x08\x0b-\x1f\x7f​‌‍﻿]")
_HYPHEN_END = re.compile(r"[^\W\d_]-$")
_LOWER_START = re.compile(r"^[^\W\d_A-ZĀ-ſ]")


class ExtractError(Exception):
    pass


# --------------------------------------------------------------------------- text

def clean_line(line):
    line = unicodedata.normalize("NFC", line).replace("­", "")
    line = _CTRL.sub("", line)
    return _SPACES.sub(" ", line).strip()


def clean_lines(lines):
    out = []
    for raw in lines:
        for part in raw.split("\n"):
            c = clean_line(part)
            if c:
                out.append(c)
    return out


def dehyphenate(lines):
    """Join words broken with a hyphen at the end of a line (Polish text only)."""
    out = []
    i = 0
    while i < len(lines):
        cur = lines[i]
        while (i + 1 < len(lines) and _HYPHEN_END.search(cur)
               and lines[i + 1][:1].islower()):
            cur = cur[:-1] + lines[i + 1]
            i += 1
        out.append(cur)
        i += 1
    return out


# --------------------------------------------------------------------------- readers

_ANNEX_HEAD = re.compile(r"^Załącznik nr \d+[a-z]?$")
_FOOT_START = re.compile(r"^(\d+)\)\s+(.*)$")
_FUTURE_PAIR_OLD = re.compile(r"^(W tym brzmieniu obowi.zuje|Wprowadzenie do wyliczenia w tym brzmieniu|"
                              r"Obowi.zuje do wejścia)")
_FUTURE_NEW = re.compile(r"^(Ze zmianą wprowadzoną|Wprowadzenie do wyliczenia ze zmianą|Wejdzie w życie)")


def _dominant_size(chars):
    sizes = {}
    for ch in chars:
        s = round(ch["size"], 1)
        sizes[s] = sizes.get(s, 0) + 1
    return max(sizes.items(), key=lambda kv: (kv[1], kv[0]))[0] if sizes else 10.0


def sejm_page_lines(page, carry=frozenset()):
    """Body lines of one Dziennik Ustaw page.

    * footnote lines (dominant size < 9.6 pt) are dropped, except the right-aligned annex heading
      "Załącznik nr N";
    * superscript footnote marks "27)" glued to numbers ("Art. 44.27)", "4)49)") are removed so that the
      unit number is visible at the start of the line;
    * a mark whose footnote says that the text is the version in force only until a later amendment
      ("W tym brzmieniu obowiązuje do wejścia w życie zmiany, o której mowa w odnośniku N+1") makes
      the N+1 version a not-yet-binding one: that mark is replaced with FUTURE_MARK. A footnote may sit
      on the page before its mark, so the set of such marks of the previous page (carry) is honoured too.

    Returns (lines, marks_to_carry_to_the_next_page).
    """
    from pdfplumber.utils import extract_text

    lines = page.extract_text_lines(return_chars=True)
    body, foot = [], {}
    for ln in lines:
        if _dominant_size(ln["chars"]) < SEJM_BODY_MIN_SIZE and not _ANNEX_HEAD.match(ln["text"].strip()):
            m = _FOOT_START.match(ln["text"].strip())
            if m:
                foot[int(m.group(1))] = m.group(2)
            continue
        body.append(ln)
    future = set()
    for n, t in foot.items():
        if _FUTURE_PAIR_OLD.match(t):
            future.add(n + 1)
        if _FUTURE_NEW.match(t):
            future.add(n)
    carry_out = frozenset(future)
    future |= set(carry)
    out = []
    for ln in body:
        groups = []  # (is_small, [chars])
        for ch in ln["chars"]:
            small = ch["size"] < SEJM_SUPERSCRIPT_MAX
            if groups and groups[-1][0] == small:
                groups[-1][1].append(ch)
            else:
                groups.append((small, [ch]))
        parts = []
        for small, chs in groups:
            if not small:
                parts.append(extract_text(chs, x_tolerance_ratio=0.15))
                continue
            raw = "".join(c["text"] for c in chs)
            m = re.fullmatch(r"\s*(\d+)\)\s*", raw)
            if m:
                parts.append(" %s " % FUTURE_MARK if int(m.group(1)) in future else " ")
            else:
                parts.append(raw)
        out.append(re.sub(r"\s+([),;])", r"\1", "".join(parts)))
    return out, carry_out


def read_pdf_lines(path, profile):
    import pdfplumber  # imported lazily: only needed for PDF sources

    lines = []
    header_re = {
        "sejm": re.compile(r"^Dziennik Ustaw\s+[–-]\s*\d+\s*[–-]\s+Poz\. \d+$"),
        "eurlex": re.compile(r"^(L \d+/\d+\s+PL\s+Dziennik Urzędowy Unii Europejskiej\s+[\d.]+|"
                             r"[\d.]+\s+PL\s+Dziennik Urzędowy Unii Europejskiej\s+L \d+/\d+)$"),
        "easa": re.compile(r"^Powered by EASA eRules Page \d+ of \d+"),
    }.get(profile)
    carry = frozenset()
    with pdfplumber.open(path) as pdf:
        for page in pdf.pages:
            if profile == "easa":
                box = (0, EAR_HEADER_Y, page.width, min(EAR_FOOTER_Y, page.height))
                page_lines = (page.crop(box).extract_text() or "").split("\n")
            elif profile == "sejm":
                page_lines, carry = sejm_page_lines(page, carry)
            else:
                page_lines = [ln["text"] for ln in page.extract_text_lines()]
            for pl in page_lines:
                cl = clean_line(pl)
                if cl and not (header_re and header_re.match(cl)):
                    lines.append(cl)
            page.flush_cache()
    return lines


class _TextExtractor(html.parser.HTMLParser):
    BLOCK = {"p", "div", "br", "li", "ul", "ol", "tr", "table", "h1", "h2", "h3", "h4", "h5", "h6",
             "section", "article", "header", "footer", "pre", "blockquote", "dd", "dt", "dl", "hr"}
    SKIP = {"script", "style", "head", "noscript", "template"}

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.parts = []
        self._skip = 0

    def handle_starttag(self, tag, attrs):
        if tag in self.SKIP:
            self._skip += 1
        elif tag in self.BLOCK or tag in ("td", "th"):
            self.parts.append("\n" if tag not in ("td", "th") else " ")

    def handle_endtag(self, tag):
        if tag in self.SKIP:
            self._skip = max(0, self._skip - 1)
        elif tag in self.BLOCK:
            self.parts.append("\n")

    def handle_data(self, data):
        if not self._skip:
            self.parts.append(data)


def read_html_lines(path):
    with open(path, "rb") as f:
        raw = f.read()
    text = raw.decode("utf-8", errors="replace")
    p = _TextExtractor()
    p.feed(text)
    p.close()
    return "".join(p.parts).split("\n")


def profile_for(src):
    if src["format"] == "html":
        return "html"
    return {"easa": "easa", "eu_reg": "eurlex"}.get(src["kind"], "sejm")


def build_corpus_text(src, path):
    profile = profile_for(src)
    if src["format"] == "pdf":
        lines = read_pdf_lines(path, profile)
    elif src["format"] == "html":
        lines = read_html_lines(path)
    else:
        raise ExtractError("%s: unsupported format %r" % (src["id"], src["format"]))
    lines = clean_lines(lines)
    if src.get("lang") == "pl":
        lines = dehyphenate(lines)
    return "\n".join(lines) + "\n"


# --------------------------------------------------------------------------- anchors

class _Span:
    __slots__ = ("key", "start", "end", "level")

    def __init__(self, key, start, level):
        self.key, self.start, self.level, self.end = key, start, level, None


def _line_offsets(text):
    out = []
    pos = 0
    for line in text.split("\n"):
        out.append((pos, line))
        pos += len(line) + 1
    return out


def _finish(spans, total):
    """Close open spans at the end of the text; emit {key: [start, end]} in document order."""
    for sp in spans:
        if sp.end is None:
            sp.end = total
    spans = sorted(spans, key=lambda s: (s.start, s.level, len(s.key)))
    out = {}
    for sp in spans:
        if sp.key not in out:
            out[sp.key] = [sp.start, sp.end]
    return out


_ART_ID = r"\d+[a-z]{0,3}(?:\[\d+[a-z]{0,2}\])?"
_ART_RE = re.compile(r"^Art\.\s*(%s)\.(?:\s+(.*))?$" % _ART_ID)
_UST_RE = re.compile(r"^(\d+[a-z]{0,2})\.(?:\s+|(?=[A-ZĄĆĘŁŃÓŚŹŻ]))\S")
_PKT_RE = re.compile(r"^(\d+[a-z]{0,2})\)")
_DIV_RE = re.compile(r"^(DZIAŁ [IVXLC]+[A-Z]?|Rozdział \d+[a-z]?|Oddział \d+[a-z]?|ZAŁĄCZNIK( NR \d+)?\.?)$")
_ANNEX_RE = re.compile(r"^Załącznik nr (\d+[a-z]?)$")
_ROW_RE = re.compile(r"^(\d+(?:\.\d+){0,5})\.\s+\S")
_NUM_SPLIT = re.compile(r"^(\d+)([a-z]*)$")
_TOC_LINE = re.compile(r"\.{3,}\s*\d*\s*$")
_PAGE_NO_TAIL = re.compile(r"[^\d.,]\s\d{1,4}$")


def _num_key(token):
    m = _NUM_SPLIT.match(token)
    return (int(m.group(1)), m.group(2)) if m else None


def _next_ok(last, cur, first=(1,)):
    """cur follows last: next integer, or the same integer with a later suffix (1 -> 1a, 1a -> 1b, 1a -> 2).

    The first unit must be one of `first` (for paragraphs an unnumbered single first paragraph is
    allowed: "Art. 201. text / 2. (uchylony)")."""
    if cur is None:
        return False
    if last is None:
        return cur[1] == "" and cur[0] in first
    if cur[0] == last[0] + 1 and cur[1] == "":
        return True
    return cur[0] == last[0] and cur[1] > last[1]


def statute_anchors(text):
    """Anchors for Polish statutes and conventions.

    art. N | art. N ust. N | art. N ust. N pkt N | art. N pkt N      (N as printed: 17a, 87[1], 156zd)
    załącznik N | załącznik N pkt L                                   (annex "Załącznik nr N"; L = Lp. of a table row, e.g. 1.1)

    Units that carry FUTURE_MARK are the redaction that is not binding yet (a later amendment replaces the
    one in force); they get no anchor and are excluded from the ranges of the units in force.
    """
    spans = []
    open_art = open_ust = open_pkt = None
    cur_art = None
    last_ust = last_pkt = None
    started = False
    annex = None
    annex_rows = set()
    dead_ust = False

    def close(sp, at):
        if sp is not None and sp.end is None:
            sp.end = at

    def close_art_tree(at):
        for sp in (open_pkt, open_ust, open_art):
            close(sp, at)

    def open_pkt_span(token, start):
        nonlocal open_pkt, last_pkt
        key = (open_ust.key if open_ust else cur_art) + " pkt " + token
        close(open_pkt, start)
        open_pkt = _Span(key, start, 3)
        spans.append(open_pkt)
        last_pkt = _num_key(token)

    def open_ust_span(token, start):
        nonlocal open_ust, open_pkt, last_ust, last_pkt
        close(open_pkt, start)
        close(open_ust, start)
        open_pkt = None
        last_pkt = None
        open_ust = _Span(cur_art + " ust. " + token, start, 2)
        spans.append(open_ust)
        last_ust = _num_key(token)

    for start, raw in _line_offsets(text):
        fut = FUTURE_MARK in raw
        line = " ".join(raw.replace(FUTURE_MARK, " ").split()) if fut else raw
        ma = _ANNEX_RE.match(line)
        if ma:
            close_art_tree(start)
            open_art = open_ust = open_pkt = None
            cur_art = None
            close(annex, start)
            for sp in spans:
                if sp.end is None and sp.level == 2:
                    sp.end = start
            annex = _Span("załącznik " + ma.group(1), start, 1)
            spans.append(annex)
            annex_rows = set()
            started = True
            continue
        if annex is not None:
            mr = _ROW_RE.match(line)
            if mr and not fut:
                key = annex.key + " pkt " + mr.group(1)
                if key not in annex_rows:
                    annex_rows.add(key)
                    for sp in spans[::-1]:
                        if sp.level == 2 and sp.end is None:
                            sp.end = start
                            break
                    spans.append(_Span(key, start, 2))
            continue
        if started and _DIV_RE.match(line):
            close_art_tree(start)
            open_art = open_ust = open_pkt = None
            cur_art = None
            continue
        m = _ART_RE.match(line)
        if m:
            token = m.group(1)
            if not started:
                if token != "1":
                    continue
                started = True
            if fut:
                close_art_tree(start)
                open_art = open_ust = open_pkt = None
                cur_art = None
                continue
            if any(sp.key == "art. " + token for sp in spans[-400:]):
                m = None  # duplicate heading text: treat as ordinary text
            if m:
                close_art_tree(start)
                cur_art = "art. " + token
                open_art = _Span(cur_art, start, 1)
                spans.append(open_art)
                open_ust = open_pkt = None
                last_ust = last_pkt = None
                dead_ust = False
                rest = m.group(2) or ""
                mu = _UST_RE.match(rest)
                if mu and _next_ok(None, _num_key(mu.group(1))):
                    open_ust_span(mu.group(1), start)
                continue
        if not started or cur_art is None:
            continue
        mu = _UST_RE.match(line)
        if mu and (fut or _next_ok(last_ust, _num_key(mu.group(1)), first=(1, 2))):
            if fut:
                close(open_pkt, start)
                close(open_ust, start)
                open_pkt = open_ust = None
                dead_ust = True
                nk = _num_key(mu.group(1))
                if _next_ok(last_ust, nk, first=(1, 2)):
                    last_ust = nk   # the unit exists in the numbering even though it is not in force yet
                    last_pkt = None
            else:
                dead_ust = False
                open_ust_span(mu.group(1), start)
            continue
        mp = _PKT_RE.match(line)
        if mp and not dead_ust and (fut or _next_ok(last_pkt, _num_key(mp.group(1)))):
            if fut:
                close(open_pkt, start)
                open_pkt = None
                nk = _num_key(mp.group(1))
                if _next_ok(last_pkt, nk):
                    last_pkt = nk
            else:
                open_pkt_span(mp.group(1), start)
    return _finish(spans, len(text))


# EU / EASA rule identifiers: SERA.5005, FCL.205.A, NCO.GEN.105, MED.A.030, BFCL.115, ORO.FC.100 ...
_RULE_ID = r"[A-Z]{2,6}(?:\.[A-Z]{1,6})*\.\d{1,4}(?:\.[A-Z])?"
_ID_PAREN = r"%s(?:\([a-z0-9]+\))*" % _RULE_ID
_RULE_RE = re.compile(r"^(%s)(?:\s+(\S.*))?$" % _RULE_ID)
# "AMC1 SERA.5005(f) Title" and the multi-rule form "AMC1 FCL.210; FCL.215 Title"
_AMC_FULL_RE = re.compile(r"^((?:AMC|GM)\d*)\s+(%s(?:\s*;\s*%s)*)(?=\s|$)" % (_ID_PAREN, _ID_PAREN))
_ART_EU_RE = re.compile(r"^(?:Article|Artykuł)\s+(\d+[a-z]?)$")
_ART_EAR_RE = re.compile(r"^Article (\d+[a-z]?) \S")
_GM_ART_RE = re.compile(r"^((?:AMC|GM)\d*) (?:to )?Article (\d+[a-z]?(?:\(\d+[a-z]?\))?)(?=\s)")
_GM_OTHER_RE = re.compile(r"^(?:AMC|GM)\d*\s+(?:and (?:AMC|GM)\d*\s+)?to\s")
_APPENDIX_RE = re.compile(r"^APPENDIX (\d+) \S")
_APP_ROW_RE = re.compile(r"^(\d{1,2}(?:\.\d{1,3}){0,4})\.\s+\S")
_PARA_RE = re.compile(r"^\(([a-z]{1,4}|\d{1,2}|[A-Z])\)\s*\S")
_PARA_NUM_RE = re.compile(r"^(\d{1,3})\.\s+\S")
_DEF_RE = re.compile(r"^(\d{1,3})([a-z]?)\.\s+[‘']")
_TABLE_NOTE_RE = re.compile(r"^\(\*+\)")
_ROMAN = ["i", "ii", "iii", "iv", "v", "vi", "vii", "viii", "ix", "x", "xi", "xii", "xiii", "xiv", "xv"]
_BOUNDARY_RE = re.compile(r"^(SUBPART [A-Z]\b.*|SECTION \d+\b.*|Appendix \d+ to .*|"
                          r"ANNEX( [IVX]+)?\b.*|ANEKS [IVX]+\b.*|Table of contents|Contents)$")


class _ParaState:
    """Tracks (a) -> (1) -> (i) nesting inside one rule, accepting only in-sequence markers."""

    def __init__(self):
        self.l1 = None
        self.l2 = None
        self.l3 = None
        self.keys = [None, None, None]
        self.frozen = False   # a table footnote "(*)" starts: later "(a)" lines are footnote text

    def classify(self, token):
        if self.frozen:
            return None
        if token.isdigit():
            if self.keys[0] is None or token != str(int(token)):
                return None
            nxt = 1 if self.l2 is None else self.l2 + 1
            return 2 if int(token) == nxt else None
        if token.islower():
            if self.keys[1] is not None and token in _ROMAN:
                exp = _ROMAN[0] if self.l3 is None else (_ROMAN[_ROMAN.index(self.l3) + 1]
                                                         if self.l3 in _ROMAN[:-1] else None)
                if token == exp:
                    return 3
            if len(token) == 1:
                exp1 = "a" if self.l1 is None else chr(ord(self.l1) + 1)
                if token == exp1:
                    return 1
        return None

    def accept(self, token, level):
        if level == 1:
            self.l1, self.l2, self.l3 = token, None, None
            self.keys = [token, None, None]
        elif level == 2:
            self.l2, self.l3 = int(token), None
            self.keys = [self.keys[0], token, None]
        else:
            self.l3 = token
            self.keys = [self.keys[0], self.keys[1], token]

    def key_suffix(self):
        return "".join("(%s)" % k for k in self.keys if k is not None)


def rule_anchors(text, kind, extras=()):
    """Rule-ID anchors for EU regulations (PL) and EASA Easy Access Rules (EN).

    SERA.5005 | SERA.5005(a)(1)(i) | AMC1 SERA.5005(f) | GM1 FCL.205.A     always;
    a heading "AMC1 FCL.210; FCL.215" gives one anchor per listed rule (same range);
    the parent "AMC1 X" of "AMC1 X(b)" is the union of its children;
    extras ("article", "appendix"; only for the one regulation an EAR is built around):
      Article N | Article N(M)  (M = numbered paragraph or definition number, e.g. Article 2(12))
      Appendix N | Appendix N pkt 1.2.1
    kind eu_reg (PL text) additionally gives art. N | art. N ust. N.
    """
    spans = []
    have = set()
    group = []          # spans of the current heading (all end together)
    para = {}           # level -> open paragraph span
    state = None
    base = None
    children = {}       # parent alias key -> child spans
    art = None          # open Article span (extras) / EU art. span
    art_last = None
    app = None
    app_rows = set()
    art_extra = "article" in extras
    app_extra = "appendix" in extras

    def end_all(at):
        nonlocal group, para, state, base, art, app
        for sp in group:
            if sp.end is None:
                sp.end = at
        for sp in para.values():
            if sp.end is None:
                sp.end = at
        group, para, state, base = [], {}, None, None
        if art is not None and art.end is None:
            art.end = at
        art = None
        for sp in spans:
            if sp.level == 8 and sp.end is None:
                sp.end = at

    def end_app(at):
        nonlocal app
        if app is not None and app.end is None:
            app.end = at
        for sp in spans:
            if sp.level == 9 and sp.end is None:
                sp.end = at
        app = None

    rows = _line_offsets(text)
    for idx, (start, line) in enumerate(rows):
        if any(_TOC_LINE.search(rows[j][1]) for j in range(idx, min(idx + 4, len(rows)))):
            continue  # table-of-contents entry (dot leaders, possibly on a wrapped later line)
        mm = _AMC_FULL_RE.match(line)
        is_head = bool(mm or _RULE_RE.match(line))
        if _PAGE_NO_TAIL.search(line) and is_head:
            continue  # table-of-contents entry whose dot leaders were lost
        if _BOUNDARY_RE.match(line):
            end_all(start)
            end_app(start)
            continue
        if app_extra and _APPENDIX_RE.match(line):
            ma = _APPENDIX_RE.match(line)
            key = "Appendix " + ma.group(1)
            end_all(start)
            end_app(start)
            if key not in have:
                have.add(key)
                app = _Span(key, start, 1)
                spans.append(app)
                app_rows = set()
            continue
        ma = _ART_EU_RE.match(line) if kind == "eu_reg" else (_ART_EAR_RE.match(line) if art_extra else None)
        if ma and app is None:
            end_all(start)
            key = ("art. " if kind == "eu_reg" else "Article ") + ma.group(1)
            if key not in have:
                have.add(key)
                art = _Span(key, start, 1)
                spans.append(art)
                art_last = None
            continue
        if _GM_OTHER_RE.match(line) and not _GM_ART_RE.match(line):
            end_app(start)
            end_all(start)   # "GM1 to Appendix 4", "GM1 to AMC1 SERA.8005(c)": text of another block
            continue
        mg = _GM_ART_RE.match(line) if art_extra else None
        if mg:
            end_app(start)
            end_all(start)
            key = "%s Article %s" % (mg.group(1), mg.group(2))
            if key not in have:
                have.add(key)
                sp = _Span(key, start, 1)
                spans.append(sp)
                group = [sp]
                state = _ParaState()
                base = key
                anc = key
                while True:
                    mpar = re.match(r"^(.+)\([a-z0-9]+\)$", anc)
                    if not mpar:
                        break
                    anc = mpar.group(1)
                    children.setdefault(anc, []).append(sp)
            continue
        if mm and kind in ("easa", "eu_reg"):
            end_app(start)
            end_all(start)
            head = mm.group(1)
            ids = [i.strip() for i in mm.group(2).split(";")]
            fulls = ["%s %s" % (head, i) for i in ids]
            new = [f for f in fulls if f not in have]
            if new:
                group = []
                for f in new:
                    have.add(f)
                    sp = _Span(f, start, 1)
                    spans.append(sp)
                    group.append(sp)
                    anc = f
                    while True:
                        mpar = re.match(r"^(.+)\([a-z0-9]+\)$", anc)
                        if not mpar:
                            break
                        anc = mpar.group(1)
                        children.setdefault(anc, []).append(sp)
                state = _ParaState()
                base = new[0]
            continue
        mr = _RULE_RE.match(line)
        if mr and (mr.group(2) is None or not mr.group(2)[:1].islower()):
            end_app(start)
            end_all(start)
            if mr.group(1) not in have:
                have.add(mr.group(1))
                sp = _Span(mr.group(1), start, 1)
                spans.append(sp)
                group = [sp]
                state = _ParaState()
                base = mr.group(1)
            continue
        if app is not None and app_extra:
            mrow = _APP_ROW_RE.match(line)
            if mrow:
                key = app.key + " pkt " + mrow.group(1)
                if key not in app_rows:
                    app_rows.add(key)
                    end_row = [sp for sp in spans if sp.level == 9 and sp.end is None]
                    for sp in end_row:
                        sp.end = start
                    spans.append(_Span(key, start, 9))
            continue
        if state is not None and group:
            if _TABLE_NOTE_RE.match(line):
                state.frozen = True
            mp = _PARA_RE.match(line)
            if mp:
                token = mp.group(1)
                level = state.classify(token)
                if level is not None:
                    for lv in [l for l in para if l >= level]:
                        para.pop(lv).end = start
                    state.accept(token, level)
                    key = base + state.key_suffix()
                    if key not in have:
                        have.add(key)
                        sp = _Span(key, start, 1 + level)
                        spans.append(sp)
                        para[level] = sp
                    continue
        if art is not None:
            if kind == "eu_reg" or art_extra:
                mn = _PARA_NUM_RE.match(line)
                md = _DEF_RE.match(line)
                if md and md.group(2) and art_last is not None and int(md.group(1)) == art_last \
                        and kind != "eu_reg":
                    key = "%s(%s%s)" % (art.key, md.group(1), md.group(2))
                    for sp in spans:
                        if sp.level == 8 and sp.end is None:
                            sp.end = start
                    if key not in have:
                        have.add(key)
                        spans.append(_Span(key, start, 8))
                    continue
                if mn:
                    num = int(mn.group(1))
                    ok = (art_last is None and num == 1) or (art_last is not None and num == art_last + 1)
                    if not ok and md and art_last is not None and art_last < num <= art_last + 3:
                        ok = True     # definitions list: a missing number in the printed sequence
                    if ok:
                        art_last = num
                        key = art.key + (" ust. %d" % num if kind == "eu_reg" else "(%d)" % num)
                        for sp in spans:
                            if sp.level == 8 and sp.end is None:
                                sp.end = start
                        if key not in have:
                            have.add(key)
                            spans.append(_Span(key, start, 8))
    end_all(len(text))
    end_app(len(text))
    by_key = {sp.key: sp for sp in spans}
    for parent, kids in children.items():
        lo = min(k.start for k in kids)
        hi = max(k.end if k.end is not None else len(text) for k in kids)
        if parent not in have:
            have.add(parent)
            sp = _Span(parent, lo, 1)
            sp.end = hi
            spans.append(sp)
        else:
            # a real heading "AMC1 X" and later separate headings "AMC1 X(b)": the parent covers its children
            sp = by_key[parent]
            sp.start = min(sp.start, lo)
            sp.end = max(sp.end if sp.end is not None else len(text), hi)
    return _finish(spans, len(text))


_AIP_RE = re.compile(r"^((?:GEN|ENR|AD) \d+(?:\.\d+)*)(?:\s|$)")
_AIP_SUB_RE = re.compile(r"^(\d+(?:\.\d+)+)\s+\S")


def aip_anchors(text):
    """GEN 1.2 / ENR 1.2 / ENR 1.2 pkt 2.1 from an eAIP rendered to text."""
    spans = []
    seen = set()
    cur = None
    sub = None
    for start, line in _line_offsets(text):
        m = _AIP_RE.match(line)
        if m and m.group(1) not in seen:
            if cur is not None:
                cur.end = start
            if sub is not None:
                sub.end = start
                sub = None
            seen.add(m.group(1))
            cur = _Span(m.group(1), start, 1)
            spans.append(cur)
            continue
        if cur is not None:
            ms = _AIP_SUB_RE.match(line)
            if ms:
                key = cur.key + " pkt " + ms.group(1)
                if key not in seen:
                    seen.add(key)
                    if sub is not None:
                        sub.end = start
                    sub = _Span(key, start, 2)
                    spans.append(sub)
    return _finish(spans, len(text))


def anchors_for(src, text):
    kind = src["kind"]
    extras = tuple(src.get("anchorExtras", ()))
    if kind in ("statute", "convention"):
        return statute_anchors(text)
    if kind in ("eu_reg", "easa"):
        return rule_anchors(text, kind, extras)
    if kind == "aip":
        return aip_anchors(text)
    raise ExtractError("%s: unknown kind %r" % (src["id"], kind))


# --------------------------------------------------------------------------- driver

def write_text(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def write_anchors(path, text_sha, anchors):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    rows = ",\n".join("    %s: [%d, %d]" % (json.dumps(k, ensure_ascii=False), s, e)
                      for k, (s, e) in anchors.items())
    body = '{\n  "textSha": "%s",\n  "anchors": {\n%s\n  }\n}\n' % (text_sha, rows)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(body)


def extract_one(src, sources_dir, corpus_dir, anchors_dir):
    path = os.path.join(sources_dir, src["id"], "%s.%s" % (src["id"], src["format"]))
    if not os.path.exists(path):
        raise ExtractError("%s: %s not found (run fetch_sources.py first)" % (src["id"], path))
    text = build_corpus_text(src, path)
    sha = hashlib.sha256(text.encode("utf-8")).hexdigest()
    anchors = anchors_for(src, text)
    write_text(os.path.join(corpus_dir, src["id"] + ".txt"), text)
    write_anchors(os.path.join(anchors_dir, src["id"] + ".json"), sha, anchors)
    return src["id"], len(text), len(anchors)


def _job(args):
    return extract_one(*args)


def main(argv=None, out=print):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--all", action="store_true", help="every available source")
    ap.add_argument("--id", action="append", default=[], help="source id (repeatable)")
    ap.add_argument("--jobs", type=int, default=min(4, os.cpu_count() or 1))
    ap.add_argument("--sources-json", default=DEFAULT_SOURCES_JSON)
    ap.add_argument("--sources-dir", default=DEFAULT_SOURCES_DIR)
    ap.add_argument("--corpus-dir", default=DEFAULT_CORPUS_DIR)
    ap.add_argument("--anchors-dir", default=DEFAULT_ANCHORS_DIR)
    args = ap.parse_args(argv)
    if not args.all and not args.id:
        ap.error("give --all or --id")
    with open(args.sources_json, encoding="utf-8") as f:
        sources = json.load(f)
    avail = [s for s in sources if s.get("status", "available") == "available"]
    if args.id:
        by_id = {s["id"]: s for s in sources}
        chosen = []
        for i in args.id:
            if i not in by_id:
                out("ERROR: unknown source id %s" % i)
                return 3
            if by_id[i].get("status", "available") != "available":
                out("ERROR: source %s is unavailable" % i)
                return 3
            chosen.append(by_id[i])
    else:
        chosen = avail
    jobs = [(s, args.sources_dir, args.corpus_dir, args.anchors_dir) for s in chosen]
    code = 0
    results = {}
    try:
        if args.jobs > 1 and len(jobs) > 1:
            with concurrent.futures.ProcessPoolExecutor(max_workers=args.jobs) as ex:
                futs = {ex.submit(_job, j): j[0]["id"] for j in jobs}
                for fut in concurrent.futures.as_completed(futs):
                    try:
                        results[futs[fut]] = fut.result()
                    except ExtractError as e:
                        out("ERROR: %s" % e)
                        code = 3
        else:
            for j in jobs:
                try:
                    results[j[0]["id"]] = _job(j)
                except ExtractError as e:
                    out("ERROR: %s" % e)
                    code = 3
    except OSError as e:
        out("ERROR: %s" % e)
        return 3
    for s in chosen:
        if s["id"] in results:
            _, n_chars, n_anchors = results[s["id"]]
            out("OK %s chars=%d anchors=%d" % (s["id"], n_chars, n_anchors))
    return code


if __name__ == "__main__":
    sys.exit(main())
