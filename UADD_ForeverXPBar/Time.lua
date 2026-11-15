-- Time values ForeverXP Bar builds from numbers, in Ukrainian: "4h 03m", "2d 5h", "36m", "<1m",
-- ">99d", "1h05", "1h12m", "5m03s", "1.5 h" and the day in "Fri 22:30". Only what the screen shows
-- changes: what the addon keeps or sends to other players stays its own English.
--   * Inside one of its texts (a %s slot: "Час на цьому рівні: %s"; a piece of a glued text), or
--     after a sign ("~4h 03m", "12%  (5m03s)"): the units stand apart, "4 год 03 хв", "5 хв 03 с".
--   * A text that is only the time (the countdown under a camp buff icon, a box on the level-up card):
--     short, with no spaces, "36хв", "45с", "1год12хв", "2д5год", so it still fits in a small space.
--     The camp icon's "1h05" (hours and minutes, no "m") becomes a clock, "1:05": it sits under a
--     20-pixel icon.
-- Cheap enough for every bar update: a length check, then a few matches tied to the start and end of
-- the text (so an XP amount such as "1.25m" never matches: the dot does not fit).

local _, ns = ...
local T = {}
ns.Time = T

local MAX = 24
local LONG = { d = "д", h = "год", m = "хв", s = "с" }
local SHORT = { d = "д", h = "год", m = "хв", s = "с" }
local DAYS = { Mon = "пн", Tue = "вт", Wed = "ср", Thu = "чт", Fri = "пт", Sat = "сб", Sun = "нд" }

-- t in Ukrainian, or nil when it is not one of the time shapes above. short: no spaces.
local function Convert(t, short)
    local p, r = t:match("^([~<>]?)(.*)$")
    local u, gap = short and SHORT or LONG, short and "" or " "
    local a, x, b, y = r:match("^(%d+)([dhms]) ?(%d+)([dhms])$")
    if a then return p .. a .. gap .. u[x] .. gap .. b .. gap .. u[y] end
    a, b = r:match("^(%d+)h(%d%d)$")
    if a then return short and p .. a .. ":" .. b or p .. a .. " " .. u.h .. " " .. b end
    a, x = r:match("^(%d+)([dhms])$")
    if a then return p .. a .. gap .. u[x] end
    a = r:match("^(%d+%.%d) h$")
    if a then return p .. a .. " " .. LONG.h end
    a, b = r:match("^(%a%a%a) (%d%d?:%d%d)$")
    if a and DAYS[a] then return p .. DAYS[a] .. " " .. b end
    return nil
end

-- A %s slot's value inside one of the addon's texts: units apart.
function T.Slot(t)
    if #t > MAX or not (t:find("^[~<>]?%d") or t:find("^%u%l%l %d")) then return nil end
    return Convert(t, false)
end

-- A whole text: short when it is only the time, units apart after a sign or "12%  (".
function T.Whole(t)
    if #t > MAX then return nil end
    local a, b, c = t:match("^(%d+%%  %()(.+)(%))$")
    if a then
        b = Convert(b, false)
        return b and a .. b .. c
    end
    if not (t:find("^[~<>]?%d") or t:find("^%u%l%l %d")) then return nil end
    return Convert(t, not t:find("^[~<>]"))
end
