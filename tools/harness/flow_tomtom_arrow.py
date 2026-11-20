"""TomTom's arrow title keeps a font with Cyrillic letters (the owner saw boxes there in the game, 2026-11-20).

TomTom makes the arrow's title from GameFontHighlightSmall and never sets its font itself. In the client that
font object is a font FAMILY: GetFont shows only the Latin file, while a FontString that follows the object
also draws Cyrillic. fs:SetFont(<that Latin file>) pins the title to the Latin file: a Cyrillic waypoint
title (UALL Forever's quest name) then shows boxes. The old AceFont.Back put a font back that way, by path.
Here every SetFont / SetFontObject on the title is recorded; "capable" means it follows its object, or is
pinned to a file with Cyrillic letters (UADD.IsCyrFont).

  * arrow A: the title shows Cyrillic; tooltips clear; /uadd tomtom off; on; tooltips clear; the title is
    set again and the module goes off once more. After each step the title is capable and still Cyrillic.
  * arrow B: with the module off, UADD code pins the title to its object's Latin file (as the old code did).
    The guard (UADD/Guard.lua) gives it its object back within 2 s and says so once in chat.

`python3 tools/harness/flow_tomtom_arrow.py --prove`: A fails with the HEAD AceFont.lua (by-path restore) if
HEAD still has it, B fails with Guard.lua emptied.
"""
import collections
import os
import sys

import flow_safe
from flow_tomtom import _game
from flow_tomtom_texts import module_there, picks, rows, shipped
from loader import txt

TITLE = "Шлях до Долини Квіксвуд"
SAID = "напис показував квадрати".encode("utf-8")

PROBE = '''
local t = TomTomCrazyArrow.title
ARROW = { pin = false }
hooksecurefunc(t, "SetFont", function(_, p) ARROW.pin = p end)
hooksecurefunc(t, "SetFontObject", function() ARROW.pin = false end)
function ARROW.capable()
    local p = ARROW.pin
    local cyr = (t:GetText() or ""):find("[\\208\\209]") ~= nil
    return cyr and (p == false or UADD.IsCyrFont(p)), tostring(p) .. " / " .. tostring(t:GetText())
end
function ARROW.clear()
    for _, name in ipairs({ "GameTooltip", "TomTomTooltip" }) do
        local tip = rawget(_G, name)
        if tip then pcall(tip.ClearLines, tip) pcall(tip.Hide, tip) end
    end
end
function ARROW.said(needle)
    local n = 0
    for _, line in ipairs(HARNESS.chat) do if tostring(line):find(needle, 1, true) then n = n + 1 end end
    return n
end
'''
SET = 'TomTomCrazyArrow.title:SetText("%s")' % TITLE
PIN = '''local t = TomTomCrazyArrow.title
local o = t:GetFontObject()
t:SetFont(o:GetFont())'''


def _run(check, p):
    c, M = _game(p)
    L = c.lua
    L.execute(PROBE.encode("utf-8"))
    A = L.globals().ARROW
    c.H.runFile("TomTom", "ArrowTitle.lua", SET.encode("utf-8"))
    M.wait(0.2)
    bad = []

    def look(step):
        ok, got = A.capable()
        if not ok:
            bad.append(f"{step}: {txt(got)}")
    look("shown")
    A.clear(); M.wait(0.2); look("tooltips cleared")
    M.uadd("tomtom off"); look("off")
    M.wait(0.2); look("off, a moment later")
    M.uadd("tomtom on"); M.wait(0.2); look("on")
    A.clear(); M.wait(0.2); look("tooltips cleared again")
    c.H.runFile("TomTom", "ArrowTitle.lua", SET.encode("utf-8")); M.wait(0.2); look("set again")
    M.uadd("tomtom off"); M.wait(0.2); look("off again")
    check("arrow A: the arrow title keeps a font with Cyrillic letters through tooltips clearing and off/on",
          not bad, "; ".join(bad))
    before = int(A.said(SAID))
    c.H.runFile("UADD_Probe", "Pin.lua", PIN.encode("utf-8"))
    pinned = A.pin
    M.wait(2.5)
    ok, got = A.capable()
    c.H.runFile("UADD_Probe", "Pin.lua", PIN.encode("utf-8"))
    M.wait(2.5)
    ok2, _ = A.capable()
    said = int(A.said(SAID)) - before
    check("arrow B: a title pinned to its object's Latin file gets its object back (guard), said once",
          pinned and ok and ok2 and said == 1, f"pinned {txt(pinned)}, then {txt(got)}, said {said}")


def run(check, facts, cuts=None):
    if not module_there() or not rows():
        return check("arrow (skipped: TomTom or UADD_TomTom not there)", True, "")
    exact, temps, keep = shipped()
    p = picks(rows(), exact, temps, keep)
    if not p:
        return check("arrow (skipped: too little Ukrainian shipped yet)", True, "")
    plain = None
    if cuts:
        plain, flow_safe.loader.read_text = flow_safe._cut(cuts)
    try:
        _run(check, p)
    finally:
        if plain:
            flow_safe.loader.read_text = plain


Check = collections.namedtuple("Check", "name ok detail")


def run_checks(cuts=None):
    checks = []

    def check(name, ok, detail=""):
        checks.append(Check("tt: " + name, bool(ok), str(detail)))
    run(check, {}, cuts)
    return checks, {}


def proofs():
    return [("tt: arrow A", {"AceFont.lua": flow_safe._head("AceFont.lua")}),
            ("tt: arrow B", {"Guard.lua": ""})]


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
