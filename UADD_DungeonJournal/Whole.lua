-- Whole lines only (CLAUDE.md "No half translations", docs/LESSONS.md lesson 6). FDJ.LocalizeFreeText
-- puts each comma part (and each part between wide dashes) through its places on its own, so a quest
-- giver line "Name, Town, Zone" with one name UALL Forever lacks came out half Ukrainian. Wrapped (by
-- Language.lua's Install): when any part with Latin letters has no Ukrainian, the whole line stays
-- exactly English. Only while our language is shown; FDJ's own languages are left as they are.

local _, ns = ...
local W = {}
ns.Whole = W

local DASH = " \226\128\148 "   -- FDJ's wide dash between parts
local orig

local function Places()
    local fdj = rawget(_G, "ForeverDungeonJournal_NS")
    local c = fdj and type(fdj.ContentLocales) == "table" and fdj.ContentLocales[ns.Lang.LOCALE]
    return type(c) == "table" and type(c.places) == "table" and c.places or {}
end

-- One part: no Latin letters (a number, a mark, already Ukrainian), or a name FDJ's map has.
local function Known(part)
    return not part:find("%a") or orig(part) ~= part
end

local function AllKnown(piece, places)
    if places[piece] then return true end
    for _, part in ipairs(ns.Content.Parts(piece)) do
        if not Known(part) then return false end
    end
    return true
end

-- Our check runs under UADD.Safe (docs/LESSONS2.md lesson 19): on an error of ours the line is English.
local Check = UADD.Safe("dj", function(value, out)
    if out == value or type(value) ~= "string" or not ns.Lang.Active() then return out end
    local places = Places()
    if places[value] then return out end
    local rest = value
    while rest do
        local i = rest:find(DASH, 1, true)
        if not AllKnown(i and rest:sub(1, i - 1) or rest, places) then return value end
        rest = i and rest:sub(i + #DASH) or nil
    end
    return out
end)

local function LocalizeFreeText(value, ...)
    local out = orig(value, ...)
    local checked = Check(value, out)
    if checked == nil then return value end
    return checked
end
W.LocalizeFreeText = LocalizeFreeText

function W.Install(fdj)
    if type(fdj.LocalizeFreeText) == "function" and fdj.LocalizeFreeText ~= LocalizeFreeText then
        orig, fdj.LocalizeFreeText = fdj.LocalizeFreeText, LocalizeFreeText
    end
end

-- Puts FDJ's function back where nobody wrapped ours since.
function W.Uninstall(fdj)
    if orig and fdj.LocalizeFreeText == LocalizeFreeText then fdj.LocalizeFreeText = orig end
end
