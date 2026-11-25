"""Reuses the results of harness jobs whose inputs did not change, in hand runs of run.py (docs/TESTING.md).

One file per job (tools/.cache/jobs/, git-ignored) holds the job's results (and those of the jobs it spawned) with
every input: the files it read, the folders it listed, the paths it looked for (jobinputs.py sees them in the job's
process), the Python files it can use (jobgraph.py), and the world around it (Python, lupa, environment, folder,
date). A job is reused only when each of them is the same now. In doubt an input counts: a false miss costs seconds.

Kept: only a job whose every check passed, with its segment's checks, and that did nothing jobinputs.py cannot
follow (bad). Not kept either: a job that passed a time limit only because clock.py stretched it for the load
(clock.DOUBT), and one with an input changed since this run began (it may have read either state).
`--fresh`: every job runs; results are kept as above, and one that fails with unchanged inputs is dropped.
Off with CI set (the push check is always fresh), UADD_CACHE=0, UADD_JOBS=1, under unittest, and where there is
no fork: pool.py then works as if this file did not exist.
"""
import hashlib
import os
import pickle
import re
import sys
import time
from concurrent.futures import ThreadPoolExecutor

import jobinputs
import pool
from jobgraph import HERE, TOOLS, Graph, edges_of, modules_of

FOLDER = os.path.join(TOOLS, ".cache", "jobs")
FORMAT = 1
BASE = ("run", "jobs", "pool", "jobcache", "jobgraph", "jobinputs", "loader", "session", "tipfont", "boxes", "clock",
        "flow")                                                                   # Python files of every job
ENV = re.compile(r"""(?:environ(?:\.get)?|getenv)\s*[\[(]\s*["'](\w+)["']""")
ENV_NAMES = re.compile(r"^(?:UADD_|CHAOS_|RTS_|PYTHON|LC_|LANG|TZ$|HOME$|USER$)")
WINDOWS_MARGIN = 600      # /mnt/c's clock is Windows' own: a file there must be this many seconds older


def off(environ=os.environ):
    """Why the cache is off, or None."""
    if environ.get("CI"):
        return "CI is set"
    if environ.get("UADD_CACHE") == "0":
        return "UADD_CACHE=0"
    if pool.workers() == 1:
        return "one job at a time"
    if "unittest" in sys.modules:
        return "a test run"
    return None if hasattr(os, "fork") else "no fork here"


def world(graph_folders=(HERE, TOOLS)):
    """What every job depends on besides files: versions, environment, working folder, the date (a kept result
    lives for a day at most)."""
    names = {n for n in os.environ if ENV_NAMES.match(n)}
    for d in graph_folders:
        for f in os.listdir(d):
            if f.endswith(".py"):
                with open(os.path.join(d, f), encoding="utf-8", errors="replace") as fh:
                    names |= set(ENV.findall(fh.read()))
    names -= {"UADD_JOBS", "UADD_CACHE"}
    packages = sorted((n, *_stat(m.__file__)) for n, m in list(sys.modules.items())
                      if "-packages" + os.sep in (getattr(m, "__file__", None) or ""))
    return (FORMAT, sys.version, sys.flags.hash_randomization, os.getcwd(), time.strftime("%Y-%m-%d %z"),
            sorted((n, os.environ[n]) for n in names if n in os.environ), packages)


def _stat(path):
    try:
        st = os.stat(path)
        return st.st_size, st.st_mtime_ns
    except OSError:
        return None, None


# ── what an input looks like now ───────────────────────────────────────────────────────────────────
def look(item):
    """(kind, path) -> what the job would see now. files: the content; dirs: the names; stats: kind, size, time."""
    kind, p = item
    try:
        if kind == "files":
            with open(p, "rb") as f:
                return hashlib.sha1(f.read()).hexdigest()
        if kind == "dirs":
            with os.scandir(p) as it:
                return hashlib.sha1("\0".join(sorted(f"{e.name}/{e.is_dir()}" for e in it
                                                     if e.name != "__pycache__")).encode(
                                                         "utf-8", "surrogateescape")).hexdigest()
        if os.path.isdir(p):
            return "dir"
        st = os.stat(p)
        return f"{st.st_size} {st.st_mtime_ns}"
    except IsADirectoryError:
        return "dir"
    except (OSError, ValueError) as e:       # ValueError: a NUL byte, a lone surrogate in the path
        return f"none: {type(e).__name__}"


def settled(item, start):
    """True when the input did not change since the run began (so every read in the run saw what is there now).
    Of a path that is not there, the folder it would be in: it may have been there earlier in the run."""
    kind, p = item
    if kind == "stats" and os.path.isdir(p):
        return True
    while True:
        try:
            st = os.stat(p)
            break
        except (OSError, ValueError):
            if p == os.path.dirname(p):
                return False
            p = os.path.dirname(p)
    return max(st.st_mtime, st.st_ctime) < start - (WINDOWS_MARGIN if p.startswith("/mnt/") else 0.05)


class Cache:
    """One run's view of the kept results. start: when the run began, before any input was read. base: the Inputs
    of the parent itself (they count for every job). wants_fresh: look nothing up."""

    def __init__(self, start, base=None, folder=FOLDER, wants_fresh=False, graph=None):
        self.start, self.folder, self.fresh = start, folder, wants_fresh
        jobinputs.to(None)                # the parent reads no more inputs: from now on only the jobs note theirs
        self.base = base if base is not None else jobinputs.Inputs()
        self.base.code = set()            # what the parent imports: the Graph says which of it each job uses
        self.graph = graph or Graph()
        self.world = world(self.graph.folders)
        self.valid, self.reused, self.why = {}, set(), {}       # labels with a fitting entry; job ids; label -> why not kept
        self.seen = {}

    def _file(self, label):
        return os.path.join(self.folder, hashlib.sha1(label.encode()).hexdigest()[:20] + ".bin")

    def _read(self, label):
        try:
            with open(self._file(label), "rb") as f:
                head, _, body = f.read().partition(b"\n")
            if hashlib.sha256(body).hexdigest().encode() != head:
                return None
            entry = pickle.loads(body)
            return entry if entry["label"] == label and entry["world"] == self.world else None
        except Exception:
            return None                   # none, cut short, of an older format: run the job

    def _look(self, items):
        todo = [i for i in items if i not in self.seen]
        with ThreadPoolExecutor(16) as ex:
            self.seen.update(zip(todo, ex.map(look, todo, chunksize=8)))

    def _closure(self, mods):
        return self.graph.closure(set(mods) | set(BASE), edges_of(self.base))

    def _loaded(self):
        """Reads every loaded repo module's edges (the ones that change another module count for that module)."""
        for m in list(sys.modules):
            if "." not in m and self.graph.path(m):
                self.graph.uses(m)

    @staticmethod
    def _labels(p, jids):
        """{label: job id} of the jobs with a label of their own."""
        seen = [p.jobs[j][2] for j in jids]
        return {p.jobs[j][2]: j for j in jids if seen.count(p.jobs[j][2]) == 1}

    def restore(self, p, jids):
        """Puts the kept results of the jobs `jids` whose inputs are the same into the pool."""
        self._loaded()
        labels = self._labels(p, jids)
        got = {lb: e for lb, e in ((lb, self._read(lb)) for lb in labels)
               if e and e["py"] == self._closure(modules_of(*p.jobs[labels[lb]][:2]) | e["mods"])}
        self._look({i for e in got.values() for i in e["inputs"]})
        for lb, e in got.items():
            if all(self.seen[i] == d for i, d in e["inputs"].items()):
                self.valid[lb] = e
                if not self.fresh:
                    self._put(p, labels[lb], e)

    def _put(self, p, top, e):
        ids = [top] + [p.add_done(lb) for lb, _, _ in e["family"][1:]]
        p.queue.remove(top)
        for jid, (_, parent, r) in zip(ids, e["family"]):
            if parent is not None:
                p.parent_of[jid] = ids[parent]
            p.results[jid] = r._replace(checks=[
                (pool.MARK + str(ids[int(n[len(pool.MARK):])]), ok, d) if n.startswith(pool.MARK) else (n, ok, d)
                for n, ok, d in r.checks])
            self.reused.add(jid)

    def store(self, p, groups):
        """groups: [(job ids, did every check of theirs pass)]. Keeps what may be kept."""
        labels = self._labels(p, [j for jids, _ in groups for j in jids])
        self.seen = {}                    # what the run's start saw does not count here
        for jids, ok in groups:
            for j in jids:
                lb = p.jobs[j][2]
                if labels.get(lb) != j:
                    continue
                if not ok:
                    self.why[lb] = "a check of its segment failed"
                    if lb in self.valid:
                        self._drop(self._file(lb))
                elif j not in self.reused:
                    self._keep(p, j, lb)
        keep = {os.path.basename(self._file(lb)) for lb in labels}
        try:
            names = os.listdir(self.folder) if os.path.isdir(self.folder) else ()
        except OSError:
            names = ()
        for f in names:
            path = os.path.join(self.folder, f)
            if f.endswith(".tmp"):        # a write that died: not ours to keep, once it is old
                if self._old(path):
                    self._drop(path)
            elif f not in keep:           # a job that is no more
                self._drop(path)

    @staticmethod
    def _old(path):
        try:
            return time.time() - os.stat(path).st_mtime > 3600
        except OSError:
            return False

    @staticmethod
    def _drop(path):
        try:
            os.remove(path)
        except OSError:
            pass

    def _keep(self, p, top, label):
        fam = p.family(top)
        if any(j not in p.results or j not in p.inputs or p.results[j].error for j in fam) or not all(
                ok for j in fam for _, ok, _ in p.results[j].checks):
            self.why[label] = "a check failed"
            return
        got, mods = jobinputs.Inputs().add(self.base), set()
        for j in fam:
            got.add(p.inputs[j])
            mods |= modules_of(*p.jobs[j][:2]) | {n.split(".")[0] for _, n in p.inputs[j].mods}
        if got.bad:
            self.why[label] = sorted(got.bad)[0]
            return
        got.files |= got.code
        py = self._closure(mods)
        items = [(k, x) for k in ("files", "dirs", "stats") for x in sorted(getattr(got, k))
                 if k != "stats" or x not in got.files]
        every = items + [("files", self.graph.path(m)) for m in py]
        with ThreadPoolExecutor(16) as ex:
            calm = list(ex.map(lambda i: settled(i, self.start), every, chunksize=8))
        if not all(calm):
            self.why[label] = f"changed during the run: {every[calm.index(False)][1]}"
            return
        self._look(items)
        at = {j: n for n, j in enumerate(fam)}
        family = [(p.jobs[j][2], at.get(p.parent_of.get(j)) if j != top else None, p.results[j]._replace(checks=[
            (pool.MARK + str(at[int(n[len(pool.MARK):])]), ok, d) if n.startswith(pool.MARK) else (n, ok, d)
            for n, ok, d in p.results[j].checks])) for j in fam]
        tmp = f"{self._file(label)}.{os.getpid()}.tmp"
        try:
            body = pickle.dumps({"label": label, "world": self.world, "mods": mods, "py": py,
                                 "inputs": {i: self.seen[i] for i in items}, "family": family})
            os.makedirs(self.folder, exist_ok=True)
            with open(tmp, "wb") as f:
                f.write(hashlib.sha256(body).hexdigest().encode() + b"\n" + body)
            os.replace(tmp, self._file(label))
        except Exception as e:            # a result that does not pickle, a full disk: the job runs next time
            self.why[label] = f"not written: {e!r}"
            self._drop(tmp)

    def notes(self, ran):
        """The run's honest lines: how many jobs were reused, and which that ran were not kept, and why."""
        out = [f"results of earlier runs: {len(self.reused)} jobs reused, {ran} run" +
               (" (--fresh)" if self.fresh else " (--fresh runs all)")]
        whys = {}
        for lb, why in sorted(self.why.items()):
            whys.setdefault(why[:150], []).append(lb.replace("jobs.segment_job", ""))
        return out + [f"not kept ({why}): {', '.join(lbs[:6])}" + (f" and {len(lbs) - 6} more" if len(lbs) > 6 else "")
                      for why, lbs in whys.items()]
