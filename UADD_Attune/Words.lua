-- Attune's English texts -> our Ukrainian. The pairs come from Pairs.lua (our tables, with the English
-- read from Attune's AttuneLang), plus ns.UA_TEXTHASH (data/hashed.lua): English Attune writes in its
-- code, found by the hash of the shown text (UADD.TextIndex). A text missing there stays English.
--   * Exact: a text as Attune shows it -> its Ukrainian. Then a quest, NPC, item or zone name that
--     Names.lua found in UALL Forever.
--   * Template: Attune fills "##NAME##"-style places with :gsub. Such a text becomes a pattern; what each
--     place captures goes into the Ukrainian at the place with the same name (the order may differ).
--     A capture that is itself one of Attune's texts or names is translated too. Only when both texts
--     have the same places and the same |c |r |T |t |H |h |n codes.
--   * A "%s" template (a glued line, or a locale text with %s in it) works the same way, its places in
--     order, but strictly: each place with letters must be translated too, else the whole text stays
--     English (the "in" line never half-translates a quest title that has the word in it).
--   * A text in one colour (|cff..text|r) is translated inside the colour.
--   * Anything else Attune builds from pieces (a reputation word and a faction, a level, a rank and a
--     kind, two colours on one line, several lines): Shape.lua translates it piece by piece.
-- Speed: Attune rebuilds about a hundred step boxes when an attunement is picked, and the Next window
-- on every bag change, so
--   * a text with no letters ("5/10", "45%") is skipped at once;
--   * every answer is kept (memo, wiped past MEMO_MAX); a miss tries the template that matched the
--     same FontString last time first (hint), then the rest, longest English first. A matching hint
--     still loses to a longer template that matches too (its rivals).
--   * In combat (W.Quick): the memo, the exact table and the hint only.
-- Never translated: texts with Ukrainian letters, and keys whose Ukrainian is the English.
-- AttuneLang is only read (rawget), never written.

local _, ns = ...
local W = {}
ns.Words = W

local CYR = "[\208-\210]"
local PLACE = "##(%u[%u%d_]*)##"
local exact, formats, names = {}, {}, {}
local hashed            -- UADD.TextIndex of ns.UA_TEXTHASH, made by W.Build
local tags = {}         -- the attunements' short tags ("MC", "Ony"): shown as they are
local nlFormats = {}      -- the templates whose English has a line break (the only ones a text with one tries)
local memo, memoSize = {}, 0
local hint = setmetatable({}, { __mode = "k" })   -- FontString -> the template it matched last
local count = 0
local MEMO_MAX, MAX_LEN, MAX_DEPTH = 3000, 600, 3
-- Places that hold a player name, a number or a version: left as they are (a player called like
-- an NPC keeps their name).
local KEEP = { PLAYER = true, FROM = true, TO = true, VERSION = true, COUNT = true, DURATION = true,
    LEVEL = true, NUMBER = true, SIZE = true, SKILL = true, NB = true }


-- ── Patterns ─────────────────────────────────────────────────────────────────────────────────

-- The template's pieces: { "lit", text } / { "place", NAME }.
local function Tokens(t)
    local out, pos = {}, 1
    while true do
        local s, e, name = t:find(PLACE, pos)
        if not s then out[#out + 1] = { "lit", t:sub(pos) } break end
        if s > pos then out[#out + 1] = { "lit", t:sub(pos, s - 1) } end
        out[#out + 1] = { "place", name }
        pos = e + 1
    end
    return out
end

local function Codes(t)
    local c = {}
    for _, code in ipairs({ "|c", "|r", "|T", "|t", "|H", "|h", "|n" }) do
        local _, n = t:gsub(code:gsub("|", "%%|"), "")
        c[#c + 1] = n
    end
    return table.concat(c, ",")
end

-- The place names, sorted: the same set in both texts, whatever the order.
local function PlaceSet(toks)
    local s = {}
    for _, tk in ipairs(toks) do if tk[1] == "place" then s[#s + 1] = tk[2] end end
    table.sort(s)
    return table.concat(s, ",")
end

-- A pattern for `en` and the Ukrainian pieces, or nil when the two do not fit together.
local function Build(en, uk)
    local et, ut = Tokens(en), Tokens(uk)
    if PlaceSet(et) ~= PlaceSet(ut) or Codes(en) ~= Codes(uk) then return nil end
    local parts, lit, at, k = { "^" }, 0, {}, 0
    for _, tk in ipairs(et) do
        if tk[1] == "lit" then
            parts[#parts + 1] = tk[2]:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
            lit = lit + #tk[2]
        else
            k = k + 1
            if at[tk[2]] then return nil end      -- one place twice: no single answer
            at[tk[2]] = k
            parts[#parts + 1] = KEEP[tk[2]] and "([^\n]-)" or "(.-)"   -- a name or number is one line
        end
    end
    if lit < 3 then return nil end            -- "##A## ##B##" alone would match anything
    parts[#parts + 1] = "$"
    return { pat = table.concat(parts), uk = ut, at = at, lit = lit, en = en,
        first = et[1][1] == "lit" and et[1][2] or "", last = et[#et][1] == "lit" and et[#et][2] or "",
        slots = {}, rivals = {} }
end

local Text, Quick

local function Fill(f, caps, depth, quick)
    local out = {}
    for _, tk in ipairs(f.uk) do
        if tk[1] == "lit" then out[#out + 1] = tk[2]
        else
            local k = f.at[tk[2]]
            local c = caps[k] or ""
            local uk
            if depth < MAX_DEPTH and not KEEP[tk[2]] then
                f.slots[k] = f.slots[k] or {}             -- this place's hint key
                uk = (quick and Quick or Text)(c, f.slots[k], depth + 1)
            end
            if f.strict and not uk and not ns.Shape.Neutral(c) then return nil end
            c = uk or c
            out[#out + 1] = c
        end
    end
    return table.concat(out)
end

-- ── The tables ───────────────────────────────────────────────────────────────────────────────

-- "%s" places as "##S1##", "##S2##" ... in order, "%%" as "%". nil when the text has no "%s".
local function Printf(t)
    if not t:find("%s", 1, true) then return nil end
    local n = 0
    t = t:gsub("%%%%", "\1"):gsub("%%s", function() n = n + 1 return "##S" .. n .. "##" end)
    return (t:gsub("\1", "%%"))
end

-- One English text and its Ukrainian into the tables.
local function Add(en, uk)
    if type(en) ~= "string" or en == "" then return end
    if type(uk) ~= "string" or uk == "" or uk == en then return end
    uk = uk:gsub("\\n", "\n")                     -- a written \n is a line break, as in Attune
    local pen, puk = Printf(en), Printf(uk)
    if pen and puk then
        local f = Build(pen, puk)
        if f then f.strict, formats[#formats + 1], count = true, f, count + 1 end
    elseif en:find(PLACE) then
        local f = Build(en, uk)
        if f then formats[#formats + 1], count = f, count + 1 end
    elseif exact[en] == nil then
        exact[en], count = uk, count + 1
    end
end

function W.Build()
    wipe(exact) wipe(formats) wipe(nlFormats) wipe(memo)
    memoSize, count = 0, 0
    ns.Pairs(Add)
    -- English Attune writes in its code: found by the hash of the shown text.
    hashed = UADD.TextIndex({ exact = ns.UA_TEXTHASH or {} })
    count = count + (hashed:Count())
    wipe(tags)
    local data = rawget(_G, "Attune_Data")
    local list = type(data) == "table" and rawget(data, "attunes")
    for _, a in ipairs(type(list) == "table" and list or {}) do
        local short = type(a) == "table" and rawget(a, "SHORT")
        if type(short) == "string" and short ~= "" then tags[short] = true end
    end
    table.sort(formats, function(a, b) return a.lit > b.lit or (a.lit == b.lit and a.en < b.en) end)
    for _, f in ipairs(formats) do
        f.nl = f.en:find("\n", 1, true) ~= nil
        if f.nl then nlFormats[#nlFormats + 1] = f end
    end
    -- Rivals: the templates before f in that order that could match a text f matches (one start is
    -- the start of the other, one end the end of the other).
    local function Fits(a, b, tail)
        if a == "" or b == "" then return true end
        if #a < #b then a, b = b, a end
        return (tail and a:sub(-#b) or a:sub(1, #b)) == b
    end
    for i, f in ipairs(formats) do
        for j = 1, i - 1 do
            local g = formats[j]
            if Fits(f.first, g.first) and Fits(f.last, g.last, true) then f.rivals[#f.rivals + 1] = g end
        end
    end
end

-- The names Names.lua found (English -> Ukrainian). The memo is wiped: misses may hit now.
function W.SetNames(map)
    names = type(map) == "table" and map or {}
    wipe(memo)
    memoSize = 0
end

-- A whole text from our tables or the names, or nil. No search: for Shape.lua's pieces.
function W.Exact(t) return exact[t] or (hashed and hashed:Exact(t)) or names[t] end

-- An attunement's short tag ("Ony"): Attune's own abbreviation, kept as it is.
function W.Tag(t) return tags[t] == true end

local function Try(f, t, depth, quick)
    local caps = { t:match(f.pat) }
    if caps[1] == nil then return nil end
    return Fill(f, caps, depth, quick)
end

-- The hint's answer, or nil: `fs`'s last template, unless a longer one (a rival) matches too.
local function Hinted(t, fs, depth, quick)
    local h = hint[fs]
    if not h or (not h.nl and t:find("\n", 1, true)) or not t:find(h.pat) then return nil end
    for _, g in ipairs(h.rivals) do
        if t:find(g.pat) then h = g break end
    end
    hint[fs] = h
    return Fill(h, { t:match(h.pat) }, depth, quick)
end

-- One text in Ukrainian, or nil. `fs`: the FontString (or place) it is for (its last template first).
local function One(t, fs, depth)
    local uk = exact[t] or (hashed and hashed:Exact(t)) or names[t]
    if uk then return uk end
    if #t > MAX_LEN then return nil end
    local nl = t:find("\n", 1, true)
    local h = fs and hint[fs]
    if h then
        uk = Hinted(t, fs, depth)
        if uk then return uk end
    end
    for _, f in ipairs(nl and nlFormats or formats) do
        if f ~= h then
            uk = Try(f, t, depth)
            if uk then
                if fs then hint[fs] = f end
                return uk
            end
        end
    end
    local code, inner = t:match("^(|c%x%x%x%x%x%x%x%x)(.-)|r$")
    if code and not inner:find("|r", 1, true) then
        uk = One(inner, nil, depth)
        if uk then return code .. uk .. "|r" end
    end
    if depth < MAX_DEPTH then return ns.Shape.Text(t, depth + 1) end
    return nil
end
W.One = function(t, depth) return One(t, nil, depth) end

-- A text Attune showed, in Ukrainian, or nil when it is none of its texts.
-- A text with no letters ("5/10", "45%") returns at once and is not kept.
Text = function(t, fs, depth)
    if type(t) ~= "string" or not t:find("%a") then return nil end
    local hit = memo[t]
    if hit ~= nil then return hit or nil end
    local uk
    if not t:find(CYR) then uk = One(t, fs, depth or 0) end
    if memoSize >= MEMO_MAX then wipe(memo) memoSize = 0 end
    memo[t], memoSize = uk or false, memoSize + 1
    return uk
end
W.Text = Text

-- In combat: the memo, the exact table, the names and the hint only (no search). Not kept: a place
-- inside may have stayed English here that a search would translate.
Quick = function(t, fs, depth)
    if type(t) ~= "string" or not t:find("%a") then return nil end
    local hit = memo[t]
    if hit ~= nil then return hit or nil end
    local uk = exact[t] or (hashed and hashed:Exact(t)) or names[t]
    if uk then return uk end
    if not fs or #t > MAX_LEN or t:find(CYR) then return nil end
    return Hinted(t, fs, depth or 0, true)
end
W.Quick = Quick

-- For the status line: how many texts we can show in Ukrainian.
function W.Count() return count end

-- For the checks: how many texts the memo holds.
function W.MemoSize() return memoSize end
