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

    def test_duplicate_with_wrong_english_number_loses(self):
        spec = dict(SPEC_PL, bilingual=True)
        lex = c.build_lexicon(str(LEGACY_DIR))
        def r(page, tail):
            return row(page, str(page), "PL010-0058", "Dolna granica TMA? The lower TMA limit?",
                       "Nie niżej niż 200 m AGL. " + tail, "Na ziemi. On the ground.", "Nigdy. Never.", "Zawsze. Always.")
        rows = [HEADER, r(1, "Not less than 20m AGL."), r(2, "Not less than 200m AGL.")]
        qs, stats = convert_rows(rows, spec, lex)
        self.assertEqual(len(qs), 1)
        self.assertEqual(qs[0]["a"][0]["en"], "Not less than 200m AGL.")
        self.assertEqual(stats.exact_duplicates[0][2], "en")

    def test_duplicate_found_by_full_cell_text_despite_a_bad_split(self):
        # PL060-0093: "Duże miasto.A large city." vs "Duże miasto. A large city." (+ "/n" artifact in the question)
        spec = dict(SPEC_PL, bilingual=True)
        lex = c.build_lexicon(str(LEGACY_DIR))
        def r(page, a0, q):
            return row(page, str(page), "PL060-0093", q, a0, "Wieś. Village.", "Brzeg morza. Sea shore.", "Droga. Road.")
        q1 = "Wybierz obiekt: Select the landmark: /n"
        q2 = "Wybierz obiekt: Select the landmark:"
        qs, stats = convert_rows([HEADER, r(1, "Duże miasto. A large city.", q1), r(2, "Duże miasto.A large city.", q2)], spec, lex)
        self.assertEqual(len(qs), 1)
        self.assertEqual(qs[0]["id"], "PL060-0093")
        self.assertEqual(qs[0]["a"][0], {"pl": "Duże miasto.", "en": "A large city."})

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
        self.assertEqual(c.split_cell("225°; 225°;", self.lex), ("225°", "225°", "twin"))
        self.assertEqual(c.split_cell("1000 m 1000 m", self.lex), ("1000 m", "1000 m", "twin"))

    def test_doubled_cells_with_odd_separators(self):
        for text, half in [("135° ; 135°;", "135°"), ("315°;315°;", "315°"), ("5 ; 5", "5"),
                           ("360. 360 .", "360."), ("003°, 359° ; 003°, 359°", "003°, 359°"),
                           ("4,1,2,5,3,6; 4,1,2,5,3,6; ,", "4,1,2,5,3,6"), ("17 US gal . 17 US gal.", "17 US gal")]:
            pl, en, flag = c.split_cell(text, self.lex)
            self.assertEqual((pl, en, flag), (half, half, "twin") if half != "17 US gal" else ("17 US gal.", "17 US gal.", "twin"), text)
            self.assertFalse(pl[:1] in ";,." or en[:1] in ";,.", text)

    def assess(self, texts):
        return c.assess_question(texts, self.lex)

    def test_mixed_doubled_and_single_answers_are_all_kept_as_in_source(self):
        texts = ["Który kurs? Which heading?", "135° ; 135°;", "270°", "315°;315°;", "5 ; 5"]
        cells, flags, reasons, _ = self.assess(texts)
        self.assertTrue(any("doubled" in r for r in reasons))
        self.assertEqual(cells, [{"pl": t, "en": None} for t in texts])

    def test_uniformly_doubled_answers_are_collapsed(self):
        texts = ["Który kurs? Which heading?", "135° ; 135°;", "270°;270°;", "315°;315°;", "5 ; 5"]
        cells, _, reasons, _ = self.assess(texts)
        self.assertEqual(reasons, [])
        self.assertEqual([x["pl"] for x in cells[1:]], ["135°", "270°", "315°", "5"])
        self.assertTrue(all(x["pl"] == x["en"] for x in cells[1:]))

    def test_polish_word_moved_into_english_means_source_form_for_all_answers(self):
        # PL080-0226: the last Polish word of every answer ended up in the English part
        texts = ["W życiu spotykamy się ze stanem równowagi: In everyday life we meet the state of equilibrium:",
                 "- stałej ; - obojętnej; - chwiejnej -fixed -neutral- unstable",
                 "- stałej ; - chwiejnej; - ruchomej -fixed -unstable- mobile",
                 "- stałej ; - obojętnej; - ruchomej -fixed- neutral- mobile",
                 "- nieobojętnej; - obojętnej; - chwiejnej -indifferent- indifferent- unstable"]
        cells, _, reasons, _ = self.assess(texts)
        self.assertEqual(cells, [{"pl": t, "en": None} for t in texts])

    def test_number_in_polish_part_misplaced_into_english(self):
        # PL040-0311: "4 tys.4" / "thousand."
        texts = ["Wysokość? Height?", "4 tys. 4 thousand.", "3 tys. 3 thousand.", "5 tys. 5 thousand.", "6 tys. 6 thousand."]
        cells, _, reasons, _ = self.assess(texts)
        for x in cells[1:]:
            self.assertFalse(x["pl"].endswith("tys.4"))
            self.assertNotEqual(x["en"], "thousand.")

    def test_numbers_must_agree_between_pl_and_en(self):
        texts = ["Dolna granica? Lower limit?", "Nie niżej niż 200 m AGL. Not less than 20m AGL.",
                 "Na ziemi. On the ground.", "Nie niżej niż 560 m AMSL. Not lower than 560 m AMSL.", "Nigdy. Never."]
        cells, _, reasons, _ = self.assess(texts)
        self.assertTrue(any("numbers differ" in r for r in reasons))
        self.assertTrue(all(x["en"] is None for x in cells))

    def test_equal_polish_text_from_different_cells_is_not_trusted(self):
        texts = ["Pytanie? Question?", "Według prawa państwa. According to the court law.",
                 "Według prawa państwa. According to the law.", "Inaczej. Otherwise.", "Nigdy. Never."]
        cells, _, reasons, _ = self.assess(texts)
        self.assertTrue(any("equal Polish text" in r for r in reasons))
        self.assertTrue(all(x["en"] is None for x in cells))

    def test_english_part_must_not_repeat_polish(self):
        texts = ["Kto? Who?", "Informacji lotniczej. Informacji lotniczej.", "Alarmowej. Alarmowej.",
                 "Kontroli. Kontroli.", "Żadnej. Żadnej."]
        _, _, reasons, _ = self.assess(texts)
        self.assertTrue(any("repeats the Polish" in r for r in reasons))

    def round3(self, number):
        with open(HERE / "fixtures" / "round3_records.json", encoding="utf-8") as f:
            return json.load(f)[number][0]

    def test_round3_records_with_wrong_boundary_stay_in_source_form(self):
        # PL090-0045 a0, PL040-0073 a0, PL040-0135 a0: the Polish tail ended up in / next to the English part
        for number in ("PL090-0045", "PL040-0073", "PL040-0135"):
            texts = self.round3(number)
            cells, _, reasons, _ = self.assess(texts)
            self.assertTrue(reasons, number)
            self.assertEqual(cells, [{"pl": t, "en": None} for t in texts], number)

    def test_lone_capital_after_a_full_stop_and_glued_english(self):
        base = ["Wybierz obiekt: Select the landmark:", "Wieś. Village.", "Brzeg morza. Sea shore.", "Droga. Road."]
        cells, _, reasons, _ = self.assess(base[:1] + ["Duże miasto.A large city."] + base[1:])
        self.assertTrue(any("lone capital" in r or "lower case" in r for r in reasons), reasons)
        self.assertTrue(all(x["en"] is None for x in cells))
        # PL040-0340 style: "...od sercaArteries and veins..."
        cells, _, reasons, _ = self.assess(base[:1] + ["Tętnice odprowadzają krew od sercaArteries and veins drain blood."] + base[1:])
        self.assertTrue(reasons)
        self.assertTrue(all(x["en"] is None for x in cells))

    def test_polish_word_anywhere_in_english_part(self):
        base = ["Wybierz obiekt: Select the landmark:", "Wieś. Village.", "Brzeg morza. Sea shore.", "Droga. Road."]
        cells, _, reasons, _ = self.assess(base[:1] + ["Duże miasto. A large city near warunków lotu."] + base[1:])
        self.assertTrue(any("Polish word inside" in r for r in reasons), reasons)
        # the proper name "Jelenia Góra" is allowed
        cells, _, reasons, _ = self.assess(base[:1] + ["Duże miasto. A large city near Jelenia Góra."] + base[1:])
        self.assertFalse(any("Polish word inside" in r for r in reasons), reasons)

    def test_trailing_separators_of_answers_are_uniform(self):
        # PL060-0134 / PL060-0185: only the first answer kept its ";" after the split
        for number in ("PL060-0134", "PL060-0185"):
            cells, _, reasons, _ = self.assess(self.round3(number))
            self.assertEqual(reasons, [], number)
            for x in cells[1:]:
                self.assertFalse(x["pl"].rstrip().endswith((";", ",")) or x["en"].rstrip().endswith((";", ",")), (number, x))
        cells, _, _, _ = self.assess(["Jednostki? Units?", "30 stóp; 30 ft", "40 stóp; 40 ft", "10 stóp; 10 ft", "50 stóp; 50 ft"])
        self.assertEqual([x["pl"] for x in cells[1:]], ["30 stóp", "40 stóp", "10 stóp", "50 stóp"])

    def test_no_cut_at_a_space_before_punctuation(self):
        # PL060-0166: the full stop must stay with the Polish text
        self.assertEqual(c.split_cell("17 US gal . 17 US gal.", self.lex), ("17 US gal.", "17 US gal.", "twin"))

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


class LegacyCompareTest(unittest.TestCase):
    @staticmethod
    def variant(q, a0, vid="PL010-0438"):
        return {"id": vid, "q": {"pl": q}, "a": [{"pl": a0}]}

    def test_number_change_is_a_real_change(self):
        cat, ids = c.classify_legacy("Jaka wysokość?", "Wysokości bezwzględnej 800 m.",
                                     [self.variant("Jaka wysokość?", "Wysokości bezwzględnej 300 m.")])
        self.assertEqual(cat, "real")

    def test_punctuation_is_a_typo(self):
        cat, _ = c.classify_legacy("Jaka?", "Wysokość bezwzględna", [self.variant("Jaka?", "Wysokość bezwzględna.")])
        self.assertEqual(cat, "unchanged")
        cat, _ = c.classify_legacy("Jaka?", "Wysokość bezwzględnie.", [self.variant("Jaka?", "Wysokość bezwzględna.")])
        self.assertEqual(cat, "typo")

    def test_empty_legacy_answer_is_its_own_category(self):
        self.assertEqual(c.classify_legacy("Jaka?", "", [self.variant("Jaka?", "Tak.")])[0], "empty_legacy")

    def test_doubled_legacy_cell_and_source_form_match(self):
        self.assertEqual(c.classify_legacy("Jaka?", "7700. 7700.", [self.variant("Jaka?", "7700.")])[0], "unchanged")
        self.assertEqual(c.classify_legacy("Jaka?", "Tak.", [self.variant("Jaka?", "Tak. Yes.")])[0], "unchanged")


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

    def test_audit_flags_new_symptoms(self):
        lex = c.build_lexicon(str(LEGACY_DIR))
        def q(a0, a1_en="Village."):
            return {"id": "PL060-0093", "number": "PL060-0093", "q": {"pl": "Q?", "en": "Q?"},
                    "a": [a0] + [{"pl": "Wieś.", "en": a1_en}] * 3, "correct": 0}
        bank = {"questions": [q({"pl": "Duże miasto.A", "en": "large city."}),
                              q({"pl": "27 Mm;", "en": "27 NM"}),
                              q({"pl": "Duże miasto.", "en": "A large city near warunków."})]}
        res = v.audit_bank(bank, lex)
        self.assertEqual(len(res["e_boundary"]), 1)
        self.assertEqual(len(res["g_tail"]), 1)
        self.assertEqual(len(res["f_polish_in_en"]), 1)

    def test_detects_separator_at_start_and_doubled_answers(self):
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            q = self.question("PL040-0004")
            q["a"][3]["en"] = ";500 ft/min"
            q["a"][0]["pl"] = "5 ; 5"
            q["a"][1]["en"] = "x"
            errors, _, _ = v.validate_bank(self.write([q], tmp))
            self.assertTrue(any("starts with a separator" in e for e in errors))
            self.assertTrue(any("doubled text" in e for e in errors))

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
