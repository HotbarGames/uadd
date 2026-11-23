-- UADD - OneForAll: our Ukrainian for one whole English text of OneForAll (its windows, chat lines, tooltip lines).
-- OneForAll's L, FLT.LNum and its name helpers stay English (other code matches their results: the never-change
-- list, local/new-addon/OneForAll.md); ours goes in where the text is drawn. data/text*.lua knows ours by the hash
-- of each English text as OneForAll draws it (T, in ns.OFA: an L key, a data sentence with its numbers, a literal)
-- and what each slot of a template holds (S, in ns.SORT: v value, f free name, n game name, t our text).
-- A text is tried, in order:
--   1. whole (U.Shapes' Exact);
--   2. as a template with its slots filled (U.Shapes: values, links, names through UALL Forever or ClassicUA),
--      then the plural marks {one|few|many} after its last number (U.Plural);
--   3. a whole text that is one of OneForAll's own dungeon names: UADD.UALL.Zone (ClassicUA first); no answer
--      leaves it English. We write no game names;
--   4. a free name inside a template (a profile or player name, kept as it is);
--   5. two pieces its code glues: a head of ours ending in a space and a rest that is a value or ours, or such a
--      rest and a tail of ours. One glue step only (lesson 22);
--   6. several lines: each line as above; one line with English words left: the whole text stays English.
-- Anything else: nil, the English stays (no half lines, lesson 27). Texts under two letters are never ours (its
-- one-letter quest marks R and D).

local _, ns = ...
local U = UADD
local find, sub, byte = string.find, string.sub, string.byte

ns.OFA = ns.OFA or {}
ns.SORT = ns.SORT or {}

local W = {}
ns.Words = W

local CYR = "[\208-\210]"
local MAXLEN, MAXLINES, MAXCUTS, MAXCACHE = 1200, 16, 16, 600
local P

local function LowFirst(uk)
    if type(uk) ~= "string" or uk == "" then return nil end
    local a, b = byte(uk, 1), byte(uk, 2)
    if a == 208 and b and b >= 144 and b <= 159 then return string.char(208, b + 32) .. sub(uk, 3) end
    if a == 208 and b and b >= 160 and b <= 175 then return string.char(209, b - 32) .. sub(uk, 3) end
    if a == 208 and (b == 132 or b == 134 or b == 135) then return string.char(209, b + 16) .. sub(uk, 3) end
    if a == 210 and b == 144 then return string.char(210, 145) .. sub(uk, 3) end
    return string.lower(sub(uk, 1, 1)) .. sub(uk, 2)
end

-- A `t` slot: a whole text of ours, or one the addon put in small letters, given in small letters too.
local function Ours(x)
    if type(x) ~= "string" or x == "" or #x > 60 then return nil end
    if find(x, "^%u") then return P.Exact(x) end      -- a capitalised text of ours ("Neutral"), never other English
    if find(x, "%u") or not find(x, "^%l") then return nil end
    return P.Exact(x) or LowFirst(P.Exact(string.upper(sub(x, 1, 1)) .. sub(x, 2)))
end

P = U.Shapes(ns.OFA, ns.SORT, { key = "oneforall", Line = Ours, maxlen = 400 })
W.P = P

local cache, ncache = {}, 0
local MISS = false

local function Key(s) return "Code." .. U.Hash(s) end

-- 3. OneForAll's own dungeon names (FLT.DUNGEONS[i].name, its English data), read once it has them.
local dungeons
local function Dungeon(s)
    if #s > 60 or find(s, "[|%[%(\n]") then return nil end
    if not dungeons then
        local F = rawget(_G, "OneForAll")
        local list = type(F) == "table" and rawget(F, "DUNGEONS")
        if type(list) ~= "table" or next(list) == nil then return nil end
        dungeons = {}
        for _, d in pairs(list) do
            if type(d) == "table" and type(d.name) == "string" then dungeons[d.name] = true end
        end
    end
    if not dungeons[s] then return nil end
    P.asked = true                                -- a game name: a miss now may be an answer later, never kept
    local route = UADD.UALL and UADD.UALL.Zone
    if type(route) ~= "function" then return nil end
    local ok, uk = pcall(route, s)
    if ok and type(uk) == "string" and uk ~= s and find(uk, CYR) then return uk end
    return nil
end

local function Value(x)
    if not find(x, "%S") then return nil end
    local ok, v = pcall(P.Val, x)
    if ok and type(v) == "string" then return v end
    if find(x, "^%s*[%d%.,:%%%+%-]+%s*$") then return x end
    return nil
end

local function FreeName(x)
    if #x == 0 or #x > 60 or find(x, "[|\n]") then return nil end
    if find(x, CYR) then return x end
    if not P.Free(x) then return nil end
    return x
end

-- 4. A template whose one slot is a free name inside the text (a profile in quotes, a player): each word tried.
local function NameSlot(s)
    local a, words = 1, 0
    while a <= #s and words < MAXCUTS do
        local sp = find(s, "[ \n]", a) or (#s + 1)
        words = words + 1
        local e = sp - 1
        local q = find(s, "'", a, true)
        if q and q < sp then e = q - 1 end
        while e >= a and find(s, "^[%?!%.,\"]", e) do e = e - 1 end
        local b = a
        while b <= e and find(s, "^[\"']", b) do b = b + 1 end
        if e >= b then
            local name = FreeName(sub(s, b, e))
            if name then
                local k = Key(sub(s, 1, b - 1) .. "%s" .. sub(s, e + 1))
                local uk = ns.OFA[k]
                if type(uk) == "string" and ns.SORT[k] == "f" then
                    local ok, out = pcall(string.format, uk, name)
                    if ok then return U.Plural(out, true) end
                end
            end
        end
        a = sp + 1
    end
    return nil
end

local function Whole(s)
    if s == "" then return nil end
    local uk = P.Exact(s)
    if uk then return uk end
    uk = P.Shapes(s)
    if type(uk) == "string" and uk ~= "" then return U.Plural(uk, true) end
    return Dungeon(s)
end

local function Rest(x) return Value(x) or Whole(x) end

-- 5. Glued pieces: the longest head first, then the longest tail first.
local function Glued(s)
    local cuts, i = 0, #s - 1
    while i > 1 and cuts < MAXCUTS do
        if byte(s, i) == 32 then
            cuts = cuts + 1
            local head = P.Exact(sub(s, 1, i))
            if head then
                local rest = Rest(sub(s, i + 1))
                if rest then return U.Plural(head .. rest, true) end
            end
        end
        i = i - 1
    end
    cuts = 0
    for j = 2, #s do
        if cuts >= MAXCUTS then break end
        local c = byte(s, j)
        if c == 32 or c == 44 then
            cuts = cuts + 1
            local tail = P.Exact(sub(s, j))
            if tail then
                local lead = Rest(sub(s, 1, j - 1))
                if lead then return U.Plural(lead .. tail, true) end
            end
        end
    end
    return nil
end

-- 5b. Money (a number and its coin icon, "12|T..|t 30|T..|t") inside a longer text: the run is one `v` slot.
local COIN = "[%d,%.]+|T[^|]*|t"
local function Moneyed(s)
    local a, b = find(s, COIN)
    if not a then return nil end
    while true do
        local _, e = find(s, "^ " .. COIN, b + 1)
        if not e then break end
        b = e
    end
    local k = Key(sub(s, 1, a - 1) .. "%s" .. sub(s, b + 1))
    local uk = ns.OFA[k]
    if type(uk) ~= "string" or ns.SORT[k] ~= "v" then return nil end
    local ok, out = pcall(string.format, uk, sub(s, a, b))
    if ok then return U.Plural(out, true) end
    return nil
end

-- 5b'. A template whose first slot is our text before a dot ("Neutral  ·  18 rewards"): the head is one slot, the
-- numbers after it the others (Shapes alone does not make that pair).
local function HeadNum(s)
    local e = find(s, "%s%s|?c?%x*·")
    if not e or e < 2 or e > 61 then return nil end
    local slots = { { a = 1, b = e - 1, en = sub(s, 1, e - 1) } }
    local i = e
    while #slots < 5 do
        local a, b = find(s, "%d+", i)
        if not a then break end
        slots[#slots + 1] = { a = a, b = b, kind = "num", d = true, en = sub(s, a, b) }
        i = b + 1
    end
    if #slots < 2 then return nil end
    local ok, uk = pcall(P.Fill, s, slots)
    if ok and type(uk) == "string" and uk ~= "" then return U.Plural(uk, true) end
    return nil
end

local function Atom(s) return Whole(s) or Moneyed(s) or HeadNum(s) or NameSlot(s) or Glued(s) end

-- 5c. Pieces joined in code with a dot or a wide gap: Joined.lua (W.Joined), loaded after this file.
W.Atom, W.Value = Atom, Value

local function Line(s) return Atom(s) or (W.Joined and W.Joined(s)) end

-- An author's signature line ("- Name", maybe in one colour): a name, kept as it is (lesson 44).
local function Signed(one)
    local core = one:gsub("^|c%x%x%x%x%x%x%x%x", ""):gsub("|r$", "")
    return find(core, "^%- %u%l+$") ~= nil
end

-- 6. Several lines: each one ours, one with no words at all, or a signature.
local function Lines(s)
    local out, n, any, pos = {}, 0, false, 1
    while pos <= #s + 1 do
        local e = find(s, "\n", pos, true) or (#s + 1)
        local one = sub(s, pos, e - 1)
        n = n + 1
        if n > MAXLINES then return nil end
        if not find(one, "%a%a") or Signed(one) then
            out[n] = one
        else
            local uk = Line(one)
            if not uk then return nil end
            out[n], any = uk, true
        end
        pos = e + 1
    end
    return any and table.concat(out, "\n") or nil
end

local function Look(s)
    if find(s, "\n", 1, true) then return Whole(s) or Moneyed(s) or NameSlot(s) or Lines(s) end
    return Line(s)
end

-- Our Ukrainian for one whole English text, or nil.
function W.Translate(en)
    local s = U.Plain(en)
    if not s or s == "" or #s > MAXLEN or find(s, CYR) or not find(s, "%a%a") then return nil end
    local hit = cache[s]
    if hit ~= nil then return hit or nil end
    P.asked = false
    local ok, uk = pcall(Look, s)
    if not ok then
        pcall(U.ReportError, tostring(uk))
        if U.Fault then pcall(U.Fault, "oneforall", tostring(uk)) end
        return nil
    end
    if type(uk) ~= "string" or uk == "" or uk == s then uk = nil end
    if uk or not P.asked then
        if ncache >= MAXCACHE then cache, ncache = {}, 0 end
        cache[s], ncache = uk or MISS, ncache + 1
    end
    return uk
end

-- Cheap (lesson 12): may this tooltip or chat line be ours? A whole-text hash only: no fill, no cache growth.
function W.Maybe(en)
    local s = U.Plain(en)
    if not s or s == "" or #s > MAXLEN or find(s, CYR) then return false end
    return ns.OFA[Key(s)] ~= nil
end

function W.Forget()
    cache, ncache = {}, 0
    dungeons = nil
    pcall(P.Forget)
end
function W.CacheSize() return ncache end
