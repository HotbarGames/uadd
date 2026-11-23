-- The header line of each Questie options tab («Загальні налаштування») gets our Cyrillic font, so
-- "і", "ї", "є" and "ґ" are not boxes.
--
-- Questie draws the tab name with Blizzard's shared font object Game13Font (12.13: one subtitle on
-- canvas.content, QuestieOptionsEngine.lua:211-226; before: "Questie • <name>"). In the client that is a font family whose
-- Cyrillic part has Russian letters only: "Загальн□ налаштування". Copying the family and setting
-- a font on the copy changes only its Latin part, so the boxes stay. What works (UALLF found this
-- in game, UALLF/Fonts.lua) is a brand-new font object with only our font file in it.
--
-- So we make one private font object like Game13Font (same size, outline, colour and shadow) and
-- put it on Questie's own header FontStrings. Game13Font itself is never changed. Questie builds a
-- tab the first time it is shown, a little later (a coroutine), so we look again for a few
-- seconds after each show. "/uadd questie off" puts Game13Font and the colour back at once.
-- Below: the same for the Ukrainian buttons of a tab and the dropdown lists of the older window.

local _, ns = ...
local H = {}
ns.HeaderFont = H

local FONT_OBJECT = "UADD_QuestieHeaderFont"
local MODES = { "Popup", "Blizz" }          -- QuestieOptionsEngine.lua:154
local BULLET = "\226\128\162"               -- "•", the FontString just before the tab name (before 12.13)
local TRIES, STEP = 50, 0.1                 -- look for a new header for up to 5 seconds

local active = false
local hooked = {}       -- canvas -> true once we hooked its OnShow
local changed = {}      -- FontString -> { font object, r, g, b, a } from before our change
local ours
local Buttons           -- set below: our font on the Ukrainian buttons of a canvas

local function Engine()
    local ok, mod = pcall(function() return QuestieLoader:ImportModule("QuestieOptionsEngine") end)
    return ok and type(mod) == "table" and mod or nil
end

local function Shared()
    return rawget(_G, "Game13Font")
end

-- Our copy of Game13Font with only the Cyrillic font file in it. Nil without a Cyrillic font.
-- A font object's SetFont gives back nothing in the client, so we ask GetFont whether ours took.
local function Ours()
    if ours then return ours end
    local base, path = Shared(), UADD.CyrFontPath()
    if not (base and path) then return nil end
    local _, size, flags = base:GetFont()
    local f = rawget(_G, FONT_OBJECT) or CreateFont(FONT_OBJECT)   -- one name, made once
    pcall(f.SetFont, f, path, size or 13, flags or "")
    if not UADD.IsCyrFont((f:GetFont())) then return nil end
    f:SetTextColor(base:GetTextColor())
    f:SetShadowColor(base:GetShadowColor())
    f:SetShadowOffset(base:GetShadowOffset())
    ours = f
    return ours
end

local function IsHeaderText(r, base)
    if not (r.GetObjectType and r:GetObjectType() == "FontString") then return false end
    local text = UADD.Plain(r:GetText())
    if type(text) ~= "string" or text == "" or text == BULLET then return false end
    if r:GetFontObject() == base then return true end
    -- If the client hides the inherited font object, the tab name is still the one after the bullet.
    local _, rel = r:GetPoint(1)
    return type(rel) == "table" and rel.GetText ~= nil and UADD.Plain(rel:GetText()) == BULLET
end

-- The regions that can hold the header: the canvas's own (Questie before 12.8) and those of
-- canvas.content, the frame Questie 12.8 builds the header on (QuestieOptionsEngine.lua:172-193, 280-284).
local function HeaderRegions(canvas)
    local out = { canvas:GetRegions() }
    local content = rawget(canvas, "content")
    if type(content) == "table" and content.GetRegions then
        for _, r in ipairs({ content:GetRegions() }) do out[#out + 1] = r end
    end
    return out
end

local CYR = "[\208-\210]"   -- the first byte of a Cyrillic letter in UTF-8 (А-я, і, ї, є, ґ)

-- With us off: Game13Font and the old colour back on a header we changed, unless it still shows
-- Cyrillic (the font follows the text). An error reading the text counts as English.
local function GiveBack(fs)
    local old = changed[fs]
    if active or not old then return end
    local ok, t = pcall(function() return UADD.Plain(fs:GetText()) end)
    if ok and type(t) == "string" and t:find(CYR) then return end
    changed[fs] = nil
    pcall(fs.SetFontObject, fs, old[1])
    pcall(fs.SetTextColor, fs, old[2], old[3], old[4], old[5])
end

local hookedHeader = {}     -- header FontString -> true once its SetText is hooked

-- Puts our font on the header FontStrings of one canvas. Returns true once its header exists.
local function Apply(canvas)
    local base, font = Shared(), Ours()
    if not (active and base and font) then return true end
    local found = false
    for _, r in ipairs(HeaderRegions(canvas)) do
        if changed[r] then
            found = true
        elseif IsHeaderText(r, base) then
            local red, green, blue, alpha = r:GetTextColor()
            changed[r] = { r:GetFontObject() or base, red, green, blue, alpha }
            if not hookedHeader[r] then
                hookedHeader[r] = true
                hooksecurefunc(r, "SetText", function(self) pcall(GiveBack, self) end)
            end
            r:SetFontObject(font)
            r:SetTextColor(red, green, blue, alpha)   -- SetFontObject may reset the colour
            found = true
        end
    end
    return found
end

-- Questie 12.8 builds a tab over several frames: the header first, the buttons later. The build is
-- done once Questie sets canvas.UpdateScrollLayout (12.13: QuestieOptionsEngine.lua:400), so until then we
-- keep looking for new buttons. Questie before 12.8 has no canvas.content: nothing to wait for.
local function Building(canvas)
    return rawget(canvas, "content") ~= nil and rawget(canvas, "UpdateScrollLayout") == nil
end

local function Look(canvas, left)
    if not active then return end
    local ok, done = pcall(Apply, canvas)
    if ok and done then
        pcall(Buttons, canvas)
        if ns.ControlFont then UADD.SafeCall(ns.ControlFont.Canvas, canvas) end   -- 12.8's labels
    end
    -- A long tab can take more than TRIES steps to build: while it is still building and shown we
    -- keep looking without counting down (a failed build clears canvas.content, so this ends).
    local building = ok and done and Building(canvas) and canvas:IsShown()
    if building then
        C_Timer.After(STEP, function() Look(canvas, left) end)
    elseif ok and not done and left > 0 then
        C_Timer.After(STEP, function() Look(canvas, left - 1) end)
    end
end

-- Questie 12.13's search (SetSearchText) builds each shown popup tab again while the old content stays
-- shown, then swaps the new content and controls in (QuestieOptionsEngine.lua:532-574): no OnShow, and
-- canvas.UpdateScrollLayout stays set. So we look at such a tab every step until its new content is in,
-- and a few steps more for the controls it gets later (a failed build: TRIES steps at most).
local function Rebuilt(canvas, old, left, after)
    if not active or not canvas:IsShown() then return end
    local swapped = rawget(canvas, "content") ~= old
    pcall(Apply, canvas)
    pcall(Buttons, canvas)
    if ns.ControlFont then UADD.SafeCall(ns.ControlFont.Canvas, canvas) end
    if swapped then after = after - 1 else left = left - 1 end
    if left > 0 and after > 0 then C_Timer.After(STEP, function() Rebuilt(canvas, old, left, after) end) end
end

local function Searched()
    if not active then return end
    for key in pairs((Engine() or {}).tabs or {}) do
        local canvas = rawget(_G, "QuestieOptionsTab_Popup_" .. tostring(key))
        if type(canvas) == "table" and canvas.IsShown and canvas:IsShown() then
            Rebuilt(canvas, rawget(canvas, "content"), TRIES, 5)
        end
    end
end

-- ── The rest of Questie's older options window: dropdowns, check boxes, headings ──────────────
-- That window is built by AceConfigDialog (Modules/Options/QuestieOptions.lua:59-67). Its widgets
-- draw with GameFontNormalSmall / GameFontHighlightSmall (a dropdown's list items, its closed
-- value, AceGUIWidget-DropDown-Items.lua:179), which have no "і", "ї", "є", "ґ" on an English
-- client: "Нежить, чоловік" would get boxes. UADD/AceFont.lua puts our font file on each such
-- FontString of Questie's widgets and gives the old font back exactly when AceGUI releases the
-- widget to its shared pool, when its text has no Cyrillic, and on "/uadd questie off".

local AF = UADD.AceFont

local function InCombat() return InCombatLockdown and InCombatLockdown() end

-- The buttons on Questie's tab canvases ("Моя подорож" in Questie's own window) use
-- GameFontHighlight, which Questie puts back on every SetText (QuestieOptionsControls.lua:929),
-- so ours goes on again after each SetText. Questie sizes the button inside that SetText, with
-- GameFontHighlight, before our hook runs; calling it again would only reset the font, so the
-- width stays Questie's (our font file has about the same letter widths). Only buttons that show
-- Cyrillic text.
local hookedButton = {}

local function ApplyButton(button)
    local fs = button:GetFontString()
    local text = fs and UADD.Plain(fs:GetText())
    if not fs or InCombat() then return end
    local C = ns.ControlFont                 -- its C.Set / C.Back: right whether or not the client keeps a hand-set file
    -- The font follows the text, off too: Ukrainian left until /reload keeps ours (ControlFont's Decide).
    if type(text) == "string" and text:find(CYR) then C.Set(fs) else C.Back(fs) end
end

Buttons = function(canvas)
    if InCombat() then return end
    for _, control in ipairs(type(canvas.controls) == "table" and canvas.controls or {}) do
        local b = type(control) == "table" and control.widget
        if type(b) == "table" and b.GetFontString then
            if not hookedButton[b] then
                hookedButton[b] = true
                hooksecurefunc(b, "SetText", function(self) UADD.SafeCall(ApplyButton, self) end)
            end
            ApplyButton(b)
        end
    end
end

-- For the checks: how many dropdown list items have our font now.
function H.ItemCount() return AF.Count("Questie", "^Dropdown%-Item") end

-- Finds Questie's canvases (Blizzard's settings panel and Questie's own window) and hooks them.
-- onlyNew: look at once only at a shown canvas we hook now (an old one's OnShow already looked).
local HookPanel
function H.Scan(onlyNew)
    if not active then return end
    AF.Hook()
    HookPanel()
    local E = Engine()
    if not (E and type(E.tabs) == "table") then return end
    -- 12.13's own window has a search label («Пошук», GameFontNormalSmall: QuestieOptionsWindow.lua:28-31).
    local popup = rawget(E, "popup")
    if type(popup) == "table" and ns.ControlFont then ns.ControlFont.Label(rawget(popup, "searchLabel")) end
    for key in pairs(E.tabs) do
        for _, mode in ipairs(MODES) do
            local canvas = rawget(_G, "QuestieOptionsTab_" .. mode .. "_" .. tostring(key))
            if type(canvas) == "table" and canvas.HookScript then
                local new = not hooked[canvas]
                if new then
                    hooked[canvas] = true
                    canvas:HookScript("OnShow", function(self) Look(self, TRIES) end)
                end
                if (new or not onlyNew) and canvas:IsShown() then Look(canvas, TRIES) end
            end
        end
    end
end

-- Questie may make a settings canvas after its OnReady, when we scanned. So we scan again each
-- time the game's settings window opens or a category in it is picked: a few name lookups, no
-- ticker. A canvas shown by that pick gets its look right there.
local panelHooked = false
HookPanel = function()
    local panel = rawget(_G, "SettingsPanel")
    if panelHooked or type(panel) ~= "table" or not panel.HookScript then return end
    panelHooked = true
    local function Rescan() if active then UADD.SafeCall(H.Scan, true) end end
    panel:HookScript("OnShow", Rescan)
    if type(panel.SelectCategory) == "function" then hooksecurefunc(panel, "SelectCategory", Rescan) end
end

local engineHooked = false

-- Called at our start-up when the module is on, and again once Questie is ready.
function H.Start()
    active = true
    if ns.ControlFont then ns.ControlFont.Start() end
    AF.Register("Questie", function() return active end)
    local E = Engine()
    if E and not engineHooked and type(E.ShowFrame) == "function" then
        engineHooked = true
        -- Questie's own window makes its canvases on first open and shows the first one at once.
        -- 12.13's window has a search label («Пошук», GameFontNormalSmall: QuestieOptionsWindow.lua:28-31).
        hooksecurefunc(E, "ShowFrame", function() if active then H.Scan() end end)
        if type(E.SetSearchText) == "function" then
            hooksecurefunc(E, "SetSearchText", function() UADD.SafeCall(Searched) end)
        end
    end
    H.Scan()
end

-- "/uadd questie off": Game13Font and the old colour go back on every header we changed that shows
-- English, and the old font on every dropdown item. The font follows the text: a header that still
-- shows our Ukrainian (Questie sets it once, at build; it stays until /reload) keeps ours, and gets
-- Game13Font back from its SetText hook (Apply) once its text turns English. An error: Game13Font back.
function H.Stop()
    active = false
    if ns.ControlFont then ns.ControlFont.Stop() end   -- the labels, values, buttons and menu entries
    AF.Stop("Questie")                  -- the older AceConfigDialog window (before 12.12)
    local list = {}
    for fs in pairs(changed) do list[#list + 1] = fs end
    for _, fs in ipairs(list) do GiveBack(fs) end
end

-- For the checks: how many header FontStrings have our font now.
function H.Count()
    local n = 0
    for fs in pairs(changed) do
        if fs:GetFontObject() == ours then n = n + 1 end
    end
    return n
end
