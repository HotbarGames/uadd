-- Our Cyrillic font on the texts of Questie 12.8's own options controls.
--
-- Since 12.8 Questie draws every setting with its own controls (QuestieOptionsControls.lua), not
-- with AceConfigDialog, so UADD/AceFont.lua's AceGUI part does not reach them. Their fonts: row
-- and divider titles GameFontNormalMed1, descriptions GameFontHighlightSmall (:139-180), container
-- and dropdown titles GameFontNormal (:493, :757), slider texts GameFontNormalSmall2 and
-- GameFontDisableTiny (:368-378), the dropdown's chosen value (WowStyle1Dropdown) and the entries
-- of the game's menu a dropdown opens. On an English client none of them has "і", "ї", "є", "ґ".
--
-- So each FontString of a control that shows Cyrillic gets our font file, at its own size and
-- flags (AF.Set: one FontString, never a shared font object; AF.Back puts its own back exactly).
--   * HeaderFont.lua's Look calls C.Canvas(canvas) each time a tab is shown and while it is built.
--   * Each FontString we handle has its SetText hooked: Ukrainian text gets ours, other text (the
--     English shown while the show-original key is held, UADD/Original.lua) gets its own font back.
--     A font set by someone else (a reset, a frame used again) is decided again (AF.Set's callback).
--   * The game's menu: its entry frames are shared by every addon's menus, so ours goes only on
--     entries of an open Questie dropdown, and comes off when such a frame shows other text.
--   * "/uadd questie off": AF.Stop("Questie") (HeaderFont.Stop) puts every font back.
--   * Nothing in combat: what was asked for then is done on PLAYER_REGEN_ENABLED.
-- Questie before 12.8 has no canvas.content: left to HeaderFont.lua and UADD/AceFont.lua.

local _, ns = ...
local C = {}
ns.ControlFont = C

local AF = UADD.AceFont
local APP = "Questie"                       -- the same owner as HeaderFont's: one AF.Stop for all
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

-- One FontString as it should be now: ours on Ukrainian text while we are on, its own font else.
local Decide
Decide = function(fs)
    if InCombat() then
        pending[fs] = true
        return Wait()
    end
    pending[fs] = nil
    if active and HasCyr(fs) and (kindOf[fs] ~= "menu" or MenuOpen()) then
        AF.Set(fs, APP, Decide)
    else
        AF.Back(fs)
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

function C.Start() active = true end

-- With us off the hooks only put fonts back; AF.Stop("Questie") (HeaderFont.Stop) does the rest.
-- Every control is walked again after the next "on" (HeaderFont.Start scans the shown canvases,
-- the hidden ones when shown): AF.Stop put their fonts back, and Questie may not set their text again.
function C.Stop()
    active = false
    openDrop, pending, rescan = nil, {}, false
    walked = setmetatable({}, { __mode = "k" })
end
