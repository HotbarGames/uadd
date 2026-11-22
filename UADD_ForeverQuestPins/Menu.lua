-- UADD_ForeverQuestPins: its World Map filter list.
-- Since 1.1.3 Forever Quest Pins no longer adds its checkboxes to the World Map's tracking menu. It puts its own
-- button on the map (made the first time the map opens) and its own list under it (made on the button's first
-- click). The list's labels are copied from L when its Config.lua loads, before our words come in (lesson 1), so
-- they are drawn English. The list is one of Screen.lua's ROOTS: on, off and the hold key switch its labels both
-- ways. Here, each click that shows the list walks it again, after Forever Quest Pins built and refreshed it, and
-- the button's tooltip goes through Screen.lua's tooltip hook (English back also once the module is off).
-- Any error in the click counts (U.Safe): 5 turn the module off, English as it was.
local _, ns = ...
local U = UADD
local Lc = ns.Locale
local M = {}
ns.Menu = M

local KEY = "foreverquestpins"
local BUTTON = "ForeverQuestPinsMapFilterButton"
local LIST = "ForeverQuestPinsMapFilterList"
local done, watching = false, false

-- After its own OnClick: only while the module is on (off, Screen.Restore already gave the English back) and
-- only when that click showed the list (a click that hid it needs nothing). Walks the list alone.
local function OnClick()
    if not ns.On() then return end
    local list = rawget(_G, LIST)
    if type(list) == "table" and type(list.IsShown) == "function" and list:IsShown() then ns.Screen.ApplyTo(list) end
end

local function Hook()
    if done then return end
    local b = rawget(_G, BUTTON)
    if type(b) ~= "table" or type(b.HookScript) ~= "function" then return end
    done = true
    b:HookScript("OnClick", U.Safe(KEY, OnClick))
    ns.Screen.TipOn(b)
end

function M.Install()
    Hook()
    if done or watching then return end
    local fqp = Lc.Target()
    if not fqp or type(fqp.EnsureWorldMapFilterButton) ~= "function" then return end
    watching = true
    hooksecurefunc(fqp, "EnsureWorldMapFilterButton", U.Safe(KEY, Hook))
end
