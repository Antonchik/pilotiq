import json
import random
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import convert as c  # noqa: E402
import validate as v  # noqa: E402

LEGACY_DIR = HERE.parent / "legacy"


def row(page, lp, number, q, a1="Odp 1", a2="Odp 2", a3="Odp 3", a4="Odp 4"):
    return {"page": page, "cells": [lp, number, q, a1, a2, a3, a4]}


HEADER = row(1, "L.p.", "NUMER", "PYTANIE", "ODP1", "ODP2", "ODP3", "ODP4")
SPEC_PL = {"bilingual": False, "file": "x.pdf", "sha256": "0" * 64, "date": "2024-07-26", "kind": "pdf"}


def convert_rows(rows, spec=SPEC_PL, lex=None):
    stats = c.Stats()
    records = c.build_records(rows, stats)
    questions = c.build_questions(records, spec, lex, stats)
    return questions, stats


class JoinLinesTest(unittest.TestCase):
    def test_wrap_with_trailing_space(self):
        self.assertEqual(c.join_lines(["Do czego jest ", "zobowiązany ", "dowódca?"]), "Do czego jest zobowiązany dowódca?")

    def test_mid_word_break_without_space(self):
        self.assertEqual(c.join_lines(["najprawdopodobni", "ej świadczą:"]), "najprawdopodobniej świadczą:")

    def test_hyphen_at_line_end(self):
        self.assertEqual(c.join_lines(["badania lotniczo-", "lekarskie"]), "badania lotniczo-lekarskie")

    def test_entities_and_whitespace(self):
        self.assertEqual(c.clean_text("H&lt;sub&gt;2&lt;/sub&gt;O    test"), "H<sub>2</sub>O test")


class StraySpaceTest(unittest.TestCase):
    @staticmethod
    def ch(text, x0, x1):
        return {"text": text, "x0": x0, "x1": x1}

    def test_overlapping_invisible_spaces_are_dropped(self):
        # "w" (318.7-326.6) with two spaces lying on top of it, then a real space after "go"
        line = [self.ch(" ", 313.2, 314.7), self.ch("w", 318.7, 326.6), self.ch(" ", 319.7, 322.2),
                self.ch(" ", 322.2, 324.7), self.ch("ł", 326.6, 329.4), self.ch("a", 329.4, 334.7),
                self.ch(" ", 334.7, 337.2), self.ch("x", 337.2, 342.0)]
        text = "".join(k["text"] for k in c._without_stray_spaces(line))
        self.assertEqual(" włą".replace("ą", "a") + " x", text)

    def test_touching_spaces_are_kept(self):
        line = [self.ch("a", 0.0, 5.0), self.ch(" ", 4.9, 7.4), self.ch("b", 7.3, 12.0)]
        self.assertEqual("a b", "".join(k["text"] for k in c._without_stray_spaces(line)))


class RecordsTest(unittest.TestCase):
    def test_continuation_across_pages_is_merged(self):
        rows = [
            HEADER,
            row(1, "5", "PL010-0005", "Kiedy ustaje obowiązek pomocy, który ", "A ", "B", "C", "D"),
            row(2, "", "", "spostrzegł inny statek?", "", "", "", ""),
            row(2, "6", "PL010-0006", "Drugie pytanie?"),
        ]
        qs, stats = convert_rows(rows)
        self.assertEqual(stats.header_rows, 1)
        self.assertEqual(stats.merged_rows, 1)
        self.assertEqual(len(qs), 2)
        self.assertEqual(qs[0]["q"]["pl"], "Kiedy ustaje obowiązek pomocy, który spostrzegł inny statek?")
        self.assertEqual(stats.table_rows, stats.header_rows + stats.merged_rows + len(qs) + len(stats.discarded) + len(stats.exact_duplicates))

    def test_number_normalisation(self):
        qs, _ = convert_rows([HEADER, row(1, "1", "PL 100-0126", "Pytanie?")])
        self.assertEqual(qs[0]["id"], "PL100-0126")
        self.assertEqual(qs[0]["number"], "PL100-0126")
        self.assertEqual(qs[0]["topic"], "PL100")
        self.assertEqual(qs[0]["subject"], "air_law")

    def test_pl021_is_aircraft_general_knowledge(self):
        qs, _ = convert_rows([HEADER, row(1, "1", "PL021-0001", "Pytanie?")])
        self.assertEqual(qs[0]["subject"], "aircraft_general_knowledge")

    def test_garbage_is_dropped_with_reason(self):
        rows = [
            HEADER,
            row(1, "1", "PL010-0001", "OK?"),
            row(1, "2", "PL010-0002", "Pusta odpowiedź?", a3=""),
            row(1, "3", "PL010-0003", ""),
            row(1, "4", "", "Brak numeru?"),
            row(1, "5", "Kąt znoszenia", "Zły numer?"),
            row(1, "6", "PL999-0001", "Nieznany temat?"),
        ]
        qs, stats = convert_rows(rows)
        self.assertEqual([q["id"] for q in qs], ["PL010-0001"])
        reasons = sorted(r for _, _, r in stats.discarded)
        self.assertEqual(reasons, ["empty NUMER", "empty answer", "empty question", "invalid NUMER",
                                   "unknown topic prefix PL999"])

    def test_html_entities_decoded(self):
        qs, _ = convert_rows([HEADER, row(1, "1", "PL050-0001", "Wzór H&lt;sub&gt;2&lt;/sub&gt;O?")])
        self.assertEqual(qs[0]["q"]["pl"], "Wzór H<sub>2</sub>O?")


class IdsTest(unittest.TestCase):
    ROWS = [
        HEADER,
        row(1, "1", "PL010-0100", "Pytanie A?", "Dobra A", "x1", "x2", "x3"),
        row(1, "2", "PL010-0100", "Pytanie B?", "Dobra B", "y1", "y2", "y3"),
        row(2, "3", "PL010-0101", "Unikalne?"),
    ]

    def test_variants_get_hash_suffix_and_unique_number_does_not(self):
        qs, _ = convert_rows(self.ROWS)
        ids = [q["id"] for q in qs]
        self.assertEqual(len(ids), 3)
        self.assertIn("PL010-0101", ids)
        suffixed = [i for i in ids if i.startswith("PL010-0100~")]
        self.assertEqual(len(suffixed), 2)
        self.assertTrue(all(len(i.split("~")[1]) == 6 for i in suffixed))

    def test_ids_do_not_depend_on_row_order(self):
        body = self.ROWS[1:]
        base = {q["id"]: q["q"]["pl"] for q in convert_rows([HEADER] + body)[0]}
        for seed in range(5):
            shuffled = body[:]
            random.Random(seed).shuffle(shuffled)
            got = {q["id"]: q["q"]["pl"] for q in convert_rows([HEADER] + shuffled)[0]}
            self.assertEqual(got, base)

    def test_exact_duplicate_is_collapsed(self):
        rows = [HEADER, row(1, "1", "PL010-0100", "Pytanie?"), row(3, "9", "PL010-0100", "Pytanie?")]
        qs, stats = convert_rows(rows)
        self.assertEqual(len(qs), 1)
        self.assertEqual(qs[0]["id"], "PL010-0100")
        self.assertEqual(stats.exact_duplicates, [(3, "PL010-0100", "exact", 1)])

    def test_near_duplicate_differing_in_spaces_and_case_is_collapsed(self):
        rows = [HEADER,
                row(1, "1", "PL010-0100", "Do 200 m. lotu ?", "Dozwolone", "a", "b", "c"),
                row(2, "2", "PL010-0100", "Do 200m. lotu?", "dozwolone", "a", "b", "c")]
        qs, stats = convert_rows(rows)
        self.assertEqual(len(qs), 1)
        self.assertEqual(qs[0]["id"], "PL010-0100")
        self.assertEqual(stats.exact_duplicates, [(2, "PL010-0100", "near", 1)])

    def test_different_sign_is_not_a_duplicate(self):
        rows = [HEADER,
                row(1, "1", "PL060-0100", "Dewiacja?", "-3", "a", "b", "c"),
                row(2, "2", "PL060-0100", "Dewiacja?", "3", "a", "b", "c")]
        qs, _ = convert_rows(rows)
        self.assertEqual(len(qs), 2)

    def test_duplicate_keeps_the_better_english_text(self):
        spec = dict(SPEC_PL, bilingual=True)
        lex = c.build_lexicon(str(LEGACY_DIR))
        def r(page, tail):
            return row(page, str(page), "PL010-0143", "Lot VFR jest dozwolony: Day VFR flight is allowed:",
                       "Przy zmniejszeniu widzialności do 1500 m. " + tail, "Nie. No.", "Tak. Yes.", "Może. Maybe.")
        rows = [HEADER, r(1, "wwith flight visibility decreased to 1500 m."), r(2, "With flight visibility decreased to 1500 m.")]
        qs, stats = convert_rows(rows, spec, lex)
        self.assertEqual(len(qs), 1)
        self.assertTrue(qs[0]["a"][0]["en"].startswith("With"))
        self.assertEqual(stats.exact_duplicates[0][3], 2)

    def test_ids_do_not_depend_on_the_splitter(self):
        spec = dict(SPEC_PL, bilingual=True)
        rows = [HEADER,
                row(1, "1", "PL010-0100", "Pytanie A? Question A?", "Dobra. Good.", "x. x.", "y. y.", "z. z."),
                row(1, "2", "PL010-0100", "Pytanie B? Question B?", "Dobra. Good.", "x. x.", "y. y.", "z. z.")]
        full = c.build_lexicon(str(LEGACY_DIR))
        empty = c.Lexicon({}, {})
        ids_a = sorted(q["id"] for q in convert_rows(rows, spec, full)[0])
        ids_b = sorted(q["id"] for q in convert_rows(rows, spec, empty)[0])
        self.assertEqual(ids_a, ids_b)

    def test_same_question_and_correct_answer_but_different_distractors(self):
        rows = [HEADER,
                row(1, "1", "PL010-0100", "Pytanie?", "Dobra", "a", "b", "c"),
                row(1, "2", "PL010-0100", "Pytanie?", "Dobra", "a", "b", "d")]
        qs, _ = convert_rows(rows)
        self.assertEqual(len({q["id"] for q in qs}), 2)

    def test_output_is_deterministic_and_valid(self):
        qs, _ = convert_rows(self.ROWS)
        source = {"file": "x.pdf", "sha256": "0" * 64, "date": "2024-07-26", "kind": "pdf"}
        a = c.dumps_bank("bpl", source, qs)
        b = c.dumps_bank("bpl", source, convert_rows(self.ROWS)[0])
        self.assertEqual(a, b)
        data = json.loads(a)
        self.assertEqual(data["schema"], 2)
        self.assertEqual([q["id"] for q in data["questions"]], sorted(q["id"] for q in data["questions"]))
        self.assertEqual(data["questions"][0]["correct"], 0)


class SplitTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.lex = c.build_lexicon(str(LEGACY_DIR))
        with open(HERE / "fixtures" / "split_examples.json", encoding="utf-8") as f:
            cls.examples = json.load(f)

    def test_examples(self):
        for ex in self.examples:
            pl, en, flag = c.split_cell(ex["mixed"], self.lex)
            self.assertEqual((pl, en, flag), (ex["pl"], ex["en"], "ok"), ex["mixed"])

    def test_repeated_digits_cell_is_collapsed(self):
        self.assertEqual(c.split_cell("225°; 225°;", self.lex), ("225°;", "225°;", "ok"))
        self.assertEqual(c.split_cell("1000 m 1000 m", self.lex), ("1000 m", "1000 m", "ok"))

    def test_digits_only_cell_is_neutral(self):
        self.assertEqual(c.split_cell("1500", self.lex), ("1500", "1500", "neutral"))

    def test_polish_only_text_is_not_split(self):
        pl, en, flag = c.split_cell("Dozwolone tylko wtedy, gdy lot nie narusza ograniczeń.", self.lex)
        self.assertIsNone(en)

    def test_bilingual_question_end_to_end(self):
        spec = dict(SPEC_PL, bilingual=True)
        rows = [HEADER, row(1, "1", "PL 100-0126",
                            "Załoga statku powietrznego ma obowiązek zapinania wszystkich pasów bezpieczeństwa i uprzęży: "
                            "The crew members are required to fasten all seat belts and harnesses:",
                            "Do startu i do lądowania. For take off and landing.",
                            "Tylko do lądowania. Only for landing.",
                            "Tylko na polecenie dowódcy. Only on the commander's order.",
                            "Zawsze. Always.")]
        qs, _ = convert_rows(rows, spec, self.lex)
        q = qs[0]
        self.assertEqual(q["q"]["en"], "The crew members are required to fasten all seat belts and harnesses:")
        self.assertEqual(q["a"][1], {"pl": "Tylko do lądowania.", "en": "Only for landing."})
        self.assertEqual(q["a"][0]["pl"], "Do startu i do lądowania.")


class ValidateTest(unittest.TestCase):
    def write(self, questions, tmp):
        data = {"schema": 2, "licence": "bpl",
                "source": {"file": "x.pdf", "sha256": "0" * 64, "date": "2024-07-26", "kind": "pdf"},
                "questions": questions}
        path = Path(tmp) / "bank_bpl.json"
        path.write_text(json.dumps(data), encoding="utf-8")
        return path

    def question(self, number, subject="human_performance"):
        return {"id": number, "number": number, "topic": number.split("-")[0], "subject": subject,
                "q": {"pl": "Q?", "en": None},
                "a": [{"pl": f"a{i}", "en": None} for i in range(4)], "correct": 0}

    def test_detects_entities_and_split_words(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            q = self.question("PL040-0003")
            q["a"][0]["pl"] = "od s t r o m ego"
            q["q"]["en"] = "Q &amp; A"
            errors, _, _ = v.validate_bank(self.write([q], tmp))
            self.assertTrue(any("inside a word" in e for e in errors))
            self.assertTrue(any("HTML entity" in e for e in errors))

    def test_warns_about_word_broken_by_a_space(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            qs = []
            for i in range(1, 15):
                q = self.question(f"PL040-{i:04d}")
                q["a"][0]["pl"] = "zezwolenia właściwego organu" if i < 5 else "zezwolenia w łaściwego organu" if i == 14 else "inne"
                qs.append(q)
            qs[0]["a"][1]["pl"] = qs[1]["a"][1]["pl"] = qs[2]["a"][1]["pl"] = qs[3]["a"][1]["pl"] = "właściwego"
            _, warnings, _ = v.validate_bank(self.write(qs, tmp))
            self.assertTrue(any("'w' + 'łaściwego'" in w for w in warnings), warnings)

    def test_detects_violations(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            qs = [self.question("PL040-0001") for _ in range(2)]
            errors, _, _ = v.validate_bank(self.write(qs, tmp))
            self.assertTrue(any("duplicate id" in e for e in errors))
            self.assertTrue(any("quizLength" in e for e in errors))
            q = self.question("PL040-0002")
            q["a"][1]["pl"] = ""
            q["correct"] = 2
            errors, _, _ = v.validate_bank(self.write([q], tmp))
            self.assertTrue(any("answer 1 is empty" in e for e in errors))
            self.assertTrue(any("correct must be 0" in e for e in errors))

    def test_accepts_valid_bank(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            qs = [self.question(f"PL040-{i:04d}") for i in range(1, 13)]
            errors, warnings, n = v.validate_bank(self.write(qs, tmp))
            self.assertEqual((errors, warnings, n), ([], [], 12))


if __name__ == "__main__":
    unittest.main()
