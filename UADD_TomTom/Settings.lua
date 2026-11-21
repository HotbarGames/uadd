-- TomTom's settings pages in Ukrainian.
--   * Most of their words come from TomTom.L, which holds ours already when TomTom builds the pages at
--     login (Module.lua). This file covers what the pages get from code: page names, row names and
--     tooltips that are finished lines (a theme name with our colour word), dropdown entries (the
--     distance units, the key names, the theme names), and texts made by a function each time a page
--     shows. Each goes through ns.Words; a text with no Ukrainian stays as it is.
--   * How: TomTom's own page and row makers (TomTom.private) are wrapped before it builds the pages.
--     Each new page is a frame of ours for Fonts.lua: looked at when it shows, and each row when the
--     list makes it. The game's settings functions and frames are never replaced.
--   * The profile dropdowns list the player's own profile names: never translated (PlayerList).
--   * Off: the words made each time (dropdowns, page texts) are English again at once; the names a page
--     got when it was built stay until /reload.
--   * Also here: TomTom's pop-ups (ns.Popups, at the end).

local _, ns = ...
local U = UADD
local S = {}
ns.Settings = S

local done = false
local count = 0

local function Tr(s)
    if type(s) ~= "string" or s == "" or not ns.WordsWanted() then return s end
    local ok, uk = pcall(ns.Words.Translate, s)
    if ok and type(uk) == "string" and uk ~= s then
        count = count + 1
        return uk
    end
    return s
end
S.Translate = Tr                               -- the translate function the checks call

local function Func(f)
    if type(f) ~= "function" then return f end
    return function(...) return Tr(f(...)) end
end

-- One dropdown's entries, as the game's settings get them: label, text and tooltip translated.
local function Entries(list)
    if type(list) ~= "table" then return list end
    for _, e in pairs(list) do
        if type(e) == "table" then
            e.label = Tr(e.label)
            e.text = Tr(e.text)
            e.tooltip = Tr(e.tooltip)
        end
    end
    return list
end
S.Entries = Entries

local function Options(f)
    if type(f) ~= "function" then return f end
    return function(...) return Entries(f(...)) end
end

-- A dropdown that lists the player's own profile names (TomTom's profile rows; their setting's variable
-- starts with PLAYER). Its entries are the player's text, never translated, whatever the names are
-- (a profile may be called like one of TomTom's texts). Their fixed entries already hold ours from L.
local PLAYER = "^TOMTOM_PROFILE_"
local playerSetting = setmetatable({}, { __mode = "k" })

local function PlayerList(setting)
    if type(setting) ~= "table" then return false end
    if playerSetting[setting] then return true end
    local ok, v = pcall(function() return setting:GetVariable() end)
    return ok and type(v) == "string" and v:find(PLAYER) ~= nil
end
S.PlayerList = PlayerList

-- One row (an initializer) before it goes on a page.
local function Fix(init)
    if type(init) ~= "table" then return end
    local data = init.data
    if type(data) ~= "table" and type(init.GetData) == "function" then
        local ok, d = pcall(init.GetData, init)
        data = ok and d or nil
    end
    if type(data) ~= "table" then return end
    for _, k in ipairs({ "name", "tooltip", "buttonText", "text" }) do data[k] = Tr(data[k]) end
    if type(data.textFunc) == "function" then data.textFunc = Func(data.textFunc) end
    if type(data.options) == "function" and not PlayerList(data.setting) then data.options = Options(data.options) end
end
S.Fix = Fix

local function OnRow(_, f) U.SafeCall(ns.Fonts.LookOwn, f) end

local function Page(page)
    if type(page) ~= "table" then return page end
    if type(page.AddInitializer) == "function" then
        local add = page.AddInitializer
        page.AddInitializer = function(self, init, ...)
            U.SafeCall(Fix, init)
            return add(self, init, ...)
        end
    end
    U.SafeCall(ns.Fonts.AddRoot, page)
    local box = page.List and page.List.ScrollBox
    if box and ScrollUtil and type(ScrollUtil.AddInitializedFrameCallback) == "function" then
        pcall(ScrollUtil.AddInitializedFrameCallback, box, OnRow, page, false)
    end
    return page
end

local function Wrap(P, name, fn)
    local orig = P[name]
    if type(orig) ~= "function" then return false end
    P[name] = fn(orig)
    return true
end

-- Wrap TomTom's page and row makers (once, before it builds the pages at login).
function S.Install()
    if done or not ns.On() then return end
    local A = ns.Addon()
    local P = A and rawget(A, "private")
    if type(P) ~= "table" then return end
    done = true
    Wrap(P, "CreateSettingsPage", function(orig)
        return function(name, parent, ...) return Page(orig(Tr(name), parent, ...)) end
    end)
    Wrap(P, "CreateUnregisteredSetting", function(orig)
        return function(category, variable, varType, name, ...)
            local s = orig(category, variable, varType, Tr(name), ...)
            if type(s) == "table" and type(variable) == "string" and variable:find(PLAYER) then
                playerSetting[s] = true
            end
            return s
        end
    end)
    Wrap(P, "CreateTextInitializer", function(orig)
        return function(data, ...)
            if type(data) == "table" then
                data.text = Tr(data.text)
                if type(data.textFunc) == "function" then data.textFunc = Func(data.textFunc) end
            end
            return orig(data, ...)
        end
    end)
    Wrap(P, "CreateColorInitializer", function(orig)
        return function(setting, tooltip, ...) return orig(setting, Tr(tooltip), ...) end
    end)
end

function S.Count() return count end
function S.Installed() return done end

-- ── Pop-ups ───────────────────────────────────────────────────────────────────────────────────
-- Its confirm pop-ups (profiles, reset, remove all): defined when TomTom loads, before our words are in
-- L, so their fields get ours here (ns.Swap) and TomTom's own back on off and the hold key.

local POPUPS = { "TOMTOM_REMOVE_ALL_CONFIRM", "TOMTOM_RESET_SETTINGS_PAGE", "TOMTOM_NEW_PROFILE",
    "TOMTOM_COPY_PROFILE", "TOMTOM_DELETE_PROFILE", "TOMTOM_RESET_PROFILE" }
local FIELDS = { "text", "button1", "button2" }
local Popups = { orig = {} }
ns.Popups = Popups
local KEY = "tomtom"

-- The game's ACCEPT and CANCEL on their buttons: ours while the global is English (the core helper; the
-- globals are never written). Fonts.lua gives the shown dialog its font.
local NAMES = {}
for _, which in ipairs(POPUPS) do NAMES[which] = true end
U.Popups.Register(KEY, {
    names = NAMES,
    globals = { ACCEPT = "ui.accept", CANCEL = "ui.cancel" },
    wanted = function() return ns.WordsWanted() end,
})

function Popups.Apply()
    if not ns.WordsWanted() or type(StaticPopupDialogs) ~= "table" then return end
    for _, which in ipairs(POPUPS) do
        local d = StaticPopupDialogs[which]
        if type(d) == "table" then
            local o = Popups.orig[which] or {}
            Popups.orig[which] = o
            for _, f in ipairs(FIELDS) do
                -- Only an English we have a word for is kept: a field the core helper already holds in
                -- Ukrainian (the game's ACCEPT, CANCEL) is not TomTom's English and must never come back.
                if o[f] == nil and type(d[f]) == "string" and ns.Swap(d[f]) then o[f] = d[f] end
                local uk = ns.Swap(o[f])
                if uk and d[f] == o[f] then d[f] = uk end
            end
        end
    end
    U.Popups.Sync(KEY)                             -- the game's button words (UADD/Popups.lua)
end

-- TomTom's English back, only where the field still holds our word (a field TomTom changed stays its own).
function Popups.Restore()
    if type(StaticPopupDialogs) == "table" then
        for which, o in pairs(Popups.orig) do
            local d = StaticPopupDialogs[which]
            if type(d) == "table" then
                for f, en in pairs(o) do
                    local uk = ns.Swap(en)
                    if uk and d[f] == uk then d[f] = en end
                end
            end
        end
    end
    U.Popups.Off(KEY)
end

function Popups.Ours(which)
    for _, w in ipairs(POPUPS) do if w == which then return true end end
    return false
end
