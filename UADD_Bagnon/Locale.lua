-- Our Ukrainian in Bagnon's own locale tables, and back.
--
-- Bagnon reads its words through AceLocale-3.0: GetLocale("Bagnon") (the bag, bank and guild bank
-- windows, from BagBrother's core) and GetLocale("Bagnon_Config") (its settings pages). GetLocale hands
-- out the very table AceLocale keeps, and almost every word is read from it when it shows, so our words
-- go into that table (rawset) and Bagnon shows them by itself. The English each one replaces is kept,
-- to put back for the hold key and "/uadd bagnon off".
--   * "Bagnon" is loaded before us (a dependency): its table gets our words at our ADDON_LOADED.
--   * "Bagnon_Config" loads on demand, later. Its pages read some words once, while they load (page
--     names, subtitles), so our words must be there before that: AceLocale's NewLocale is wrapped, and
--     each word Bagnon_Config writes is swapped for ours right after it is written. If the wrapper was
--     lost (a newer AceLocale replaced it), our words go in at its ADDON_LOADED instead, too late for
--     the words it read while loading.
--   * A line is used only while the English it was made from is still Bagnon's (data: src, a hash), and
--     only with the same number of % slots. Otherwise that text stays English.
--   * Words Bagnon read once while loading are put right here, both ways (Lc.Patch): the window title
--     formats (the class fields and the title of each open window), the names of three basic bag rules,
--     the four key binding names, and the page titles and subtitles of the settings. The page names in
--     the game's Settings list are registered once by the game: they stay as they were until /reload.

local _, ns = ...
local U = UADD
local Lc = {}
ns.Locale = Lc

local CORE, CONFIG, NAME = "Bagnon", "Bagnon_Config", "Bagnon"
local english = { core = {}, config = {} }   -- key -> Bagnon's English that our word replaced
local inTable = { core = false, config = false }
local faqOwn, faqOurs                        -- Bagnon_Config's own FAQ list, and our copy of it
local reverse = {}                           -- Bagnon's English -> our Ukrainian (U.Missed, tests)
local wrapped, wrapLost = false, false

local function Ace() return LibStub and LibStub("AceLocale-3.0", true) end
local function App(name) local a = Ace() return a and a.apps and a.apps[name] end
local function Data() return ns.BGN or {} end
local function Key(s) return #s .. ":" .. (U.Hash(s) or "") end

local function Slots(s)
    local n = 0
    for _ in s:gsub("%%%%", ""):gmatch("%%") do n = n + 1 end
    return n
end

-- Our line for Bagnon's English `en` under "table:key" `id`, or nil.
local function Fit(id, en, uk)
    if type(en) ~= "string" or type(uk) ~= "string" or uk == "" then return nil end
    local src = (Data().src or {})[id]
    if src and src ~= Key(en) then return nil end
    if Slots(en) ~= Slots(uk) then return nil end
    return uk
end

local function Put(which, t, on)
    local words, saved = Data()[which] or {}, english[which]
    for k, uk in pairs(words) do
        if on then
            local cur = rawget(t, k)
            if saved[k] == nil and Fit(which .. ":" .. k, cur, uk) then saved[k] = cur end
            if saved[k] ~= nil then
                rawset(t, k, uk)
                reverse[saved[k]] = uk
            end
        elseif saved[k] ~= nil then
            rawset(t, k, saved[k])
        end
    end
    inTable[which] = on
end

local function PutFaq(t, on)
    local list = rawget(t, "FAQ")
    if not on then
        if faqOwn and list == faqOurs then rawset(t, "FAQ", faqOwn) end
        return
    end
    if type(list) ~= "table" or list == faqOurs then return end
    local words = Data().faq or {}
    if not next(words) then return end
    local copy = {}
    for i, en in ipairs(list) do
        local uk = Fit("faq:" .. i, en, words[i])
        if uk and en:find("ADDON", 1, true) and not uk:find("ADDON", 1, true) then uk = nil end
        copy[i] = uk or en
        if uk then reverse[(en:gsub("ADDON", NAME))] = (uk:gsub("ADDON", NAME)) end
    end
    faqOwn, faqOurs = list, copy
    rawset(t, "FAQ", copy)
end

-- ── Words read once while loading ────────────────────────────────────────────────────────────

local TITLES = { Inventory = "TitleBags", Bank = "TitleBank", Vault = "TitleVault" }
local RULES = { normal = "NormalBags", trade = "TradeBags", ammo = "AmmoBags" }
local BINDINGS = { TOGGLE = "OpenBags", BANK_TOGGLE = "OpenBank", VAULT_TOGGLE = "OpenVault",
    GUILD_TOGGLE = "OpenGuild" }
local PANELS = { "GeneralOptions", "FrameOptions", "DisplayOptions", "SlotOptions", "Help", "Patrons" }

-- The value of `key` in Bagnon's English and in ours: (now, other) for the swap.
local function Both(which, key)
    local en, t = english[which][key], App(which == "core" and CORE or CONFIG)
    local uk = en and t and (Data()[which] or {})[key]
    return en, uk
end

-- `cur` is Bagnon's English or ours for `key`: the one wanted now. Anything else (a player's own
-- name for a rule) is left as it is.
local function Swap(which, key, cur, on)
    local en, uk = Both(which, key)
    if not en or not uk or (cur ~= en and cur ~= uk) then return cur, false end
    local want = on and uk or en
    return want, want ~= cur
end

local function PatchPanels(on)
    local Addon = rawget(_G, NAME)
    for _, id in ipairs(PANELS) do
        local p = type(Addon) == "table" and rawget(Addon, id)
        if type(p) == "table" then
            if type(p.title) == "string" then
                local en, uk = Both("config", id)
                local from, to = on and en or uk, on and uk or en
                if from and to and p.title:sub(1, #from) == from then p.title = to .. p.title:sub(#from + 1) end
            end
            if type(p.subtitle) == "string" then
                local en, uk = Both("config", id .. "Description")
                local from = en and (on and en or uk):format(NAME)
                if from and p.subtitle == from then p.subtitle = (on and uk or en):format(NAME) end
            end
        end
    end
end

function Lc.Patch(on)
    local Addon = rawget(_G, NAME)
    if type(Addon) ~= "table" then return end
    for class, key in pairs(TITLES) do
        local c = rawget(Addon, class)
        if type(c) == "table" and type(rawget(c, "Title")) == "string" then
            c.Title = Swap("core", key, c.Title, on)
        end
    end
    local frames = type(Addon.Frames) == "table" and Addon.Frames.Registry
    for _, f in ipairs(type(frames) == "table" and frames or {}) do
        local key = TITLES[type(f.id) == "string" and f.id:gsub("^.", string.upper) or ""]
        local w = rawget(f, 0) and f.Title
        if key and type(w) == "table" and type(w.title) == "string" then
            local new, changed = Swap("core", key, w.title, on)
            w.title = new
            if changed and w.Update then U.SafeCall(w.Update, w) end
        end
    end
    local rules = type(Addon.Rules) == "table" and Addon.Rules.Registry
    for id, key in pairs(RULES) do
        local r = type(rules) == "table" and rules[id]
        if type(r) == "table" and type(r.title) == "string" then r.title = Swap("core", key, r.title, on) end
    end
    for id, key in pairs(BINDINGS) do
        local g = "BINDING_NAME_BAGNON_" .. id
        local cur = rawget(_G, g)
        if type(cur) == "string" then _G[g] = (Swap("core", key, cur, on)) end
    end
    PatchPanels(on)
    if ns.Game then U.SafeCall(ns.Game.Set, on) end                -- the game's words (Game.lua)
end

-- ── Bagnon_Config, while it loads ───────────────────────────────────────────────────────────

local function Wrap()
    local A = Ace()
    if wrapped or not A or type(A.NewLocale) ~= "function" then return end
    local real = A.NewLocale
    local mine
    mine = function(self, app, locale, isDefault, silent)
        local proxy = real(self, app, locale, isDefault, silent)
        if app ~= CONFIG or not isDefault or type(proxy) ~= "table" or not ns.WordsWanted() then return proxy end
        return setmetatable({}, {
            __index = function(_, k) local t = App(CONFIG) return t and t[k] end,
            __newindex = function(_, k, v)
                proxy[k] = v
                local t = App(CONFIG)
                if type(t) ~= "table" then return end
                if k == "FAQ" then PutFaq(t, true) return end
                local uk = (Data().config or {})[k]
                local cur = rawget(t, k)
                if uk and english.config[k] == nil and Fit("config:" .. k, cur, uk) then
                    english.config[k] = cur
                    rawset(t, k, uk)
                    reverse[cur] = uk
                    inTable.config = true
                elseif ns.Game then
                    U.SafeCall(ns.Game.Config, t, k)               -- a word of the game's (Game.lua)
                end
            end,
        })
    end
    A.NewLocale = mine
    wrapped = true
    Lc.WrapOk = function() return Ace() and Ace().NewLocale == mine end
end

-- ── API ──────────────────────────────────────────────────────────────────────────────────────

-- Our words in (on) or Bagnon's English back (off), in both tables, and the words read at load.
function Lc.Set(on)
    on = on and true or false
    local core, config = App(CORE), App(CONFIG)
    if type(core) == "table" then Put("core", core, on) end
    if type(config) == "table" then
        Put("config", config, on)
        PutFaq(config, on)
    end
    U.SafeCall(Lc.Patch, on)
end

-- Bagnon_Config has loaded: our words in now if the wrapper missed it.
function Lc.ConfigLoaded()
    if not inTable.config and ns.WordsWanted() then
        wrapLost = true
        Lc.Set(true)
    else
        U.SafeCall(Lc.Patch, ns.WordsWanted())
    end
end

function Lc.Install() Wrap() end
function Lc.Ukrainian(en) return reverse[en] end
function Lc.LateConfig() return wrapLost end

-- How many of Bagnon's texts show our words now.
function Lc.Count()
    local n = 0
    for _, which in ipairs({ "core", "config" }) do
        local t = App(which == "core" and CORE or CONFIG)
        for k in pairs(english[which]) do
            if t and rawget(t, k) == (Data()[which] or {})[k] then n = n + 1 end
        end
    end
    local t = App(CONFIG)
    if faqOurs and t and rawget(t, "FAQ") == faqOurs then
        for i, s in ipairs(faqOurs) do if s ~= faqOwn[i] then n = n + 1 end end
    end
    return n
end

Lc.Install()
