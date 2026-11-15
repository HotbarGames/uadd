-- UADD core: Ukrainian names from UALL Forever (UALLF), read at run time.
--
-- UALLF keeps its tables private (ns.zoneNames, ns.npcNames, ...), but it hooks SetText on some
-- Blizzard font strings and swaps the English for Ukrainian inside the same call. We write the
-- English into one of those font strings while its window is hidden, catch the Ukrainian that
-- UALLF writes back, and put the old text and colour back. All in one call, so nothing is drawn.
-- We never copy UALLF's data, never write into its tables, never touch its files.
-- See docs/research-uall-names.md for every route, with UALLF file:line.
--
--   kind   font string (only while hidden)            UALLF hook                     setting
--   zone   ZoneTextString / SubZoneTextString / ...   ZoneHooks Translate (zoneNames) world.zones
--   npc    QuestFrame / GossipFrame title              GossipHooks PinNpcTitle         gossip
--   item   GroupLootFrame1..4 .Name                    LootHooks ItemText (itemNames)  interface.loot
--   quest  a closed bag window's title                 StorageHooks Translate          interface.storage
--          (looks up uiStrings, items, NPCs, then quest titles, all by the English text)
--
-- Every function returns a Ukrainian string or nil, never throws. nil = keep the English.
-- "Not now" (combat, held Shift, a window on screen, not logged in) is never cached and comes back
-- as nil, true: ask again later. Real answers and real misses are cached per session.

UADD.UALL = UADD.UALL or {}
local U = UADD.UALL

-- ── Safe string helpers (Midnight "secret" strings throw on any comparison) ───────────────────

local function Text(v)
    if type(v) ~= "string" then return nil end
    local ok, empty = pcall(function() return v == "" end)
    if not ok or empty then return nil end
    return v
end

local function Same(a, b)
    local ok, same = pcall(function() return a == b end)
    return not ok or same
end

local function HasCyrillic(s)
    local ok, at = pcall(string.find, s, "[\208\209\210]")
    return ok and at ~= nil
end

-- Quest text tokens: $G male:female; and $P(male:female) pick the player's form; the rest go.
local function Clean(s)
    local ok, out = pcall(function()
        local female = UnitSex and UnitSex("player") == 3
        local function pick(m, f) return female and f or m end
        local t = s:gsub("%$GUILD", "")
        t = t:gsub("%$[Gg]%s*([^:;]*):([^;]*);", pick)
        t = t:gsub("%$[Pp]%(([^:%)]*):([^%)]*)%)", pick)
        t = t:gsub("%$[Bb]", " ")
        t = t:gsub("%$%a", "")
        t = t:gsub("{class:?v?}", "")
        t = t:gsub("%s%s+", " ")
        t = t:gsub("^%s+", "")
        t = t:gsub("%s+$", "")
        return t
    end)
    return ok and Text(out) or nil
end

-- ── The probe ─────────────────────────────────────────────────────────────────────────────────

local probing, probeInput, captured
local hooked = setmetatable({}, { __mode = "k" })

-- Runs inside UALLF's own SetText hook (its busy flag is set): must never raise.
-- The first text that differs from what we wrote is UALLF's answer. In UALLF's reverse mode
-- it writes the English straight back, but we read the argument, so the answer still arrives.
local function OnSetText(self, text)
    if probing ~= self or captured then return end
    text = Text(text)
    if text and not Same(text, probeInput) then captured = text end
end

-- A font string we may borrow right now: exists, not forbidden, not on screen.
local function Free(fs)
    if type(fs) ~= "table" or type(fs.SetText) ~= "function" or type(fs.GetText) ~= "function" then return false end
    if fs.IsForbidden then
        local ok, forbidden = pcall(fs.IsForbidden, fs)
        if not ok or forbidden then return false end
    end
    if type(fs.IsVisible) ~= "function" then return false end
    local ok, visible = pcall(fs.IsVisible, fs)
    return ok and not visible
end

-- Write `en`, catch UALLF's answer, restore. Returns ua (or nil), done (false = no real answer).
local function Ask(fs, en)
    if probing then return nil, false end
    if not hooked[fs] then
        if not pcall(hooksecurefunc, fs, "SetText", OnSetText) then return nil, false end
        hooked[fs] = true
    end
    local okGet, before = pcall(fs.GetText, fs)
    if not okGet then return nil, false end
    if before ~= nil and not pcall(function() return before == before end) then
        return nil, false                      -- a secret string: we could not compare it later
    end
    local r, g, b, a
    if type(fs.GetTextColor) == "function" then
        local okC, cr, cg, cb, ca = pcall(fs.GetTextColor, fs)
        if okC then r, g, b, a = cr, cg, cb, ca end
    end
    probing, probeInput, captured = fs, en, nil
    local okSet = pcall(fs.SetText, fs, en)
    local ua = captured
    probing, probeInput, captured = nil, nil, nil
    pcall(fs.SetText, fs, before)
    if r and type(fs.SetTextColor) == "function" then pcall(fs.SetTextColor, fs, r, g, b, a) end
    if not okSet then return nil, false end
    return ua, true
end

-- ── Routes ────────────────────────────────────────────────────────────────────────────────────

local function Title(frame)
    if type(frame) ~= "table" or type(frame.GetTitleText) ~= "function" then return nil end
    local ok, fs = pcall(frame.GetTitleText, frame)
    return ok and fs or nil
end

-- Each route lists its candidate font strings, best first; missing frames are simply skipped.
local KINDS = {
    zone = {
        gate = "world.zones",
        widgets = function(add)
            add(_G.ZoneTextString); add(_G.SubZoneTextString); add(_G.PVPInfoTextString)
        end,
        canary = { "Elwynn Forest", "Durotar", "Stormwind City" },
    },
    npc = {
        gate = "gossip",
        widgets = function(add) add(Title(_G.QuestFrame)); add(Title(_G.GossipFrame)) end,
        canary = { "Thrall", "Marshal Dughan", "Cairne Bloodhoof" },
    },
    item = {
        gate = "interface.loot",
        widgets = function(add)
            for i = 4, 1, -1 do                -- Blizzard fills roll frames from 1, so start at 4
                local f = _G["GroupLootFrame" .. i]
                if type(f) == "table" then add(f.Name) end
            end
        end,
        canary = { "Linen Cloth", "Copper Ore", "Peacebloom" },
    },
    quest = {
        gate = "interface.storage",
        widgets = function(add)
            for i = (NUM_CONTAINER_FRAMES or 13), 1, -1 do   -- Blizzard opens the lowest free one
                add(Title(_G["ContainerFrame" .. i]))
            end
        end,
        canary = { "Kobold Camp Cleanup", "A Threat Within", "Wolves Across the Border" },
    },
}

-- First free widget of a kind, or nil (all on screen, or none exist in this client).
local function Widget(spec)
    local found
    local function add(fs)
        if not found and fs and Free(fs) then found = fs end
    end
    if not pcall(spec.widgets, add) then return nil end
    return found
end

local function Raw(kind, en)
    local fs = Widget(KINDS[kind])
    if not fs then return nil, false end
    return Ask(fs, en)
end

-- ── When to ask ───────────────────────────────────────────────────────────────────────────────

local function Settings()
    local s = _G.UALLFSettingsDB
    return type(s) == "table" and s or {}
end

local function KeyHeld(s)
    local key = s.originalKey or "SHIFT"
    return (key == "SHIFT" and IsShiftKeyDown and IsShiftKeyDown())
        or (key == "CTRL" and IsControlKeyDown and IsControlKeyDown())
        or (key == "ALT" and IsAltKeyDown and IsAltKeyDown()) or false
end

function U.IsAvailable()
    local ok, yes = pcall(function()
        local loaded
        if C_AddOns and C_AddOns.IsAddOnLoaded then
            local loading, done = C_AddOns.IsAddOnLoaded("UALLF")
            loaded = loading and done ~= false
        elseif IsAddOnLoaded then
            loaded = IsAddOnLoaded("UALLF")
        end
        if not loaded then return false end
        return Settings().enabled ~= false
    end)
    return ok and yes or false
end

-- true = UALLF would answer right now. false = "not now" or switched off: do not cache.
local function Ready(gate)
    if not U.IsAvailable() then return false end
    if InCombatLockdown and InCombatLockdown() then return false end
    if IsLoggedIn and not IsLoggedIn() then return false end    -- gossip title is pinned at login
    local s = Settings()
    if s[gate] == false then return false end
    if not s.reverseOriginal and KeyHeld(s) then return false end   -- UALLF shows English then
    return true
end

-- ── Cache ─────────────────────────────────────────────────────────────────────────────────────

local cache = { zone = {}, npc = {}, item = {}, quest = {} }
local verified = {}       -- kind -> true once any lookup of that kind came back Ukrainian
local canaryAt = {}       -- kind -> GetTime() of the last failed canary run
local sig, sigAt

local SIG_KEYS = { "enabled", "reverseOriginal", "world.zones", "gossip", "interface.loot", "interface.storage" }

local function CheckSettings()
    local now = GetTime and GetTime() or 0
    if sigAt == now then return end
    sigAt = now
    local s, parts = Settings(), {}
    for i, k in ipairs(SIG_KEYS) do parts[i] = tostring(s[k]) end
    local new = table.concat(parts, ",")
    if new ~= sig then
        sig = new
        for _, t in pairs(cache) do wipe(t) end
        wipe(verified)
        wipe(canaryAt)
    end
end

-- A miss only counts once we know the route works at all. If UALLF never pinned the widget
-- (another client build, a renamed frame), every probe would "miss" and we must not cache that.
local function RouteWorks(kind)
    if verified[kind] then return true end
    local now = GetTime and GetTime() or 0
    if canaryAt[kind] and now - canaryAt[kind] < 10 then return false end
    for _, en in ipairs(KINDS[kind].canary) do
        local ua, done = Raw(kind, en)
        if done and ua and HasCyrillic(ua) then
            verified[kind] = true
            return true
        end
    end
    canaryAt[kind] = now
    return false
end

local function Lookup(kind, en)
    en = Text(en)
    if not en then return nil end
    CheckSettings()
    local hit = cache[kind][en]
    if hit ~= nil then return hit or nil end
    if not Ready(KINDS[kind].gate) then return nil, true end
    local ua, done = Raw(kind, en)
    if not done then return nil, true end
    ua = ua and Clean(ua)
    if ua and (Same(ua, en) or not HasCyrillic(ua)) then ua = nil end
    if ua then
        verified[kind] = true
    elseif not RouteWorks(kind) then
        return nil, true
    end
    cache[kind][en] = ua or false
    return ua
end

-- ── Public ────────────────────────────────────────────────────────────────────────────────────

local function Safe(kind, en)
    local ok, ua, wait = pcall(Lookup, kind, en)
    return ok and ua or nil, ok and wait or nil
end

function U.Zone(englishName) return Safe("zone", englishName) end
function U.Npc(englishName) return Safe("npc", englishName) end
function U.Item(englishName) return Safe("item", englishName) end
function U.Text(englishText) return Safe("quest", englishText) end   -- any text the bag-title route knows: UI words ("Hall of Thanes"), items, NPCs, quests

-- UALLF has no hidden by-ID route (its by-ID quest titles only go through GameTooltip),
-- so this looks up the English title. Without one, the client's own title for the ID is used.
function U.Quest(questId, englishTitle)
    local ok, ua, wait = pcall(function()
        local en = Text(englishTitle)
        if not en and type(questId) == "number" and C_QuestLog and C_QuestLog.GetTitleForQuestID then
            en = Text(C_QuestLog.GetTitleForQuestID(questId))
        end
        return Lookup("quest", en)
    end)
    return ok and ua or nil, ok and wait or nil
end

local SAMPLES = {
    zone  = { "Elwynn Forest", "Stormwind City", "Durotar", "Orgrimmar", "Westfall",
              "Ironforge", "The Barrens", "Mulgore", "Teldrassil", "Tirisfal Glades" },
    npc   = { "Thrall", "Marshal Dughan", "Hogger", "Cairne Bloodhoof", "Gryan Stoutmantle",
              "Deputy Willem", "Lady Sylvanas Windrunner", "Magni Bronzebeard" },
    item  = { "Hearthstone", "Linen Cloth", "Copper Ore", "Light Leather", "Peacebloom",
              "Silverleaf", "Rough Stone", "Wool Cloth" },
    quest = { "Kobold Camp Cleanup", "A Threat Within", "Wolves Across the Border",
              "Brotherhood of Thieves", "Rest and Relaxation", "Investigate Echo Ridge",
              "The Defias Brotherhood", "Your Place In The World" },
}

-- /uadd test: per kind, how many samples UALLF answered and how long the probes took.
-- Goes straight to the probe (no cache), so the time is the real cost per lookup.
function U.SelfTest()
    local function say(msg) print("|cff4fc3f7UADD|r UALL: " .. msg) end
    local ok, err = pcall(function()
        if not U.IsAvailable() then say("UALL Forever is not loaded, or its translation is switched off.") return end
        if InCombatLockdown and InCombatLockdown() then say("in combat: lookups wait until combat ends.") return end
        local s = Settings()
        if not s.reverseOriginal and KeyHeld(s) then say("let go of the show-original key and try again.") return end
        for _, kind in ipairs({ "zone", "npc", "item", "quest" }) do
            local spec, list = KINDS[kind], SAMPLES[kind]
            if s[spec.gate] == false then
                say(("%s: off in UALL settings (%s)."):format(kind, spec.gate))
            elseif not Widget(spec) then
                say(("%s: no free widget for this route (window on screen, or frame missing)."):format(kind))
            else
                local hits, first = 0, nil
                local t0 = debugprofilestop()
                for _, en in ipairs(list) do
                    local ua = Raw(kind, en)
                    ua = ua and Clean(ua)
                    if ua and HasCyrillic(ua) then
                        hits = hits + 1
                        first = first or (en .. " -> " .. ua)
                    end
                end
                local ms = debugprofilestop() - t0
                say(("%s: %d/%d resolved, %.2f ms (%.3f ms each)%s"):format(kind, hits, #list, ms,
                    ms / #list, first and (", e.g. " .. first) or ""))
            end
        end
    end)
    if not ok then say("self-test error: " .. tostring(err)) end
end
