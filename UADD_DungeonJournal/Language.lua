-- The journal's language. FDJ asks FDJ.GetLanguage() on every draw, so we wrap it: it says
-- "ukUA" while our language is chosen, and FDJ's own answer otherwise. FDJ.SetLanguage (its menu
-- and "/dj lang") is wrapped too, only to notice that the player chose another language.
--
-- Our language is chosen (Wants) when the module is on and either
--   * the player picked «Українська» in the journal's language menu (db.choice = "uk"), or
--   * nothing was picked since (db.choice = nil) and the journal's own saved language is English,
--     or "auto" on an English client (enUS, enGB): Ukrainian is the default. "auto" on any other
--     client is that client's language, so we step aside until «Українська» is picked.
-- Picking any other language sets db.choice = "other" and FDJ is left fully alone.
-- While the show-original key is held (UADD.OnOriginal) the journal shows English.
-- Our choice lives in UADD_DB; FDJ's saved language is never written by us.
--
-- A full redraw has no public entry in FDJ, so we press the menu's own English option with
-- the save switched off (quiet): FDJ then redraws everything for the language GetLanguage says.
-- That option plays FDJ's menu click and closes the menu, so it is pressed only for something the
-- player just did (picking «Українська», "/uadd dj on" / "off"); muting it would taint PlaySound.
-- Everything else (the hold key, names that arrive) uses L.Light: silent, but FDJ has no public
-- way to redo its labels (tabs, buttons), so those stay in the language they were drawn in.

local _, ns = ...
local L = { LOCALE = "ukUA", LABEL = "Українська" }
ns.Lang = L

local orig = {}
local installed = false
local quiet = false
local labelGuard = false
local entry                -- our button in the language menu
local dirty = false        -- a switch came while the journal window was shut: redraw it when it opens
local lastSaved, lastEnglish   -- FDJ's saved language at the last look, and whether it means English

local function FDJ() return rawget(_G, "ForeverDungeonJournal_NS") end
local function Frame() return rawget(_G, "ForeverDungeonJournalFrame") end

-- Does FDJ's saved language mean English? FDJ asks GetLanguage thousands of times in one search, so
-- the answer is kept until the saved value changes (or L.Forget); the client's language never does.
local function SavedEnglish(raw)
    if lastEnglish ~= nil and raw == lastSaved then return lastEnglish end
    local saved = raw ~= nil and tostring(raw):lower() or "auto"
    local english
    if saved == "auto" or saved == "" then
        -- "auto" is the client's language: English only on an English client. On a German or
        -- Russian client the journal is already in the player's language, so we step aside.
        local client = type(GetLocale) == "function" and GetLocale() or "enUS"
        english = client == "enUS" or client == "enGB"
    else
        english = saved == "enus" or saved == "engb" or saved == "en" or saved == "english"
    end
    lastSaved, lastEnglish = raw, english
    return english
end

function L.Forget() lastEnglish = nil end

function L.Wants()
    local db = ns.db
    if not (db and db.enabled and installed) then return false end
    if db.choice == "uk" then return true end
    if db.choice == "other" then return false end
    local fdb = rawget(_G, "ForeverDungeonJournalDB")
    return SavedEnglish(type(fdb) == "table" and fdb.language or nil)
end

function L.Active()
    return L.Wants() and not ns.held
end

local function GetLanguage(...)
    if L.Active() then return L.LOCALE end
    return orig.GetLanguage(...)
end

local function SetLanguage(...)
    if quiet then return orig.GetLanguage() end
    local db = ns.db
    if db and db.enabled then db.choice = "other" end
    -- Old fonts back now, before FDJ redraws and sets the fonts for the language just picked.
    if ns.Fonts then ns.Fonts.Restore() end
    if ns.Prose then ns.Prose.Restore() end
    L.Forget()
    return orig.SetLanguage(...)
end

function L.Install()
    local fdj = FDJ()
    if installed or not (fdj and type(fdj.GetLanguage) == "function" and type(fdj.Locales) == "table") then
        return installed
    end
    orig.GetLanguage, orig.SetLanguage = fdj.GetLanguage, fdj.SetLanguage
    fdj.GetLanguage = GetLanguage
    -- An older journal without SetLanguage: nothing to wrap, and then nothing can save a language.
    if type(orig.SetLanguage) == "function" then fdj.SetLanguage = SetLanguage end
    ns.Head.Install(fdj)                -- the header's level line (Head.lua)
    ns.Whole.Install(fdj)               -- free-text lines whole (Whole.lua)
    fdj.Locales[L.LOCALE] = ns.Content.Strings()
    if type(fdj.ContentLocales) == "table" then fdj.ContentLocales[L.LOCALE] = ns.Content.Build() end
    installed = true
    L.Forget()
    return true
end

-- Puts FDJ back as it was (where nobody wrapped our wrappers since; otherwise they stay and
-- only pass FDJ's answers through, because the module is off).
function L.Uninstall()
    local fdj = FDJ()
    if not (installed and fdj) then return end
    if fdj.GetLanguage == GetLanguage then fdj.GetLanguage = orig.GetLanguage end
    if fdj.SetLanguage == SetLanguage then fdj.SetLanguage = orig.SetLanguage end
    fdj.Locales[L.LOCALE] = nil
    if type(fdj.ContentLocales) == "table" then fdj.ContentLocales[L.LOCALE] = nil end
    installed = false
    ns.Head.Uninstall(fdj)              -- also the header's English back
    ns.Whole.Uninstall(fdj)
    L.Forget()
    if entry then L.ShowEntry(false) end
end

-- New names: a new content table (FDJ caches its free-text map per table).
function L.NewNames()
    local fdj = FDJ()
    if installed and fdj and type(fdj.ContentLocales) == "table" then
        fdj.ContentLocales[L.LOCALE] = ns.Content.Build()
    end
end

-- ── The selector label and the menu entry ─────────────────────────────────────────────────────

local function FixLabel(fs)
    if labelGuard or not L.Active() then return end
    if UADD.Plain(fs:GetText()) ~= L.LABEL then
        labelGuard = true
        fs:SetText(L.LABEL)
        labelGuard = false
    end
end

local function FdjOptions(menu)
    local r = {}
    for _, c in ipairs({ menu:GetChildren() }) do
        if c ~= entry and c.GetObjectType and c:GetObjectType() == "Button" then r[#r + 1] = c end
    end
    return r
end

-- The text on one of FDJ's option buttons (a FontString region; it has no field name).
local function OptionLabel(button)
    for _, r in ipairs({ button:GetRegions() }) do
        if r.GetObjectType and r:GetObjectType() == "FontString" then return UADD.Plain(r:GetText()) end
    end
    return nil
end

local function EnglishOption(menu)
    for _, b in ipairs(FdjOptions(menu)) do
        if OptionLabel(b) == "English" then return b end
    end
    return nil
end

-- FDJ's menu is 24 px per option + 10 tall, its rows 22 px apart from 5 px down, so there is room
-- left at the bottom; it only grows when our row would not fit with 5 px to spare.
local menuHeight
function L.ShowEntry(show)
    local f = Frame()
    local menu = f and f.languageMenu
    if not (menu and entry) or entry:IsShown() == show then return end
    entry:SetShown(show)
    if show then
        menuHeight = menu:GetHeight()
        local need = 5 + (#FdjOptions(menu) + 1) * 22 + 5
        if menuHeight < need then menu:SetHeight(need) end
    elseif menuHeight then
        menu:SetHeight(menuHeight)
    end
end

function L.AddEntry()
    local f = Frame()
    local menu = f and f.languageMenu
    if not menu then return false end
    if not entry then
        local n = #FdjOptions(menu)
        -- Laid out like FDJ's own rows: 6 px in from both sides, 21 high, text 10 px in.
        entry = CreateFrame("Button", nil, menu)
        entry:SetHeight(21)
        entry:SetPoint("TOPLEFT", menu, "TOPLEFT", 6, -5 - n * 22)
        entry:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -6, -5 - n * 22)
        entry:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        local fs = entry:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(ns.Fonts.FontFor("GameFontHighlight") or GameFontHighlight)
        fs:SetPoint("LEFT", entry, "LEFT", 10, 0)
        fs:SetText(L.LABEL)
        fs:SetTextColor(0.95, 0.83, 0.53)
        entry.label = fs
        entry:SetScript("OnClick", function()
            menu:Hide()
            L.Choose()
        end)
        entry:Hide()
        if f.languageSelectorText then hooksecurefunc(f.languageSelectorText, "SetText", FixLabel) end
    end
    L.ShowEntry(true)
    if f.languageSelectorText then FixLabel(f.languageSelectorText) end
    return true
end

-- ── Redraws ───────────────────────────────────────────────────────────────────────────────────

-- Everything, labels included, through FDJ's own English option with saving switched off.
function L.Redraw()
    if not L.Active() then ns.Prose.Restore() end
    local f = Frame()
    local menu = f and f.languageMenu
    local english = menu and EnglishOption(menu)
    local click = english and english:GetScript("OnClick")
    if not click then return L.Light() end
    quiet = true
    local ok, err = pcall(click, english, "LeftButton", false)
    quiet = false
    if f.languageSelectorText then FixLabel(f.languageSelectorText) end
    local fdj = FDJ()
    if fdj and type(fdj.RefreshQuestTracker) == "function" then pcall(fdj.RefreshQuestTracker) end
    ns.Screen.Schedule()
    if not ok then error(err, 0) end
end

-- Is one of FDJ's quest tracker windows shown? They are named ForeverDungeonJournalQuestTracker,
-- ...Tracker2, ...Tracker3 (a saved slot number, so there may be gaps). FDJ shows one only from its
-- own tracker redraw, which draws it in the language of that moment.
local function TrackerShown()
    for i = 1, 12 do
        local t = rawget(_G, "ForeverDungeonJournalQuestTracker" .. (i > 1 and i or ""))
        if type(t) == "table" and t.IsShown and t:IsShown() then return true end
    end
    return false
end

-- Nothing of ours touches the journal's frames in combat: a redraw asked for then (the hold key,
-- names, the window opened after a switch, the folded search) is done once when combat ends; the
-- mark stays till then.
-- FDJ itself redraws its own frames in combat (a click, its Favourites list on a bag update).
local function InCombat() return InCombatLockdown and InCombatLockdown() end
local waiter = CreateFrame("Frame")
waiter:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    UADD.SafeCall(L.Light)
end)

-- The open page only (the hold key, names that just arrived): no sound, no menu.
-- Only the shown page is redrawn. A shut journal window is marked and redrawn when it opens
-- (L.OnShown); FDJ shows its search results and its trackers only from a fresh draw.
function L.Light()
    if InCombat() then return waiter:RegisterEvent("PLAYER_REGEN_ENABLED") end
    if not L.Active() then ns.Prose.Restore() end
    local f, fdj = Frame(), FDJ()
    if not (f and fdj) then return end
    -- FDJ's own relabel call, on any page and with the window shut too: the buttons above the home
    -- cards (Favourites, Loot Filter) are then right when home comes back, and FDJ's chain redraws
    -- its Favourites window (a window of its own that stays open over any page; shown or not, so
    -- it is right when it opens) and its open Loot Filter and Run Log windows.
    if type(fdj.RelocalizeLootFilter) == "function" then pcall(fdj.RelocalizeLootFilter, f) end
    if f:IsShown() then
        dirty = false
        if f.currentView == "home" then
            if type(fdj.RefreshHomeCards) == "function" then pcall(fdj.RefreshHomeCards) end
        elseif type(fdj.RefreshRPGPage) == "function" then
            pcall(fdj.RefreshRPGPage)
        end
        local box, results = f.searchEditBox, f.searchResultsFrame
        local text = box and UADD.Plain(box:GetText()) or ""
        if text ~= "" and results and results:IsShown() then pcall(ns.Search.Refresh, text) end
    else
        dirty = true
        ns.Screen.WatchShow(f)
    end
    if TrackerShown() and type(fdj.RefreshQuestTracker) == "function" then pcall(fdj.RefreshQuestTracker) end
    UADD.SafeCall(ns.Head.Texts)
    ns.Screen.Schedule()
end

-- A journal window was shown (Screen.lua's OnShow hook, after FDJ's own draw on show).
function L.OnShown(frame)
    if dirty and frame == Frame() then L.Light() end
end

function L.Choose()
    ns.db.choice = "uk"
    L.Forget()
    L.Redraw()
end

-- The show-original key: English while it is held.
function L.OnOriginal(show)
    if not L.Wants() then ns.held = false return end
    if (ns.held or false) == show then return end
    ns.held = show
    L.Light()
end
