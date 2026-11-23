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
MUTANTS = {"byhand": ("Font.lua", "not (was.byhand and U.IsCyrFont", "not ((true) and U.IsCyrFont")}


def _refill(F, p, cut=None):
    def pre(c):
        c.lua.execute(CUT_LUA)
        c.H.mccut.file, c.H.mccut.old, c.H.mccut.new = map(lua_str, cut)
    c, M = F._game([F._stand_in(), F._addon("UADD"), F._addon(F.MODULE)], "enUS", p, pre if cut else None)
    M.later()
    boxes = txt(M.refill(lua_str(p["tip"])) or "")
    was = bool(c.H.mccut.wasCut) if cut else False
    del c, M
    gc.collect()
    return boxes, was


def mutants(F, check, p):
    src = open(os.path.join(session.REPO, "UADD", "Font.lua"), encoding="utf-8").read()
    base, _ = _refill(F, p)
    for name, (f, old, new) in MUTANTS.items():
        if src.count(old) != 1:
            check(f"mutant {name}: its fix is in {f} once", False, f"found {src.count(old)} times")
            continue
        boxes, was = _refill(F, p, (f, old, new))
        check(f"mutant {name}: {f} fix cut, 'item tooltip filled again' fails", not base and was and boxes,
              f"base={base!r}; cut={was}; boxes={boxes!r}")
