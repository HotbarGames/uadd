"""UADD_BugSack on a stand-in for BugSack (tools/harness/bugsack). BugSack is All Rights Reserved, so none of its
English is here: the stand-in draws the shapes its sack window, options and send popup draw, and gets every text at
run time from a feed built here from the installed addon (tools/bs_source.py: its locale table and where its code
reads each key). Keys only in this file; the English never.

  * Game E (no module): its English: what "off" and the hold key must give back.
  * Game A (on at login): 1 ours: the session label, the window's labels and tabs, the option labels and their
    tooltips (made while its table was English), the wipe button's and the session label's tooltips, the no-bugs
    line, the send popup; the filter box stays. 2 the session label as a whole line: today, a clock, a date, sent by
    a name (kept), an unknown word and a bare count (whole English). 3 the popup: text and both buttons ours.
    4 the text area: an error text untouched; the no-bugs line ours on the player's font size choice too.
    5 our font on every Cyrillic text and on no other: on, held, after each button's state change.
    6 hold key, off and on, three times: English exactly, then ours exactly, no font kept. 8 the text area (an edit
    box: its own nameless font record) never gets that record back, so no client crash (lesson 47).
    7 /uadd bs says on.
  * Game C (off at login): the player typed the filter label's text in the filter box; then on: kept (lesson 13).
  * Game B: no BugSack (the module's TOC needs it: no errors, nothing more).
  * Mutants (--prove): each step fails with its fix cut out.
"""
import os
import sys

import halves_mods
import session
from flow_bs_crash import crash
from flow_pawn_game import cyr, diff, errors

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import bs_source as G  # noqa: E402
from hashtext import djb2  # noqa: E402
from flow import Check  # noqa: E402
from loader import Addon, Client, lua_str, read_text, txt  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
MODULE, TARGET = "UADD_BugSack", "BugSack"
ROLES = {"today": "0e2d9ee6", "nobugs": "60fc61d4", "loc": "71531c39", "sent": "3034da1b", "pop": "45e5f276",
         "send": "7c8c4f2f"}
WORD = "0f6321ef"
OFF = {"UADD": "UADD_DB = { modules = { bs = { enabled = false } } }"}


def installed():
    return os.path.isfile(os.path.join(str(G.addon_dir()), G.LOCALES))


def module_there():
    return os.path.isfile(os.path.join(session.REPO, MODULE, MODULE + ".toc"))


def _q(s):
    """A Lua string literal (every byte outside plain ASCII as a decimal escape)."""
    return '"' + "".join(chr(b) if 32 <= b < 127 and b not in (34, 92) else "\\%d" % b
                         for b in s.encode("utf-8")) + '"'


def _list(keys):
    return "{" + ",".join(_q(k) for k in keys) + "}"


def feed():
    """The stand-in's feed (Lua code): its locale table and which key each part of its window shows."""
    a = G.addon_dir()
    en = G.english(a)
    used, words = G.uses(a)
    by_hash = {}
    for k, v in en.items():
        by_hash.setdefault(djb2(v), k)
    role = {r: by_hash[h] for r, h in ROLES.items()}
    roles = set(role.values())
    win, tips = [], []
    for key, kind, f, _ in used:
        if f == "sack.lua" and kind == "window" and key not in roles and key not in win and key in en:
            win.append(key)
        if f == "sack.lua" and kind == "tip" and key in en:
            tips.append(key)
    assert len(win) == 8 and len(tips) == 4, (len(win), len(tips))
    lines = {}
    for key, kind, f, line in used:
        if f == "config.lua" and kind in ("option", "tip") and key in en:
            lines.setdefault(line, []).append((kind, key))
    opts = [(v[0][1], v[1][1]) for _, v in sorted(lines.items()) if len(v) >= 2 and v[0][0] == "option"
            and v[1][0] == "tip"]
    rows = [v[0][1] for _, v in sorted(lines.items()) if len(v) == 1 and v[0][0] == "option"]
    assert len(opts) == 7 and len(rows) == 2, (len(opts), len(rows))
    word = words[0][0]
    assert djb2(word) == WORD
    body = ",".join("[%s]=%s" % (_q(k), _q(v)) for k, v in en.items())
    return ("BugSackStandInFeed = { L = {%s}, role = {%s}, win = { filter = %s, buttons = %s, tabs = %s }, "
            "tips = { session = %s, wipe = %s }, opts = {%s}, rows = %s, word = %s }") % (
        body, ",".join("%s=%s" % (r, _q(k)) for r, k in role.items()), _q(win[0]), _list(win[1:5]),
        _list(win[5:8]), _list(tips[:2]), _list(tips[2:]), ",".join(_list(p) for p in opts), _list(rows), _q(word))


def game(target=True, module=True, cut=None, cuts=None, off=False):
    addons = [Addon(TARGET, os.path.join(HERE, "bugsack", TARGET), session.FLAVOR)] if target else []
    addons += [Addon(n, os.path.join(session.REPO, n), session.FLAVOR) for n in ("UADD",) + ((MODULE,) if module else ())]
    c = Client(addons, OFF if off else None, "enUS")
    c.lua.execute(read_text(os.path.join(HERE, "flow_bs.lua")))
    M = c.H.bs
    if target:
        M.feed(lua_str(feed()))
    for name, (file, old, new) in (cuts or {}).items():
        M.addCut(lua_str(name), lua_str(file), lua_str(old), lua_str(new))
    M.cut = lua_str(cut) if cut else None
    c.start()
    c.H.pump(20)
    if target:
        M.open()
    return c, M


def snap(M):
    return {txt(k): txt(v) for k, v in M.snap().items()}


# ── Steps: each (check, c, M, E, A) -> ok ──────────────────────────────────────────────────────

def ours(check, c, M, E, A):
    words = [k for k in A if k[0] in "SWOTRP" and k not in ("S:tip1", "W:filter") and not k.startswith("WT:")
             and not cyr(A[k])]
    tips = [k for k in A if k.startswith("WT:") and not cyr(A[k])]
    ok = (set(A) == set(E) and not words and not tips and cyr(A["W:filter"]) and cyr(A["X:text"])
          and A.get("F:filter") == E.get("F:filter") and A.get("S:tip1") == E.get("S:tip1"))
    check("1 ours: session label, labels, tabs, options and their tooltips, other tooltips, no-bugs line, popup; "
          "the filter box and the addon's name stay", ok, (sorted(set(A) ^ set(E))[:3], words[:4], tips))
    return ok


def sessions(check, c, M, E, A):
    got = {k: txt(M.session(k, None, "Zorp")) for k in ("today", "local", "date", "sent", "num", "options")}
    odd = txt(M.session("local", lua_str("Gizmo"), None))
    bad = [k for k in ("today", "local", "date", "sent") if not cyr(got[k])]
    bad += [k for k in ("num",) if cyr(got[k])]
    if "Zorp" not in got["sent"]:
        bad.append("sent: name")
    if cyr(odd) or "Gizmo" not in odd:
        bad.append("unknown word: " + odd)
    if cyr(got["options"]) and "Options" in got["options"]:
        bad.append("options half")
    check("2 session label as a whole line: today, a clock, a date, sent by a name (kept); an unknown word and a "
          "count whole English", not bad, (bad, got))
    return not bad


def popup(check, c, M, E, A):
    t, b1, b2 = (txt(x) for x in M.popup())
    ok = cyr(t) and cyr(b1) and cyr(b2) and t != E["P:text"]
    check("3 send popup: its text and both buttons ours", ok, (cyr(t), cyr(b1), cyr(b2)))
    return ok


def textarea(check, c, M, E, A):
    err_now, err = (txt(x) for x in M.bugs(1))
    M.bugs(0)
    M.fontSize(lua_str("GameFontNormal"))      # the player's choice while the no-bugs line shows: no SetText after
    a = [x for x in (txt(y) for y in M.fonts().values()) if x.startswith("text:")]
    M.fontSize(lua_str("GameFontHighlightSmall"))
    no = txt(M.bugs(0)[0])
    ok = err_now == err and not a and cyr(no)
    check("4 text area: an error text untouched; the no-bugs line ours, on the player's font size too", ok,
          (err_now == err, a, cyr(no)))
    return ok


def boxes(check, c, M, E, A):
    bad = [("on", txt(x)) for x in M.fonts().values()]
    bad += [("tabs on", txt(x)) for x in M.hoverTabs().values()]
    M.key(True)
    bad += [("held", txt(x)) for x in M.fonts().values()]
    bad += [("tabs held", txt(x)) for x in M.hoverTabs().values()]
    M.key(False)
    M.press()
    bad += [("pressed", txt(x)) for x in M.fonts().values()]
    bad += [("tabs pressed", txt(x)) for x in M.hoverTabs().values()]
    check("5 our font on every Cyrillic text and on no other: on, held, after each button's state change, the "
          "mouse over each tab (the client's own font switch); each tab fitted to ours", not bad, bad[:4])
    return not bad


def loop(check, c, M, E, A):
    bad = []
    for i in range(3):
        for how, want in (("hold", E), ("release", A), ("off", E), ("on", A)):
            if how in ("hold", "release"):
                M.key(how == "hold")
            else:
                M.uadd("bs " + how)
            d = diff(want, snap(M))
            n = int(M.saved())
            if d or (how in ("off", "hold") and n):
                bad.append((i + 1, how, d[:3], n))
    check("6 hold key, off, on (x3): English exactly (window, tooltips, popup), then ours exactly; no font kept",
          not bad, bad[:3])
    return not bad


def typed(check, c, M, E, A):
    """Game C: off at login; the filter label's own text typed in the filter box; then on."""
    was = txt(M.typed())
    M.uadd("bs on")
    now = snap(M)
    ok = bool(was) and now.get("F:filter") == was and cyr(now.get("W:filter")) and int(M.shown()) > 0
    check("C on after login: the labels ours; the label's English the player typed in the filter box stays",
          ok, (now.get("F:filter") == was, int(M.shown())))
    return ok


def run(check, facts):
    if not module_there() or not installed():
        halves_mods.bs(check, None, halves_mods.SKIP)
        facts["note"] = "BugSack or the module not there: skipped"
        return
    c, M = game(module=False)
    E = snap(M)
    errors(c, check, "game E")

    c, M = game()
    A = snap(M)
    for step in (ours, sessions, popup, textarea, boxes, loop, crash):
        step(check, c, M, E, A)
    M.uadd("bs")
    status = [x for x in c.chat()[-5:] if "увімкнено" in x]
    check("7 /uadd bs: on, with counts", status, c.chat()[-4:])
    facts["texts"] = len(E)
    halves_mods.bs(check, c)
    errors(c, check, "game A")

    c, M = game(off=True)
    typed(check, c, M, E, None)
    errors(c, check, "game C")

    c, M = game(target=False)
    errors(c, check, "game B (no BugSack)")


def run_checks():
    """Every check of this file. Returns (checks, facts)."""
    checks, facts = [], {}

    def check(name, ok, detail=""):
        checks.append(Check("bs: " + name, bool(ok), str(detail)))
    run(check, facts)
    return checks, facts


# ── Mutants: each cuts one fix out of the module; its step must fail ─────────────────────────────

CUTS = {
    "wrap": ("Screen.lua", "        pcall(ns.Words, false)\n", "", loop, False),
    "session": ("Screen.lua", '    hooksecurefunc(btn, "SetText", Guard(function(self, text) ns.OnSession(self, '
                "U.Plain(text)) end))", "", sessions, False),
    "textarea": ("Screen.lua", 'hooksecurefunc(ta, "SetFontObject", Guard(function(self)',
                 "local _ = (function(f) return f end)(Guard(function(self)", textarea, False),
    "tip": ("Screen.lua", "        if want then HookTip(f) end\n", "", ours, False),
    "refix": ("Screen.lua", "    if ns.WordsWanted() and t and UK[t] then Fresh(fs) pcall(CyrOn, fs) end", "",
              boxes, False),
    # No "fresh" any more (lesson 32 again): on a button's label the core never saves our copy as its own font
    # (U.FontBase in U.SaveFont and U.FontBack, ButtonFont.lua), so the cut changed nothing here; that proof is
    # the core's (flow_button.py).
    # The core's button helper (lesson 46): a button's state objects left as they were, so the client's own
    # switch under the mouse puts the game's Latin object back on our text.
    "states": ("UADD:ButtonFont.lua", "local ok, yes = pcall(Put, btn, look)", "local ok, yes = true, true", boxes,
               False),
    "fit": ("Screen.lua", "then FitTab(owner) end", "then end", boxes, False),
    # Lesson 47: the core takes any object (the text area's own nameless record too): it goes back, the client dies.
    "record": ("UADD:FontObject.lua",'if type(o) ~= "table" or o == fs or type(o.GetFont) ~= "function" or not Named(o) '
               "then return false end", 'if type(o) ~= "table" or type(o.GetFont) ~= "function" then return false end',
               crash, False),
}


def prove():
    """Each cut: a fresh game without that fix; the step must fail. Returns the exit code."""
    _, M = game(module=False)
    E = snap(M)
    cuts = {k: v[:3] for k, v in CUTS.items()}
    bad = []
    for name, (_, _, _, step, off) in CUTS.items():
        c, M = game(cut=name, cuts=cuts, off=off)
        ok = step(lambda *_: None, c, M, E, None if off else snap(M))
        cut = bool(M.wasCut)
        print(("ok    " if cut and ok is False else "FAIL  ") + f"cut {name}: cut={cut}, step {step.__name__} ok={ok}")
        if not (cut and ok is False):
            bad.append(name)
    print(f"{len(CUTS) - len(bad)}/{len(CUTS)} cuts break their step")
    return 1 if bad else 0


if __name__ == "__main__":       # alone: python3 tools/harness/flow_bs.py [--prove]
    if "--prove" in sys.argv:
        sys.exit(prove())
    cs, fs = run_checks()
    for x in cs:
        print(("ok    " if x.ok else "FAIL  ") + x.name + (f"  [{x.detail[:400]}]" if x.detail else ""))
    print(fs)
    print(f"{sum(x.ok for x in cs)}/{len(cs)} passed")
    sys.exit(0 if all(x.ok for x in cs) else 1)
