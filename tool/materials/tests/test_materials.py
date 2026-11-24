import copy
import io
import json
import shutil
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import materials as m  # noqa: E402

FIX = Path(__file__).resolve().parent / "fixtures" / "materials"

CORPUS = "Art. 1. Przepisy ogólne. Statek powietrzny to urządzenie zdolne do unoszenia się w atmosferze. Art. 2. Inny przepis."
GOOD_TEXT = "Odpowiada dowódca statku powietrznego. Wynika to wprost z przepisu art. 1."
GOOD_QUOTE = "Statek powietrzny to urządzenie zdolne do unoszenia się w atmosferze."


def jdump(path, obj):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, ensure_ascii=False), encoding="utf-8")


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / "assets" / "data").mkdir(parents=True)
        for p in FIX.glob("bank_*.json"):
            shutil.copy(p, self.root / "assets" / "data" / p.name)
        self.ctx = m.Ctx(self.root)
        jdump(self.ctx.sources, [{"id": "LAW", "title_pl": "Prawo lotnicze", "kind": "statute",
                                  "version": "Dz.U. test", "fetched": "2026-11-20", "legalState": "2026-09-16",
                                  "status": "available", "allowQuote": True},
                                 {"id": "UNAV", "title_pl": "Niedostępny", "kind": "eu_reg", "status": "unavailable",
                                  "fetched": "", "allowQuote": True},
                                 {"id": "REF", "title_pl": "Easy Access", "kind": "easa", "status": "available",
                                  "fetched": "2026-11-24", "allowQuote": False, "lang": "en"}])
        jdump(self.ctx.anchors / "REF.json", {"textSha": "y", "anchors": {"SERA.5005": [0, 5], "SERA.5005(a)": [0, 5]}})
        jdump(self.ctx.anchors / "UNAV.json", {"textSha": "z", "anchors": {"SERA.5005": [0, 5]}})
        (self.ctx.corpus).mkdir(parents=True)
        (self.ctx.corpus / "LAW.txt").write_text(CORPUS, encoding="utf-8")
        s1 = CORPUS.index("Art. 1.")
        s2 = CORPUS.index("Art. 2.")
        jdump(self.ctx.anchors / "LAW.json", {"textSha": "x", "anchors": {
            "art. 1": [s1, s2], "art. 2": [s2, len(CORPUS)], "art. 1 ust. 1": [s1, s2]}})
        jdump(self.ctx.ledger, {})
        self.run_cmd(m.cmd_inventory, stats=False)

    def run_cmd(self, fn, **kw):
        ns = type("A", (), kw)()
        buf = io.StringIO()
        with redirect_stdout(buf):
            rc = fn(self.ctx, ns)
        self.out = buf.getvalue()
        return rc

    def inv(self):
        return {e["key"]: e for e in m.read_json(self.ctx.inventory)}

    def key_of(self, number):
        return next(k for k in self.inv() if k.startswith(number + "#"))

    def rec(self, key, **over):
        r = {"key": key, "status": "draft", "text": GOOD_TEXT,
             "refs": [{"src": "LAW", "loc": "art. 1", "quote": GOOD_QUOTE}], "disputeNote": None, "sameAs": None}
        r.update(over)
        return r

    def put_src(self, name, records):
        jdump(self.ctx.src_dir / ("%s.json" % name), records)

    def validate(self, **kw):
        return m.validate_all(self.ctx, **kw)

    def review(self, name, verdicts):
        p = self.root / name
        jdump(p, verdicts)
        return self.run_cmd(m.cmd_apply_review, file=str(p), date="2026-11-24")

    def build(self):
        self.run_cmd(m.cmd_build)
        return json.loads(self.ctx.asset.read_text(encoding="utf-8"))


class FingerprintTest(unittest.TestCase):
    def test_stable_under_wrong_answer_order_case_and_spaces(self):
        a = m.fingerprint("Pytanie?", "Dobra", ["x", "y", "z"])
        b = m.fingerprint("  PYTANIE?  ", "dobra ", ["Z", "X", "y"])
        self.assertEqual(a, b)

    def test_tags_and_tail_ignored(self):
        a = m.fingerprint("H<sub>2</sub>O", "ok", ["a", "b", "c"])
        b = m.fingerprint("H2O", "ok /n", ["a", "b", "c"])
        self.assertEqual(a, b)

    def test_one_wrong_answer_changes_key(self):
        a = m.fingerprint("P", "ok", ["a", "b", "c"])
        b = m.fingerprint("P", "ok", ["a", "b", "d"])
        self.assertNotEqual(a, b)

    def test_correct_answer_matters(self):
        self.assertNotEqual(m.fingerprint("P", "ok", ["a", "b", "c"]), m.fingerprint("P", "a", ["ok", "b", "c"]))


class SentenceTest(unittest.TestCase):
    def test_count(self):
        self.assertEqual(m.count_sentences("Jedno zdanie."), 1)
        self.assertEqual(m.count_sentences("Zgodnie z art. 5 ust. 2 pkt 3 tak jest. Drugie zdanie, np. takie."), 2)
        self.assertEqual(m.count_sentences("A. B! C? D."), 4)
        self.assertEqual(m.count_sentences("Wartość 1.5 m jest duża. Drugie."), 2)


class InventoryTest(Base):
    def test_one_key_two_links_across_licences(self):
        inv = self.inv()
        k = self.key_of("PL010-0001")
        self.assertEqual(inv[k]["licences"], ["ppla", "pplh", "spl"])
        self.assertEqual(inv[k]["ids"], {"ppla": "PL010-0001~aaaaaa", "pplh": "PL010-0001~bbbbbb", "spl": "PL010-0001"})
        self.assertEqual(sum(len(e["ids"]) for e in inv.values()), 6)  # не-air_law отброшен

    def test_raw_mixed(self):
        self.assertTrue(self.inv()[self.key_of("PL010-0003")]["rawMixed"])
        self.assertFalse(self.inv()[self.key_of("PL010-0001")]["rawMixed"])

    def test_deterministic(self):
        a = self.ctx.inventory.read_bytes()
        self.run_cmd(m.cmd_inventory, stats=False)
        self.assertEqual(a, self.ctx.inventory.read_bytes())

    def test_uncovered_question_is_error(self):
        inv = m.read_json(self.ctx.inventory)
        inv = [e for e in inv if e["number"] != "PL010-1001"]
        jdump(self.ctx.inventory, inv)
        self.assertTrue(any("не покрыт" in e for e in self.validate(no_corpus=True).errors))

    def test_links_to_one_key_for_all_licences(self):
        k = self.key_of("PL010-0001")
        self.put_src("P01", [self.rec(k)])
        self.review("P01.r1.editor.json", [{"key": k, "verdict": "PASS", "note": ""}])
        links = self.build()["links"]
        for lic, qid in self.inv()[k]["ids"].items():
            self.assertEqual(links[lic][qid], k)


class BuildTest(Base):
    def test_empty_asset_valid(self):
        a = self.build()
        self.assertEqual(a["explanations"], {})
        self.assertEqual(a["links"], {l: {} for l in m.LICENCES})
        self.assertEqual(self.validate(no_corpus=True, check_asset=True).errors, [])

    def test_draft_not_in_asset(self):
        k = self.key_of("PL010-0001")
        self.put_src("P01", [self.rec(k)])
        self.assertEqual(self.build()["explanations"], {})

    def test_verified_in_asset_without_quote(self):
        k = self.key_of("PL010-0001")
        self.put_src("P01", [self.rec(k)])
        self.review("P01.r1.editor.json", [{"key": k, "verdict": "PASS", "note": ""}])
        a = self.build()
        self.assertEqual(a["explanations"][k]["status"], "verified")
        self.assertEqual(a["explanations"][k]["refs"], [{"src": "LAW", "loc": "art. 1"}])
        self.assertNotIn('"quote"', self.ctx.asset.read_text(encoding="utf-8"))
        self.assertEqual(a["legalStateAsOf"], "2026-09-16")
        self.assertEqual(self.validate(check_asset=True).errors, [])

    def test_build_twice_identical(self):
        k = self.key_of("PL010-0001")
        self.put_src("P01", [self.rec(k)])
        self.review("P01.r1.editor.json", [{"key": k, "verdict": "PASS"}])
        self.run_cmd(m.cmd_build)
        a = self.ctx.asset.read_bytes()
        self.run_cmd(m.cmd_build)
        self.assertEqual(a, self.ctx.asset.read_bytes())

    def test_sameas_expands_links(self):
        k1 = self.key_of("PL010-0001")
        k3 = self.key_of("PL010-0003")
        self.put_src("P01", [self.rec(k1), self.rec(k3, text=None, refs=[], sameAs=k1)])
        self.review("P01.r1.editor.json", [{"key": k1, "verdict": "PASS"}, {"key": k3, "verdict": "PASS"}])
        a = self.build()
        self.assertEqual(list(a["explanations"]), [k1])
        self.assertEqual(a["links"]["pplh"]["PL010-0003"], k1)
        self.assertEqual(self.validate(no_corpus=True).errors, [])

    def test_sameas_missing_target_is_error(self):
        k3 = self.key_of("PL010-0003")
        self.put_src("P01", [self.rec(k3, text=None, refs=[], sameAs="PL010-9999#deadbeef")])
        self.assertTrue(any("sameAs на несуществующий" in e for e in self.validate(no_corpus=True).errors))

    def test_check_detects_stale_asset(self):
        self.build()
        k = self.key_of("PL010-0001")
        self.put_src("P01", [self.rec(k)])
        self.review("P01.r1.editor.json", [{"key": k, "verdict": "PASS"}])
        self.assertTrue(any("не совпадает с результатом build" in e
                            for e in self.validate(check_asset=True).errors))


class ValidateTest(Base):
    def setUp(self):
        super().setUp()
        self.k = self.key_of("PL010-0001")

    def errors(self, **kw):
        return self.validate(**kw).errors

    def verified(self):
        self.put_src("P01", [self.rec(self.k)])
        self.review("P01.r1.editor.json", [{"key": self.k, "verdict": "PASS"}])

    def test_clean(self):
        self.verified()
        self.assertEqual(self.errors(), [])

    def test_edit_after_review_removes_from_asset_and_fails(self):
        self.verified()
        path = self.ctx.src_dir / "P01.json"
        data = m.read_json(path)
        data[0]["text"] = "Odpowiada pilot. Tak stanowi przepis art. 1 ustawy."
        jdump(path, data)
        self.assertEqual(self.build()["explanations"], {})
        self.assertTrue(any("textSha" in e for e in self.errors()))

    def test_orphan_error_retired_ok(self):
        self.put_src("P01", [self.rec("PL010-0001#00000000")])
        self.assertTrue(any("сирота" in e for e in self.errors(no_corpus=True)))
        self.put_src("P01", [self.rec("PL010-0001#00000000", status="retired")])
        self.assertEqual(self.errors(no_corpus=True), [])

    def test_orphan_lists_candidates_with_same_number(self):
        self.put_src("P01", [self.rec("PL010-0001#00000000")])
        self.assertTrue(any(self.k in e for e in self.errors(no_corpus=True)))

    def test_duplicate_key_in_two_files(self):
        self.put_src("P01", [self.rec(self.k)])
        self.put_src("P02", [self.rec(self.k)])
        self.assertTrue(any("ключ уже есть" in e for e in self.errors(no_corpus=True)))

    def test_bad_status(self):
        self.put_src("P01", [self.rec(self.k, status="great")])
        self.assertTrue(any("вне списка" in e for e in self.errors(no_corpus=True)))

    def test_bad_loc(self):
        for loc in ("art. 99", "Artykul 1", "art. 1 ust. 7"):
            self.put_src("P01", [self.rec(self.k, status="verified",
                                          refs=[{"src": "LAW", "loc": loc, "quote": GOOD_QUOTE}])])
            self.assertTrue(any("loc" in e or "якоря" in e for e in self.errors(no_corpus=True)), loc)

    def test_unknown_src(self):
        self.put_src("P01", [self.rec(self.k, status="verified",
                                      refs=[{"src": "NOPE", "loc": "art. 1", "quote": "x"}])])
        self.assertTrue(any("sources.json" in e for e in self.errors(no_corpus=True)))

    def test_verified_without_refs(self):
        self.put_src("P01", [self.rec(self.k, status="verified", refs=[])])
        self.assertTrue(any("нет refs" in e for e in self.errors(no_corpus=True)))

    def test_quote_not_in_corpus(self):
        self.put_src("P01", [self.rec(self.k, refs=[{"src": "LAW", "loc": "art. 1", "quote": "Tego nie ma w ustawie."}])])
        self.assertTrue(any("quote не найден" in e for e in self.errors()))
        self.assertEqual(self.errors(no_corpus=True), [])

    def test_quote_normalisation_and_other_article(self):
        q = "Statek  powietrzny to urządzenie\nzdolne do unoszenia się w atmosferze."
        self.put_src("P01", [self.rec(self.k, refs=[{"src": "LAW", "loc": "art. 1", "quote": q}])])
        self.assertEqual(self.errors(), [])
        self.put_src("P01", [self.rec(self.k, refs=[{"src": "LAW", "loc": "art. 2", "quote": GOOD_QUOTE}])])
        self.assertTrue(any("quote не найден" in e for e in self.errors()))

    def test_quote_too_long(self):
        self.put_src("P01", [self.rec(self.k, refs=[{"src": "LAW", "loc": "art. 1", "quote": "a" * 301}])])
        self.assertTrue(any("quote длиннее" in e for e in self.errors(no_corpus=True)))

    def test_disputed_without_note(self):
        self.put_src("P01", [self.rec(self.k, status="disputed")])
        self.assertTrue(any("нет disputeNote" in e for e in self.errors(no_corpus=True)))

    def test_text_length(self):
        self.put_src("P01", [self.rec(self.k, text="Jedno zdanie.")])
        self.assertTrue(any("предложений" in e for e in self.errors(no_corpus=True)))
        self.put_src("P01", [self.rec(self.k, text="Zdanie. " * 5)])
        self.assertTrue(any("предложений" in e for e in self.errors(no_corpus=True)))
        self.put_src("P01", [self.rec(self.k, text=("Słowo " * 60 + "koniec. ") * 2)])
        self.assertTrue(any("700" in e for e in self.errors(no_corpus=True)))

    def test_topics_checks(self):
        keys = sorted(self.inv())
        jdump(self.ctx.topics, [{"id": "AL01", "title": {"pl": "a", "en": "a"}, "order": keys[:2], "complete": False},
                                {"id": "AL02", "title": {"pl": "b", "en": "b"}, "order": keys[1:3], "complete": False}])
        errs = self.errors(no_corpus=True)
        self.assertTrue(any("в двух подтемах" in e for e in errs))
        self.assertTrue(any("не назначены" in e for e in errs))
        jdump(self.ctx.topics, [{"id": "AL01", "title": {"pl": "a", "en": "a"}, "order": keys, "complete": False}])
        self.assertEqual(self.errors(no_corpus=True), [])

    def test_complete_topic_requires_section_coverage(self):
        keys = sorted(self.inv())
        jdump(self.ctx.topics, [{"id": "AL01", "title": {"pl": "a", "en": "a"}, "order": keys, "complete": True}])
        sec = {"id": "AL01-1", "heading": "H", "body": ["Tekst."], "status": "draft",
               "refs": [{"src": "LAW", "loc": "art. 1", "quote": GOOD_QUOTE}], "questionKeys": keys[:2]}
        jdump(self.ctx.sum_dir / "AL01.json", {"topic": "AL01", "sections": [sec]})
        self.assertTrue(any("complete" in e for e in self.errors(no_corpus=True)))
        self.review("AL01.r1.editor.json", [{"key": "AL01-1", "verdict": "PASS"}])
        self.assertTrue(any("complete" in e for e in self.errors(no_corpus=True)))  # покрыты не все ключи
        sec["questionKeys"] = keys
        sec["status"] = "draft"
        jdump(self.ctx.sum_dir / "AL01.json", {"topic": "AL01", "sections": [sec]})
        self.review("AL01.r2.editor.json", [{"key": "AL01-1", "verdict": "PASS"}])
        self.assertEqual(self.errors(no_corpus=True), [])
        asset = self.build()
        self.assertEqual(asset["topics"][0]["summary"]["sections"][0]["id"], "AL01-1")
        self.assertEqual(set(asset["links"]["bpl"].values()), {self.key_of("PL010-1001")})


class ApplyReviewTest(Base):
    def setUp(self):
        super().setUp()
        self.k = self.key_of("PL010-0001")
        self.put_src("P01", [self.rec(self.k)])

    def status(self):
        return m.read_json(self.ctx.src_dir / "P01.json")[0]["status"]

    def ledger(self):
        return m.read_json(self.ctx.ledger)

    def test_pass_writes_ledger(self):
        self.assertEqual(self.review("P01.r1.editor.json", [{"key": self.k, "verdict": "PASS"}]), 0)
        self.assertEqual(self.status(), "verified")
        e = self.ledger()[self.k]
        self.assertEqual((e["portion"], e["round"], e["verdict"], e["date"]), ("P01", 1, "PASS", "2026-11-24"))

    def test_unknown_key_is_error_and_changes_nothing(self):
        rc = self.review("P01.r1.editor.json", [{"key": self.k, "verdict": "PASS"}, {"key": "PL010-0001#ffffffff", "verdict": "PASS"}])
        self.assertEqual(rc, 1)
        self.assertEqual(self.status(), "draft")
        self.assertEqual(self.ledger(), {})

    def test_disputed_needs_note(self):
        self.review("P01.r1.editor.json", [{"key": self.k, "verdict": "DISPUTED"}])
        self.assertEqual(self.status(), "unverified")
        self.put_src("P01", [self.rec(self.k, disputeNote="Klucz ULC budzi wątpliwości.")])
        self.review("P01.r1.editor.json", [{"key": self.k, "verdict": "DISPUTED"}])
        self.assertEqual(self.status(), "disputed")
        self.assertEqual(self.validate(no_corpus=True).errors, [])

    def test_fix_then_round2_unverified(self):
        self.review("P01.r1.editor.json", [{"key": self.k, "verdict": "FIX", "note": "zła ustawa"}])
        self.assertEqual(self.status(), "draft")
        self.review("P01.r2.editor.json", [{"key": self.k, "verdict": "FIX"}])
        self.assertEqual(self.status(), "unverified")
        self.assertEqual(self.build()["explanations"], {})

    def test_bad_file_name(self):
        p = self.root / "bad.json"
        jdump(p, [])
        self.assertEqual(self.run_cmd(m.cmd_apply_review, file=str(p), date=None), 1)

    def test_report(self):
        self.review("P01.r1.editor.json", [{"key": self.k, "verdict": "PASS"}])
        self.assertEqual(self.run_cmd(m.cmd_report, src=None), 0)
        self.assertIn("verified=1", self.out)
        self.assertIn("PASS 1 из 1", self.out)
        self.assertEqual(self.run_cmd(m.cmd_report, src="LAW"), 0)
        self.assertIn(self.k, self.out)


class SourcesTest(Base):
    def setUp(self):
        super().setUp()
        self.k = self.key_of("PL010-0001")

    def test_unavailable_source_cannot_be_cited(self):
        self.put_src("P01", [self.rec(self.k, status="verified", refs=[{"src": "UNAV", "loc": "SERA.5005"}])])
        self.assertTrue(any("недоступен" in e for e in self.validate(no_corpus=True).errors))
        self.ctx.ledger.write_text("{}")
        self.review("P01.r1.editor.json", [{"key": self.k, "verdict": "PASS"}])
        self.assertEqual(self.build()["explanations"], {})

    def test_reference_only_no_quote_anchor_checked(self):
        ref = {"src": "REF", "loc": "SERA.5005(a)"}
        self.put_src("P01", [self.rec(self.k, refs=[ref])])
        self.review("P01.r1.editor.json", [{"key": self.k, "verdict": "PASS"}])
        self.assertEqual(self.validate().errors, [])
        a = self.build()
        self.assertEqual(a["explanations"][self.k]["refs"], [ref])
        self.assertEqual(a["legalStateAsOf"], "2026-11-24")
        self.put_src("P01", [self.rec(self.k, status="verified", refs=[{"src": "REF", "loc": "SERA.5005(b)"}])])
        self.assertTrue(any("якоря" in e for e in self.validate().errors))

    def test_reference_only_quote_forbidden(self):
        self.put_src("P01", [self.rec(self.k, refs=[{"src": "REF", "loc": "SERA.5005", "quote": "x"}])])
        self.assertTrue(any("цитаты запрещены" in e for e in self.validate().errors))

    def test_legal_state_preferred(self):
        self.put_src("P01", [self.rec(self.k)])
        self.review("P01.r1.editor.json", [{"key": self.k, "verdict": "PASS"}])
        self.assertEqual(self.build()["legalStateAsOf"], "2026-09-16")


class RealAnchorsTest(unittest.TestCase):
    """Каждый ключ реальных anchors/*.json проходит грамматику своего вида (если файлы S1 есть)."""

    def test_all_real_anchor_keys_valid(self):
        mat = Path(__file__).resolve().parents[1]
        sources = {s["id"]: s for s in json.loads((mat / "sources.json").read_text(encoding="utf-8"))} \
            if (mat / "sources.json").exists() else {}
        files = sorted((mat / "anchors").glob("*.json"))
        if not files:
            self.skipTest("нет anchors/ (корпус не собран)")
        for f in files:
            kind = sources[f.stem]["kind"]
            bad = [k for k in json.loads(f.read_text(encoding="utf-8"))["anchors"] if not m.loc_valid(kind, k)]
            self.assertEqual(bad[:5], [], f.name)


class LocTest(unittest.TestCase):
    def test_statute_numbers(self):
        for loc in ("art. 67fa", "art. 156zd ust. 2", "art. 87[1]", "art. 87[1a] ust. 3 pkt 2", "art. 5 ust. 1a pkt 2b"):
            self.assertTrue(m.loc_valid("statute", loc), loc)
        for loc in ("art.", "art. 87[", "art. 87[]", "art. x1", "art. 5 pkt", "art. 5 ust. 1 ust. 2", "art 5", "art. 5; drop"):
            self.assertFalse(m.loc_valid("statute", loc), loc)

    def test_grammar(self):
        self.assertTrue(m.loc_valid("statute", "art. 128 ust. 1 pkt 2"))
        self.assertFalse(m.loc_valid("statute", "SERA.5005"))
        self.assertTrue(m.loc_valid("eu_reg", "SERA.5005(a)(1)"))
        self.assertTrue(m.loc_valid("eu_reg", "FCL.205.A"))
        self.assertTrue(m.loc_valid("eu_reg", "NCO.GEN.105"))
        self.assertTrue(m.loc_valid("aip", "ENR 1.2 pkt 2.1"))
        self.assertFalse(m.loc_valid("aip", "ENR"))

    def test_parents(self):
        self.assertEqual(m.loc_parents("art. 5 ust. 2 pkt 3"), ["art. 5 ust. 2", "art. 5"])
        self.assertEqual(m.loc_parents("SERA.5005(a)(1)"), ["SERA.5005(a)", "SERA.5005"])
        self.assertEqual(m.loc_parents("art. 5"), [])


if __name__ == "__main__":
    unittest.main()
