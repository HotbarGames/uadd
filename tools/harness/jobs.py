"""run.py's flows as pool.py jobs, side by side: the main flow (its parts with sessions of their own become jobs of
their own, flow_split.py), the journal's, and one job per segment. A segment module with pieces() (chaos.py) gives
one job per piece, and its assemble() puts their results together. The checks come back in run.py's order, each
segment with its tooltip font check (tipfont.py), as if they had run one after another.

UADD_JOBS=1 runs them all in this process, in order (pool.py).
"""
import gc
import glob
import json
import os

import jobinputs
import loader
import pool
import boxes
import tipfont

HERE = os.path.dirname(os.path.abspath(__file__))
WARM_THREADS = 16          # files read at a time by warm() (2026-11-26: 439 files on /mnt/c in 0.36 s, one by one 5.5 s)
# The slowest first, so they do not end the run alone (one run on 8 cores, 2026-11-22: qtag 17 s, chaos 62 s in
# one job, now its modules side by side, the slowest 13 s; lt 11 s). The rest go in run.py's order.
# Again on 2026-11-26 (8 cores): qtag 28 s, lt 18, dj 17, gq 16, pops 12, ttp 10, wtw 10, litemount 8, dci 7; gq and
# ttp started last and ended the run alone.
SLOW = ("qtag", "chaos", "lt", "dj", "gq", "pops", "ttp", "wtw", "litemount", "dci", "mc", "fqp", "cua", "lsw",
        "safe", "wp")
# Chaos pieces that take longest (same run: 28, 24, 21, 13, 11, 10 s) start first; their checks keep pieces() order.
SLOW_CHAOS = ("UADD_OneForAll", "UADD_Mastercraft", "UADD_DeleteCheapestItem", "UADD_RoadToSixty",
              "UADD_WhatsTraining", "UADD_GearQuestForever")


def _slow_first(pieces, serial):
    """The indexes of `pieces` in the order to start them: SLOW_CHAOS first when side by side, else as given."""
    rank = {f: i for i, f in enumerate(SLOW_CHAOS)}
    at = range(len(pieces))
    if serial:
        return list(at)
    return sorted(at, key=lambda i: rank.get(pieces[i][1][0] if pieces[i][1] else None, len(rank)))


# How long each job took in the last side-by-side runs (label -> wall seconds, the mean of the last record and this
# run): with it the jobs start slowest first, after the main flow (its spawned parts go first anyway). Wall time, not
# CPU: a job that waits (TomTom's place flow: 2 s CPU in 9 s) also ends the run alone when it starts last. The
# record is outside the repo, as the push check runs in a fresh copy of it. It sets only the start order: the checks,
# their order and verdicts stay the same (pool.py's expand).
TIMES = os.environ.get("UADD_JOB_TIMES") or os.path.join(
    os.environ.get("XDG_CACHE_HOME") or os.path.join(os.path.expanduser("~"), ".cache"), "uadd", "harness-times.json")


def recorded():
    """The recorded seconds by job label; {} when there is no readable record. Not an input of any job
    (jobinputs.py does not see it): it changes no check."""
    was = jobinputs.to(None)
    try:
        with open(TIMES, encoding="utf-8") as fh:
            got = json.load(fh)
        return {str(k): float(v) for k, v in got.items()}
    except (OSError, ValueError, TypeError, AttributeError):
        return {}
    finally:
        jobinputs.to(was)


def by_time(p, first, times):
    """Sorts the pool's queue: `first` (the main flow), then the jobs with no record (they may be slow; in the
    order they were added), then the rest by recorded time, slowest first. No record at all, or UADD_JOBS=1
    (one after another, the reference): as added."""
    if times and not p.serial:
        p.queue.sort(key=lambda j: (j != first, -times.get(p.jobs[j][2], float("inf"))))


def keep_times(p, times, reused=()):
    """Records the time of each job that ran here side by side; a reused one keeps its old record."""
    if p.serial:
        return
    labels = {p.jobs[j][2] for j in p.jobs}
    new = {k: v for k, v in times.items() if k in labels}
    for j, r in p.results.items():
        if j not in reused:
            label = p.jobs[j][2]
            new[label] = round((r.secs + new[label]) / 2 if label in new else r.secs, 2)
    if new == times:
        return
    was = jobinputs.to(None)               # nor is writing it something a kept result must know of
    try:
        os.makedirs(os.path.dirname(TIMES), exist_ok=True)
        part = f"{TIMES}.{os.getpid()}"
        with open(part, "w", encoding="utf-8") as fh:
            json.dump(new, fh, ensure_ascii=False, sort_keys=True, indent=0)
        os.replace(part, TIMES)
    except OSError:                        # only the next run's order needs it
        pass
    finally:
        jobinputs.to(was)


def main_job():
    import flow
    f = flow.run(spawn=pool.spawn)          # looked up now: in UADD_JOBS=1 pool.py swaps spawn for its own
    return f.checks, f.facts


def dj_job():
    import flow_dj_module
    return flow_dj_module.run()


def segment_job(mod):
    return mod.run_checks()


def _warm_one(item):
    """Reads one file of an addon's TOC into loader's memo; returns the files an XML of it includes."""
    folder, rel = item
    path = os.path.join(folder, *rel.split("/"))
    if not loader.is_file(path):
        return []
    text = loader.read_text(path)
    if not rel.lower().endswith(".xml"):
        return []
    try:
        root = loader.parse_xml(text)
    except Exception:
        return []
    base = os.path.dirname(rel)
    return [(folder, f"{base}/{x}" if base else x) for x in
            (el.get("file", "").replace("\\", "/") for el in root.iter()) if x]


def warm():
    """Reads the files most jobs share (the main flow's addons, the stubs) into loader's memo, so the jobs
    forked after this have them. The same files as one after another, read WARM_THREADS at a time: a file on
    /mnt/c costs 3-10 ms of waiting over 9P, so 16 in flight take a fraction of the time."""
    import session
    from concurrent.futures import ThreadPoolExecutor
    with ThreadPoolExecutor(WARM_THREADS) as ex:
        list(ex.map(loader.read_text, glob.glob(os.path.join(HERE, "*.lua"))))
        todo = [(a.folder, r.replace("\\", "/")) for a in session.addons() for r in a.files]
        while todo:                        # one level of XML includes at a time
            todo = [x for got in ex.map(_warm_one, todo) for x in got]


def _segment(p, key, mod, jids):
    """One segment's (checks with its tooltip font check, facts, did its jobs pass) from its jobs' results."""
    import flow
    tip = tipfont.merge([p.tip(j) for j in jids])
    tail = tipfont.segment(key, flow.Check, tip) + boxes.segment(key, flow.Check, boxes.merge([p.boxes(j) for j in jids]))
    if not hasattr(mod, "pieces"):
        r = p.results.get(jids[0])
        checks = p.expand(jids[0]) + tail
        return checks, (r.facts if r else {}), all(c.ok for c in checks)
    got = [(p.expand(j), p.results[j].facts if j in p.results and not p.results[j].error else {}) for j in jids]
    checks, facts = mod.assemble(got)
    checks = [flow.Check(*c) for c in checks] + tail
    own = {c[0] for c in mod.assemble([([], {})] * len(jids))[0] if not c[1]}     # FAILs with no job's part in them
    return checks, facts, all(c.ok or c.name in own for c in checks)


def run_all(segments, cache=None):
    """`segments`: run.py's ((facts key, flow module), ...). `cache`: None (every job runs), or a function that
    makes the jobcache.Cache. Returns (checks, facts, notes, journal's missing addons)."""
    import flow
    import flow_dj_module
    loader.fresh()
    p = pool.Pool(flow.Check, watch=cache is not None)
    main = p.add(main_job)
    missing = flow_dj_module.missing_addons()
    ids, mods = {}, dict(segments)
    for key in [k for k in SLOW if k in mods or k == "dj"] + [k for k in mods if k not in SLOW]:
        if key == "dj":
            if not missing:
                ids["dj"] = [p.add(dj_job)]
        elif hasattr(mods[key], "pieces"):
            ps = mods[key].pieces()
            got = {i: p.add(ps[i][0], *ps[i][1]) for i in _slow_first(ps, p.serial)}
            ids[key] = [got[i] for i in range(len(ps))]          # results in pieces() order (assemble)
        else:
            ids[key] = [p.add(segment_job, mods[key])]
    notes, groups = [], []                 # groups: (job ids, did every check of theirs pass), for the cache
    tops = [main] + [j for js in ids.values() for j in js]
    if cache:
        try:
            import session
            session.addons()               # warm() would make them here, unseen: the jobs forked later inherit them
            cache = cache()
            cache.restore(p, tops)
        except Exception as e:             # the cache never aborts a run: go on without it, run what is not done
            cache = None
            notes.append(f"results of earlier runs: not used, the cache failed: {e!r}")
            p.queue += [j for j in tops if j not in p.results and j not in p.queue]
    times = recorded()
    if p.queue and p.serial:
        p.run(before_rest=warm)
    elif p.queue:                          # side by side: every job, the main flow too, forks with the files read
        by_time(p, main, times)
        warm()
        p.run()
    keep_times(p, times, cache.reused if cache else ())

    checks = (p.expand(main) + tipfont.segment("main", flow.Check, p.tip(main))
              + boxes.segment("main", flow.Check, p.boxes(main)))
    groups.append(([main], all(c.ok for c in checks)))
    facts = {}
    for jid in p.family(main):
        r = p.results.get(jid)
        facts.update(r.facts if r else {})
    if missing:
        notes.append("dj module checks skipped: missing addons: " + ", ".join(missing))
    else:
        got, facts["dj_module"], ok = _segment(p, "dj", None, ids["dj"])
        groups.append((ids["dj"], ok))
        checks += got
    for key, mod in segments:
        got, facts[key], ok = _segment(p, key, mod, ids[key])
        groups.append((ids[key], ok))
        checks += got
    if cache:
        try:
            cache.store(p, groups)
        except Exception as e:             # nothing is kept from this run; the checks are what counts
            notes.append(f"results of earlier runs: none kept, the cache failed: {e!r}")
    reused = cache.reused if cache else ()
    secs = sorted(((r.secs, p.jobs[j][2]) for j, r in p.results.items() if j not in reused), reverse=True)
    notes += cache.notes(len(secs)) if cache else []
    notes.append(f"jobs: {len(secs)} in {pool.workers()} at a time; slowest: " +
                 ", ".join(f"{label.replace('jobs.segment_job', '')} {s:.0f} s" for s, label in secs[:8]))
    del p
    gc.collect()
    return checks, facts, notes, missing
