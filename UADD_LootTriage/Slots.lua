-- UADD - LootTriage: the shapes of its texts (slots by shape, never by words), for Words.lua.
--
-- A text is one string literal of its code, a format template (looked up as the template, its slots
-- filled), or literals it glues with ".." (each piece looked up alone). Slots are found by their shape,
-- never by words: a number, a link, a part in brackets, a keep click (one word with "+"), the reason after
-- the addon's prefix, money with its texture codes, an empty slot. The answer is a whole Ukrainian line, or
-- nil: the line stays as it came.
--   * A link's name comes from UALL Forever or ClassicUA (UADD.UALL.Item / .Quest, lesson 20); with no
--     answer the line stays English (no half lines). A quest title glued in comes the same way, so a title
--     the addon made itself for an unknown quest keeps the line English (lesson 27).
--   * A free slot (f) keeps no word in small letters (lesson 7).
-- No English of LootTriage is stored here: its texts are known by hash only.

local _, ns = ...
local U = UADD
local P = { asked = false }               -- asked: a game-name route was asked for this text (its answer may come later)
ns.Slots = P
ns.LT = ns.LT or {}
ns.SORT = ns.SORT or {}

local find, sub, byte, match, format = string.find, string.sub, string.byte, string.match, string.format
local concat, unpack = table.concat, unpack
local CYR = "[\208-\210]"
local PREFIX = "LootTriage: "             -- the addon's name: its tooltip lines start so
local MAXWORDS = 20

local function Key(s) return "Code." .. U.Hash(s) end

-- One literal of its code (not a template).
local function Exact(s)
    if type(s) ~= "string" or s == "" then return nil end
    local k = Key(s)
    if ns.SORT[k] then return nil end
    local uk = ns.LT[k]
    return type(uk) == "string" and uk or nil
end

-- ── Shapes ────────────────────────────────────────────────────────────────────────────────────

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

-- A link with the name between its brackets in Ukrainian, or nil.
local function Link(text)
    local R = U.UALL
    local o = find(text, "|h[", 1, true)
    local c = o and find(text, "]|h", o + 3, true)
    if type(R) ~= "table" or not c then return nil end
    local name, kind = sub(text, o + 3, c - 1), match(text, "|H(%a+):")
    local uk
    P.asked = true
    if kind == "item" and type(R.Item) == "function" then uk = R.Item(name)
    elseif kind == "quest" and type(R.Quest) == "function" then uk = R.Quest(tonumber(match(text, "|Hquest:(%d+)")), name) end
    if type(uk) ~= "string" or not find(uk, CYR) then return nil end
    return sub(text, 1, o + 2) .. uk .. sub(text, c)
end

-- Money as the game draws it (digits, spaces, colour and texture codes), then maybe one of our pieces.
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

local function Free(en) return type(en) == "string" and not find(" " .. en, "%s%l") end

-- What one slot puts in the Ukrainian template, or nil (then the line stays English).
local function Slot(sort, sl)
    local k = sl.kind
    if k == "empty" then return "" end
    if k == "num" then return sl.d and tonumber(sl.en) or sl.en end
    if k == "link" then return Link(sl.en) end            -- a game name, whatever the letter says
    local uk = sl.uk
    if uk == nil and sl.get then uk = sl.get(sl.en) end
    if uk then return uk end
    if sort == "f" and Free(sl.en) then return sl.en end
    return nil
end

-- The template the slots make of s, looked up; the line in Ukrainian or nil.
local function Fill(s, slots)
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
    local uk, sorts = ns.LT[k], ns.SORT[k]
    if type(uk) ~= "string" or type(sorts) ~= "string" or #sorts ~= #slots then return nil end
    P.matched = true
    local vals = {}
    for i, sl in ipairs(slots) do
        local v = Slot(sub(sorts, i, i), sl)
        if v == nil then return nil end
        vals[i] = v
    end
    local ok, out = pcall(format, uk, unpack(vals, 1, #slots))
    return ok and out or nil
end

-- The links and the numbers outside codes and outside `skip` ({a, b} ranges), as slots.
local function Base(s, codes, skip)
    local out = {}
    local function Free_(a, b) return not InCode(skip, a, b) end
    for _, c in ipairs(codes) do
        if c[3] and Free_(c[1], c[2]) then out[#out + 1] = { a = c[1], b = c[2], kind = "link", en = sub(s, c[1], c[2]) } end
    end
    local i = 1
    while true do
        local a, b = find(s, "%d+", i)
        if not a then break end
        if not InCode(codes, a, b) and Free_(a, b) then out[#out + 1] = { a = a, b = b, kind = "num", d = true, en = sub(s, a, b) } end
        i = b + 1
    end
    return out
end

local function With(list, ...)
    local out = { unpack(list) }
    for i = 1, select("#", ...) do out[#out + 1] = select(i, ...) end
    return out
end

-- The groups in brackets outside codes: { a ("("), b (")") }, last first.
local function Parens(s, codes)
    local out, i = {}, 1
    while #out < 4 do
        local a = find(s, "(", i, true)
        if not a then break end
        local b = find(s, ")", a + 1, true)
        if not b then break end
        if not InCode(codes, a, a) then table.insert(out, 1, { a, b }) end
        i = b + 1
    end
    return out
end

-- A number piece of ours in brackets, with the space before it (formatted on its own, then glued in).
local function Piece(x)
    local uk = Exact(x)
    if uk then return uk end
    local codes = Codes(x)
    return Fill(x, Base(x, codes, {}))
end

-- The ends of the words of s outside codes, for an empty slot ("this%s" with "").
local function WordEnds(s, codes)
    local out, i = {}, 1
    while #out < MAXWORDS do
        local a, b = find(s, "%w[%s%.,:;!?]", i)
        if not a then break end
        if not InCode(codes, a, a) then out[#out + 1] = a + 1 end
        i = b
    end
    return out
end

local function Tries(s)
    local codes = Codes(s)
    local base = Base(s, codes, {})
    local uk = Fill(s, With(base))
    if uk then return uk end
    local parens = Parens(s, codes)
    local pieces = {}                                     -- our bracket pieces with their space
    for _, g in ipairs(parens) do
        local a = (byte(s, g[1] - 1) == 32) and g[1] - 1 or g[1]
        local p = Piece(sub(s, a, g[2]))
        if p then pieces[#pieces + 1] = { a = a, b = g[2], kind = "piece", uk = p, en = sub(s, a, g[2]) } end
        -- the inside as one slot: money and maybe our piece, a reason, a click
        local inner = { a = g[1] + 1, b = g[2] - 1, kind = "piece", en = sub(s, g[1] + 1, g[2] - 1), get = Value }
        uk = Fill(s, With(Base(s, codes, { { inner.a, inner.b } }), inner))
        if uk then return uk end
        local t1, t2 = find(s, "^[^%s|]*%+[^%s|]*", g[1] + 1)         -- a keep click at its start
        if t1 then
            local click = { a = t1, b = t2, kind = "piece", en = sub(s, t1, t2), get = Exact }
            uk = Fill(s, With(Base(s, codes, { { t1, t2 } }), click))
            if uk then return uk end
        end
    end
    local pr = {}
    for _, p in ipairs(pieces) do pr[#pr + 1] = { p.a, p.b } end
    local glued = With(Base(s, codes, pr), unpack(pieces))
    if #pieces > 0 then
        uk = Fill(s, glued)
        if uk then return uk end
    end
    -- the reason after the prefix, up to the first comma
    if sub(s, 1, #PREFIX) == PREFIX then
        local c = find(s, ", ", #PREFIX + 1, true)
        if c and c > #PREFIX + 1 then
            local why = { a = #PREFIX + 1, b = c - 1, kind = "piece", en = sub(s, #PREFIX + 1, c - 1), get = Exact }
            uk = Fill(s, With(Base(s, codes, { { why.a, why.b } }), why))
            if uk then return uk end
        end
    end
    -- an empty slot (a piece left out), and maybe one of our words at the end ("... for %s.")
    if #s > 200 then return nil end
    local tail, e = {}, #s
    if find(sub(s, e), "[%.!?]") then e = e - 1 end
    local i = 1
    while #tail < MAXWORDS do
        local sp = find(s, " ", i, true)
        if not sp or sp >= e then break end
        local x = sub(s, sp + 1, e)
        if not InCode(codes, sp + 1, e) and Exact(x) then tail[#tail + 1] = { a = sp + 1, b = e, kind = "piece", en = x, get = Exact } end
        i = sp + 1
    end
    local ends = WordEnds(s, codes)
    for _, c in ipairs(codes) do                          -- right after a link: its number piece left out
        if c[3] then table.insert(ends, 1, c[2] + 1) end
    end
    local function Try(extra) return Fill(s, With(Base(s, codes, With(pr, { extra.a, extra.b })), extra, unpack(pieces))) end
    for _, t in ipairs(tail) do
        uk = Try(t)
        if uk then return uk end
        for _, at in ipairs(ends) do
            if at <= t.a then
                local list = With(Base(s, codes, With(pr, { t.a, t.b })), t, { a = at, b = at - 1, kind = "empty" }, unpack(pieces))
                uk = Fill(s, list)
                if uk then return uk end
            end
        end
    end
    for _, at in ipairs(ends) do
        uk = Fill(s, With(glued, { a = at, b = at - 1, kind = "empty" }))
        if uk then return uk end
    end
    return nil
end

-- A text whose tries met no template of ours never will (the data does not change): kept, so a line that also
-- asked a route (not cached in Words) does not run the loops again. No route is asked before a template matched.
local miss, nmiss = {}, 0
local function Shapes(s)
    if miss[s] then return nil end
    P.matched = false
    local uk = Tries(s)
    if uk == nil and not P.matched then
        if nmiss >= 400 then miss, nmiss = {}, 0 end
        miss[s], nmiss = true, nmiss + 1
    end
    return uk
end
function P.Forget() miss, nmiss = {}, 0 end

P.Key, P.Exact, P.Codes, P.Link, P.Base, P.Shapes = Key, Exact, Codes, Link, Base, Shapes
