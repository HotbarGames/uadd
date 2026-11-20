"""UADD_WhatsTraining on a stand-in for What's Training? (tools/harness/whatstraining). The stand-in holds
none of What's Training?'s English: this flow reads its texts from the installed addon
(flow_whatstraining_texts.py) and gives them to the stand-in before the game starts. The expected
Ukrainian is the module's own data (ns.WT, read by M.want and M.fill in flow_whatstraining.lua). The
data may be partial (translators at work): texts are picked from what is shipped, and the checks that
need our Ukrainian are skipped with a note when none is.

  * Game A (English client): What's Training? stand-in, UADD, UADD_WhatsTraining. Font strings in
    WhatsTrainingFrame (made at load, under WhatsTrainingOverlay), an unnamed button's label set through
    the button, and WhatsTrainingSettings (made after login, found through the CreateFontString hook).
    Ours shows where we have it, an unknown line stays English; a coloured text and one with outer
    spaces keep them; a text set again later changes too; fonts read back; another addon's frame with
    the same texts and the Broker text stay English. Its own tooltip and its game tooltip lines change,
    the same game tooltip line from other code does not; its chat line changes, an unknown one and
    one from other code do not. No Cyrillic font: no Ukrainian anywhere, English back. The hold key
    and "/uadd whatstraining off" give the English back, key up and "on" give ours again. Speed and
    garbage of the miss paths; no half-translated line. The main window made late, on first open
    (WhatsTrainingFloatingFrame, a template title): ours after the next tick, also shown again.
  * Game C (ruRU client): the module does nothing and says why.
"""
import collections
import gc
import os
import sys

import halves_mods
import session
from flow_whatstraining_texts import MODULE, ROLES, module_there, picks, rows, shipped, templates, title
from halves_cover import kinds

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import hashtext  # noqa: E402
from loader import Addon, Client, lua_str, read_text, txt  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
UNKNOWN = "Glimmering quixberry pudding"
COLOUR = "|cffffd100"
BROKER = "7 available"          # made up: the Broker text is shown by another addon, left English
SPEED_N = 10000
SPEED_MS = 150         # 3 x SPEED_N misses (a text, a chat line, a shown font string)
SPEED_KB = 4           # garbage they may make in all


def _feed(M, p):
    load = [("label", p["label"], ""), ("colour", COLOUR + p["colour"] + "|r", ""),
            ("spaces", "  " + p["spaces"] + " ", ""), ("long", p["long"], ""), ("button", p["button"], "button"),
            ("unknown", UNKNOWN, "")]
    later = [("later", p["later"], ""), ("later:unknown", UNKNOWN, "")]
    if p["tpl"]:
        tv = tuple(range(3, 3 + len(kinds(p["tpl"]))))
        p["tpl_en"], p["tpl_vals"] = p["tpl"] % tv, tuple(str(v) for v in tv)
        later.append(("later:tpl", p["tpl_en"], ""))
    for where, rows_ in (("load", load), ("later", later)):
        for name, text, how in rows_:
            M.feed(where, name, lua_str(text), how, 12)
    M.broker(lua_str(BROKER))
    M.feedTitle(lua_str(p["title"]))


def _game(addons, locale, p=None):
    c = Client(addons, None, locale)
    c.lua.execute(read_text(os.path.join(HERE, "flow_whatstraining.lua")))
    M = c.H.wt
    if p:
        _feed(M, p)
    c.start()
    c.H.pump(60)
    return c, M


def _addon(name):
    return Addon(name, os.path.join(session.REPO, name), session.FLAVOR)


def _stand_in():
    return Addon("WhatsTraining", os.path.join(HERE, "whatstraining"), session.FLAVOR)


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


def _english(p):
    out = {"label": p["label"], "colour": COLOUR + p["colour"] + "|r", "spaces": "  " + p["spaces"] + " ",
           "long": p["long"], "button": p["button"], "unknown": UNKNOWN, "later": p["later"],
           "later:unknown": UNKNOWN, "broker:text": BROKER, "other:broker": BROKER}
    if p["tpl"]:
        out["later:tpl"] = p["tpl_en"]
    for k in ("label", "colour", "spaces", "long", "button", "unknown"):
        out["other:" + k] = out[k]
    return out


def _wanted(M, p):
    out = _english(p)
    out.update({"label": _want(M, p["label"]), "colour": COLOUR + _want(M, p["colour"]) + "|r",
                "spaces": "  " + _want(M, p["spaces"]) + " ", "long": _want(M, p["long"]),
                "button": _want(M, p["button"]), "later": _want(M, p["later"])})
    if p["tpl"]:
        out["later:tpl"] = txt(M.fill(lua_str(hashtext.key(p["tpl"])), *map(lua_str, p["tpl_vals"])) or "")
    return out


def _screen(check, M, p):
    english, want = _english(p), _wanted(M, p)
    ours = sum(1 for k in want if want[k] != english[k])
    on = _snap(M)
    bad = {n: on.get(n) for n in want if on.get(n) != want[n]}
    check(f"our words on {ours} font strings; unknown lines, another addon's frame and the Broker text "
          "English", not bad, list(bad.items())[:3])
    check("font strings found: at load, the button label, and in the window made later (CreateFontString hook)",
          M.hooked() >= ours + 2 and on.get("later") == want["later"] and on.get("button") == want["button"],
          (M.hooked(), ours))
    good, badf, wrong = M.fonts()
    check(f"fonts: {good} Ukrainian texts in our font, none without, English ones keep their own",
          good == ours and badf == 0 and wrong == 0 and M.fontCount() == good, (good, badf, wrong, M.fontCount()))
    M.set("later", lua_str(p["later2"]))
    M.label(lua_str(p["button2"]))
    got = _snap(M)
    check("a text set again (font string, button label): ours again",
          (got["later"], got["button"]) == (_want(M, p["later2"]), _want(M, p["button2"])),
          (got["later"], got["button"]))
    M.set("later", lua_str(p["later"]))
    M.label(lua_str(p["button"]))
    return english, _snap(M), good


def _lines(check, M, p):
    left, _, cyr = M.tip(lua_str(p["tip"]))
    check("game tooltip line from What's Training?: ours, in our font",
          txt(left or "") == _want(M, p["tip"]) and cyr, txt(left or ""))
    left, right, _ = M.tip(lua_str(p["tip2"]), lua_str(p["tip3"]))
    check("game tooltip double line from What's Training?: both sides ours",
          (txt(left or ""), txt(right or "")) == (_want(M, p["tip2"]), _want(M, p["tip3"])), txt(left or ""))
    check("the same game tooltip line from other code stays as it is", txt(M.tipOther(lua_str(p["tip"]))) == "", "")
    left, _, cyr = M.ownTip(lua_str(p["own"]))
    check("its own tooltip: ours, in our font", txt(left or "") == _want(M, p["own"]) and cyr, txt(left or ""))
    left, right, _ = M.ownTip(lua_str(p["own2"]), lua_str(UNKNOWN))
    check("its own tooltip, double line: ours on the left, an unknown right side English",
          (txt(left or ""), txt(right or "")) == (_want(M, p["own2"]), UNKNOWN), (txt(left or ""), txt(right or "")))
    got = txt(M.print(lua_str(p["chat"])))
    check("chat line from What's Training?: ours", got == _want(M, p["chat"]), got)
    got = txt(M.print(lua_str(UNKNOWN)))
    check("chat line we have no Ukrainian for stays English", got == UNKNOWN, got)
    got = txt(M.say(lua_str(p["chat"])))
    check("the same chat line from other code stays as it is", got == p["chat"], got)


def _back(check, M, p, english, on, good):
    M.nofont(True)
    n, names = _diff(_snap(M), english)
    left, _, _ = M.ownTip(lua_str(p["own"]))
    check("no Cyrillic font: no Ukrainian anywhere, What's Training?'s English",
          n == 0 and M.anyCyr() == 0 and M.fontCount() == 0 and txt(left or "") == p["own"],
          (n, names, M.anyCyr(), txt(left or "")))
    M.nofont(False)
    n, names = _diff(_snap(M), on)
    check("Cyrillic font again: our words again", n == 0 and M.fontCount() == good, (n, names))
    M.key(True)
    n, names = _diff(_snap(M), english)
    left, _, _ = M.ownTip(lua_str(p["own"]))
    check("hold key down: What's Training?'s English, its own font, tooltip lines English",
          n == 0 and M.fontCount() == 0 and txt(left or "") == p["own"], (n, names, M.fontCount()))
    M.key(False)
    n, names = _diff(_snap(M), on)
    check("hold key up: our words and font again", n == 0 and M.fontCount() == good, (n, names))
    M.uadd("whatstraining off")
    n, names = _diff(_snap(M), english)
    got = txt(M.print(lua_str(p["chat"])))
    check("/uadd whatstraining off: What's Training?'s English and fonts, chat English",
          n == 0 and M.fontCount() == 0 and M.fonts()[2] == 0 and got == p["chat"], (n, names, got))
    M.uadd("whatstraining on")
    n, names = _diff(_snap(M), on)
    check("/uadd whatstraining on: our words and fonts again", n == 0 and M.fontCount() == good,
          (n, names, M.fontCount()))


def _late(check, M, p):
    """The main window made on first open, after the module's login scan (Forever's
    WhatsTrainingFloatingFrame: a template title no CreateFontString made)."""
    want = _want(M, p["title"])
    M.open()
    M.wait(0.1)                         # the C_Timer tick: the queued CreateFontString work
    text, cyr = M.title()
    first = (txt(text), bool(cyr))
    text, cyr = M.reshow(lua_str(p["title"]))
    again = (txt(text), bool(cyr))
    check("late window: title Ukrainian after the next tick (and after hide, show, the English set again)",
          first == (want, True) and again == (want, True), (first, again))


def game_a(check, facts, p, src, temps):
    c, M = _game([_stand_in(), _addon("UADD"), _addon(MODULE)], "enUS", p)
    check("module on after login", M.loaded() and M.on(), "")
    M.later()
    if p["n"]:
        english, on, good = _screen(check, M, p)
        facts["words"], facts["fonts"], facts["picked_from"] = int(M.count()), int(M.fontCount()), p["n"]
        _lines(check, M, p)
        _back(check, M, p, english, on, good)
        _late(check, M, p)
    ms, kb = M.speed(SPEED_N, "unknown")
    facts["speed_ms"], facts["garbage_kb"] = round(ms, 2), round(kb, 2)
    check(f"speed: {3 * SPEED_N} misses under {SPEED_MS} ms, under {SPEED_KB} KB garbage",
          ms < SPEED_MS and kb < SPEED_KB, f"{ms:.1f} ms, {kb:.1f} KB")
    M.uadd("whatstraining")
    check("status: on, with counts", "увімкнено: What's Training? українською" in txt(M.lastChat(4)),
          txt(M.lastChat(2)))
    M.names(lua_str(halves_mods.NAME), lua_str("Квікс"))
    tps = templates(src, temps)
    halves_mods.wt(check, M, tps, "" if tps else "skipped: no Ukrainian templates shipped yet")
    _errors(c, check, "game A")


def game_c(check, p):
    c, M = _game([_stand_in(), _addon("UADD"), _addon(MODULE)], "ruRU", p)
    M.uadd("whatstraining")
    snap = _snap(M)
    check("ruRU client: module off, says why, What's Training?'s texts as they are",
          not M.on() and "клієнт не англійський" in txt(M.lastChat(4)) and snap.get("label") == p["label"],
          txt(M.lastChat(2)))
    _errors(c, check, "game C (ruRU)")


def run(check, facts):
    if not module_there():
        check("UADD_WhatsTraining is there", False, "no UADD_WhatsTraining/UADD_WhatsTraining.toc")
        return
    src = rows()
    if not src:
        check("What's Training? checks (skipped: What's Training? is not installed)", True, "")
        halves_mods.wt(check, None, [], halves_mods.SKIP)
        return
    exact, temps = shipped()
    p = picks(src, exact, temps)
    if not p:                       # nothing shipped yet: the checks that need no Ukrainian
        check("our-words checks (skipped: no Ukrainian shipped yet)", True, len(src))
        p = {role: UNKNOWN for role in ROLES}
        p.update(tpl=None, n=0, title=UNKNOWN)
    else:
        check(f"real texts for each path read from the installed What's Training? ({p['n']} shipped)", True, "")
        p["title"] = title(exact) or p["label"]
    game_a(check, facts, p, src, temps)
    gc.collect()
    game_c(check, p)
    gc.collect()
    import flow_whatstraining_names     # game names from UALL Forever, and the foreign-frame leave (5b)
    flow_whatstraining_names.run(check, facts)


Check = collections.namedtuple("Check", "name ok detail")


def run_checks():
    """Every check of this file. Returns (checks, facts)."""
    checks, facts = [], {}

    def check(name, ok, detail=""):
        checks.append(Check("wt: " + name, bool(ok), str(detail)))
    run(check, facts)
    return checks, facts


if __name__ == "__main__":       # alone: python3 tools/harness/flow_whatstraining.py
    cs, fs = run_checks()
    for x in cs:
        print(("ok    " if x.ok else "FAIL  ") + x.name + (f"  [{x.detail}]" if x.detail else ""))
    print(fs)
    print(f"{sum(x.ok for x in cs)}/{len(cs)} passed")
    sys.exit(0 if all(x.ok for x in cs) else 1)
