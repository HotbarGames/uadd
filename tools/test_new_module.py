"""tools/new_module.py: no skeleton left half-written in git, each module is in every list, and the tool itself.

- no tracked file (a staged one counts) has the mark of an unfinished skeleton (new_module_lists.MARK);
- each tracked UADD_* module is in every list of new_module_reg.PLACES, except KNOWN (each with a reason);
- the skeleton of a made-up addon compiles, keeps the size limits and leaves no placeholder; --register adds it
  everywhere and a second run changes nothing.

python3 -m unittest tools.test_new_module
"""
import contextlib
import io
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from unittest import mock

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parent
sys.path.insert(0, str(TOOLS))
import new_module as N  # noqa: E402
import new_module_lists as L  # noqa: E402
import new_module_reg as G  # noqa: E402

KEYS = "real gap, found 2026-11-25: "
KNOWN = {
    ("UADD_BugSack", "README commands"): KEYS + "README and docs/TESTING.md say /uadd bugsack, its key is bs",
    ("UADD_ForeverXPBar", "README commands"): KEYS + "no /uadd fxpb rows",
    ("UADD_LayerSwap", "README commands"): KEYS + "no /uadd layerswap rows",
    ("UADD_ForeverXPBar", "TESTING"): KEYS + "no section in the test guides",
    ("UADD_LayerSwap", "TESTING"): KEYS + "no section in the test guides",
    ("UADD_GatherMate2", "CHANGELOG"): KEYS + "never named in UADD/CHANGELOG.md",
    ("UADD_Questie", "TESTING"): "docs/TESTING.md itself starts with Questie's steps, under no heading of its own",
}


def git(*args):
    return subprocess.run(["git", "-C", str(ROOT), *args], capture_output=True, text=True, check=False)


def registered_untracked():
    """Untracked module folders that make_zip.py's FOLDERS lists: they ship, so they are checked like tracked ones."""
    zipped = G.section((TOOLS / "make_zip.py").read_text(encoding="utf-8"), "FOLDERS = [", "]")
    return [f for f in set(N.listing(ROOT, others=True)[0]) - set(N.tracked(ROOT)) if f'"{f}"' in zipped]


class Repo(unittest.TestCase):
    def test_no_unfinished_skeleton(self):
        r = git("grep", "-l", "-F", L.MARK)
        self.assertLess(r.returncode, 2, f"git grep failed ({r.returncode}): {r.stderr}")
        self.assertEqual(r.stdout.split(), [], f"tracked files with {L.MARK}: finish them before the commit")
        new = registered_untracked()
        if new:
            r = git("grep", "--untracked", "-l", "-F", L.MARK, "--", *new)
            self.assertLess(r.returncode, 2, f"git grep failed ({r.returncode}): {r.stderr}")
            self.assertEqual(r.stdout.split(), [], f"registered untracked files with {L.MARK}")

    def test_every_module_in_every_list(self):
        mods = sorted({*N.tracked(ROOT), *registered_untracked()})
        if not mods:
            self.skipTest("no git here")
        cache, got = {}, set()
        for f in mods:
            m = G.Mod(ROOT, f)
            got |= {(f, place) for place, _ in G.missing(m, cache)}
        self.assertEqual(sorted(got - set(KNOWN)), [], "run python3 tools/new_module.py --check")
        self.assertEqual(sorted(set(KNOWN) - got), [], "not missing any more: take it out of KNOWN")


class Skeleton(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.dir.cleanup)
        self.root = Path(self.dir.name) / "repo"
        addon = Path(self.dir.name) / "AddOns" / "GizmoBoard"
        addon.mkdir(parents=True)
        (addon / "GizmoBoard.toc").write_text("## Title: |cff33ff99Gizmo|r Board\n", encoding="utf-8")
        env = mock.patch.dict(os.environ, {"UADD_ADDONS_DIR": str(addon.parent)})
        env.start()
        self.addCleanup(env.stop)

    def words(self, licence="none", **kw):
        return N.words(ROOT, "GizmoBoard", "gz", licence, **kw)

    def test_title_from_the_toc(self):
        w = self.words()
        self.assertEqual((w["TITLE"], w["F"], w["key"]), ("Gizmo Board", "UADD_GizmoBoard", "gz"))
        self.assertEqual(self.words(title="Sprocket", name="Sp", key="spr")["key"], "spr")

    def test_files(self):
        try:
            from lupa import lua51 as lua
        except ImportError:
            lua = None
        for like in N.OURS:
            files = N.scaffold(ROOT, self.words(), like)
            self.assertEqual("UADD_GizmoBoard/Chat.lua" in files, like == "rts")
            self.assertTrue(any(L.MARK in t for t in files.values()))
            for rel, text in files.items():
                with self.subTest(f"{like} {rel}"):
                    self.assertEqual(re.findall(r"@\w+@|@chat", text), [])
                    self.assertEqual(G.over(ROOT, rel, text), "")
                    if rel.endswith(".py"):
                        compile(text, rel, "exec")
                    elif rel.endswith(".lua") and lua:
                        ok = lua.LuaRuntime().eval("function(s) return (loadstring(s)) ~= nil end")(text)
                        self.assertTrue(ok, "does not compile")
            toc = files["UADD_GizmoBoard/UADD_GizmoBoard.toc"]
            listed = re.findall(r"^(\S+\.lua)$", toc, re.M)
            self.assertEqual(sorted(listed), sorted(f[16:] for f in files if f.startswith("UADD_") and f.endswith(".lua")))

    def test_refusals(self):
        for kw in ({"target": "Gizmo-Board"}, {"short": "Gz"}, {"short": "x"}, {"title": 'a "b"'},
                    {"name": "a b"}, {"name": "x/y"}, {"key": "Gz"}, {"key": "g-z"}):
            args = {"target": "GizmoBoard", "short": "gz", "licence": "none", **kw}
            with self.assertRaises(SystemExit):
                N.words(ROOT, **args)
        self.assertIn("is there already", N.taken(ROOT, dict(self.words(), x="bs")))
        self.assertEqual(N.taken(ROOT, self.words()), "")

    def copy_repo(self):
        """The files --register reads, in a folder of their own."""
        rels = {p[1] for p in G.PLACES} | {"size-budget.json", "docs/TESTING.md", "docs/TESTING-ADDONS.md"}
        rels |= {p.relative_to(ROOT).as_posix() for x in ("halves_*.py", "flow*.py")
                 for p in (TOOLS / "harness").glob(x)}
        for rel in rels:
            (self.root / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy(ROOT / rel, self.root / rel)

    def state(self):
        return {p.relative_to(self.root).as_posix(): p.read_bytes() for p in self.root.rglob("*") if p.is_file()}

    def test_register_twice(self):
        for licence in ("none", "arr", "gpl", "mit"):
            with self.subTest(licence):
                shutil.rmtree(self.root, ignore_errors=True)
                self.copy_repo()
                N.write(self.root, N.scaffold(ROOT, self.words(licence)))
                G.flows.cache_clear()
                m = G.Mod(self.root, "UADD_GizmoBoard")
                self.assertEqual((m.short, m.licence, m.target, m.title), ("gz", licence, "GizmoBoard", "Gizmo Board"))
                before = self.state()
                dry = G.register(m, dry=True)
                self.assertEqual(self.state(), before, "a dry run writes nothing")
                done, left = G.register(m)
                self.assertEqual((done, left), dry)
                self.assertGreater(len(done), 20)
                self.assertEqual([x for x in left if not x[2].startswith("no room")], [])
                once = self.state()
                self.assertEqual([p for p, _ in G.missing(m)], [p for p, _, _ in left])
                self.assertEqual(G.register(m), ([], left))
                self.assertEqual(self.state(), once, "a second run changes nothing")
                for rel, raw in once.items():
                    if rel.endswith(".py"):
                        compile(raw, rel, "exec")
                    if before.get(rel, raw) != raw:
                        self.assertEqual(G.over(ROOT, rel, raw.decode("utf-8").replace("\r\n", "\n")), "", rel)
                self.assertNotIn(b"\n", once["install.bat"].replace(b"\r\n", b""))
        G.flows.cache_clear()

    def test_register_needs_short_and_licence(self):
        with self.assertRaises(SystemExit):
            G.register(G.Mod(ROOT, "UADD_BugSack"), dry=True)


    # Review fixes. Each fails on the code before them (the old copy of the tools ran the same tests: see the report).
    def test_taken_by_any_file_of_the_skeleton(self):
        for short in ("mods", "sources", "ours", "gz"):
            w = N.words(ROOT, "GizmoBoard", short, "none")
            for rel in N.scaffold(ROOT, w):
                with self.subTest(f"{short} {rel}"):
                    shutil.rmtree(self.root, ignore_errors=True)
                    (self.root / rel).parent.mkdir(parents=True)
                    (self.root / rel).write_text("x\n")
                    self.assertTrue(N.taken(self.root, w))
        shutil.rmtree(self.root, ignore_errors=True)      # --short mods: tools/harness/halves_mods.py is there already
        (self.root / "tools/harness").mkdir(parents=True)
        (self.root / "tools/harness/halves_mods.py").write_text("x = 1\n")
        (self.root / "UADD").mkdir()
        (self.root / "UADD/UADD.toc").write_text("## Interface: 1\n## Version: 1\n")
        with self.assertRaises(SystemExit):
            N.main(["GizmoBoard", "--short", "mods", "--root", str(self.root)])
        self.assertFalse((self.root / "UADD_GizmoBoard").exists())

    def test_whole_entries_only(self):
        some = SimpleNamespace(title="Road", titles=["Road", "Sack", "Bug", "Quest", "Loot", "Map"], folder="UADD_Bug",
                               short="zz", root=self.root)
        notes = "## Notes: Ukrainian for: Questie, Forever Quest Pins, BugSack, Road to Sixty, LootTriage, OpenMap.\n"
        notes_has = next(p[2] for p in G.PLACES if p[0] == "core TOC Notes")
        self.assertFalse(notes_has(notes, some))
        self.assertFalse(G.said("")("- BugSack: new module; Road to Sixty\n  Quest Log\n", some))
        self.assertTrue(notes_has(notes, SimpleNamespace(title="Road to Sixty")))
        self.assertTrue(G.said("")("- Pawn: x\n\n## Details! (Damage Meter) (MIT)\n", SimpleNamespace(
            titles=["Details! (Damage Meter)"])))
        (self.root / "tools/harness").mkdir(parents=True)
        (self.root / "tools/harness/flow_x.py").write_text('"""UADD_BugSack\'s flow"""\n')
        G.flows.cache_clear()
        self.assertFalse(G.in_runner("    import flow_x\n    run(flow_xzz)\n", some))
        self.assertTrue(G.in_runner("    import flow_x\n", SimpleNamespace(short="a", folder="UADD_BugSack", root=self.root)))
        G.flows.cache_clear()

    def test_bat_block_is_escaped(self):
        self.assertEqual(L.cmd_safe("Details! (Damage Meter) & Co | <x> ^ 5%"),
                         "Details! ^(Damage Meter^) ^& Co ^| ^<x^> ^^ 5%%")
        block = G.bat_block(SimpleNamespace(target="Details", folder="UADD_Details", title="Details! (Damage Meter)"))
        self.assertIn("the Details! ^(Damage Meter^) module stays off", block)

    def test_one_broken_text_writes_nothing(self):
        self.copy_repo()
        N.write(self.root, N.scaffold(ROOT, self.words("none")))
        G.flows.cache_clear()
        m = G.Mod(self.root, "UADD_GizmoBoard")
        bad = ("bad", "tools/harness/chaos_mods2.py", lambda t, m: "def (:" in t, lambda t, m: t + "\ndef (:\n", lambda m: True)
        with mock.patch.object(G, "PLACES", [G.PLACES[0], G.PLACES[1], bad]):
            before = self.state()
            done, left = G.register(m)
        self.assertEqual((done, self.state()), ([], before))
        self.assertTrue(any(p == "bad" and "does not compile" in why for p, _, why in left), left)
        G.flows.cache_clear()

    def test_put_entry_keeps_code_valid(self):
        for src in ('X = [\n    "a",\n]\n', 'X = [\n    "a"\n]\n', 'X = ["a",]\n', 'X = ["a"]\n'):
            with self.subTest(src):
                new = L.put_entry(src, "X = [", "]", '"b"', 4)
                ns = {}
                exec(compile(new, "x", "exec"), ns)
                self.assertEqual(ns["X"], ["a", "b"])

    def test_check_without_modules(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.assertNotEqual(N.main(["--check", "--root", str(self.root)]), 0)
        self.assertIn("no modules", out.getvalue())
        if shutil.which("git"):
            (self.root / "UADD_Foo").mkdir(parents=True)
            (self.root / "UADD_Foo/UADD_Foo.toc").write_text("## Title: x\n")
            subprocess.run(["git", "-C", str(self.root), "init", "-q"], check=True)
            self.assertEqual((N.listing(self.root)[0], N.listing(self.root, others=True)[0]), ([], ["UADD_Foo"]))


class Lists(unittest.TestCase):
    def test_edits(self):
        self.assertEqual(L.join_last("put A, B and C here", "here", "D"), "put A, B, C and D here")
        with self.assertRaises(L.Gap):
            L.join_last("put A here", "here", "D")
        self.assertEqual(L.put_entry('X = ["a",\n     "b"]', "X = [", "]", '"c"', 5), 'X = ["a",\n     "b", "c"]')
        self.assertEqual(L.after_line("a 1\na 2\nb", r"^a \d$", "a 3"), "a 1\na 2\na 3\nb")
        self.assertEqual(L.wrap("x" * 10 + ", yy", "  ", 12), "x" * 10 + ",\n  yy")


if __name__ == "__main__":
    unittest.main()
