-- Our words in GatherMate2's own locale table, and its English back.
--   * GatherMate2's locale keys are its English, so our data is keyed by "L." .. UADD.Hash(key). The table is
--     AceLocale's ("GatherMate2"); its node tables (herbs, ores, fish...) are game names and never touched
--     (lesson 9: its Collector matches them with what the game shows).
--   * Text read later (chat lines, the launcher tooltip, the pin menu, the options built by functions) reads
--     the table and so gets ours. Text it copied at load is in its option tables: Options.lua changes those,
--     using W.Translate (its English -> ours).
--   * STAY: never ours (the chat line glues an engine token to it). DISPLAY: the profession names it compares
--     with the game's (Constants.lua): never in the table, ours only where a settings list shows them.
--   * PIN: never in the table. The world map pin menu glues a node's name after it, and node names stay
--     English (game names), so that menu line stays all English. The settings button with the same word copied
--     it at load: Options.lua gives it ours there (W.Translate knows it).
--   * The two key binding names it copied into globals at load get ours too, and English back on off.
-- tools/test_gm_text.py checks that STAY and DISPLAY match tools/gm_rules.py.

local _, ns = ...
local U = UADD
local W = {}
ns.Swap = W

local STAY = { ["L.8d54e40a"] = true }
local DISPLAY = { ["L.1e363afc"] = true, ["L.c3266907"] = true, ["L.0d75bacd"] = true, ["L.6585e410"] = true,
    ["L.ba066853"] = true }
local PIN = { ["L.adde7058"] = true }
local BINDINGS = { "BINDING_NAME_TOGGLE_GATHERMATE2_MINIMAPICONS", "BINDING_NAME_TOGGLE_GATHERMATE2_MAINMAPICONS" }

local saved = {}       -- locale key -> its English, while ours is in the table
local bound = {}       -- binding global -> its English, while ours is in it
local rev = {}         -- its English -> ours (every row of ours, DISPLAY too)
local hash = {}        -- locale key -> "L." .. hash (each key hashed once)

function W.Locale()
    local AL = LibStub and LibStub("AceLocale-3.0", true)
    local t = AL and type(AL.apps) == "table" and AL.apps["GatherMate2"]
    return type(t) == "table" and t or nil
end

local function Row(k)
    local h = hash[k]
    if not h then
        h = "L." .. U.Hash(k)
        hash[k] = h
    end
    return h
end

-- The English -> ours map, from the table's English (saved English first: the table may hold ours now).
local function Build(L)
    wipe(rev)
    for k, v in pairs(L) do
        local en = saved[k] or v
        local ua = type(k) == "string" and type(en) == "string" and ns.AL[Row(k)]
        if ua and not STAY[Row(k)] then rev[en] = ua end
    end
end

-- Ours for one English text GatherMate2 copied (option names, list entries), or nil.
function W.Translate(en)
    return type(en) == "string" and rev[en] or nil
end

function W.SwapIn()
    local L = W.Locale()
    if not L then return end
    Build(L)
    for k, v in pairs(L) do
        local h = type(k) == "string" and Row(k)
        local ua = h and ns.AL[h]
        if ua and not STAY[h] and not DISPLAY[h] and not PIN[h] and type(v) == "string" then
            if saved[k] == nil then saved[k] = v end
            if v ~= ua then rawset(L, k, ua) end
        end
    end
    for _, name in ipairs(BINDINGS) do
        local en = bound[name] or rawget(_G, name)
        local ua = W.Translate(en)
        if ua then
            bound[name] = en
            _G[name] = ua
        end
    end
end

function W.SwapOut()
    local L = W.Locale()
    if L then
        for k, en in pairs(saved) do
            if rawget(L, k) == ns.AL[Row(k)] then rawset(L, k, en) end
        end
    end
    wipe(saved)
    for name, en in pairs(bound) do
        if rawget(_G, name) == W.Translate(en) then _G[name] = en end
    end
    wipe(bound)
end

-- Texts of ours in its locale table now.
function W.Count()
    local n = 0
    for _ in pairs(saved) do n = n + 1 end
    return n
end
