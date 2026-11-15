-- Texts by hash: finding another addon's English on screen without keeping its English.
-- Most addons we translate are All Rights Reserved, so our data may not hold their texts. It holds a
-- hash of each English text (djb2, 32 bits: the same as tools/hashtext.py) and our Ukrainian.
--   * UADD.Hash(s): 8 hex digits ("00001505" for ""). UADD_DungeonJournal's prose keys are these too.
--   * UADD.TextIndex(data): an index over a table that tools/hashtext.py writes:
--       data.exact     = { ["<bytes>:<hash>"] = Ukrainian }   -- "14:1f2e3d4c": the length comes first
--       data.templates = { { id = .., len = { .. }, hash = { .. }, kinds = { .. }, uk = { .. } }, .. }
--     A template is an English text with slots (%s, %d, %.1f, %02x, %1$s, ##NAME##, [KEY:..]). Of its
--     English only the literal pieces around the slots are kept, each as its length and hash: a
--     template with N slots has N + 1 pieces (some may be empty). kinds[i] says what slot i may hold.
--     uk is our Ukrainian as pieces: a string is text, a number k is slot k's value (any order).
--   * index:Exact(s) -> Ukrainian or nil. A length no text has is never hashed.
--   * index:Match(s [, after]) -> id, captures, rank: the template `s` was filled in from, and what
--     each slot holds. When several fit, the one with the most literal bytes wins (rank 1 is the
--     best; a tie goes to the earlier one in data.templates), like the modules' "longest English
--     first". `after`: only templates ranked below that one (the next best, when Fill said no).
--   * index:Fill(id, captures [, fn]) -> Ukrainian or nil. fn(k, value, template) may return a new
--     value for slot k (a translated %s), nil to keep it, or false: this template does not fit.
--   * index:Text(s [, fn]) -> Exact, else the best Match whose Fill works (then also its id).
-- Slot kinds: s any text, l one line, d a whole number ("-1,234"), f a number with a point too,
-- x hex digits, x2 two hex digits (a colour byte), t a |T..|t picture (DialogueUI's [KEY:..]).
-- A secret string (UADD.Plain says no) gives nil everywhere.
-- Speed (these run in SetText hooks): Match hashes the text once, keeping the hash of every prefix,
-- so the hash of any piece of the text is a few sums. It then tries only the templates whose first
-- piece (or last piece, for a template that starts with a slot) has a length and hash the text has.
-- A middle piece is looked for at each place it could start, by its hash. A miss makes no tables
-- and no strings; a hit makes one table and a string per slot.

UADD = UADD or {}
local U = UADD

local byte, floor, format = string.byte, math.floor, string.format
local M = 4294967296          -- 2^32: the hash is kept below it
local MAX_LEN = 1000          -- a longer text is never matched against templates

local function HashNum(s)
    local h = 5381
    for i = 1, #s do h = (h * 33 + byte(s, i)) % M end    -- below 2^38: a double holds it exactly
    return h
end

-- Two halves: some clients' %x cannot print a number past 2^31.
local function Hex(h) return format("%04x%04x", floor(h / 65536), h % 65536) end

function U.Hash(s)
    s = U.Plain(s)
    return s and Hex(HashNum(s)) or nil
end

-- (a * b) % 2^32 in 16-bit halves: a * b itself can need 64 bits, more than a double holds.
local function MulMod(a, b)
    local al, bl = a % 65536, b % 65536
    local ah, bh = (a - al) / 65536, (b - bl) / 65536
    return ((ah * bl + al * bh) % 65536 * 65536 + al * bl) % M
end

local POW = { [0] = 1 }       -- 33^i % 2^32
for i = 1, MAX_LEN do POW[i] = POW[i - 1] * 33 % M end

-- ── Matching ─────────────────────────────────────────────────────────────────────────────────
-- Scratch shared by every index (Match never calls out while it uses them): the text, its length,
-- P[i] = the hash of its first i bytes, the slot bounds of the try in progress (CS/CE) and of the
-- best match so far (BS/BE), and the template being tried (T, with N slots).
local S, SN, P, CS, CE, BS, BE = "", 0, {}, {}, {}, {}, {}
local T, N

local function Prefixes(n)
    local h = 5381
    P[0] = h
    for i = 1, n do h = (h * 33 + byte(S, i)) % M P[i] = h end
end

-- The hash of S[i..j]: djb2 is P[j] - P[i-1] * 33^len + 5381 * 33^len.
local function Sub(i, j)
    return (P[j] + MulMod((5381 - P[i - 1]) % M, POW[j - i + 1])) % M
end

local function Set(chars)
    local t = {}
    for i = 1, #chars do t[byte(chars, i)] = true end
    return t
end
local DIGITS = "0123456789"
local CLASS = { d = Set(DIGITS .. ","), f = Set(DIGITS .. ".,"), x = Set(DIGITS .. "abcdefABCDEF") }
CLASS.x2 = CLASS.x
local SIGNED = { d = true, f = true }
local MIN = { s = 0, l = 0, d = 1, f = 1, x = 1, x2 = 2, t = 4 }   -- the fewest bytes a slot holds
local MINUS, NL, BAR, UT, LT = 45, 10, 124, 84, 116                -- "-", "\n", "|", "T", "t"

local Try

-- Slot i is S[cur .. p-1]; piece i+1 must start at p, then the next slot follows it.
local function Step(i, cur, p)
    if i == N then CS[i], CE[i] = cur, p - 1 return true end   -- the last piece was checked first
    local L = T.L[i + 1]
    if L > 0 and Sub(p, p + L - 1) ~= T.H[i + 1] then return false end
    CS[i], CE[i] = cur, p - 1
    return Try(i + 1, p + L)
end

-- A number slot: its longest run first, then shorter ones (as Lua's greedy "[%d,]+").
local function Number(i, cur, hi, kind)
    local class, j = CLASS[kind], cur
    if SIGNED[kind] and byte(S, j) == MINUS then j = j + 1 end
    local first, stop = j, hi - 1
    if kind == "x2" and stop > first + 1 then stop = first + 1 end
    while j <= stop and class[byte(S, j)] do j = j + 1 end
    local low = first + MIN[kind]
    if i == N then return hi >= low and hi <= j and Step(i, cur, hi) end
    for p = j, low, -1 do
        if Step(i, cur, p) then return true end
    end
    return false
end

-- Slot i starts at cur. hi: the last place the piece after it can start (room for the rest).
Try = function(i, cur)
    local kind = T.kinds[i]
    local hi = SN - T.tail[i + 1] + 1
    if hi < cur + MIN[kind] then return false end
    if CLASS[kind] then return Number(i, cur, hi, kind) end
    if kind == "s" and i == N then return Step(i, cur, hi) end
    local pic = kind == "t"
    if pic and (byte(S, cur) ~= BAR or byte(S, cur + 1) ~= UT) then return false end
    local lo = i == N and hi or cur + MIN[kind]
    for p = cur, hi do                                  -- the shortest first (as Lua's ".-")
        if kind == "l" and p > cur and byte(S, p - 1) == NL then return false end
        if p >= lo and (not pic or (byte(S, p - 2) == BAR and byte(S, p - 1) == LT)) and Step(i, cur, p) then
            return true
        end
    end
    return false
end

local function Whole(rec)
    if SN < rec.tail[1] then return false end
    T, N = rec, rec.N
    local L1, Lz = rec.L[1], rec.L[N + 1]
    if L1 > 0 and P[L1] ~= rec.H[1] then return false end
    if Lz > 0 and Sub(SN - Lz + 1, SN) ~= rec.H[N + 1] then return false end
    return Try(1, L1 + 1)
end

-- The best template of `list` (rank order) that fits and beats `best`; its bounds go to BS/BE.
local function Scan(list, after, best)
    for k = 1, #list do
        local rec = list[k]
        if best and rec.rank >= best.rank then return best end
        if rec.rank > after and Whole(rec) then
            for i = 1, rec.N do BS[i], BE[i] = CS[i], CE[i] end
            return rec
        end
    end
    return best
end

-- ── The index ────────────────────────────────────────────────────────────────────────────────

local Index = {}
Index.__index = Index

-- A template as the matcher needs it, or nil when its data is broken (it is left out).
local function Record(d, pos)
    if type(d) ~= "table" or type(d.kinds) ~= "table" or type(d.uk) ~= "table" then return nil end
    local n = #d.kinds
    if n < 1 or type(d.len) ~= "table" or type(d.hash) ~= "table" or #d.len ~= n + 1 or #d.hash ~= n + 1 then
        return nil
    end
    local rec = { data = d, id = d.id or pos, pos = pos, N = n, kinds = d.kinds, L = {}, H = {}, tail = {}, lit = 0 }
    for i = 1, n + 1 do
        rec.L[i], rec.H[i] = tonumber(d.len[i]), tonumber(d.hash[i], 16)
        if not rec.L[i] or not rec.H[i] or (i <= n and not MIN[d.kinds[i]]) then return nil end
        rec.lit = rec.lit + rec.L[i]
    end
    local tail = rec.L[n + 1]                           -- tail[j]: the fewest bytes from piece j on
    rec.tail[n + 1] = tail
    for j = n, 1, -1 do
        tail = tail + MIN[d.kinds[j]] + rec.L[j]
        rec.tail[j] = tail
    end
    return rec
end

local function Bucket(map, lens, len, h, rec)
    if not map[len] then map[len] = {} lens[#lens + 1] = len end
    local list = map[len][h] or {}
    map[len][h] = list
    list[#list + 1] = rec                               -- added in rank order
end

function U.TextIndex(data)
    data = type(data) == "table" and data or {}
    local self = setmetatable({ byLen = {}, byId = {}, pre = {}, preLens = {}, suf = {}, sufLens = {},
        loose = {}, exacts = 0 }, Index)
    for key, uk in pairs(type(data.exact) == "table" and data.exact or {}) do
        local len, h = tostring(key):match("^(%d+):(%x+)$")
        if len and type(uk) == "string" then
            len = tonumber(len)
            self.byLen[len] = self.byLen[len] or {}
            self.byLen[len][tonumber(h, 16)] = uk
            self.exacts = self.exacts + 1
        end
    end
    local recs = {}
    for pos, d in ipairs(type(data.templates) == "table" and data.templates or {}) do
        recs[#recs + 1] = Record(d, pos)
    end
    table.sort(recs, function(a, b) return a.lit > b.lit or (a.lit == b.lit and a.pos < b.pos) end)
    for rank, rec in ipairs(recs) do
        rec.rank = rank
        if self.byId[rec.id] == nil then self.byId[rec.id] = rec end
        local L1, Lz = rec.L[1], rec.L[rec.N + 1]
        if L1 > 0 then Bucket(self.pre, self.preLens, L1, rec.H[1], rec)
        elseif Lz > 0 then Bucket(self.suf, self.sufLens, Lz, rec.H[rec.N + 1], rec)
        else self.loose[#self.loose + 1] = rec end      -- starts and ends with a slot: always tried
    end
    table.sort(self.preLens)
    table.sort(self.sufLens)
    self.templates = #recs
    return self
end

function Index:Exact(s)
    s = U.Plain(s)
    local m = s and self.byLen[#s]
    return m and m[HashNum(s)] or nil
end

function Index:Match(s, after)
    s = U.Plain(s)
    if not s or self.templates == 0 then return nil end
    local n = #s
    if n == 0 or n > MAX_LEN then return nil end
    S, SN = s, n
    Prefixes(n)
    after = after or 0
    local best
    local lens, map = self.preLens, self.pre
    for k = 1, #lens do
        local L = lens[k]
        if L > n then break end
        local list = map[L][P[L]]
        if list then best = Scan(list, after, best) end
    end
    lens, map = self.sufLens, self.suf
    for k = 1, #lens do
        local L = lens[k]
        if L > n then break end
        local list = map[L][Sub(n - L + 1, n)]
        if list then best = Scan(list, after, best) end
    end
    best = Scan(self.loose, after, best)
    S = ""
    if not best then return nil end
    local caps = {}
    for i = 1, best.N do caps[i] = s:sub(BS[i], BE[i]) end
    return best.id, caps, best.rank
end

function Index:Fill(id, caps, fn)
    local rec = self.byId[id]
    if not rec or type(caps) ~= "table" then return nil end
    local d, out = rec.data, {}
    for k, part in ipairs(d.uk) do
        if type(part) == "number" then
            local v = caps[part]
            if v == nil then return nil end
            if fn then
                local r = fn(part, v, d)
                if r == false then return nil end
                if r ~= nil then v = r end
            end
            part = v
        end
        out[k] = part
    end
    return table.concat(out)
end

function Index:Text(s, fn)
    local uk = self:Exact(s)
    if uk then return uk end
    local after = 0
    while true do
        local id, caps, rank = self:Match(s, after)
        if not id then return nil end
        uk = self:Fill(id, caps, fn)
        if uk then return uk, id end
        after = rank
    end
end

-- The template's data (kinds, names, uk and any fields the module's generator added), or nil.
function Index:Template(id)
    local rec = self.byId[id]
    return rec and rec.data or nil
end

-- How many exact texts and templates the index holds.
function Index:Count() return self.exacts, self.templates end
