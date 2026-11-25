-- Lua helpers for flow_tomtom_place.py: the arrow's title and a pin's tooltip title named after a map. Reached
-- from Python as HARNESS.ttp. Run before the game starts, after flow_tomtom.lua.
local H = HARNESS
local M = {}
H.ttp = M

-- The proof that a step has teeth: with M.cut set, UADD_TomTom's Title.lua or Module.lua runs without one fix
-- (in memory only).
-- hook: the title's SetText hook; map: the arrow's waypoint map; cache: the last answer kept (lesson 12);
-- guard: the title's SetText hook under U.Safe, dead after an off for errors (lesson 19);
-- wait: a "not known yet" answer kept as if final; back: the English back on the hold key; tip: the pin tooltip.
local CUTS = {
    hook = { "        hooksecurefunc(fs, \"SetText\", Guard(Title.OnText))", "\n", "\n" },
    guard = { "        hooksecurefunc(fs, \"SetText\", Guard(Title.OnText))", "\n",
              "        hooksecurefunc(fs, \"SetText\", U.Safe(\"tomtom\", Title.OnText))\n" },
    map = { "    Title.map = type(uid) == \"table\"", "\n", "\n" },
    cache = { "    if en ~= Title.ken or Title.map ~= Title.kmap then", "\n", "    if true then\n" },
    wait = { "        if wait and CanWait() then", "\n", "        if false then\n" },
    back = { "            U.SafeCall(Title.Restore)\n            U.SafeCall(ns.SwapOut)", "\n", "\n" },
    tip = { " or Coords(s) or ns.TipPlace(s) end", "\n", " or Coords(s) end,\n" },
}
M.cut, M.wasCut = nil, false
local runFile = H.runFile
function H.runFile(addon, path, code)
    if addon == "UADD_TomTom" and (path == "Module.lua" or path == "Title.lua") and M.cut then
        local c = CUTS[M.cut]
        local a = code:find(c[1], 1, true)
        local b = a and select(2, code:find(c[2], a + #c[1], true))   -- the rest of c[1]'s line goes too
        if a and b then code, M.wasCut = code:sub(1, a - 1) .. c[3] .. code:sub(b + 1), true end
    end
    local r = { runFile(addon, path, code) }
    if addon == "TomTom" and path == "TomTom.lua" then M.standIn() end
    return unpack(r)
end

-- The real TomTom sets the arrow's title in SetCrazyArrow(uid, dist, title); uid = { mapID, x, y, title = ... }.
function M.standIn()
    local A = rawget(_G, "TomTom")
    if type(A) ~= "table" then return end
    function A:SetCrazyArrow(uid, dist, title) TomTomCrazyArrow.title:SetText(title) end
end

-- A made-up map tree: 7001 Zorpwood Vale under 7000 Blatter Reach; 7002 Fizzle Marsh (no source knows it) under
-- 7000; 7003 Glorp Hollow. UADD.UALL.Zone is a stub (lesson 20: UADD.UALL, never the root) that counts its asks.
M.zones, M.waiting, M.asks, M.player = {}, false, 0, nil
local TREE = { [7000] = { "Blatter Reach", 0 }, [7001] = { "Zorpwood Vale", 7000 },
               [7002] = { "Fizzle Marsh", 7000 }, [7003] = { "Glorp Hollow", 0 } }
function M.maps()
    C_Map = C_Map or {}
    local info, best = C_Map.GetMapInfo, C_Map.GetBestMapForUnit
    C_Map.GetMapInfo = function(id)
        local t = TREE[id]
        if t then return { mapID = id, name = t[1], mapType = 3, parentMapID = t[2] } end
        return info and info(id)
    end
    C_Map.GetBestMapForUnit = function(unit) if unit == "player" and M.player then return M.player end
        return best and best(unit) end
    C_Map.GetUserWaypoint = function() return nil end
    UADD.UALL.Zone = function(en)
        M.asks = M.asks + 1
        if M.waiting then return nil, true end
        return M.zones[en]
    end
end
function M.zone(en, uk) M.zones[en] = uk end
function M.wait4(on) M.waiting = on and true or false end
function M.at(id) M.player = id end

local function T() return TomTomCrazyArrow.title end
function M.arrow(map, title)
    TomTom:SetCrazyArrow({ map, 0.5, 0.5, title = title }, 10, title)
    return T():GetText()
end
function M.again(title, n)                      -- a hijacking addon sets the same title on every frame
    local before = M.asks
    for _ = 1, n do T():SetText(title) H.step(0.02) end
    return M.asks - before, T():GetText()
end
-- Our look-up throws, as when its data is odd; back on false.
local place
function M.throw(on)
    local ns = H.ns["UADD_TomTom"]
    if on then
        place = place or ns.Place
        ns.Place = function() error("harness: a title look-up fails") end
    elseif place then
        ns.Place, place = place, nil
    end
end
function M.title() return T():GetText() end
function M.tip(title)                           -- TomTom's code shows a pin's tooltip, its title first
    TomTomTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    TomTomTooltip:SetText(title)
    TomTomTooltip:Show()
    return TomTomTooltipTextLeft1:GetText()
end
