"""flow_mastercraft.py --prove: one fix cut out of core UADD/Font.lua in memory; Mastercraft's "item tooltip
filled again" step must fail then (docs/LESSONS4.md, lesson 18 again)."""
import gc
import os

import session
from loader import lua_str, txt

CUT_LUA = r"""
local H, cut = HARNESS, { wasCut = false }
H.mccut = cut
local runFile = H.runFile
function H.runFile(addon, path, code)
    if addon == "UADD" and cut.file and path:sub(-#cut.file) == cut.file then
        local a, b = code:find(cut.old, 1, true)
        if a then code, cut.wasCut = code:sub(1, a - 1) .. cut.new .. code:sub(b + 1), true end
    end
    return runFile(addon, path, code)
end
"""
# No "byhand" mutant (cut `was.byhand` in U.FontBack) any more: Mastercraft's lines take UADD's font OBJECT only
# (U.CyrOnLocked), never a Cyrillic file by hand, so no line here keeps a file for that cut to put back by path.
MUTANTS = {# U.FontBack cut to a plain SetFont by the saved path: the symptom check (boxes.lua) must see a hit
           "fontback": ("Font.lua", "    if U.Locked(fs) then\n        if was.object",
                        "    if was.path and was.size then fs:SetFont(was.path, was.size, was.flags or \"\") return end\n"
                        "    if U.Locked(fs) then\n        if was.object")}
# After the refill: the tooltip shown again with Ukrainian on its lines, and the symptom check looks at what is
# on screen (boxes.lua) as the frame is drawn, then after one more frame (HARNESS.step). The guard (Guard.lua)
# repairs a pinned line on its next frame, so the first look is the one that sees the cut. Gives the box count.
# The text has a letter only Ukrainian has (і): boxes.lua counts a Cyrillic text set outside UADD only then
# (UALL Forever's Ukrainian on the next fill; Theirs in boxes.lua), so a Russian-looking one would be skipped.
SHOW_LUA = r"""
local H, tip = HARNESS, GameTooltip
H.boxHits = {}
tip:SetOwner(UIParent, "ANCHOR_NONE")
for i = 1, 6 do tip:AddLine("") _G["GameTooltipTextLeft" .. i]:SetText("\208\166\209\150\208\189\208\176 " .. i) end
tip:Show()
H.boxLook()
H.step(0.05)
tip:Hide()
return #H.boxHits
"""


def _refill(F, p, cut=None):
    def pre(c):
        c.lua.execute(CUT_LUA)
        c.H.mccut.file, c.H.mccut.old, c.H.mccut.new = map(lua_str, cut)
        c.H.boxQuiet = True                  # a mutant's boxes are wanted here, not in the segment's check
    c, M = F._game([F._stand_in(), F._addon("UADD"), F._addon(F.MODULE)], "enUS", p, pre if cut else None)
    M.later()
    boxes = txt(M.refill(lua_str(p["tip"])) or "")
    hits = int(c.lua.execute(SHOW_LUA) or 0)
    was = bool(c.H.mccut.wasCut) if cut else False
    del c, M
    gc.collect()
    return boxes, was, hits


def mutants(F, check, p):
    src = open(os.path.join(session.REPO, "UADD", "Font.lua"), encoding="utf-8").read()
    base, _, base_hits = _refill(F, p)
    for name, (f, old, new) in MUTANTS.items():
        if src.count(old) != 1:
            check(f"mutant {name}: its fix is in {f} once", False, f"found {src.count(old)} times")
            continue
        boxes, was, hits = _refill(F, p, (f, old, new))
        seen = hits if name == "fontback" else boxes
        check(f"mutant {name}: {f} fix cut, 'item tooltip filled again' fails", not base and not base_hits and was
              and seen, f"base={base!r} {base_hits} hits; cut={was}; boxes={boxes!r}; hits on screen={hits}")
