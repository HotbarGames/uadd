"""UADD_Mastercraft on a stand-in for Mastercraft (tools/harness/mastercraft). The stand-in holds none of
Mastercraft's English: this flow reads its texts from the installed addon (tools/mc_text_lib.py) and gives
them to the stand-in before the game starts. The expected Ukrainian is the module's own data (ns.MC, read
by M.want and M.fill in flow_mastercraft.lua).

  * Game A (English client): Mastercraft stand-in, UADD, UADD_Mastercraft. Font strings made the way
    Mastercraft makes them (mcSetText, mcRaw, mcUpper, mcFitTo), in MastercraftFrame (made at load) and
    MastercraftGoals (made after login, found through the CreateFontString hook). Ours shows where we
    have it, an unknown line stays English; a heading in Ukrainian capitals; a coloured text and one with
    outer spaces keep them; a button label shrinks to fit; fonts read back; a tooltip line from
    Mastercraft's code changes, the same line from other code does not; a chat line with Mastercraft's
    name changes, an unknown one and one without the name do not; the hold key and "/uadd mastercraft
    off" give the English back, key up and "on" give ours again; no half-translated line.
  * Game C (ruRU client): the module does nothing and says why.
"""
import collections
import gc
import os
import re
import sys

import halves_mods
import session
from halves_cover import kinds

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import hashtext  # noqa: E402
import mc_text_lib as L  # noqa: E402
from loader import Addon, Client, lua_str, read_text, txt  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
MODULE = "UADD_Mastercraft"
DATA = os.path.join(session.REPO, MODULE, "data")
UNKNOWN = "Glimmering quixberry pudding"
COLOUR = "|cffffd100"


def module_there():
    return os.path.isfile(os.path.join(session.REPO, MODULE, MODULE + ".toc"))


def addon_dir():
    try:
        import make_mc_text
        return make_mc_text.addon_dir()
    except Exception:                       # mc_rules may be half-edited: the same lookup
        from pathlib import Path
        base = os.environ.get("UADD_ADDONS_DIR") or \
            "/mnt/c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns"
        return Path(base) / "Mastercraft"


def shipped():
    """(exact keys {key: uk}, templates {id: [sort letters]}) parsed from the module's data files."""
    exact, temps = {}, {}
    for name in sorted(os.listdir(DATA)):
        with open(os.path.join(DATA, name), encoding="utf-8") as f:
            for line in re.sub(r'" \.\.\n    "', "", f.read()).splitlines():   # joins make_mc_text's wrap() cuts
                m = re.match(r'E\["([^"]+)"\] = "(.*)"$', line.rstrip("\n"))
                if m:
                    exact[m.group(1)] = m.group(2)
                m = re.match(r'T\[#T \+ 1\] = \{ id = "([^"]+)".*sort = \{([^}]*)\}', line)
                if m:
                    temps[m.group(1)] = re.findall(r'"(\w)"', m.group(2))
    return exact, temps


def rows():
    """Mastercraft's English: [(en, kind)], or [] when it is not installed."""
    d = addon_dir()
    if not os.path.isdir(d):
        return []
    return [(en, kind) for en, kind, _, _, _ in L.source(d)]


def picks(src, exact, temps):
    """Real texts for each path: plain English, single line, whole texts we ship."""
    plain = [en for en, kind in src if kind == "exact" and "|" not in en and hashtext.key(en) in exact]
    plain.sort(key=len)
    short = [e for e in plain if 4 <= len(e) <= 14]
    mid = [e for e in plain if 15 <= len(e) <= 40]
    longer = [e for e in plain if 60 <= len(e) <= 200]
    fit = [e for e in short if len(exact[hashtext.key(e)].encode()) > len(e) + 4]
    tpl = [en for en, kind in src if kind == "template" and hashtext.key(en) in temps
           and set(kinds(en)) == {"d"} and set(temps[hashtext.key(en)]) == {"v"}
           and "|" not in en and len(en) < 80]
    if len(short) < 3 or len(mid) < 5 or not longer or not fit or not tpl:
        return None
    return {"label": short[0], "colour": short[1], "spaces": short[2], "fit": fit[0], "upper": mid[0],
            "long": longer[0], "tip": mid[1], "tip2": mid[2], "tip3": mid[3], "chat": mid[4], "tpl": tpl[0]}


def _feed(M, p):
    tv = tuple(range(3, 3 + len(kinds(p["tpl"]))))
    p["tpl_en"] = p["tpl"] % tv
    p["tpl_vals"] = tuple(str(v) for v in tv)
    load = [("label", p["label"], "", 12, 0), ("colour", COLOUR + p["colour"] + "|r", "", 12, 0),
            ("spaces", "  " + p["spaces"] + " ", "", 12, 0), ("upper", p["upper"], "upper", 14, 0),
            ("fit", p["fit"], "fit", 12, len(p["fit"]) * 6 + 12), ("unknown", UNKNOWN, "", 12, 0)]
    later = [("goals:long", p["long"], "", 12, 0), ("goals:tpl", p["tpl_en"], "", 12, 0),
             ("goals:unknown", UNKNOWN, "", 12, 0)]
    for where, rows_ in (("load", load), ("later", later)):
        for name, text, how, size, width in rows_:
            M.feed(where, name, lua_str(text), how, size, width)


def _game(addons, locale, p=None):
    c = Client(addons, None, locale)
    c.lua.execute(read_text(os.path.join(HERE, "flow_mastercraft.lua")))
    M = c.H.mc
    if p:
        _feed(M, p)
    c.start()
    c.H.pump(60)
    return c, M


def _addon(name):
    return Addon(name, os.path.join(session.REPO, name), session.FLAVOR)


def _stand_in():
    return Addon("Mastercraft", os.path.join(HERE, "mastercraft"), session.FLAVOR)


def _snap(M):
    return {txt(k): txt(v) for k, v in M.snap().items()}


def _errors(c, check, step):
    errs = c.errors()
    check(f"{step}: no Lua errors", not errs, "; ".join(f"{w}: {m[:160]}" for w, m, _ in errs[:3]))


def _diff(a, b):
    names = sorted(n for n in set(a) | set(b) if a.get(n) != b.get(n))
    return len(names), names[:4]


def _want(M, en):
    return txt(M.want(lua_str(hashtext.key(en))) or "")


def game_a(check, facts, p, src, temps):
    c, M = _game([_stand_in(), _addon("UADD"), _addon(MODULE)], "enUS", p)
    check("module on after login", M.loaded() and M.on(), "")
    M.later()
    english = {"label": p["label"], "colour": COLOUR + p["colour"] + "|r", "spaces": "  " + p["spaces"] + " ",
               "upper": p["upper"].upper(), "fit": p["fit"], "unknown": UNKNOWN, "goals:long": p["long"],
               "goals:tpl": p["tpl_en"], "goals:unknown": UNKNOWN}
    want = {"label": _want(M, p["label"]), "colour": COLOUR + _want(M, p["colour"]) + "|r",
            "spaces": "  " + _want(M, p["spaces"]) + " ", "upper": txt(M.upper(M.want(lua_str(
                hashtext.key(p["upper"]))))), "fit": _want(M, p["fit"]), "unknown": UNKNOWN,
            "goals:long": _want(M, p["long"]),
            "goals:tpl": txt(M.fill(lua_str(hashtext.key(p["tpl"])), *map(lua_str, p["tpl_vals"])) or ""),
            "goals:unknown": UNKNOWN}
    on = _snap(M)
    bad = {n: on.get(n) for n in want if on.get(n) != want[n]}
    check(f"our words on {len(want) - 2} font strings, an unknown line English", not bad, list(bad.items())[:3])
    check("font strings found: at load and in the window made later (CreateFontString hook)",
          M.hooked() >= len(want) and on.get("goals:long") == want["goals:long"], (M.hooked(), len(want)))
    good, badf, wrong = M.fonts()
    check(f"fonts: {good} Ukrainian texts in our font, none without, English ones keep Mastercraft's",
          good == len(want) - 2 and badf == 0 and wrong == 0 and M.fontCount() == good,
          (good, badf, wrong, M.fontCount()))
    path, size, cyr, _, mc_size = M.font("fit")
    check("button label shrinks to fit (3/4 of its size at least)", cyr and 9 <= size < mc_size, (size, mc_size))
    facts["words"], facts["fonts"] = int(M.count()), int(M.fontCount())
    # Tooltip: a line from Mastercraft's code, a double line, and the same line from other code.
    left, _, cyr = M.tip(lua_str(p["tip"]))
    check("tooltip line from Mastercraft: ours, in our font", txt(left or "") == _want(M, p["tip"]) and cyr,
          txt(left or ""))
    left, right, _ = M.tip(lua_str(p["tip2"]), lua_str(p["tip3"]))
    check("tooltip double line from Mastercraft: both sides ours",
          (txt(left or ""), txt(right or "")) == (_want(M, p["tip2"]), _want(M, p["tip3"])), txt(left or ""))
    check("the same tooltip line from other code stays as it is", txt(M.tipOther(lua_str(p["tip"]))) == "", "")
    boxes = M.refill(lua_str(p["tip"]))
    check("item tooltip filled again: UALL Forever's Ukrainian on every line draws (lesson 18)", not boxes, boxes)
    # Chat.
    pre = "|cff4da6ffMastercraft|r  "
    got = txt(M.print(lua_str(p["chat"])))
    check("chat line with Mastercraft's name: ours, the name kept", got == pre + _want(M, p["chat"]), got)
    got = txt(M.print(lua_str(UNKNOWN)))
    check("chat line we have no Ukrainian for stays English", got == pre + UNKNOWN, got)
    got = txt(M.say(lua_str(p["chat"])))
    check("chat line without Mastercraft's name stays as it is", got == p["chat"], got)
    # The hold key.
    M.key(True)
    n, names = _diff(_snap(M), english)
    check("hold key down: Mastercraft's English, its own font", n == 0 and M.fontCount() == 0,
          (n, names, M.fontCount()))
    M.key(False)
    n, names = _diff(_snap(M), on)
    check("hold key up: our words and font again", n == 0 and M.fontCount() == good, (n, names))
    # Off and on.
    M.uadd("mastercraft off")
    n, names = _diff(_snap(M), english)
    path, size, _, mc_path, mc_size = M.font("fit")
    check("/uadd mastercraft off: Mastercraft's English, its own font and size",
          n == 0 and M.fontCount() == 0 and txt(path) == txt(mc_path) and size == mc_size, (n, names, size))
    M.uadd("mastercraft on")
    n, names = _diff(_snap(M), on)
    check("/uadd mastercraft on: our words and fonts again", n == 0 and M.fontCount() == good,
          (n, names, M.fontCount()))
    M.uadd("mastercraft")
    check("status: on, with counts", "увімкнено: Mastercraft українською" in txt(M.lastChat(4)), txt(M.lastChat(2)))
    # No half-translated line.
    M.names(lua_str(halves_mods.NAME), lua_str("Квікс"))
    halves_mods.mc(check, M, src, temps)
    _errors(c, check, "game A")


def game_c(check, p):
    c, M = _game([_stand_in(), _addon("UADD"), _addon(MODULE)], "ruRU", p)
    M.uadd("mastercraft")
    snap = _snap(M)
    check("ruRU client: module off, says why, Mastercraft's texts as they are",
          not M.on() and "клієнт не англійський" in txt(M.lastChat(4)) and snap.get("label") == p["label"],
          txt(M.lastChat(2)))
    _errors(c, check, "game C (ruRU)")


def run(check, facts):
    if not module_there():
        check("UADD_Mastercraft is there", False, "no UADD_Mastercraft/UADD_Mastercraft.toc")
        return
    src = rows()
    if not src:
        check("Mastercraft checks (skipped: Mastercraft is not installed)", True, "")
        halves_mods.mc(check, None, None, None)
        return
    exact, temps = shipped()
    p = picks(src, exact, temps)
    check("real texts for each path read from the installed Mastercraft", p, len(src))
    if not p:
        return
    game_a(check, facts, p, src, temps)
    gc.collect()
    import flow_mc_code                     # lines it builds in code: a game of their own
    flow_mc_code.run(check, sys.modules[__name__], src)
    gc.collect()
    import flow_mc_code2                    # the lines of the owner's screenshots (2026-11-20)
    flow_mc_code2.run(check, sys.modules[__name__], src)
    gc.collect()
    game_c(check, p)


Check = collections.namedtuple("Check", "name ok detail")


def run_checks():
    """Every check of this file. Returns (checks, facts)."""
    checks, facts = [], {}

    def check(name, ok, detail=""):
        checks.append(Check("mc: " + name, bool(ok), str(detail)))
    run(check, facts)
    return checks, facts


if __name__ == "__main__":       # alone: python3 tools/harness/flow_mastercraft.py
    cs, fs = run_checks()
    for x in cs:
        print(("ok    " if x.ok else "FAIL  ") + x.name + (f"  [{x.detail}]" if x.detail else ""))
    print(fs)
    print(f"{sum(x.ok for x in cs)}/{len(cs)} passed")
    sys.exit(0 if all(x.ok for x in cs) else 1)
