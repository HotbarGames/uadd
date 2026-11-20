-- A font with Ukrainian letters for our words in GatherMate2 (lesson 2).
--   * GatherMate2 never sets a font: its settings are AceGUI widgets, its launcher tooltip and pin menu are the
--     game's own. A FontString that shows Cyrillic gets UADD's Cyrillic font file at its own size and flags,
--     on that one FontString (UADD/AceFont.lua). Shared font objects are never changed.
--   * Settings: AceFont.Register for each of its options apps, and the page names in the game's settings list.
--   * Launcher tooltip: our OnTooltipShow wrapper sets the font after GatherMate2 filled the lines; the font
--     goes back when that tooltip is cleared.
--   * Pin menu (world map, right click): when the game opens GatherMate2's own menu frame, the shown lines of
--     the menu list get the font; it goes back when the list hides. Other menus are never touched (lesson 12).
--   * Read back: F.Count counts only FontStrings whose font file really is ours now.

local _, ns = ...
local U = UADD
local F = {}
ns.Fonts = F

local APP = "GatherMate2"
local CYR = "[\208-\210]"                      -- the first byte of a Cyrillic letter in UTF-8
local MENU = "GatherMate2_GenericDropDownMenu"
local registered, set = {}, {}
local panelHooked, menuHooked, tipHooked = false, false, false
local ldbObj, ldbOrig, ldbOurs

local function Cyr(fs)
    local t = type(fs) == "table" and fs.GetText and U.Plain(fs:GetText())
    return t and t:find(CYR) and true or false
end

local function Mark(fs)
    if ns.On() and Cyr(fs) then
        UADD.AceFont.Set(fs, APP)
        set[fs] = true
    end
end

local function BackAll()
    for fs in pairs(set) do UADD.AceFont.Back(fs) end
    wipe(set)
end

-- Every FontString of frame f and its shown children (the settings list).
local function Walk(f, depth)
    if type(f) ~= "table" or not f.GetObjectType or depth > 6 then return end
    if f:GetObjectType() == "FontString" then return Mark(f) end
    if f.GetRegions then
        for _, g in ipairs({ f:GetRegions() }) do
            if g.GetObjectType and g:GetObjectType() == "FontString" then Mark(g) end
        end
    end
    if f.GetChildren and f:IsVisible() then
        for _, c in ipairs({ f:GetChildren() }) do Walk(c, depth + 1) end
    end
end

local function OnPanel()
    local p = rawget(_G, "SettingsPanel")
    local list = p and p.CategoryList
    if ns.On() and list and list.IsVisible and list:IsVisible() then U.SafeCall(Walk, list, 0) end
end

local function Collect()
    local reg = LibStub and LibStub("AceConfigRegistry-3.0", true)
    for app in pairs(reg and type(reg.tables) == "table" and reg.tables or {}) do
        if type(app) == "string" and ns.Options.IsOurs(app) and not registered[app] then
            registered[app] = true
            UADD.AceFont.Register(app, ns.On)
        end
    end
end

-- The pin menu: only GatherMate2's own menu frame, only its first list level.
local function OnMenu(level, _, frame)
    if frame ~= rawget(_G, MENU) or not ns.On() then return end
    local list = rawget(_G, "DropDownList" .. (tonumber(level) or 1))
    for i = 1, list and tonumber(list.numButtons) or 0 do Mark(rawget(_G, list:GetName() .. "Button" .. i .. "NormalText")) end
end

local function OnTipShow(tip)
    if not ns.On() or type(tip) ~= "table" or not tip.GetName or not tip:GetName() then return end
    for i = 1, tip.NumLines and tip:NumLines() or 0 do
        Mark(rawget(_G, tip:GetName() .. "TextLeft" .. i))
        Mark(rawget(_G, tip:GetName() .. "TextRight" .. i))
    end
end

local function HookTip(tip)
    if tipHooked or type(tip) ~= "table" or not tip.HookScript then return end
    tipHooked = true
    tip:HookScript("OnTooltipCleared", function() if next(set) then BackAll() end end)
end

function F.Install()
    Collect()
    local p = rawget(_G, "SettingsPanel")
    if not panelHooked and p and p.HookScript then
        panelHooked = true
        p:HookScript("OnShow", function() C_Timer.After(0, OnPanel) end)
        if type(p.SelectCategory) == "function" then hooksecurefunc(p, "SelectCategory", OnPanel) end
    end
    if not menuHooked and type(rawget(_G, "ToggleDropDownMenu")) == "function" then
        menuHooked = true
        hooksecurefunc("ToggleDropDownMenu", function(level, value, frame) U.SafeCall(OnMenu, level, value, frame) end)
        local list = rawget(_G, "DropDownList1")
        if list and list.HookScript then list:HookScript("OnHide", function() if next(set) then BackAll() end end) end
    end
    local ldb = LibStub and LibStub("LibDataBroker-1.1", true)
    local obj = ldb and ldb:GetDataObjectByName("GatherMate2")
    if obj and not ldbObj and type(obj.OnTooltipShow) == "function" then
        ldbObj, ldbOrig = obj, obj.OnTooltipShow
        ldbOurs = function(tip, ...)
            ldbOrig(tip, ...)
            HookTip(tip)
            U.SafeCall(OnTipShow, tip)
            if ns.On() and tip and tip.Show then tip:Show() end
        end
        obj.OnTooltipShow = ldbOurs
    end
end

-- Decide again for the settings and the shown settings list (after the words changed: hold key, on, off).
function F.Sync()
    BackAll()
    if ns.On() then
        Collect()
        OnPanel()
    end
end

-- Every font back as GatherMate2 had it, and its own tooltip function back.
function F.Restore()
    BackAll()
    UADD.AceFont.Stop(APP)
    for app in pairs(registered) do UADD.AceFont.Stop(app) end
    if ldbObj then
        -- Only our wrapper goes; if another addon wrapped it since, theirs stays (ours then just passes through).
        if ldbObj.OnTooltipShow == ldbOurs then
            ldbObj.OnTooltipShow, ldbObj, ldbOrig, ldbOurs = ldbOrig, nil, nil, nil
        end
    end
end

-- FontStrings in our font now, read back from the game.
function F.Count()
    local n = UADD.AceFont.Count(APP)
    for app in pairs(registered) do n = n + UADD.AceFont.Count(app) end
    return n
end
