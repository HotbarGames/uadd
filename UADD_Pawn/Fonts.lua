-- A font with Ukrainian letters for our words in Pawn (lesson 2).
--   * Pawn's texts use its own font objects, made from the game's (Latin letters only on an English
--     client). A FontString that shows Cyrillic gets UADD's Cyrillic font file at its own size and flags, on
--     that one FontString (UADD/AceFont.lua). Shared font objects are never changed.
--   * Pawn's windows (its main window, its settings page, its two text dialogs): each FontString is hooked
--     once (SetText, SetFormattedText) when its window shows, and decides again on each new text.
--   * Tooltips: only lines Pawn itself adds (PawnAddTooltipLine; the help of its window, PawnUIFrame_TooltipOn)
--     and only when they hold Cyrillic. Their font goes back when that tooltip is cleared. Nothing else in a
--     tooltip is touched, and a tooltip Pawn never wrote to costs one table lookup (lesson 12).
--   * Read back: F.Count counts only FontStrings whose font file really is ours now.

local _, ns = ...
local U = UADD
local F = {}
ns.Fonts = F

local APP, TIP = "Pawn", "PawnTip"
local CYR = "[\208-\210]"                      -- the first byte of a Cyrillic letter in UTF-8
local hooked, hookedRoot, seen = {}, {}, {}
local tipSet, tipHooked = {}, {}               -- tooltip -> { FontString we set }; tooltips hooked once
local installed = false

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

-- ── Tooltip lines Pawn adds ───────────────────────────────────────────────────────────────────

local function TipBack(tip)
    local set = tipSet[tip]
    if not set then return end
    tipSet[tip] = nil
    for _, fs in ipairs(set) do UADD.AceFont.Back(fs) end
end

local function TipLine(tip, i)
    if type(tip) ~= "table" or not tip.GetName or not tip:GetName() then return end
    if not tipHooked[tip] and tip.HookScript then
        tipHooked[tip] = true
        tip:HookScript("OnTooltipCleared", function(t) if tipSet[t] then U.SafeCall(TipBack, t) end end)
    end
    for _, side in ipairs({ "Left", "Right" }) do
        local fs = rawget(_G, tip:GetName() .. "Text" .. side .. i)
        local t = fs and fs.GetText and U.Plain(fs:GetText())
        if t and t:find(CYR) then
            UADD.AceFont.Set(fs, TIP)
            tipSet[tip] = tipSet[tip] or {}
            table.insert(tipSet[tip], fs)
        end
    end
end

local function OnAddLine(tip)
    if not ns.WordsWanted() or type(tip) ~= "table" or not tip.NumLines then return end
    TipLine(tip, tip:NumLines())
end

local function OnHelp()
    local tip = rawget(_G, "GameTooltip")
    if not ns.WordsWanted() or not tip or not tip.NumLines then return end
    for i = 1, tip:NumLines() do TipLine(tip, i) end
end

-- ── Install, scan, sync ───────────────────────────────────────────────────────────────────────

function F.Install()
    for _, name in ipairs(ns.Swap.ROOTS) do AddRoot(rawget(_G, name)) end
    if installed then return end
    installed = true
    if type(rawget(_G, "PawnAddTooltipLine")) == "function" then
        hooksecurefunc("PawnAddTooltipLine", function(tip) U.SafeCall(OnAddLine, tip) end)
    end
    if type(rawget(_G, "PawnUIFrame_TooltipOn")) == "function" then
        hooksecurefunc("PawnUIFrame_TooltipOn", function() U.SafeCall(OnHelp) end)
    end
end

-- Our font on every shown text of Pawn's shown windows.
function F.Scan()
    if not ns.On() then return end
    for _, name in ipairs(ns.Swap.ROOTS) do AddRoot(rawget(_G, name)) end
    for f in pairs(hookedRoot) do
        if f.IsVisible and f:IsVisible() then U.SafeCall(Look, f) end
    end
end

-- Decide again for every FontString hooked so far (after the words changed: hold key, on, off).
function F.Sync()
    for fs in pairs(hooked) do U.SafeCall(Decide, fs) end
    if not ns.WordsWanted() then for tip in pairs(tipSet) do U.SafeCall(TipBack, tip) end end
    if ns.On() then U.SafeCall(F.Scan) end
end

-- Every font back as Pawn had it.
function F.Restore()
    for tip in pairs(tipSet) do U.SafeCall(TipBack, tip) end
    UADD.AceFont.Stop(APP)
    UADD.AceFont.Stop(TIP)
end

-- FontStrings in our font now, read back from the game.
function F.Count() return UADD.AceFont.Count(APP) + UADD.AceFont.Count(TIP) end
