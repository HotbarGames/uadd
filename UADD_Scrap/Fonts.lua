-- A font with Ukrainian letters for our words in Scrap (the same way as the other modules).
--   * Scrap's texts use the game's font objects (Latin letters only on an English client). A FontString
--     that shows Cyrillic gets UADD's Cyrillic font file at the size and with the flags it has now, on that
--     one FontString (UADD/AceFont.lua). Shared font objects are never changed.
--   * Each FontString is hooked once (SetText, SetFormattedText; a button's own text and font object
--     setters too) and decides again on each new text: Cyrillic gets ours, anything else its own font back.
--   * Where: Scrap's settings pages, its junk list window, its tutorial frame, its Sushi pop-ups (the
--     dialog before destroying junk), and GameTooltip lines while the tooltip's owner is one of those or
--     the merchant window's Scrap button, and shows no item. The tooltip hook leaves first for any other
--     tooltip (lesson 12).
--   * Read back: F.Count counts only the FontStrings whose font file really is ours now (lesson 2).
--   * "/uadd scrap off" and the hold key put back exactly what Scrap had.

local _, ns = ...
local U = UADD
local F = {}
ns.Fonts = F

local APP, TIP = "Scrap", "Scrap tooltip"
local CYR = "[\208-\210]"                      -- the first byte of a Cyrillic letter in UTF-8
local GROUPS = { "Main", "Filters", "Help", "Credits" }
local hooked, hookedRoot, roots, seen = {}, {}, {}, {}
local NONE = {}
local tipBusy, tipHooked, popupHooked = false, false, false

local function Scrap() local a = rawget(_G, "Scrap") return type(a) == "table" and a or nil end
local function Sushi() return LibStub and LibStub("Sushi-3.2", true) end
local function Cyr(s) s = U.Plain(s) return s ~= nil and s:find(CYR) ~= nil end

-- A name in the junk list (an item: a game name) or the patrons page (people): never a miss of ours.
local function NotOurs(fs)
    local p = fs.GetParent and fs:GetParent()
    if type(p) == "table" and p.Icon and p.Text == fs then return true end
    local a = Scrap()
    local O = a and a.Options
    local credits = type(O) == "table" and rawget(O, "Credits")
    for _ = 1, 6 do
        if type(p) ~= "table" then return false end
        if credits and p == credits then return true end
        p = p.GetParent and p:GetParent()
    end
    return false
end

local Decide
Decide = function(fs)
    if type(fs) ~= "table" or not fs.GetText then return end
    local t = U.Plain(fs:GetText())
    if ns.On() and t and t:find(CYR) then
        UADD.AceFont.Set(fs, APP, Decide)
    else
        UADD.AceFont.Back(fs)
        if t and ns.WordsWanted() and t:find("%a%a%a") and not NotOurs(fs) then U.Missed("scrap", t, fs) end
    end
end
F.Decide = Decide

local function HookFs(fs)
    if hooked[fs] then return end
    hooked[fs] = true
    hooksecurefunc(fs, "SetText", Decide)
    hooksecurefunc(fs, "SetFormattedText", Decide)
end

local function OnButton(b)
    local fs = b.GetFontString and b:GetFontString()
    if fs then HookFs(fs) Decide(fs) end
end

local function HookButton(b)
    if hooked[b] then return end
    hooked[b] = true
    for _, m in ipairs({ "SetText", "SetFormattedText", "SetNormalFontObject", "SetHighlightFontObject",
        "SetDisabledFontObject" }) do
        if b[m] then hooksecurefunc(b, m, OnButton) end
    end
end

local function Walk(f)
    if seen[f] or type(f) ~= "table" or not f.GetObjectType then return end
    seen[f] = true
    if f.IsProtected and f:IsProtected() then return end
    local kind = f:GetObjectType()
    if kind == "EditBox" then return end
    if kind == "FontString" then HookFs(f) Decide(f) return end
    if (kind == "Button" or kind == "CheckButton") and f.GetFontString then HookButton(f) OnButton(f) end
    if f.GetRegions then
        for _, g in ipairs({ f:GetRegions() }) do
            if g.GetObjectType and g:GetObjectType() == "FontString" then HookFs(g) Decide(g) end
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

local function OnRoot(f) U.SafeCall(Look, f) end

-- Scrap's pages, its junk list window, its tutorial frame and its merchant button (a tooltip owner).
local function Collect()
    wipe(roots)
    local a = Scrap()
    if not a then return end
    local O = a.Options
    for _, id in ipairs(GROUPS) do
        local g = type(O) == "table" and rawget(O, id)
        if type(g) == "table" and g.GetObjectType then roots[g] = true end
    end
    local V = a.Visualizer
    if type(V) == "table" and V.GetObjectType then roots[V] = true end
    local CT = LibStub and LibStub("CustomTutorials-2.1", true)
    local tut = CT and type(CT.frames) == "table" and a.Tutorials and CT.frames[a.Tutorials]
    if type(tut) == "table" and tut.GetObjectType then roots[tut] = true end
    local M = a.Merchant
    if type(M) == "table" and M.GetObjectType then roots[M] = true end
    for f in pairs(roots) do
        if not hookedRoot[f] and f.HookScript then
            hookedRoot[f] = true
            f:HookScript("OnShow", OnRoot)
            if type(f.UpdateChildren) == "function" then hooksecurefunc(f, "UpdateChildren", OnRoot) end
        end
    end
end

-- Is frame `f` (or one of its parents) a Scrap page, window or pop-up?
-- Cheapest test first (lesson 12): the parent walk against our roots; the pop-up list only when one is open.
local function Ours(f)
    if type(f) ~= "table" then return false end
    local start = f
    for _ = 1, 30 do
        if type(f) ~= "table" then break end
        if roots[f] then return true end
        f = f.GetParent and f:GetParent()
    end
    local S = Sushi()
    local popups = S and S.Popup and S.Popup.Active
    if type(popups) ~= "table" or #popups == 0 then return false end
    f = start
    for _ = 1, 30 do
        if type(f) ~= "table" then return false end
        for _, p in ipairs(popups) do if p == f then return true end end
        f = f.GetParent and f:GetParent()
    end
    return false
end
F.Ours = Ours

-- ── Tooltips and pop-ups ─────────────────────────────────────────────────────────────────────────

local function OnTip(tip)
    if tipBusy or not ns.On() then return end
    if not Ours(tip:GetOwner()) then return end               -- any other tooltip: leave at once
    if tip.GetItem and tip:GetItem() then return end           -- an item's tooltip: never ours
    local name, any = tip:GetName(), false
    for i = 1, tip:NumLines() do
        for _, side in ipairs({ "Left", "Right" }) do
            local fs = name and _G[name .. "Text" .. side .. i]
            if fs and fs:IsShown() and Cyr(fs:GetText()) then
                UADD.AceFont.Set(fs, TIP)
                any = true
            end
        end
    end
    if any then
        tipBusy = true
        pcall(tip.Show, tip)
        tipBusy = false
    end
end

local function TipBack() UADD.AceFont.Stop(TIP) end

local function OnPopup()
    local S = Sushi()
    for _, p in ipairs(S and S.Popup and S.Popup.Active or NONE) do
        local t = p.Text or p.text
        local s = type(t) == "table" and t.GetText and t:GetText()
        if Cyr(s) then U.SafeCall(Look, p) end
    end
end

function F.Install()
    Collect()
    if not tipHooked and GameTooltip then
        tipHooked = true
        hooksecurefunc(GameTooltip, "Show", function(tip) U.SafeCall(OnTip, tip) end)
        GameTooltip:HookScript("OnTooltipCleared", TipBack)
        GameTooltip:HookScript("OnHide", TipBack)
    end
    local S = Sushi()
    if not popupHooked and S and type(S.Popup) == "table" and type(S.Popup.New) == "function" then
        popupHooked = true
        hooksecurefunc(S.Popup, "New", function() U.SafeCall(OnPopup) end)
    end
end

-- Our font on every shown text of the shown pages and windows.
function F.Scan()
    if not ns.On() then return end
    Collect()
    for f in pairs(roots) do
        if f.IsVisible and f:IsVisible() then U.SafeCall(Look, f) end
    end
end

-- Decide again for every FontString hooked so far (after the words changed: hold key, on, off).
function F.Sync()
    for fs in pairs(hooked) do
        if fs.GetObjectType and fs:GetObjectType() == "FontString" then U.SafeCall(Decide, fs) end
    end
end

function F.Restore()
    UADD.AceFont.Stop(APP)
    UADD.AceFont.Stop(TIP)
end

function F.Count() return UADD.AceFont.Count(APP) + UADD.AceFont.Count(TIP) end
