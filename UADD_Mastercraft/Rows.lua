-- UADD - Mastercraft: more rows it glues in code (Glue.lua calls R.New's reader last): where a recipe comes
-- from, tooltip rows with a mark or a count before the name, lists of zones. Each part is ours or a game name
-- (ClassicUA, UALL Forever); one part with no Ukrainian leaves the whole row English. Plain finds only, never a
-- pattern with two lazy runs (docs/LESSONS2.md lesson 22).

local _, ns = ...
local P = ns.Split
local R = {}
ns.Rows = R
R.FAVOR = "Прихильність Крамаря"        -- UALL Forever's word for the trade hub's currency

local NPC, ZONE, QUEST, RECIPE = { "Npc" }, { "Zone" }, { "Text" }, { "Item", "Spell" }
local COLOUR = "|c%x%x%x%x%x%x%x%x"
local TAG = { [" (A)"] = " (А)", [" (H)"] = " (О)" }        -- the vendor's side: Alliance, Horde
-- a zone its data writes short: asked as it is first, then by its whole name
local SHORT = {
    Barrens = "The Barrens", Redridge = "Redridge Mountains", Stranglethorn = "Stranglethorn Vale",
    Hillsbrad = "Hillsbrad Foothills", Dustwallow = "Dustwallow Marsh", Alterac = "Alterac Mountains",
    Arathi = "Arathi Highlands", Stormwind = "Stormwind City", Theramore = "Theramore Isle",
    ["1000 Needles"] = "Thousand Needles", ["W. Plaguelands"] = "Western Plaguelands",
    ["E. Plaguelands"] = "Eastern Plaguelands", BRD = "Blackrock Depths",
}

-- the last place of a mark in a line
local function Last(s, mark)
    local p, from = nil, 1
    while true do
        local a = s:find(mark, from, true)
        if not a then return p end
        p, from = a, a + 1
    end
end

-- The rows above that Mastercraft puts in tooltips (Tooltip.lua's cheap gate, Maybe): true when s has the shape.
function R.Could(s)
    return s:find("^> [^>%s]") ~= nil or s:find("^%d+ x %S") ~= nil or s:find("^" .. COLOUR .. "%*|r ") ~= nil
        or s:find("^" .. COLOUR .. "Mastercraft|r  ") ~= nil or s:find(", level %d") ~= nil
        or s:find("^%a[%a ]*:  |c") ~= nil or s:find("^Drop: ") ~= nil or P.Count(s) ~= nil
        or (s:sub(-3) == ")|r" and s:find(COLOUR .. " %([%d%-]+%)|r$") ~= nil)
end

-- H: One, Name, HasLatin, Translate(s), Lower1(s) (Glue.lua).
function R.New(H)
    local One, Name, HasLatin, Translate, Lower1 = H.One, H.Name, H.HasLatin, H.Translate, H.Lower1

    local function Zone(z)
        return One(z, ZONE) or SHORT[z] and One(SHORT[z], ZONE) or nil
    end

    -- a vendor, maybe with its side
    local function Npc(v)
        local tag = TAG[v:sub(-4)]
        local ua = One(tag and v:sub(1, -5) or v, NPC)
        return ua and (ua .. (tag or ""))
    end

    -- our words before a slot at the end of one of our templates ("<words> %s"), read with a number in it
    local function Head(words)
        local t = Translate(words .. "7")
        return t and t:sub(-1) == "7" and t:sub(1, -2) or nil
    end

    -- "Sold by <npc> (A) - <zone>"
    local function Sold(s)
        if s:sub(1, 8) ~= "Sold by " then return nil end
        local d = s:find(" - ", 9, true)
        local npc = Npc(s:sub(9, d and d - 1))
        local zone = d and Zone(s:sub(d + 3))
        local head = npc and (zone or not d) and Head("Sold by ")
        return head and (head .. npc .. (zone and (" - " .. zone) or ""))
    end

    -- what it costs: money as it is, or the trade hub's favour
    local function Cost(v)
        if not HasLatin(v) then return v end
        local n = v:match("^(%d+) Merchant's Favor$")
        return n and (R.FAVOR .. ": " .. n)
    end

    -- "Vendor: <npc> (A) / <npc> (H) - <cost>"
    local function Vendor(s)
        if s:sub(1, 8) ~= "Vendor: " then return nil end
        local d = Last(s, " - ")
        local cost = d and Cost(s:sub(d + 3))
        if d and not cost then return nil end
        local out = {}
        for part in (s:sub(9, d and d - 1) .. " / "):gmatch("(.-) / ") do
            local npc = Npc(part)
            if not npc then return nil end
            out[#out + 1] = npc
        end
        local head = Head("Vendor: ")
        return head and (head .. table.concat(out, " / ") .. (cost and (" - " .. cost) or ""))
    end

    -- "Drop: <npc> (<zone>) 0.31%" (no key: our "Drops from:")
    local function Drop(s)
        if s:sub(1, 6) ~= "Drop: " then return nil end
        local body = s:sub(7)
        local pct = body:match(" <?[%d%.]+%%$") or ""
        body = body:sub(1, #body - #pct)
        local p = body:sub(-1) == ")" and Last(body, " (")
        local npc = One(p and body:sub(1, p - 1) or body, NPC)
        local zone = p and Zone(body:sub(p + 2, -2))
        local head = npc and (zone or not p) and Translate("Drops from:")
        return head and (head .. " " .. npc .. (zone and (" (" .. zone .. ")") or "") .. pct)
    end

    -- "<creature>, level 21-22 - <zone>: 0.31%"
    local function Creature(s)
        local a = s:find(", level ", 2, true)
        if not a then return nil end
        local n, rest = s:sub(a + 8):match("^(%d+%-?%d*) %- (.+)$")
        local c = rest and Last(rest, ": ")
        if not c or HasLatin(rest:sub(c)) then return nil end
        local npc, zone, lv = One(s:sub(1, a - 1), NPC), Zone(rest:sub(1, c - 1)), Head("Level ")
        if not (npc and zone and lv) then return nil end
        return npc .. ", " .. Lower1(lv) .. n .. " - " .. zone .. rest:sub(c)
    end

    -- a mark of the addon's, then a text: "> <text>", a star, its own name in colour
    local function Marked(s)
        local mark = s:match("^(> )[^>]") or s:match("^" .. COLOUR .. "%*|r ") or s:match("^" .. COLOUR .. "Mastercraft|r  ")
        local t = mark and Translate(s:sub(#mark + 1))
        return t and (mark .. t)
    end

    -- "<zone>|cff...... (42-55)|r"
    local function Range(s)
        local zone, tail = s:match("^([^|]+)(" .. COLOUR .. " %([%d%-]+%)|r)$")
        local ua = zone and Zone(zone)
        return ua and (ua .. tail)
    end

    -- "<profession>:  <numbers in colours>" (a node's skill levels)
    local function Numbers(s)
        local label, tail = s:match("^(%a[%a ]*):  (|c.+)$")
        if not label or HasLatin(tail) then return nil end
        local t = Translate(label)
        return t and (t .. ":  " .. tail)
    end

    -- "Learn <rank> (level 35): <npc>, <zone> (63.4, 20.8)", maybe " - <note>" after it
    local function Learn(s)
        if s:sub(1, 6) ~= "Learn " then return nil end
        local a, b = s:find(" %(%d+%.%d, %d+%.%d%)")
        if not a then return nil end
        local note = s:sub(b + 1)
        local head, tail = Translate(s:sub(1, a - 1)), ""
        if note ~= "" then
            local t = note:sub(1, 3) == " - " and Translate(note:sub(4))
            if not t then return nil end
            tail = " - " .. t
        end
        return head and (head .. s:sub(a, b) .. tail)
    end

    -- two of its sentences joined with one space: the first in colour with its full stop, the next starting in one
    local function Two(s)
        local p = s:find(".|r |c", 1, true)
        if not p or s:sub(1, 2) ~= "|c" then return nil end
        p = p + 1
        local a = Translate(s:sub(1, p + 1))
        local b = a and Translate(s:sub(p + 3))
        return b and (a .. " " .. b)
    end

    -- players' names, kept as they are: a word in small letters means a phrase (lesson 7)
    local function Players(v) return not v:find("%f[%a]%l%a") end

    -- "<recipe> x4  |cff8a93a6(<profession>)|r", maybe "  <who>": the players who know it (grey or green) are kept
    local function Used(s)
        local a, b = s:find("  |cff8a93a6(", 2, true)
        local c, d = s:find(")|r", b or #s, true)
        if not a or not c then return nil end
        local who = s:sub(d + 1)
        local own = who:match("^  |cff8a93a6([^|]+)|r$") or who:match("^  |cff3dc773([^|]+)|r$")
        if who ~= "" and not (own and Players(own)) then
            who = who:sub(1, 2) == "  " and Translate(who)
        end
        local head, prof = Name(s:sub(1, a - 1), RECIPE, true), Translate(s:sub(b + 1, c - 1))
        if not (head and prof and who) or head == s:sub(1, a - 1) then return nil end
        return head .. "  |cff8a93a6(" .. prof .. ")|r" .. who
    end

    -- "|cff......<player>|r  |cff8a93a613 in bags, 5 in bank|r": the player's name is kept
    local function Owner(s)
        local c, who, counts = s:match("^(" .. COLOUR .. ")([^|]+)|r  |cff8a93a6(%d+ in [^|]+)|r$")
        local head = who and Players(who) and (c .. who .. "|r  |cff8a93a6")
        local t = head and Translate(counts)
        return t and not HasLatin(t) and (head .. t .. "|r") or nil
    end

    -- "|cffffd140<quest>|r   |cff5c6373level 60, needs level 50|r"
    local function Quest(s)
        local title, n, needs = s:match("^|cffffd140([^|]+)|r   |cff5c6373level (%d+)([^|]*)|r$")
        if not title then return nil end
        local ua, lv = One(title, QUEST), Head("Level ")
        local t = needs == "" and "" or Translate(needs)
        if not (ua and lv and t) then return nil end
        return "|cffffd140" .. ua .. "|r   |cff5c6373" .. Lower1(lv) .. n .. t .. "|r"
    end

    -- "<zone>, <zone>, <zone>  +2": zones alone, every one known, at least one of two words ("Thrall, Jaina"
    -- may be players, lesson 13)
    local function Zones(s)
        if #s > 300 or not s:find(", ", 2, true) or s:find("[|:%(]") then return nil end
        local more = s:match("  %+%d+$") or ""
        local out, wide = {}, false
        for part in (s:sub(1, #s - #more) .. ", "):gmatch("(.-), ") do
            local z = Zone(part)
            if not z then return nil end
            wide = wide or part:find(" ", 1, true) ~= nil
            out[#out + 1] = z
        end
        return wide and (table.concat(out, ", ") .. more) or nil
    end

    -- (Owner runs before any template: a slot would ask the player's name as a game name, lesson 13)
    return function(s)
        return Sold(s) or Vendor(s) or Drop(s) or Creature(s) or Marked(s) or Range(s) or Numbers(s) or Learn(s)
            or Two(s) or Used(s) or Quest(s) or Zones(s)
    end, Owner
end
