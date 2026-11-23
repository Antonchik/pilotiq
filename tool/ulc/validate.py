#!/usr/bin/env python3
"""Validate generated question banks (assets/data/bank_*.json).

    python3 tool/ulc/validate.py assets/data/bank_*.json

Exit code 0 = all banks are valid, 1 = violations found, 2 = unreadable input.
"""

import json
import re
import sys
from pathlib import Path

import convert
from convert import LICENCES, NUMBER_RE, QUIZ_LENGTH, SCHEMA, SUBJECTS, TOPIC_TO_SUBJECT

ENTITY_RE = re.compile(r"&#?\w+;")
# four or more single lower-case letters separated by single spaces ("od s t r o m ego")
SPLIT_WORD_RE = re.compile(r"(?<![\w])(?:[^\W\d_A-Z] ){3,}[^\W\d_A-Z](?![\w])")
ID_RE = re.compile(r"^PL\d{3}-\d{4}(~[0-9a-f]{6})?$")


def _all_texts(q):
    texts = []
    for cell in [q.get("q")] + list(q.get("a") or []):
        if isinstance(cell, dict):
            texts.extend(t for t in (cell.get("pl"), cell.get("en")) if isinstance(t, str))
    return texts


def _tokens(text):
    return [t.strip(".,;:!?()\"'„”«»") for t in text.split()]


def _split_word_warnings(questions):
    """Warn about 'w łaściwego': a one-letter token followed by a token that is not a word of its
    own, while the glued form is a word used at least 3 times elsewhere in the same bank."""
    counts = {}
    for q in questions:
        if isinstance(q, dict):
            for text in _all_texts(q):
                for t in _tokens(text):
                    counts[t] = counts.get(t, 0) + 1
    out, seen = [], set()
    for q in questions:
        if not isinstance(q, dict):
            continue
        for text in _all_texts(q):
            toks = _tokens(text)
            for a, b in zip(toks, toks[1:]):
                if len(a) == 1 and a.isalpha() and len(b) >= 3 and counts.get(b, 0) <= 1 and counts.get(a + b, 0) >= 3:
                    if (a, b) not in seen:
                        seen.add((a, b))
                        out.append(f"{q.get('id')}: possibly a word broken by a space: {a!r} + {b!r}")
    return out


def validate_bank(path):
    errors = []
    warnings = []
    try:
        with open(path, encoding="utf-8") as f:
            bank = json.load(f)
    except (OSError, ValueError) as e:
        return [f"cannot read JSON: {e}"], [], 0
    if bank.get("schema") != SCHEMA:
        errors.append(f"schema must be {SCHEMA}, got {bank.get('schema')!r}")
    if bank.get("licence") not in LICENCES:
        errors.append(f"unknown licence {bank.get('licence')!r}")
    src = bank.get("source")
    if not isinstance(src, dict) or not all(src.get(k) for k in ("file", "sha256", "date", "kind")):
        errors.append("source must contain file, sha256, date, kind")
    questions = bank.get("questions")
    if not isinstance(questions, list) or not questions:
        return errors + ["no questions"], warnings, 0

    seen = set()
    per_subject = {}
    multi = {}
    for i, q in enumerate(questions):
        where = f"question #{i} ({q.get('id') if isinstance(q, dict) else '?'})"
        if not isinstance(q, dict):
            errors.append(f"{where}: not an object")
            continue
        qid, number = q.get("id"), q.get("number")
        if not isinstance(qid, str) or not ID_RE.match(qid):
            errors.append(f"{where}: bad id")
        elif qid in seen:
            errors.append(f"{where}: duplicate id")
        else:
            seen.add(qid)
        if not isinstance(number, str) or not NUMBER_RE.match(number):
            errors.append(f"{where}: bad number {number!r}")
            continue
        if isinstance(qid, str) and qid.split("~")[0] != number:
            errors.append(f"{where}: id does not start with number {number}")
        topic = number.split("-")[0]
        if q.get("topic") != topic:
            errors.append(f"{where}: topic {q.get('topic')!r} != {topic}")
        if q.get("subject") not in SUBJECTS:
            errors.append(f"{where}: invalid subject {q.get('subject')!r}")
        elif TOPIC_TO_SUBJECT.get(topic) != q["subject"]:
            errors.append(f"{where}: subject {q['subject']} does not match topic {topic}")
        if q.get("correct") != 0:
            errors.append(f"{where}: correct must be 0")
        qt = q.get("q")
        if not isinstance(qt, dict) or not isinstance(qt.get("pl"), str) or not qt["pl"].strip():
            errors.append(f"{where}: empty question text")
        elif qt.get("en") is not None and (not isinstance(qt["en"], str) or not qt["en"].strip()):
            errors.append(f"{where}: empty question en (use null)")
        answers = q.get("a")
        if not isinstance(answers, list) or len(answers) != 4:
            errors.append(f"{where}: need exactly 4 answers")
        else:
            for j, a in enumerate(answers):
                if not isinstance(a, dict) or not isinstance(a.get("pl"), str) or not a["pl"].strip():
                    errors.append(f"{where}: answer {j} is empty")
                elif a.get("en") is not None and (not isinstance(a["en"], str) or not a["en"].strip()):
                    errors.append(f"{where}: answer {j} en is empty (use null)")
            if all(isinstance(a, dict) and isinstance(a.get("pl"), str) for a in answers):
                texts = [a["pl"] for a in answers]
                if len(set(texts)) < 4:
                    warnings.append(f"{where}: identical answer texts in the source")
        if isinstance(qid, str):
            if "~" in qid:
                multi[number] = multi.get(number, 0) + 1
            per_subject[q.get("subject")] = per_subject.get(q.get("subject"), 0) + 1
        for text in _all_texts(q):
            if ENTITY_RE.search(text):
                errors.append(f"{where}: HTML entity left in text: {ENTITY_RE.search(text).group()!r}")
                break
        for text in _all_texts(q):
            if text[:1] in (";", ","):
                errors.append(f"{where}: text starts with a separator: {text[:20]!r}")
                break
        if isinstance(answers, list) and any(isinstance(a, dict) and a.get("en") for a in answers):
            for j, a in enumerate(answers):
                if isinstance(a, dict) and isinstance(a.get("pl"), str) and convert._identical_halves(a["pl"]):
                    errors.append(f"{where}: answer {j} is a doubled text in a translated question: {a['pl'][:40]!r}")
        for text in _all_texts(q):
            m = SPLIT_WORD_RE.search(text)
            if m:
                errors.append(f"{where}: letters separated by spaces inside a word: {m.group()!r}")
                break
    warnings.extend(_split_word_warnings(questions))
    for number, c in multi.items():
        if c < 2:
            errors.append(f"{number}: id has a hash suffix but the NUMER is unique")
    for sid, n in sorted(per_subject.items()):
        if sid in QUIZ_LENGTH and n < QUIZ_LENGTH[sid]:
            errors.append(f"subject {sid}: {n} questions < quizLength {QUIZ_LENGTH[sid]}")
    ids = [q.get("id") for q in questions if isinstance(q, dict)]
    if ids != sorted(ids):
        errors.append("questions are not sorted by id")
    return errors, warnings, len(questions)


def audit_bank(bank, lex):
    """Whole-bank sweeps; each returns a list of (id, detail). Used by `validate.py --audit`."""
    out = {"a_numbers": [], "b_mixed": [], "c_en_start": [], "d_equal_pl": [], "e_boundary": [], "h_en_lower_tail": [], "f_polish_in_en": [], "g_tail": [], "info_spelling": []}
    for q in bank["questions"]:
        cells = [q["q"]] + q["a"]
        names = ["q"] + [f"a{i}" for i in range(4)]
        for name, c in zip(names, cells):
            if c["en"]:
                dp, de = convert.digits(c["pl"]), convert.digits(c["en"])
                if dp and de and dp != de:
                    out["a_numbers"].append((q["id"], f"{name}: {c['pl'][:50]!r} | {c['en'][:50]!r}"))
                if c["en"] != c["pl"] and convert.starts_polish(c["en"], lex):
                    out["c_en_start"].append((q["id"], f"{name}: {c['en'][:60]!r}"))
                if c["en"] != c["pl"]:
                    bad = convert.boundary_looks_wrong(c["pl"], c["en"])
                    all_lower = name != "q" and all((a["en"] or "")[:1].islower() for a in q["a"])
                    if bad and not (all_lower and bad.startswith("EN starts in lower case")):
                        out["e_boundary"].append((q["id"], f"{name}: {bad}: {c['pl'][-25:]!r} | {c['en'][:25]!r}"))
                    if convert.polish_in_english(c["en"], lex):
                        out["f_polish_in_en"].append((q["id"], f"{name}: {c['en'][:70]!r}"))
        nulls = [a["en"] is None for a in q["a"]]
        if not all(nulls):  # translated question: list punctuation ; , is dropped from every answer alike
            for j, a in enumerate(q["a"]):
                if a["pl"].rstrip()[-1:] in ";," or (a["en"] or "").rstrip()[-1:] in ";,":
                    out["g_tail"].append((q["id"], f"a{j}: {a['pl'][-20:]!r} | {(a['en'] or '')[-20:]!r}"))
        if any(nulls) and not all(nulls):
            out["b_mixed"].append((q["id"], "some answers have en=null, others not"))
        elif not all(nulls):
            # answers whose Polish and English texts are the same apart from punctuation/spacing:
            # either all of them are identical strings or none (no mixed "0,8;" / "0,8" forms)
            near = [a for a in q["a"] if convert.fold(a["pl"]) == convert.fold(a["en"])]
            exact = [a for a in near if a["pl"] == a["en"]]
            if exact and len(exact) != len(near):
                out["info_spelling"].append((q["id"], "same text in both languages, but written differently: "
                                       + "; ".join(f"{a['pl'][:20]!r}|{a['en'][:20]!r}" for a in near if a["pl"] != a["en"])))
            if any(a["pl"][:1] in ";,." or (a["en"] or "")[:1] in ";,." for a in q["a"]):
                out["b_mixed"].append((q["id"], "separator at the start of an answer"))
        for j, a in enumerate(q["a"]):
            if a["en"] and a["en"] != a["pl"] and convert._LOWER_TAIL.search(a["en"]):
                out["h_en_lower_tail"].append((q["id"], f"a{j}: ...{a['en'][-45:]!r}"))
        seen = {}
        for j, a in enumerate(q["a"]):
            key = a["pl"].casefold().replace(" ", "")
            if key in seen and q["a"][seen[key]]["en"] != a["en"]:
                out["d_equal_pl"].append((q["id"], f"a{seen[key]}/a{j}: {a['pl'][:50]!r}"))
            seen.setdefault(key, j)
    return out


def main(argv):
    if argv and argv[0] == "--audit":
        lex = convert.build_lexicon(str(Path(convert.HERE) / "legacy"))
        for arg in argv[1:]:
            with open(arg, encoding="utf-8") as f:
                res = audit_bank(json.load(f), lex)
            print(f"== {arg}")
            for key, items in res.items():
                print(f"  {key}: {len(items)}")
                for qid, detail in items:
                    print(f"     {qid}  {detail}")
        return 0
    if not argv:
        print(__doc__)
        return 2
    failed = False
    for arg in argv:
        errs, warns, n = validate_bank(Path(arg))
        if errs:
            failed = True
            print(f"FAIL {arg}: {len(errs)} problem(s)")
            for e in errs[:50]:
                print("  -", e)
            if len(errs) > 50:
                print(f"  ... and {len(errs) - 50} more")
        else:
            print(f"OK   {arg}: {n} questions" + (f", {len(warns)} warning(s)" if warns else ""))
        for w in warns[:20]:
            print("  warning:", w)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
