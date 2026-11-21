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

-- ── Place: a pin named after its map ─────────────────────────────────────────────────────────────
-- A pin with no name of the player's is named with its map's name: Waypoint UI's own pins, and OpenMap's pins
-- with no note through TomTom. The core helper (UADD/Place.lua) asks ClassicUA / UALL Forever for it, only when
-- it is the name of the user waypoint's map or the player's map, or of a map above them (lesson 13).

-- The Ukrainian of a map's name, or nil; nil, true: not known yet (ask again later, do not keep the answer).
function ns.Place(en)
    local ok, w = false, nil
    if type(C_Map) == "table" and type(C_Map.GetUserWaypoint) == "function" then ok, w = pcall(C_Map.GetUserWaypoint) end
    return U.Place(en, U.UALL and U.UALL.Zone, ok and type(w) == "table" and w.uiMapID or nil)
end

-- The maps a Place answer depends on (the waypoint's and the player's), so a kept answer is asked again
-- when either changes.
function ns.PlaceMaps()
    if type(C_Map) ~= "table" then return "" end
    local ok, w = false, nil
    if type(C_Map.GetUserWaypoint) == "function" then ok, w = pcall(C_Map.GetUserWaypoint) end
    local ok2, p = false, nil
    if type(C_Map.GetBestMapForUnit) == "function" then ok2, p = pcall(C_Map.GetBestMapForUnit, "player") end
    return tostring(ok and type(w) == "table" and w.uiMapID) .. ":" .. tostring(ok2 and p)
end

-- Pinpoint: "<pin name>" or "<pin name>\n<grey line>". The name is the player's or a game name (lesson 13):
-- kept as it is, unless it is its map's name (Place). The grey line: one of our texts whole, or a line with
-- no English (the coordinates) kept as it is. Any other English in it keeps the whole text English (nil).
function ns.Pinpoint(en)
    en = U.Plain(en)
    if not en then return nil end
    local name, rest = en:match("^([^\n]*)\n(.*)$")
    if not rest then return ns.Place(en) end
    if rest:find("\n", 1, true) then return nil end
    local c, inner = rest:match("^(|c%x%x%x%x%x%x%x%x)(.*)|r$")
    local grey = inner or rest
    local uk = ns.Text(grey)
    if not uk then
        if U.HasLatin(grey) then return nil end
        uk = grey
    end
    local place, wait = ns.Place(name)
    local out = (place or name) .. "\n" .. (c and (c .. uk .. "|r") or uk)
    if out == en then return nil, wait end
    return out, wait
end
