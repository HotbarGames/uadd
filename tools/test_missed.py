"""tools/missed.py on a made-up SavedVariables file (no real addon text): the Lua reader, the groups, the
files it writes, that STAY texts (also a STAY template filled in) and account folder names never show, a file
it cannot read, the names bucket, and the exit codes (1: texts listed, 0: "nothing missed.", 2: nothing read).

Run: python3 -m unittest tools.test_missed
"""
import contextlib
import io
import os
import sys
import tempfile
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hashtext  # noqa: E402
import missed  # noqa: E402

ACCOUNT = "SECRETACCOUNT42"
SAVED = rb"""
UADD_DB = {
	["version"] = "1.0",
	["modules"] = {
		["fxpb"] = { ["enabled"] = true, },
	},
	["missed"] = {
		["mods"] = {
			["fxpb"] = {
				["v"] = "2.0",
				["dropped"] = 3,
				["texts"] = {
					["14:00000001"] = { ["t"] = "Wobbly gizmo #", ["n"] = 7, ["d"] = "2026-11-18", ["v"] = "2.0", },
					["10:00000002"] = { ["t"] = "Zork Plank", ["n"] = 2, ["d"] = "2026-11-17", ["v"] = "2.0", },
					["10:00000003"] = { ["t"] = "Old thingy", ["n"] = 1, ["d"] = "2026-11-01", ["v"] = "1.9", },
					["10:00000004"] = { ["t"] = "Stay as is", ["n"] = 9, ["d"] = "2026-11-18", ["v"] = "2.0", },
					["10:00000005"] = { ["t"] = "Two\nlines \"quoted\" \208\184", ["n"] = 1, ["d"] = "2026-11-18", },
				},
			},
			["layerswap"] = {
				["namesDropped"] = 4,
				["names"] = {
					["9:00000006"] = { ["t"] = "Quux Vale", ["n"] = 3, ["d"] = "2026-11-18", },
				},
			},
			["openmap"] = {
				["texts"] = {
				},
			},
		},
	},
}
-- [1] a comment the game may write
"""


class Reader(unittest.TestCase):
    def test_parse(self):
        db = missed.parse(b"A = { 1, -2.5, [\"k\"] = { x = true, [3] = false }, 0x10, } B = nil")
        self.assertEqual(db["A"], {1: 1, 2: -2.5, "k": {"x": True, 3: False}, 3: 16})
        self.assertIsNone(db["B"])

    def test_odd_numbers(self):
        db = missed.parse(b"A = { inf, -inf, nan, -nan(ind), 1.#INF, -1.#IND, 1.#QNAN, [nan] = 1, x = info, }")
        a = db["A"]
        self.assertEqual((a[1], a[2], a[5]), (float("inf"), float("-inf"), float("inf")))
        self.assertTrue(all(a[i] != a[i] for i in (3, 4, 6, 7)))     # NaN
        self.assertIsNone(a["x"])                                      # a bare word: no value
        self.assertEqual(len(a), 8)                                    # the NaN key is left out

    def test_odd_values(self):
        saved = missed.parse(b'UADD_DB = { missed = { mods = { a = 5, b = { dropped = inf, namesDropped = -2, '
                             b'v = 3, texts = { "x", { t = 7 }, { t = "Fine", n = nan, d = 2 } } } } } }')
        mods = missed.collect_db(saved)
        self.assertNotIn("a", mods)
        b = mods["b"]
        self.assertEqual((b["dropped"], b["namesDropped"], b["v"]), (0, 0, "3"))
        self.assertEqual(b["texts"], {"Fine": {"n": 0, "d": "2", "v": None}})
        self.assertEqual(missed.collect_db({"UADD_DB": "junk"}), {})

    def test_escapes(self):
        text = missed.parse(SAVED)["UADD_DB"]["missed"]["mods"]["fxpb"]["texts"]["10:00000005"]["t"]
        self.assertEqual(text, 'Two\nlines "quoted" и')


class Report(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = os.path.join(self.tmp.name, "WTF")
        sv = os.path.join(root, "Account", ACCOUNT, "SavedVariables")
        os.makedirs(sv)
        with open(os.path.join(sv, "UADD.lua"), "wb") as f:
            f.write(SAVED)
        self.root, self.out = root, os.path.join(self.tmp.name, "out")

    def run_main(self, saved=None):
        if saved is not None:
            with open(os.path.join(self.root, "Account", ACCOUNT, "SavedVariables", "UADD.lua"), "wb") as f:
                f.write(saved)
        buf = io.StringIO()
        old_env, old_out = os.environ.get("UADD_WTF_DIR"), missed.OUT
        os.environ["UADD_WTF_DIR"], missed.OUT = self.root, self.out
        try:
            with contextlib.redirect_stdout(buf):
                code = missed.main([])
        finally:
            missed.OUT = old_out
            if old_env is None:
                os.environ.pop("UADD_WTF_DIR")
            else:
                os.environ["UADD_WTF_DIR"] = old_env
        return code, buf.getvalue()

    def test_groups(self):
        mods = missed.collect([("account 1", os.path.join(self.root, "Account", ACCOUNT, "SavedVariables", "UADD.lua"))])
        stay = {"fxpb": {"keys": {hashtext.key("Stay as is")}, "texts": set(), "templates": [], "note": None}}
        texts, names, older, stayed = missed.sort_out("fxpb", mods["fxpb"], stay)
        self.assertEqual([t for t, _ in texts], ["Wobbly gizmo #", 'Two\nlines "quoted" и'])
        self.assertEqual([t for t, _ in names], ["Zork Plank"])
        self.assertEqual([t for t, _ in older], ["Old thingy"])
        self.assertEqual(stayed, 1)

    def test_main(self):
        old_stay = missed.stay_sets
        missed.stay_sets = lambda: {"fxpb": {"keys": set(), "texts": {"Stay as is"}, "templates": [], "note": None}}
        try:
            code, out = self.run_main()
        finally:
            missed.stay_sets = old_stay
        self.assertEqual(code, 1)                   # texts listed
        self.assertIn("account 1", out)
        self.assertNotIn(ACCOUNT, out)
        self.assertIn("fxpb: 4 missed (addon version 2.0)", out)
        self.assertIn("1 STAY not shown", out)
        self.assertIn("3 over the limit", out)
        self.assertNotIn("Stay as is", out)
        self.assertNotIn("openmap", out)            # no texts: no line
        self.assertIn("layerswap: 1 missed; 1 maybe names, 4 over the limit", out)
        with open(os.path.join(self.out, "fxpb.txt"), encoding="utf-8") as f:
            body = f.read()
        self.assertIn("    7 x  Wobbly gizmo #", body)
        self.assertIn("Two\\nlines", body)          # one line per text
        self.assertIn("# maybe names (1)", body)
        self.assertIn("# from an older version (1)", body)
        self.assertNotIn(ACCOUNT, body)

    def test_nothing(self):
        code, out = self.run_main(b"UADD_DB = { [\"missed\"] = { [\"mods\"] = {} } }")
        self.assertEqual(code, 0)
        self.assertEqual(out.splitlines(), ["Read: account 1", "nothing missed."])
        self.assertEqual(os.listdir(self.out), [])

    def test_no_file(self):
        old = os.environ.get("UADD_WTF_DIR")
        os.environ["UADD_WTF_DIR"] = os.path.join(self.tmp.name, "none")
        try:
            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                self.assertEqual(missed.main([]), 2)
        finally:
            if old is None:
                os.environ.pop("UADD_WTF_DIR")
            else:
                os.environ["UADD_WTF_DIR"] = old
        self.assertIn("No UADD.lua found", buf.getvalue())

    def test_bad_file(self):
        code, out = self.run_main(b'UADD_DB = { ["missed"] = ')
        self.assertEqual(code, 2)
        self.assertEqual(out.splitlines(), ["Read: account 1", "account 1: cannot read (ValueError)"])
        self.assertNotIn(ACCOUNT, out)
        self.assertNotIn(self.tmp.name, out)

    def test_stay_template(self):
        addons = os.path.join(self.tmp.name, "AddOns")
        os.makedirs(os.path.join(addons, "Fake"))
        with open(os.path.join(addons, "Fake", "a.lua"), "w") as f:
            f.write('print("%s wobbles at %d") print("Plain stay")')
        old_env, old_lists = os.environ.get("UADD_ADDONS_DIR"), missed.STAY_LISTS
        keys = {hashtext.key("%s wobbles at %d"), hashtext.key("Plain stay")}
        missed.STAY_LISTS = {"fake": ("Fake", lambda: keys, lambda: (), None),
                             "gone": ("Gone", lambda: keys, lambda: (), None)}
        os.environ["UADD_ADDONS_DIR"] = addons
        try:
            stay = missed.stay_sets()
        finally:
            missed.STAY_LISTS = old_lists
            if old_env is None:
                os.environ.pop("UADD_ADDONS_DIR")
            else:
                os.environ["UADD_ADDONS_DIR"] = old_env
        self.assertIsNone(stay["fake"]["note"])
        self.assertIn("Gone not installed", stay["gone"]["note"])
        mod = {"v": None, "dropped": 0, "namesDropped": 0, "names": {},
               "texts": {t: {"n": 1, "d": "x", "v": None} for t in
                         ("Bob wobbles at 5", "%s wobbles at 12", "|cffff0000Bob wobbles at 5|r", "Plain stay",
                          "Bob wobbles at home", "Wobbly gizmo")}}
        texts, _, _, stayed = missed.sort_out("fake", mod, stay)
        self.assertEqual(stayed, 4)
        self.assertEqual(sorted(t for t, _ in texts), ["Bob wobbles at home", "Wobbly gizmo"])
        texts, _, _, stayed = missed.sort_out("gone", mod, stay)
        self.assertEqual(stayed, 1)                # not installed: only the exact text, by its hash


if __name__ == "__main__":
    unittest.main()
