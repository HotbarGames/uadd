"""The tooltip font check (wow_fontfam.lua, docs/LESSONS2.md lesson 18), counted per run.py segment.

Each Client sends its reports here (loader.Client sets HARNESS.tipReport): "put" (UADD pinned its Cyrillic
font on a line of a game tooltip, by file or as its Cyrillic font object), "back" (UADD gave such a line its font object back), "checked" (a cleared
tooltip had such a line) and "bad" (UADD put the old font back by pinning its file, or the line was still
pinned by UADD after the tooltip was cleared: it lost its font family, so UALL Forever's Ukrainian on it would
show boxes). segment() turns what came in since the last call into one check.
"""
STATE = {"put": 0, "back": 0, "checked": 0, "bad": []}

# The segments whose flows put UADD's font on lines of the game's tooltips: each must put and look back.
# Not here: main (Questie: UALL Forever's tracker), bgn and gm (their flows show no game tooltip line in
# Cyrillic yet); a put there still has to be looked at.
TOUCH = {"dj", "fxpb", "auc", "att", "lsw", "ap", "mc", "wt", "tt", "pawn", "scrap"}


def report(kind, detail=""):
    if kind == "bad":
        if detail not in STATE["bad"]:
            STATE["bad"].append(str(detail))
    elif kind in STATE:
        STATE[kind] += 1


def take():
    got = dict(STATE, bad=list(STATE["bad"]))
    STATE.update(put=0, back=0, checked=0, bad=[])
    return got


def merge(takes):
    """One take() result from several (the parts of one segment that ran in other processes, pool.py)."""
    out = {"put": 0, "back": 0, "checked": 0, "bad": []}
    for got in takes:
        for k in ("put", "back", "checked"):
            out[k] += got[k]
        out["bad"] += [b for b in got["bad"] if b not in out["bad"]]
    return out


def segment(key, check, got=None):
    """[check] for what came in since the last call (or for `got`, a take() result); `check` is flow.Check."""
    got = take() if got is None else got
    name = f"tooltip font object back after clear: {key}"
    counts = f"put {got['put']}, back {got['back']}, checked {got['checked']}"
    if got["bad"]:
        return [check(name, False, "; ".join(got["bad"][:3]) + f" ({len(got['bad'])} lines)")]
    if key in TOUCH and not got["put"]:
        return [check(name, False, f"no font put on a game tooltip line ({counts})")]
    if got["put"] and not (got["back"] or got["checked"]):
        return [check(name, False, f"nothing looked at ({counts})")]
    if not got["put"] and not got["checked"]:
        return []
    return [check(name, True, counts)]
