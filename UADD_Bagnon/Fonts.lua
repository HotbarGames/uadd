-- A font with Ukrainian letters for our words in Bagnon (the same way as the other modules).
--   * Bagnon's texts use the game's font objects (Latin letters only on an English client). A
--     FontString that shows Cyrillic gets UADD's Cyrillic font file at the size and with the flags it
--     has now, on that one FontString (UADD/AceFont.lua). Shared font objects are never changed.
--   * Each FontString is hooked once (SetText, SetFormattedText; a button's own text and font object
--     setters too) and decides again on each new text: Cyrillic gets ours, anything else gets its own
--     font back, exactly as it was.
--   * Where: Bagnon's windows (bags, bank, guild bank: found in its Frames registry, hooked when one is
--     made), its settings pages (Bagnon_Config), its Sushi pop-ups, the menus it opens (right-click
--     menus: the first level), and GameTooltip lines while the tooltip's owner is inside a Bagnon window
--     and shows no item.
--   * Read back: F.Count counts only the FontStrings whose font file really is ours now (lesson 2).
--   * "/uadd bagnon off" and the hold key put back exactly what Bagnon had.

local _, ns = ...
local U = UADD
local F = {}
ns.Fonts = F

local APP, TIP = "Bagnon", "Bagnon tooltip"
local CYR = "[\208-\210]"                      -- the first byte of a Cyrillic letter in UTF-8
local NAME = "Bagnon"
local PANELS = { "GeneralOptions", "FrameOptions", "DisplayOptions", "SlotOptions", "Help", "Patrons" }
local hooked, hookedRoot, roots, seen = {}, {}, {}, {}
local NONE = {}                                -- no pop-ups (one table, so a miss makes no garbage)
local tipBusy, tipHooked, frameHooked, menuHooked, popupHooked = false, false, false, false, false

local function Addon() local a = rawget(_G, NAME) return type(a) == "table" and a or nil end
local function Sushi() return LibStub and LibStub("Sushi-3.2", true) end

local function Cyr(s) s = U.Plain(s) return s ~= nil and s:find(CYR) ~= nil end

local Decide
Decide = function(fs)
    if type(fs) ~= "table" or not fs.GetText then return end
    local t = U.Plain(fs:GetText())
    if ns.On() and t and t:find(CYR) then
        UADD.AceFont.Set(fs, APP, Decide)
    else
        UADD.AceFont.Back(fs)
        if t and ns.WordsWanted() and t:find("%a%a%a") then U.Missed("bagnon", t, fs) end
    end
end

F.Decide = Decide                              -- what a hooked SetText runs (the harness times it)

-- What the hooks run: through U.SafeCall, so an error of ours never reaches the game (the text stays as set).
local function OnSet(fs) U.SafeCall(F.Decide, fs) end

local function HookFs(fs)
    if hooked[fs] then return end
    hooked[fs] = true
    hooksecurefunc(fs, "SetText", OnSet)
    hooksecurefunc(fs, "SetFormattedText", OnSet)
end

local function OnButton(b)
    local fs = b.GetFontString and b:GetFontString()
    if fs then HookFs(fs) Decide(fs) end
end

local function OnButtonSet(b) U.SafeCall(OnButton, b) end

local function HookButton(b)
    if hooked[b] then return end
    hooked[b] = true
    for _, m in ipairs({ "SetText", "SetFormattedText", "SetNormalFontObject", "SetHighlightFontObject",
        "SetDisabledFontObject" }) do
        if b[m] then hooksecurefunc(b, m, OnButtonSet) end
    end
end

local function Walk(f)
    if seen[f] or type(f) ~= "table" or not f.GetObjectType then return end
    seen[f] = true
    if f.IsProtected and f:IsProtected() then return end    -- item slots: no words of ours
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

-- Bagnon's open windows and settings pages.
local function Collect()
    wipe(roots)
    local A = Addon()
    if not A then return end
    local reg = type(A.Frames) == "table" and A.Frames.Registry
    for _, f in ipairs(type(reg) == "table" and reg or {}) do
        if rawget(f, 0) then roots[f] = true end
    end
    for _, id in ipairs(PANELS) do
        local p = rawget(A, id)
        if type(p) == "table" and p.GetObjectType then roots[p] = true end
    end
    for f in pairs(roots) do
        if not hookedRoot[f] and f.HookScript then
            hookedRoot[f] = true
            f:HookScript("OnShow", OnRoot)
            if type(f.UpdateChildren) == "function" then hooksecurefunc(f, "UpdateChildren", OnRoot) end
        end
    end
end

-- Is frame `f` (or one of its parents) a Bagnon window, page or pop-up?
local function Ours(f)
    local S = Sushi()
    local popups = S and S.Popup and S.Popup.Active or NONE
    for _ = 1, 30 do
        if type(f) ~= "table" then return false end
        if roots[f] then return true end
        for _, p in ipairs(popups) do if p == f then return true end end
        f = f.GetParent and f:GetParent()
    end
    return false
end
F.Ours = Ours

-- ── Tooltips, pop-ups and menus ───────────────────────────────────────────────────────────────

local function OnTip(tip)
    if tipBusy or not ns.On() then return end
    if tip.GetItem and tip:GetItem() then return end       -- an item's tooltip: never ours
    if not Ours(tip:GetOwner()) then return end
    local name, any = tip:GetName(), false
    if ns.Game then U.SafeCall(ns.Game.Tip, tip, name) end    -- the game's words from UALL Forever
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
        pcall(tip.Show, tip)                              -- laid out again in the new font
        tipBusy = false
    end
end

local function TipBack() U.SafeCall(UADD.AceFont.Stop, TIP) end

local function OnMenu(owner)
    if not ns.On() or not Ours(owner) then return end
    local m = Menu and Menu.GetManager and Menu.GetManager()
    local open = m and m.GetOpenMenu and m:GetOpenMenu()
    if open then U.SafeCall(Look, open) end
end

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
    local A = Addon()
    if not frameHooked and A and type(A.Frames) == "table" and type(A.Frames.New) == "function" then
        frameHooked = true
        hooksecurefunc(A.Frames, "New", function() U.SafeCall(F.Scan) end)
    end
    if not tipHooked and GameTooltip then
        tipHooked = true
        hooksecurefunc(GameTooltip, "Show", function(tip) U.SafeCall(OnTip, tip) end)
        GameTooltip:HookScript("OnTooltipCleared", function(t) U.SafeCall(TipBack, t) end)
        GameTooltip:HookScript("OnHide", function(t) U.SafeCall(TipBack, t) end)
    end
    if not menuHooked and MenuUtil and type(MenuUtil.CreateContextMenu) == "function" then
        menuHooked = true
        hooksecurefunc(MenuUtil, "CreateContextMenu", function(owner) U.SafeCall(OnMenu, owner) end)
    end
    local S = Sushi()
    if not popupHooked and S and type(S.Popup) == "table" and type(S.Popup.New) == "function" then
        popupHooked = true
        hooksecurefunc(S.Popup, "New", function() U.SafeCall(OnPopup) end)
    end
end

-- Our font on every shown text of the shown windows and pages.
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

-- Every font back as Bagnon had it.
function F.Restore()
    UADD.AceFont.Stop(APP)
    UADD.AceFont.Stop(TIP)
end

-- FontStrings in our font now, read back from the game.
function F.Count() return UADD.AceFont.Count(APP) + UADD.AceFont.Count(TIP) end
