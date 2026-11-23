"""run.py's flows as pool.py jobs, side by side: the main flow (its parts with sessions of their own become jobs of
their own, flow_split.py), the journal's, and one job per segment. A segment module with pieces() (chaos.py) gives
one job per piece, and its assemble() puts their results together. The checks come back in run.py's order, each
segment with its tooltip font check (tipfont.py), as if they had run one after another.

UADD_JOBS=1 runs them all in this process, in order (pool.py).
"""
import gc
import glob
import os

import loader
import pool
import boxes
import tipfont

HERE = os.path.dirname(os.path.abspath(__file__))
# The slowest first, so they do not end the run alone (one run on 8 cores, 2026-11-22: qtag 17 s, chaos 62 s in
# one job, now its modules side by side, the slowest 13 s; lt 11 s). The rest go in run.py's order.
SLOW = ("qtag", "chaos", "lt", "dj", "pops", "mc", "lsw", "wtw", "fqp", "litemount", "safe", "wp")


def main_job():
    import flow
    f = flow.run(spawn=pool.spawn)          # looked up now: in UADD_JOBS=1 pool.py swaps spawn for its own
    return f.checks, f.facts


def dj_job():
    import flow_dj_module
    return flow_dj_module.run()


def segment_job(mod):
    return mod.run_checks()


def warm():
    """Reads the files most jobs share (the main flow's addons, the stubs) into loader's memo, so the jobs
    forked after this have them."""
    import session
    for path in glob.glob(os.path.join(HERE, "*.lua")):
        loader.read_text(path)
    for a in session.addons():
        todo = [r.replace("\\", "/") for r in a.files]
        while todo:
            rel = todo.pop()
            path = os.path.join(a.folder, *rel.split("/"))
            if not loader.is_file(path):
                continue
            text = loader.read_text(path)
            if rel.lower().endswith(".xml"):
                try:
                    root = loader.parse_xml(text)
                except Exception:
                    continue
                base = os.path.dirname(rel)
                todo += [f"{base}/{x}" if base else x for x in
                         (el.get("file", "").replace("\\", "/") for el in root.iter()) if x]


def _segment(p, key, mod, jids):
    """One segment's (checks with its tooltip font check, facts) from its jobs' results."""
    import flow
    tip = tipfont.merge([p.tip(j) for j in jids])
    tail = tipfont.segment(key, flow.Check, tip) + boxes.segment(key, flow.Check, boxes.merge([p.boxes(j) for j in jids]))
    if not hasattr(mod, "pieces"):
        r = p.results.get(jids[0])
        return p.expand(jids[0]) + tail, (r.facts if r else {})
    got = [(p.expand(j), p.results[j].facts if j in p.results and not p.results[j].error else {}) for j in jids]
    checks, facts = mod.assemble(got)
    return [flow.Check(*c) for c in checks] + tail, facts


def run_all(segments):
    """`segments`: run.py's ((facts key, flow module), ...). Returns (checks, facts, notes, journal's missing
    addons)."""
    import flow
    import flow_dj_module
    loader.fresh()
    p = pool.Pool(flow.Check)
    main = p.add(main_job)
    missing = flow_dj_module.missing_addons()
    ids, mods = {}, dict(segments)
    for key in [k for k in SLOW if k in mods or k == "dj"] + [k for k in mods if k not in SLOW]:
        if key == "dj":
            if not missing:
                ids["dj"] = [p.add(dj_job)]
        elif hasattr(mods[key], "pieces"):
            ids[key] = [p.add(fn, *args) for fn, args in mods[key].pieces()]
        else:
            ids[key] = [p.add(segment_job, mods[key])]
    p.run(before_rest=warm)

    notes = []
    checks = (p.expand(main) + tipfont.segment("main", flow.Check, p.tip(main))
              + boxes.segment("main", flow.Check, p.boxes(main)))
    facts = {}
    for jid in p.family(main):
        r = p.results.get(jid)
        facts.update(r.facts if r else {})
    if missing:
        notes.append("dj module checks skipped: missing addons: " + ", ".join(missing))
    else:
        got, facts["dj_module"] = _segment(p, "dj", None, ids["dj"])
        checks += got
    for key, mod in segments:
        got, facts[key] = _segment(p, key, mod, ids[key])
        checks += got
    secs = sorted(((r.secs, p.jobs[j][2]) for j, r in p.results.items()), reverse=True)
    notes.append(f"jobs: {len(p.results)} in {pool.workers()} at a time; slowest: " +
                 ", ".join(f"{label.replace('jobs.segment_job', '')} {s:.0f} s" for s, label in secs[:8]))
    del p
    gc.collect()
    return checks, facts, notes, missing
