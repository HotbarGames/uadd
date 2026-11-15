-- Which UALL Forever setting switches off the route each kind of name comes through (the "gate"
-- of each route in uall.lua). With its route off, UALLF shows that kind in English, and UALL
-- would say "not now" for it until the player switches it back on. So Names.lua does not wait
-- for it: that kind stays English, as it does in UALLF.
-- UALLFSettingsDB is UALLF's saved settings, a global; we only read it.
local U = UADD.UALL

local SETTING = { zones = "world.zones", Quest = "interface.storage", Npc = "gossip", Item = "interface.loot" }
local ORDER = { "zones", "Quest", "Npc", "Item" }

-- true when the player switched off the route for this kind ("zones", "Quest", "Npc" or "Item").
-- Only false counts: a missing setting is UALLF's default, which is on.
function U.RouteOff(kind)
    local s, key = _G.UALLFSettingsDB, SETTING[kind]
    return key ~= nil and type(s) == "table" and s[key] == false
end

-- The kinds switched off now, like "Npc,Item", or "" when all are on. Part of the saved-cache
-- signature (Names.lua), so a route switched back on gets its names collected again.
function U.RoutesOff()
    local off = {}
    for _, kind in ipairs(ORDER) do
        if U.RouteOff(kind) then off[#off + 1] = kind end
    end
    return table.concat(off, ",")
end
