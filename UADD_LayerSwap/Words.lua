-- LayerSwap's English texts -> our Ukrainian. No English is kept: data/words.lua (ns.LSW, made by
-- tools/make_lsw_data.py) holds hashes of it, and UADD.TextIndex (UADD/Hash.lua) finds them on screen.
--   * Exact: a whole text the addon shows -> its Ukrainian.
--   * Template: a text with %s / %d slots; what each slot holds goes into the Ukrainian. A %s that is
--     itself one of the addon's texts is translated too. When several templates fit, the one with the
--     most fixed text wins. A %s holding other English means the template does not fit, so a line is
--     never half translated; only slots marked free (names, zones) keep English.
--   * A text in one colour (|cff..text|r) is translated inside the colour.
--   * A text glued from several of the addon's own (a help line, a title and a dash) is split at its
--     first joining mark (Parts); every piece must be one of its texts.
--   * Plural forms: our Ukrainian may hold {one|few|many}, e.g. "5 {гравець|гравці|гравців}". The form
--     is picked by the last number before the mark (Plural). A mark with no number before it inside a
--     piece is kept until the whole line is put together, then picked; with no number at all, "many".
-- Speed: the panel sets its texts every second, so
--   * a text with no letters (numbers, "3/40") is skipped at once;
--   * every answer is kept (memo, wiped past MEMO_MAX); the index looks only at templates whose first
--     or last piece the text has;
--   * in combat (W.Quick): the memo, the exact texts, and a FontString (or %s slot) that matched a
--     template before may match again, but no colour or glued-text search, and nothing new is kept.
-- Never translated: texts with Ukrainian letters (already ours).

local _, ns = ...
local W = {}
ns.Words = W

local U = UADD
local CYR = "[\208-\210]"
local idx, knownIdx = U.TextIndex({}), U.TextIndex({})
local memo, memoSize = {}, 0
local hint = setmetatable({}, { __mode = "k" })   -- FontString or slot key -> rank of its last template
local slotKeys = {}                                -- template data -> { [slot] = that slot's hint key }
local count = 0
local MEMO_MAX, MAX_LEN, MAX_DEPTH = 3000, 600, 3

local Text, Quick, Parts
local BULLET = "\226\128\162"

-- ── Plural forms ─────────────────────────────────────────────────────────────────────────────

-- The Ukrainian form for n: 1, 21, 31 -> one; 2-4, 22-24 -> few; the rest -> many. A fraction -> few.
local function Form(num)
    if not num then return 3 end
    local whole, frac = num:match("^([%d,]*)%.?(%d*)$")
    if frac and frac:find("[1-9]") then return 2 end
    local n = tonumber((whole or num):gsub(",", ""), 10)
    if not n then return 3 end
    local ten, hundred = n % 10, n % 100
    if ten == 1 and hundred ~= 11 then return 1 end
    if ten >= 2 and ten <= 4 and (hundred < 12 or hundred > 14) then return 2 end
    return 3
end

-- The last number in s (colour codes and icons do not count), or nil.
local function LastNumber(s)
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
    local last
    for n in s:gmatch("%d[%d,%.]*") do last = n end
    return last and (last:gsub("[,%.]+$", "")) or nil
end

-- Every {one|few|many} in uk picked by the last number before it. final: a mark with no number
-- before it takes "many"; otherwise it is kept for the whole line.
local function Plural(uk, final)
    if type(uk) ~= "string" or not uk:find("{", 1, true) then return uk end
    return (uk:gsub("(){([^{}|]*)|([^{}|]*)|([^{}|]*)}", function(at, one, few, many)
        local num = LastNumber(uk:sub(1, at - 1))
        if not num and not final then return nil end
        local k = Form(num)
        return k == 1 and one or k == 2 and few or many
    end))
end
W.Plural = Plural

-- ── The tables ───────────────────────────────────────────────────────────────────────────────

-- Signature of a template's English: its pieces' lengths and hashes and its slot kinds.
local function Sig(d)
    return table.concat(d.len, ",") .. "|" .. table.concat(d.hash, ",") .. "|" .. table.concat(d.kinds, ",")
end

-- data/words.lua's tables, with `extra` (the checks' own test texts) over them: its exact texts win,
-- and its templates take the place of ours with the same English.
local function Merge(base, extra)
    local exact, templates, mine = {}, {}, {}
    for k, v in pairs(base.exact or {}) do exact[k] = v end
    for k, v in pairs(extra.exact or {}) do exact[k] = v end
    for _, d in ipairs(extra.templates or {}) do mine[Sig(d)] = true end
    for _, d in ipairs(base.templates or {}) do
        if not mine[Sig(d)] then templates[#templates + 1] = d end
    end
    for _, d in ipairs(extra.templates or {}) do templates[#templates + 1] = d end
    return { exact = exact, templates = templates }
end

function W.Build(extra)
    local base = ns.LSW or {}
    idx = U.TextIndex(Merge(base, extra or {}))
    local known = {}
    for _, k in ipairs(base.known or {}) do known[k] = "" end
    knownIdx = U.TextIndex({ exact = known, templates = base.long })
    wipe(memo) wipe(hint) wipe(slotKeys)
    memoSize = 0
    local e, t = idx:Count()
    count = e + t
end

-- ── Templates ────────────────────────────────────────────────────────────────────────────────

-- The hint key of slot k of template d: a slot's last template is kept like a FontString's.
local function SlotKey(d, k)
    local keys = slotKeys[d] or {}
    slotKeys[d] = keys
    keys[k] = keys[k] or {}
    return keys[k]
end

-- A value the addon puts in a %s as it is: no letters but a unit of 1 to 3 right after a digit
-- ("1,234", "5m", "<1m", "--"), or one capital letter alone (a layer's letter: "B" in "Layer B").
-- Colour codes and icons around it do not count.
local function IsValue(c)
    c = c:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
    if c:find("^%u$") then return true end
    local from = 1
    while true do
        local a, b = c:find("%a+", from)
        if not a then return true end
        if b - a > 2 or a == 1 or not c:find("^%d", a - 1) then return false end
        from = b + 1
    end
end

local function Has(list, k)
    if list then
        for _, v in ipairs(list) do if v == k then return true end end
    end
    return false
end

-- What goes into slot k (holding c) of template d, for Index:Fill: false when the template does not
-- fit, nil to keep c. A %s must hold a value or one of the addon's own texts (translated here, or
-- one it shows in English): other English there means another text that only starts or ends like
-- this one, and a half-translated line is worse than none. Only d.free slots keep any English.
-- One function per depth and mode, made once.
local fillers = { [false] = {}, [true] = {} }
local function Filler(depth, quick)
    local f = fillers[quick][depth]
    if f then return f end
    f = function(k, c, d)
        local s = d.kinds[k] == "s"
        -- A bullet or a wide gap in a %s: a short template ate a glued text. Not this one, then.
        if s and (c:find(BULLET, 1, true) or c:find("   ", 1, true)) then return false end
        if Has(d.blank, k) then return "" end
        if not s then return nil end
        if IsValue(c) then return nil end
        if depth < MAX_DEPTH then
            local uk = (quick and Quick or Text)(c, SlotKey(d, k), depth + 1)
            if uk then return uk end
        end
        -- A free slot holds one name: a line break or " - " in it means a text glued on. Not this one.
        if Has(d.free, k) and not (c:find("\n", 1, true) or c:find(" - ", 1, true)) then return nil end
        if knownIdx:Exact(c) ~= nil then return nil end
        return false
    end
    fillers[quick][depth] = f
    return f
end

-- t filled in from one of the templates, in Ukrainian, or nil. Best template first; when one does not
-- fit (Filler said no), the next best. Quick: only a FontString's (or slot's) last template or a
-- better one, and no second try.
local function Search(t, fs, depth, quick)
    local h = fs and hint[fs]
    if quick and not h then return nil end
    local fn, after = Filler(depth, quick), 0
    while true do
        local id, caps, rank = idx:Match(t, after)
        if not id or (quick and rank > h) then return nil end
        local uk = idx:Fill(id, caps, fn)
        if uk then
            if fs then hint[fs] = rank end
            return uk
        end
        if quick then return nil end
        after = rank
    end
end

-- One text in Ukrainian, or nil. `fs`: the FontString (or slot) it is for.
local function One(t, fs, depth)
    local uk = idx:Exact(t)
    if uk then return uk end
    if #t > MAX_LEN then return nil end
    uk = Search(t, fs, depth, false)
    if uk then return uk end
    local code, inner = t:match("^(|c%x%x%x%x%x%x%x%x)(.-)|r$")
    if code and not inner:find("|r", 1, true) then
        uk = One(inner, nil, depth)
        if uk then return code .. uk .. "|r" end
    end
    return Parts(t, depth)
end

-- The marks LayerSwap joins its texts with, and ours. Bullets become dashes: the game's fonts with
-- Ukrainian letters may have no bullet. The help line's wide bar comes first (before the wide gap).
local SEPS = { { "   |   ", "   |   " }, { "\n", "\n" }, { "  |  ", "  |  " },
    { "   \226\128\162   ", "   —   " }, { "  \226\128\162  ", "  —  " }, { " \226\128\162 ", " — " },
    { " - ", " — " }, { "   ", "   " } }

-- A piece: no letters stays as it is; the rest goes through Text, so a piece, found or not, is kept.
local function Piece(t, depth)
    if not t:find("%a") then return t end
    return Text(t, nil, depth)
end

-- t split at the first joining mark in SEPS's order that it holds, both sides in Ukrainian, or nil.
-- Only that mark is tried: a miss is a miss (no other split). Each side is shorter, so it ends.
Parts = function(t, depth)
    for _, sep in ipairs(SEPS) do
        local s, e = t:find(sep[1], 1, true)
        if s then
            local a = Piece(t:sub(1, s - 1), depth)
            local b = a and Piece(t:sub(e + 1), depth)
            return b and a .. sep[2] .. b or nil
        end
    end
    return nil
end

-- A text LayerSwap showed, in Ukrainian (plural marks with a number before them picked), or nil.
-- A text with no letters returns at once and is not kept.
Text = function(t, fs, depth)
    if type(t) ~= "string" or not t:find("%a") then return nil end
    local hit = memo[t]
    if hit ~= nil then return hit or nil end
    local uk
    if not t:find(CYR) then uk = Plural(One(t, fs, depth or 0), false) end
    if memoSize >= MEMO_MAX then wipe(memo) memoSize = 0 end
    memo[t], memoSize = uk or false, memoSize + 1
    return uk
end

-- In combat: the memo, the exact texts and the FontString's last template (see Search). Not kept: a
-- %s inside may have stayed English here that a full search would translate.
Quick = function(t, fs, depth)
    if type(t) ~= "string" or not t:find("%a") then return nil end
    local hit = memo[t]
    if hit ~= nil then return hit or nil end
    local uk = idx:Exact(t)
    if uk then return Plural(uk, false) end
    if not fs or #t > MAX_LEN or t:find(CYR) then return nil end
    return Plural(Search(t, fs, depth or 0, true), false)
end

-- The whole line: every plural mark left picked too.
function W.Text(t, fs) return Plural(Text(t, fs), true) end
function W.Quick(t, fs) return Plural(Quick(t, fs), true) end

-- One of LayerSwap's exact English texts (translated or not).
function W.Known(t) return knownIdx:Exact(t) ~= nil end
function W.Index() return idx, knownIdx end   -- for U.Missed: our templates, then the kept ones

-- For the status line: how many texts we can show in Ukrainian.
function W.Count() return count end

-- For the checks: how many texts the memo holds.
function W.MemoSize() return memoSize end
