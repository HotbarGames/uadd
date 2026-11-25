"""Runs harness jobs side by side, one forked process per job (jobs.py says which jobs).

A job is a module-level function that returns (checks, facts). It runs in a child forked from this process, so
it starts with what the parent already read (loader's file memo) and leaves nothing behind for the next job: its
Lua states, hooks, the tooltip font counts and the box hits (tipfont.STATE, boxes.STATE) die with it. A job may start more jobs with
spawn(fn, *args): it gets a place-holder check at once, which `expand` later swaps for that job's checks, so the
check list keeps the order of a run with no pool.

No result is lost or made up: a job that raises, dies or runs past its time gives a FAIL check with what is
known (the error, the exit code or signal) and a repro line.

UADD_JOBS: how many jobs at a time (default: the CPU count; 1 runs every job here, in this process, in order).
UADD_JOB_TIMEOUT: seconds a job may take (default 900).
"""
import collections
import gc
import json
import os
import pickle
import signal
import time
import traceback
from multiprocessing.connection import Pipe, wait

import boxes
import clock
import jobinputs
import tipfont

MARK = "\x00job:"           # the name of a place-holder check: MARK + job id
MIN_FREE_MB = 2500           # do not start another job while less memory than this is free (one job: 0.5-3 GB)
# tip: {"tip": the tooltip font counts (tipfont.take), "box": the symptom check's hits (boxes.take)}
Result = collections.namedtuple("Result", "checks facts tip secs error")


def _take():
    return {"tip": tipfont.take(), "box": boxes.take()}

_CHILD = [None]              # in a child: its end of the pipe to the parent


def workers():
    try:
        return max(1, int(os.environ.get("UADD_JOBS", "0"))) if os.environ.get("UADD_JOBS") else os.cpu_count() or 1
    except ValueError:
        return os.cpu_count() or 1


def timeout():
    try:
        return float(os.environ.get("UADD_JOB_TIMEOUT", "900"))
    except ValueError:
        return 900.0


def free_mb():
    try:
        with open("/proc/meminfo") as fh:
            for line in fh:
                if line.startswith("MemAvailable:"):
                    return int(line.split()[1]) // 1024
    except OSError:
        pass
    return 1 << 30


def _plain(checks):
    """(name, ok, detail) tuples that pickle: a detail that does not pickle goes as its str()."""
    out = []
    for c in checks:
        name, ok, detail = c[0], bool(c[1]), c[2]
        try:
            pickle.dumps(detail)
        except Exception:
            detail = str(detail)
        out.append((name, ok, detail))
    return out


def _plain_facts(facts):
    try:
        pickle.dumps(facts)
        return facts
    except Exception:
        return json.loads(json.dumps(facts, default=str))


def label(fn, args):
    def one(a):
        if isinstance(a, str):
            return a
        r = repr(a)                        # the same in every run, or the object's type name (no " at 0x1234")
        return r if " at 0x" not in r and len(r) <= 80 else getattr(a, "__name__", type(a).__name__)
    shown = ", ".join(one(a) for a in args)
    return f"{fn.__module__}.{fn.__name__}({shown})"


def spawn(fn, *args):
    """Starts fn(*args) as a job of its own; returns its place-holder check (a (name, ok, detail) tuple).
    Only inside a job (see Pool); fn and args must pickle (fn: a module-level function)."""
    conn = _CHILD[0]
    conn.send(("spawn", fn, args))
    return (MARK + str(conn.recv()), True, "")


class Pool:
    def __init__(self, check, watch=False):
        self.check = check                 # flow.Check
        self.watch = watch                 # jobcache.py is on: each job notes what it reads (jobinputs.py)
        self.inputs = {}                   # id -> its jobinputs.Inputs
        self.jobs = {}                     # id -> (fn, args, label)
        self.queue = []                    # ids not started yet; spawned ones go first
        self.results = {}                  # id -> Result
        self.parent_of = {}                # id -> the id that spawned it
        self.serial = workers() == 1

    def add(self, fn, *args):
        jid = len(self.jobs)
        self.jobs[jid] = (fn, args, label(fn, args))
        self.queue.append(jid)
        return jid

    def add_done(self, name):
        """A place for a job spawned in an earlier run (jobcache.py puts its result in), never run here."""
        jid = len(self.jobs)
        self.jobs[jid] = (None, (), name)
        return jid

    # ── a job, in the child ────────────────────────────────────────────────────────────────────
    def _child(self, jid, conn):
        _CHILD[0] = conn
        fn, args, _ = self.jobs[jid]
        _take()                            # what the parent had is not this job's
        t0, seen = time.time(), jobinputs.Inputs()
        if self.watch:
            clock.DOUBT.clear()
            jobinputs.to(seen)
        try:
            checks, facts = fn(*args)
            msg = ("done", _plain(checks), _plain_facts(facts), _take(), time.time() - t0, None)
        except BaseException:
            msg = ("done", [], {}, _take(), time.time() - t0, traceback.format_exc()[-1500:])
        jobinputs.to(None)
        if clock.DOUBT:
            seen.bad.add(f"a time limit passed only by its stretch under load ({max(clock.DOUBT):.1f} ms)")
        conn.send(msg + (seen,))

    # ── the parent ─────────────────────────────────────────────────────────────────────────────
    def run(self, before_rest=None):
        """Runs every job (and the jobs they spawn) to the end. `before_rest()` runs here once the first job has
        started (pool.py's caller warms the file memo with it, while the first job reads its own)."""
        if self.serial:
            return self._run_serial(before_rest)
        running = {}                       # conn -> (id, pid, start time)
        limit, n = timeout(), workers()
        first = True
        while self.queue or running:
            while self.queue and len(running) < n and (not running or free_mb() >= MIN_FREE_MB):
                jid = self.queue.pop(0)
                conn, pid = self._fork(jid)
                running[conn] = (jid, pid, time.time())
                if first and before_rest:
                    before_rest()
                first = False
            ready = wait(list(running), timeout=1.0)
            for conn in ready:
                jid, pid, t0 = running[conn]
                try:
                    msg = conn.recv()
                except (EOFError, OSError):
                    msg = None
                if msg and msg[0] == "spawn":
                    new = self.add(msg[1], *msg[2])
                    self.queue.remove(new)
                    self.queue.insert(0, new)          # it holds up the job that asked for it
                    self.parent_of[new] = jid
                    conn.send(new)
                    continue
                del running[conn]
                conn.close()
                status = os.waitpid(pid, 0)[1]
                if msg and msg[0] == "done":
                    self.results[jid], self.inputs[jid] = Result(*msg[1:-1]), msg[-1]
                else:
                    self.results[jid] = Result([], {}, None, time.time() - t0, f"the job's process ended with no "
                                               f"result ({self._why(status)})")
            for conn, (jid, pid, t0) in list(running.items()):
                if time.time() - t0 > limit:
                    os.kill(pid, signal.SIGKILL)
                    os.waitpid(pid, 0)
                    conn.close()
                    del running[conn]
                    self.results[jid] = Result([], {}, None, time.time() - t0,
                                               f"over UADD_JOB_TIMEOUT ({limit:.0f} s): killed")
        return self.results

    def _fork(self, jid):
        mine, theirs = Pipe()
        pid = os.fork()
        if pid == 0:                       # the child: run the job, send its result, leave at once
            code = 0
            try:
                mine.close()
                self._child(jid, theirs)
            except BaseException:
                code = 3
            finally:
                os._exit(code)
        theirs.close()
        return mine, pid

    @staticmethod
    def _why(status):
        if os.WIFSIGNALED(status):
            return f"killed by signal {os.WTERMSIG(status)}"
        return f"exit code {os.WEXITSTATUS(status)}"

    def _run_serial(self, before_rest):
        """UADD_JOBS=1: every job here, in order; a spawn runs its job at once."""
        def inline(fn, *args):
            jid = self.add(fn, *args)
            self.queue.remove(jid)
            self._one(jid)
            return (MARK + str(jid), True, "")
        global spawn
        real, spawn = spawn, inline
        try:
            while self.queue:
                self._one(self.queue.pop(0))
                if before_rest:
                    before_rest()
                    before_rest = None
        finally:
            spawn = real
        return self.results

    def _one(self, jid):
        fn, args, _ = self.jobs[jid]
        outer = _take()                    # a job that spawned this one keeps what it had so far
        t0 = time.time()
        try:
            checks, facts = fn(*args)
            self.results[jid] = Result(_plain(checks), facts, _take(), time.time() - t0, None)
        except Exception:
            self.results[jid] = Result([], {}, _take(), time.time() - t0, traceback.format_exc()[-1500:])
        tipfont.STATE.update(outer["tip"])
        boxes.STATE.update(outer["box"])
        gc.collect()

    # ── the results ────────────────────────────────────────────────────────────────────────────
    def expand(self, jid):
        """The job's checks with each place-holder swapped for its job's checks (in place, in order), as
        flow.Check; a job that failed gives one FAIL check that names it, why, and how to run it alone."""
        r = self.results.get(jid)
        out = []
        if r is None:
            return [self.check(f"job ran: {self.jobs[jid][2]}", False, "no result (the pool stopped first)")]
        for name, ok, detail in r.checks:
            if name.startswith(MARK):
                out += self.expand(int(name[len(MARK):]))
            else:
                out.append(self.check(name, ok, detail))
        if r.error:
            out.append(self.check(f"job ran: {self.jobs[jid][2]}", False,
                                  r.error.strip() + "  (repro: UADD_JOBS=1 python3 tools/harness/run.py)"))
        return out

    def family(self, jid):
        """The job and every job it spawned, at any depth."""
        out = [jid]
        for kid, parent in self.parent_of.items():
            if parent == jid:
                out += self.family(kid)
        return out

    def tip(self, jid):
        """The tooltip font counts of the job and its spawned jobs, merged (tipfont.merge)."""
        return tipfont.merge([self.results[j].tip["tip"] for j in self.family(jid)
                              if j in self.results and self.results[j].tip])

    def boxes(self, jid):
        """The symptom check's hits of the job and its spawned jobs, merged (boxes.merge)."""
        return boxes.merge([self.results[j].tip["box"] for j in self.family(jid)
                            if j in self.results and self.results[j].tip])
