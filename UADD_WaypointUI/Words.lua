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

-- ── Quest: a pin named after the quest the player tracks ─────────────────────────────────────────
-- For a quest's pin Waypoint UI takes the title from the quest API (the super-tracked quest's
-- C_QuestLog.GetTitleForQuestID), which is English on Forever. We tell it apart by that source, never by its
-- words: only a text equal to the tracked quest's title is asked, through UADD.UALL.Quest (lessons 9, 34).

-- The tracked quest's id and its English title, or nil.
local function Tracked()
    if type(C_SuperTrack) ~= "table" or type(C_SuperTrack.GetSuperTrackedQuestID) ~= "function" then return nil end
    local ok, id = pcall(C_SuperTrack.GetSuperTrackedQuestID)
    if not ok or type(id) ~= "number" or id <= 0 then return nil end
    if type(C_QuestLog) ~= "table" or type(C_QuestLog.GetTitleForQuestID) ~= "function" then return nil end
    local ok2, t = pcall(C_QuestLog.GetTitleForQuestID, id)
    t = ok2 and U.Plain(t) or nil
    if not t or t == "" or #t > 200 then return nil end
    return id, t
end

-- Is en the tracked quest's title? Then true, and its Ukrainian or nil (none: the whole text stays English);
-- nil, true as the 2nd and 3rd values: not known yet (ask again later, do not keep the answer).
function ns.Quest(en)
    local id, title = Tracked()
    if not id or en ~= title or not U.HasLatin(en) then return false end
    local route = U.UALL and U.UALL.Quest
    if type(route) ~= "function" then return true, nil end
    local ok, uk, wait = pcall(route, id, en)
    if not ok or type(uk) ~= "string" or uk == "" or uk == en then return true, nil, ok and wait and true or nil end
    return true, uk
end

-- A pin's name: the tracked quest's title (Quest) or its map's name (Place), else nil (kept as it is).
-- Returns the Ukrainian, "wait", and whether it is the quest's title.
local function Name(en)
    local isQuest, uk, wait = ns.Quest(en)
    if isQuest then return uk, wait, true end
    local place, w = ns.Place(en)
    return place, w, false
end

-- The waypoint's destination line: a quest's title or a map's name; any other name stays as typed.
function ns.Info(en)
    en = U.Plain(en)
    if not en then return nil end
    local uk, wait = Name(en)
    return uk, wait
end

-- What a Place or Quest answer depends on (the waypoint's map, the player's map, the tracked quest), so a kept
-- answer is asked again when one changes.
function ns.PlaceMaps()
    local q = Tracked()
    if type(C_Map) ~= "table" then return ":" .. tostring(q) end
    local ok, w = false, nil
    if type(C_Map.GetUserWaypoint) == "function" then ok, w = pcall(C_Map.GetUserWaypoint) end
    local ok2, p = false, nil
    if type(C_Map.GetBestMapForUnit) == "function" then ok2, p = pcall(C_Map.GetBestMapForUnit, "player") end
    return tostring(ok and type(w) == "table" and w.uiMapID) .. ":" .. tostring(ok2 and p) .. ":" .. tostring(q)
end

-- Pinpoint: "<pin name>" or "<pin name>\n<grey line>". The name is the player's or a game name (lesson 13):
-- kept as it is, unless it is the tracked quest's title (Quest) or its map's name (Place). A quest's title with
-- no Ukrainian keeps the whole text English. The grey line: one of our texts whole, or a line with no English
-- (the coordinates) kept as it is. Any other English in it keeps the whole text English (nil).
function ns.Pinpoint(en)
    en = U.Plain(en)
    if not en then return nil end
    local name, rest = en:match("^([^\n]*)\n(.*)$")
    if not rest then
        local uk, wait = Name(en)
        return uk, wait
    end
    if rest:find("\n", 1, true) then return nil end
    local c, inner = rest:match("^(|c%x%x%x%x%x%x%x%x)(.*)|r$")
    local grey = inner or rest
    local uk = ns.Text(grey)
    if not uk then
        if U.HasLatin(grey) then return nil end
        uk = grey
    end
    local place, wait, quest = Name(name)
    if quest and not place then return nil, wait end
    local out = (place or name) .. "\n" .. (c and (c .. uk .. "|r") or uk)
    if out == en then return nil, wait end
    return out, wait
end
