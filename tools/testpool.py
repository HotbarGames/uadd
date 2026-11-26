"""Runs the test files of `python3 -m unittest discover -s tools` side by side, one forked process per file, and
reports them in this process in discovery order, as if they had run one after another (docs/LESSONS4.md, lesson 41).

test__parallel.py is the first file discover finds ("__" sorts before any letter); it calls install(). From then
on each test file that discover loads becomes a FileSuite. It forks a process (at most workers() at a time) that runs
the file's tests with a Recorder (testrecord.py), and when the run reaches the file, it replays what the Recorder
saw into the real result: the same tests in the same order, the same ok / FAIL / ERROR / skip, the same tracebacks,
and what the tests printed, each piece between the same two results as before.

No result is lost: a process that dies, fails or runs past UADD_TEST_TIMEOUT gives an ERROR for each of its file's
tests, with what it printed and a repro line.

UADD_TEST_JOBS: files at a time (default: CPU count - 2, at least 2, so the PC stays usable). UADD_TEST_JOBS=1 runs
the old way: every test in this process, one after another (the reference). A run that is not discovery (a
`python3 -m unittest tools.test_x`) always runs the old way.
UADD_TEST_TIMEOUT: seconds a file's process may take (default 900).
"""
import atexit
import os
import signal
import sys
import tempfile
import time
import traceback
import unittest
from multiprocessing.connection import Pipe, wait

import testrecord

SERIAL = {"test__parallel"}        # files that run in this process, as before


def workers():
    try:
        v = int(os.environ.get("UADD_TEST_JOBS", "0"))
    except ValueError:
        v = 0
    return max(1, v) if v else max(2, (os.cpu_count() or 1) - 2)


def timeout():
    try:
        return float(os.environ.get("UADD_TEST_TIMEOUT", "900"))
    except ValueError:
        return 900.0


def repro(name):
    return f"repro: UADD_TEST_JOBS=1 python3 -m unittest -v tools.{name}"


class Job:
    def __init__(self, pid, conn, out, err):
        self.pid, self.conn, self.out, self.err = pid, conn, out, err
        self.deadline = time.time() + timeout()


def _child(suite, conn, out, err):
    msg = ("error", "")
    try:
        os.dup2(out.fileno(), 1)
        os.dup2(err.fileno(), 2)
        rec = testrecord.Recorder()
        suite.run(rec)
        msg = ("ok", rec.events)
    except BaseException:
        msg = ("error", traceback.format_exc()[-3000:])
    try:
        sys.stdout.flush()
        sys.stderr.flush()
        conn.send(msg)
    finally:
        os._exit(0)


def _status(status):
    if status is None:
        return "unknown status"
    if os.WIFSIGNALED(status):
        return f"signal {os.WTERMSIG(status)}"
    return f"exit code {os.WEXITSTATUS(status)}"


class Pool:
    def __init__(self):
        self.queue, self.running, self.done = [], {}, {}
        atexit.register(self.stop)

    def add(self, suite):
        self.queue.append(suite)
        self.pump()

    def pump(self):
        while self.queue and len(self.running) < workers():
            self._start(self.queue.pop(0))

    def _start(self, suite):
        out, err = tempfile.TemporaryFile(), tempfile.TemporaryFile()
        mine, theirs = Pipe(duplex=False)
        sys.stdout.flush()
        sys.stderr.flush()
        pid = os.fork()
        if pid == 0:
            mine.close()
            _child(suite.inner, theirs, out, err)
        theirs.close()
        self.running[suite] = Job(pid, mine, out, err)

    def _finish(self, suite, killed=False):
        job = self.running.pop(suite)
        msg = None
        if killed:
            try:
                os.kill(job.pid, signal.SIGKILL)
            except OSError:
                pass
        else:
            try:
                msg = job.conn.recv()
            except (EOFError, OSError):
                msg = None
        job.conn.close()
        try:
            status = os.waitpid(job.pid, 0)[1]
        except OSError:
            status = None
        printed = []
        for f in (job.out, job.err):
            f.seek(0)
            printed.append(f.read())
            f.close()
        if killed:
            why = f"ran past UADD_TEST_TIMEOUT ({timeout():.0f} s) and was killed"
        elif msg is None:
            why = f"ended with no result ({_status(status)})"
        elif msg[0] != "ok":
            why = "failed outside its tests:\n" + msg[1]
        else:
            why = None
        self.done[suite] = (msg[1] if why is None else None, printed, why)

    def result(self, suite):
        """(events or None, [stdout bytes, stderr bytes], why it has no events) of a file, once its process ended."""
        while suite not in self.done:
            self.pump()                       # files before this one are done: it is next in the queue
            conns = {j.conn: s for s, j in self.running.items()}
            left = min(j.deadline for j in self.running.values()) - time.time()
            for c in wait(list(conns), timeout=max(0.0, min(left, 5.0))):
                self._finish(conns[c])
            now = time.time()
            for s, j in list(self.running.items()):
                if j.deadline <= now:
                    self._finish(s, killed=True)
        self.pump()
        return self.done.pop(suite)

    def stop(self):
        for job in self.running.values():
            try:
                os.kill(job.pid, signal.SIGKILL)
                os.waitpid(job.pid, 0)
            except OSError:
                pass
        self.running.clear()


class FileSuite(unittest.TestSuite):
    """One test file's tests, run in a process of their own and replayed here (see the top of this file)."""

    __hash__ = object.__hash__         # a key of the pool's dicts, by identity (TestSuite compares by tests)

    def __init__(self, inner, name, pool):
        super().__init__([inner])
        self.inner, self.name, self.pool = inner, name, pool
        self.tests = {t.id(): t for t in testrecord.flat(inner)}
        pool.add(self)

    def run(self, result, debug=False):
        if debug:
            return self.inner.run(result, debug)
        # what a run in order does before this file's first test: end the class and the module before it
        self._tearDownPreviousClass(None, result)
        self._handleModuleTearDown(result)
        result._previousTestClass = None
        events, printed, why = self.pool.result(self)
        if why is None:
            testrecord.replay(result, self.tests, events, printed)
        else:
            tail = b"".join(printed).decode("utf-8", "replace")[-2000:]
            testrecord.dead(result, self.inner, printed, f"the test process of {self.name} {why}\n"
                            + (f"its last output:\n{tail}\n" if tail.strip() else "") + repro(self.name) + "\n")
        return result


def install():
    """From now on each test file discover loads runs in a process of its own. Returns whether it is on."""
    if workers() < 2:
        return False
    orig = unittest.TestLoader.loadTestsFromModule
    if getattr(orig, "testpool", False):
        return True
    pool = Pool()

    def load(self, module, *args, pattern=None, **kws):
        suite = orig(self, module, *args, pattern=pattern, **kws)
        if pattern is None or module.__name__ in SERIAL or not suite.countTestCases():
            return suite
        return FileSuite(suite, module.__name__, pool)

    load.testpool = True
    unittest.TestLoader.loadTestsFromModule = load
    return True
