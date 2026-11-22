-- UADD - Road to Sixty: our Ukrainian for one whole English text of Road to Sixty (its windows, prints, tooltips,
-- popups). Road to Sixty keeps its texts as literals in its code; data/text*.lua knows ours by the hash of each
-- literal (T, in ns.RTS) and what each slot of a template holds (S, in ns.SORT: v value, f free name, n game name,
-- t our text, also one the addon lowered, given lowered; u English unit: that line stays English). No English of
-- Road to Sixty is stored here.
-- A text is tried, in order:
--   1. whole, as one literal (U.Shapes' Exact);
--   2. as a template with its slots filled (U.Shapes: values, dates, links, names through UALL Forever or ClassicUA),
--      then the plural marks {one|few|many} after its last number (U.Plural);
--   3. as pieces the code glues: a head piece of ours ending in a space and a rest that is a value or a whole text
--      of ours, or such a rest and a tail piece of ours (starting with a space, a comma or an apostrophe). Only a
--      possessive tail (an apostrophe first) takes a free name before it (a character's name): any other rest
--      must be ours or a value, so a zone or other English never sits in a Ukrainian line. One glue step only:
--      the cost stays bounded (lesson 22);
--   4. a text of several lines: each line as above; one line with English words left: the whole text stays English.
-- Anything else: nil, the English stays (no half lines, lesson 27).

local _, ns = ...
local U = UADD
local find, sub, byte = string.find, string.sub, string.byte

ns.RTS = ns.RTS or {}
ns.SORT = ns.SORT or {}

local W = {}
ns.Words = W

local CYR = "[\208-\210]"
local MAXLEN, MAXLINES, MAXCUTS, MAXCACHE = 400, 12, 16, 400
local P

-- The first letter of our word in small letters (Cyrillic: А-Я, Є, І, Ї, Ґ; Latin through string.lower).
local function LowFirst(uk)
    if type(uk) ~= "string" or uk == "" then return nil end
    local a, b = byte(uk, 1), byte(uk, 2)
    if a == 208 and b and b >= 144 and b <= 159 then return string.char(208, b + 32) .. sub(uk, 3) end
    if a == 208 and b and b >= 160 and b <= 175 then return string.char(209, b - 32) .. sub(uk, 3) end
    if a == 208 and (b == 132 or b == 134 or b == 135) then return string.char(209, b + 16) .. sub(uk, 3) end
    if a == 210 and b == 144 then return string.char(210, 145) .. sub(uk, 3) end
    return string.lower(sub(uk, 1, 1)) .. sub(uk, 2)
end

-- A `t` slot: a whole text of ours, or one the addon put in small letters (a chart's name, lowered), given in
-- small letters too. Never a text with a capital inside: that is not one of our words lowered.
local function Ours(x)
    if type(x) ~= "string" or x == "" or #x > 60 or find(x, "%u") or not find(x, "^%l") then return nil end
    return P.Exact(x) or LowFirst(P.Exact(string.upper(sub(x, 1, 1)) .. sub(x, 2)))
end

P = U.Shapes(ns.RTS, ns.SORT, { key = "rts", Line = Ours })
W.P = P

local cache, ncache = {}, 0
local MISS = false

local function Key(s) return "Code." .. U.Hash(s) end

-- A value on its own: a number, a time, money, a date, a link.
local function Value(x)
    if not find(x, "%S") then return nil end
    local ok, v = pcall(P.Val, x)
    if ok and type(v) == "string" then return v end
    if find(x, "^%s*[%d%.,:%%%+%-]+%s*$") then return x end
    return nil
end

-- A free name: one character's name as it is (one word, maybe with its realm after a dash), never a phrase,
-- a code or a line break.
local function FreeName(x)
    if #x == 0 or #x > 60 or find(x, "[|\n%s]") then return nil end
    if find(x, CYR) then return x end
    if not P.Free(x) then return nil end
    return x
end

-- A template whose one slot is a free name inside the text (a character's name, also before "'s"): each word,
-- or the part of it before an apostrophe, tried as the slot (at most MAXCUTS words, one hash each). A word ends at
-- a space or a line break, and a mark after the name ("?", "!", ".", ",") stays in the template, not in the name:
-- a popup's whole text of several lines is one template with the name in its first line.
local function NameSlot(s)
    local a, words = 1, 0
    while a <= #s and words < MAXCUTS do
        local sp = find(s, "[ \n]", a) or (#s + 1)
        words = words + 1
        local e = sp - 1
        local q = find(s, "'", a, true)
        if q and q < sp then e = q - 1 end
        while e >= a and find(s, "^[%?!%.,]", e) do e = e - 1 end
        if e >= a then
            local name = FreeName(sub(s, a, e))
            if name then
                local k = Key(sub(s, 1, a - 1) .. "%s" .. sub(s, e + 1))
                local uk = ns.RTS[k]
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
    return nil
end

-- A rest beside a piece of ours: a value, or a whole text of ours.
local function Rest(x) return Value(x) or Whole(x) end

-- 3. Glued pieces: the longest head first, then the longest tail first.
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
        if c == 32 or c == 44 or c == 39 then
            cuts = cuts + 1
            local tail = P.Exact(sub(s, j))
            if tail then
                local before = sub(s, 1, j - 1)
                local lead = Rest(before) or (c == 39 and FreeName(before)) or nil
                if lead then return U.Plural(lead .. tail, true) end
            end
        end
    end
    return nil
end

local function Line(s) return Whole(s) or NameSlot(s) or Glued(s) end

-- 4. Several lines: each one ours, or one with no words at all.
local function Lines(s)
    local out, n, any, pos = {}, 0, false, 1
    while pos <= #s + 1 do
        local e = find(s, "\n", pos, true) or (#s + 1)
        local one = sub(s, pos, e - 1)
        n = n + 1
        if n > MAXLINES then return nil end
        if not find(one, "%a") then
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
    if find(s, "\n", 1, true) then return Whole(s) or NameSlot(s) or Lines(s) end
    return Line(s)
end

-- Our Ukrainian for one whole English text, or nil.
function W.Translate(en)
    local s = U.Plain(en)
    if not s or s == "" or #s > MAXLEN or find(s, CYR) or not find(s, "%a") then return nil end
    local hit = cache[s]
    if hit ~= nil then return hit or nil end
    P.asked = false
    local ok, uk = pcall(Look, s)
    if not ok then
        pcall(U.ReportError, tostring(uk))
        if U.Fault then pcall(U.Fault, "rts", tostring(uk)) end
        return nil
    end
    if type(uk) ~= "string" or uk == "" or uk == s then uk = nil end
    if uk or not P.asked then                     -- a game name not known yet: asked again later, never kept
        if ncache >= MAXCACHE then cache, ncache = {}, 0 end
        cache[s], ncache = uk or MISS, ncache + 1
    end
    return uk
end

-- Cheap (lesson 12): may this tooltip line of the game be ours? A whole-text hash only: no fill, no cache growth.
function W.Maybe(en)
    local s = U.Plain(en)
    if not s or s == "" or #s > MAXLEN or find(s, CYR) then return false end
    return ns.RTS[Key(s)] ~= nil
end

-- A field the game formats itself (a popup's text with its %s, filled with a character's name or a number):
-- our template as it is, only when each slot is a value or a free name and it has no plural mark.
function W.Field(en)
    local s = U.Plain(en)
    if not s or s == "" or #s > MAXLEN or find(s, CYR) then return nil end
    local k = Key(s)
    local uk, sorts = ns.RTS[k], ns.SORT[k]
    if type(uk) ~= "string" then return nil end
    if sorts == nil then return W.Translate(s) end
    if type(sorts) ~= "string" or find(sorts, "[^vf]") or find(uk, "{", 1, true) then return nil end
    return uk
end

function W.Forget()
    cache, ncache = {}, 0
    pcall(P.Forget)
end
function W.CacheSize() return ncache end
