"""Runs our real addon files with the real Questie, QuestieDB and UALLF in the offline harness
(tools/harness), then the Dungeon Journal module with the real ForeverDungeonJournal (tools/harness/run.py).
Skips when lupa or the Forever AddOns folder is missing.

The harness starts when this file is imported: `unittest discover` imports every test file before it runs one,
so the harness runs in a process of its own while the other files' tests run, and setUpClass takes its result
(the same checks, in the same order). UADD_HARNESS_EARLY=0 runs it in setUpClass, in this process, as before.

python3 -m unittest discover -s tools
"""
import atexit
import collections
import json
import os
import pickle
import signal
import sys
import traceback
import unittest
from multiprocessing.connection import Pipe

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "harness"))

import loader  # noqa: E402
import session  # noqa: E402

WHY_NOT = None
if loader.lua_runtime() is None:
    WHY_NOT = "lupa is not installed (pip install lupa)"
elif session.missing_addons():
    WHY_NOT = "addons not found in " + session.addons_dir() + ": " + ", ".join(session.missing_addons())

Check = collections.namedtuple("Check", "name ok detail")
_EARLY = {}            # "conn", "pid": the harness process started at import


def _plain(checks, facts):
    """What the harness gave, in a form that pickles: (name, ok, detail) tuples, facts as JSON allows."""
    out = []
    for c in checks:
        try:
            pickle.dumps(c[2])
            out.append((c[0], bool(c[1]), c[2]))
        except Exception:
            out.append((c[0], bool(c[1]), str(c[2])))
    try:
        pickle.dumps(facts)
    except Exception:
        facts = json.loads(json.dumps(facts, default=str))
    return out, facts


def _start():
    """Forks the harness. It stays in this process group, so the push's `timeout` and Ctrl-C reach it and its
    jobs; if this process ends first, atexit kills it, and each job it forked ends when it finds no one to send
    its result to."""
    mine, theirs = Pipe(duplex=False)
    pid = os.fork()
    if pid == 0:
        try:
            mine.close()
            import run
            checks, facts, _ = run.run_all()
            msg = ("ok",) + _plain(checks, facts)
        except BaseException:
            msg = ("error", traceback.format_exc()[-3000:])
        try:
            theirs.send(msg)
        finally:
            os._exit(0)
    theirs.close()
    _EARLY.update(conn=mine, pid=pid)
    atexit.register(_stop)


def _stop():
    pid = _EARLY.pop("pid", None)
    if pid is None:
        return
    try:
        os.kill(pid, signal.SIGKILL)
    except OSError:
        pass
    try:
        os.waitpid(pid, 0)
    except OSError:
        pass


def _result():
    """The early harness's (checks, facts). Its own jobs time out (UADD_JOB_TIMEOUT); the push's `timeout`
    bounds the whole run."""
    conn = _EARLY.pop("conn")
    try:
        msg = conn.recv()
    except EOFError:
        msg = ("error", "the harness process ended with no result (killed?); "
                        "repro: UADD_HARNESS_EARLY=0 python3 -m unittest tools.test_harness -v")
    finally:
        conn.close()
        pid = _EARLY.pop("pid", None)
        if pid is not None:
            try:
                os.waitpid(pid, 0)
            except ChildProcessError:      # this file runs in a process of its own (testpool.py): the parent reaps it
                pass
    if msg[0] != "ok":
        raise RuntimeError("the harness failed to run:\n" + msg[1])
    return [Check(*c) for c in msg[1]], msg[2]


if not WHY_NOT and os.environ.get("UADD_HARNESS_EARLY", "1") != "0":
    _start()


@unittest.skipIf(WHY_NOT, WHY_NOT or "")
class Flow(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if "conn" in _EARLY:
            cls.checks, cls.facts = _result()
            return
        import run
        cls.checks, cls.facts, _ = run.run_all()      # the main flow, then the Dungeon Journal module

    def test_every_check_passes(self):
        for c in self.checks:
            with self.subTest(c.name):
                self.assertTrue(c.ok, c.detail)

    def test_collection_finds_most_names(self):
        facts = self.facts
        for kind, total in facts["totals"].items():
            self.assertGreater(facts["counts"][kind], total // 2, kind)


if __name__ == "__main__":
    unittest.main()
