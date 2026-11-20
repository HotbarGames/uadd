-- UADD - Mastercraft: its own words on the Crafters page's "raw" font strings (ns.RawText).
--
-- RawText is Mastercraft's string for text that stays as it is in every language (a player's name, a
-- recipe), so it has none of the mc* fields Screen.lua looks for. A few of them still show Mastercraft's
-- own words, built in its code: the profile card's line under the name (level, class, professions with
-- their skill) and its note line (our words around the player's own note, which stays as typed), and
-- the hub tiles' two lines when they are the tile's "nothing here" text, a count ("<n> available") or
-- "<player> can make <recipe> - online now". Raw.Look(frame) (from Screen.lua, for each frame it looks
-- at) finds these by their fields and gives them what Screen.lua wants:
--   * mcSetText / mcSetFont: the font string kind's own setters (not RawText's wrappers);
--   * mcRaw: set by a hook that runs before Screen.lua's, only for a text of the kinds above. Any other
--     text (a favourite's name, a recipe with its time) gets no mcRaw: Screen.lua leaves it as it is,
--     whatever it says, so a player named like one of Mastercraft's texts keeps the name (lesson 13).

local _, ns = ...
local R = {}
ns.Raw = R

local marked = setmetatable({}, { __mode = "k" })

local function Method(fs, name)
    local mt = getmetatable(fs)
    local t = type(mt) == "table" and mt.__index
    return type(t) == "table" and t[name] or nil
end

local function Always() return true end

local function Plain(s) return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

-- A tile line that is Mastercraft's own words: the tile's empty text (grey), a count, a watched recipe.
local function TileOwn(empty)
    local grey = "|cff8c8c8c" .. empty .. "|r"
    return function(text)
        if text == grey then return true end
        local p = Plain(text)
        return p:find("^%d+ %a") ~= nil or p:find(" %- online now$") ~= nil
    end
end

local function Mark(fs, own)
    if type(fs) ~= "table" or marked[fs] or rawget(fs, "mcSetText") ~= nil then return end
    if not (fs.GetObjectType and fs:GetObjectType() == "FontString") then return end
    local set, font = Method(fs, "SetText"), Method(fs, "SetFont")
    if type(set) ~= "function" or type(font) ~= "function" then return end
    marked[fs] = true
    rawset(fs, "mcSetText", set)
    rawset(fs, "mcSetFont", font)
    local function Take(self, text)
        rawset(self, "mcRaw", (type(text) == "string" and own(text)) and text or nil)
    end
    Take(fs, fs:GetText())
    hooksecurefunc(fs, "SetText", Take)       -- before Screen.lua's hook, so it reads this mcRaw
    ns.Screen.Hook(fs)
end

function R.Look(f)
    if type(f) ~= "table" then return end
    local profs, note = rawget(f, "profs"), rawget(f, "note")
    if profs and note and rawget(f, "name") and rawget(f, "cls") then
        Mark(profs, Always)
        Mark(note, Always)
    end
    local l1, l2, empty = rawget(f, "l1"), rawget(f, "l2"), rawget(f, "emptyText")
    if l1 and l2 and type(empty) == "string" and rawget(f, "num") then
        local own = TileOwn(empty)
        Mark(l1, own)
        Mark(l2, own)
    end
end

function R.Count()
    local n = 0
    for _ in pairs(marked) do n = n + 1 end
    return n
end
