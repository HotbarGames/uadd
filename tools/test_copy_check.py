"""Tests for tools/copy_check.py and tools/copy_scan.py (the copy guard of tools/check_repo.py), on a fake
AddOns folder.

python3 -m unittest discover -s tools
"""
import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import copy_check as C  # noqa: E402
import copy_scan as S  # noqa: E402

# made-up texts of a made-up restricted addon (folder "Auctionator" so it counts as restricted)
LOCALE = 'L["SEARCH_HELP"] = "Search for the cheapest items here"\nL["SHORT"] = "Cancel"\n' \
         'L["some long key of the addon here"] = "Key text in the table here"\n'
NUMBERS = ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve"]
CODE = ("-- a comment that is never collected anywhere\n"
        'print("The price has increased a lot today")\n'
        "local t = 'Search for the \"best\" deals in town'\n"
        'local w = "|cffff0000Warning:|r the auction ends very soon"\n'
        'local shared = "Left click to open the map window"\n'
        + "".join(f'local n{i} = "stand-in text number {w} for the test"\n' for i, w in enumerate(NUMBERS)))
BIG_FILE = "-- a whole file of the addon\n" + "x = 1\n" * 20


class Fake(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.base = os.path.join(self.tmp.name, "AddOns")
        self.root = os.path.join(self.tmp.name, "repo")
        self.put(self.base, "Auctionator/Auctionator.toc", "## Title: Auctionator\n")
        self.put(self.base, "Auctionator/Locales/enUS.lua", LOCALE)
        self.put(self.base, "Auctionator/Locales/deDE.lua", 'L["X"] = "this other language file is skipped"\n')
        self.put(self.base, "Auctionator/Source/Main.lua", CODE)
        self.put(self.base, "Auctionator/Source/Big.lua", BIG_FILE)
        self.put(self.base, "Auctionator/Libs/Lib.lua", 'x = "a bundled library text is skipped"\n')
        self.put(self.base, "Questie/Questie.toc", "## Title: Questie\n")
        self.put(self.base, "Questie/Code.lua", 'x = "Left click to open the map window"\n')
        self.paths = []
        S._memo.clear()

    def tearDown(self):
        self.tmp.cleanup()

    def put(self, top, path, text):
        full = os.path.join(top, path)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)

    def repo(self, path, text):
        self.put(self.root, path, text)
        self.paths.append(path)

    def check(self, cache=None):
        return C.check(self.root, self.paths, lambda p: p.endswith(".png"), base=self.base, cache=cache)

    def problem_for(self, path, problems):
        return [p for p in problems if p.startswith(f"{C.TAG} {path}:")]

    def test_collects_locale_and_code_texts_only(self):
        texts, _, _ = C.targets(self.base, cache=None)
        got = texts["Auctionator"]
        self.assertIn("Search for the cheapest items here", got)
        self.assertIn("The price has increased a lot today", got)
        self.assertIn('Search for the "best" deals in town', got)
        self.assertIn("the auction ends very soon", got)
        for t in ("Cancel", "some long key of the addon here", "a comment that is never collected anywhere",
                  "this other language file is skipped", "a bundled library text is skipped",
                  "Left click to open the map window"):   # short, a key, a comment, deDE, Libs, Questie has it
            self.assertNotIn(t, got)

    def test_meaningful(self):
        for t in ("The price has increased a lot today", "Search for the cheapest items here"):
            self.assertTrue(C.meaningful(t), t)
        for t in ("Gryan Stoutmantle", "Large Brilliant Shard", "Drag to move", "Speak with Shoni Today",
                  "Fonts/frizqt__.ttf", "%s - %s (%d%%) %s - %s", "AUCTIONATOR_L_SEARCH_HELP"):
            self.assertFalse(C.meaningful(t), t)

    def test_hits_over_and_under_budget(self):
        self.repo("UADD_Auctionator/ui/locale.lua",
                  'ns.UA = {\n    SEARCH_HELP = "Шукайте тут", -- Search for the cheapest items here\n}\n')
        self.repo("UADD_Auctionator/ok.lua", 'ns.UA = { SEARCH_HELP = "Шукайте найдешевші предмети тут" }\n')
        self.repo("UADD_Auctionator/esc.lua", 'x = "Search for the \\"best\\" deals in town"\n'
                                              "-- the auction ends very soon\n")
        self.repo("UADD_Questie/x.lua", '-- Left click to open the map window\n')
        few = "".join(f"-- stand-in text number {w} for the test\n" for w in NUMBERS[:C.HARNESS_BUDGET])
        many = "".join(f"-- stand-in text number {w} for the test\n" for w in NUMBERS[:C.HARNESS_BUDGET + 1])
        self.repo("tools/harness/auctionator/Few.lua", few)
        self.repo("tools/harness/auctionator/Many.lua", many)
        self.repo("LICENSE", "The price has increased a lot today\n")
        problems, notes = self.check()
        self.assertEqual(len(self.problem_for("UADD_Auctionator/ui/locale.lua", problems)), 1, problems)
        self.assertIn("1 text(s) copied from Auctionator", self.problem_for("UADD_Auctionator/ui/locale.lua",
                                                                            problems)[0])
        self.assertIn("2 text(s) copied", self.problem_for("UADD_Auctionator/esc.lua", problems)[0])
        self.assertIn(f"{C.HARNESS_BUDGET + 1} text(s) copied",
                      self.problem_for("tools/harness/auctionator/Many.lua", problems)[0])
        for ok in ("UADD_Auctionator/ok.lua", "UADD_Questie/x.lua", "tools/harness/auctionator/Few.lua", "LICENSE"):
            self.assertEqual(self.problem_for(ok, problems), [], ok)
        self.assertEqual(len(problems), 3, problems)

    def test_exact_copy_and_locale_names(self):
        self.repo("UADD_Auctionator/Big.lua", BIG_FILE)
        self.repo("UADD_Auctionator/ui/enUS.lua", "x = 1\n")
        self.repo("tools/dj_prose/en_1.lua", "x = 1\n")
        self.repo("tools/harness/auctionator/en.lua", "x = 1\n")
        problems, _ = self.check()
        self.assertIn("an exact copy of a file of Auctionator", self.problem_for("UADD_Auctionator/Big.lua",
                                                                                problems)[0])
        for p in ("UADD_Auctionator/ui/enUS.lua", "tools/dj_prose/en_1.lua"):
            self.assertIn("named like a copied English locale file", self.problem_for(p, problems)[0])
        self.assertEqual(self.problem_for("tools/harness/auctionator/en.lua", problems), [])

    def test_not_installed_is_a_note(self):
        self.repo("UADD_Attune/x.lua", "x = 1\n")
        problems, notes = self.check()
        self.assertEqual(problems, [])
        for name in ("Attune", "DialogueUI", "ForeverXPbar", "ForeverDungeonJournal"):
            self.assertTrue(any(f"{name} is not installed" in n for n in notes), notes)
        self.assertFalse(any("Auctionator is not" in n for n in notes))

    def test_cache_is_reused_until_any_read_file_changes(self):
        cache = os.path.join(self.tmp.name, "cache.json")
        C.targets(self.base, cache)
        real = S.scan_addon
        S.scan_addon = lambda *a, **k: self.fail("scanned again although nothing changed")
        try:
            S._memo.clear()
            C.targets(self.base, cache)
        finally:
            S.scan_addon = real
        self.put(self.base, "Auctionator/Source/New.lua", 'x = "a text added without touching the toc"\n')
        S._memo.clear()
        self.assertIn("a text added without touching the toc", C.targets(self.base, cache)[0]["Auctionator"])
        main = os.path.join(self.base, "Auctionator/Source/Main.lua")
        st = os.stat(main)
        with open(main, "a", encoding="utf-8") as f:   # same name, new size: a changed file is seen too
            f.write('y = "a text changed inside an old file here"\n')
        os.utime(main, ns=(st.st_atime_ns, st.st_mtime_ns))
        S._memo.clear()
        self.assertIn("a text changed inside an old file here", C.targets(self.base, cache)[0]["Auctionator"])

    def test_xml_texts_and_labels(self):
        self.put(self.base, "Auctionator/Frames.xml",
                 '<Ui>\n  <!-- an xml comment that is never collected anywhere -->\n'
                 '  <Button name="AuctionatorFakeButton" text="Press it to sell all the junk now" '
                 'parentKey="Fake Key Name">\n'
                 '    <Scripts><OnClick>print("A Lua text in an xml script here") x = L["Xml Key Label"]</OnClick>'
                 '</Scripts>\n'
                 '  </Button>\n  <FontString text="Xml Button Label"/>\n'
                 '  <Text>The element text of the frame &amp; more here</Text>\n</Ui>\n')
        texts, _, _, labels = C.targets(self.base, cache=None, with_labels=True)
        for t in ("Press it to sell all the junk now", "A Lua text in an xml script here",
                  "The element text of the frame & more here"):
            self.assertIn(t, texts["Auctionator"])
        self.assertNotIn("an xml comment that is never collected anywhere", texts["Auctionator"])
        self.assertIn("Xml Button Label", labels["Auctionator"])
        self.assertNotIn("Fake Key Name", labels["Auctionator"])   # not a text attribute
        self.assertNotIn("Xml Key Label", labels["Auctionator"])   # its own locale key

    def test_harness_total_over_all_files(self):
        lines = [f"-- stand-in sentence number {i} goes right here\n" for i in range(C.HARNESS_TOTAL + 1)]
        self.put(self.base, "Auctionator/Source/More.lua",
                 "".join(f'x{i} = "stand-in sentence number {i} goes right here"\n' for i in range(len(lines))))
        per = C.HARNESS_BUDGET
        for n in range(0, C.HARNESS_TOTAL, per):   # every file within its own budget, HARNESS_TOTAL in all
            self.repo(f"tools/harness/auctionator/Part{n}.lua", "".join(lines[n:n + per]))
        problems, _ = self.check()
        self.assertEqual(problems, [])
        self.repo("tools/harness/auctionator/Last.lua", lines[-1])
        S._memo.clear()
        problems, _ = self.check()
        self.assertEqual(len(problems), 1, problems)
        self.assertIn(f"{C.HARNESS}: {C.HARNESS_TOTAL + 1} text(s) copied from Auctionator in all its files",
                      problems[0])

    def test_labels_in_bulk(self):
        limit = C.LABEL_LIMIT["Auctionator"]
        names = [f"Blorp Option {i}" for i in range(limit + 1)]
        self.put(self.base, "Auctionator/Source/Labels.lua",
                 "".join(f'b{i} = "{t}"\n' for i, t in enumerate(names))
                 + 'L["Zorb Key Label"] = "Zorbify"\nshared = "Shared Fake Label"\n')
        self.put(self.base, "Questie/Labels.lua", 'x = "Shared Fake Label"\n')
        _, _, _, labels = C.targets(self.base, cache=None, with_labels=True)
        got = labels["Auctionator"]
        for t in names + ["Cancel", "Zorbify"]:
            self.assertIn(t, got)
        for t in ("Zorb Key Label", "Shared Fake Label", "SEARCH_HELP", "Search for the cheapest items here"):
            self.assertNotIn(t, got)   # its own key, Questie has it, code-like, a text (counted apart)
        self.assertTrue(C.label("Auction House") and C.label("Cancel") and C.label("Price:"))
        for t in ("OnClick", "LEFT", "frame", "TOPLEFT RIGHT", "Interface/Icons/x", "MY_FRAME", "%s %d", "Ok"):
            self.assertFalse(C.label(t), t)
        # as quoted strings, comments, list items and table cells: all count
        self.repo("UADD_Auctionator/many.lua", "".join(f'  "{t}",\n' for t in names[:limit - 3])
                  + f"-- {names[-4]}\n- {names[-3]}\n| {names[-2]} | x |\ny = 1 -- {names[-1]}\n")
        self.repo("UADD_Auctionator/few.lua", "".join(f'  "{t}",\n' for t in names[:limit]))
        self.repo("docs/prose.md", "".join(f"See {t} in the menu.\n" for t in names))   # inside prose: no
        self.repo("UADD_Auctionator/shared.lua", '"Shared Fake Label"\n' * 3)
        problems, _ = self.check()
        self.assertEqual(len(problems), 1, problems)
        self.assertIn(f"UADD_Auctionator/many.lua: {limit + 1} label(s) copied from Auctionator", problems[0])

    def test_untracked_files_are_checked(self):
        subprocess.run(["git", "init", "-q", self.root], check=True)
        self.repo("UADD_Auctionator/tracked.lua", "x = 1\n")
        self.put(self.root, ".gitignore", "ignored.lua\n")
        self.put(self.root, "UADD_Auctionator/new.lua", "-- The price has increased a lot today\n")
        self.put(self.root, "UADD_Auctionator/ignored.lua", "-- The price has increased a lot today\n")
        problems, _ = self.check()
        self.assertEqual(len(problems), 1, problems)
        self.assertIn("UADD_Auctionator/new.lua: 1 text(s) copied from Auctionator", problems[0])

    def test_check_repo_fails_with_the_copy_hint(self):
        subprocess.run(["git", "init", "-q", self.root], check=True)
        self.repo("UADD_Auctionator/x.lua", "-- The price has increased a lot today\n")
        subprocess.run(["git", "add", "-f", "UADD_Auctionator/x.lua"], cwd=self.root, check=True)
        env = dict(os.environ, UADD_ADDONS_DIR=self.base, UADD_COPY_CACHE="")
        out = subprocess.run([sys.executable, os.path.join(HERE, "check_repo.py")], cwd=self.root, env=env,
                             capture_output=True, text=True)
        self.assertEqual(out.returncode, 1, out.stdout + out.stderr)
        self.assertIn("UADD_Auctionator/x.lua: 1 text(s) copied from Auctionator", out.stdout)
        self.assertIn(C.HINT, out.stdout)


if __name__ == "__main__":
    unittest.main()
