-- UADD.CodeText: the shared base of modules whose addon keeps its words in its own code or a private table
-- (LootTriage, DeleteCheapestItem Reloaded). Our Ukrainian is known by the hash of each English text
-- ("Code." .. UADD.Hash), never by its English. A module makes one with its two data tables:
--   local H = UADD.CodeText(T, SORT)      -- T: key -> Ukrainian; SORT: key -> what each slot holds
-- and gets:
--   H.Key(s), H.Exact(s)          the key of a text; our Ukrainian of a whole text that is no template
--   H.Codes(s), H.InCode(c, a, b) the escape codes of a text ({ a, b, link }); is a range inside one
--   H.Link(text)                  a link with its name from UALL Forever or ClassicUA (lesson 20), or nil
--   H.Value(x)                    money as the game draws it (digits, |T|t, |c|r), maybe then our piece
--   H.Free(en)                    can a free slot keep this as it is (no word in small letters, lesson 7)
--   H.Fill(s, slots, Resolve)     the template the slots make of s, looked up and filled, or nil
--   H.asked                       a game-name route was asked (its answer may come later: not cached)
--   H.matched                     a template of ours matched in the last Fill
-- A slot is { a, b, en, d (a number: %d) }; Resolve(letter, slot) gives what it puts in, or nil: then the
-- whole line stays English (no half lines). Nothing here stores another addon's English.

local U = UADD
local find, sub, byte, match, format = string.find, string.sub, string.byte, string.match, string.format
local concat, unpack = table.concat, unpack
local CYR = "[\208-\210]"

-- The escape codes of a text, in order: { a, b, link } (a link with its colour and |r is one range).
local function Codes(s)
    local out, i, n = {}, 1, #s
    while i < n do
        local p = find(s, "|", i, true)
        if not p or p >= n then break end
        local c, e, link = sub(s, p + 1, p + 1), nil, false
        if c == "c" then e = p + 9
        elseif c == "T" then e = select(2, find(s, "|t", p + 2, true))
        elseif c == "A" then e = select(2, find(s, "|a", p + 2, true))
        elseif c == "H" then
            local h1 = find(s, "|h", p + 2, true)
            local h2 = h1 and find(s, "|h", h1 + 2, true)
            e, link = h2 and h2 + 1, true
        else e = p + 1 end
        if not e then break end
        local a = p
        if link then
            local last = out[#out]
            if last and not last[3] and last[2] == p - 1 and sub(s, last[1], last[1] + 1) == "|c" then
                a = last[1]
                out[#out] = nil
            end
            if sub(s, e + 1, e + 2) == "|r" then e = e + 2 end
        end
        out[#out + 1] = { a, e, link }
        i = e + 1
    end
    return out
end

local function InCode(codes, a, b)
    for _, c in ipairs(codes) do if a <= c[2] and b >= c[1] then return true end end
    return false
end

local function Free(en) return type(en) == "string" and not find(" " .. en, "%s%l") end

function U.CodeText(T, SORT)
    local H = { asked = false, matched = false, Codes = Codes, InCode = InCode, Free = Free }

    local function Key(s) return "Code." .. U.Hash(s) end

    local function Exact(s)
        if type(s) ~= "string" or s == "" then return nil end
        local k = Key(s)
        if SORT[k] then return nil end
        local uk = T[k]
        return type(uk) == "string" and uk or nil
    end

    -- A link with the name between its brackets in Ukrainian, or nil.
    local function Link(text)
        local R = U.UALL
        local o = find(text, "|h[", 1, true)
        local c = o and find(text, "]|h", o + 3, true)
        if type(R) ~= "table" or not c then return nil end
        local name, kind = sub(text, o + 3, c - 1), match(text, "|H(%a+):")
        local uk
        H.asked = true
        if kind == "item" and type(R.Item) == "function" then uk = R.Item(name)
        elseif kind == "quest" and type(R.Quest) == "function" then
            uk = R.Quest(tonumber(match(text, "|Hquest:(%d+)")), name)
        end
        if type(uk) ~= "string" or not find(uk, CYR) then return nil end
        return sub(text, 1, o + 2) .. uk .. sub(text, c)
    end

    local function Value(x)
        local uk = Exact(x)
        if uk then return uk end
        local i, n = 1, #x
        while i <= n do
            local c = byte(x, i)
            if (c >= 48 and c <= 57) or c == 32 then i = i + 1
            elseif c == 124 and sub(x, i + 1, i + 1) == "T" then
                local _, e = find(x, "|t", i + 2, true)
                if not e then break end
                i = e + 1
            elseif c == 124 and sub(x, i + 1, i + 1) == "c" then i = i + 10
            elseif c == 124 and sub(x, i + 1, i + 1) == "r" then i = i + 2
            else break end
        end
        while i > 1 and byte(x, i - 1) == 32 do i = i - 1 end
        local money = sub(x, 1, i - 1)
        if not find(money, "%d") then return nil end
        if i > n then return money end
        local rest = Exact(sub(x, i))
        return rest and money .. rest or nil
    end

    local function Fill(s, slots, Resolve)
        table.sort(slots, function(x, y) return x.a < y.a end)
        local parts, at = {}, 1
        for _, sl in ipairs(slots) do
            if sl.a < at then return nil end                  -- overlapping slots: not a shape
            parts[#parts + 1] = (sub(s, at, sl.a - 1):gsub("%%", "%%%%"))
            parts[#parts + 1] = sl.d and "%d" or "%s"
            at = sl.b + 1
        end
        parts[#parts + 1] = (sub(s, at):gsub("%%", "%%%%"))
        local k = Key(concat(parts))
        local uk, sorts = T[k], SORT[k]
        if type(uk) ~= "string" or type(sorts) ~= "string" or #sorts ~= #slots then return nil end
        H.matched = true
        local vals = {}
        for i, sl in ipairs(slots) do
            local v = Resolve(sub(sorts, i, i), sl)
            if v == nil then return nil end
            vals[i] = v
        end
        local ok, out = pcall(format, uk, unpack(vals, 1, #slots))
        return ok and out or nil
    end

    H.Key, H.Exact, H.Link, H.Value, H.Fill = Key, Exact, Link, Value, Fill
    return H
end
