-- Our Cyrillic font on the texts of Questie 12.8's own options controls.
--
-- Since 12.8 Questie draws every setting with its own controls (QuestieOptionsControls.lua), not
-- with AceConfigDialog, so UADD/AceFont.lua's AceGUI part does not reach them. Their fonts: row
-- and divider titles GameFontNormalMed1, descriptions GameFontHighlightSmall (:139-180), container
-- and dropdown titles GameFontNormal (:493, :757), slider texts GameFontNormalSmall2 and
-- GameFontDisableTiny (:368-378), the dropdown's chosen value (WowStyle1Dropdown) and the entries
-- of the game's menu a dropdown opens. On an English client none of them has "і", "ї", "є", "ґ".
--
-- So each FontString of a control that shows Cyrillic gets our font, at its own size and flags
-- (C.Set: one FontString, never a shared font object; C.Back puts its own back exactly).
--   * HeaderFont.lua's Look calls C.Canvas(canvas) each time a tab is shown and while it is built.
--   * Each FontString we handle has its SetText hooked: Ukrainian text gets ours, other text (the
--     English shown while the show-original key is held, UADD/Original.lua) gets its own font back.
--     A font set by someone else (a reset, a frame used again) is decided again (OnFont).
--   * The game's menu: its entry frames are shared by every addon's menus, so ours goes only on
--     entries of an open Questie dropdown, and comes off when such a frame shows other text.
--   * "/uadd questie off": C.Stop (from HeaderFont.Stop) puts back the fonts of labels that show
--     English; one still Ukrainian keeps ours until its text turns English (the font follows the text).
--   * Nothing in combat: what was asked for then is done on PLAYER_REGEN_ENABLED.
-- Questie before 12.8 has no canvas.content: left to HeaderFont.lua and UADD/AceFont.lua.
--
-- The font (docs/LESSONS4.md, lesson 18 again after lesson 44): the client keeps a file set by hand
-- (SetFont) over a later SetFontObject. So ours goes on as a font object first (U.CyrOnLocked), and
-- by hand (U.CyrOnOwn, which marks `was.byhand`) only on a label set by hand before us or where the
-- object did not take; U.FontBack with that same `was` then puts the file back too. The font is
-- saved only while ours is not on (lesson 32), and every change is read back (lesson 2).

local _, ns = ...
local C = {}
ns.ControlFont = C

local CYR = "[\208-\210]"                   -- the first byte of a Cyrillic letter in UTF-8
local DEPTH, MENU_DEPTH = 4, 8              -- how deep we look into a control / an open menu

local active = false
local kindOf = {}                           -- FontString -> "control" or "menu" once SetText is hooked
local walked = setmetatable({}, { __mode = "k" })   -- control -> true once its texts are hooked
local hookedDrop = {}                       -- Questie dropdown -> true once its OpenMenu is hooked
local openDrop                              -- the Questie dropdown whose menu we saw open last
local pending = {}                          -- FontString -> true: changed in combat, decide later
local rescan = false                        -- a canvas was shown in combat
local waiter = CreateFrame("Frame")

local function InCombat() return InCombatLockdown and InCombatLockdown() end

local function IsFs(r)
    return type(r) == "table" and type(r.GetObjectType) == "function" and r:GetObjectType() == "FontString"
end

local function HasCyr(fs)
    local t = UADD.Plain(fs:GetText())
    return type(t) == "string" and t:find(CYR) ~= nil
end

local function Wait()
    waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
end

local function MenuOpen()
    local d = openDrop
    local ok, open = pcall(function() return d and d:IsMenuOpen() end)
    return ok and open and true or false
end

-- ── Our font on one FontString, and its own back ─────────────────────────────────────────────
local rec = {}          -- FontString -> its font before ours (U.SaveFont), while ours is on
local again = {}        -- FontString -> function(fs) that decides again after someone set a font
local hookedFs = {}     -- FontString -> true once its SetFont and SetFontObject are hooked
local busy = false      -- up while we change a font ourselves

local function Ours(fs)
    local ok, p = pcall(fs.GetFont, fs)
    return ok and UADD.IsCyrFont(p)
end

local function IsOurObject(o)
    local name = type(o) == "table" and o.GetName and o:GetName()
    return type(name) == "string" and name:find("^UADD_") ~= nil
end

-- Someone else set a font on a FontString of ours. Still ours (a file set by hand stays over their
-- object): the record is kept, with their new object to give back. Their font now: nothing to put
-- back. Either way the text is decided again.
local function OnFont(fs)
    if busy then return end
    local was = rec[fs]
    if was then
        if Ours(fs) then
            local o = UADD.SafeFontObject(fs)      -- one that may go back (lesson 47)
            if o and not IsOurObject(o) then was.object = o end
        else
            rec[fs] = nil
        end
    end
    local f = again[fs]
    if f and not InCombat() then UADD.SafeCall(f, fs) end
end

-- Ours on fs, at its size and flags; `redecide(fs)` runs after someone else sets a font on it.
function C.Set(fs, redecide)
    if type(fs) ~= "table" or not fs.GetFont or not UADD.CyrFontPath() then return end
    local locked = UADD.Locked(fs)
    again[fs] = redecide
    if not hookedFs[fs] and not locked then
        hookedFs[fs] = true
        hooksecurefunc(fs, "SetFont", OnFont)
        hooksecurefunc(fs, "SetFontObject", OnFont)
        if UADD.GuardWatch then UADD.GuardWatch(fs) end
    end
    local p = fs:GetFont()
    if not p or UADD.IsCyrFont(p) then return end      -- ours already: never save ours (lesson 32)
    local was = UADD.SaveFont(fs)
    if locked then was.own, was.locked = false, true end
    rec[fs] = was
    busy = true
    local ok, took = true, false
    if not was.own then ok, took = pcall(UADD.CyrOnLocked, fs) end   -- our font object
    if ok and not took and not locked then ok, took = pcall(UADD.CyrOnOwn, fs, was) end
    if not (ok and took and Ours(fs)) then              -- whole English, never half a font
        pcall(UADD.FontBack, fs, was)
        rec[fs] = nil
    end
    busy = false
end

-- fs's own font back (U.FontBack with the record of C.Set). A menu row the menu reset is left alone.
function C.Back(fs)
    local was = fs and rec[fs]
    if not was then return end
    rec[fs] = nil
    if was.locked and not Ours(fs) then return end
    busy = true
    pcall(UADD.FontBack, fs, was)
    busy = false
end

-- For the checks: the font fs had before ours (path, size, flags, font object), or nil.
function C.Original(fs)
    local r = rec[fs]
    if r then return r.path, r.size, r.flags, r.object end
end

-- For the status line and the checks: FontStrings in our font now.
function C.Count()
    local n = 0
    for fs in pairs(rec) do if Ours(fs) then n = n + 1 end end
    return n
end

-- One FontString as it should be now: the font follows the text. Ours on Ukrainian text, its own font
-- on any other. Off too: Questie's built windows keep our Ukrainian until /reload, so a label of ours
-- that still shows it keeps (or gets again) our font, and gets its own once its text turns English;
-- never Ukrainian in a font without Cyrillic. A menu row (shared by every addon's menus) gets ours only
-- in an open Questie dropdown while we are on; off, one still ours keeps it while its text is Ukrainian.
local Decide
Decide = function(fs)
    if InCombat() then
        pending[fs] = true
        return Wait()
    end
    pending[fs] = nil
    local cyr, menu = HasCyr(fs), kindOf[fs] == "menu"
    if cyr and (not menu or active and MenuOpen()) then
        C.Set(fs, Decide)
    elseif not (cyr and menu and not active and rec[fs]) then
        C.Back(fs)
    end
end

local function Track(fs, kind)
    if not kindOf[fs] then
        hooksecurefunc(fs, "SetText", function(self) UADD.SafeCall(Decide, self) end)
        kindOf[fs] = kind
    end
    Decide(fs)
end

-- The FontStrings of a frame and of its child frames, `depth` levels down. A child that is a
-- control itself (a container's rows) is skipped here: it is in canvas.controls too.
local function Collect(frame, depth, out)
    for _, r in ipairs({ frame:GetRegions() }) do
        if IsFs(r) then out[#out + 1] = r end
    end
    if depth <= 0 or not frame.GetChildren then return out end
    for _, child in ipairs({ frame:GetChildren() }) do
        if type(child) == "table" and rawget(child, "itemData") == nil and child.GetRegions then
            Collect(child, depth - 1, out)
        end
    end
    return out
end

-- A Questie dropdown opened its menu: ours on the entries that show Ukrainian.
local function OnOpen(dropdown)
    if not active then return end
    if InCombat() then return end           -- a menu opened in combat keeps the game's font
    openDrop = dropdown
    if not dropdown:IsMenuOpen() then return end
    local menu = rawget(dropdown, "menu")
    if type(menu) ~= "table" and Menu and Menu.GetManager then
        local ok, m = pcall(function() return Menu.GetManager():GetOpenMenu() end)
        menu = ok and m or nil
    end
    if type(menu) ~= "table" or not menu.GetRegions then return end
    for _, fs in ipairs(Collect(menu, MENU_DEPTH, {})) do
        if kindOf[fs] ~= "control" then Track(fs, "menu") end
    end
end

local function HookDropdown(w)
    -- Questie sets OpenMenu on the dropdown itself and the template's mixin copies IsMenuOpen onto
    -- it, so rawget finds both; other widgets (buttons, sliders) have neither and are skipped.
    if hookedDrop[w] or type(rawget(w, "OpenMenu")) ~= "function" or type(rawget(w, "IsMenuOpen")) ~= "function" then return end
    hookedDrop[w] = true
    hooksecurefunc(w, "OpenMenu", function(self) UADD.SafeCall(OnOpen, self) end)
end

-- The texts of one control. A row's title and description sit on a wrapper frame that Questie
-- parents to the row's parent, not to the row (QuestieOptionsControls.lua:101-106, 139-180), so a
-- walk of the row's own frames misses them: the row's references to them are taken too.
local LABELS = { "titleFrame", "descriptionFrame", "valueDisplay" }

local function Texts(control)
    local out = Collect(control, DEPTH, {})
    for _, key in ipairs(LABELS) do
        local fs = rawget(control, key)
        if IsFs(fs) then out[#out + 1] = fs end
    end
    return out
end

-- Every control of a Questie 12.8 canvas: hook and decide each of its texts once (once per "on").
function C.Canvas(canvas)
    if not active or rawget(canvas, "content") == nil then return end
    if InCombat() then
        rescan = true
        return Wait()
    end
    for _, control in ipairs(type(canvas.controls) == "table" and canvas.controls or {}) do
        if type(control) == "table" and control.GetRegions and not walked[control] then
            walked[control] = true
            for _, fs in ipairs(Texts(control)) do Track(fs, "control") end
            local w = rawget(control, "widget")
            if type(w) == "table" then HookDropdown(w) end
        end
    end
end

waiter:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    local list = pending
    pending = {}
    for fs in pairs(list) do UADD.SafeCall(Decide, fs) end
    if rescan then
        rescan = false
        if active and ns.HeaderFont then UADD.SafeCall(ns.HeaderFont.Scan) end
    end
end)

-- One more Questie label outside canvas.controls (the search label of its own window): tracked as a control.
function C.Label(fs)
    if active and IsFs(fs) and not InCombat() then Track(fs, "control") end
end

function C.Start() active = true end

-- Off: the font follows the text (Decide). A label that shows English now gets its own font back here;
-- one that still shows our Ukrainian (Questie does not set its text again before /reload) keeps ours,
-- and its SetText hook gives its own back once the text turns English. An error: its own font back.
-- Every control is walked again after the next "on" (HeaderFont.Start scans the shown canvases,
-- the hidden ones when shown): Questie may not set their text again.
function C.Stop()
    active = false
    openDrop, pending, rescan = nil, {}, false
    walked = setmetatable({}, { __mode = "k" })
    local list = {}
    for fs in pairs(rec) do list[#list + 1] = fs end
    for _, fs in ipairs(list) do
        local ok, cyr = pcall(HasCyr, fs)
        if not (ok and cyr) then C.Back(fs) end
    end
end
