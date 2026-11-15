"""UADD_ForeverXP Bar on a stand-in for ForeverXP Bar (tools/harness/foreverxpbar: named frames, bar
ticks in FRIZQT and its own Latin-only font, ARIALN labels, a nameless Settings page, a minimap tooltip,
printMsg lines, what it sends, an edit box and a tooltip it reads back). A small test seed
(flow_fxpb.lua) covers what data/words.lua leaves English; fxpb_words.overlay hashes it over the data.

  * Game A (English client): exact texts, templates (%s/%d, nested, a blanked plural slot; times,
    Completed/Rested and glued texts in flow_fxpb_words.py), a Cyrillic font at the same size and
    flags, cheap bar ticks, chat lines, its minimap tooltip only, sent/read-back texts stay English,
    the hold key, nameless frames (Settings page, feature guide, drop-down list; not another addon's
    dialog), its StaticPopup, hints and no half-translated line (flow_fxpb_mixed.py), font put back
    on a text with no words of ours, combat (no search), "/uadd fxpb off" and "on" again; no Lua errors.
  * Game B: no ForeverXP Bar (the module stays idle). Run by run.py.
"""
import collections
import gc
import os
import sys

import flow_fxpb_mixed
import flow_fxpb_words
import session

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import fxpb_words  # noqa: E402
import glossary  # noqa: E402
from flow_fxpb_words import BOTH_EN, BOTH_UK, CAMP_EN, CAMP_UK
from loader import Addon, Client, lua_str, read_text, txt

HERE = os.path.dirname(os.path.abspath(__file__))
STAND_IN = Addon("ForeverXPbar", os.path.join(HERE, "foreverxpbar"), session.FLAVOR)
MODULE = "UADD_ForeverXPBar"
HELD = 0.4          # the hold key counts after 0.25 s
TICKS = 1000
TICK_BUDGET_MS = 0.25   # per bar update with the module on, in the harness's Lua
FRIZ = "Fonts\\FRIZQT__.TTF"


def module_there():
    return os.path.isfile(os.path.join(session.REPO, MODULE, MODULE + ".toc"))


def _addon(name):
    return Addon(name, os.path.join(session.REPO, name), session.FLAVOR)


def _game(addons, locale="enUS"):
    c = Client(addons, None, locale)
    c.lua.execute(read_text(os.path.join(HERE, "flow_fxpb.lua")))
    c.start()
    c.H.pump(60)
    return c, c.H.fxpb


def _errors(c, check, step):
    errs = c.errors()
    check(f"{step}: no Lua errors", not errs, "; ".join(f"{w}: {m[:160]}" for w, m, _ in errs[:3]))


def want(M, i, mode):
    """What the bar should show after tick i (from flow_fxpb.lua), as real text."""
    return tuple(txt(x) for x in M.want(i, mode))


def _eq(check, name, got, want):
    got = txt(got)
    check(name, got == want, f"{got!r} | want {want!r}")


def _seed(c, M):
    """The seed built into the module; (count, expected Ukrainian by English)."""
    with open(os.path.join(session.REPO, MODULE, "data", "words.lua"), encoding="utf-8") as f:
        src, S = fxpb_words.overlay({txt(k): txt(v) for k, v in M.SEED.items()}, f.read(), glossary.Glossary())
    for en, uk in S.items():
        M.SEED[lua_str(en)] = lua_str(uk)
    return M.seed(lua_str(src)), S


def game_a(check, facts):
    c, M = _game([STAND_IN, _addon("UADD"), _addon(MODULE)])
    n, S = _seed(c, M)
    Cyr = c.lua.globals().UADD.IsCyrFont
    check("seed built", n >= len(S), f"{n} texts, {len(S)} checked")
    # Exact texts, templates, fonts.
    _eq(check, "exact text (bar label)", M.text("lock"), S["Lock Bar"])
    _eq(check, "template %s (time this level)", M.uk(lua_str("Time this level: 1h 2m")), S["Time this level: %s"] % "1 год 2 хв")
    _eq(check, "template %d and %s (race created)", M.text("raceInfo"),
        S["Race created: %s | Code: %s. Share the code with friends."] % ("Speed", "AB12"))
    rate, left = want(M, 1, "uk")
    _eq(check, "template inside a template (leveling in)", M.text("underLeft"), left)
    _eq(check, "#476: '+%d level%s' -> no English 's'", M.uk(lua_str("+3 levels since you started")), "+3 рів. від початку")
    _eq(check, "#476: singular too", M.uk(lua_str("+1 level since you started")), "+1 рів. від початку")
    flow_fxpb_mixed.checks(check, _eq, M, S)   # hints; never a half-translated line
    p, size, flags = M.font("underLeft")
    check("own Latin font -> Cyrillic font, size and flags kept", Cyr(p) and size == 14 and flags == "", f"{p} {size} {flags!r}")
    p = M.font("lock")[0]
    check("ARIALN label keeps its own font", txt(p) == "Fonts\\ARIALN.TTF", p)
    check("guard (no Ukrainian in a font without Ukrainian letters)", not session.cyr_boxes(c), session.cyr_boxes(c)[:3])
    check("number-only text left alone and not kept", txt(M.text("right")).startswith("37 / 100000") and M.uk("1,234 / 5,000") is None, M.text("right"))
    flow_fxpb_words.checks(check, _eq, M, S, Cyr)   # times, Completed/Rested, a glued footer
    # The bar's ticks: right words every time, cheap.
    memo0, calls0 = M.memo(), M.hookCalls()
    ms_on = M.ticks(TICKS, 2)
    want_rate, want_left = want(M, TICKS + 1, "uk")
    _eq(check, f"after {TICKS} ticks: rate text right", M.text("rate"), want_rate)
    _eq(check, f"after {TICKS} ticks: leveling text right", M.text("underLeft"), want_left)
    check("ticks: memo stays bounded", M.memo() <= 3000, M.memo())
    calls = M.hookCalls() - calls0
    check("ticks: one hook call per SetText", calls == 3 * TICKS, f"{calls} for {3 * TICKS}")
    check(f"ticks: under {TICK_BUDGET_MS} ms per bar update", ms_on / TICKS < TICK_BUDGET_MS, f"{ms_on / TICKS:.4f} ms")
    facts["tick_ms_on"] = round(ms_on / TICKS, 4)
    facts["memo"] = M.memo() - memo0
    M.setText("rate", lua_str("Some other text"))
    check("a text with no words of ours gets its own font back", txt(M.font("rate")[0]) == FRIZ, M.font("rate"))
    M.tick(TICKS + 1)
    check("... and ours again with our words", Cyr(M.font("rate")[0]), M.font("rate"))
    # Chat.
    M.print(lua_str("position and size reset."))
    _eq(check, "chat line with its prefix translated", M.lastChat(), "|cff8ee6deForeverXP Bar|r " + S["position and size reset."])
    M.print(lua_str("Some other line."))
    _eq(check, "unknown chat line stays", M.lastChat(), "|cff8ee6deForeverXP Bar|r Some other line.")
    # What it sends and reads back.
    msg, line = M.send()
    _eq(check, "addon message sent in English", M.sent(1)[1], "LVL:12:Lock Bar")
    _eq(check, "chat line sent in English", M.sent(2)[1], "[FXPB] ForeverXP Bar - Level 12")
    _eq(check, "a [FXPB] chat line read back stays English", M.lastChat(), "[FXPB] ForeverXP Bar - Level 12")
    box, scan = M.readBack()
    check("edit box and scanning tooltip read back English", txt(box) == "Lock Bar" and txt(scan) == "Lock Bar", f"{box!r} {scan!r}")
    # Tooltip.
    M.hover()
    _eq(check, "tooltip: title template", M.tipLine(1), S["ForeverXP Bar - Level %s"] % "12")
    _eq(check, "tooltip: line", M.tipLine(2), S["Left-click: settings"])
    _eq(check, "tooltip: double line left", M.tipLine(3), S["Kills to level"])
    check("tooltip: Cyrillic font on its lines", c.lua.globals().UADD.IsCyrFont(M.tipFont(2)), M.tipFont(2))
    M.leave()
    check("tooltip: font back when hidden", txt(M.tipFont(2)) == "Fonts\\FRIZQT__.TTF", M.tipFont(2))
    M.hoverOther()
    _eq(check, "tooltip of another frame untouched", M.tipLine(1), "Left-click: settings")
    M.leave()
    # Windows: options, a tab shown later, the nameless Settings page.
    M.options(True)
    _eq(check, "options window label", M.text("options"), S["Options"])
    M.tab(True)
    M.wait(1.2)
    _eq(check, "tab shown later picked up", M.text("leveling"), S["Leveling info"])
    check("nameless Settings page found", M.extras() >= 1, M.extras())
    check("the Settings page made at PLAYER_ENTERING_WORLD found", M.isExtra("pageDesc"), M.extras())
    check("feature guide found (a long text of its own)", M.isExtra("guideOk"), M.extras())
    check("a drop-down's list with short words found (anchored inside its window)", M.isExtra("popRow"), M.extras())
    check("another addon's dialog with a short word of its own not taken", not M.isExtra("otherText"), M.extras())
    for what, name, en in (("guide", "guideOk", "I understand"), ("pop", "popRow", "Lock Bar"),
                           ("page2", "pageDesc", "Optional challenges, races, leaderboards, level-up cards and Played records.")):
        M.show(what, True)
        M.wait(0.1)
        _eq(check, f"{what} text", M.text(name), S[en])
        M.show(what, False)
    check("Settings page 2 text in our font", Cyr(M.font("pageDesc")[0]), M.font("pageDesc"))
    M.show("other", True)
    M.wait(1.2)
    _eq(check, "another addon's dialog untouched", M.text("otherText"), "Options")
    M.show("other", False)
    M.page(True)
    M.wait(0.1)
    _eq(check, "Settings page text", M.text("pageFlight"), S["Flight travel"])
    M.page(False)
    M.record(True)
    _eq(check, "record window on show", M.text("record"), S["ForeverXP Bar - Record"])
    _eq(check, "#476 on screen", M.text("since"), "+3 рів. від початку")
    # The hold key: shown texts only, a hidden window put right when it shows.
    M.record(False)
    M.hover()
    M.key(True)
    M.wait(HELD)
    _eq(check, "Shift: bar text English", M.text("underLeft"), want(M, TICKS + 1, "en")[1])
    _eq(check, "Shift: label English", M.text("lock"), "Lock Bar")
    _eq(check, "Shift: Completed and Rested English", M.text("underRight"), BOTH_EN)
    _eq(check, "Shift: camp countdown English", M.text("camp"), CAMP_EN)
    check("Shift: original font back", txt(M.font("underLeft")[0]) == "Interface\\AddOns\\ForeverXPbar\\Fonts\\BigNoodleToo.ttf", M.font("underLeft"))
    _eq(check, "Shift: tooltip English", M.tipLine(2), "Left-click: settings")
    _eq(check, "Shift: hidden window not redrawn", M.text("record"), S["ForeverXP Bar - Record"])
    check("Shift: hidden text marked", M.stale("record"), "")
    M.tick(TICKS + 1)
    _eq(check, "Shift: a tick stays English", M.text("underLeft"), want(M, TICKS + 1, "en")[1])
    M.record(True)
    _eq(check, "Shift: hidden window English when shown", M.text("record"), "ForeverXP Bar - Record")
    _eq(check, "Shift: #476 exact English", M.text("since"), "+3 levels since you started")
    M.key(False)
    M.wait(0.1)
    _eq(check, "Shift up: Ukrainian again", M.text("record"), S["ForeverXP Bar - Record"])
    _eq(check, "Shift up: bar Ukrainian again", M.text("underLeft"), want(M, TICKS + 1, "uk")[1])
    _eq(check, "Shift up: Completed and Rested Ukrainian again", M.text("underRight"), BOTH_UK)
    _eq(check, "Shift up: camp countdown Ukrainian again", M.text("camp"), CAMP_UK)
    _eq(check, "Shift up: tooltip Ukrainian again", M.tipLine(2), S["Left-click: settings"])
    M.leave()
    # Its StaticPopup question: our words, the hold key, hidden.
    REL = "ForeverXP Bar: the minimap icon setting changed.\n\nReload the UI now to apply and save it?"
    M.askReload()
    t, f = M.popup("text")
    _eq(check, "popup: question", t, S[REL])
    check("popup: Cyrillic font", Cyr(f), f)
    _eq(check, "popup: buttons", M.popup("button1")[0] + "|" + M.popup("button2")[0], S["Reload UI"] + "|" + S["Later"])
    h, want_h = M.popup("height")
    check("popup: height follows the text", h == want_h, f"{h} {want_h}")
    M.key(True)
    M.wait(HELD)
    _eq(check, "Shift: popup English", M.popup("text")[0], REL)
    _eq(check, "Shift: popup button English", M.popup("button1")[0], "Reload UI")
    check("Shift: popup font back", txt(M.popup("text")[1]) == FRIZ, M.popup("text")[1])
    M.key(False)
    M.wait(0.1)
    _eq(check, "Shift up: popup Ukrainian", M.popup("text")[0], S[REL])
    M.popupHide()
    _eq(check, "popup hidden: English", M.popup("text")[0], REL)
    check("popup hidden: font back", txt(M.popup("text")[1]) == FRIZ, M.popup("text")[1])
    down, up = M.perf()
    facts["shift_ms"] = {"down": round(down or -1, 3), "up": round(up or -1, 3)}
    check("/uadd perf has ForeverXP Bar", down is not None and up is not None, f"{down} {up}")
    # Combat: known texts stay ours (memo, exact, hint: no search), the rest after it.
    M.combat(True)
    memo0 = M.memo()
    M.tick(5001)
    _eq(check, "combat: new numbers in a known template stay Ukrainian", M.text("rate"), want(M, 5001, "uk")[0])
    M.tick(5000)
    _eq(check, "combat: an exact text stays Ukrainian", M.text("rate"), want(M, 5000, "uk")[0])
    _eq(check, "combat: a template inside a template stays Ukrainian", M.text("underLeft"), want(M, 5000, "uk")[1])
    check("combat: no search (memo unchanged)", M.memo() == memo0, f"{memo0} -> {M.memo()}")
    check("combat: Cyrillic font kept", Cyr(M.font("underLeft")[0]), M.font("underLeft"))
    M.askReload()
    _eq(check, "combat: popup left alone", M.popup("text")[0], REL)
    M.popupHide()
    M.combat(False)
    M.wait(0.1)
    _eq(check, "after combat: Ukrainian", M.text("underLeft"), want(M, 5000, "uk")[1])
    # Off: exact English and fonts; on again.
    M.askReload()
    M.uadd("fxpb off")
    _eq(check, "off: popup exact English", M.popup("text")[0], REL)
    check("off: popup font back", txt(M.popup("text")[1]) == FRIZ, M.popup("text")[1])
    M.popupHide()
    _eq(check, "off: own justify kept after its font object is back", M.justify("pageDesc"), "LEFT")
    check("off: font object's font back", txt(M.font("pageDesc")[0]) == FRIZ, M.font("pageDesc"))
    _eq(check, "off: bar text exact English", M.text("underLeft"), want(M, 5000, "en")[1])
    _eq(check, "off: label exact English", M.text("lock"), "Lock Bar")
    _eq(check, "off: Completed and Rested exact English", M.text("underRight"), BOTH_EN)
    _eq(check, "off: camp countdown exact English", M.text("camp"), CAMP_EN)
    own = "Interface\\AddOns\\ForeverXPbar\\Fonts\\BigNoodleToo.ttf"
    check("off: their own font exact", [(txt(p), s, txt(fl)) for p, s, fl in (M.font("underRight"), M.font("camp"))]
          == [(own, 12, ""), (own, 10, "OUTLINE")], f"{M.font('underRight')} {M.font('camp')}")
    _eq(check, "off: #476 exact English", M.text("since"), "+3 levels since you started")
    p, size, flags = M.font("underLeft")
    check("off: exact font (file, size, flags)", (txt(p), size, txt(flags)) == ("Interface\\AddOns\\ForeverXPbar\\Fonts\\BigNoodleToo.ttf", 14, ""), f"{p} {size} {flags!r}")
    check("off: no font of ours left", M.fontCount() == 0, M.fontCount())
    check("off: chat AddMessage put back", M.chatPutBack(), "")
    M.tick(5001)
    _eq(check, "off: a tick stays English", M.text("underLeft"), want(M, 5001, "en")[1])
    M.uadd("fxpb on")
    M.tick(5002)
    _eq(check, "on again: tick Ukrainian", M.text("underLeft"), want(M, 5002, "uk")[1])
    _eq(check, "on again: label Ukrainian", M.text("lock"), S["Lock Bar"])
    check("on again: guard", not session.cyr_boxes(c), session.cyr_boxes(c)[:3])
    _errors(c, check, "game A")


def game_b(check):
    c, M = _game([_addon("UADD"), _addon(MODULE)])
    out = txt(M.uadd("fxpb") or "")
    _errors(c, check, "game B (no ForeverXP Bar)")
    check("game B: module waits", "ForeverXP Bar" in " ".join(txt(x) for x in list(c.H.chat.values())[-3:]), out)


def run(check, facts):
    if not module_there():
        check("UADD_ForeverXPBar is there", False, "no UADD_ForeverXPBar/UADD_ForeverXPBar.toc")
        return
    for g in (lambda: game_a(check, facts), lambda: game_b(check)):
        g()
        gc.collect()


Check = collections.namedtuple("Check", "name ok detail")


def run_checks():
    """Every check of this file. Returns (checks, facts)."""
    checks, facts = [], {}

    def check(name, ok, detail=""):
        checks.append(Check("fxpb: " + name, bool(ok), str(detail)))
    run(check, facts)
    return checks, facts


if __name__ == "__main__":       # alone: python3 tools/harness/flow_fxpb.py
    cs, fs = run_checks()
    for x in cs:
        print(("ok    " if x.ok else "FAIL  ") + x.name + (f"  [{x.detail}]" if x.detail else ""))
    print(fs)
    print(f"{sum(x.ok for x in cs)}/{len(cs)} passed")
    sys.exit(0 if all(x.ok for x in cs) else 1)
