"""Runs the other test files side by side (tools/testpool.py) and tests that it changes nothing they report.

discover finds this file first ("__" sorts before any letter), so install() runs before any other test file is
loaded. UADD_TEST_JOBS=1 runs every file the old way, one after another in one process (the reference).

python3 -m unittest tools.test__parallel
"""
import contextlib
import io
import os
import re
import sys
import unittest
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import testpool  # noqa: E402

testpool.install()


def _cases():
    """A made-up test file with every kind of result: ok, FAIL, ERROR, skip, subtests, expected failures, a
    setUpClass that fails, and printed output between them."""

    class A(unittest.TestCase):
        def test_1_ok(self):
            print("out of test 1")

        def test_2_fail(self):
            """A doc line."""
            print("err of test 2", file=sys.stderr)
            self.assertEqual(1, 2, "one is not two")

        def test_3_error(self):
            raise KeyError("boom")

        @unittest.skip("not today")
        def test_4_skip(self):
            pass

        def test_5_subtests(self):
            for i in range(4):
                with self.subTest(i=i):
                    if i == 1:
                        self.fail("sub one")
                    if i == 2:
                        raise ValueError("sub two")
                    if i == 3:
                        self.skipTest("sub three")

        @unittest.expectedFailure
        def test_6_xfail(self):
            self.fail("wanted")

        @unittest.expectedFailure
        def test_7_xpass(self):
            pass

    class B(unittest.TestCase):
        @classmethod
        def setUpClass(cls):
            raise RuntimeError("no class today")

        def test_never(self):
            pass

    class C(unittest.TestCase):
        @classmethod
        def setUpClass(cls):
            raise unittest.SkipTest("class skipped")

        def test_skipped(self):
            pass

    for c in (A, B, C):
        c.__module__ = "fakefile"
    return [A, B, C]


def _suite(classes):
    loader = unittest.TestLoader()
    return unittest.TestSuite(loader.loadTestsFromTestCase(c) for c in classes)


def _run(suite):
    """(what the runner wrote, what the tests printed, the result) of a -v run, its time taken out."""
    stream, out = io.StringIO(), io.StringIO()
    with contextlib.redirect_stdout(out):
        r = unittest.TextTestRunner(stream=stream, verbosity=2).run(suite)
    text = re.sub(r"Ran (\d+) tests? in [\d.]+s", r"Ran \1 tests", stream.getvalue())
    return text, out.getvalue(), r


def _sums(r):
    return (r.testsRun, [(str(t), e) for t, e in r.failures], [(str(t), e) for t, e in r.errors],
            [(str(t), why) for t, why in r.skipped], len(r.expectedFailures), len(r.unexpectedSuccesses))


class Sameness(unittest.TestCase):
    def test_same_report_as_in_order(self):
        serial = _run(_suite(_cases()))
        pool = testpool.Pool()
        try:
            side = _run(unittest.TestSuite([testpool.FileSuite(_suite(_cases()), "fakefile", pool)]))
        finally:
            pool.stop()
        self.assertEqual(serial[0], side[0])          # the -v lines, FAIL/ERROR blocks and the summary
        self.assertEqual(serial[1], side[1])          # printed output (stderr goes to the real fd 2)
        self.assertEqual(_sums(serial[2]), _sums(side[2]))
        self.assertIn("one is not two", side[0])
        self.assertRegex(side[0], r"ERROR: setUpClass \(fakefile\.\S*B\)")
        self.assertIn("ERROR: test_5_subtests", side[0])

    def test_many_files_keep_their_order(self):
        def make(n):
            class T(unittest.TestCase):
                def test_x(self):
                    self.assertTrue(n % 3, f"file {n}")
            T.__module__ = f"file{n}"
            T.__qualname__ = f"T{n}"
            return T
        serial = _run(unittest.TestSuite(_suite([make(n)]) for n in range(7)))
        with mock.patch.dict(os.environ, {"UADD_TEST_JOBS": "2"}):
            pool = testpool.Pool()
            try:
                side = _run(unittest.TestSuite(testpool.FileSuite(_suite([make(n)]), f"file{n}", pool)
                                               for n in range(7)))
            finally:
                pool.stop()
        self.assertEqual(serial[0], side[0])
        self.assertEqual(_sums(serial[2]), _sums(side[2]))

    def test_a_dead_process_is_an_error_with_a_repro(self):
        class D(unittest.TestCase):
            def test_a(self):
                print("before the end")
                sys.stdout.flush()
                os._exit(3)

            def test_b(self):
                pass
        D.__module__ = "deadfile"
        pool = testpool.Pool()
        try:
            text, _, r = _run(unittest.TestSuite([testpool.FileSuite(_suite([D]), "deadfile", pool)]))
        finally:
            pool.stop()
        self.assertEqual((r.testsRun, len(r.errors)), (2, 2))
        self.assertIn("exit code 3", r.errors[0][1])
        self.assertIn("before the end", r.errors[0][1])
        self.assertIn(testpool.repro("deadfile"), r.errors[1][1])

    def test_a_process_past_its_time_is_killed(self):
        class S(unittest.TestCase):
            def test_slow(self):
                import time
                time.sleep(60)
        S.__module__ = "slowfile"
        with mock.patch.dict(os.environ, {"UADD_TEST_TIMEOUT": "1"}):
            pool = testpool.Pool()
            try:
                _, _, r = _run(unittest.TestSuite([testpool.FileSuite(_suite([S]), "slowfile", pool)]))
            finally:
                pool.stop()
        self.assertEqual((r.testsRun, len(r.errors)), (1, 1))
        self.assertIn("ran past UADD_TEST_TIMEOUT", r.errors[0][1])
        self.assertIn(testpool.repro("slowfile"), r.errors[0][1])

    def test_workers_leave_two_cpus(self):
        with mock.patch.dict(os.environ, {"UADD_TEST_JOBS": ""}), mock.patch("os.cpu_count", return_value=8):
            self.assertEqual(testpool.workers(), 6)
        with mock.patch.dict(os.environ, {"UADD_TEST_JOBS": ""}), mock.patch("os.cpu_count", return_value=2):
            self.assertEqual(testpool.workers(), 2)
        with mock.patch.dict(os.environ, {"UADD_TEST_JOBS": "1"}):
            self.assertEqual(testpool.workers(), 1)


if __name__ == "__main__":
    unittest.main()
