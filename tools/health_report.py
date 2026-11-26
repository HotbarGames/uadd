"""The game-health part of tools/missed.py: what UADD's guard (UADD/Guard.lua, UADD/BoxGuard.lua) had to repair in
the game, and the font facts the in-client probe recorded (UADD_DB.health.probe, UADD/Probe.lua).
  * UADD_DB.health.guard: {kind: count}, counted over all sessions; health.guardLast: {kind: {at, version,
    sample}}: when the kind last happened (time()), in which UADD version, and one sample (a frame and its text).
  * A guard repair means UADD broke the game for a moment (boxes, a dead key): it is printed first and loudly,
    to fix before any missed text. A kind whose last repair was in an older UADD than the one installed now
    may be fixed already: it is printed quietly and is not counted.
Standard library only."""
import math
import os
import re
import time

KINDS = {
    "tip": "a tooltip line would show boxes: its font was fixed",
    "line": "a text showed boxes: its font was fixed",
    "tipfail": "a tooltip line may show boxes: no Cyrillic font took",
    "linefail": "a text may show boxes: no Cyrillic font took",
    "box": "a text drew boxes (its width): our font again or the file by hand fixed it",
    "boxfail": "a text drew boxes and nothing fixed it: its English is back for the session",
    "font": "UADD code changed a shared game font: put back",
    "focus": "a hidden edit box held the keyboard: freed",
}
SAMPLE = 120          # characters of a sample shown
VERSION = re.compile(r"^\s*##\s*Version:\s*(\S+)", re.M)


def _num(v):
    if isinstance(v, bool) or not isinstance(v, (int, float)) or not math.isfinite(v) or v < 0:
        return 0
    return int(v)


def _text(v, cap):
    if not isinstance(v, str):
        return None
    v = re.sub(r"[\x00-\x1f\x7f]+", " ", v).strip()
    return v[:cap] or None


def _last(rec):
    """One guardLast record, made safe: {at, version, sample}, or None when it holds nothing usable."""
    if not isinstance(rec, dict):
        return None
    out = {"at": _num(rec.get("at")) or None, "version": _text(rec.get("version"), 30),
           "sample": _text(rec.get("sample"), SAMPLE)}
    return out if any(out.values()) else None


def collect(saved_dbs):
    """saved_dbs: parsed files ({global: value}). Returns (guard {kind: count}, [probe dicts], last {kind: record}):
    the counts added up over the files, and per kind the newest guardLast record."""
    guard, probes, last = {}, [], {}
    for saved in saved_dbs:
        db = saved.get("UADD_DB") if isinstance(saved, dict) else None
        health = db.get("health") if isinstance(db, dict) else None
        if not isinstance(health, dict):
            continue
        g = health.get("guard")
        for kind, n in (g.items() if isinstance(g, dict) else ()):
            if _num(n):
                guard[str(kind)] = guard.get(str(kind), 0) + _num(n)
        gl = health.get("guardLast")
        for kind, rec in (gl.items() if isinstance(gl, dict) else ()):
            rec, old = _last(rec), last.get(str(kind))
            if rec and (old is None or (rec["at"] or 0) >= (old["at"] or 0)):
                last[str(kind)] = rec
        if isinstance(health.get("probe"), dict):
            probes.append(health["probe"])
    return guard, probes, last


def installed_version(addons_dir):
    """The UADD version installed in an AddOns folder (its UADD.toc), or None."""
    try:
        with open(os.path.join(addons_dir, "UADD", "UADD.toc"), encoding="utf-8-sig", errors="replace") as f:
            m = VERSION.search(f.read())
    except (OSError, TypeError):
        return None
    return m.group(1) if m else None


def _when(rec):
    bits = []
    if rec.get("at"):
        bits.append(time.strftime("%Y-%m-%d %H:%M UTC", time.gmtime(rec["at"])))
    if rec.get("version"):
        bits.append("UADD " + rec["version"])
    if rec.get("sample"):
        bits.append("sample: " + rec["sample"])
    return ", ".join(bits)


def report(guard, probes, last=None, current=None):
    """Prints the guard's repairs (loud) and the probe's facts. `current`: the UADD version installed now; a kind
    last seen in another version is printed quietly. Returns the number of repairs that may still happen."""
    last = last or {}
    now, old = {}, {}
    for kind, n in guard.items():
        v = (last.get(kind) or {}).get("version")
        (old if current and v and v != current else now)[kind] = n
    total = sum(now.values())
    if total:
        print("!!! GAME HEALTH: UADD's guard had to repair the game %d times. Fix this first:" % total)
        for kind, n in sorted(now.items(), key=lambda kv: -kv[1]):
            print("  guard %s = %d: %s" % (kind, n, KINDS.get(kind, "a kind this tool does not know")))
            if last.get(kind):
                print("    last: " + _when(last[kind]))
        print("  (UADD/Guard.lua and UADD/BoxGuard.lua name each kind; a 'fail' kind means the repair did not work.)")
    for kind, n in sorted(old.items(), key=lambda kv: -kv[1]):
        print("guard %s = %d, last in UADD %s (installed: %s): may be fixed; last: %s"
              % (kind, n, last[kind]["version"], current, _when(last[kind])))
    for p in probes:
        facts = ", ".join("%s=%s" % (k, p[k]) for k in sorted(p) if k not in ("build", "at"))
        print("font probe (build %s): %s" % (p.get("build", "?"), facts or "no facts"))
    return total
