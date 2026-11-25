-- UADD - OneForAll: pieces of a line that OneForAll joins in code with a dot ("Level 18  ·  Paladin  ·  0 / 12")
-- or a wide gap: each piece is ours (a text, a class from the glossary, a zone from UALL Forever or ClassicUA, a
-- value); one piece left English keeps the whole line English. The dot is drawn as our "  -  " (lesson 6).
-- Also its tooltip lines with a head before names ("Drops from: Boss (Dungeon)", "Target: Name"), with its own mark
-- ("OFA", an arrow, our text, "(replaces <item>)" in grey) and two of its words with a slash ("Rare / Optional").
-- Words.lua calls W.Joined after its own steps; it gives W.Atom, W.Value and W.Dungeon for the pieces. W.Headed is
-- its cheap gate for tooltip lines (W.Maybe).

local _, ns = ...
local U = UADD
local find, sub = string.find, string.sub
local W = ns.Words
local P = W.P
local Atom, Value = W.Atom, W.Value
local CYR = "[\208-\210]"
local MAXPIECES = 8

local function Class(p)
    local G = U.Glossary
    if not (G and G.Text) or #p > 80 or find(p, "[^%a, ]") then return nil end
    local out, n = {}, 0
    for name in string.gmatch(p, "[^,]+") do
        name = name:gsub("^%s+", ""):gsub("%s+$", "")
        local ok, uk = pcall(G.Text, "class." .. string.lower(name):gsub(" ", "_"))
        n = n + 1
        if n > 12 or not ok or type(uk) ~= "string" then return nil end
        out[n] = uk
    end
    return n > 0 and table.concat(out, ", ") or nil
end

local function Zone(p)
    if #p > 60 or find(p, "[|%[%(\n%d]") or not find(p, "^%u") then return nil end
    P.asked = true                                -- a game name: a miss now may be an answer later, never kept
    local route = UADD.UALL and UADD.UALL.Zone
    if type(route) ~= "function" then return nil end
    local ok, uk = pcall(route, p)
    if ok and type(uk) == "string" and uk ~= p and find(uk, CYR) then return uk end
    return nil
end

local function Coords(p) return find(p, "^%(?%d+%.?%d*, %d+%.?%d*%)?$") and p or nil end

local Joined

local function Piece(p)
    local lead = p:match("^|c%x%x%x%x%x%x%x%x") or ""
    local core = sub(p, #lead + 1)
    local tail = core:match("|r$") or ""
    core = sub(core, 1, #core - #tail)
    core = core:gsub("^%s+", ""):gsub("%s+$", "")
    if core == "" or not find(core, "%w") then return nil end
    local uk = Atom(core) or Class(core) or Coords(core) or Value(core) or Zone(core)
    if not uk then
        local z, c = core:match("^(%u[^%d|%(]-)%s+([%(%d][%d%.,%) ]*)$")
        local zk = z and Zone(z)
        if zk and Coords(c) then uk = zk .. " " .. c end
    end
    if not uk and find(core, "  ", 1, true) then uk = Joined(core) end
    return uk and (lead .. uk .. tail) or nil
end

function Joined(s)
    if #s > 300 then return nil end
    local dot = find(s, "\194\183", 1, true)   -- the addon's middle dot (bytes: a pattern, not text we draw)
    if not dot and not find(s, "  ", 1, true) then return nil end
    local out, n, pos = {}, 0, 1
    while pos <= #s + 1 do
        -- the next separator: a dot between wide gaps, maybe in its own colour, or a wide gap
        local a, b, code = find(s, "%s%s(|?c?%x*)\194\183%s%s", pos)
        if a and code ~= "" and not find(code, "^|c%x%x%x%x%x%x%x%x$") then a = nil end
        local sep = "  -  "
        if a then
            sep = "  " .. code .. "-  "
        else
            a, b = find(s, "  +", pos)
            sep = a and sub(s, a, b) or ""
        end
        local piece = sub(s, pos, (a or #s + 1) - 1)
        n = n + 1
        if n > MAXPIECES then return nil end
        local uk = Piece(piece)
        if not uk then return nil end
        out[n] = uk
        if not a then break end
        out[n + 1] = sep
        n = n + 1
        pos = b + 1
    end
    return table.concat(out)
end

local TAG = "|cffc8961eOFA|r "                    -- its mark before its gear lines, kept as it is
local GREY = "  |cffb0b0b0"                       -- a second part in grey: "(replaces <item>)"

local function Npc(p)
    if #p == 0 or #p > 60 or find(p, "[|%[%(\n]") or not find(p, "^%u") or find(p, "%s$") then return nil end
    P.asked = true                                -- a game name, as in Zone
    local route = UADD.UALL and UADD.UALL.Npc
    if type(route) ~= "function" then return nil end
    local ok, uk = pcall(route, p)
    if ok and type(uk) == "string" and uk ~= p and find(uk, CYR) then return uk end
    return nil
end

-- "Boss (Dungeon), Boss (Dungeon) +3": every name known, else the whole line stays English.
local function Drops(x)
    local plus = x:match(" %+%d+$") or ""
    x = sub(x, 1, #x - #plus)
    local out, n, pos = {}, 0, 1
    while n < MAXPIECES do
        local a = find(x, " (", pos, true)
        local b = a and find(x, ")", a, true)
        if not b then return nil end
        local boss, place = Npc(sub(x, pos, a - 1)), W.Dungeon(sub(x, a + 2, b - 1))
        if not (boss and place) then return nil end
        n = n + 1
        out[n] = boss .. " (" .. place .. ")"
        if b == #x then return table.concat(out, ", ") .. plus end
        if sub(x, b + 1, b + 2) ~= ", " then return nil end
        pos = b + 3
    end
    return nil
end

-- A player's name in its class colour (one word) is kept; ">> You <<" is ours; an NPC's name is asked.
local function Target(x)
    local c, name = x:match("^(|c%x%x%x%x%x%x%x%x)([^|\n]+)|r$")
    if not c then return Npc(x) end
    local you = name:match("^>> (%a+) <<$")
    if you then
        local uk = P.Exact(you)
        return uk and (c .. ">> " .. uk .. " <<|r") or nil
    end
    return find(name, "^%S+$") and x or nil
end

local NAMED = { ["Drops from:"] = Drops, ["Target:"] = Target }

local function Named(s)
    local e = find(s, ": ", 1, true)
    local f = e and e < 20 and NAMED[sub(s, 1, e)]
    local head = f and P.Exact(sub(s, 1, e))
    local rest = head and f(sub(s, e + 2))
    return rest and (head .. " " .. rest) or nil
end

local function Two(x)                             -- "Downgrade: 4.0% (overall 2.0%)": two texts of ours
    local uk = Atom(x)
    if uk then return uk end
    local a = find(x, " (", 1, true)
    local l, r = a and Atom(sub(x, 1, a - 1)), a and Atom(sub(x, a + 1))
    return l and r and (l .. " " .. r) or nil
end

-- A template with one slot at a..b of s, whose letter is `letter` (Shapes alone does not find these two kinds).
local function Slot(s, a, b, letter, uk)
    local k = "Code." .. U.Hash(sub(s, 1, a - 1) .. "%s" .. sub(s, b + 1))
    local t = ns.OFA[k]
    if not uk or type(t) ~= "string" or ns.SORT[k] ~= letter then return nil end
    local ok, out = pcall(string.format, t, uk)
    return ok and out or nil
end

local function Clock(s)                           -- "Next free instance in 12:34.": a clock inside the text
    local a, b = find(s, "%d+:%d%d[:%d]*")
    return a and Slot(s, a, b, "v", sub(s, a, b)) or nil
end

-- "26 |4Min:Min; ago" (the game's SecondsToTime) or "26 min ago" (its own): one unit, ours, else the line is English.
local UNITS = { sec = "с", min = "хв", hr = "год", hrs = "год", day = "д", days = "д" }
local function Age(s)
    local a, b, n, unit = find(s, "(%d+) |4(%a+):%a+;")
    if not a then a, b, n, unit = find(s, "(%d+) (%a+)") end
    local uk = a and UNITS[string.lower(unit)]
    return uk and Slot(s, a, b, "v", n .. " " .. uk) or nil
end

local COORD = "%d+%.%d, %d+%.%d$"                 -- "Coordinates: 12.3, 45.6": a %.1f template
local function Spot(s)
    local a = find(s, COORD)
    local uk = a and ns.OFA["Code." .. U.Hash(sub(s, 1, a - 1) .. "%.1f, %.1f")]
    return type(uk) == "string" and (uk:gsub("%%%.1f, %%%.1f", function() return sub(s, a) end)) or nil
end

local function Worn(s)                            -- "(replaces <item>)"
    local a = find(s, " ", 1, true)
    if not a or sub(s, -1) ~= ")" then return nil end
    P.asked = true                                -- a game name, as in Zone
    return Slot(s, a + 1, #s - 1, "n", P.Item(sub(s, a + 1, -2)))
end

local function Tag(s)
    if sub(s, 1, #TAG) ~= TAG then return nil end
    local a = #TAG + 1
    if sub(s, a, a + 1) == "|T" then
        local e = find(s, "|t ", a, true)
        if not e then return nil end
        a = e + 3
    end
    local g = find(s, GREY, a, true)
    local uk = Two(sub(s, a, (g or #s + 1) - 1))
    if not uk then return nil end
    if not g then return sub(s, 1, a - 1) .. uk end
    if sub(s, -2) ~= "|r" then return nil end
    local last = sub(s, g + #GREY, -3)
    local grey = Atom(last) or Worn(last)
    return grey and (sub(s, 1, a - 1) .. uk .. GREY .. grey .. "|r") or nil
end

local function Slash(s)                           -- "Rare / Optional"
    local a = find(s, " / ", 1, true)
    if not a then return nil end
    local l, r = P.Exact(sub(s, 1, a - 1)), P.Exact(sub(s, a + 3))
    return l and r and (l .. " / " .. r) or nil
end

-- Cheap (lesson 12): does a tooltip line start with a head its code fills or glues? By its first bytes only.
local HEADS = { "Drops from: ", "Target: ", "On your wishlist: ", "Killed after ", "Quests in your log: ",
    "Instances this hour: ", "The game lets you enter ", "Next free instance in ", "Sort by ", "Last scan here: ",
    "Ready again in about ", "Coordinates: ", "Object: ", "Territory: ", TAG }

function W.Headed(s)
    for i = 1, #HEADS do
        if sub(s, 1, #HEADS[i]) == HEADS[i] then return true end
    end
    return false
end

function W.Joined(s) return Named(s) or Tag(s) or Slash(s) or Joined(s) or Clock(s) or Age(s) or Spot(s) end
