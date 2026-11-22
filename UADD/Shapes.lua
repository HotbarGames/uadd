-- UADD.Shapes(T, SORT [, opts]): slots found by their shape, never by words, on top of UADD.CodeText (the model:
-- LootTriage's and DeleteCheapestItem Reloaded's Slots.lua, which keep their own copies). Hash keys only: nothing
-- here stores another addon's English. P = UADD.Shapes(...) has all of CodeText's fields, and:
--   P.Shapes(s [, d]): the whole line in Ukrainian, or nil (it stays as it came); misses cached (400), P.Forget().
--   P.Fill(s, slots [, d]): one shape looked up and filled, or nil; P.Try(name, s, d): one try of TRIES alone.
-- opts: Line(x, d) (our text in a `t` slot), prefix ("Name: ": the reason after it, up to ", ", is one slot),
-- order (the tries by name; default TRIES), key (for U.Fault), maxcuts 12, maxquotes 6, maxwords 20, maxlen 200.
-- A slot { a, b, en, d } with no kind holds, by its SORT letter: v a value (digits, money with its codes, a date
-- through UADD.DateUk), f a free name (no word in small letters, lesson 7; 60 bytes, no wide gap, tab, line break
-- or " - " gluing more text on), n a game name (a
-- link, a count and a link, digits, an item's name from UALL Forever or ClassicUA), t our text (opts.Line) or a
-- link, u a duration in English units (the line stays English). With kind: "empty" (""), "num", "link", "piece"
-- (uk, or get(en), or the English when the letter is f and Free). Any nil keeps the whole line English.
-- The last try, loose, puts numbers in a %s, a dotted version ("1.15.7") in one %s, and the rest after a space in
-- one slot beside the numbers before it.

local U = UADD
local find, sub, byte, match = string.find, string.sub, string.byte, string.match
local unpack = unpack or table.unpack
local TRIES = { "base", "runs", "cuts", "quotes", "parens", "prefix", "tail", "loose" }
local MAXFLIP = 4                                       -- loose: at most this many numbers tried as %s (15 keys)

function U.Shapes(T, SORT, opts)
    opts = type(opts) == "table" and opts or {}
    local P = U.CodeText(T, SORT)
    local MAXCUTS, MAXQUOTES = opts.maxcuts or 12, opts.maxquotes or 6
    local MAXWORDS, MAXLEN = opts.maxwords or 20, opts.maxlen or 200
    local PREFIX = type(opts.prefix) == "string" and opts.prefix ~= "" and opts.prefix or nil
    local Exact, Codes, InCode, Link, Value = P.Exact, P.Codes, P.InCode, P.Link, P.Value
    -- Numbers: digits, separators, colour and texture codes; OneLink: one whole link, its name not cut short;
    -- N: a link, or "3x" and a link; Item: an item's plain name; Kept: Cyrillic, no Latin; OneName: a free
    -- slot's one name with nothing glued on (CodeText.lua).
    local Numbers, OneLink, N, Item, Kept, OneName = P.Numbers, P.OneLink, P.N, P.Item, P.Kept, P.OneName
    local function Date(x) return find(x, "%a") and not find(x, "|") and U.DateUk and U.DateUk(x) or nil end
    local function Val(x) return Numbers(x) or Value(x) or Date(x) end

    local function Resolver(d)
        return function(letter, sl)
            if letter == "u" then return nil end
            local x, k = sl.en, sl.kind
            if k == "empty" then return "" end
            if k == "num" then return sl.d and tonumber(x) or x end
            if k == "link" then return Link(x) end
            if k then
                local uk = sl.uk or (sl.get and sl.get(x))
                return uk or (letter == "f" and OneName(x)) or nil
            end
            if letter == "v" then return sl.d and tonumber(x) or Val(x)
            elseif letter == "f" then
                return OneName(x)
            elseif letter == "n" then
                return N(x) or (match(x, "^%d+$") and x) or Item(x)
            elseif letter == "t" then
                return (type(opts.Line) == "function" and opts.Line(x, d)) or N(x)
            end
            return nil
        end
    end
    local raw = P.Fill
    local function Fill(s, slots, d) return raw(s, slots, Resolver(d)) end

    -- The links and the numbers outside codes and outside `skip` ({a, b} ranges), as slots. dotted: a run of
    -- digits and dots ("1.15.7", a version) is one slot, in a %s.
    local function Base(s, codes, skip, dotted)
        local out = {}
        for _, c in ipairs(codes) do
            if c[3] and not InCode(skip, c[1], c[2]) then out[#out + 1] = { a = c[1], b = c[2], kind = "link", en = sub(s, c[1], c[2]) } end
        end
        local i = 1
        while true do
            local a, b = find(s, dotted and "%d[%d%.]*" or "%d+", i)
            if not a then break end
            while dotted and byte(s, b) == 46 do b = b - 1 end
            if not InCode(codes, a, b) and not InCode(skip, a, b) then
                local x = sub(s, a, b)
                out[#out + 1] = { a = a, b = b, kind = "num", d = not find(x, ".", 1, true), en = x }
            end
            i = b + 1
        end
        return out
    end
    local function With(list, ...)
        local out = { unpack(list) }
        for i = 1, select("#", ...) do out[#out + 1] = select(i, ...) end
        return out
    end
    local function Parens(s, codes)                      -- groups in brackets outside codes, last first
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
    local function Piece(x)                              -- a piece of ours with numbers, formatted on its own
        return Exact(x) or Fill(x, Base(x, Codes(x), {}))
    end
    local function WordEnds(s, codes)                    -- word ends outside codes (for an empty slot)
        local out, i = {}, 1
        while #out < MAXWORDS do
            local a, b = find(s, "%w[%s%.,:;!?]", i)
            if not a then break end
            if not InCode(codes, a, a) then out[#out + 1] = a + 1 end
            i = b
        end
        return out
    end
    local function One(s, a, b, d) return Fill(s, { { a = a, b = b, en = sub(s, a, b) } }, d) end

    local R = {}
    function R.base(s, d, c) return Fill(s, Base(s, c.codes, {}), d) end
    function R.runs(s, d, c)                             -- a link, or a |c..|r run, as one slot
        for _, k in ipairs(c.codes) do
            local uk
            if k[3] then uk = One(s, k[1], k[2], d)
            elseif sub(s, k[1], k[1] + 1) == "|c" then
                local r = find(s, "|r", k[2] + 1, true)
                if r then uk = One(s, k[1], r + 1, d) end
            end
            if uk then return uk end
        end
    end
    function R.cuts(s, d, c)                             -- the rest after a space, the part before it
        local n, i, sp = #s, 1, 0
        while sp < MAXCUTS do
            local p = find(s, " ", i, true)
            if not p then break end
            if not InCode(c.codes, p, p) then
                sp = sp + 1
                local uk = (p < n and One(s, p + 1, n, d)) or (p > 1 and One(s, 1, p - 1, d)) or nil
                if uk then return uk end
            end
            i = p + 1
        end
    end
    function R.quotes(s, d)                              -- the names in single quote marks
        local q, i = {}, 1
        while #q <= MAXQUOTES do
            local p = find(s, "'", i, true)
            if not p then break end
            q[#q + 1], i = p, p + 1
        end
        if #q < 2 or #q > MAXQUOTES then return nil end
        local first, last = q[1], q[#q]
        local uk = last > first + 1 and One(s, first + 1, last - 1, d) or nil
        if uk then return uk end
        for j = 2, #q - 2 do
            local x1, x2 = q[j], q[j + 1]
            if x1 > first + 1 and last > x2 + 1 then
                uk = Fill(s, { { a = first + 1, b = x1 - 1, en = sub(s, first + 1, x1 - 1) },
                    { a = x2 + 1, b = last - 1, en = sub(s, x2 + 1, last - 1) } }, d)
                if uk then return uk end
            end
        end
    end
    function R.parens(s, d, c)                           -- a bracket group: our piece, its inside, a keep click
        local codes, pieces = c.codes, {}
        c.pieces = pieces
        for _, g in ipairs(Parens(s, codes)) do
            local a = (byte(s, g[1] - 1) == 32) and g[1] - 1 or g[1]
            local p = Piece(sub(s, a, g[2]))
            if p then pieces[#pieces + 1] = { a = a, b = g[2], kind = "piece", uk = p, en = sub(s, a, g[2]) } end
            local inner = { a = g[1] + 1, b = g[2] - 1, kind = "piece", en = sub(s, g[1] + 1, g[2] - 1), get = Value }
            local uk = Fill(s, With(Base(s, codes, { { inner.a, inner.b } }), inner), d)
            if uk then return uk end
            local t1, t2 = find(s, "^[^%s|]*%+[^%s|]*", g[1] + 1)
            if t1 then
                local click = { a = t1, b = t2, kind = "piece", en = sub(s, t1, t2), get = Exact }
                uk = Fill(s, With(Base(s, codes, { { t1, t2 } }), click), d)
                if uk then return uk end
            end
        end
        if #pieces > 0 then
            local pr = {}
            for _, p in ipairs(pieces) do pr[#pr + 1] = { p.a, p.b } end
            return Fill(s, With(Base(s, codes, pr), unpack(pieces)), d)
        end
    end
    function R.prefix(s, d, c)                           -- the reason after the addon's prefix, up to ", "
        if not PREFIX or sub(s, 1, #PREFIX) ~= PREFIX then return nil end
        local k = find(s, ", ", #PREFIX + 1, true)
        if not k or k <= #PREFIX + 1 then return nil end
        local why = { a = #PREFIX + 1, b = k - 1, kind = "piece", en = sub(s, #PREFIX + 1, k - 1), get = Exact }
        return Fill(s, With(Base(s, c.codes, { { why.a, why.b } }), why), d)
    end
    function R.tail(s, d, c)                             -- an empty slot, maybe with our word at the end
        if #s > MAXLEN then return nil end
        local codes, pieces = c.codes, c.pieces or {}
        local pr = {}
        for _, p in ipairs(pieces) do pr[#pr + 1] = { p.a, p.b } end
        local tail, e, i = {}, #s, 1
        if find(sub(s, e), "[%.!?]") then e = e - 1 end
        while #tail < MAXWORDS do
            local sp = find(s, " ", i, true)
            if not sp or sp >= e then break end
            local x = sub(s, sp + 1, e)
            if not InCode(codes, sp + 1, e) and Exact(x) then
                tail[#tail + 1] = { a = sp + 1, b = e, kind = "piece", en = x, get = Exact }
            end
            i = sp + 1
        end
        local ends = WordEnds(s, codes)
        for _, k in ipairs(codes) do if k[3] then table.insert(ends, 1, k[2] + 1) end end
        for _, t in ipairs(tail) do
            local rest = Base(s, codes, With(pr, { t.a, t.b }))
            local uk = Fill(s, With(rest, t, unpack(pieces)), d)
            if uk then return uk end
            for _, at in ipairs(ends) do
                if at <= t.a then
                    uk = Fill(s, With(rest, t, { a = at, b = at - 1, kind = "empty" }, unpack(pieces)), d)
                    if uk then return uk end
                end
            end
        end
        local glued = With(Base(s, codes, pr), unpack(pieces))
        for _, at in ipairs(ends) do
            local uk = Fill(s, With(glued, { a = at, b = at - 1, kind = "empty" }), d)
            if uk then return uk end
        end
    end
    local function Flips(s, slots, d) return P.Flips(s, slots, Resolver(d), MAXFLIP) end
    -- Last, for a text no other try fits: numbers in a %s, a dotted version as one slot, and the rest after a
    -- space as one slot beside the numbers before it ("At level 10: <our word>").
    function R.loose(s, d, c)
        local codes = c.codes
        local uk = Flips(s, Base(s, codes, {}), d)
        if uk then return uk end
        if find(s, "%d%.%d") then
            local dot = Base(s, codes, {}, true)
            uk = Fill(s, dot, d) or Flips(s, dot, d)
            if uk then return uk end
        end
        local n, i, sp = #s, 1, 0
        while sp < MAXCUTS do
            local p = find(s, " ", i, true)
            if not p then break end
            if p < n and not InCode(codes, p, p) then
                sp = sp + 1
                local nums = Base(s, codes, { { p + 1, n } })
                if #nums > 0 then
                    uk = Fill(s, With(nums, { a = p + 1, b = n, en = sub(s, p + 1, n) }), d)
                    if uk then return uk end
                end
            end
            i = p + 1
        end
    end

    local order = type(opts.order) == "table" and opts.order or TRIES
    local function Tries(s, d)
        local c = { codes = Codes(s) }
        for _, name in ipairs(order) do
            local f = R[name]
            local uk = f and f(s, d, c)
            if uk then return uk end
        end
        return nil
    end

    -- A text whose tries met no template of ours never will (the data does not change): kept, so a line that
    -- also asked a route does not run the loops again. A route is asked only once a template matched.
    local miss, nmiss = {}, 0
    function P.Shapes(s, d)
        if type(s) ~= "string" or s == "" or miss[s] then return nil end
        local was = P.matched
        P.matched = false
        local ok, uk = pcall(Tries, s, d)
        if not ok then
            pcall(U.ReportError, tostring(uk))
            if opts.key and U.Fault then pcall(U.Fault, opts.key, tostring(uk)) end
            uk = nil
        elseif uk == nil and not P.matched then
            if nmiss >= 400 then miss, nmiss = {}, 0 end
            miss[s], nmiss = true, nmiss + 1
        end
        P.matched = was or P.matched
        return uk
    end
    function P.Forget() miss, nmiss = {}, 0 end
    function P.Try(name, s, d) local f = R[name] return f and f(s, d, { codes = Codes(s) }) or nil end

    P.FillWith, P.Fill = raw, Fill                       -- FillWith: CodeText's own Fill(s, slots, Resolve)
    P.Numbers, P.Val, P.OneLink, P.N, P.Item, P.Kept, P.Date = Numbers, Val, OneLink, N, Item, Kept, Date
    P.Base, P.With, P.Parens, P.WordEnds, P.Piece, P.Resolver, P.TRIES = Base, With, Parens, WordEnds, Piece,
        Resolver, R
    return P
end
