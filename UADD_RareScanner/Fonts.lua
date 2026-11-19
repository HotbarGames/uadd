-- A font with Ukrainian letters for our words in RareScanner (lesson 2).
--   * Its texts use the game's font objects (Latin letters only on an English client). A FontString
--     that shows Cyrillic gets UADD's Cyrillic font file at its own size and flags, on that one
--     FontString (UADD/AceFont.lua). Shared font objects are never changed.
--   * Each FontString is hooked once (SetText, SetFormattedText) and decides again on each new text:
--     Cyrillic gets ours, anything else its own font back.
--   * Where: its settings pages (AceFont.Register per app), the page names in the game's settings
--     list, its own frames (the scanner button, the explorer, the export window made late, its named
--     tooltips; looked at when they show), its pop-ups (when one is spawned) and its LibQTip tooltips.
--     Only RareScanner's own frames and its own library copies are hooked: nothing game-wide (lesson 12).
--   * Read back: F.Count counts only FontStrings whose font file really is ours now.

local _, ns = ...
local U = UADD
local F = {}
ns.Fonts = F

local APP = "RareScanner"
local PREFIX = "^RareScanner"
local CYR = "[\208-\210]"                      -- the first byte of a Cyrillic letter in UTF-8
local ROOTS = { "RARESCANNER_BUTTON", "RSExplorerFrame", "RareScannerTelemetryExportFrame", "StopTooltip",
    "GoTooltip", "LootBarToolTip", "RSMapItemToolTip", "RSMapInfoToolTip", "ExplorerTooltip",
    "RareScanner_AddonCompartimentTooltip" }
local hooked, hookedRoot, seen, registered = {}, {}, {}, {}
local dialogHooked, qtipHooked, panelHooked = false, false, false

local Decide
Decide = function(fs)
    if type(fs) ~= "table" or not fs.GetText then return end
    local t = U.Plain(fs:GetText())
    if ns.On() and t and t:find(CYR) then
        UADD.AceFont.Set(fs, APP, Decide)
    else
        UADD.AceFont.Back(fs)
    end
end
F.Decide = Decide

local function HookFs(fs)
    if not hooked[fs] then
        hooked[fs] = true
        hooksecurefunc(fs, "SetText", Decide)
        hooksecurefunc(fs, "SetFormattedText", Decide)
    end
    Decide(fs)
end

-- Every FontString of frame f and its shown children. Fonts only: protected frames are walked too
-- (the scanner button is secure), but nothing on them is called but GetRegions and GetChildren.
local function Walk(f)
    if seen[f] or type(f) ~= "table" or not f.GetObjectType then return end
    seen[f] = true
    local kind = f:GetObjectType()
    if kind == "EditBox" then return end                    -- what the player types: never ours
    if kind == "FontString" then return HookFs(f) end
    if f.GetFontString then
        local fs = f:GetFontString()
        if fs then HookFs(fs) end
    end
    if f.GetRegions then
        for _, g in ipairs({ f:GetRegions() }) do
            if g.GetObjectType and g:GetObjectType() == "FontString" then HookFs(g) end
        end
    end
    if f.GetChildren and f:IsVisible() then
        for _, c in ipairs({ f:GetChildren() }) do Walk(c) end
    end
end

local function Look(f)
    if not ns.On() or type(f) ~= "table" then return end
    wipe(seen)
    local ok, err = pcall(Walk, f)
    wipe(seen)
    if not ok then error(err, 0) end
end
F.Look = Look

local function OnRoot(f) U.SafeCall(Look, f) end

local function AddRoot(f)
    if type(f) ~= "table" or hookedRoot[f] or not f.HookScript then return end
    hookedRoot[f] = true
    f:HookScript("OnShow", OnRoot)
end

local function Collect()
    for _, name in ipairs(ROOTS) do AddRoot(rawget(_G, name)) end
    local reg = LibStub and LibStub("AceConfigRegistry-3.0", true)
    for app in pairs(reg and type(reg.tables) == "table" and reg.tables or {}) do
        if type(app) == "string" and app:find(PREFIX) and not registered[app] then
            registered[app] = true
            UADD.AceFont.Register(app, ns.On)
        end
    end
end

local function OnPanel()
    local p = rawget(_G, "SettingsPanel")
    local list = p and p.CategoryList
    if list and list.IsVisible and list:IsVisible() then U.SafeCall(Look, list) end
end

function F.Install()
    Collect()
    local dlg = LibStub and LibStub("LibDialog-1.0RS", true)
    if not dialogHooked and dlg and type(dlg.Spawn) == "function" then
        dialogHooked = true
        hooksecurefunc(dlg, "Spawn", function()
            for _, d in ipairs(type(dlg.active_dialogs) == "table" and dlg.active_dialogs or {}) do OnRoot(d) end
        end)
    end
    local qt = LibStub and LibStub("LibQTip-1.0RS", true)
    if not qtipHooked and qt and type(qt.Acquire) == "function" then
        qtipHooked = true
        hooksecurefunc(qt, "Acquire", function(_, key)
            local tip = type(qt.activeTooltips) == "table" and qt.activeTooltips[key]
            if tip then AddRoot(tip) end
        end)
    end
    local p = rawget(_G, "SettingsPanel")
    if not panelHooked and p and p.HookScript then
        panelHooked = true
        p:HookScript("OnShow", function() C_Timer.After(0, OnPanel) end)
        if type(p.SelectCategory) == "function" then hooksecurefunc(p, "SelectCategory", OnPanel) end
    end
end

-- Our font on every shown text of its shown frames (the export window is found once it exists).
function F.Scan()
    if not ns.On() then return end
    Collect()
    for f in pairs(hookedRoot) do
        if f.IsVisible and f:IsVisible() then U.SafeCall(Look, f) end
    end
end

-- Decide again for every FontString hooked so far (after the words changed: hold key, on, off).
function F.Sync()
    for fs in pairs(hooked) do U.SafeCall(Decide, fs) end
    if ns.On() then U.SafeCall(F.Scan) end
end

-- Every font back as RareScanner had it.
function F.Restore() UADD.AceFont.Stop(APP) end

-- FontStrings in our font now, read back from the game.
function F.Count() return UADD.AceFont.Count(APP) end
