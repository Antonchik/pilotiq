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

    def test_eu_regulation_articles(self):
        text = "Artykuł 1\nPrzedmiot\n1. Pierwszy ustęp.\n2. Drugi ustęp.\nArtykuł 2\nDefinicje\n"
        a = ec.rule_anchors(text, "eu_reg")
        self.assertEqual({"art. 1", "art. 1 ust. 1", "art. 1 ust. 2", "art. 2"}, set(a))


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


class RealSourcesJsonTest(unittest.TestCase):
    def test_registry_is_well_formed(self):
        data = json.loads((HERE.parent / "sources.json").read_text(encoding="utf-8"))
        ids = [s["id"] for s in data]
        self.assertEqual(len(ids), len(set(ids)))
        for s in data:
            for k in ("id", "title_pl", "kind", "url", "format", "version", "sha256", "fetched",
                      "reuse", "allowQuote"):
                self.assertIn(k, s, "%s lacks %s" % (s.get("id"), k))
            self.assertIn(s["kind"], ("statute", "eu_reg", "convention", "aip", "easa"))
            self.assertIn(s["reuse"], ("public-domain", "eu-reuse", "reference-only"))
            if s["kind"] in ("aip", "easa"):
                self.assertFalse(s["allowQuote"], s["id"])
            if s.get("status", "available") == "available":
                self.assertRegex(s["sha256"], r"^[0-9a-f]{64}$", s["id"])
            else:
                self.assertTrue(s.get("unavailable_reason"), s["id"])


if __name__ == "__main__":
    unittest.main()
