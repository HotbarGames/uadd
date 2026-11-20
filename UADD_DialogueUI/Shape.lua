-- The shape of a text, for Words.lua: its upper case; is a %s value one name, does a line have English
-- words? The last two keep a line whole: all Ukrainian or all English (CLAUDE.md "No half translations").

local _, ns = ...
local Sh = {}
ns.Shape = Sh

-- Upper case, Cyrillic too: Lua's upper does not touch Cyrillic letters, so they go by hand.
local UP = {}
do
    for i = 0, 15 do UP["\208" .. string.char(0xB0 + i)] = "\208" .. string.char(0x90 + i) end   -- а-п
    for i = 0, 15 do UP["\209" .. string.char(0x80 + i)] = "\208" .. string.char(0xA0 + i) end   -- р-я
    UP["\209\150"], UP["\209\151"], UP["\209\148"] = "\208\134", "\208\135", "\208\132"        -- і ї є
    UP["\210\145"] = "\210\144"                                                                   -- ґ
end

function Sh.Upper(s)
    s = s:gsub("[\208\209\210][\128-\191]", UP)
    if not s:find("|", 1, true) then s = s:upper() end   -- escape codes (|cff..) stay as they are
    return s
end

-- A %s kept as it is holds one name or a value, never two texts glued (a wide gap, " - ") nor a phrase:
-- a word all in small letters, other than a name's small joining words, says no (docs/LESSONS.md
-- lesson 7). The template does not fit then, and the line stays English.
local JOIN = { a = true, an = true, the = true, of = true, ["and"] = true, ["or"] = true, to = true,
    ["in"] = true, on = true, at = true, by = true, ["for"] = true, from = true, with = true, into = true,
    de = true, des = true, la = true, le = true, du = true, von = true, van = true, der = true, del = true }

function Sh.OneName(v)
    v = v:gsub("|H.-|h", ""):gsub("|h", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", " ")
    if v:find("  ", 1, true) or v:find(" - ", 1, true) then return false end
    for w in v:gmatch("[%w']+") do
        if w:find("^%l[%l%d']*$") and not JOIN[w] then return false end
    end
    return true
end

-- An English word in a line: two Latin letters in a row once colour codes, pictures and links are out.
function Sh.HasWords(line)
    line = line:gsub("|H.-|h.-|h", " "):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", " ")
    return line:find("%a%a") ~= nil
end
