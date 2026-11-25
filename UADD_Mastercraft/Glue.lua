-- UADD - Mastercraft: shapes Mastercraft glues together in code (no key of their own). Words.lua hands in its
-- helpers (ns.Glue(H)) and gets back Code, Late and Owner. Each part is ours or a game name (UALL Forever,
-- ClassicUA first); a part with no Ukrainian leaves the whole line English (no half lines).
-- H: One, Name, Joined, HasLatin, Translate(s), Upper(s).

local _, ns = ...

function ns.Glue(H)
    local One, Name, Joined, HasLatin, Translate = H.One, H.Name, H.Joined, H.HasLatin, H.Translate
    local SPEC = { Armorsmith = true, Weaponsmith = true }   -- the two specialization cards: spell names
    local CAPS = { ["MERCHANT'S FAVOR"] = ns.Rows.FAVOR }   -- a heading in its code (the apostrophe)
    local KEYC = "|cff3dc773"                                -- the colour our "N of M recipes" key is bound to

    -- the first letter of a Cyrillic word in small letters ("Рівень" -> "рівень")
    local function Lower1(t)
        t = t:gsub("^\208([\144-\159])", function(c) return "\208" .. string.char(c:byte() + 32) end)
        return (t:gsub("^\208([\160-\175])", function(c) return "\209" .. string.char(c:byte() - 32) end))
    end

    -- the last " (" in a line, by plain find (no pattern with lazy runs)
    local function LastParen(s)
        local p, from = nil, 0
        while true do
            local a = s:find(" (", from + 1, true)
            if not a then return p end
            p, from = a, a
        end
    end

    local Row, Owner = ns.Rows.New({ One = One, Name = Name, HasLatin = HasLatin, Translate = Translate, Lower1 = Lower1 })

    -- a number in another colour than the key's ("|cff......58|r of 104 ..."): the key's colour, then the line's back
    local function Lead(s)
        local c, num, rest = s:match("^(|c%x%x%x%x%x%x%x%x)([%d%.,]+)|r(.+)$")
        if not c or c == KEYC then return nil end
        local t = Translate(KEYC .. num .. "|r" .. rest)
        if not t then return nil end
        local back = t:gsub(KEYC:gsub("%p", "%%%0"), (c:gsub("%%", "%%%%")))
        return back
    end

    -- "<text> (<duration> ago)": the text and the duration each alone
    local function Ago(s)
        if s:sub(-5) ~= " ago)" then return nil end
        local p = LastParen(s)
        if not p or p < 2 then return nil end
        -- the duration alone ("21h 24m" -> "21 год 24 хв"), then our "тому": never English units left
        local h, d = Translate(s:sub(1, p - 1)), Translate(s:sub(p + 2, -6))
        if not (h and d) or HasLatin(d) then return nil end
        return h .. " (" .. d .. " тому)"
    end

    -- "<text> about <money>": the text, our "приблизно", the value as it is (a proposal word, not in the glossary)
    local function About(s)
        local a = s:find(" about ", 1, true)
        if not a or a < 2 then return nil end
        local tail = s:sub(a + 7)
        if tail == "" or HasLatin(tail) then return nil end
        local h = Translate(s:sub(1, a - 1))
        return h and (h .. " приблизно " .. tail)
    end

    -- "<npc> (level 37, <zone>): 71%": the npc, the zone and "level" from UALL Forever / our words
    local function Level(s)
        local a = s:find(" (level ", 1, true)
        if not a or a < 2 then return nil end
        local n, zone, tail = s:sub(a + 8):match("^(%d+), ([^%)]+)%)(.*)$")
        if not n or HasLatin(tail) then return nil end
        local npc, z = One(s:sub(1, a - 1), { "Npc" }), One(zone, { "Zone" })
        local lv = Translate("Level " .. n)
        if not (npc and z and lv) then return nil end
        return npc .. " (" .. Lower1(lv) .. ", " .. z .. ")" .. tail
    end

    -- "<item> x4 (<profession>)"
    local function Suffix(s)
        local p = LastParen(s)
        if not p or p < 2 or s:sub(-1) ~= ")" then return nil end
        local prof = s:sub(p + 2, -2)
        if prof:find("[^%a ]") or prof:find("^level") then return nil end
        local head = Name(s:sub(1, p - 1), { "Item" }, true)
        local pu = Translate(prof)
        if not (head and pu and head ~= s:sub(1, p - 1)) then return nil end
        return head .. " (" .. pu .. ")"
    end

    -- "13 in bags, 5 in bank": counts joined with a comma, each alone
    local function Counts(s)
        if not s:find("^%d") or not s:find(", ", 1, true) then return nil end
        local out = Joined(s, ", ", ", ")
        -- after a comma our word goes on in small letters («у банку»)
        return out and (out:gsub(", \208([\144-\175])", function(c)
            local b = c:byte()
            return b < 160 and (", \208" .. string.char(b + 32)) or (", \209" .. string.char(b - 32))
        end))
    end

    local function Code(s)
        if SPEC[s] then return One(s, { "Spell" }) end
        return Lead(s) or Ago(s) or About(s) or Level(s) or Suffix(s) or Counts(s) or Row(s)
    end

    -- "<X> to <Y>, <X> to <Y>": the transmutes' names, each as the spell "Transmute: <X> to <Y>"
    local function Transmutes(s)
        local out = {}
        for part in (s .. ", "):gmatch("(.-), ") do
            local t = part:find(" to ", 1, true) and One("Transmute: " .. part, { "Spell" })
            t = t and t:match(":%s*(.+)$")
            if not t then return nil end
            out[#out + 1] = t
        end
        return #out > 0 and table.concat(out, ", ") or nil
    end

    -- one part of a chip or row joined with two spaces ("Drop: <npc>" is a row of Rows.lua)
    local function Part(p)
        if not HasLatin(p) then return p end
        return Translate(p) or (#p < 200 and Transmutes(p)) or nil
    end

    local function Chip(s)
        if #s > 400 or s:find("   ", 1, true) or s:find("\n", 1, true) or not s:find("  ", 1, true) then return nil end
        local out = {}
        for part in (s .. "  "):gmatch("(.-)  ") do
            local t = part
            if part ~= "" then t = Part(part) end
            if not t then return nil end
            out[#out + 1] = t
        end
        return #out > 1 and table.concat(out, "  ") or nil
    end

    -- a heading Mastercraft writes in capitals ("NOW"): the word in small letters, then Ukrainian capitals
    local function Caps(s)
        if CAPS[s] then return H.Upper(CAPS[s]) end
        if #s > 40 or not s:find("^%u%u[%u ]*$") then return nil end
        local t = Translate(s:sub(1, 1) .. s:sub(2):lower())
        return t and H.Upper(t)
    end

    local function Late(s)
        return Caps(s) or Chip(s)
    end

    return Code, Late, Owner
end
