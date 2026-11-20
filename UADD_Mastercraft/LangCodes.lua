-- UADD - Mastercraft: which language Mastercraft draws in, for Language.lua (its menu row «Українська»).
-- Mastercraft's saved data is only read, never written (lesson 14).

local _, ns = ...
local L = {}
ns.Lang = L

-- Mastercraft's saved language: nil (never chosen) or "en" mean English on an English client.
local function SavedLang()
    local db = rawget(_G, "MastercraftDB")
    local s = type(db) == "table" and rawget(db, "settings")
    return type(s) == "table" and rawget(s, "lang") or nil
end

-- The codes Mastercraft can draw in: its menu's rows (it lists only those), learnt when we see the menu
-- and kept in UADD_DB (ns.db.codes, "de,en,fr") for the next login, before its window is made.
local known
local function Known()
    if known then return known end
    local saved = ns.db and ns.db.codes
    if type(saved) ~= "string" or saved == "" then return nil end
    local k = {}
    for c in saved:gmatch("[^,]+") do k[c] = true end
    if k.en then known = k return k end
end
function L.Learn(rows)
    local k, list = {}, {}
    for _, r in ipairs(rows) do
        if not k[r.code] then k[r.code] = true list[#list + 1] = r.code end
    end
    known = k
    table.sort(list)
    if ns.db then ns.db.codes = table.concat(list, ",") end
end

-- The language Mastercraft draws in, and whether we are sure: a saved code it does not know, or cannot
-- draw ("zh" without its font), is English to it. Its menu then ticks English, and its English row does
-- nothing when pressed, so that must count as English here. Before we know its codes: the saved code,
-- not sure.
function L.MastercraftLang()
    local lang = SavedLang()
    if lang == nil or lang == "en" then return "en", true end
    local k = Known()
    if not k then return lang, false end
    if k[lang] then return lang, true end
    return "en", true
end
function L.MastercraftEnglish() return (L.MastercraftLang()) == "en" end

-- Our words are wanted when the player has not picked another language in Mastercraft's menu.
function L.Wants()
    local db = ns.db
    return db ~= nil and db.choice ~= "other" and L.MastercraftEnglish()
end
