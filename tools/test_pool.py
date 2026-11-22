"""Tests for tools/harness/pool.py, which runs run.py's flows side by side (docs/LESSONS4.md lesson 41).

No result is lost or made up: the checks come back in the order of a run with no pool, and a job that raises,
dies or runs past UADD_JOB_TIMEOUT gives a FAIL check with why and a repro line, while the other jobs' checks stay.

python3 -m unittest tools.test_pool
"""
import collections
import os
import sys
import time
import unittest
from unittest import mock

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "harness"))
import pool  # noqa: E402

Check = collections.namedtuple("Check", "name ok detail")


def kid():
    return [("kid 1", True, ""), ("kid 2", False, "why")], {"kid": 1}


def parent():
    return [("first", True, ""), pool.spawn(kid), ("last", True, "")], {"parent": 1}


def raises():
    raise ValueError("made-up failure")


def dies():
    os._exit(5)


def sleeps():
    time.sleep(60)
    return [], {}


def ok_job(name):
    return [(name, True, "")], {}


def run(jobs, n="2", limit="900"):
    with mock.patch.dict(os.environ, {"UADD_JOBS": n, "UADD_JOB_TIMEOUT": limit}):
        p = pool.Pool(Check)
        ids = [p.add(fn, *args) for fn, args in jobs]
        p.run()
    return [p.expand(j) for j in ids]


@unittest.skipUnless(hasattr(os, "fork"), "pool.py forks")
class PoolTest(unittest.TestCase):
    def test_spawned_checks_keep_their_place(self):
        for n in ("1", "3"):
            with self.subTest(jobs=n):
                got = run([(parent, ()), (ok_job, ("other",))], n)
                self.assertEqual([c.name for c in got[0]], ["first", "kid 1", "kid 2", "last"])
                self.assertEqual([c.ok for c in got[0]], [True, True, False, True])
                self.assertEqual([c.name for c in got[1]], ["other"])

    def test_a_failing_job_is_a_fail_with_a_repro(self):
        for n in ("1", "3"):
            with self.subTest(jobs=n):
                got = run([(ok_job, ("before",)), (raises, ()), (ok_job, ("after",))], n)
                self.assertEqual([c.name for c in got[0] + got[2]], ["before", "after"])
                (fail,) = got[1]
                self.assertFalse(fail.ok)
                self.assertIn("test_pool.raises", fail.name)
                self.assertIn("made-up failure", fail.detail)
                self.assertIn("repro: UADD_JOBS=1", fail.detail)

    def test_a_job_that_dies_is_a_fail(self):
        got = run([(dies, ()), (ok_job, ("still here",))], "2")
        self.assertFalse(got[0][0].ok)
        self.assertIn("exit code 5", got[0][0].detail)
        self.assertEqual([c.name for c in got[1]], ["still here"])

    def test_a_job_past_its_time_is_killed(self):
        t0 = time.time()
        got = run([(sleeps, ()), (ok_job, ("still here",))], "2", limit="1")
        self.assertLess(time.time() - t0, 15)
        self.assertFalse(got[0][0].ok)
        self.assertIn("over UADD_JOB_TIMEOUT", got[0][0].detail)
        self.assertEqual([c.name for c in got[1]], ["still here"])


if __name__ == "__main__":
    unittest.main()
