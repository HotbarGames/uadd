-- A font with Ukrainian letters for our words in TomTom (the same way as the other modules).
--   * TomTom's texts use the game's font objects (Latin letters only on an English client). A
--     FontString that shows Cyrillic gets UADD's Cyrillic font file at the size and with the flags it
--     has now, on that one FontString (UADD/AceFont.lua). Shared font objects are never changed.
--   * Each FontString is hooked once (SetText, SetFormattedText; a button's own setters too) and
--     decides again on each new text: Cyrillic gets ours, anything else gets its own font back.
--   * Where: TomTom's own frames (the arrow, the coordinate block, the paste window, made late: found
--     when it is made), its settings pages (Settings.lua adds them), the category list of the game's
--     settings window (our page names), its pop-ups, the menus it opens, and the lines of its tooltips
--     that already hold Ukrainian (from TomTom.L): TomTomTooltip, GameTooltip when TomTom's code shows
--     it or its owner is ours, SettingsTooltip over our pages. A tooltip line gets UADD's Cyrillic font
--     object (SetFontObject), never a file by hand, and its own object back when the tooltip clears.
--   * Read back: F.Count counts only the FontStrings whose font file really is ours now (lesson 2).
--   * "/uadd tomtom off" and the hold key put back exactly what TomTom had.

local _, ns = ...
local U = UADD
local F = {}
ns.Fonts = F

local APP = "TomTom"
local tipFonts = {}                            -- tooltip line FontString -> its own font (U.SaveFont)
local CYR = "[\208-\210]"                      -- the first byte of a Cyrillic letter in UTF-8
local ROOTS = { "TomTomCrazyArrow", "TomTomBlock", "TomTomPaste" }
local LATE = { TomTomPaste = true }             -- made when first opened
local hooked, own, hookedRoot, roots, seen = {}, {}, {}, {}, {}
local tipBusy, tipHooked, menuHooked, popupHooked, frameHooked, panelHooked = false, false, false, false, false,
    false
local lateLeft = 1

local function Cyr(s) s = U.Plain(s) return s ~= nil and s:find(CYR) ~= nil end

-- Was this called from TomTom's code? (Our hooks run right after it.)
local function FromTomTom()
    local ok, st = pcall(debugstack, 2, 20, 0)
    return ok and type(st) == "string" and st:find(ns.FROM) ~= nil
end
F.FromTomTom = FromTomTom

local Decide
Decide = function(fs)
    if type(fs) ~= "table" or not fs.GetText then return end
    local t = U.Plain(fs:GetText())
    if ns.On() and t and t:find(CYR) then
        UADD.AceFont.Set(fs, APP, Decide)
    else
        UADD.AceFont.Back(fs)
        if own[fs] and t and ns.WordsWanted() and t:find("%a%a%a") then U.Missed("tomtom", t, fs) end
    end
end
F.Decide = Decide                              -- what a hooked SetText runs (the harness times it)

local mine = false                             -- walking one of TomTom's own frames (for U.Missed)

local function HookFs(fs)
    if mine then own[fs] = true end
    if hooked[fs] or U.Locked(fs) then return end   -- a game menu's row: lent out, left unhooked (lesson 38)
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
    -- a button draws its new label without the label's SetText; its states' fonts are the core's (ButtonFont.lua)
    for _, m in ipairs({ "SetText", "SetFormattedText" }) do
        if b[m] then hooksecurefunc(b, m, OnButton) end
    end
end

local function Walk(f)
    if seen[f] or type(f) ~= "table" or not f.GetObjectType then return end
    seen[f] = true
    if f.IsProtected and f:IsProtected() then return end
    local kind = f:GetObjectType()
    if kind == "EditBox" then return end                    -- what the player types: never ours
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

-- Our font on every shown text of frame f. isOwn: f is TomTom's (its English left is reported missed).
local function Look(f, isOwn)
    if not ns.On() or type(f) ~= "table" then return end
    wipe(seen)
    mine = isOwn and true or false
    local ok, err = pcall(Walk, f)
    mine = false
    wipe(seen)
    if not ok then error(err, 0) end
end
F.Look = Look
function F.LookOwn(f) return Look(f, true) end

local function OnRoot(f) U.SafeCall(Look, f, true) end

-- A frame of ours (Settings.lua adds its pages): looked at whenever it shows.
function F.AddRoot(f)
    if type(f) ~= "table" then return end
    roots[f] = true
    if not hookedRoot[f] and f.HookScript then
        hookedRoot[f] = true
        f:HookScript("OnShow", OnRoot)
    end
end

local function Collect()
    for _, name in ipairs(ROOTS) do
        local f = rawget(_G, name)
        if type(f) == "table" and f.GetObjectType then
            if LATE[name] and not roots[f] then lateLeft = lateLeft - 1 end
            F.AddRoot(f)
        end
    end
end

-- Is frame f (or one of its parents) ours?
local function Ours(f)
    for _ = 1, 30 do
        if type(f) ~= "table" then return false end
        if roots[f] then return true end
        local n = f.GetName and f:GetName()
        if type(n) == "string" and n:find("^TomTom") then return true end
        f = f.GetParent and f:GetParent()
    end
    return false
end
F.Ours = Ours

-- ── Tooltips, pop-ups, menus, the settings category list ──────────────────────────────────────

local SIDES = { "Left", "Right" }

-- The lines of a tooltip that show Ukrainian in a font without our letters (nil: none). Cheap, so it
-- comes first: most of the game's tooltips have none (English, or UALL Forever's in its own font).
local function Needs(tip)
    local name, list = tip.GetName and tip:GetName(), nil
    if not name then return nil end
    for i = 1, tip:NumLines() do
        for _, side in ipairs(SIDES) do
            local fs = _G[name .. "Text" .. side .. i]
            if fs and fs:IsShown() and Cyr(fs:GetText()) and not U.IsCyrFont((fs:GetFont()))
                and not tipFonts[fs] then
                list = list or {}
                list[#list + 1] = fs
            end
        end
    end
    return list
end

-- A game tooltip line is never given a file by hand (lesson 18 again, lesson 44): UADD's Cyrillic font
-- object goes on with SetFontObject (read back); its own object comes back with U.FontBack (TipBack).
-- A line that keeps a file set by hand before us (our object is on, its file stayed: lesson 44) has no
-- family left to lose: our file goes on by hand (U.CyrOnOwn), and U.FontBack puts that same file back.
local function Kept(fs)
    local o = fs.GetFontObject and fs:GetFontObject()
    local ok, n = pcall(function() return o:GetName() end)
    return ok and type(n) == "string" and n:find("^UADD_CyrFont") ~= nil
end

local function FixTip(tip, list)
    for _, fs in ipairs(list) do
        local was = U.SaveFont(fs)                        -- saved before ours goes on (lesson 32)
        tipFonts[fs] = was
        if not (U.CyrOnLocked(fs) or Kept(fs) and U.CyrOnOwn(fs, was)) then   -- ours did not take: its own font
            U.FontBack(fs, was)
            tipFonts[fs] = nil
        end
    end
    tipBusy = true
    pcall(tip.Show, tip)                                  -- laid out again in the new font
    tipBusy = false
end

-- Each GameTooltip:Show of the game comes here: the cheap tests first, the stack (debugstack) last and
-- only for a tooltip with a line to fix (lesson 12).
local function OnTip(tip, always)
    if tipBusy or not ns.On() or type(tip) ~= "table" or not tip.NumLines then return end
    if not always and tip.GetItem and tip:GetItem() then return end   -- an item's tooltip: never ours
    local list = Needs(tip)
    if not list then return end
    if not always and not Ours(tip.GetOwner and tip:GetOwner()) and not FromTomTom() then return end
    FixTip(tip, list)
end
F.OnTip = OnTip

local function TipBack()
    if next(tipFonts) == nil then return end
    for fs, was in pairs(tipFonts) do pcall(U.FontBack, fs, was) end
    wipe(tipFonts)
end

local function HookTip(tip, always)
    if type(tip) ~= "table" or hooked[tip] then return end
    hooked[tip] = true
    hooksecurefunc(tip, "Show", function(t) U.SafeCall(OnTip, t, always) end)
    tip:HookScript("OnTooltipCleared", function(t) U.SafeCall(TipBack, t) end)
    tip:HookScript("OnHide", function(t) U.SafeCall(TipBack, t) end)
end

local function OnMenu(owner)
    if not ns.On() or not (Ours(owner) or FromTomTom()) then return end
    local m = Menu and Menu.GetManager and Menu.GetManager()
    local open = m and m.GetOpenMenu and m:GetOpenMenu()
    if open then U.SafeCall(Look, open) end
end

local function OnPopup(which)
    if not ns.On() or not ns.Popups.Ours(which) then return end
    for i = 1, (STATICPOPUP_NUMDIALOGS or 4) do
        local d = _G["StaticPopup" .. i]
        if d and d.IsShown and d:IsShown() and d.which == which then U.SafeCall(Look, d) end
    end
end

-- The game's settings window: the left list holds our page names.
local function OnPanel()
    local p = rawget(_G, "SettingsPanel")
    local list = p and p.CategoryList
    if list and list.IsVisible and list:IsVisible() then U.SafeCall(Look, list) end
end

function F.Install()
    Collect()
    if not tipHooked then
        tipHooked = true
        local tt = rawget(_G, "TomTomTooltip")
        if tt then HookTip(tt, true) end
        if GameTooltip then HookTip(GameTooltip, false) end
        local st = rawget(_G, "SettingsTooltip")
        if st then HookTip(st, false) end
    end
    if not menuHooked and MenuUtil and type(MenuUtil.CreateContextMenu) == "function" then
        menuHooked = true
        hooksecurefunc(MenuUtil, "CreateContextMenu", function(owner) U.SafeCall(OnMenu, owner) end)
    end
    if not popupHooked and type(StaticPopup_Show) == "function" then
        popupHooked = true
        hooksecurefunc("StaticPopup_Show", function(which) U.SafeCall(OnPopup, which) end)
    end
    -- A window TomTom makes late (the paste window): found by its name when it is made.
    if not frameHooked and lateLeft > 0 then
        frameHooked = true
        U.OnNewFrame(function(_, name)                -- the core hook, under U.SafeCall (lesson 35)
            if lateLeft > 0 and type(name) == "string" and LATE[name] then
                C_Timer.After(0, function() U.SafeCall(Collect) U.SafeCall(F.Scan) end)
            end
        end)
    end
    local p = rawget(_G, "SettingsPanel")
    if not panelHooked and p and p.HookScript then
        panelHooked = true
        p:HookScript("OnShow", function() C_Timer.After(0, OnPanel) end)
        if type(p.SelectCategory) == "function" then hooksecurefunc(p, "SelectCategory", OnPanel) end
    end
end

-- Our font on every shown text of the shown frames of ours.
function F.Scan()
    if not ns.On() then return end
    Collect()
    for f in pairs(roots) do
        if f.IsVisible and f:IsVisible() then U.SafeCall(Look, f, true) end
    end
end

-- Decide again for every FontString hooked so far (after the words changed: hold key, on, off).
function F.Sync()
    for fs in pairs(hooked) do
        if fs.GetObjectType and fs:GetObjectType() == "FontString" then U.SafeCall(Decide, fs) end
    end
end

-- Every font back as TomTom had it.
function F.Restore()
    UADD.AceFont.Stop(APP)
    TipBack()
end

-- FontStrings in our font now, read back from the game.
function F.Count()
    local n = UADD.AceFont.Count(APP)
    for fs in pairs(tipFonts) do if U.IsCyrFont((fs:GetFont())) then n = n + 1 end end
    return n
end
