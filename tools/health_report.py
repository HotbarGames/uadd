"""The game-health part of tools/missed.py: what UADD's guard (UADD/Guard.lua) had to repair in the last
game session (UADD_DB.health.guard: {kind: count}), and the font facts the in-client probe recorded
(UADD_DB.health.probe, UADD/Probe.lua). A guard repair means UADD broke the game for a moment (boxes, a dead
key): it is printed first and loudly, to fix before any missed text. Standard library only."""
import math


def _num(v):
    if isinstance(v, bool) or not isinstance(v, (int, float)) or not math.isfinite(v) or v < 0:
        return 0
    return int(v)


def collect(saved_dbs):
    """saved_dbs: parsed files ({global: value}). Returns (guard {kind: count}, [probe dicts])."""
    guard, probes = {}, []
    for saved in saved_dbs:
        db = saved.get("UADD_DB") if isinstance(saved, dict) else None
        health = db.get("health") if isinstance(db, dict) else None
        if not isinstance(health, dict):
            continue
        g = health.get("guard")
        for kind, n in (g.items() if isinstance(g, dict) else ()):
            if _num(n):
                guard[str(kind)] = guard.get(str(kind), 0) + _num(n)
        if isinstance(health.get("probe"), dict):
            probes.append(health["probe"])
    return guard, probes


def report(guard, probes):
    """Prints the guard's repairs (loud) and the probe's facts. Returns the number of repairs."""
    total = sum(guard.values())
    if total:
        print("!!! GAME HEALTH: UADD's guard had to repair the game %d times last session. Fix this first:" % total)
        for kind, n in sorted(guard.items(), key=lambda kv: -kv[1]):
            print("  guard %s = %d" % (kind, n))
        print("  (UADD/Guard.lua names each kind; a 'fail' kind means the repair did not work.)")
    for p in probes:
        facts = ", ".join("%s=%s" % (k, p[k]) for k in sorted(p) if k not in ("build", "at"))
        print("font probe (build %s): %s" % (p.get("build", "?"), facts or "no facts"))
    return total
