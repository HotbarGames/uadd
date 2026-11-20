-- UADD_WaypointUI words: our Ukrainian for Waypoint UI's texts, looked up by a hash of its English
-- (data/text01.lua, made by tools/make_wp_text.py build), and its units (distance and time) by pattern.
-- Waypoint UI has no licence file (all rights reserved): no English of it here.
-- A line is all Ukrainian or all English: a template fills only slots tools/wp_rules.py SORTS allows
-- (a value, or a free name kept as it is); anything else gives nil and the line stays English.
local _, ns = ...
local U = UADD

ns.WP = ns.WP or { exact = {}, templates = {} }
ns.Words = U.NewWords(ns.WP)

-- The last English and its answer per kind of line: the arrival time is set on every tick (lesson 12).
local last = { text = {}, units = {} }

local function Cached(box, en, fn)
    if box.en == en then return box.uk end
    local ok, uk = pcall(fn, en)
    box.en, box.uk = en, ok and uk or nil
    return box.uk
end

-- Our Ukrainian for a whole text of Waypoint UI, or nil.
local function Look(en)
    local uk = ns.Words.Translate(en)
    if type(uk) ~= "string" or uk == en then return nil end
    return uk
end

function ns.Text(en)
    en = U.Plain(en)
    if not en or en == "" or not U.HasLatin(en) then return nil end
    return Cached(last.text, en, Look)
end

-- ── Units (lead decision 3): values only; any other English keeps the whole line English ──────────

local YARDS = "{ярд|ярди|ярдів}"                -- the glossary's ui.yards («ярдів») in its three forms
local UNIT = { m = "м", km = "км" }
local TIME = { h = "год", m = "хв", s = "с" }

-- "1,234 yds" / "250 m" / "1.25 km" -> Ukrainian, else nil. Each pattern is anchored, one run only.
local function Distance(s)
    local n = s:match("^(%d[%d,]*) yds$")
    if n then return U.Plural(n .. " " .. YARDS, true) end
    local v, u = s:match("^(%d[%d%.]*) (k?m)$")
    if v then return v .. " " .. UNIT[u] end
end

-- "1h 5m 3s", "5m ", "12s" -> «1 год 5 хв 3 с», else nil. Only number+unit pieces and spaces.
local function Time(s)
    if #s > 32 or s:find("[^%dhms ]") then return nil end
    local out, rest = {}, s
    while true do
        rest = rest:gsub("^ +", "")
        if rest == "" then break end
        local n, u, after = rest:match("^(%d+)([hms])(.*)$")
        if not n then return nil end
        out[#out + 1] = n .. " " .. TIME[u]
        rest = after
    end
    return #out > 0 and table.concat(out, " ") or nil
end

local function Units(s)
    return Distance(s) or Time(s)
end

function ns.Units(en)
    en = U.Plain(en)
    if not en or en == "" or not en:find("%d") then return nil end
    return Cached(last.units, en, Units)
end

-- Pinpoint: "<pin name>\n<grey line>". The name is the player's or a game name (lesson 13): kept as it is.
-- Only a grey line that is one of our texts whole is changed; else nil.
function ns.Pinpoint(en)
    en = U.Plain(en)
    if not en then return nil end
    local name, rest = en:match("^([^\n]*)\n(.*)$")
    if not rest or rest:find("\n", 1, true) then return nil end
    local c, inner = rest:match("^(|c%x%x%x%x%x%x%x%x)(.*)|r$")
    local uk = ns.Text(inner or rest)
    if not uk then return nil end
    return name .. "\n" .. (c and (c .. uk .. "|r") or uk)
end
