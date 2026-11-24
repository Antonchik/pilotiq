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

# EU / EASA rule identifiers: SERA.5005, SERA.14095, FCL.205.A, NCO.GEN.105, MED.A.030, ORA.AeMC.215,
# ARA.GEN.135A, 21.A.3A, 145.A.30, M.A.201, T.A.101
_RULE_ID = (r"(?:[A-Z]{2,6}(?:[/-][A-Z]{2,6})?(?:\.[A-Za-z]{1,6})*\.\d{1,5}[A-Z]?(?:\.[A-Z])?"
            r"|(?:\d{2,3}|[A-Z])\.[A-Z]\.\d{1,5}[A-Z]?)")

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

    def __init__(self, skip_classes=None):
        super().__init__(convert_charrefs=True)
        self.parts = []
        self._skip = 0
        self._skip_classes = skip_classes
        self._skip_tag = None   # element (tag name) whose subtree is skipped because of its class
        self._skip_depth = 0

    def handle_starttag(self, tag, attrs):
        if self._skip_tag is not None:
            if tag == self._skip_tag:
                self._skip_depth += 1
            return
        if self._skip_classes is not None:
            cls = dict(attrs).get("class") or ""
            if self._skip_classes.search(cls):
                self._skip_tag, self._skip_depth = tag, 1
                return
        if tag in self.SKIP:
            self._skip += 1
        elif tag in self.BLOCK or tag in ("td", "th"):
            self.parts.append("\n" if tag not in ("td", "th") else " ")

    def handle_endtag(self, tag):
        if self._skip_tag is not None:
            if tag == self._skip_tag:
                self._skip_depth -= 1
                if self._skip_depth == 0:
                    self._skip_tag = None
            return
        if tag in self.SKIP:
            self._skip = max(0, self._skip - 1)
        elif tag in self.BLOCK:
            self.parts.append("\n")

    def handle_data(self, data):
        if not self._skip and self._skip_tag is None:
            self.parts.append(re.sub(r"\s+", " ", data))


# EUR-Lex / CELLAR consolidated XHTML: amendment-reference paragraphs and the table of contents are not text of the act
_EURLEX_SKIP = re.compile(r"\b(modref|toc-\d+|arrow|superscript|oj-note|oj-note-tag|oj-super)\b")
_AMEND_MARK = re.compile(r"[►▼◄](?:[A-Z]\d*[A-Z]?\d*)?")
_LABEL_ONLY = re.compile(r"^(?:\(?[a-z]{1,4}\)|\(?\d{1,3}[a-z]?\)|\d{1,3}[a-z]?\.|%s)$" % _RULE_ID)


def read_html_lines(path, profile="html"):
    with open(path, "rb") as f:
        raw = f.read()
    text = raw.decode("utf-8", errors="replace")
    p = _TextExtractor(_EURLEX_SKIP if profile == "eurlex_html" else None)
    p.feed(text)
    p.close()
    lines = "".join(p.parts).split("\n")
    if profile == "eurlex_html":
        lines = [re.sub(r"[—–-]{4,}", " ", ln) for ln in lines]
        lines = [re.sub(r"\s+([,;)]|\.(?=\s|$))", r"\1", re.sub(r"\(\s*\)", "", _AMEND_MARK.sub(" ", ln)))
                 for ln in lines]
        merged = []
        i = 0
        lines = [re.sub(r"^(%s) ([A-Z])$" % _RULE_ID, r"\1\2", clean_line(ln)) for ln in lines]
        lines = [ln for ln in lines if ln]
        while i < len(lines):
            if _LABEL_ONLY.match(lines[i]) and i + 1 < len(lines):
                merged.append(lines[i] + " " + lines[i + 1])
                i += 2
            else:
                merged.append(lines[i])
                i += 1
        lines = merged
    return lines


def profile_for(src):
    if src["format"] == "html":
        return "eurlex_html" if src["kind"] == "eu_reg" else "html"
    return {"easa": "easa", "eu_reg": "eurlex"}.get(src["kind"], "sejm")


def build_corpus_text(src, path):
    profile = profile_for(src)
    if src["format"] == "pdf":
        lines = read_pdf_lines(path, profile)
    elif src["format"] == "html":
        lines = read_html_lines(path, profile)
    else:
        raise ExtractError("%s: unsupported format %r" % (src["id"], src["format"]))
    lines = clean_lines(lines)
    if src.get("lang") == "pl":
        lines = dehyphenate(lines)
    return "\n".join(lines) + "\n"


# --------------------------------------------------------------------------- anchors

class _Span:
    __slots__ = ("key", "start", "end", "level", "dummy")

    def __init__(self, key, start, level):
        self.key, self.start, self.level, self.end = key, start, level, None
        self.dummy = False


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
_ART_RE = re.compile(r"^(Art\.|§)\s*(%s)\.(?:\s+(.*))?$" % _ART_ID)   # "Art. 5." of statutes, "§ 5." of regulations
_UST_RE = re.compile(r"^(\d+[a-z]{0,2})\.(?:\s+|(?=[A-ZĄĆĘŁŃÓŚŹŻ]))\S")
_PKT_RE = re.compile(r"^(\d+[a-z]{0,2})\)")
_DIV_RE = re.compile(r"^(DZIAŁ [IVXLC]+[A-Z]?|Rozdział \d+[a-z]?|Oddział \d+[a-z]?|ZAŁĄCZNIK( NR \d+)?\.?)$")
_ANNEX_RE = re.compile(r"^Załącznik nr (\d+[a-z]?)$")
_ITEM_RE = re.compile(r"^(?:[a-z]\)|–|-|\d+[a-z]?\)|\d+[a-z]?\.|Art\.)\s")
_TABLE_RE = re.compile(r"^Tabela nr (\d+)$")
_PART_RE = re.compile(r"^Część ([IVX]+[a-z]?)(?:\s.*)?$")
_FOOTNOTES_RE = re.compile(r"^Przypisy:?$")
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


def statute_anchors(text, future_out=None):
    """Anchors for Polish statutes and conventions.

    art. N | art. N ust. N | art. N ust. N pkt N | art. N pkt N      (N as printed: 17a, 87[1], 156zd)
    załącznik N | załącznik N pkt L                                   (annex "Załącznik nr N"; L = Lp. of a table row, e.g. 1.1)

    Units that carry FUTURE_MARK are the redaction that is not binding yet (a later amendment replaces the
    one in force); they get no anchor. Their text ranges (from the marked heading to the next unit of the same
    or a higher level) are appended to `future_out` as [start, end] and stored in anchors JSON as "future";
    the validator masks them, so enclosing anchors cannot be used to quote the not-yet-binding text.
    """
    spans = []
    open_art = open_ust = open_pkt = None
    cur_art = None
    last_ust = last_pkt = None
    started = False
    annex = None
    annex_rows = set()
    tab = part = None
    dead_ust = False
    fut_start = None
    fut_level = 0

    def close(sp, at):
        if sp is not None and sp.end is None:
            sp.end = at

    def close_future(at, level):
        """A unit heading of the given level (0 = division / annex) ends a future-redaction range of >= its level."""
        nonlocal fut_start
        if fut_start is not None and level <= fut_level:
            if future_out is not None and at > fut_start:
                if future_out and future_out[-1][1] == fut_start:
                    future_out[-1][1] = at
                else:
                    future_out.append([fut_start, at])
            fut_start = None

    def open_future(at, level):
        nonlocal fut_start, fut_level
        close_future(at, level)
        if fut_start is None:
            fut_start, fut_level = at, level

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
        if fut_start is not None and fut_level == 4 and not fut and start > fut_start and _ITEM_RE.match(line):
            close_future(start, 4)   # a marked letter / dash item ended: the next item is in force again
        if fut and fut_start is None:
            fut_start, fut_level = start, 4   # provisional: a marker inside a lit. / dash item (unit headings re-open at their level)
        ma = _ANNEX_RE.match(line)
        if ma:
            close_art_tree(start)
            open_art = open_ust = open_pkt = None
            cur_art = None
            close_future(start, 0)
            close(annex, start)
            for sp in spans:
                if sp.end is None and sp.level >= 2:
                    sp.end = start
            annex = _Span("załącznik " + ma.group(1), start, 1)
            spans.append(annex)
            annex_rows = set()
            tab = part = None
            started = True
            continue
        if annex is not None:
            mt = _TABLE_RE.match(line)
            mpart = _PART_RE.match(line)
            if mt:
                for sp in spans:
                    if sp.end is None and sp.level >= 2:
                        sp.end = start
                tab = _Span("%s tabela %s" % (annex.key, mt.group(1)), start, 2)
                spans.append(tab)
                part = None
                continue
            if mpart:
                for sp in spans:
                    if sp.end is None and sp.level >= 3:
                        sp.end = start
                base_key = tab.key if tab is not None else annex.key
                part = _Span("%s część %s" % (base_key, mpart.group(1)), start, 3)
                spans.append(part)
                continue
            if _FOOTNOTES_RE.match(line):
                for sp in spans:
                    if sp.end is None and sp.level >= 4:
                        sp.end = start
                continue
            mr = _ROW_RE.match(line)
            if mr and not fut:
                ctx = part.key if part is not None else (tab.key if tab is not None else annex.key)
                key = "%s pkt %s" % (ctx, mr.group(1))
                if key not in annex_rows:
                    annex_rows.add(key)
                    for sp in spans:
                        if sp.end is None and sp.level >= 4:
                            sp.end = start
                    spans.append(_Span(key, start, 4))
            continue
        if started and _DIV_RE.match(line):
            close_future(start, 0)
            close_art_tree(start)
            open_art = open_ust = open_pkt = None
            cur_art = None
            continue
        m = _ART_RE.match(line)
        if m:
            token = m.group(2)
            unit = "§ " if m.group(1) == "§" else "art. "
            if not started:
                if token != "1":
                    continue
                started = True
            if fut:
                open_future(start, 1)
                close_art_tree(start)
                open_art = open_ust = open_pkt = None
                cur_art = None
                continue
            close_future(start, 1)
            if any(sp.key == unit + token for sp in spans[-400:]):
                m = None  # duplicate heading text: treat as ordinary text
            if m:
                close_art_tree(start)
                cur_art = unit + token
                open_art = _Span(cur_art, start, 1)
                spans.append(open_art)
                open_ust = open_pkt = None
                last_ust = last_pkt = None
                dead_ust = False
                rest = m.group(3) or ""
                mu = _UST_RE.match(rest)
                if mu and _next_ok(None, _num_key(mu.group(1))):
                    open_ust_span(mu.group(1), start)
                continue
        if not started or cur_art is None:
            continue
        mu = _UST_RE.match(line)
        if mu and (fut or _next_ok(last_ust, _num_key(mu.group(1)), first=(1, 2))):
            if fut:
                open_future(start, 2)
                close(open_pkt, start)
                close(open_ust, start)
                open_pkt = open_ust = None
                dead_ust = True
                nk = _num_key(mu.group(1))
                if _next_ok(last_ust, nk, first=(1, 2)):
                    last_ust = nk   # the unit exists in the numbering even though it is not in force yet
                    last_pkt = None
            else:
                close_future(start, 2)
                dead_ust = False
                open_ust_span(mu.group(1), start)
            continue
        mp = _PKT_RE.match(line)
        if mp and not dead_ust and (fut or _next_ok(last_pkt, _num_key(mp.group(1)))):
            if fut:
                open_future(start, 3)
                close(open_pkt, start)
                open_pkt = None
                nk = _num_key(mp.group(1))
                if _next_ok(last_pkt, nk):
                    last_pkt = nk
            else:
                close_future(start, 3)
                open_pkt_span(mp.group(1), start)
    close_future(len(text), 0)
    return _finish(spans, len(text))


# EU / EASA rule identifiers: SERA.5005, FCL.205.A, NCO.GEN.105, MED.A.030, BFCL.115, ORO.FC.100 ...
_ID_PAREN = r"%s(?:\([a-z0-9]+\))*" % _RULE_ID
_RULE_RE = re.compile(r"^(%s)(?:\s+(\S.*))?$" % _RULE_ID)
# "AMC1 SERA.5005(f) Title" and the multi-rule form "AMC1 FCL.210; FCL.215 Title"
_AMC_FULL_RE = re.compile(r"^((?:AMC|GM|CS)\d*)\s+(%s(?:\s*;\s*%s)*)(?=\s|$)" % (_ID_PAREN, _ID_PAREN))
_ART_EU_RE = re.compile(r"^(?:Article|Artykuł)\s+(\d+[a-z]?)$")
_ART_EAR_RE = re.compile(r"^Article (\d+[a-z]?) \S")
_GM_ART_RE = re.compile(r"^((?:AMC|GM)\d*) (?:to )?Article (\d+[a-z]?(?:\(\d+[a-z]?\))?)(?=\s)")
_GM_OTHER_RE = re.compile(r"^(?:AMC|GM)\d*\s+(?:and (?:AMC|GM)\d*\s+)?to\s")
_AMC_APP_RE = re.compile(r"^(Appendix \d+ to (?:AMC|GM)\d* %s(?:\([a-z0-9]+\))*)(?=\s|$)" % _RULE_ID)
_APPENDIX_RE = re.compile(r"^APPENDIX (\d+) \S")
_APP_ROW_RE = re.compile(r"^(\d{1,2}(?:\.\d{1,3}){0,4})\.\s+\S")
_PARA_RE = re.compile(r"^\(([a-z]{1,4}|\d{1,2}|[A-Z])\)\s*\S")
_PARA_NUM_RE = re.compile(r"^(\d{1,3})\.\s+\S")
_DEF_RE = re.compile(r"^(\d{1,3})([a-z]?)\.\s+[‘']")
# a heading-like line of a change log ("... New Issue 1, Amdt 16 ED Decision 2022/012/R", "... Changed 1/12 EDD 2019/019/R")
_CHANGELOG_RE = re.compile(
    r"(?:(?:New|Changed|Renumbered|Deleted|Amdt|Moved|Issue \d|\d+/\d+)[^\n]*\b(?:ED Decision|EDD)\s+\d{4}/\d+(?:/[A-Z])?\s*$)"
    r"|(?:\b(?:New(?: point)?|Changed|Deleted|Renumbered|Moved)\s+(?:Reg\.|N/a|Regulation|ED Decision|EDD)(?=\s|$))")
_TABLE_NOTE_RE = re.compile(r"^\(\*+\)")
_ROMAN = ["i", "ii", "iii", "iv", "v", "vi", "vii", "viii", "ix", "x", "xi", "xii", "xiii", "xiv", "xv"]
_EXAM_SECTION_RE = re.compile(r"^SECTION (\d+[A-Z]?):")   # skill-test sections inside an AMC: "SECTION 2A: WINCH OR CAR LAUNCH"
_BOUNDARY_RE = re.compile(r"^(SUBPART [A-Z]\b.*|SECTION \d+(?![A-Za-z0-9:])(?!\s*:).*|Appendix \d+ to .*|"
                          r"ANNEX( [IVX]+)?\b.*|ANEKS [IVX]+\b.*|Table of contents|Contents)$")


_CHANGELOG_TITLE_RE = re.compile(r"^(?:Changed|Deleted|Renumbered|Moved|Amended)\b|^New\s+(?:Issue|Reg\.|N/a|\d)")


def _heading_flags(rows):
    """True for every line that looks like a rule / AMC / GM heading (title case not checked)."""
    flags = []
    for _, ln in rows:
        m = _AMC_FULL_RE.match(ln)
        if m:
            flags.append(not ln[m.end():].strip()[:1].islower())
            continue
        m = _RULE_RE.match(ln)
        flags.append(bool(m) and (m.group(2) is None or not m.group(2)[:1].islower()))
    return flags


def _toc_like(flags, i):
    """A heading that sits in a run of three consecutive heading lines is a table of contents / changelog row."""
    n = len(flags)
    return bool((0 < i < n - 1 and flags[i - 1] and flags[i + 1])
                or (i + 2 < n and flags[i + 1] and flags[i + 2])
                or (i >= 2 and flags[i - 2] and flags[i - 1]))


def _heading_key(line):
    m = _AMC_FULL_RE.match(line)
    if m:
        return "%s %s" % (m.group(1), m.group(2).split(";")[0].strip())
    m = _RULE_RE.match(line)
    return m.group(1) if m else None


_BODY_STOP_RE = re.compile(r"^\(?(?:PODCZĘŚĆ|PODSEKCJA|Podsekcja|SEKCJA|DZIAŁ|ROZDZIAŁ|ODDZIAŁ|TYTUŁ|ZAŁĄCZNIK|Dodatek|\[CZĘŚĆ|"
                           r"SUBPART|SECTION|APPENDIX|Appendix|ANNEX)\b")
_SOURCE_LINE_RE = re.compile(r"^(?:Regulation|ED Decision|Commission|Rozporządzenie|Decyzja)\b")
MIN_BODY = 25


def _heading_rejected(rows, flags, idx):
    """Table-of-contents entry (dot leaders, trailing page number), change-log row or cross-reference list item."""
    line = rows[idx][1]
    if idx and re.search(r"(?:&|\band|,)$", rows[idx - 1][1]):
        return True   # second line of a wrapped heading ("AMC1 X Title &" / "ARO.RAMP.130 Other title")
    if any(_TOC_LINE.search(rows[j][1]) for j in range(idx, min(idx + 4, len(rows)))):
        return True
    if _PAGE_NO_TAIL.search(line):
        return True
    return bool(any(_CHANGELOG_RE.search(rows[j][1]) for j in range(idx, min(idx + 3, len(rows))))
                or (line.endswith(",") and idx + 1 < len(rows) and flags[idx + 1])
                or (idx + 1 < len(rows) and flags[idx + 1] and rows[idx + 1][1].endswith(","))
                or _changelog_title(line))


def _loser_occurrences(rows, flags, require_source=False):
    """Line indexes of repeated or empty headings that are not the real rule heading.

    The same rule heading appears in a table of contents, in a change log and in the body. The real one is the
    first occurrence followed by text (>= MIN_BODY characters, source lines such as "Regulation (EU) ..." not
    counted) before the next heading or division line. A heading that never has a body gets no anchor.
    With require_source (EASA Easy Access Rules) an occurrence followed, within its wrapped title, by the source
    line ("Regulation (EU) ..." / "ED Decision ...") is preferred."""
    occ = {}
    for i, (_, ln) in enumerate(rows):
        if flags[i]:
            key = _heading_key(ln)
            if key:
                occ.setdefault(key, []).append(i)

    def body(i):
        n = 0
        for j in range(i + 1, min(i + 600, len(rows))):
            ln = rows[j][1]
            if flags[j] or _BODY_STOP_RE.match(ln):
                break
            if len(ln) >= 25 and not _SOURCE_LINE_RE.match(ln):   # short lines are wrapped table-of-contents titles
                n += len(ln)
        return n
    def has_source(i):
        for j in range(i + 1, min(i + 5, len(rows))):
            if _SOURCE_LINE_RE.match(rows[j][1]):
                return True
            if flags[j]:
                return False
        return False
    losers = set()
    for idxs in occ.values():
        good = [i for i in idxs if not _heading_rejected(rows, flags, i) and body(i) >= MIN_BODY]
        if require_source and any(has_source(i) for i in good):
            good = [i for i in good if has_source(i)]
        keep = good[0] if good else None
        losers.update(i for i in idxs if i != keep)
    return losers


def _changelog_title(line):
    m = _AMC_FULL_RE.match(line) or _RULE_RE.match(line)
    if not m:
        return False
    rest = line[m.end(1):].strip() if _RULE_RE.match(line) and not _AMC_FULL_RE.match(line) else line[m.end():].strip()
    return bool(_CHANGELOG_TITLE_RE.match(rest))


class _ParaState:
    """Tracks (a) -> (1) -> (i) nesting inside one rule, accepting only in-sequence markers."""

    def __init__(self):
        self.l1 = None
        self.l2 = None
        self.l3 = None
        self.keys = [None, None, None]
        self.frozen = False   # a table footnote "(*)" starts: later "(a)" lines are footnote text

    GAP = 2   # repealed / deleted items leave gaps in the printed numbering: (iii) (v), 3) 5)

    def classify(self, token):
        if self.frozen:
            return None
        if token.isdigit():
            if self.keys[0] is None or token != str(int(token)):
                return None
            if self.l2 is None:
                return 2 if int(token) == 1 else None          # the first item is always 1
            nxt = self.l2 + 1
            return 2 if nxt <= int(token) <= nxt + self.GAP else None
        if token.islower():
            if self.keys[1] is not None and token in _ROMAN:
                if self.l3 is None:
                    if token == "i":
                        return 3
                else:
                    base = _ROMAN.index(self.l3) + 1 if self.l3 in _ROMAN else None
                    if base is not None and base <= _ROMAN.index(token) <= base + self.GAP:
                        return 3
            if len(token) == 1:
                base = 0 if self.l1 is None else ord(self.l1) - ord("a") + 1
                if ord(token) - ord("a") == base:   # letters: no gaps (a stray "(g)" line must not shift the list)
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


def _prune_outside(anchors):
    """Drop sub-point anchors that do not lie inside their parent anchor (a reused number elsewhere)."""
    changed = True
    while changed:
        changed = False
        for key in list(anchors):
            m = re.match(r"^(.+)\([a-z0-9]+\)$", key)
            if not m:
                continue
            if m.group(1) not in anchors:
                if key in anchors and re.match(r"^((AMC|GM|CS)\d* )?[A-Z]", key):
                    del anchors[key]   # its parent was pruned (a reused number elsewhere): drop the orphan too
                    changed = True
                continue
            ps, pe = anchors[m.group(1)]
            s, e = anchors[key]
            if not (ps <= s and e <= pe):
                for k in [k for k in anchors if k == key or k.startswith(key + "(")]:
                    del anchors[k]   # together with its own sub-points
                changed = True
    return anchors


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
        for sp in spans:
            if sp.level == 7 and sp.end is None:
                sp.end = at
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
    flags = _heading_flags(rows)
    losers = _loser_occurrences(rows, flags, require_source=(kind == "easa"))
    for idx, (start, line) in enumerate(rows):
        if idx in losers:
            continue   # repeated heading of a table of contents / change log
        if any(_TOC_LINE.search(rows[j][1]) for j in range(idx, min(idx + 4, len(rows)))):
            continue  # table-of-contents entry (dot leaders, possibly on a wrapped later line)
        if flags[idx] and (
                any(_CHANGELOG_RE.search(rows[j][1]) for j in range(idx, min(idx + 3, len(rows))))
                or (line.endswith(",") and idx + 1 < len(rows) and flags[idx + 1])
                or (idx + 1 < len(rows) and flags[idx + 1] and rows[idx + 1][1].endswith(","))
                or _changelog_title(line)):
            continue  # change log / table of contents / cross-reference list, not a heading
        mm = _AMC_FULL_RE.match(line)
        if mm and line[mm.end():].strip()[:1].islower():
            mm = None   # running text that starts with a reference ("AMC1 ORO.GEN.200(b) should be used.")
        is_head = bool(mm or _RULE_RE.match(line))
        if _PAGE_NO_TAIL.search(line) and is_head:
            continue  # table-of-contents entry whose dot leaders were lost
        mapp = _AMC_APP_RE.match(line) if kind == "easa" else None
        if mapp:
            end_all(start)
            end_app(start)
            key = mapp.group(1)
            if key not in have:
                have.add(key)
                sp = _Span(key, start, 1)
                spans.append(sp)
                group = [sp]
            state = None
            continue
        if _BOUNDARY_RE.match(line):
            end_all(start)
            end_app(start)
            continue
        if app_extra and _APPENDIX_RE.match(line):
            ma = _APPENDIX_RE.match(line)
            key = "Appendix " + ma.group(1)
            if app is not None and app.key == key and start - app.start < 200:
                continue   # the heading is printed twice in a row
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
                state = None   # paragraph numbering inside a GM/AMC is its own: no sub-keys
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
                state = None   # paragraph numbering inside a GM/AMC is its own: no sub-keys
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
        me = _EXAM_SECTION_RE.match(line)
        if me and group and group[0].key.startswith(("AMC", "GM")):
            for sp in spans:
                if sp.level == 7 and sp.end is None:
                    sp.end = start
            key = "%s SECTION %s" % (group[0].key, me.group(1))
            if key not in have:
                have.add(key)
                spans.append(_Span(key, start, 7))
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
                    sp = _Span(key, start, 1 + level)
                    # a key that already belongs to another block (or whose parent point does) is not anchored
                    sp.dummy = key in have or any(para[l].dummy for l in para if l < level)
                    if not sp.dummy:
                        have.add(key)
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
    drop = set()
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
            # when they are close; a far-away child is a different item with a reused number: it is dropped
            sp = by_key[parent]
            pend = sp.end if sp.end is not None else len(text)
            near = [k for k in kids if k.start >= sp.start and (k.end or len(text)) <= pend
                    or abs(k.start - pend) <= 20000]
            for k in kids:
                if k not in near:
                    drop.update(x.key for x in spans if x.key.startswith(k.key))
            if near:
                sp.start = min(sp.start, min(k.start for k in near))
                sp.end = max(pend, max(k.end if k.end is not None else len(text) for k in near))
    spans = [sp for sp in spans if sp.key not in drop]
    return _prune_outside(_finish(spans, len(text)))


_EU_ART_RE = re.compile(r"^Artykuł (\d+[a-z]?)$")
_EU_ANNEX_RE = re.compile(r"^ZAŁĄCZNIK(?: ([IVXLC]+))?$")
_EU_APP_RE = re.compile(r"^Dodatek (\d+)(?: do załącznika ([IVXLC]+).*)?$")
_EU_BOUNDARY_RE = re.compile(r"^(?:PODCZĘŚĆ|SEKCJA|DZIAŁ|ROZDZIAŁ|ODDZIAŁ|TYTUŁ|\[CZĘŚĆ) \S")
_EU_PARA_RE = re.compile(r"^(?:\(([ivx]{1,5})\)|([a-z])\)|(\d{1,2})\))\s*\S")
_EU_UST_RE = re.compile(r"^(\d{1,3})\.\s+\S")
_EU_DEF_RE = re.compile(r"^(\d{1,3}[a-z]?)\)\s+„")   # a numbered definition: 57) „lotnictwo ogólne” oznacza ...
_EU_PKT_RE = re.compile(r"^(\d{1,3}[a-z]?)\)\s*\S")


def _gap_ok(last, cur, maxgap=3):
    """Numbering that may skip a few numbers (repealed or removed points): cur > last, at most maxgap ahead."""
    if cur is None:
        return False
    if last is None:
        return cur[1] == "" and cur[0] <= maxgap
    if cur[0] == last[0]:
        return cur[1] > last[1]
    return last[0] < cur[0] <= last[0] + maxgap and cur[1] == ""


def eureg_anchors(text, extras=()):
    """Anchors for Polish consolidated EU regulations (EUR-Lex / CELLAR XHTML text).

    art. N | art. N ust. K | art. N pkt K | art. N ust. K pkt M       (Artykuł N; K = "K." paragraph, M = "M)" point or definition)
    załącznik [I] | dodatek N | załącznik I dodatek N | ... pkt 1.2.1    (annex; appendix; numbered row of an appendix)
    SERA.5005 | FCL.205.A | MED.A.030 | SERA.5005(a)(1)(i)             (rule of an annex and its paragraphs a) 1) (i))
    """
    spans = []
    have = set()
    art = ust = pkt = None
    last_ust = last_pkt = None
    annex = None
    annex_key = ""          # "" for a bare "ZAŁĄCZNIK"
    app = None
    app_rows = set()
    block = None
    state = None
    para = {}
    mode = "pre"

    def close(sp, at):
        if sp is not None and sp.end is None:
            sp.end = at

    def close_block(at):
        nonlocal block, state, para
        close(block, at)
        for sp in para.values():
            close(sp, at)
        block, state, para = None, None, {}

    def close_art(at):
        nonlocal art, ust, pkt
        for sp in (pkt, ust, art):
            close(sp, at)
        art = ust = pkt = None

    def add(key, start, level):
        if key in have:
            return None
        have.add(key)
        sp = _Span(key, start, level)
        spans.append(sp)
        return sp

    rows = _line_offsets(text)
    flags = _heading_flags(rows)
    losers = _loser_occurrences(rows, flags)
    for idx, (start, line) in enumerate(rows):
        if idx in losers and flags[idx] and mode == "annex":
            continue   # repeated heading of an annex table of contents
        ma = _EU_ART_RE.match(line)
        if ma and mode in ("pre", "art"):
            close_art(start)
            mode = "art"
            art = add("art. " + ma.group(1), start, 1)
            last_ust = last_pkt = None
            continue
        mx = _EU_ANNEX_RE.match(line)
        if mx:
            close_art(start)
            close_block(start)
            close(app, start)
            close(annex, start)
            for sp in spans:
                if sp.level in (4, 5) and sp.end is None:
                    sp.end = start
            app = None
            mode = "annex"
            annex_key = "załącznik" + (" " + mx.group(1) if mx.group(1) else "")
            annex = add(annex_key, start, 1)
            continue
        if mode in ("annex", "app"):
            mp = _EU_APP_RE.match(line)
            if mp:
                close_block(start)
                close(app, start)
                for sp in spans:
                    if sp.level == 4 and sp.end is None:
                        sp.end = start
                ak = ("załącznik " + mp.group(2)) if mp.group(2) else annex_key
                key = ("%s dodatek %s" % (ak, mp.group(1))) if ak and ak != "załącznik" else "dodatek " + mp.group(1)
                app = add(key, start, 1)
                app_rows = set()
                mode = "app"
                continue
            if _EU_BOUNDARY_RE.match(line):
                close_block(start)
                if mode == "app":
                    close(app, start)
                    for sp in spans:
                        if sp.level == 4 and sp.end is None:
                            sp.end = start
                    app = None
                    mode = "annex"
                continue
        if mode == "app" and app is not None:
            mr = _APP_ROW_RE.match(line)
            if mr:
                key = app.key + " pkt " + mr.group(1)
                if key not in app_rows:
                    app_rows.add(key)
                    for sp in spans:
                        if sp.level == 4 and sp.end is None:
                            sp.end = start
                    have.add(key)
                    spans.append(_Span(key, start, 4))
            continue
        if mode == "annex":
            if "annexdefs" in extras and annex is not None and mode == "annex" and annex_key:
                mdf = _EU_DEF_RE.match(line)
                if mdf:
                    key = "%s pkt %s" % (annex_key, mdf.group(1))
                    if key not in have:
                        for sp in spans:
                            if sp.level == 5 and sp.end is None:
                                sp.end = start
                        have.add(key)
                        spans.append(_Span(key, start, 5))
                    continue
            if "annexpoints" in extras and annex is not None and mode == "annex":
                mpt = _APP_ROW_RE.match(line)
                if mpt and not _RULE_RE.match(line):
                    key = ("%s pkt %s" % (annex_key, mpt.group(1))) if annex_key else None
                    if key and key not in have:
                        for sp in spans:
                            if sp.level == 5 and sp.end is None:
                                sp.end = start
                        have.add(key)
                        spans.append(_Span(key, start, 5))
                    continue
            mr = _RULE_RE.match(line)
            if mr and (mr.group(2) is None or not mr.group(2)[:1].islower()):
                if _changelog_title(line):
                    continue
                close_block(start)
                block = add(mr.group(1), start, 2)
                state = _ParaState()
                continue
            if block is not None and state is not None:
                mq = _EU_PARA_RE.match(line)
                if mq:
                    token = mq.group(1) or mq.group(2) or mq.group(3)
                    level = state.classify(token)
                    if level is not None:
                        for lv in [l for l in para if l >= level]:
                            close(para.pop(lv), start)
                        state.accept(token, level)
                        key = block.key + state.key_suffix()
                        sp = _Span(key, start, 2 + level)
                        sp.dummy = key in have
                        if not sp.dummy:
                            have.add(key)
                            spans.append(sp)
                        para[level] = sp
            continue
        if mode == "art" and art is not None:
            mu = _EU_UST_RE.match(line)
            if mu:
                nk = _num_key(mu.group(1))
                if _next_ok(last_ust, nk):
                    close(pkt, start)
                    close(ust, start)
                    pkt = None
                    last_pkt = None
                    ust = add("%s ust. %s" % (art.key, mu.group(1)), start, 2)
                    last_ust = nk
                    continue
            mk = _EU_PKT_RE.match(line)
            if mk:
                nk = _num_key(mk.group(1))
                if _gap_ok(last_pkt, nk):
                    close(pkt, start)
                    pkt = add("%s pkt %s" % ((ust or art).key, mk.group(1)), start, 3)
                    last_pkt = nk
    close_block(len(text))
    close_art(len(text))
    close(app, len(text))
    close(annex, len(text))
    for sp in spans:
        if sp.end is None:
            sp.end = len(text)
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


# --------------------------------------------------------------------------- AIP Polska (manually downloaded eAIP sections)
#
# Each eAIP page is a two-column PL | EN print. The Polish column is the left half of the page: its words start left
# of the gutter. ENR 1.1 is English only (columns "full", lang "en"); the table sections ENR 1.4 / ENR 2.1 are read
# across the whole width. The pages are listed per file in sources.json: fetch.files[{section, file, columns, lang, entries}].

_AIP_NOISE = re.compile(
    r"^(?:AIP POLSKA\b.*|AIP POLAND\b.*|(?:GEN|ENR) [\d.]+ - \d+(?: AIP POLSKA)?|\d{2} [A-Z]{3} \d{4}(?: AIP POLAND)?|"
    r"POLSKA AGENCJA ŻEGLUGI POWIETRZNEJ|AIRAC AMDT .*|AMDT\b.*|POLISH AIR NAVIGATION.*)$")
_AIP_SYMBOLS = "†‡*¤#"
AIP_HEADER_Y = 45


def _aip_split_x(page):
    """x of the gutter between the Polish and the English column: the x in 270..330 crossed by the fewest words."""
    words = page.extract_words()
    best = None
    for x in range(270, 331, 2):
        crossing = sum(1 for w in words if w["x0"] < x < w["x1"])
        key = (crossing, abs(x - 298))
        if best is None or key < best[0]:
            best = (key, x)
    return best[1]


def _aip_clean(lines):
    out = []
    for ln in lines:
        c = clean_line(ln)
        if c and not _AIP_NOISE.match(c):
            out.append(c)
    return out


def aip_file_lines(path, cfg):
    """Corpus lines of one eAIP section file. Returns (lines, page_dates)."""
    import pdfplumber

    columns = cfg.get("columns", "split")
    lines = []
    dates = []
    with pdfplumber.open(path) as pdf:
        for page in pdf.pages:
            head = " ".join((page.extract_text() or "").split("\n")[:3])
            dates.extend(re.findall(r"\b\d{2} [A-Z]{3} \d{4}\b", head))
            if columns == "split":
                split = _aip_split_x(page)
                # a word belongs to the Polish half when it STARTS left of the gutter: words that cross the gutter
                # (full-width table cells) stay whole instead of being cut in the middle
                keep = set()
                for w in page.extract_words(return_chars=True):
                    if w["x0"] < split:
                        keep.update((round(c["x0"], 2), round(c["top"], 2), c["text"]) for c in w["chars"])
                pg = page.filter(lambda o, k=keep: o["object_type"] != "char" or (o["text"].isspace() and o["x0"] < split) or (round(o["x0"], 2), round(o["top"], 2), o["text"]) in k)
            else:
                pg = page
            rows = [ln for ln in pg.extract_text_lines() if ln["top"] > AIP_HEADER_Y or not _AIP_NOISE.match(clean_line(ln["text"]))]
            rows = [ln for ln in rows if clean_line(ln["text"]) and not _AIP_NOISE.match(clean_line(ln["text"]))]
            if cfg.get("entries") == "abbreviations":
                margin = min([ln["x0"] for ln in rows] or [0])
                for ln in rows:
                    txt = clean_line(ln["text"])
                    if ln["x0"] < margin + 12:
                        first = txt.split(" ", 1)[0]
                        if first[:1] in _AIP_SYMBOLS or len(txt.split()) < 2:
                            lines.append(txt)       # legend or alphabet heading, not an entry
                        else:
                            lines.append("\x01" + txt)   # \x01 marks "an entry starts here" for the joining below
                    elif re.fullmatch(r"[A-Z]", txt):
                        continue                    # letter heading in the middle of the page
                    elif lines and lines[-1].startswith("\x01"):
                        lines[-1] += " " + txt     # continuation of the entry meaning
                    else:
                        lines.append(txt)
            else:
                lines.extend(clean_line(ln["text"]) for ln in rows)
            page.flush_cache()
    lines = [ln[1:] if ln.startswith("\x01") else ln for ln in lines]
    return lines, dates


def build_manual_corpus(src, sources_dir):
    """(text, sections) of a manual source; sections = [(section, start, end, cfg, page_dates)] in file order."""
    base = os.path.join(sources_dir, src["fetch"].get("dir", src["id"]))
    chunks = []
    sections = []
    pos = 0
    for f in src["fetch"]["files"]:
        path = os.path.join(base, f["file"])
        if not os.path.exists(path):
            raise ExtractError("%s: %s not found (place it into %s)" % (src["id"], f["file"], base))
        lines, dates = aip_file_lines(path, f)
        lines = clean_lines(lines)
        if f.get("lang", "pl") == "pl":
            lines = dehyphenate(lines)
        block = "\n".join(lines) + "\n"
        sections.append((f["section"], pos, pos + len(block), f, dates))
        chunks.append(block)
        pos += len(block)
    return "".join(chunks), sections


_AIP_HEAD_RE = re.compile(r"^(\d{1,2})\s+([A-ZĄĆĘŁŃÓŚŹŻ][A-ZĄĆĘŁŃÓŚŹŻ0-9 ,/()'’.&-]{2,})$")
_AIP_DOT_RE = re.compile(r"^(\d{1,2}(?:\.\d{1,2})+)\.?\s+\S")
_AIP_TOP_RE = re.compile(r"^(\d{1,2})\.\s+\S")
_AIP_DEF_RE = re.compile(r"^(?P<name>[A-ZĄĆĘŁŃÓŚŹŻ][A-ZĄĆĘŁŃÓŚŹŻ0-9 ,/()-]*?)\s*\((?P<abbr>[A-Z]{2,6})\)\s*[–-]\s")
_AIP_ABBR_RE = re.compile(r"^([A-Z0-9][A-Z0-9/&.\-]{0,9})[†‡*¤#]*\s+\S")
_AIP_INDICATOR_RE = re.compile(r"^.*?\b(EP[A-Z]{2})\*{0,3}(?:\s|$)")
_AIP_CLASS_RE = re.compile(r"^([A-G])\*{0,4}(?:\s|$)")


_REF_WRAPPED_RE = re.compile(
    r"(?:\b(?:ENR|GEN|AD|Załącznika|Załączniku|Załącznik|Annex|rozdziału|rozdział|pkt|punkcie|punktu|punkt|ust\.|część|części|sekcji|Part|Chapter|Appendix)|patrz:?)\s*$",
    re.I)


def _aip_pkt_key(section, number):
    return "%s pkt %s" % (section, number)


def aip_sections_anchors(text, sections):
    """Anchors of the manual AIP source (see notes §5): `ENR 1.2`, `ENR 1.2 pkt 3.1`, `GEN 2.2 CBA`, `ENR 5.2.1 TSA`,
    `ENR 1.4 klasa C`. Returns (anchors, langs)."""
    spans = []
    langs = {}
    have = set()

    def add(key, start, level):
        if key in have:
            return None
        have.add(key)
        sp = _Span(key, start, level)
        spans.append(sp)
        return sp

    for section, s0, s1, cfg, _dates in sections:
        langs[section] = cfg.get("lang") or ("pl+en" if cfg.get("columns") == "full" or cfg.get("bilingual") else "pl")
        sec = add(section, s0, 1)
        sec.end = s1
        rows = [(s0 + o, ln) for o, ln in _line_offsets(text[s0:s1]) if ln]
        mode = cfg.get("entries", "text")
        items = []   # (start, key, depth)
        if mode == "indicators":
            for start, line in rows:
                m = _AIP_INDICATOR_RE.match(line)
                if m:
                    items.append((start, "%s %s" % (section, m.group(1)), 1))
        elif mode == "abbreviations":
            for start, line in rows:
                m = _AIP_ABBR_RE.match(line)
                if m and line[:1] not in _AIP_SYMBOLS and len(line.split()) >= 2 and not line.startswith(section + " "):
                    items.append((start, "%s %s" % (section, m.group(1)), 1))
        else:
            has_heads = any(_AIP_HEAD_RE.match(ln) for _, ln in rows)
            last_top = 0
            last_head = 0
            last_class = None
            for i, (start, line) in enumerate(rows):
                if i and _REF_WRAPPED_RE.search(rows[i - 1][1]):
                    continue    # "... AIP Polska ENR⏎1.10 oraz ...": a wrapped cross-reference, not a new point
                mh = _AIP_HEAD_RE.match(line)
                if mh and int(mh.group(1)) <= 40 and not line.startswith(section.split()[0] + " "):
                    n = int(mh.group(1))
                    if last_head < n <= last_head + 4:     # headings run 1, 2, 3 ...: a stray "15 ICAO." in a cell is not one
                        last_head = n
                        items.append((start, _aip_pkt_key(section, mh.group(1)), 1))
                        continue
                md = _AIP_DOT_RE.match(line)
                if md:
                    items.append((start, _aip_pkt_key(section, md.group(1)), md.group(1).count(".") + 1))
                    continue
                mt = _AIP_TOP_RE.match(line)
                if mt and not has_heads and last_top < int(mt.group(1)) <= last_top + 3:
                    last_top = int(mt.group(1))
                    items.append((start, _aip_pkt_key(section, mt.group(1)), 1))
                    continue
                mdef = _AIP_DEF_RE.match(line)
                if mdef:
                    st = start
                    if i and rows[i - 1][1] == rows[i - 1][1].upper() and re.search(r"[A-ZĄĆĘŁŃÓŚŹŻ]{3}", rows[i - 1][1]) \
                            and not _AIP_HEAD_RE.match(rows[i - 1][1]) and not _AIP_DEF_RE.match(rows[i - 1][1]):
                        st = rows[i - 1][0]
                    items.append((st, "%s %s" % (section, mdef.group("abbr")), 1))
                    continue
                if cfg.get("classes"):
                    mc = _AIP_CLASS_RE.match(line)
                    if mc and (last_class is None or ord(mc.group(1)) == ord(last_class) + 1):
                        last_class = mc.group(1)
                        items.append((start, "%s klasa %s" % (section, mc.group(1)), 1))
        items.sort(key=lambda it: it[0])
        # end of an item: next item that is not its descendant (dotted numbers), else section end
        for idx, (start, key, depth) in enumerate(items):
            end = s1
            for start2, key2, _d in items[idx + 1:]:
                if key.split(" pkt ")[-1] != key and key2.startswith(key + ".") and " pkt " in key2:
                    continue
                end = start2
                break
            sp = add(key, start, 1 + depth)
            if sp is not None:
                sp.end = end
        # synthetic parents of dotted points whose parent line is missing (union of the children)
        for key in [k for k in list(have) if k.startswith(section + " pkt ")]:
            parts = key.split(" pkt ")[1].split(".")
            for n in range(len(parts) - 1, 0, -1):
                parent = _aip_pkt_key(section, ".".join(parts[:n]))
                kids = [sp for sp in spans if sp.key.startswith(parent + ".") and sp.key.startswith(section + " pkt ")]
                if parent not in have and kids:
                    ps = add(parent, min(k.start for k in kids), n + 1)
                    ps.end = max(k.end for k in kids)
    return _finish(spans, len(text)), langs


# --------------------------------------------------------------------------- owner-supplied ICAO / ITU documents (manual sources)
#
# kind "icao" (Doc 7300 Convention, Doc 4444 PANS-ATM) and kind "itu" (Radio Regulations Appendix 18): reference-only,
# English. The per-file "profile" in sources.json selects the reader and the anchor rules.

_EN_STOP = set("the of and shall to in that is by for with be any which state states aircraft contracting each".split())
_ICAO_ART_RE = re.compile(r"^Article (\d+)( bis| ter| quater)?\*{0,2}$")
_ICAO_PKT_RE = re.compile(r"^(\d{1,2}(?:\.\d{1,3}){1,5})\s+(?=[A-Z(])")
_ICAO_DEF_RE = re.compile(r"^([A-Z][^.:;]{1,70}?)\.\s+\S")
_ICAO_CHAPTER_HEADER = re.compile(r"^Chapter (\d+)\.\s+(.+?)\s+\d+-\d+$")
_ICAO_EVEN_HEADER = re.compile(r"^(\d+)-\d+\s+Air Traffic Management \(PANS-ATM\)$")
_ICAO_APP_HEADER = re.compile(r"^Appendix (\d+)\s+A\d+-\d+$|^A(\d+)-\d+\s+Air Traffic Management \(PANS-ATM\)$")
_ITU_CHANNEL_RE = re.compile(r"^((?:AIS|ASM) ?\d|\d{2,4})\s+(?:[a-z]{1,2}\)(?:,\s*[a-z]{1,2}\))*\s+)?\d{3}\.\d{3}")
_ITU_NOTE_RE = re.compile(r"^([a-z]{1,2})\)\s*\S")


def _english_left_half(page):
    left = page.filter(lambda o: o["object_type"] != "char" or o["x0"] < page.width / 2)
    text = left.extract_text() or ""
    words = re.findall(r"[a-z]+", text.lower())
    score = sum(1 for w in words if w in _EN_STOP) / max(1, len(words))
    return left, score, len(words)


def icao7300_lines(path, cfg):
    """English column of the 9th edition of the Convention (EN|FR spreads; only pages from Article 1 on)."""
    import pdfplumber

    lines = []
    started = False
    with pdfplumber.open(path) as pdf:
        for page in pdf.pages:
            left, score, nwords = _english_left_half(page)
            if score <= 0.12 or nwords < 80:
                continue
            rows = [clean_line(ln["text"]) for ln in left.extract_text_lines()]
            rows = [r for r in rows if r and not re.fullmatch(r"\d{1,3}", r)]
            if not started:
                if "Article 1" not in rows:
                    continue
                started = True
            lines.extend(rows)
            page.flush_cache()
    return lines


def icao4444_lines(path, cfg):
    """PANS-ATM (Doc 4444, 16th ed.): chapters from Chapter 1; running headers dropped, replaced by "Chapter N. Title" /
    "Appendix N" lines; Chapter 1 definitions joined to one line each."""
    import pdfplumber

    lines = []
    chapter = None
    started = False
    with pdfplumber.open(path) as pdf:
        for page in pdf.pages:
            rows = page.extract_text_lines()
            if not rows:
                continue
            head = clean_line(rows[0]["text"]) if rows[0]["top"] < 60 else ""
            body = [r for r in rows if 60 <= r["top"] <= 725]
            title = None
            m = _ICAO_CHAPTER_HEADER.match(head)
            if m:
                cur, title = ("Chapter", m.group(1)), m.group(2)
            elif _ICAO_EVEN_HEADER.match(head):
                cur = ("Chapter", _ICAO_EVEN_HEADER.match(head).group(1))
            elif _ICAO_APP_HEADER.match(head):
                g = _ICAO_APP_HEADER.match(head)
                cur = ("Appendix", g.group(1) or g.group(2))
            elif head == "Chapter 1" or (rows and clean_line(rows[0]["text"]) == "Chapter 1"):
                cur = ("Chapter", "1")
            else:
                cur = None
            if not started:
                if cur != ("Chapter", "1"):
                    continue
                started = True
            if cur and cur != chapter:
                chapter = cur
                if cur[0] == "Chapter":
                    lines.append(("== Chapter %s. %s ==" % (cur[1], title or "")).replace(". ==", " =="))
                else:
                    lines.append("== Appendix %s ==" % cur[1])
            is_defs = chapter == ("Chapter", "1")
            prev_end = True
            for r in body:
                txt = clean_line(r["text"])
                if not txt or re.fullmatch(r"\d{1,2}/\d{1,2}/\d{2}(?:/\d{2})?", txt):
                    continue
                if is_defs and lines:
                    first = _ICAO_DEF_RE.match(txt) and not txt.startswith(("Note", "a)", "b)", "c)", "d)"))
                    if first and (r["x0"] < 72 or prev_end):
                        lines.append(txt)
                    elif lines and not lines[-1].startswith("== "):
                        lines[-1] += " " + txt
                    else:
                        lines.append(txt)
                else:
                    lines.append(txt)
                prev_end = txt.endswith((".", "—", ":"))
            page.flush_cache()
    return lines


def itu_lines(path, cfg):
    import pdfplumber

    lo, hi = cfg.get("pages", [0, 10 ** 6])
    lines = []
    with pdfplumber.open(path) as pdf:
        for idx, page in enumerate(pdf.pages):
            if not lo <= idx <= hi:
                continue
            for ln in page.extract_text_lines():
                t = clean_line(ln["text"])
                if t and not re.fullmatch(r"AP\d+-\d+|- \d+ -", t):
                    lines.append(t)
            page.flush_cache()
    return lines


_OWNER_PROFILES = {"icao7300": icao7300_lines, "icao4444": icao4444_lines, "itu-rr": itu_lines}


def build_owner_corpus(src, sources_dir):
    base = os.path.join(sources_dir, src["fetch"].get("dir", src["id"]))
    f = src["fetch"]["files"][0]
    path = os.path.join(base, f["file"])
    if not os.path.exists(path):
        raise ExtractError("%s: %s not found (place it into %s)" % (src["id"], f["file"], base))
    lines = clean_lines(_OWNER_PROFILES[f["profile"]](path, f))
    return "\n".join(lines) + "\n", f


def owner_anchors(text, cfg):
    """Anchors: icao7300 `Article 5`, `Article 3 bis`, `Article 5(a)`; icao4444 `Chapter 5`, `Appendix 2`, `pkt 5.4.2.1`,
    `def Aerodrome control service`; itu-rr `Appendix 18`, `Appendix 18 channel 06`, `Appendix 18 note f`."""
    spans = []
    have = set()

    def add(key, start, level):
        if key in have:
            return None
        have.add(key)
        sp = _Span(key, start, level)
        spans.append(sp)
        return sp

    rows = _line_offsets(text)
    prof = cfg["profile"]
    if prof == "icao7300":
        art = None
        last_letter = None
        for start, line in rows:
            m = _ICAO_ART_RE.match(line)
            if m:
                if art is not None and art.end is None:
                    art.end = start
                for sp in spans:
                    if sp.level == 2 and sp.end is None:
                        sp.end = start
                if int(m.group(1)) > 96:
                    continue     # OCR noise: the Convention has 96 articles
                key = "Article %s%s" % (m.group(1), m.group(2) or "")
                art = add(key, start, 1)
                last_letter = None
                continue
            if art is None:
                continue
            ml = re.match(r"^([a-z])\)\s+\S", line)
            if ml:
                exp = "a" if last_letter is None else chr(ord(last_letter) + 1)
                if ml.group(1) == exp:
                    for sp in spans:
                        if sp.level == 2 and sp.end is None:
                            sp.end = start
                    add("%s(%s)" % (art.key, exp), start, 2)
                    last_letter = exp
    elif prof == "icao4444":
        chapter = None
        defs_on = False
        for start, line in rows:
            mc = re.match(r"^== Chapter (\d+)\b", line)
            ma = re.match(r"^== Appendix (\d+) ==$", line)
            if mc or ma:
                for sp in spans:
                    if sp.end is None and sp.level == 1:
                        sp.end = start
                chapter = int(mc.group(1)) if mc else None
                add("Chapter %s" % mc.group(1) if mc else "Appendix %s" % ma.group(1), start, 1)
                defs_on = bool(mc and mc.group(1) == "1")
                continue
            if defs_on:
                md = _ICAO_DEF_RE.match(line)
                if md and not line.startswith("Note"):
                    for sp in spans:
                        if sp.level == 2 and sp.end is None:
                            sp.end = start
                    add("def %s" % md.group(1), start, 2)
                continue
            mp = _ICAO_PKT_RE.match(line)
            if mp and chapter is not None and int(mp.group(1).split(".")[0]) == chapter:
                for sp in spans:
                    if sp.level >= 2 and sp.end is None and not mp.group(1).startswith(sp.key[4:] + "."):
                        sp.end = start
                add("pkt %s" % mp.group(1), start, 2 + mp.group(1).count("."))
        # synthetic ancestors (pkt 5.4.2 for pkt 5.4.2.1) as the union of their children
        for key in [k for k in list(have) if k.startswith("pkt ")]:
            parts = key[4:].split(".")
            for n in range(len(parts) - 1, 1, -1):
                parent = "pkt " + ".".join(parts[:n])
                kids = [sp for sp in spans if sp.key.startswith(parent + ".")]
                if parent not in have and kids:
                    ps = add(parent, min(k.start for k in kids), n + 1)
                    ps.end = max(k.end if k.end is not None else len(text) for k in kids)
    elif prof == "itu-rr":
        root = None
        in_notes = False
        for start, line in rows:
            if root is None and re.match(r"^APPENDIX 18\b", line):
                root = add("Appendix 18", start, 1)
                continue
            if root is None:
                continue
            if line.startswith("Notes referring to the Table"):
                in_notes = True
            if not in_notes:
                mc = _ITU_CHANNEL_RE.match(line)
                if mc:
                    for sp in spans:
                        if sp.level == 2 and sp.end is None:
                            sp.end = start
                    add("Appendix 18 channel %s" % mc.group(1).replace(" ", ""), start, 2)
            else:
                mn = _ITU_NOTE_RE.match(line)
                if mn:
                    for sp in spans:
                        if sp.level == 2 and sp.end is None:
                            sp.end = start
                    add("Appendix 18 note %s" % mn.group(1), start, 2)
    for sp in spans:
        if sp.end is None:
            sp.end = len(text)
    # an item ends at the end of its container
    return _finish(spans, len(text))


def anchors_for(src, text):
    kind = src["kind"]
    extras = tuple(src.get("anchorExtras", ()))
    if kind in ("statute", "convention"):
        future = []
        anchors = statute_anchors(text, future)
        return anchors, future
    if kind == "eu_reg":
        return eureg_anchors(text, extras), []
    if kind == "easa":
        return rule_anchors(text, kind, extras), []
    if kind == "aip":
        return aip_anchors(text), []
    raise ExtractError("%s: unknown kind %r" % (src["id"], kind))


# --------------------------------------------------------------------------- driver

def write_text(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)


def write_anchors(path, text_sha, anchors, future=(), langs=None):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    rows = ",\n".join("    %s: [%d, %d]" % (json.dumps(k, ensure_ascii=False), s, e)
                      for k, (s, e) in anchors.items())
    fut = ""
    if future:
        fut = ',\n  "future": [%s]' % ", ".join("[%d, %d]" % (a, b) for a, b in future)
    if langs and any(v != "pl" for v in langs.values()):
        fut += ',\n  "langs": %s' % json.dumps({k: v for k, v in langs.items() if v != "pl"}, ensure_ascii=False, sort_keys=True)
    body = '{\n  "textSha": "%s",\n  "anchors": {\n%s\n  }%s\n}\n' % (text_sha, rows, fut)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(body)


def extract_one(src, sources_dir, corpus_dir, anchors_dir):
    if (src.get("fetch") or {}).get("mode") == "manual" and src["kind"] in ("icao", "itu"):
        text, cfg = build_owner_corpus(src, sources_dir)
        sha = hashlib.sha256(text.encode("utf-8")).hexdigest()
        anchors = owner_anchors(text, cfg)
        write_text(os.path.join(corpus_dir, src["id"] + ".txt"), text)
        write_anchors(os.path.join(anchors_dir, src["id"] + ".json"), sha, anchors, (), {src["id"]: "en"})
        return src["id"], len(text), len(anchors)
    if (src.get("fetch") or {}).get("mode") == "manual":
        text, sections = build_manual_corpus(src, sources_dir)
        sha = hashlib.sha256(text.encode("utf-8")).hexdigest()
        anchors, langs = aip_sections_anchors(text, sections)
        write_text(os.path.join(corpus_dir, src["id"] + ".txt"), text)
        write_anchors(os.path.join(anchors_dir, src["id"] + ".json"), sha, anchors, (), langs)
        return src["id"], len(text), len(anchors)
    path = os.path.join(sources_dir, src["id"], "%s.%s" % (src["id"], src["format"]))
    if not os.path.exists(path):
        raise ExtractError("%s: %s not found (run fetch_sources.py first)" % (src["id"], path))
    text = build_corpus_text(src, path)
    sha = hashlib.sha256(text.encode("utf-8")).hexdigest()
    anchors, future = anchors_for(src, text)
    write_text(os.path.join(corpus_dir, src["id"] + ".txt"), text)
    write_anchors(os.path.join(anchors_dir, src["id"] + ".json"), sha, anchors, future)
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
