-- UADD - GearQuest Forever: its locale table (GearQuest.L) answers with our Ukrainian.
--
-- GearQuest keeps its words in GQ.L, keyed by its English, and has a language list of its own (other languages
-- come from its Languages addon). We plug in next to that list:
--   * GQ.L's lookup is wrapped: while ours is in force, a key whose hash is in our data gives our Ukrainian;
--     every other key gives what GearQuest gives (its English, or its own language pack's word).
--   * GearQuest's own locale state stays its English state (GQ.LocaleActive false), so its sentence, name and
--     phrase-rule paths (TL, TN, TX) keep the English as it is: we never make half lines through them.
--   * Its language list gets one more entry, "Українська" (id ukUA). GearQuest saves only the id; without UADD it
--     falls back to its English. Our Ukrainian is in force when the list says ukUA or nothing (auto); English when
--     the player picked English (or its "English interface" switch); another language is left to GearQuest.
--   * Words it built once at load: its spec names (GQ.Spec.CLASS_SPECS) are switched both ways (lesson 15), and its
--     coloured source tag is rebuilt from the label (GQ.GetSourceTag reads a load-time copy).
--   * Each pair it hands out is learned (our text -> its English key), so Screen.lua can give the English back on
--     the hold key and off, and ours again after.
-- Any error leaves GearQuest's own answer. No English of GearQuest is stored here.

local _, ns = ...
local U = UADD

local Lc = {}
ns.Loc = Lc

local GQ                     -- GearQuest's namespace, once found
local inForce = false        -- ours in force now (changed only by Lc.Set, out of combat)
local cache = {}             -- English key -> ours, or false (no Ukrainian of ours); at most MAXCACHE kept
local ncache, MAXCACHE = 0, 2048
local back = {}              -- ours -> English key (learned from its lookups)
local templates = {}         -- English key -> ours, for the keys with slots (learned)
local nlearned, nasked = 0, 0
local SLOT = "%%[-+#0]*%d*%.?%d*[sdif]"

function Lc.Addon()
    if GQ then return GQ end
    local g = rawget(_G, "GearQuest")
    if type(g) == "table" and type(g.L) == "table" then GQ = g end
    return GQ
end

-- Our Ukrainian for one English key of its locale table, or nil. A key with no letters or of a kind we keep
-- English (STAY in the data) has none. Cached per key, hit or miss.
local function Ours(key)
    local hit = cache[key]
    if hit ~= nil then return hit or nil end
    local ours
    if #key < 4000 then
        local h = "L." .. U.Hash(key)
        ours = ns.AL[h]
        if type(ours) ~= "string" or ours == "" then ours = nil end
    end
    if ncache >= MAXCACHE then cache, ncache = {}, 0 end    -- text it draws without a lookup (lesson 21: bounded)
    cache[key], ncache = ours or false, ncache + 1
    if ours then
        back[ours] = key
        nlearned = nlearned + 1
        if key:find(SLOT) then templates[key] = ours end
    end
    return ours
end
Lc.Ours = function(key) return type(key) == "string" and Ours(key) or nil end

-- A whole English text drawn without its locale table (a page of its guide, a label), keyed X.<hash>.
function Lc.Text(en)
    if type(en) ~= "string" or en == "" or #en > 4000 then return nil end
    local ours = Lc.Ours(en) or ns.AL["X." .. U.Hash(en)]
    if type(ours) == "string" and ours ~= "" then
        back[ours] = back[ours] or en
        return ours
    end
    return nil
end

function Lc.Back() return back end
function Lc.Templates() return templates end
function Lc.InForce() return inForce end
function Lc.Count() return nlearned end
function Lc.Asked() return nasked end

-- ── The choice in its language list ─────────────────────────────────────────────────────────────

local function Settings()
    local g = Lc.Addon()
    local db = g and rawget(g, "db")
    if type(db) == "table" and type(db.settings) == "table" then return db.settings end
    local saved = rawget(_G, "GearQuestForeverDB")
    if type(saved) == "table" and type(saved.settings) == "table" then return saved.settings end
    return nil
end

local function IsPack(id)
    local g = Lc.Addon()
    local packs = g and rawget(g, "LocalePacks")
    if type(packs) ~= "table" then return false end
    for _, p in ipairs(packs) do
        if type(p) == "table" and p.id == id and id ~= "ukUA" then return true end
    end
    return false
end

-- "uk": ours (ukUA, nothing, auto); "en": the player picked English; "other": GearQuest's own language.
function Lc.Choice()
    local g = Lc.Addon()
    if not g then return "en" end
    if rawget(g, "LocaleActive") then return "other" end
    local s = Settings()
    if s and s.englishInterface then return "en" end
    local id = s and s.locale
    if id == nil or id == "" or id == "auto" or id == "ukUA" then return "uk" end
    if id == "enUS" or id == "enGB" then return "en" end
    if IsPack(id) then return "other" end
    return "uk"
end

-- ── Words built once at load ────────────────────────────────────────────────────────────────────

local specEnglish = setmetatable({}, { __mode = "k" })   -- spec entry -> its English label
local function Specs(on)
    local g = Lc.Addon()
    local S = g and rawget(g, "Spec")
    local all = type(S) == "table" and rawget(S, "CLASS_SPECS")
    if type(all) ~= "table" then return end
    for _, list in pairs(all) do
        if type(list) == "table" then
            for _, e in ipairs(list) do
                if type(e) == "table" and type(e.label) == "string" then
                    local en = specEnglish[e] or back[e.label] or e.label
                    specEnglish[e] = en
                    local want = on and Lc.Ours(en) or en
                    if e.label ~= want then e.label = want end
                end
            end
        end
    end
end

-- ── Install ─────────────────────────────────────────────────────────────────────────────────────

local installed = false

local function Guard(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            pcall(U.ReportError, tostring(err))
            pcall(U.Fault, "gq", tostring(err))
        end
    end
end

-- Its lookup, wrapped once. Our part runs under a pcall: any error gives GearQuest's own answer.
local function WrapLookup(g)
    local mt = getmetatable(g.L)
    if type(mt) ~= "table" or type(mt.__index) ~= "function" then return false end
    local own = mt.__index
    mt.__index = function(t, key)
        local v = own(t, key)
        if not inForce or v ~= key or type(key) ~= "string" then return v end
        nasked = nasked + 1
        local ok, ours = pcall(Ours, key)
        if ok and ours then return ours end
        if not ok then pcall(U.Fault, "gq", tostring(ours)) end
        return v
    end
    return true
end

-- Its coloured source tag reads a copy built at load (English): its label, as ours, inside the same colour.
local function WrapSourceTag(g)
    local own = rawget(g, "GetSourceTag")
    if type(own) ~= "function" then return end
    g.GetSourceTag = function(self, ...)
        local out = own(self, ...)
        if not inForce or type(out) ~= "string" then return out end
        local ok, res = pcall(function()
            local c, mid = out:match("^(|c%x%x%x%x%x%x%x%x)(.-)|r$")
            local ours = mid and Lc.Ours(mid)
            return ours and (c .. ours .. "|r") or out
        end)
        return ok and res or out
    end
end

-- One more entry in its language list (only its list: the id is never a pack it loads).
local function AddPack(g)
    local packs = rawget(g, "LocalePacks")
    if type(packs) ~= "table" then return end
    for _, p in ipairs(packs) do
        if type(p) == "table" and p.id == "ukUA" then return end
    end
    packs[#packs + 1] = { id = "ukUA", name = "Українська" }
end

-- Its language step (at its settings' load, and when a choice changes): after it, ours follows the choice.
local function WrapApply(g)
    local own = rawget(g, "ApplyLanguageSetting")
    if type(own) ~= "function" then return end
    g.ApplyLanguageSetting = function(...)
        own(...)
        Guard(function() if ns.Sync then ns.Sync() end end)()
    end
end

function Lc.Install()
    if installed then return true end
    local g = Lc.Addon()
    if not g or not WrapLookup(g) then return false end
    installed = true
    WrapSourceTag(g)
    AddPack(g)
    WrapApply(g)
    return true
end
function Lc.Installed() return installed end

-- Ours in force (true) or GearQuest's own words (false): the lookup and the load-time words. Out of combat only
-- (Module.lua), so its windows switch whole.
function Lc.Set(on)
    inForce = on and installed or false
    local g = Lc.Addon()
    -- Its language list shows the entry the player picked; its own state stays English (LocaleActive false).
    if g and not rawget(g, "LocaleActive") then
        local s = Settings()
        local want = (inForce and s and s.locale == "ukUA") and "ukUA" or "enUS"
        if g.ActiveLocale ~= want and (g.ActiveLocale == "enUS" or g.ActiveLocale == "ukUA") then
            g.ActiveLocale = want
        end
    end
    Specs(inForce)
end
