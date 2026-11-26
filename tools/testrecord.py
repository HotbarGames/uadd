"""testpool.py's two ends of a test file run in a process of its own: the Recorder notes what the run reports, in
the child; replay() reports the same into the parent's real result (docs/LESSONS4.md, lesson 41)."""
import os
import sys
import unittest


def flat(suite):
    for t in suite:
        if isinstance(t, unittest.TestSuite):
            yield from flat(t)
        else:
            yield t


def _who(test):
    """A test as the parent can find it again: ("test", id), or what a subtest or a setUpClass error shows."""
    if isinstance(test, unittest.case._SubTest):
        return ("sub", test.test_case.id(), str(test), test.id(), test.shortDescription())
    if isinstance(test, unittest.TestCase):
        return ("test", test.id())
    return ("other", str(test), test.id(), test.shortDescription())


class Recorder(unittest.TestResult):
    """Notes each call the run makes on its result, with where the printed output (fd 1, fd 2) stood then."""

    def __init__(self):
        super().__init__()
        self.events = []

    def _note(self, kind, test, *more):
        sys.stdout.flush()
        sys.stderr.flush()
        at = (os.lseek(1, 0, os.SEEK_CUR), os.lseek(2, 0, os.SEEK_CUR))
        self.events.append((kind, _who(test), more, at))

    def startTest(self, test):
        self.testsRun += 1
        self._note("start", test)

    def stopTest(self, test):
        self._note("stop", test)

    def addSuccess(self, test):
        self._note("success", test)

    def addFailure(self, test, err):
        self.failures.append((test, ""))
        self._note("failure", test, self._exc_info_to_string(err, test))

    def addError(self, test, err):
        self.errors.append((test, ""))
        self._note("error", test, self._exc_info_to_string(err, test))

    def addSkip(self, test, reason):
        self._note("skip", test, reason)

    def addExpectedFailure(self, test, err):
        self._note("xfail", test, self._exc_info_to_string(err, test))

    def addUnexpectedSuccess(self, test):
        self._note("xpass", test)

    def addSubTest(self, test, subtest, err):
        if err is None:
            self._note("sub", test, _who(subtest), None, None)
        else:
            kind = "failure" if issubclass(err[0], test.failureException) else "error"
            self._note("sub", test, _who(subtest), kind, self._exc_info_to_string(err, test))

    def addDuration(self, test, elapsed):              # Python 3.12+
        self._note("duration", test, elapsed)


class _Stand:
    """Stands for a test the parent has no object of (a subtest, a setUpClass error): shows as it did."""

    def __init__(self, text, tid, short, case=None):
        self._text, self._id, self._short, self.test_case = text, tid, short, case
        self.failureException = AssertionError

    def __str__(self):
        return self._text

    def id(self):
        return self._id

    def shortDescription(self):
        return self._short


def _with_text(result, text, call, *args):
    """Calls result.addFailure / addError / ... so that it keeps `text` as the formatted error."""
    had = vars(result).get("_exc_info_to_string")
    result._exc_info_to_string = lambda err, test: text
    try:
        call(*args)
    finally:
        if had is None:
            del result._exc_info_to_string
        else:
            result._exc_info_to_string = had


def _obj(tests, who):
    if who[0] == "test":
        return tests.get(who[1]) or _Stand(who[1], who[1], None)
    if who[0] == "sub":
        case = tests.get(who[1]) or _Stand(who[1], who[1], None)
        return _Stand(who[2], who[3], who[4], case)
    return _Stand(*who[1:])


def emit(printed, was, at):
    """Prints what the child printed (stdout, stderr bytes) between positions `was` and `at`."""
    for i, stream in enumerate((sys.stdout, sys.stderr)):
        chunk = printed[i][was[i]:at[i]]
        if chunk:
            stream.flush()
            if hasattr(stream, "buffer"):
                stream.buffer.write(chunk)
                stream.buffer.flush()
            else:
                stream.write(chunk.decode("utf-8", "replace"))
            stream.flush()


def _fail(result, kind, t, text):
    exc = t.failureException if kind == "failure" else Exception
    call = {"failure": result.addFailure, "error": result.addError, "xfail": result.addExpectedFailure}[kind]
    _with_text(result, text, call, t, (exc, exc(), None))


def replay(result, tests, events, printed):
    """Reports the Recorder's `events` into `result`; `tests`: {id: test} of the file's own test objects."""
    was = (0, 0)
    for kind, who, more, at in events:
        emit(printed, was, at)
        was = at
        if kind == "start" and result.shouldStop:
            return
        t = _obj(tests, who)
        if kind == "start":
            result.startTest(t)
        elif kind == "stop":
            result.stopTest(t)
        elif kind == "success":
            result.addSuccess(t)
        elif kind == "skip":
            result.addSkip(t, more[0])
        elif kind == "xpass":
            result.addUnexpectedSuccess(t)
        elif kind == "duration":
            if hasattr(result, "addDuration"):
                result.addDuration(t, more[0])
        elif kind in ("failure", "error", "xfail"):
            _fail(result, kind, t, more[0])
        elif kind == "sub":
            sub, sk, text = more
            if sk is None:
                result.addSubTest(t, _obj(tests, sub), None)
            else:
                exc = t.failureException if sk == "failure" else Exception
                _with_text(result, text, result.addSubTest, t, _obj(tests, sub), (exc, exc(), None))
    emit(printed, was, tuple(len(p) for p in printed))


def dead(result, suite, printed, text):
    """The file's process gave no results: each of its tests is an ERROR with `text`, so none passes unseen."""
    emit(printed, (0, 0), tuple(len(p) for p in printed))
    for t in flat(suite):
        if result.shouldStop:
            return
        result.startTest(t)
        _fail(result, "error", t, text)
        result.stopTest(t)
