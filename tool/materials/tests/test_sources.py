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
