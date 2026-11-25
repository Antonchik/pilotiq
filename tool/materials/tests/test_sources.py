import hashlib
import json
import os
import pathlib
import sys
import tempfile
import unittest

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

import extract_corpus as ec  # noqa: E402
import fetch_sources as fs  # noqa: E402

FIX = HERE / "fixtures" / "sources"


def read_fix(name):
    return (FIX / name).read_text(encoding="utf-8")


def anchor_text(text, anchors, key):
    s, e = anchors[key]
    return text[s:e]


def make_pdf(lines):
    """A minimal one-page PDF with Helvetica text, built byte by byte (no libraries)."""
    body = ["BT /F1 12 Tf 72 760 Td 14 TL"]
    for ln in lines:
        body.append("(%s) Tj T*" % ln.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)"))
    body.append("ET")
    stream = "\n".join(body).encode("latin-1")
    objs = [
        b"<< /Type /Catalog /Pages 2 0 R >>",
        b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R "
        b"/Resources << /Font << /F1 5 0 R >> >> >>",
        b"<< /Length %d >>\nstream\n" % len(stream) + stream + b"\nendstream",
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
    ]
    out = bytearray(b"%PDF-1.4\n")
    offs = []
    for i, o in enumerate(objs, 1):
        offs.append(len(out))
        out += b"%d 0 obj\n" % i + o + b"\nendobj\n"
    xref = len(out)
    out += b"xref\n0 %d\n0000000000 65535 f \n" % (len(objs) + 1)
    for o in offs:
        out += b"%010d 00000 n \n" % o
    out += b"trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n" % (len(objs) + 1, xref)
    return bytes(out)


class StatuteAnchorsTest(unittest.TestCase):
    def setUp(self):
        self.text = "\n".join(ec.clean_lines(read_fix("statute_sample.txt").split("\n"))) + "\n"
        self.a = ec.statute_anchors(self.text)

    def test_articles_ust_and_pkt(self):
        for key in ("art. 1", "art. 1 ust. 1", "art. 1 ust. 2", "art. 2", "art. 2 pkt 1", "art. 2 pkt 3",
                    "art. 3", "art. 87[1]", "art. 87[1] ust. 1", "art. 87[1] ust. 1 pkt 2",
                    "art. 87[1] ust. 2", "art. 128", "art. 128a", "art. 128a ust. 2a",
                    "art. 128a ust. 3 pkt 2"):
            self.assertIn(key, self.a, key)

    def test_inline_first_ust_and_ranges(self):
        t = anchor_text(self.text, self.a, "art. 1 ust. 1")
        self.assertTrue(t.startswith("Art. 1. 1. Przepisy"))
        self.assertIn("lotnictwa cywilnego.", t)
        self.assertNotIn("2. Przepisy stosuje", t)
        art = anchor_text(self.text, self.a, "art. 1")
        self.assertIn("2. Przepisy stosuje", art)
        self.assertNotIn("Art. 2.", art)

    def test_multiline_pkt_range(self):
        t = anchor_text(self.text, self.a, "art. 2 pkt 1")
        self.assertIn("się w atmosferze;", t)
        self.assertNotIn("lotnisko", t)

    def test_chapter_heading_is_not_part_of_article(self):
        t = anchor_text(self.text, self.a, "art. 128")
        self.assertIn("wyznaczania.", t)
        self.assertNotIn("Rozdział 2", t)
        self.assertNotIn("Licencje", t)

    def test_text_reference_is_not_an_anchor(self):
        # "ust. 2 i innych." starts a wrapped line but must not create a second "ust. 2"
        self.assertEqual(1, sum(1 for k in self.a if k == "art. 128a ust. 2"))
        self.assertIn("ust. 2 i innych", anchor_text(self.text, self.a, "art. 128a ust. 2"))

    def test_sequence_guard(self):
        # numbering that skips ahead is not accepted as a new paragraph
        text = "Art. 1. 1. A.\n5. wrapped number.\nArt. 2. B.\n"
        a = ec.statute_anchors(text)
        self.assertNotIn("art. 1 ust. 5", a)
        self.assertIn("art. 2", a)


class RuleAnchorsTest(unittest.TestCase):
    def setUp(self):
        self.text = read_fix("sera_sample.txt")
        self.a = ec.rule_anchors(self.text, "easa")

    def test_rule_and_subpoints(self):
        for key in ("SERA.5005", "SERA.5005(a)", "SERA.5005(a)(1)", "SERA.5005(a)(2)", "SERA.5005(b)",
                    "SERA.5005(b)(1)", "SERA.5005(b)(1)(i)", "SERA.5005(b)(1)(ii)", "SERA.5005(b)(2)",
                    "SERA.5005(c)", "SERA.5010", "SERA.5010(a)"):
            self.assertIn(key, self.a, key)

    def test_amc_gm_with_parent(self):
        self.assertIn("AMC1 SERA.5005(b)", self.a)
        self.assertIn("AMC1 SERA.5005", self.a)  # parent alias required by the locator validator
        self.assertIn("GM1 SERA.5005", self.a)

    def test_ranges(self):
        rule = anchor_text(self.text, self.a, "SERA.5005")
        self.assertIn("(c) Third paragraph.", rule)
        self.assertNotIn("AMC1", rule)
        sub = anchor_text(self.text, self.a, "SERA.5005(a)(1)")
        self.assertIn("Table S5-1;", sub)
        self.assertNotIn("(2) the aircraft", sub)
        self.assertEqual("(i)", anchor_text(self.text, self.a, "SERA.5005(b)(1)(i)")[:3])

    def test_toc_lines_are_ignored(self):
        s, _ = self.a["SERA.5005"]
        self.assertGreater(s, self.text.index("SECTION 5"))



class EuPolishAnchorsTest(unittest.TestCase):
    def setUp(self):
        self.text = read_fix("eu_pl_sample.txt")
        self.a = ec.eureg_anchors(self.text)

    def test_articles_paragraphs_points_and_definitions(self):
        for key in ("art. 1", "art. 1 ust. 1", "art. 1 ust. 2", "art. 2", "art. 2 pkt 1", "art. 2 pkt 3",
                    "art. 2 pkt 4", "art. 3", "art. 3 ust. 1", "art. 3 ust. 1 pkt 1", "art. 3 ust. 1 pkt 2",
                    "art. 3 ust. 2"):
            self.assertIn(key, self.a, key)
        self.assertNotIn("art. 2 ust. 1", self.a)
        self.assertTrue(anchor_text(self.text, self.a, "art. 2 pkt 3").startswith("3) „lotnisko”"))
        self.assertNotIn("Artykuł 3", anchor_text(self.text, self.a, "art. 2 pkt 4"))

    def test_annex_rules_and_paragraphs(self):
        for key in ("załącznik", "SERA.5005", "SERA.5005(a)", "SERA.5005(b)", "SERA.5005(b)(1)", "SERA.5005(b)(2)",
                    "SERA.5005(c)(1)", "SERA.5005(c)(3)", "SERA.5005(c)(3)(i)", "SERA.5005(c)(3)(ii)",
                    "SERA.5010", "SERA.5010(a)", "załącznik II", "FCL.205.A", "FCL.205.A(a)"):
            self.assertIn(key, self.a, key)
        rule = anchor_text(self.text, self.a, "SERA.5005")
        self.assertIn("(ii) przepisy nie mają zastosowania;", rule)
        self.assertNotIn("SERA.5010 Lot", rule)
        # a rule reference at the start of a running-text line is not a heading
        self.assertEqual(1, [k for k in self.a].count("SERA.5010"))
        self.assertNotIn("jest cytowane", anchor_text(self.text, self.a, "SERA.5010(a)"))

    def test_appendices(self):
        for key in ("dodatek 1", "dodatek 1 pkt 1", "dodatek 1 pkt 1.1", "dodatek 1 pkt 1.2", "dodatek 2",
                    "dodatek 2 pkt 1", "załącznik II dodatek 1", "załącznik II dodatek 1 pkt 1"):
            self.assertIn(key, self.a, key)
        self.assertNotIn("dodatek 1 pkt 215", self.a)
        self.assertNotIn("Balony", anchor_text(self.text, self.a, "dodatek 1"))
        # the annex covers its appendices, the next annex starts a new range
        annex = anchor_text(self.text, self.a, "załącznik")
        self.assertIn("Dodatek 2", annex)
        self.assertNotIn("FCL.205.A", annex)

    def test_eurlex_xhtml_text(self):
        lines = ec.clean_lines(ec.read_html_lines(str(FIX / "eurlex_sample.html"), "eurlex_html"))
        text = "\n".join(lines)
        self.assertNotIn("spis treści", text)
        self.assertNotIn("▼", text)
        self.assertNotIn("►", text)
        self.assertNotIn("◄", text)
        self.assertIn("1. Bez uszczerbku dla rozporządzenia (UE) 2020/723, obowiązują zasady.", lines)
        self.assertIn("1) „dokładność” oznacza zgodność;", lines)
        self.assertIn("SERA.5005 Przepisy lotu", lines)
        self.assertIn("Klasa", lines)
        self.assertIn("Dokument ten służy wyłącznie do celów informacyjnych.", lines)


class StatuteFootnoteAndAnnexTest(unittest.TestCase):
    FM = ec.FUTURE_MARK

    def anchors(self, body):
        text = "\n".join(ec.clean_lines(("Art. 1. Start.\n" + body).split("\n"))) + "\n"
        return text, ec.statute_anchors(text)

    def test_future_redaction_is_not_anchored_and_does_not_extend_the_current_one(self):
        text, a = self.anchors(
            "Art. 43. 1. First.\n"
            "Art. 44. 1. Current first paragraph.\n2. Current second.\n"
            "Art. 44.%s 1. Future first paragraph.\n2. Future second.\n"
            "Art. 45. Next article.\n" % self.FM)
        self.assertEqual(["art. 1", "art. 43", "art. 43 ust. 1", "art. 44", "art. 44 ust. 1", "art. 44 ust. 2",
                          "art. 45"], list(a))
        self.assertNotIn("Future", anchor_text(text, a, "art. 44"))
        self.assertTrue(anchor_text(text, a, "art. 44 ust. 2").startswith("2. Current second."))

    def test_future_paragraph_keeps_the_numbering_for_the_next_one(self):
        text, a = self.anchors(
            "Art. 67c. 1. One.\n2. %s Future two.\n2a. Two a.\n3. Three.\n"
            "1) pkt one;\n2) pkt two;\n2) %s pkt two future;\n3) pkt three;\n" % (self.FM, self.FM))
        for key in ("art. 67c ust. 1", "art. 67c ust. 2a", "art. 67c ust. 3", "art. 67c ust. 3 pkt 1",
                    "art. 67c ust. 3 pkt 2", "art. 67c ust. 3 pkt 3"):
            self.assertIn(key, a, key)
        self.assertNotIn("art. 67c ust. 2", a)
        self.assertNotIn("Future", anchor_text(text, a, "art. 67c ust. 3 pkt 1"))

    def test_unnumbered_first_paragraph_and_glued_number(self):
        _, a = self.anchors("Art. 201. Single paragraph text.\n2. (uchylony)\n3. (uchylony)\n"
                            "Art. 156c. 1. A.\n2. B.\n3. C.\n4. D.\n5.Prezes Urzedu decyduje.\n")
        self.assertIn("art. 201 ust. 2", a)
        self.assertIn("art. 201 ust. 3", a)
        self.assertNotIn("art. 201 ust. 1", a)
        self.assertIn("art. 156c ust. 5", a)

    def test_annex_has_its_own_anchors_and_ends_the_last_article(self):
        text, a = self.anchors(
            "Art. 232. Last article.\nZałącznik nr 1\nWysokość kary\n1. Naruszenie\n1.1. Szczegół\n"
            "215 535\nZałącznik nr 5a\n1. Opłata\n")
        self.assertEqual(["art. 1", "art. 232", "załącznik 1", "załącznik 1 pkt 1", "załącznik 1 pkt 1.1",
                          "załącznik 5a", "załącznik 5a pkt 1"], list(a))
        self.assertNotIn("Załącznik", anchor_text(text, a, "art. 232"))
        self.assertNotIn("Naruszenie", anchor_text(text, a, "załącznik 5a"))


class SejmPdfFootnoteTest(unittest.TestCase):
    def test_superscript_marks_are_removed_and_future_redaction_marked(self):
        # (size, text) segments per line; footnotes at 6 pt
        content = [
            "BT 72 760 Td /F1 10 Tf (Art. 44.) Tj /F1 6.5 Tf (27\\)) Tj /F1 10 Tf ( 1. Current paragraph text here.) Tj ET",
            "BT 72 740 Td /F1 10 Tf (Art. 44.) Tj /F1 6.5 Tf (28\\)) Tj /F1 10 Tf ( 1. Future paragraph text here.) Tj ET",
            "BT 72 100 Td /F1 6 Tf (27\\) W tym brzmieniu obowiazuje do wejscia w zycie zmiany, o ktorej mowa w odnosniku 28.) Tj ET",
            "BT 72 90 Td /F1 6 Tf (28\\) Ze zmiana wprowadzona przez art. 3 ustawy.) Tj ET",
        ]
        stream = "\n".join(content).encode("latin-1")
        objs = [
            b"<< /Type /Catalog /Pages 2 0 R >>",
            b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
            b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R "
            b"/Resources << /Font << /F1 5 0 R >> >> >>",
            b"<< /Length %d >>\nstream\n" % len(stream) + stream + b"\nendstream",
            b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
        ]
        out = bytearray(b"%PDF-1.4\n")
        offs = []
        for i, o in enumerate(objs, 1):
            offs.append(len(out))
            out += b"%d 0 obj\n" % i + o + b"\nendobj\n"
        xref = len(out)
        out += b"xref\n0 %d\n0000000000 65535 f \n" % (len(objs) + 1)
        for o in offs:
            out += b"%010d 00000 n \n" % o
        out += b"trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n" % (len(objs) + 1, xref)
        with tempfile.TemporaryDirectory() as d:
            path = pathlib.Path(d) / "x.pdf"
            path.write_bytes(bytes(out))
            lines = ec.clean_lines(ec.read_pdf_lines(str(path), "sejm"))
        self.assertEqual(2, len(lines), lines)
        self.assertTrue(lines[0].startswith("Art. 44. 1. Current paragraph"), lines[0])
        self.assertNotIn(ec.FUTURE_MARK, lines[0])
        self.assertIn(ec.FUTURE_MARK, lines[1])
        self.assertNotIn("27)", " ".join(lines))


class EarExtrasTest(unittest.TestCase):
    def setUp(self):
        self.text = read_fix("sera_ext_sample.txt")
        self.a = ec.rule_anchors(self.text, "easa", ("article", "appendix"))

    def test_articles_and_definitions(self):
        for key in ("Article 1", "Article 1(1)", "Article 1(2)", "Article 2", "Article 2(1)", "Article 2(3)",
                    "Article 2(5)", "Article 2(5a)", "GM1 Article 2(12)", "Article 3", "Article 3(1)"):
            self.assertIn(key, self.a, key)
        self.assertNotIn("Article 10", self.a)  # table-of-contents entry wrapped over three lines
        self.assertTrue(anchor_text(self.text, self.a, "Article 2(5)").startswith("5. ‘aerial work’"))
        self.assertNotIn("GM1", anchor_text(self.text, self.a, "Article 2"))

    def test_gm_to_article_definition(self):
        self.assertIn("GM1 Article 2(12)", self.a)
        self.assertIn("GM1 Article 2", self.a)
        self.assertNotIn("Article 3", anchor_text(self.text, self.a, "GM1 Article 2(12)"))

    def test_multi_rule_heading_and_parent_union(self):
        self.assertIn("AMC1 FCL.210", self.a)
        self.assertIn("AMC1 FCL.215", self.a)
        self.assertEqual(self.a["AMC1 FCL.210"], self.a["AMC1 FCL.215"])
        s, e = self.a["AMC1 SERA.5005"]
        for key in ("AMC1 SERA.5005(f)", "AMC1 SERA.5005(b)"):
            self.assertTrue(s <= self.a[key][0] and self.a[key][1] <= e, key)

    def test_table_footnote_paragraph_is_not_a_subpoint(self):
        self.assertIn("SERA.5001", self.a)
        self.assertNotIn("SERA.5001(a)", self.a)

    def test_gm_to_other_block_ends_the_previous_one(self):
        self.assertNotIn("Text of GM", anchor_text(self.text, self.a, "AMC1 SERA.5005(b)"))

    def test_appendices(self):
        for key in ("Appendix 1", "Appendix 1 pkt 1", "Appendix 1 pkt 1.1", "Appendix 1 pkt 1.1.1",
                    "Appendix 1 pkt 1.2", "Appendix 2", "Appendix 2 pkt 1"):
            self.assertIn(key, self.a, key)
        self.assertNotIn("Appendix 1 pkt 215", self.a)
        self.assertNotIn("Balloons", anchor_text(self.text, self.a, "Appendix 1"))

    def test_extras_are_off_by_default(self):
        plain = ec.rule_anchors(self.text, "easa")
        self.assertFalse([k for k in plain if k.startswith(("Article", "Appendix", "GM1 Article"))])


class RuleHeadingsTest(unittest.TestCase):
    def test_five_digit_rule_ids(self):
        text = ("SERA.14095 Phraseology for distress\nRegulation (EU) 2016/1185\n(a) Distress communications shall be made.\n"
                "SERA.11015 Interception procedures\nRegulation (EU) 2016/1185\n(a) An intercepted aircraft shall comply.\n"
                "ARA.GEN.135A Immediate reaction\nRegulation (EU) 2016/1185\n(a) The authority shall implement a system.\n")
        a = ec.rule_anchors(text, "easa")
        for key in ("SERA.14095", "SERA.14095(a)", "SERA.11015", "ARA.GEN.135A"):
            self.assertIn(key, a, key)
        a2 = ec.eureg_anchors("ZAŁĄCZNIK\n" + text)
        self.assertIn("SERA.14095", a2)

    def test_toc_changelog_and_body_occurrences(self):
        text = ("Summary of changes\n"
                "NCO.OP.160 Changed N/a Regulation (EU) 2021/2237\n"
                "NCO.OP.165 Changed N/a Regulation (EU) 2021/2237\n"
                "NCO.OP.170 New N/a Regulation (EU) 2021/2237\n"
                "SPO.POL.110 New Reg. (EU) 2019/1384\n"
                "Contents\nNCO.OP.160 Meteorological conditions\nNCO.OP.165 Fuel\n"
                "NCO.OP.160 Meteorological conditions\nRegulation (EU) 2018/1042\n"
                "(a) The pilot-in-command shall commence a VFR flight only if the weather permits.\n"
                "NCO.OP.165 Fuel and oil\nRegulation (EU) 2018/1042\n(a) A pilot shall carry enough fuel for the flight.\n"
                "SPO.POL.110 Mass and balance system\nRegulation (EU) 2019/1384\n(a) The operator shall establish mass and balance.\n")
        a = ec.rule_anchors(text, "easa")
        for key in ("NCO.OP.160", "NCO.OP.165", "SPO.POL.110"):
            s, e = a[key]
            self.assertIn("Regulation (EU) 20", text[s:e], key)
            self.assertTrue(text[s:].startswith(key + " M") or text[s:].startswith(key + " F"), (key, text[s:s + 40]))
        self.assertNotIn("NCO.OP.170", a)  # only ever in the change log

    def test_polish_annex_toc_and_body(self):
        text = ("ZAŁĄCZNIK I\nSPIS TREŚCI\n21.A.1\nZakres\n21.A.2\nPodejmowanie czynności\n(PODCZĘŚĆ C – NIE STOSUJE SIĘ)\n"
                "PODCZĘŚĆ A\n21.A.1 Zakres\nNiniejsza podczęść określa ogólne prawa i obowiązki wnioskodawców.\n"
                "21.A.2 Podejmowanie czynności\nCzynności i obowiązki, które mają być podjęte przez posiadacza certyfikatu.\n"
                "21.A.3A System zgłaszania\nPosiadacz certyfikatu ustanawia system zgłaszania zdarzeń.\n")
        a = ec.eureg_anchors(text)
        for key in ("21.A.1", "21.A.2", "21.A.3A"):
            s, e = a[key]
            self.assertGreater(e - s, 60, key)
            self.assertTrue(text[s:].startswith(key + " "), key)

    def test_amc_and_gm_have_no_paragraph_subkeys(self):
        text = ("SERA.5005 Visual flight rules\nRegulation (EU) 2024/404\n(a) The flight shall be conducted so that the conditions are met.\n"
                "AMC1 SFCL.150(b) SPL privileges\nED Decision 2020/004/R\n(a) The training elements as per point SFCL.150(b)(1) should be covered.\n"
                "(b) The second element of the training programme should be covered.\n")
        a = ec.rule_anchors(text, "easa")
        self.assertIn("SERA.5005(a)", a)
        self.assertIn("AMC1 SFCL.150(b)", a)
        self.assertFalse([k for k in a if k.startswith("AMC1 SFCL.150(b)(")], list(a))

    def test_deleted_text_dashes_are_removed_from_cellar_text(self):
        lines = ec.clean_lines(ec.read_html_lines(str(FIX / "eurlex_sample.html"), "eurlex_html"))
        self.assertFalse([l for l in lines if "————" in l])
        html_text = "<html><body><p class=\"norm\">a) tekst ————— koniec</p></body></html>"
        with tempfile.TemporaryDirectory() as d:
            path = pathlib.Path(d) / "x.html"
            path.write_text(html_text, encoding="utf-8")
            out = ec.clean_lines(ec.read_html_lines(str(path), "eurlex_html"))
        self.assertEqual(["a) tekst koniec"], out)


class StatuteFutureAndTablesTest(unittest.TestCase):
    FM = ec.FUTURE_MARK

    def test_future_ranges_are_recorded(self):
        text = ("Art. 1. Start.\n"
                "Art. 40. 1. Przepis o rejestrze:\n"
                "1) a;\n2) b;\n3) c;\n4) d;\n"
                "4a) statek podlega wpisowi, o którym mowa w art. 44 ust. 1 i 2;\n"
                "4a) %s statek podlega wpisowi, o którym mowa w art. 44 ust. 1 albo art. 44a;\n"
                "5) mimo zaistnienia okoliczności nie obowiązuje porozumienie.\n"
                "Art. 41. Inny przepis.\n" % self.FM)
        future = []
        a = ec.statute_anchors(text, future)
        self.assertEqual(1, len(future))
        s, e = future[0]
        self.assertTrue(text[s:].startswith("4a) " + self.FM))
        self.assertTrue(text[e:].startswith("5) mimo"))
        self.assertLessEqual(a["art. 40 ust. 1"][0], s)
        self.assertGreaterEqual(a["art. 40 ust. 1"][1], e)   # the enclosing anchor contains it: the validator masks it
        self.assertIn("art. 40 ust. 1 pkt 5", a)

    def test_marked_letter_and_dash_items_are_future_ranges_too(self):
        text = ("Art. 1. Start.\nArt. 2. 1. Zakres:\na) pierwszy w mocy;\nb) %s przyszły literowy\nciąg dalszy przyszłego;\n"
                "c) trzeci w mocy;\n– %s przyszły z kreską;\n– w mocy z kreską.\nArt. 3. Dalej.\n" % (self.FM, self.FM))
        future = []
        ec.statute_anchors(text, future)
        covered = [text[s:e] for s, e in future]
        self.assertEqual(2, len(covered), covered)
        self.assertIn("ciąg dalszy przyszłego;", covered[0])
        self.assertNotIn("trzeci w mocy", covered[0])
        self.assertIn("przyszły z kreską", covered[1])
        self.assertNotIn("w mocy z kreską", covered[1])
        marks = [i for i in range(len(text)) if text.startswith(self.FM, i)]
        self.assertTrue(all(any(s <= i < e for s, e in future) for i in marks))

    def test_future_article_range_ends_at_next_article(self):
        text = "Art. 1. Start.\nArt. 2. Jeden.\nArt. 3.%s Trzy przyszłe.\n1. Ust.\nArt. 4. Cztery.\n" % (" " + self.FM)
        future = []
        a = ec.statute_anchors(text, future)
        self.assertNotIn("art. 3", a)
        self.assertEqual([[text.index("Art. 3."), text.index("Art. 4.")]], future)

    def test_annex_rows_are_keyed_by_table_and_part(self):
        text = ("Art. 1. Start.\nZałącznik nr 6\nTabela nr 1\nCzęść III\n3.14. Inne certyfikaty\nopłata 2000\n"
                "Tabela nr 2\nCzęść I Egzaminy\n3.14. Przeprowadzenie egzaminu teoretycznego\n5. Inny wiersz\n"
                "Przypisy:\n1) objaśnienie\nTabela nr 3\nCzęść I\n5. Wiersz piąty\n")
        a = ec.statute_anchors(text)
        for key in ("załącznik 6", "załącznik 6 tabela 1", "załącznik 6 tabela 1 część III",
                    "załącznik 6 tabela 1 część III pkt 3.14", "załącznik 6 tabela 2", "załącznik 6 tabela 2 część I",
                    "załącznik 6 tabela 2 część I pkt 3.14", "załącznik 6 tabela 2 część I pkt 5",
                    "załącznik 6 tabela 3 część I pkt 5"):
            self.assertIn(key, a, key)
        self.assertNotIn("załącznik 6 pkt 3.14", a)
        row = anchor_text(text, a, "załącznik 6 tabela 1 część III pkt 3.14")
        self.assertIn("Inne certyfikaty", row)
        self.assertNotIn("Egzaminy", row)
        self.assertNotIn("egzaminu teoretycznego", row)
        row2 = anchor_text(text, a, "załącznik 6 tabela 2 część I pkt 5")
        self.assertNotIn("objaśnienie", row2)


class AipAndHtmlTest(unittest.TestCase):
    def test_html_to_text_and_anchors(self):
        path = FIX / "aip_sample.html"
        lines = ec.clean_lines(ec.read_html_lines(str(path)))
        text = "\n".join(lines) + "\n"
        self.assertNotIn("GEN 9.9", text)
        self.assertNotIn("color:red", text)
        self.assertIn("Klasy przestrzeni", text)
        a = ec.aip_anchors(text)
        self.assertEqual(["ENR 1.2", "ENR 1.2 pkt 1.1", "ENR 1.2 pkt 2.1", "ENR 1.3"], list(a))


class CleaningTest(unittest.TestCase):
    def test_dehyphenate_joins_lowercase_continuations_only(self):
        lines = ["statków powietrz-", "nych oraz UE-", "EFTA oraz tic-", "wa"]
        self.assertEqual(["statków powietrznych oraz UE-", "EFTA oraz ticwa"], ec.dehyphenate(lines))

    def test_clean_line(self):
        self.assertEqual("a b c", ec.clean_line("a  b\t c­ "))


class ExtractionDeterminismTest(unittest.TestCase):
    def _run(self, workdir, src, name, data):
        sdir = pathlib.Path(workdir) / "sources" / src["id"]
        sdir.mkdir(parents=True, exist_ok=True)
        (sdir / name).write_bytes(data)
        sj = pathlib.Path(workdir) / "sources.json"
        sj.write_text(json.dumps([src]), encoding="utf-8")
        out = []
        code = ec.main(["--all", "--jobs", "1", "--sources-json", str(sj),
                        "--sources-dir", str(pathlib.Path(workdir) / "sources"),
                        "--corpus-dir", str(pathlib.Path(workdir) / "corpus"),
                        "--anchors-dir", str(pathlib.Path(workdir) / "anchors")], out=out.append)
        self.assertEqual(0, code, out)
        corpus = (pathlib.Path(workdir) / "corpus" / (src["id"] + ".txt")).read_bytes()
        anchors = (pathlib.Path(workdir) / "anchors" / (src["id"] + ".json")).read_bytes()
        return corpus, anchors

    def test_pdf_twice_gives_identical_output(self):
        pdf = make_pdf(["Art. 1. 1. Pierwszy ustep.", "2. Drugi ustep.", "Art. 2. Definicje.", "1) pkt jeden;"])
        src = {"id": "T-PDF", "kind": "statute", "lang": "pl", "format": "pdf", "status": "available"}
        with tempfile.TemporaryDirectory() as d1, tempfile.TemporaryDirectory() as d2:
            c1, a1 = self._run(d1, src, "T-PDF.pdf", pdf)
            c2, a2 = self._run(d2, src, "T-PDF.pdf", pdf)
            self.assertEqual(c1, c2)
            self.assertEqual(a1, a2)
        doc = json.loads(a1)
        self.assertEqual(hashlib.sha256(c1).hexdigest(), doc["textSha"])
        self.assertEqual(["art. 1", "art. 1 ust. 1", "art. 1 ust. 2", "art. 2", "art. 2 pkt 1"],
                         list(doc["anchors"]))

    def test_html_twice_gives_identical_output(self):
        data = (FIX / "aip_sample.html").read_bytes()
        src = {"id": "T-AIP", "kind": "aip", "lang": "pl", "format": "html", "status": "available"}
        with tempfile.TemporaryDirectory() as d1, tempfile.TemporaryDirectory() as d2:
            self.assertEqual(self._run(d1, src, "T-AIP.html", data), self._run(d2, src, "T-AIP.html", data))


class FetchSourcesTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = pathlib.Path(self.tmp.name)
        self.addCleanup(self.tmp.cleanup)
        self.payload = make_pdf(["hello"])
        (self.dir / "remote.pdf").write_bytes(self.payload)
        self.sha = hashlib.sha256(self.payload).hexdigest()
        self.sj = self.dir / "sources.json"
        self.sdir = self.dir / "sources"

    def write_sources(self, sha="", status="available"):
        self.sj.write_text(json.dumps([{
            "id": "T1", "kind": "statute", "lang": "pl", "status": status,
            "url": (self.dir / "remote.pdf").as_uri(), "format": "pdf", "sha256": sha, "fetched": ""}]),
            encoding="utf-8")

    def run_main(self, *args):
        out = []
        code = fs.main(list(args) + ["--sources-json", str(self.sj), "--sources-dir", str(self.sdir)],
                       out=out.append)
        return code, out

    def test_unpinned_source_needs_pin_flag(self):
        self.write_sources()
        code, out = self.run_main()
        self.assertEqual(fs.EXIT_ERROR, code, out)
        self.assertFalse((self.sdir / "T1" / "T1.pdf").exists())

    def test_pin_records_hash_and_file_then_matches(self):
        self.write_sources()
        code, out = self.run_main("--pin")
        self.assertEqual(0, code, out)
        rec = json.loads(self.sj.read_text(encoding="utf-8"))[0]
        self.assertEqual(self.sha, rec["sha256"])
        self.assertTrue(rec["fetched"])
        self.assertEqual(self.payload, (self.sdir / "T1" / "T1.pdf").read_bytes())
        code, out = self.run_main("--check")
        self.assertEqual(0, code, out)

    def test_check_reports_changed_online_version_without_overwriting(self):
        self.write_sources(sha="0" * 64)
        local = self.sdir / "T1"
        local.mkdir(parents=True)
        (local / "T1.pdf").write_bytes(b"%PDF-old")
        code, out = self.run_main("--check")
        self.assertEqual(fs.EXIT_CHANGED, code)
        self.assertTrue(any("CHANGED" in line for line in out), out)
        self.assertEqual(b"%PDF-old", (local / "T1.pdf").read_bytes())

    def test_fetch_with_wrong_pin_never_writes_file(self):
        self.write_sources(sha="f" * 64)
        code, out = self.run_main()
        self.assertEqual(fs.EXIT_MISMATCH, code, out)
        self.assertFalse((self.sdir / "T1" / "T1.pdf").exists())
        self.assertFalse((self.sdir / "T1" / "T1.pdf.part").exists())

    def test_wrong_pin_keeps_existing_file(self):
        self.write_sources(sha="f" * 64)
        local = self.sdir / "T1"
        local.mkdir(parents=True)
        (local / "T1.pdf").write_bytes(b"%PDF-existing")
        code, _ = self.run_main()
        self.assertEqual(fs.EXIT_MISMATCH, code)
        self.assertEqual(b"%PDF-existing", (local / "T1.pdf").read_bytes())

    def test_unavailable_source_is_skipped(self):
        self.write_sources(status="unavailable")
        code, out = self.run_main("--pin")
        self.assertEqual(0, code)
        self.assertTrue(any(line.startswith("SKIP") for line in out), out)

    def test_not_a_pdf_is_rejected(self):
        (self.dir / "remote.pdf").write_bytes(b"<html>challenge</html>")
        self.write_sources()
        code, out = self.run_main("--pin")
        self.assertEqual(fs.EXIT_ERROR, code, out)
        self.assertFalse((self.sdir / "T1" / "T1.pdf").exists())


class CellarFetchTest(unittest.TestCase):
    """CELLAR mode against a local fake of publications.europa.eu (SPARQL + 303 content negotiation)."""

    def setUp(self):
        import http.server
        import threading
        outer = self
        self.latest = "02012R0923-20250501"
        self.seen = []

        class Handler(http.server.BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def do_GET(self):
                outer.seen.append((self.path, self.headers.get("Accept"), self.headers.get("Accept-Language")))
                port = self.server.server_address[1]
                if self.path.startswith("/sparql"):
                    body = json.dumps({"results": {"bindings": [{"c": {"value": outer.latest}}]}}).encode()
                    self.send_response(200)
                    self.send_header("Content-Type", "application/sparql-results+json")
                elif self.path.startswith("/resource/celex/"):
                    celex = self.path.rsplit("/", 1)[1]
                    self.send_response(303)
                    self.send_header("Location", "http://127.0.0.1:%d/doc/%s" % (port, celex))
                    body = b""
                else:
                    celex = self.path.rsplit("/", 1)[1]
                    body = ('<?xml version="1.0"?><html><body><p>Artykuł 1 %s</p></body></html>' % celex).encode()
                    self.send_response(200)
                    self.send_header("Content-Type", "application/xhtml+xml")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)

        self.server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        threading.Thread(target=self.server.serve_forever, daemon=True).start()
        self.addCleanup(self.server.server_close)
        self.addCleanup(self.server.shutdown)
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dir = pathlib.Path(self.tmp.name)
        port = self.server.server_address[1]
        self.sj = self.dir / "sources.json"
        self.sj.write_text(json.dumps([{
            "id": "EU-T", "kind": "eu_reg", "lang": "pl", "status": "available", "format": "html",
            "url": "http://x/", "sha256": "", "fetched": "",
            "fetch": {"mode": "cellar", "base": "2012R0923", "lang": "pol",
                      "sparql": "http://127.0.0.1:%d/sparql" % port,
                      "resource": "http://127.0.0.1:%d/resource/celex/" % port}}]), encoding="utf-8")

    def run_main(self, *args):
        out = []
        code = fs.main(list(args) + ["--sources-json", str(self.sj), "--sources-dir", str(self.dir / "sources")],
                       out=out.append)
        return code, out

    def test_pin_follows_303_and_records_celex(self):
        code, out = self.run_main("--pin")
        self.assertEqual(0, code, out)
        rec = json.loads(self.sj.read_text(encoding="utf-8"))[0]
        self.assertEqual("02012R0923-20250501", rec["celex"])
        self.assertEqual("2025-05-01", rec["legalState"])
        self.assertTrue(rec["url"].endswith("/resource/celex/02012R0923-20250501"))
        data = (self.dir / "sources" / "EU-T" / "EU-T.html").read_bytes()
        self.assertEqual(hashlib.sha256(data).hexdigest(), rec["sha256"])
        self.assertIn("Artykuł 1 02012R0923-20250501".encode(), data)
        doc_calls = [c for c in self.seen if c[0].startswith("/resource/celex/")]
        self.assertEqual(("application/xhtml+xml", "pol"), doc_calls[0][1:])

    def test_check_reports_newer_consolidated_version(self):
        self.assertEqual(0, self.run_main("--pin")[0])
        code, out = self.run_main("--check")
        self.assertEqual(0, code, out)
        self.latest = "02012R0923-20260101"
        code, out = self.run_main("--check")
        self.assertEqual(fs.EXIT_CHANGED, code)
        self.assertTrue(any("newer consolidated version" in line for line in out), out)

    def test_pinned_celex_is_downloaded_even_when_a_newer_one_exists(self):
        self.assertEqual(0, self.run_main("--pin")[0])
        (self.dir / "sources" / "EU-T" / "EU-T.html").unlink()
        self.latest = "02012R0923-20260101"
        code, out = self.run_main()
        self.assertEqual(0, code, out)
        self.assertIn(b"02012R0923-20250501", (self.dir / "sources" / "EU-T" / "EU-T.html").read_bytes())

    def test_fixed_celex_skips_sparql_and_pins_without_legal_state(self):
        rec = json.loads(self.sj.read_text(encoding="utf-8"))
        rec[0]["fetch"] = dict(rec[0]["fetch"], celex="32007R0864")
        self.sj.write_text(json.dumps(rec), encoding="utf-8")
        code, out = self.run_main("--pin")
        self.assertEqual(0, code, out)
        pinned = json.loads(self.sj.read_text(encoding="utf-8"))[0]
        self.assertEqual("32007R0864", pinned["celex"])
        self.assertNotIn("legalState", pinned)
        self.assertFalse([c for c in self.seen if c[0].startswith("/sparql")])
        self.latest = "02012R0923-29990101"
        code, out = self.run_main("--check")
        self.assertEqual(0, code, out)       # a newer consolidation of the same regulation is irrelevant for a fixed CELEX

    def test_html_challenge_page_is_rejected(self):
        self.assertTrue(fs.is_cellar(json.loads(self.sj.read_text())[0]))
        bad = self.dir / "bad.html"
        bad.write_bytes(b"\x00\x01 binary")
        with self.assertRaises(fs.FetchError):
            fs.check_magic({"format": "html", "url": "u"}, str(bad))


def make_positioned_pdf(pages):
    """PDF with absolutely positioned text: pages = [[(x, y, size, text), ...], ...] (y from the page top)."""
    objs = [b"<< /Type /Catalog /Pages 2 0 R >>", None]
    kids = []
    for items in pages:
        body = []
        for x, y, size, text in items:
            esc = text.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)")
            body.append("BT /F1 %d Tf %d %d Td (%s) Tj ET" % (size, x, 842 - y, esc))
        stream = "\n".join(body).encode("latin-1")
        objs.append(b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents %d 0 R "
                    b"/Resources << /Font << /F1 %d 0 R >> >> >>" % (len(objs) + 2, 3 + 2 * len(pages)))
        kids.append(len(objs))
        objs.append(b"<< /Length %d >>\nstream\n" % len(stream) + stream + b"\nendstream")
    objs[1] = b"<< /Type /Pages /Kids [%s] /Count %d >>" % (" ".join("%d 0 R" % k for k in kids).encode(), len(pages))
    objs.append(b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>")
    out = bytearray(b"%PDF-1.4\n")
    offs = []
    for i, o in enumerate(objs, 1):
        offs.append(len(out))
        out += b"%d 0 obj\n" % i + o + b"\nendobj\n"
    xref = len(out)
    out += b"xref\n0 %d\n0000000000 65535 f \n" % (len(objs) + 1)
    for o in offs:
        out += b"%010d 00000 n \n" % o
    out += b"trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n" % (len(objs) + 1, xref)
    return bytes(out)


class AipManualTest(unittest.TestCase):
    """Manually downloaded eAIP sections: two-column PL | EN pages, only the Polish column is the corpus."""

    ENR12 = [(52, 20, 9, "AIP POLSKA ENR 1.2 - 1"), (52, 32, 9, "AIP POLAND 09 JUL 2026"),
             (52, 60, 10, "ENR 1.2 PRZEPISY WYKONYWANIA LOTU"), (310, 60, 10, "ENR 1.2 VISUAL FLIGHT RULES"),
             (52, 90, 10, "1. W FIR Warszawa stosuje sie przepisy SERA."), (310, 90, 10, "1. Within the FIR Warszawa the SERA applies."),
             (52, 110, 10, "2. Zwolnienia mozna uzyskac w trybie wyjatkowym."), (310, 110, 10, "2. Exemptions may be granted."),
             (52, 130, 10, "3. Na zadanie piloci stosuja nastepujace zasady:"), (310, 130, 10, "3. On request pilots shall apply the rules:"),
             (52, 150, 10, "3.1. Pierwsza zasada dotyczy widzialnosci."), (310, 150, 10, "3.1. The first rule concerns visibility."),
             (52, 170, 10, "3.1.1. Szczegol pierwszej zasady."), (310, 170, 10, "3.1.1. Detail of the first rule."),
             (52, 200, 10, "5. Punkt po przerwie w numeracji."), (310, 200, 10, "5. Point after a gap in numbering."),
             (52, 800, 8, "AIRAC AMDT 07/26 POLISH AIR NAVIGATION SERVICES AGENCY")]
    GEN22 = [(54, 20, 9, "AIP POLSKA GEN 2.2 - 1"), (54, 50, 10, "GEN 2.2 SKROTY WYKORZYSTYWANE W PUBLIKACJACH AIS"),
             (54, 80, 10, "* Legenda skrotow"),
             (54, 100, 10, "CBA Strefa lotow po obydwu stronach granicy"), (310, 100, 10, "CBA Cross border area"),
             (54, 120, 10, "CTR Rejon kontrolowany lotniska"), (182, 132, 10, "oraz jego okolice"),
             (310, 120, 10, "CTR Control zone"),
             (54, 150, 10, "MRT Trasa lotnictwa wojskowego"), (310, 150, 10, "MRT Military route")]
    ENR521 = [(52, 60, 10, "ENR 5.2.1 ZASADY"), (52, 80, 10, "1 DEFINICJE"), (310, 80, 10, "1 DEFINITIONS"),
              (52, 100, 10, "STREFA CZASOWO WYDZIELONA (TSA) - przestrzen powietrzna"), (310, 100, 10, "TEMPORARY SEGREGATED AREA (TSA) - airspace"),
              (52, 120, 10, "PRZESTRZEN BUFOROWA NA POTRZEBY WALIDOWANIA"), (52, 132, 10, "PLANOW LOTU (FBZ) - wirtualny bufor"),
              (52, 160, 10, "2 PRZEZNACZENIE"), (52, 180, 10, "2.1. Strefy TSA/TRA ustanawia sie dla celow."), (310, 180, 10, "2.1. TSAs and TRAs are established.")]

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dir = pathlib.Path(self.tmp.name)
        (self.dir / "sources" / "AIP-T").mkdir(parents=True)
        files = [("ENR 1.2", "ENR 1.2.pdf", self.ENR12, {}), ("GEN 2.2", "GEN 2.2.pdf", self.GEN22, {"entries": "abbreviations"}),
                 ("ENR 5.2.1", "ENR 5.2.1.pdf", self.ENR521, {})]
        self.files = []
        for sec, name, items, cfg in files:
            (self.dir / "sources" / "AIP-T" / name).write_bytes(make_positioned_pdf([items]))
            self.files.append(dict(section=sec, file=name, **cfg))
        self.src = {"id": "AIP-T", "kind": "aip", "lang": "pl", "format": "pdf", "status": "available", "url": "u",
                    "sha256": "", "fetched": "", "fetch": {"mode": "manual", "dir": "AIP-T", "files": self.files}}
        self.sj = self.dir / "sources.json"
        self.sj.write_text(json.dumps([self.src]), encoding="utf-8")

    def extract(self):
        out = []
        code = ec.main(["--all", "--jobs", "1", "--sources-json", str(self.sj), "--sources-dir", str(self.dir / "sources"),
                        "--corpus-dir", str(self.dir / "corpus"), "--anchors-dir", str(self.dir / "anchors")], out=out.append)
        self.assertEqual(0, code, out)
        text = (self.dir / "corpus" / "AIP-T.txt").read_text(encoding="utf-8")
        return text, json.loads((self.dir / "anchors" / "AIP-T.json").read_text(encoding="utf-8"))

    def test_only_the_polish_column_numbered_paragraphs_and_hierarchy(self):
        text, doc = self.extract()
        a = doc["anchors"]
        for key in ("ENR 1.2", "ENR 1.2 pkt 1", "ENR 1.2 pkt 2", "ENR 1.2 pkt 3", "ENR 1.2 pkt 3.1", "ENR 1.2 pkt 3.1.1",
                    "ENR 1.2 pkt 5"):
            self.assertIn(key, a, key)
        self.assertNotIn("Within the FIR", text)
        self.assertNotIn("VISUAL FLIGHT RULES", text)
        self.assertNotIn("AIP POLSKA", text)
        self.assertNotIn("AIRAC AMDT", text)
        s, e = a["ENR 1.2 pkt 3"]
        self.assertIn("Szczegol pierwszej zasady", text[s:e])      # a paragraph contains its sub-paragraphs
        s, e = a["ENR 1.2 pkt 2"]
        self.assertNotIn("Na zadanie", text[s:e])
        self.assertEqual({}, {k: v for k, v in doc.get("langs", {}).items() if v != "pl"})

    def test_abbreviations_and_definitions(self):
        text, doc = self.extract()
        a = doc["anchors"]
        for key in ("GEN 2.2 CBA", "GEN 2.2 CTR", "GEN 2.2 MRT", "ENR 5.2.1 TSA", "ENR 5.2.1 FBZ", "ENR 5.2.1 pkt 2.1", "ENR 5.2.1 pkt 2"):
            self.assertIn(key, a, key)
        self.assertNotIn("GEN 2.2 GEN", a)
        s, e = a["GEN 2.2 CTR"]
        self.assertEqual("CTR Rejon kontrolowany lotniska oraz jego okolice", text[s:e].strip())
        self.assertNotIn("Control zone", text)
        s, e = a["ENR 5.2.1 FBZ"]
        self.assertTrue(text[s:].startswith("PRZESTRZEN BUFOROWA"), text[s:s + 40])   # the definition starts on the line before the (FBZ)

    def test_english_only_and_table_sections_are_marked(self):
        self.files[0]["lang"] = "en"
        self.files[0]["columns"] = "full"
        self.files[2]["columns"] = "full"
        self.sj.write_text(json.dumps([self.src]), encoding="utf-8")
        text, doc = self.extract()
        self.assertEqual({"ENR 1.2": "en", "ENR 5.2.1": "pl+en"}, doc["langs"])
        self.assertIn("Within the FIR", text)

    def test_deterministic(self):
        t1, d1 = self.extract()
        t2, d2 = self.extract()
        self.assertEqual((t1, d1), (t2, d2))

    def run_fetch(self, *args):
        out = []
        code = fs.main(list(args) + ["--sources-json", str(self.sj), "--sources-dir", str(self.dir / "sources")], out=out.append)
        return code, out

    def test_manual_pin_check_and_mismatch(self):
        code, out = self.run_fetch()
        self.assertEqual(fs.EXIT_ERROR, code, out)              # not pinned yet
        code, out = self.run_fetch("--pin")
        self.assertEqual(0, code, out)
        rec = json.loads(self.sj.read_text(encoding="utf-8"))[0]
        self.assertTrue(all(len(f["sha256"]) == 64 for f in rec["fetch"]["files"]))
        self.assertEqual(fs.manual_digest(rec["fetch"]["files"]), rec["sha256"])
        self.assertEqual(0, self.run_fetch("--check")[0])
        (self.dir / "sources" / "AIP-T" / "ENR 1.2.pdf").write_bytes(b"%PDF-changed")
        code, out = self.run_fetch("--check")
        self.assertEqual(fs.EXIT_CHANGED, code, out)
        (self.dir / "sources" / "AIP-T" / "ENR 1.2.pdf").unlink()
        code, out = self.run_fetch()
        self.assertEqual(fs.EXIT_ERROR, code)
        self.assertTrue(any("missing" in line for line in out), out)

    def test_adding_a_section_changes_the_source_digest(self):
        self.assertEqual(0, self.run_fetch("--pin")[0])
        rec = json.loads(self.sj.read_text(encoding="utf-8"))[0]
        rec["fetch"]["files"].append({"section": "ENR 1.4", "file": "ENR 1.4.pdf"})
        (self.dir / "sources" / "AIP-T" / "ENR 1.4.pdf").write_bytes(make_positioned_pdf([[(52, 60, 10, "ENR 1.4 KLASYFIKACJA")]]))
        self.sj.write_text(json.dumps([rec]), encoding="utf-8")
        self.assertEqual(0, self.run_fetch("--pin")[0])
        rec2 = json.loads(self.sj.read_text(encoding="utf-8"))[0]
        self.assertNotEqual(rec["sha256"], rec2["sha256"])


class RegulationPartsTest(unittest.TestCase):
    def test_paragraph_sign_regulation_units(self):
        text = ("§ 1. 1. Rozporządzenie określa zasady.\n2. Drugi ustęp:\n1) pierwszy punkt;\n2) drugi punkt.\n"
                "§ 2. Ilekroć jest mowa o:\n1) lotnisku - rozumie się obszar;\n2) lądowisku - rozumie się teren.\n"
                "§ 3. Przepis końcowy.\nZałącznik nr 1\n1. Wiersz\n")
        a = ec.statute_anchors(text)
        for key in ("§ 1", "§ 1 ust. 1", "§ 1 ust. 2", "§ 1 ust. 2 pkt 2", "§ 2", "§ 2 pkt 1", "§ 2 pkt 2", "§ 3",
                    "załącznik 1", "załącznik 1 pkt 1"):
            self.assertIn(key, a, key)
        self.assertNotIn("art. 1", a)
        import materials as m
        for loc in ("§ 1", "§ 8 ust. 2 pkt 3", "§ 14a"):
            self.assertTrue(m.loc_valid("statute", loc), loc)
        self.assertEqual(m.loc_parents("§ 8 ust. 2 pkt 3"), ["§ 8 ust. 2", "§ 8"])

    def test_annex_points_of_eu_regulation_without_rule_ids(self):
        text = ("Artykuł 1\nPrzedmiot\n1. Ustęp.\nZAŁĄCZNIK\n1. OCHRONA PORTU LOTNICZEGO\n1.0. PRZEPISY OGÓLNE\n"
                "3. KONTROLA DOSTĘPU\n3.1. Zasady ogólne dotyczące kontroli osób.\n3.1.1. Pierwszy punkt szczegółowy.\n")
        a = ec.eureg_anchors(text, ("annexpoints",))
        for key in ("art. 1", "załącznik", "załącznik pkt 1", "załącznik pkt 1.0", "załącznik pkt 3.1", "załącznik pkt 3.1.1"):
            self.assertIn(key, a, key)
        self.assertNotIn("załącznik pkt 3.1", ec.eureg_anchors(text))      # off by default
        self.assertTrue(a["załącznik pkt 3.1"][0] <= a["załącznik pkt 3.1.1"][0])

    def test_skill_test_sections_stay_inside_the_amc_and_get_anchors(self):
        text = ("AMC1 SFCL.145 Skill test for the SPL\nED Decision 2020/004/R\n(d) CONTENT OF THE SKILL TEST\n"
                "(1) The following skill test contents and sections should be used for the skill test:\n"
                "SECTION 1: PRE-FLIGHT OPERATIONS AND DEPARTURE\na Pre-flight inspection and documentation of the sailplane\n"
                "SECTION 2A: WINCH OR CAR LAUNCH\na Signals before and during launch, including messages\n"
                "(2) For a TMG the following sections apply:\nSECTION 5: TMG OPERATIONS\na Engine start and warm-up of the motor glider\n"
                "SERA.4001 Submission of a flight plan\nRegulation (EU) 2023/1\n(a) A flight plan shall be submitted before departure.\n"
                "SECTION 4 Flight plans\nSERA.4005 Content of a flight plan\nRegulation (EU) 2023/1\n(a) The plan shall contain the aircraft identification.\n")
        a = ec.rule_anchors(text, "easa")
        for key in ("AMC1 SFCL.145", "AMC1 SFCL.145 SECTION 1", "AMC1 SFCL.145 SECTION 2A", "AMC1 SFCL.145 SECTION 5", "SERA.4001", "SERA.4005"):
            self.assertIn(key, a, key)
        amc = anchor_text(text, a, "AMC1 SFCL.145")
        self.assertIn("SECTION 5: TMG OPERATIONS", amc)
        self.assertIn("Engine start and warm-up", amc)
        self.assertNotIn("SERA.4001", amc)
        sec1 = anchor_text(text, a, "AMC1 SFCL.145 SECTION 1")
        self.assertIn("Pre-flight inspection", sec1)
        self.assertNotIn("WINCH", sec1)
        self.assertNotIn("SECTION 4 Flight plans", anchor_text(text, a, "SERA.4001"))   # a real division heading still ends the rule
        import materials as m
        self.assertTrue(m.loc_valid("easa", "AMC1 SFCL.145 SECTION 2A"))
        self.assertEqual(m.loc_parents("AMC1 SFCL.145 SECTION 2A"), ["AMC1 SFCL.145"])

    def test_annex_definitions_of_eu_regulation(self):
        text = ("Artykuł 1\nPrzedmiot\n1. Ustęp.\nZAŁĄCZNIK I\nDEFINICJE TERMINÓW\n"
                "2) „prace lotnicze” oznaczają operację statku powietrznego;\n"
                "57) „lotnictwo ogólne” oznacza wszelkie operacje lotnictwa cywilnego oprócz prac lotniczych;\n"
                "57a) „lotnictwo dodatkowe” oznacza przykład;\nZAŁĄCZNIK II\nATM/ANS.AR.A.001 Zakres\nW niniejszym załączniku ustanawia się wymagania.\n")
        a = ec.eureg_anchors(text, ("annexdefs",))
        for key in ("załącznik I", "załącznik I pkt 2", "załącznik I pkt 57", "załącznik I pkt 57a", "załącznik II"):
            self.assertIn(key, a, key)
        s, e = a["załącznik I pkt 57"]
        self.assertIn("lotnictwo ogólne", text[s:e])
        self.assertNotIn("lotnictwo dodatkowe", text[s:e])
        self.assertNotIn("załącznik I pkt 2", ec.eureg_anchors(text))     # off by default

    def test_rule_ids_with_slash_and_cs_prefix(self):
        text = ("ATM/ANS.OR.A.001 Application for a certificate\nRegulation (EU) 2017/373\n(a) A provider shall apply to the authority.\n"
                "CS ADR-DSN.B.075 Runway shoulders\nED Decision 2016/027/R\nRunway shoulders should be provided where the code letter is D or E.\n"
                "ADR.OPS.B.010 Rescue and firefighting\nRegulation (EU) 139/2014\n(a) The aerodrome operator shall provide the service.\n")
        a = ec.rule_anchors(text, "easa")
        for key in ("ATM/ANS.OR.A.001", "ATM/ANS.OR.A.001(a)", "CS ADR-DSN.B.075", "ADR.OPS.B.010"):
            self.assertIn(key, a, key)
        import materials as m
        for loc in ("ATM/ANS.OR.A.001", "CS ADR-DSN.B.075", "ADR.OPS.B.010(a)"):
            self.assertTrue(m.loc_valid("easa", loc), loc)
            self.assertTrue(m.loc_valid("eu_reg", loc) or loc.startswith("CS "), loc)


class OwnerDocumentsTest(unittest.TestCase):
    """Owner-supplied ICAO / ITU PDFs: manual sources, English, reference-only."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dir = pathlib.Path(self.tmp.name)
        (self.dir / "sources" / "OWN").mkdir(parents=True)

    def run_extract(self, sid, kind, name, pages, cfg):
        (self.dir / "sources" / "OWN" / name).write_bytes(make_positioned_pdf(pages))
        src = {"id": sid, "kind": kind, "lang": "en", "format": "pdf", "status": "available", "url": "u", "sha256": "",
               "fetched": "", "fetch": {"mode": "manual", "dir": "OWN", "files": [dict(section=sid, file=name, **cfg)]}}
        sj = self.dir / "sources.json"
        sj.write_text(json.dumps([src]), encoding="utf-8")
        out = []
        code = ec.main(["--all", "--jobs", "1", "--sources-json", str(sj), "--sources-dir", str(self.dir / "sources"),
                        "--corpus-dir", str(self.dir / "corpus"), "--anchors-dir", str(self.dir / "anchors")], out=out.append)
        self.assertEqual(0, code, out)
        return ((self.dir / "corpus" / (sid + ".txt")).read_text(encoding="utf-8"),
                json.loads((self.dir / "anchors" / (sid + ".json")).read_text(encoding="utf-8")))

    def test_doc7300_english_pages_articles_and_paragraphs(self):
        en = [(40, 60, 10, "Article 1"), (40, 74, 10, "Sovereignty the contracting States recognize that each State shall have"),
              (40, 88, 10, "complete and exclusive sovereignty over the airspace and the territory of the State."),
              (40, 120, 10, "Article 3 bis*"), (40, 134, 10, "a) The contracting States recognize that every State must refrain from the use of"),
              (40, 148, 10, "b) The contracting States recognize that every State shall be entitled to require that"),
              (40, 162, 10, "Article 3 bis. This amendment came into force on 1 October 1998."),
              (320, 60, 10, "Article 1"), (320, 74, 10, "Souverainete les Etats contractants reconnaissent que chaque Etat a la")]
        filler = [(40, 180 + 14 * i, 10, "The contracting States agree that the State shall apply the rules to each aircraft and to any flight of the State.") for i in range(6)]
        en = en + filler
        foreword = [(40, 60, 10, "Foreword the Convention is a text which shall be read with the introduction of the"),
                    (40, 74, 10, "Article 1 appears here only in the table of contents of the printed edition of this book")]
        text, doc = self.run_extract("DOC7300", "icao", "d.pdf", [foreword, en], {"profile": "icao7300", "lang": "en"})
        a = doc["anchors"]
        for key in ("Article 1", "Article 3 bis", "Article 3 bis(a)", "Article 3 bis(b)"):
            self.assertIn(key, a, key)
        self.assertNotIn("Souverainete", text)       # only the English (left) column
        self.assertNotIn("Foreword", text)           # nothing before Article 1
        self.assertEqual({"DOC7300": "en"}, doc["langs"])

    def test_doc4444_chapters_definitions_and_paragraph_numbers(self):
        def page(header, items):
            return [(66, 51, 9, header)] + items + [(66, 735, 8, "10/11/16")]
        p1 = page("Chapter 1. Definitions 1-3", [
            (66, 81, 10, "Aerodrome control service. Air traffic control service for aerodrome traffic."),
            (66, 105, 10, "Air traffic management (ATM). The dynamic, integrated management of air traffic"),
            (84, 117, 10, "and airspace including air traffic services."),
            (84, 141, 10, "Note.- A note belonging to the previous definition.")])
        p2 = page("5-2 Air Traffic Management (PANS-ATM)", [])
        p3 = page("Chapter 5. Separation Methods and Minima 5-3", [
            (200, 81, 10, "5.2 VERTICAL SEPARATION"), (84, 105, 10, "5.2.1 Vertical separation is obtained by requiring aircraft to use different levels."),
            (66, 117, 10, "selected from the tables."), (84, 141, 10, "5.2.1.1 Detail of the first rule."),
            (84, 165, 10, "Note.- see Chapter 8, 8.6.5.2 for vectoring.")])
        p0 = [(66, 60, 10, "Foreword nothing here")]
        text, doc = self.run_extract("DOC4444", "icao", "d.pdf", [p0, [(66, 80, 10, "Chapter 1")], p1, p2, p3],
                                     {"profile": "icao4444", "lang": "en"})
        a = doc["anchors"]
        for key in ("Chapter 1", "Chapter 5", "def Aerodrome control service", "def Air traffic management (ATM)",
                    "pkt 5.2", "pkt 5.2.1", "pkt 5.2.1.1"):
            self.assertIn(key, a, key)
        self.assertNotIn("Chapter 8", a)       # a "Chapter 8." reference inside a note is not a chapter
        s, e = a["def Air traffic management (ATM)"]
        self.assertIn("airspace including air traffic services", text[s:e])
        self.assertIn("Note.- A note belonging", text[s:e])
        self.assertNotIn("Foreword", text)

    def test_itu_appendix_18_channels_and_notes(self):
        page = [(150, 40, 11, "APPENDIX 18 (REV.WRC-19)"), (40, 80, 9, "Channel Notes frequencies"),
                (44, 120, 9, "06 f) 156.300 x"), (44, 132, 9, "16 156.800 156.800 x"),
                (44, 144, 9, "AIS 1 f), l), p) 161.975 161.975"), (170, 200, 9, "Notes referring to the Table"),
                (40, 220, 9, "f) The frequencies 156.300 MHz may also be used by aircraft stations."),
                (55, 232, 9, "for search and rescue."), (40, 250, 9, "g) Channels 15 and 17 may also be used on board."),
                (353, 22, 8, "AP18-1")]
        other = [(150, 40, 11, "APPENDIX 25 (REV.WRC-03)"), (44, 120, 9, "99 156.999 x")]
        text, doc = self.run_extract("ITU18", "itu", "r.pdf", [page, other], {"profile": "itu-rr", "lang": "en", "pages": [0, 0]})
        a = doc["anchors"]
        for key in ("Appendix 18", "Appendix 18 channel 06", "Appendix 18 channel 16", "Appendix 18 channel AIS1",
                    "Appendix 18 note f", "Appendix 18 note g"):
            self.assertIn(key, a, key)
        self.assertNotIn("APPENDIX 25", text)      # only the requested pages
        self.assertNotIn("AP18-1", text)
        self.assertIn("search and rescue", text[slice(*a["Appendix 18 note f"])])


class ReviewSrc2R1Test(unittest.TestCase):
    """M-SRC2-r1: wrapped cross-references, annex numbering, SECTION series, lit., two-letter points, closing sentences."""

    def test_aip_wrapped_cross_reference_is_not_a_point(self):
        text = ("ENR 1.10 PLANOWANIE LOTOW\n3 SKLADANIE PLANU\n3.11. Pole wyboru w prawym dolnym rogu formularza opublikowanego w AIP Polska ENR\n"
                "1.10 oraz dopisac adres e-mail.\n3.12. Nastepny punkt.\n4 DYSTRYBUCJA\n4.4. Plan mozna przeslac (patrz: ENR\n"
                "1.11 ADRESOWANIE KOMUNIKATOW) oraz:\ne.faksem;\n")
        sections = [("ENR 1.10", 0, len(text), {}, [])]
        a, _ = ec.aip_sections_anchors(text, sections)
        self.assertNotIn("ENR 1.10 pkt 1.10", a)
        self.assertNotIn("ENR 1.10 pkt 1.11", a)
        self.assertIn("faksem", text[slice(*a["ENR 1.10 pkt 4.4"])])
        self.assertIn("oraz dopisac", text[slice(*a["ENR 1.10 pkt 3.11"])])

    def test_aip_heading_numbers_must_run_in_order(self):
        text = "GEN 3.1 X\n1 PIERWSZY\ntekst\n2 DRUGI\ntekst\n15 ICAO.\ndalej tekst\n3 TRZECI\ntekst\n"
        a, _ = ec.aip_sections_anchors(text, [("GEN 3.1", 0, len(text), {}, [])])
        self.assertNotIn("GEN 3.1 pkt 15", a)
        self.assertIn("dalej tekst", text[slice(*a["GEN 3.1 pkt 2"])])
        self.assertIn("GEN 3.1 pkt 3", a)

    def test_aip_abbreviation_with_two_meanings_and_class_footnotes(self):
        text = "GEN 2.2 SKROTY\nCTA¤ Obliczony czas przybycia\nCTA Obszar kontrolowany\nCTAM Wznies sie\n"
        a, _ = ec.aip_sections_anchors(text, [("GEN 2.2", 0, len(text), {"entries": "abbreviations"}, [])])
        self.assertEqual("CTA Obliczony czas przybycia\n", text[slice(*a["GEN 2.2 CTA"])].replace("¤", ""))
        self.assertIn("Obszar kontrolowany", text[slice(*a["GEN 2.2 CTA 2"])])
        t2 = "ENR 1.4 KLASY\nF IFR a\nG IFR Brak sluzby\nVFR Brak\n* - Gdy wysokosc jest mniejsza niz 3050 m.\n**** - Klasa nie stosowana w FIR Warszawa.\n"
        a2, _ = ec.aip_sections_anchors(t2, [("ENR 1.4", 0, len(t2), {"classes": True}, [])])
        self.assertIn("klasa G", " ".join(a2))
        self.assertNotIn("nie stosowana", t2[slice(*a2["ENR 1.4 klasa G"])])
        self.assertIn("nie stosowana", t2[slice(*a2["ENR 1.4 przypis ****"])])
        import materials as m
        for loc in ("GEN 2.2 CTA 2", "ENR 1.4 przypis **"):
            self.assertTrue(m.loc_valid("aip", loc), loc)
            self.assertEqual(["GEN 2.2" if loc.startswith("GEN") else "ENR 1.4"], m.loc_parents(loc))

    def test_second_exam_section_series_gets_its_own_keys(self):
        text = ("AMC1 SFCL.145 Skill test\nED Decision 2020/004/R\n(d) CONTENT OF THE SKILL TEST\n"
                "(1) The skill test contents for the issue of an SPL in a sailplane:\n"
                "SECTION 1: PRE-FLIGHT\na Pre-flight inspection of the sailplane\nSECTION 4: CIRCUIT\na Circuit and landing\n"
                "(2) The skill test contents for the issue of an SPL in a TMG:\n"
                "SECTION 1: PRE-FLIGHT\na Pre-flight inspection of the TMG\nSECTION 5: ABNORMAL\na Engine failure\n"
                "SERA.4001 Submission of a flight plan\nRegulation (EU) 2023/1\n(a) A flight plan shall be submitted before departure.\n")
        a = ec.rule_anchors(text, "easa")
        self.assertIn("sailplane", text[slice(*a["AMC1 SFCL.145 SECTION 1"])])
        sec4 = text[slice(*a["AMC1 SFCL.145 SECTION 4"])]
        self.assertIn("Circuit", sec4)
        self.assertNotIn("TMG", sec4)             # the introduction of the second table is not part of SECTION 4
        self.assertNotIn("AMC1 SFCL.145 SECTION 5", a)
        self.assertIn("Engine failure", text[slice(*a["AMC1 SFCL.145 (2) SECTION 5"])])
        self.assertIn("TMG", text[slice(*a["AMC1 SFCL.145 (2) SECTION 1"])])
        import materials as m
        self.assertTrue(m.loc_valid("easa", "AMC1 SFCL.145 (2) SECTION 5"))
        self.assertEqual(["AMC1 SFCL.145"], m.loc_parents("AMC1 SFCL.145 (2) SECTION 5"))

    def test_annexpoints_chapters_need_an_uppercase_heading(self):
        text = ("Artykuł 1\nPrzedmiot\n1. Ustęp.\nZAŁĄCZNIK\n1. OCHRONA PORTU\n1.1. Wymagania\n"
                "1. Przy projektowaniu uwzględnia się wymogi.\n2. W porcie ustanawia się następujące obszary:\n"
                "1.2. Kontrola dostępu\n2. STREFY WYDZIELONE\nTekst strefy.\n"
                "3. OCHRONA STATKU\n3.1. Przeszukanie\n3.1.1. Przeszukanie przed lotem.\n"
                "DODATEK 3-A\n8.1. Czy dostęp jest kontrolowany? TAK lub NIE\n8.2. Ocena\n"
                "ZAŁĄCZNIK\n4. PASAŻEROWIE\n4.1. Kontrola\n"
                "5. BAGAŻ\n5.1. Rejestrowany\n6.5 ZATWIERDZENI PRZEWOŹNICY\n")
        a = ec.eureg_anchors(text, ("annexpoints",))
        self.assertEqual("załącznik", [k for k in a if k.startswith("załącznik")][0])
        for key in ("załącznik pkt 1", "załącznik pkt 1.1", "załącznik pkt 1.2", "załącznik pkt 2", "załącznik pkt 3", "załącznik pkt 3.1",
                    "załącznik pkt 3.1.1", "załącznik pkt 4", "załącznik pkt 4.1", "załącznik pkt 5"):
            self.assertIn(key, a, key)
        self.assertNotIn("załącznik pkt 8.1", a)                                  # a questionnaire item of the appendix
        self.assertIn("W porcie ustanawia", text[slice(*a["załącznik pkt 1.1"])])   # paragraph "2." stays inside 1.1
        self.assertNotIn("STREFY", text[slice(*a["załącznik pkt 1.1"])])
        self.assertIn("Tekst strefy", text[slice(*a["załącznik pkt 2"])])
        self.assertNotIn("DODATEK", text[slice(*a["załącznik pkt 3.1.1"])])
        self.assertIn("załącznik pkt 5.1", a)

    def test_chapter_heading_between_articles_is_not_part_of_the_article(self):
        text = "Artykuł 1\nPrzedmiot\n1. Ustęp pierwszy.\nROZDZIAŁ II\nZASADY WSPÓLNE\nArtykuł 2\nDefinicje\n1. Ustęp.\n"
        a = ec.eureg_anchors(text)
        self.assertNotIn("ROZDZIAŁ", text[slice(*a["art. 1"])])
        self.assertNotIn("ROZDZIAŁ", text[slice(*a["art. 1 ust. 1"])])

    def test_appendix_sekcja_with_points(self):
        text = ("ZAŁĄCZNIK XI\nWymagania\nDodatek 1\nWYMAGANIA\nSEKCJA I\nSpecyfikacje\na) REJONY\nTekst rejonów:\n"
                "1) cały układ;\n2) cała przestrzeń.\nb) OBSZARY\n3) nie dotyczy\n1) Obszary wyznacza się tak.\n"
                "SEKCJA II\na) Trasy ATS\nZAŁĄCZNIK XII\nCoś\n")
        a = ec.eureg_anchors(text)
        for key in ("załącznik XI dodatek 1", "załącznik XI dodatek 1 sekcja I", "załącznik XI dodatek 1 sekcja I(a)",
                    "załącznik XI dodatek 1 sekcja I(a)(2)", "załącznik XI dodatek 1 sekcja I(b)", "załącznik XI dodatek 1 sekcja II",
                    "załącznik XI dodatek 1 sekcja II(a)"):
            self.assertIn(key, a, key)
        self.assertIn("cała przestrzeń", text[slice(*a["załącznik XI dodatek 1"])])
        self.assertNotIn("Cos", text[slice(*a["załącznik XI dodatek 1 sekcja II(a)"])])
        import materials as m
        self.assertTrue(m.loc_valid("eu_reg", "załącznik XI dodatek 1 sekcja I(a)(2)"))
        self.assertEqual(["załącznik XI dodatek 1 sekcja I(a)", "załącznik XI dodatek 1 sekcja I", "załącznik XI dodatek 1", "załącznik XI"],
                         m.loc_parents("załącznik XI dodatek 1 sekcja I(a)(2)"))

    def test_rule_heading_with_full_stop_two_letter_points_and_first_letter_c(self):
        text = ("SERA.7001. Przepisy ogólne\na) Pierwszy punkt;\nb) drugi punkt.\n"
                "SERA.8015 Zezwolenia\ne) Potwierdzenie przez powtórzenie:\n(i) zezwolenia ATC;\nea) Zmiany zezwolenia\neb) Zezwolenie dotyczące\n"
                "(i) zniżanie;\nec) Zezwolenia warunkowe\nf) Dalszy punkt\n"
                "SERA.11001 Przepisy ogólne\nc) W sytuacji awaryjnej organy ATS udzielają pomocy.\nd) Późniejsze działania.\n"
                "SERA.11005 Bezprawna ingerencja\naa) Statek stara się ustawić transponder.\nab) Pilot dowódca podejmuje starania.\nb) Organy ATS spełniają żądania.\n")
        a = ec.eureg_anchors(text, ())
        for key in ("SERA.7001", "SERA.7001(a)", "SERA.8015(e)", "SERA.8015(e)(i)", "SERA.8015(ea)", "SERA.8015(eb)", "SERA.8015(eb)(i)",
                    "SERA.8015(ec)", "SERA.8015(f)", "SERA.11001(c)", "SERA.11001(d)", "SERA.11005(aa)", "SERA.11005(ab)", "SERA.11005(b)"):
            self.assertIn(key, a, key)
        self.assertNotIn("Zmiany zezwolenia", text[slice(*a["SERA.8015(e)"])])
        import materials as m
        self.assertTrue(m.loc_valid("eu_reg", "SERA.8015(ea)"))

    def test_table_rows_are_not_points_and_closing_sentence_belongs_to_the_parent(self):
        text = ("SERA.14005 Kategorie\na) Kategorie zgodne z tabelą S14-1.\nTabela S14-1\nKategoria depesz\n"
                "a) Wezwanie w sytuacji zagrożenia\nMAYDAY\nb) Depesze pilne\nPAN PAN\nc) Komunikaty\n—\n"
                "b) Depesze o sytuacji zagrożenia należy traktować zgodnie z przepisami.\nc) Depesze pilne należy traktować inaczej.\n"
                "FCL.025 Egzaminy\n1) Wynik ważny przez okres:\n(i) 24 miesięcy;\n(ii) 36 miesięcy; lub\n(iii) bez ograniczeń czasowych.\n"
                "Okresy podane w ppkt (i) i (ii) liczy się od dnia egzaminu.\n2) Wynik ATPL pozostaje ważny.\n")
        a = ec.eureg_anchors(text, ())
        self.assertIn("Wezwanie", text[slice(*a["SERA.14005(a)"])])
        self.assertIn("Depesze o sytuacji", text[slice(*a["SERA.14005(b)"])])
        self.assertNotIn("Wezwanie", text[slice(*a["SERA.14005(b)"])])
        self.assertNotIn("PAN PAN", text[slice(*a["SERA.14005(b)"])])
        self.assertIn("Okresy podane", text[slice(*a["FCL.025(1)"])])
        self.assertNotIn("Okresy podane", text[slice(*a["FCL.025(1)(iii)"])])

    def test_statute_lit_sanction_tail_and_annex_heading_with_footnote(self):
        text = ("Art. 210. 1. Kto:\n1) pierwsze;\n2) drugie, w tym:\na) litera a;\nb) litera b;\nea) nie jest literą;\n"
                "3) trzecie\n– podlega karze grzywny.\n2. Ust drugi.\nZałącznik nr 2\nZałącznik nr 2\nWiersz\n"
                "Załącznik nr 35)\nZałącznik nr 2\nDane\n")
        a = ec.statute_anchors(text)
        for key in ("art. 210 ust. 1 pkt 2 lit. a", "art. 210 ust. 1 pkt 2 lit. b", "załącznik 2", "załącznik 3"):
            self.assertIn(key, a, key)
        self.assertNotIn("art. 210 ust. 1 pkt 2 lit. ea", a)
        self.assertNotIn("podlega", text[slice(*a["art. 210 ust. 1 pkt 3"])])
        self.assertIn("Dane", text[slice(*a["załącznik 3"])])
        import materials as m
        self.assertTrue(m.loc_valid("statute", "art. 5 ust. 1 pkt 2 lit. ea"))
        self.assertEqual(["art. 5 ust. 1 pkt 2", "art. 5 ust. 1", "art. 5"], m.loc_parents("art. 5 ust. 1 pkt 2 lit. b"))

    def test_icao_definition_line_after_a_wrapped_sentence_is_not_a_definition(self):
        text = ("== Chapter 1 ==\nDEFINITIONS\nAircraft. Any machine that can derive support.\n"
                "Note 2.-- References to the Radio Regulations published by the International\nTelecommunication Union (ITU). Amended often.\n"
                "Pressure-altitude. An atmospheric pressure.*\nPrimary radar. A radar system.\n")
        a = ec.owner_anchors(text, {"profile": "icao4444"})
        self.assertNotIn("def Telecommunication Union (ITU)", a)
        self.assertIn("def Primary radar", a)
        self.assertIn("def Aircraft", a)

    def test_easa_annex_definitions_and_article_paragraph_definitions(self):
        text = ("Article 2 Definitions\nRegulation (EU) No 139/2014\n(1) 'aerodrome’ means a defined area;\n(2) 'aeroplane’ means an aircraft;\n"
                "ANNEX I — DEFINITIONS\nRegulation (EU) 2024/1400\n(1) ‘Acceptable Means of Compliance (AMC)’ means standards;\n"
                "(4) ‘aerodrome equipment’ means equipment;\n(4a) ‘[aerodrome] traffic density’ means movements;\n(5) ‘aeronautical data’ means a representation;\n"
                "ANNEX II — AUTHORITY REQUIREMENTS\nADR.AR.A.001 Scope\n(a) This Annex applies.\n")
        a = ec.rule_anchors(text, "easa", ("article",))
        for key in ("Article 2", "Article 2(1)", "Article 2(2)", "Annex I", "Annex I(1)", "Annex I(4)", "Annex I(4a)", "Annex I(5)", "ADR.AR.A.001"):
            self.assertIn(key, a, key)
        self.assertNotIn("ADR.AR.A.001", text[slice(*a["Annex I(5)"])])
        import materials as m
        self.assertTrue(m.loc_valid("easa", "Annex I(4a)"))


class RealSourcesJsonTest(unittest.TestCase):
    def test_registry_is_well_formed(self):
        data = json.loads((HERE.parent / "sources.json").read_text(encoding="utf-8"))
        ids = [s["id"] for s in data]
        self.assertEqual(len(ids), len(set(ids)))
        for s in data:
            for k in ("id", "title_pl", "kind", "url", "format", "version", "sha256", "fetched",
                      "reuse", "allowQuote"):
                self.assertIn(k, s, "%s lacks %s" % (s.get("id"), k))
            self.assertIn(s["kind"], ("statute", "eu_reg", "convention", "aip", "easa", "icao", "itu"))
            self.assertIn(s["reuse"], ("public-domain", "eu-reuse", "reference-only"))
            if s["kind"] in ("aip", "easa") and (s.get("fetch") or {}).get("mode") != "manual":
                self.assertFalse(s["allowQuote"], s["id"])
            if s["kind"] in ("icao", "itu"):
                self.assertFalse(s["allowQuote"], s["id"])    # ICAO / ITU copyright: reference only
                self.assertEqual("reference-only", s["reuse"], s["id"])
            if s.get("status", "available") == "available":
                self.assertRegex(s["sha256"], r"^[0-9a-f]{64}$", s["id"])
            else:
                self.assertTrue(s.get("unavailable_reason"), s["id"])


if __name__ == "__main__":
    unittest.main()
