-- UADD - DeleteCheapestItem Reloaded: the shapes of its texts (slots by shape, never by words), for Words.lua.
--
-- A slot holds: v a value (digits, money with its texture codes, colour codes), f a free name kept as it is (no
-- word in small letters, lesson 7; one line, at most 60 bytes), n a game name (an item's link or its plain name,
-- from UALL Forever or ClassicUA through UADD.UALL, lesson 20; a name the addon cut short with three dots keeps
-- the line English), t another text of ours (Words.lua's Line, set as Sl.Line).
-- A shape is tried as one hash; a slot is resolved only once a template of ours matched.
-- No English of DeleteCheapestItem Reloaded is stored here: its texts are known by hash only.

local _, ns = ...
local U = UADD
ns.T = ns.T or {}
ns.SORT = ns.SORT or {}
local P = U.CodeText(ns.T, ns.SORT)       -- the shared base (UADD/CodeText.lua)
ns.Code = P
local Sl = { P = P }
ns.Slots = Sl

-- Not U.Safe (lesson 19): hooks that also put the English back must run after an off for errors. An error is
-- reported and counted as U.Safe does (5 turn the module off); it never throws. Here, in the first file, so every
-- later file can wrap its hooks while it loads.
function ns.Guard(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if ok then return end
        err = tostring(err)
        pcall(U.ReportError, err)
        if type(U.Fault) == "function" then pcall(U.Fault, "dci", err) end
    end
end

local find, sub, byte, match = string.find, string.sub, string.byte, string.match
local CYR = "[\208-\210]"
local MAXCUTS = 12          -- spaces tried per text
local MAXQUOTES = 6         -- quote marks tried per text (the profile questions)
local Codes, InCode, Link, Value, Free = P.Codes, P.InCode, P.Link, P.Value, P.Free

-- Only digits, spaces, separators and colour or texture codes (a count, money), with a digit: kept as it is.
local function Numbers(x)
    local i, n, digit = 1, #x, false
    while i <= n do
        local c = byte(x, i)
        if c >= 48 and c <= 57 then digit, i = true, i + 1
        elseif c == 32 or c == 44 or c == 46 or c == 47 then i = i + 1
        elseif c == 124 then
            local k = sub(x, i + 1, i + 1)
            if k == "c" and find(sub(x, i + 2, i + 9), "^%x%x%x%x%x%x%x%x$") then i = i + 10
            elseif k == "r" then i = i + 2
            elseif k == "T" then
                local _, e = find(x, "|t", i + 2, true)
                if not e then return nil end
                i = e + 1
            else return nil end
        else return nil end
    end
    return digit and x or nil
end
local function Val(x) return Numbers(x) or Value(x) end

-- One whole item link with its name from UALL Forever or ClassicUA; a name cut short ("...") gives nil.
local function OneLink(x)
    local c = Codes(x)
    if #c ~= 1 or not c[1][3] or c[1][1] ~= 1 or c[1][2] ~= #x then return nil end
    local o = find(x, "|h[", 1, true)
    local e = o and find(x, "]|h", o + 3, true)
    if not e or sub(x, e - 3, e - 1) == "..." then return nil end
    return Link(x)
end

-- A link, or a count and a link ("3x" and the link).
local function N(x)
    local l = OneLink(x)
    if l then return l end
    local q = match(x, "^%d+x ?")
    if q and #q < #x then
        l = OneLink(sub(x, #q + 1))
        if l then return q .. l end
    end
    return nil
end

-- An item's plain name, from UALL Forever or ClassicUA (never one cut short, never one with codes).
local function Item(x)
    if #x > 80 or find(x, "[|\n%[%]]") or sub(x, -3) == "..." or not find(x, "%a") then return nil end
    local R = U.UALL
    if type(R) ~= "table" or type(R.Item) ~= "function" then return nil end
    P.asked = true
    local ok, uk = pcall(R.Item, x)
    if ok and type(uk) == "string" and find(uk, CYR) then return uk end
    return nil
end

-- A piece already in Cyrillic with no Latin letter: kept.
local function Kept(x)
    if find(x, CYR) and not find(x, "%a") then return x end
    return nil
end

local function Resolver(d)
    return function(letter, sl)
        local x = sl.en
        if letter == "v" then
            if sl.d then return tonumber(x) end
            return Val(x)
        elseif letter == "f" then
            if x ~= "" and #x <= 60 and Free(x) and not find(x, "[\n|]") then return x end
            return nil
        elseif letter == "n" then
            return N(x) or (match(x, "^%d+$") and x) or Item(x)
        elseif letter == "t" then
            return (Sl.Line and Sl.Line(x, d)) or N(x)
        end
        return nil
    end
end

local function Fill(s, slots, d) return P.Fill(s, slots, Resolver(d)) end

-- The template shapes of one text: a colour run, a link, the rest after a space, the part before a space,
-- the names in quote marks.
local function Tries(s, d)
    local codes, n = Codes(s), #s
    local uk
    for _, c in ipairs(codes) do
        if c[3] then
            uk = Fill(s, { { a = c[1], b = c[2], en = sub(s, c[1], c[2]) } }, d)
            if uk then return uk end
        elseif sub(s, c[1], c[1] + 1) == "|c" then
            local r = find(s, "|r", c[2] + 1, true)
            if r then
                uk = Fill(s, { { a = c[1], b = r + 1, en = sub(s, c[1], r + 1) } }, d)
                if uk then return uk end
            end
        end
    end
    local sp, i = {}, 1
    while #sp < MAXCUTS do
        local p = find(s, " ", i, true)
        if not p then break end
        if not InCode(codes, p, p) then sp[#sp + 1] = p end
        i = p + 1
    end
    for _, p in ipairs(sp) do
        if p < n then
            uk = Fill(s, { { a = p + 1, b = n, en = sub(s, p + 1) } }, d)
            if uk then return uk end
        end
        if p > 1 then
            uk = Fill(s, { { a = 1, b = p - 1, en = sub(s, 1, p - 1) } }, d)
            if uk then return uk end
        end
    end
    local q = {}
    i = 1
    while #q <= MAXQUOTES do
        local p = find(s, "'", i, true)
        if not p then break end
        q[#q + 1] = p
        i = p + 1
    end
    if #q >= 2 and #q <= MAXQUOTES then
        local first, last = q[1], q[#q]
        if last > first + 1 then
            uk = Fill(s, { { a = first + 1, b = last - 1, en = sub(s, first + 1, last - 1) } }, d)
            if uk then return uk end
        end
        for j = 2, #q - 2 do
            local x1, x2 = q[j], q[j + 1]
            if x1 > first + 1 and last > x2 + 1 then
                uk = Fill(s, { { a = first + 1, b = x1 - 1, en = sub(s, first + 1, x1 - 1) },
                    { a = x2 + 1, b = last - 1, en = sub(s, x2 + 1, last - 1) } }, d)
                if uk then return uk end
            end
        end
    end
    return nil
end

-- A text whose tries met no template of ours never will (the data does not change): kept, so a line that also
-- asked a route (not cached in Words) does not run the loops again.
local miss, nmiss = {}, 0
local function Shapes(s, d)
    if miss[s] then return nil end
    local was = P.matched
    P.matched = false
    local uk = Tries(s, d)
    if uk == nil and not P.matched then
        if nmiss >= 400 then miss, nmiss = {}, 0 end
        miss[s], nmiss = true, nmiss + 1
    end
    P.matched = was or P.matched
    return uk
end
function Sl.Forget() miss, nmiss = {}, 0 end

Sl.Numbers, Sl.N, Sl.Kept, Sl.Shapes = Numbers, N, Kept, Shapes
