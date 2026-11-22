"""A right-click on TomTom's arrow opens the game's menu, and our font goes on its rows in a way the menu allows
(docs/LESSONS3.md lesson 38).

In the game (2026-11-22): TomTom's crazy_arrow.lua calls MenuUtil.CreateContextMenu; UADD_TomTom's hook gave the
rows our font with fs:SetFont. The game's menu (Blizzard_Menu's compositor) forbids even reading SetFont on its
rows: "Use of function 'SetFont' is disallowed", five times, and the module turned itself off. The stand-in
menu here (menu_compositor.lua) lends its rows out the same way; every forbidden read or call is kept.

  * menu A: right-click the arrow 7 times (more than the 5 errors that turn a module off): no Lua error, no
    forbidden use, no fault of the module, the module still on; the Ukrainian row reads back a font with
    Cyrillic letters (H.cyrBoxes finds no box), the English row keeps the menu's own font; each close gives
    the rows the menu's font again.
  * menu B: /uadd tomtom off with the menu open, then open it again: still no error, no forbidden use, and
    the rows English in the menu's own font.

`python3 tools/harness/flow_tomtom_menu.py --prove`: A and B each fail with mutant `set` (AceFont.Set hooks and
calls fs:SetFont on a menu row again, as before lesson 38).
"""
import collections
import os
import sys

import flow_safe
import session
from flow_tomtom import _game
from flow_tomtom_texts import module_there, picks, rows, shipped
from loader import lua_str, txt

PLAIN = "Wobbly gizmo"            # made-up English: a row the module does not translate
OPENS = 7

PROBE = '''
local H, C = HARNESS, HARNESS.compositor
TTMENU = { faults = 0 }
local fault = UADD.Fault
UADD.Fault = function(key, err)
    if key == "tomtom" then TTMENU.faults = TTMENU.faults + 1 end
    return fault(key, err)
end
function TTMENU.feed(uk, en) TomTomStandInFeed.menu = { uk, en } end
function TTMENU.click()
    H.call("OnClick", TomTomCrazyArrow:GetScript("OnClick"), TomTomCrazyArrow, "RightButton")
end
function TTMENU.close() C.close() end
local function Cyr(t) return type(t) == "string" and t:find("[\\208\\209]") ~= nil end
-- Each row: its text has Cyrillic?, its font has Cyrillic?, its font file (read back).
function TTMENU.rows()
    local out = {}
    for i, fs in pairs(C.rows()) do
        local p = fs:GetFont()
        out[i] = { cyr = Cyr(fs:GetText()), font = UADD.IsCyrFont(p), path = tostring(p) }
    end
    return out
end
function TTMENU.reset()
    for i, b in ipairs({ C.menu:GetChildren() }) do
        local fs = rawget(b, "fontString")
        if fs and not C.lent(fs) and fs:GetFontObject() ~= C.default then return false end
    end
    return true
end
function TTMENU.bad(from) return table.concat(C.bad, "; ", (from or 0) + 1) end
function TTMENU.nbad() return #C.bad end
function TTMENU.boxes() return table.concat(H.cyrBoxes(5), "; ") end
function TTMENU.on() return H.ns.UADD_TomTom.On() and not UADD.IsTurnedOff("tomtom") end
'''


def _run(check, p):
    c, M = _game(p, pre=["menu_compositor.lua"])
    L = c.lua
    L.execute(PROBE.encode("utf-8"))
    T = L.globals().TTMENU
    T.feed(lua_str(p["L"]), lua_str(PLAIN))
    before = len(c.errors())
    bad = []
    for i in range(OPENS):
        T.click()
        M.wait(0.1)
        r = T.rows()
        uk, en = r[1], r[2]
        if not (uk and uk.cyr and uk.font):
            bad.append(f"open {i + 1}: the Ukrainian row {txt(uk and uk.path)} (Cyrillic text: {uk and uk.cyr})")
        if not (en and not en.cyr and not en.font):
            bad.append(f"open {i + 1}: the English row {txt(en and en.path)}")
        boxes = txt(T.boxes())
        if boxes:
            bad.append(f"open {i + 1}: boxes {boxes}")
        T.close()
        if not T.reset():
            bad.append(f"open {i + 1}: a row kept our font after the menu closed")
    errs = c.errors()[before:]
    check("menu A: right-click on the arrow 7 times: our font on the Ukrainian row, menu fonts after close",
          not bad, "; ".join(bad[:3]))
    check("menu A: no Lua error, no forbidden SetFont, no fault, the module still on",
          not errs and not txt(T.bad()) and int(T.faults) == 0 and T.on(),
          f"errors {[m[:120] for _, m, _ in errs[:2]]}, forbidden {txt(T.bad())[:200]}, "
          f"faults {int(T.faults)}, on {T.on()}")
    before, nbad, faults = len(c.errors()), int(T.nbad()), int(T.faults)     # B looks only at its own part
    T.click(); M.wait(0.1)
    M.uadd("tomtom off"); M.wait(0.2)
    T.close()
    T.click(); M.wait(0.1)
    r = T.rows()
    english = all(x is not None and not x.cyr and not x.font for x in (r[1], r[2]))
    errs, bad_b = c.errors()[before:], txt(T.bad(nbad))
    check("menu B: /uadd tomtom off with the menu open, then open again: English rows, no error, no forbidden use",
          english and not errs and not bad_b and int(T.faults) == faults,
          f"rows {[txt(x.path) if x else None for x in (r[1], r[2])]}, errors {[m[:120] for _, m, _ in errs[:2]]}, "
          f"forbidden {bad_b[:200]}, faults {int(T.faults) - faults}")
    T.close()


def run(check, facts, cuts=None):
    if not module_there() or not rows():
        return check("menu (skipped: TomTom or UADD_TomTom not there)", True, "")
    exact, temps, keep = shipped()
    p = picks(rows(), exact, temps, keep)
    if not p:
        return check("menu (skipped: too little Ukrainian shipped yet)", True, "")
    plain = flow_safe.loader.read_text
    if cuts:
        def read(path):
            q = path.replace("\\", "/")
            for name, text in cuts.items():
                if q.endswith("/" + name):
                    return text.encode("utf-8").decode("latin-1")   # as read_text: bytes as they are
            return plain(path)
        flow_safe.loader.read_text = read
    try:
        _run(check, p)
    finally:
        flow_safe.loader.read_text = plain


Check = collections.namedtuple("Check", "name ok detail")


def run_checks(cuts=None):
    checks = []

    def check(name, ok, detail=""):
        checks.append(Check("tt: " + name, bool(ok), str(detail)))
    run(check, {}, cuts)
    return checks, {}


def _replace(path, old, new):
    with open(os.path.join(session.REPO, path), encoding="utf-8") as f:
        text = f.read()
    assert old in text, (path, old)
    return text.replace(old, new)


def proofs():
    """(step, cuts): mutant `set` makes AceFont.Set treat a menu row as any FontString again (hook and
    fs:SetFont, the code before lesson 38). A and B each want their own part to fail with it."""
    cut = {"UADD/AceFont.lua": _replace("UADD/AceFont.lua", "local locked = UADD.Locked(fs)", "local locked = false")}
    return [("tt: menu A", cut), ("tt: menu B", cut)]


if __name__ == "__main__":
    if "--prove" in sys.argv:
        bad = 0
        for step, cuts in proofs():
            try:
                cs, _ = run_checks(cuts)
                failed = [f"{x.name} [{x.detail}]" for x in cs if x.name.startswith(step) and not x.ok]
            except Exception as e:                      # the cut itself broke the flow: no proof
                failed = []
                print(f"  flow stopped: {e!r}"[:300])
            print(("proof ok  " if failed else "PROOF BAD ") + step + ": " + "; ".join(failed)[:300])
            bad += not failed
        sys.exit(1 if bad else 0)
    cs, _ = run_checks()
    for x in cs:
        print(("ok    " if x.ok else "FAIL  ") + x.name + (f"  [{x.detail}]" if x.detail else ""))
    print(f"{sum(x.ok for x in cs)}/{len(cs)} passed")
    sys.exit(0 if all(x.ok for x in cs) else 1)
