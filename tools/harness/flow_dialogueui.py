"""UADD_DialogueUI on a stand-in for DialogueUI (tools/harness/dialogueui: its three global frames,
pooled option buttons, settings rows, a nameless tooltip, the book window and chat lines, all in
DialogueUI's own font without Ukrainian letters). Run by run.py after the other flows.

  * Game A (stand-in, UADD, the module; English client): our words and a Cyrillic font on every
    DialogueUI text, format values kept, upper-case option names, a joined description, key
    pictures, game text and read-back lines left alone (the stand-in's item-level parse still
    works), chat lines, the guard; pooled buttons set again on new events; the font size setting
    (FontUtil) then the window again; the hold key; combat (nothing changes, then a catch-up);
    "/uadd dialogueui off" (exact English, exact fonts, hooks idle) and "on" again; no Lua errors.
  * Game B: DialogueUI loaded after UADD. Game C: no DialogueUI (idle). Game D: a Russian client
    (the module steps aside).
The Lua helpers are in flow_dialogueui.lua.
"""
import collections
import gc
import os
import sys

import session
from loader import Addon, Client, lua_str, read_text, txt

HERE = os.path.dirname(os.path.abspath(__file__))
STAND_IN = Addon("DialogueUI", os.path.join(HERE, "dialogueui"), session.FLAVOR)
MODULE = "UADD_DialogueUI"
WAIT = 0.8          # the module looks at most every 0.2 s and ticks every 0.5 s
HELD = 0.4          # the hold key counts after 0.25 s


def module_there():
    return os.path.isfile(os.path.join(session.REPO, MODULE, MODULE + ".toc"))


def _uadd():
    return Addon("UADD", os.path.join(session.REPO, "UADD"), session.FLAVOR)


def _module():
    return Addon(MODULE, os.path.join(session.REPO, MODULE), session.FLAVOR)


def _game(addons, locale="enUS"):
    c = Client(addons, None, locale)
    c.lua.execute(read_text(os.path.join(HERE, "flow_dialogueui.lua")))
    c.start()
    c.H.pump(60)
    return c, c.H.dui


def _list(c, t):
    return [txt(x) for x in c.lines(t)]


def _errors(c, check, step):
    errs = c.errors()
    check(f"{step}: no Lua errors", not errs, "; ".join(f"{w}: {m[:160]}" for w, m, _ in errs[:3]))


def _all_uk(c, M, check, step):
    bad, n = M.compare("uk")
    bad = _list(c, bad)
    check(f"{step}: every shown DialogueUI word in Ukrainian", not bad and n > 0, f"{n} looked at; " + "; ".join(bad[:3]))
    fonts = _list(c, M.fontsCyr())
    check(f"{step}: Ukrainian in a Cyrillic font, size and flags kept", not fonts, "; ".join(fonts[:3]))
    boxes = session.cyr_boxes(c)
    check(f"{step}: guard (no Ukrainian in a font without Ukrainian letters)", not boxes, boxes[:3])


def _all_en(c, M, check, step, fonts=True):
    bad, n = M.compare("en")
    bad = _list(c, bad)
    check(f"{step}: every shown text exactly DialogueUI's English", not bad and n > 0, f"{n} looked at; " + "; ".join(bad[:3]))
    if fonts:
        f = _list(c, M.fontsOriginal())
        check(f"{step}: every font exactly DialogueUI's (object, file, size, flags)", not f, "; ".join(f[:3]))


def _is(M, check, name, step, what):
    got, want = txt(M.text(name)), txt(M.want(name, "uk"))
    check(f"{step}: {what}", got == want, f"{got!r} | want {want!r}")
    return got or ""


def _body(c, M, check, facts):
    """Quest text: the game's prose on DialogueUI's pooled FontStrings (ContentFrame) stays as it is."""
    check("body: quest text found by DialogueUI's ContentFrame", M.isBody("body1") and not M.isBody("questType"))
    for name, what in (("body1", "a sentence ending ' completed.' left as the game's"),
                       ("body2", "'Title: ...' prose left as the game's")):
        got, en = txt(M.text(name)), txt(M.want(name, "en"))
        check(f"body: {what}", got == en, got)
    _is(M, check, "bodyHeader", "body", "a sub-header (one short L value) in Ukrainian")
    _is(M, check, "bodySuggested", "body", "the suggested-players format (a %d) in Ukrainian")
    long = "Long ago the shamans sealed the fire. Now the last step of the ritual is completed."
    check("words: a %s value with '. ' in it is prose (no match)", M.words(long, False) is None, txt(M.words(long, False)))
    check("words: a %s value over 60 letters (no match)", M.words("Kill " + "the wolves " * 6 + "completed.", False) is None)
    named = txt(M.words("Wanted: Hogger completed.", False)) or ""
    check("words: a name in %s still matches", named.startswith("Wanted: Hogger") and named != "Wanted: Hogger completed.",
          named)
    check("words: on a quest page a %s format never matches", M.words("Wanted: Hogger completed.", True) is None)
    facts["dialogueui_dupe_keys"] = int(M.dupes())
    n, bad = M.shapes()
    check("words: Lua's hashes of a game global = make_dui_data.py's", int(n or 0) > 0 and not bad, f"{n} looked at; {bad}")


def game_a(check, facts):
    c, M = _game([STAND_IN, _uadd(), _module()])
    M.showAll()
    M.wait(WAIT)
    _all_uk(c, M, check, "on")
    for name, what in (("suggested", "%d kept (SetFormattedText)"), ("progress", "two %d inside |c..|r kept"),
                       ("xp", "%d/%d (%d%%) kept"), ("option2", "%s kept in an option button")):
        _is(M, check, name, "on", what)
    rows = [_is(M, check, f"row{i}", "on", f"settings row {i} in upper-case Ukrainian") for i in (1, 2, 3)]
    check("on: upper-case rows have no lower-case Ukrainian letters", all(r == txt(M.UpperUK(lua_str(r))) for r in rows), rows)
    _is(M, check, "description", "on", "description..'\\n\\n'..choice joined, both in Ukrainian")
    tab = _is(M, check, "tabHint", "on", "Tab key picture in the Ukrainian")
    check("on: key pictures kept", "PC-TAB.png" in tab and "PC-SPACE.png" in (txt(M.text("spaceAlert")) or ""),
          [tab[:60], txt(M.text("spaceAlert"))])
    check("on: game text (server option) left in English", txt(M.serverText()) is not None, txt(M.serverText()))
    parsed, line_ok, tts_ok, tts = M.readBack()
    check("read-back: item level line untouched, the stand-in's parse finds L['Item Level']", parsed and line_ok,
          txt(M.text("itemLevel")))
    check("read-back: quest name untouched (text-to-speech reads it)", tts_ok, txt(tts))
    chat = _list(c, M.chat("uk"))
    check("on: DialogueUI chat lines in Ukrainian", not chat, chat[:2])
    M.uadd("dialogueui status")
    st = txt(M.lastChat(3))
    check("on: status line says on", "увімкнено" in st, st[:160])
    _body(c, M, check, facts)

    # A FontString hidden until its first SetText (a pool's spare) was hooked before: Ukrainian at once.
    M.useSpare()
    _is(M, check, "spare", "hidden", "a hidden FontString's first SetText caught at once (no frame passed)")

    # Pooled option buttons: released and set again on every event.
    M.event("GOSSIP_SHOW")
    _is(M, check, "option1", "pool", "a hooked pooled button in Ukrainian at once (no frame passed)")
    M.wait(WAIT)
    facts["dialogueui_buttons_made"] = int(M.made())
    _all_uk(c, M, check, "pool GOSSIP_SHOW (one new button)")
    M.event("QUEST_DETAIL")
    M.wait(WAIT)
    _all_uk(c, M, check, "pool QUEST_DETAIL again")

    # FontUtil: the size setting resets DialogueUI's fonts, then the window shows again.
    M.fontSize(14)
    facts["dialogueui_boxes_after_font_reset"] = len(session.cyr_boxes(c))
    M.wait(WAIT)
    _all_uk(c, M, check, "font size 14, no text set again (our font follows the object)")
    M.showAll()
    M.wait(WAIT)
    _all_uk(c, M, check, "font size 14 then shown again")
    check("font size 14: the new size kept", int(M.size("questType") or 0) == 14, M.size("questType"))

    # Something sets our own words again (SetText(GetText())): the English is still known.
    M.setAgain("questType")
    _is(M, check, "questType", "set again", "SetText(GetText()) keeps our words")

    # The hold key.
    M.key(True)
    M.wait(HELD)
    _all_en(c, M, check, "Shift held", fonts=False)
    qt, qe = txt(M.text("questType")), txt(M.want("questType", "en"))
    check("Shift held: the text set again shows its English", qt == qe, [qt, qe])
    M.key(False)
    M.wait(HELD)
    _all_uk(c, M, check, "Shift let go")

    # The hold key with the settings hidden: its texts are left as they are, and put right the moment
    # the window shows (no wait for the next look).
    M.root("DUIDialogSettings", False)
    M.key(True)
    M.wait(HELD)
    row = txt(M.text("row1"))
    check("Shift held, settings hidden: its texts not touched", row == txt(M.want("row1", "uk")), row)
    M.root("DUIDialogSettings", True)
    _all_en(c, M, check, "Shift held, settings shown at once", fonts=False)
    M.root("DUIDialogSettings", False)
    M.key(False)
    M.wait(HELD)
    M.root("DUIDialogSettings", True)
    _all_uk(c, M, check, "let go while hidden, settings shown at once")

    # Combat: nothing changes; after combat, a catch-up.
    M.combat(True)
    M.key(True)
    M.wait(HELD)
    bad, _ = M.compare("uk")
    check("combat: the hold key changes nothing", not _list(c, bad), _list(c, bad)[:3])
    M.key(False)
    M.wait(HELD)
    M.event("GOSSIP_SHOW")
    M.wait(WAIT)
    o1, en1 = txt(M.text("option1")), txt(M.want("option1", "en"))
    check("combat: a text DialogueUI sets in combat stays its English", o1 == en1, [o1, en1])
    M.combat(False)
    M.wait(WAIT)
    _all_uk(c, M, check, "after combat")

    # Off, then on again.
    M.uadd("dialogueui off")
    M.wait(0.3)
    _all_en(c, M, check, "off")
    check("off: the font size set while on (14) back, not the old one", int(M.size("questType") or 0) == 14,
          M.size("questType"))
    chat = _list(c, M.chat("en"))
    check("off: chat lines English", not chat, chat[:2])
    check("off: DEFAULT_CHAT_FRAME.AddMessage put back", M.chatPutBack())
    M.event("GOSSIP_SHOW")
    M.showAll()
    M.wait(WAIT)
    _all_en(c, M, check, "off, after new events (hooks idle)")
    M.uadd("dialogueui on")
    M.showAll()
    M.wait(WAIT)
    _all_uk(c, M, check, "on again")
    chat = _list(c, M.chat("uk"))
    check("on again: chat lines in Ukrainian", not chat, chat[:2])
    _errors(c, check, "game A")
    del c, M
    gc.collect()


def game_b(check):
    c, M = _game([_uadd(), _module(), STAND_IN])
    M.showAll()
    M.wait(WAIT)
    _all_uk(c, M, check, "DialogueUI loaded after UADD")
    _errors(c, check, "DialogueUI loaded after UADD")


def game_c(check):
    c, M = _game([_uadd(), _module()])
    M.wait(WAIT)
    M.uadd("dialogueui status")
    st = txt(M.lastChat(3))
    check("no DialogueUI: the module waits, status says so", "Dialogue UI не завантажено" in st, st[:160])
    _errors(c, check, "no DialogueUI")


def game_d(check):
    c, M = _game([STAND_IN, _uadd(), _module()], "ruRU")
    M.showAll()
    M.wait(WAIT)
    _all_en(c, M, check, "ruRU client: module steps aside")
    _errors(c, check, "ruRU client")


def run(check, facts):
    if not module_there():
        check("UADD_DialogueUI is there", False, "no UADD_DialogueUI/UADD_DialogueUI.toc")
        return
    for g in (lambda: game_a(check, facts), lambda: game_b(check), lambda: game_c(check), lambda: game_d(check)):
        g()
        gc.collect()


Check = collections.namedtuple("Check", "name ok detail")


def run_checks():
    """Every check of this file. Returns (checks, facts)."""
    checks, facts = [], {}

    def check(name, ok, detail=""):
        checks.append(Check("dialogueui: " + name, bool(ok), str(detail)))
    run(check, facts)
    return checks, facts


if __name__ == "__main__":       # alone: python3 tools/harness/flow_dialogueui.py
    cs, fs = run_checks()
    for x in cs:
        print(("ok    " if x.ok else "FAIL  ") + x.name + (f"  [{x.detail}]" if x.detail else ""))
    print(fs)
    print(f"{sum(x.ok for x in cs)}/{len(cs)} passed")
    sys.exit(0 if all(x.ok for x in cs) else 1)
