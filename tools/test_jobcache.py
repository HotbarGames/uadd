"""Tests for tools/harness/jobcache.py: a job's kept result is reused only while every input of it is the same
(docs/LESSONS4.md, lesson 41 again). Each test changes one KIND of input in a small made-up world and names the jobs
that must run again; each run is a process of its own, as run.py's are.

python3 -m unittest tools.test_jobcache
"""
import json
import os
import re
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

TOOLS = os.path.dirname(os.path.abspath(__file__))
HARNESS = os.path.join(TOOLS, "harness")
REPO = os.path.dirname(TOOLS)
sys.path.insert(0, HARNESS)
import jobcache  # noqa: E402
import jobgraph  # noqa: E402

DRIVER = r"""
import collections, json, os, sys, time
harness, world, late, fresh = sys.argv[1], sys.argv[2], float(sys.argv[3]), sys.argv[4] == "fresh"
time.sleep(0.1)                     # the files the test just wrote are older than the run
START = time.time() - late
sys.path[:0] = [os.path.join(world, "mods"), harness]
os.chdir(world)
import jobinputs, loader
base = jobinputs.Inputs()
jobinputs.install()
jobinputs.to(base)
import flow_a, flow_b, flow_kid, flow_prog, flow_late, patch_b
import jobcache, jobgraph, pool
loader.fresh()
Check = collections.namedtuple("Check", "name ok detail")
p = pool.Pool(Check, watch=True)
ids = {m.__name__: p.add(m.run_checks) for m in (flow_a, flow_b, flow_kid, flow_prog, flow_late)}
cache = jobcache.Cache(START, base, os.path.join(world, "cache"), fresh, jobgraph.Graph((os.path.join(world, "mods"),)))
cache.restore(p, list(ids.values()))
if p.queue:
    p.run()
got = {k: p.expand(j) for k, j in ids.items()}
cache.store(p, [([j], all(c.ok for c in got[k])) for k, j in ids.items()])
print(json.dumps({"ran": sorted(k for k, j in ids.items() if j not in cache.reused), "why": cache.why, "checks": got,
                  "kept": len(os.listdir("cache")) if os.path.isdir("cache") else 0, "notes": cache.notes(0)}))
"""
READ = """import glob, os, loader, session_like
import steps_a
def run_checks():
    import late_a
    texts = [loader.read_text(p) for p in ["UADD/Core.lua", "UADD_A/A.lua", "stand/a.lua"] + sorted(glob.glob("UADD_A/data/*.lua"))]
    x = os.path.join(os.environ["UADD_ADDONS_DIR"], "A", "x.lua")
    texts.append(loader.read_text(x))
    opt = loader.is_file("UADD_A/opt.lua")
    return [("a", "BAD" not in "".join(texts) and steps_a.OK and late_a.OK, f"{opt} {os.environ.get('UADD_ODD')}")], {}
"""
FILES = {
    "mods/flow_a.py": READ, "mods/steps_a.py": "import rules\nOK = rules.OK\n", "mods/rules.py": "OK = True\n",
    "mods/late_a.py": "OK = True\n", "mods/session_like.py": "X = 1\n",
    "mods/flow_b.py": "import loader\nSTEPS = {}\ndef run_checks():\n    t = loader.read_text('UADD/Core.lua') + "
                      "loader.read_text('UADD_B/B.lua')\n    return [('b', 'BAD' not in t, '')], {}\n",
    "mods/patch_b.py": "import flow_b\nflow_b.STEPS.update(x=1)\n",
    "mods/flow_kid.py": "import loader, pool\ndef kid():\n    t = loader.read_text('UADD_B/kid.lua')\n"
                        "    return [('kid', 'BAD' not in t, '')], {}\n"
                        "def run_checks():\n    return [('first', True, ''), pool.spawn(kid), ('last', True, '')], {}\n",
    "mods/flow_prog.py": "import subprocess, sys\ndef run_checks():\n    subprocess.run(['true'])\n"
                         "    return [('prog', True, '')], {}\n",
    "mods/flow_late.py": "import clock\ndef run_checks():\n    b = clock.Limit(20.0)\n    b.base = 5.0\n"
                         "    return [('late', 7.0 <= b, '')], {}\n",
    "UADD/Core.lua": "core\n", "UADD_A/A.lua": "a\n", "UADD_A/data/one.lua": "one\n", "UADD_A/data/two.lua": "two\n",
    "stand/a.lua": "stand\n", "UADD_B/B.lua": "b\n", "UADD_B/kid.lua": "kid\n", "addons/A/x.lua": "x\n",
}
ALWAYS = ["flow_late", "flow_prog"]          # never kept: a doubtful time, a program run


@unittest.skipUnless(hasattr(os, "fork"), "pool.py forks")
class JobCacheTest(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.dir = tmp.name
        for rel, text in FILES.items():
            self.write(rel, text)

    def write(self, rel, text):
        path = os.path.join(self.dir, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            f.write(text)

    def go(self, late=0.0, fresh=False, **env):
        e = {k: v for k, v in os.environ.items() if not k.startswith("UADD_") and k != "CI"}
        e.update({"UADD_ADDONS_DIR": os.path.join(self.dir, "addons"), "UADD_JOBS": "4", "PYTHONDONTWRITEBYTECODE": "1"}, **env)
        r = subprocess.run([sys.executable, "-c", DRIVER, HARNESS, self.dir, str(late), "fresh" if fresh else ""],
                           capture_output=True, text=True, env=e, timeout=60)
        self.assertEqual(r.returncode, 0, r.stderr[-2000:])
        return json.loads(r.stdout)

    def changed(self, want, do, **env):
        """After a first run, `do()` makes just the jobs in `want` (and the never kept) run again."""
        first = self.go()
        self.assertEqual(len(first["ran"]), 5)
        again = self.go()
        self.assertEqual(again["ran"], ALWAYS, again["why"])
        self.assertEqual(again["checks"], first["checks"])
        do()
        got = self.go(**env)
        self.assertEqual(got["ran"], sorted(set(want) | set(ALWAYS)))
        return got

    def test_module_lua(self):
        self.changed(["flow_a"], lambda: self.write("UADD_A/A.lua", "A\n"))

    def test_core_lua(self):
        self.changed(["flow_a", "flow_b"], lambda: self.write("UADD/Core.lua", "Core\n"))

    def test_data_lua(self):
        self.changed(["flow_a"], lambda: self.write("UADD_A/data/two.lua", "2\n"))

    def test_stand_in(self):
        self.changed(["flow_a"], lambda: self.write("stand/a.lua", "Stand\n"))

    def test_installed_addon(self):
        self.changed(["flow_a"], lambda: self.write("addons/A/x.lua", "X\n"))

    def test_new_file_in_a_listed_folder(self):
        self.changed(["flow_a"], lambda: self.write("UADD_A/data/three.lua", "three\n"))

    def test_removed_file(self):
        self.changed(["flow_a"], lambda: os.remove(os.path.join(self.dir, "UADD_A/data/one.lua")))

    def test_a_file_looked_for_comes_up(self):
        got = self.changed(["flow_a"], lambda: self.write("UADD_A/opt.lua", "opt\n"))
        self.assertTrue(got["checks"]["flow_a"][0][2].startswith("True"))

    def test_flow_py(self):
        self.changed(["flow_a"], lambda: self.write("mods/flow_a.py", READ + "# more\n"))

    def test_shared_py_two_imports_away(self):
        self.changed(["flow_a"], lambda: self.write("mods/rules.py", "OK = 1\n"))

    def test_py_imported_in_a_function(self):
        self.changed(["flow_a"], lambda: self.write("mods/late_a.py", "OK = 1\n"))

    def test_py_that_changes_another_as_it_loads(self):
        self.changed(["flow_b"], lambda: self.write("mods/patch_b.py", "import flow_b\nflow_b.STEPS.update(x=2)\n"))

    def test_spawned_job(self):
        got = self.changed(["flow_kid"], lambda: self.write("UADD_B/kid.lua", "Kid\n"))
        self.assertEqual([c[0] for c in got["checks"]["flow_kid"]], ["first", "kid", "last"])

    def test_environment(self):
        got = self.changed(["flow_a", "flow_b", "flow_kid"], lambda: None, UADD_ODD="1")
        self.assertEqual(got["checks"]["flow_a"][0][2], "False 1")

    def test_a_fail_is_not_kept_and_comes_back(self):
        got = self.changed(["flow_a", "flow_b"], lambda: self.write("UADD/Core.lua", "BAD\n"))
        for _ in range(2):
            self.assertEqual(got["ran"], sorted(["flow_a", "flow_b"] + ALWAYS))
            self.assertEqual([got["checks"][k][0][1] for k in ("flow_a", "flow_b", "flow_kid")], [False, False, True])
            self.assertIn("check", got["why"]["flow_a.run_checks()"])
            got = self.go()

    def test_spawned_fail_is_not_kept(self):
        self.write("UADD_B/kid.lua", "BAD\n")
        for _ in range(2):
            got = self.go()
            self.assertIn("flow_kid", got["ran"])
            self.assertEqual([c[1] for c in got["checks"]["flow_kid"]], [True, False, True])

    def test_why_not_kept_is_said(self):
        why = self.go()["why"]
        self.assertIn("subprocess", why["flow_prog.run_checks()"])
        self.assertIn("stretch", why["flow_late.run_checks()"])
        self.assertEqual(len(why), 2)

    def test_an_input_changed_during_the_run_is_not_kept(self):
        got = self.go(late=3600)               # as if the run had begun before the files were written
        self.assertEqual(got["kept"], 0)
        self.assertIn("changed during the run", got["why"]["flow_b.run_checks()"])

    def test_fresh_runs_all_and_keeps(self):
        self.go()
        self.assertEqual(len(self.go(fresh=True)["ran"]), 5)
        self.assertEqual(self.go()["ran"], ALWAYS)

    def test_broken_and_old_entries(self):
        self.go()
        folder = os.path.join(self.dir, "cache")
        names = sorted(os.listdir(folder))
        self.assertEqual(len(names), 3)
        for n, data in zip(names, (b"", b"junk\nmore", None)):
            with open(os.path.join(folder, n), "rb") as f:
                old = f.read()
            with open(os.path.join(folder, n), "wb") as f:
                f.write(old[:len(old) // 2] if data is None else data)
        self.write("cache/0123.bin", "of a job that is no more")
        got = self.go()
        self.assertEqual(len(got["ran"]), 5)
        self.assertEqual(sorted(os.listdir(folder)), names)            # one file per job, the old one dropped
        self.assertEqual(self.go()["ran"], ALWAYS)

    def test_a_failed_write_leaves_no_tmp(self):
        self.go()
        folder = os.path.join(self.dir, "cache")
        name = next(n for n in sorted(os.listdir(folder)) if n.endswith(".bin"))
        os.remove(os.path.join(folder, name))
        os.mkdir(os.path.join(folder, name))                          # os.replace onto a folder fails
        got = self.go()
        self.assertTrue(any("not written" in w for w in got["why"].values()), got["why"])
        self.assertEqual([n for n in os.listdir(folder) if n.endswith(".tmp")], [])


class OffTest(unittest.TestCase):
    def test_when_it_is_off(self):
        with mock.patch.object(jobcache.pool, "workers", lambda: 8):
            self.assertEqual(jobcache.off({"CI": "1"}), "CI is set")
            self.assertEqual(jobcache.off({"UADD_CACHE": "0"}), "UADD_CACHE=0")
            self.assertEqual(jobcache.off({}), "a test run")
        with mock.patch.object(jobcache.pool, "workers", lambda: 1):
            self.assertEqual(jobcache.off({}), "one job at a time")

    def test_run_all_of_the_suite_gets_no_cache(self):
        import run
        with mock.patch.dict(os.environ, {"CI": "1"}):
            self.assertEqual(run.kept_results([]), (None, "CI is set"))
        self.assertIsNone(run.kept_results([])[0])
        self.assertEqual(run.run_all.__defaults__, (None,))            # test_harness.py calls run_all()


class UnseenTest(unittest.TestCase):
    """What jobinputs.py can not see is not there."""

    def test_our_lua_opens_no_file(self):
        bad = re.compile(r"\b(io\s*\.\s*\w+|loadfile|dofile|require|os\s*\.\s*(?:execute|remove|rename|tmpname))\s*\(")
        found = []
        for top in [HARNESS] + [os.path.join(REPO, d) for d in os.listdir(REPO) if d.startswith("UADD")]:
            for folder, _, files in os.walk(top):
                for f in files:
                    if f.endswith(".lua"):
                        with open(os.path.join(folder, f), encoding="utf-8", errors="replace") as fh:
                            found += [f"{f}:{n}" for n, line in enumerate(fh, 1) if bad.search(line.split("--")[0])]
        self.assertEqual(found, [], "Lua that reads a file itself: jobcache.py would not see that input")

    def test_the_harness_reads_no_dir_entry_data(self):
        """DirEntry.stat/is_file data comes from the listing, not from jobinputs.py's audit of os.stat/open."""
        found = []
        for f in os.listdir(HARNESS):
            if f.endswith(".py") and f not in ("jobinputs.py", "jobcache.py"):      # jobcache.look is the reader itself
                with open(os.path.join(HARNESS, f), encoding="utf-8") as fh:
                    found += [f"{f}:{n}" for n, line in enumerate(fh, 1) if "scandir(" in line.split("#")[0]]
        self.assertEqual(found, [], "os.scandir in the harness: jobinputs.py would not see the stats it hands out")

    def test_a_python_file_run_by_its_path_counts(self):
        self.assertIn("fxpb_words", jobgraph.Graph().uses("lsw_words"))

    def test_steps_added_as_a_module_loads_count(self):
        g = jobgraph.Graph()
        for m in ("flow_litemount_globals", "flow_fqp_errors"):
            g.uses(m)
        self.assertTrue(any("flow_fqp_errors" in mods for mods in g.back.values()))


if __name__ == "__main__":
    unittest.main()
