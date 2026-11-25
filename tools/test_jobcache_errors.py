"""A cache error never aborts a harness run (tools/harness/jobcache.py, jobs.py): the checks come back, a note says why.

python3 -m unittest tools.test_jobcache_errors
"""
import os
import sys
import tempfile
import unittest
from unittest import mock

HARNESS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "harness")
sys.path.insert(0, HARNESS)
import jobcache  # noqa: E402
import jobgraph  # noqa: E402


class _Cache:
    """A cache that fails where `bad` says."""
    reused = ()

    def __init__(self, bad):
        self.bad = bad
        if bad == "make":
            raise ValueError("embedded null byte")

    def restore(self, p, jids):
        if self.bad == "restore":
            raise SyntaxError("scratch .py")

    def store(self, p, groups):
        if self.bad == "store":
            raise OSError("disk gone")

    def notes(self, ran):
        return []


class CacheErrorTest(unittest.TestCase):
    def run_with(self, bad):
        import collections
        Check = collections.namedtuple("Check", "name ok detail")
        flow = mock.Mock(Check=Check, run=lambda spawn=None: mock.Mock(checks=[Check("m", True, "")], facts={}))
        dj = mock.Mock(missing_addons=lambda: ["none"])
        import jobs
        with mock.patch.dict(sys.modules, {"flow": flow, "flow_dj_module": dj, "session": mock.Mock(addons=lambda: [])}), \
                mock.patch.dict(os.environ, {"UADD_JOBS": "1"}):
            checks, _, notes, _ = jobs.run_all([], lambda: _Cache(bad))
        self.assertEqual([c.name for c in checks if c.name == "m"], ["m"])
        return notes

    def test_make_restore_and_store_that_raise(self):
        for bad in ("make", "restore", "store"):
            with self.subTest(bad):
                self.assertTrue(any("cache failed" in n for n in self.run_with(bad)))
        self.assertFalse(any("cache failed" in n for n in self.run_with("")))

    def test_a_path_that_cannot_be_read_is_never_the_same(self):
        for bad in ("a\0b", "a\udc80b"):
            for kind in ("files", "dirs", "stats"):
                self.assertTrue(jobcache.look((kind, bad)).startswith("none"), (kind, bad))
            self.assertFalse(jobcache.settled(("files", bad), 1e12))

    def test_an_old_tmp_goes_and_a_new_one_stays(self):
        with tempfile.TemporaryDirectory() as d:
            c = jobcache.Cache(0, None, d, False, jobgraph.Graph())
            old, new = (os.path.join(d, n) for n in ("x.1.tmp", "y.2.tmp"))
            for path in (old, new):
                with open(path, "w") as f:
                    f.write("half")
            os.utime(old, (1, 1))
            c.store(mock.Mock(jobs={}), [])
            self.assertEqual(os.listdir(d), ["y.2.tmp"])


if __name__ == "__main__":
    unittest.main()
