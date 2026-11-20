-- Our words in Scrap's own locale table, and its English back.
--   * Scrap's locale keys are plain names (L.SellJunk), so our data is keyed by "L." .. key. The table is
--     AceLocale's ("Scrap"). Most texts are read when shown (tooltips, chat, the dialog, the tutorial, the
--     settings pages built when Scrap_Config loads), so they get ours from the table.
--   * FAQ is a list (question, answer, question...): ours goes in as a new list ("FAQ." .. n), a pair only
--     when both lines are ours, and Scrap's own list goes back on off.
--   * STAY: chat lines with an item link (a game name) in them: never ours (lesson 9).
--   * The four key binding names Scrap copied into globals at load get ours too, and English back on off.
--   * Scrap saves no text of the table in its data (only item ids and its settings: lesson 14).
-- tools/test_scrap_text.py checks that STAY matches tools/scrap_rules.py.

local _, ns = ...
local U = UADD
local W = {}
ns.Swap = W

local STAY = { ["L.Added"] = true, ["L.Removed"] = true, ["L.Forgotten"] = true, ["L.Destroyed"] = true }
local BINDINGS = {
    BINDING_NAME_SCRAP_TOGGLE = "L.ToggleMousehover", BINDING_NAME_SCRAP_DESTROY_ONE = "L.DestroyCheapest",
    BINDING_NAME_SCRAP_DESTROY_ALL = "L.DestroyJunk", BINDING_NAME_SCRAP_SELL = "L.SellJunk",
}

local saved = {}       -- locale key -> its English, while ours is in the table
local bound = {}       -- binding global -> its English, while ours is in it
local faq, ourFaq      -- Scrap's own question list and ours, while ours is in the table
local rev, back = {}, {}   -- its English -> ours, ours -> its English

function W.Locale()
    local AL = LibStub and LibStub("AceLocale-3.0", true)
    local t = AL and type(AL.apps) == "table" and AL.apps["Scrap"]
    return type(t) == "table" and t or nil
end

local function Ours(k)
    local h = type(k) == "string" and "L." .. k
    return h and not STAY[h] and ns.AL[h] or nil
end

local function Pair(en, ua)
    if type(en) == "string" and type(ua) == "string" then rev[en] = ua; back[ua] = en end
end

-- Both maps, from the table's English (saved English first: the table may hold ours now).
local function Build(L)
    wipe(rev)
    wipe(back)
    for k, v in pairs(L) do Pair(saved[k] or v, Ours(k)) end
    local list = faq or rawget(L, "FAQ")
    if type(list) == "table" then
        for i, en in ipairs(list) do Pair(en, ns.AL["FAQ." .. i]) end
    end
end

-- Ours for one English text of Scrap (a locale text, or one its settings code writes itself), or nil.
function W.Translate(en)
    if type(en) ~= "string" or en == "" then return nil end
    return rev[en] or ns.AL["Code." .. U.Hash(en)]
end

-- Scrap's English for one text of ours from its locale table, or nil.
function W.English(ua) return type(ua) == "string" and back[ua] or nil end

local function SwapFaq(L)
    local list = rawget(L, "FAQ")
    if faq or type(list) ~= "table" then return end
    local mine, any = {}, false
    for i = 1, #list, 2 do
        local q, a = ns.AL["FAQ." .. i], ns.AL["FAQ." .. (i + 1)]
        if q and (a or list[i + 1] == nil) then
            mine[i], mine[i + 1], any = q, a, true
        else
            mine[i], mine[i + 1] = list[i], list[i + 1]
        end
    end
    if not any then return end
    faq, ourFaq = list, mine
    rawset(L, "FAQ", mine)
end

function W.SwapIn()
    local L = W.Locale()
    if not L then return end
    Build(L)
    for k, v in pairs(L) do
        local ua = type(v) == "string" and Ours(k)
        if ua then
            if saved[k] == nil then saved[k] = v end
            if v ~= ua then rawset(L, k, ua) end
        end
    end
    SwapFaq(L)
    for name, key in pairs(BINDINGS) do
        local en = bound[name] or rawget(_G, name)
        local ua = ns.AL[key]
        if ua and type(en) == "string" then
            bound[name] = en
            _G[name] = ua
        end
    end
end

function W.SwapOut()
    local L = W.Locale()
    if L then
        for k, en in pairs(saved) do
            if rawget(L, k) == Ours(k) then rawset(L, k, en) end
        end
        if faq and rawget(L, "FAQ") == ourFaq then rawset(L, "FAQ", faq) end
    end
    wipe(saved)
    faq, ourFaq = nil, nil
    for name, en in pairs(bound) do
        if rawget(_G, name) == ns.AL[BINDINGS[name]] then _G[name] = en end
    end
    wipe(bound)
end

-- Texts of ours in its locale table now (the question list counts as one).
function W.Count()
    local n = faq and 1 or 0
    for _ in pairs(saved) do n = n + 1 end
    return n
end
