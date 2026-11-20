-- DialogueUI's English texts -> our Ukrainian. Only texts that are a DialogueUI L value change.
-- DialogueUI is all rights reserved and keeps its L private, so no English of it is here: ui/hashes.lua
-- (tools/make_dui_data.py, from the installed addon) has, per DialogueUI locale key, hashes of that key's
-- English (UADD/Hash.lua). W.Build joins them with our Ukrainian (ns.UA, ui/locale.lua, the same keys) into
-- one UADD.TextIndex. A key DialogueUI takes from a game global first (`GLOBAL or ...`) is hashed from the
-- game's own text here, as that is what DialogueUI shows (Shape below; the tool makes the same).
--   * Exact: the English of a key, as the game shows it -> its Ukrainian.
--   * Formatted: an English with %s / %d / [KEY:..] is a template; what its slots hold goes into the
--     Ukrainian in the same order. "[KEY:PC:SPACE]" markup reaches the screen as a |T..|t picture
--     (DialogueUI's LocaleFormatter.lua), so that slot holds the picture and goes where the Ukrainian
--     has the same key. Only when the % specs and the |c |r |T |t |H |h |n codes match.
--   * UPPER CASE: the settings show option and tab names through string.upper, so the upper-cased
--     English is matched too and our Ukrainian is upper-cased (Cyrillic letters by hand: Lua's upper
--     does not touch them).
--   * Joined texts: a settings description is description.."\n\n"..choice tooltip, so a text with
--     line breaks is translated by the longest runs of lines that are one L value each.
--   * Quest and book text (body): DialogueUI's paragraphs are the game's prose, on the same pooled
--     FontStrings as its sub-headers. There only a short text that is one L value as a whole, or a
--     format whose values are numbers or key pictures, changes: never a %s, never joined lines.
--   * What a %s may hold (a number, a time, one of DialogueUI's own texts, a name of the kind that key
--     takes): Slots.lua. Anything else there and the format does not fit, so a line is never half
--     translated.
-- Never translated (DialogueUI or the game reads them back, or they are names, keys or patterns): the
-- SKIP keys below and every key whose Ukrainian is false or the English.

local _, ns = ...
local U = UADD
local W = {}
ns.Words = W

local CYR = "[\208-\210]"
local index                -- UADD.TextIndex of our words, made by W.Build
local memo, memoBody, memoSize = {}, {}, 0
local count = 0
local dupes = {}          -- keys whose English an earlier key has with other Ukrainian (that one wins)
local MAX_BODY = 60

-- Item level lines: DialogueUI finds L["Item Level"] in a tooltip line and appends a delta to it.
-- Money symbols are single letters. The rest are matched against game text or are names.
local SKIP = { ["Item Level"] = true, ["Format Item Level"] = true, ["Symbol Gold"] = true,
    ["Symbol Silver"] = true, ["Symbol Copper"] = true, ["Gossip Quest Option Prepend"] = true,
    ["Quest Failed Pattern"] = true }
local SKIP_PREFIX = { "Pin ", "Match Stat ", "AutoCompleteQuest", "Abbrev Breakpoint", "Key ",
    "TTS Use Hotkey Tooltip", "Input Device Xbox", "Input Device PlayStation", "Input Device Switch" }
local KEEP = { ["Input Device Xbox Tooltip"] = true, ["Input Device PlayStation Tooltip"] = true,
    ["Input Device Switch Tooltip"] = true }

local function Skipped(key)
    if SKIP[key] then return true end
    if KEEP[key] then return false end
    for _, p in ipairs(SKIP_PREFIX) do
        if key:sub(1, #p) == p then return true end
    end
    return false
end

W.Upper = ns.Shape.Upper   -- upper case, Cyrillic too (Shape.lua)

-- ── Tokens ───────────────────────────────────────────────────────────────────────────────────

local SPEC = "%%[%-%+ #0]*%d*%.?%d*[sdif]"
local KEYM = "%[KEY:[%w:]+%]"

-- The next token from `pos`: "%%", a % spec or a [KEY:..]; returns start, end, kind.
local function NextToken(t, pos)
    local s1, e1 = t:find("%%%%", pos)
    local s2, e2 = t:find(SPEC, pos)
    local s3, e3 = t:find(KEYM, pos)
    local best, be, kind
    for _, c in ipairs({ { s1, e1, "pct" }, { s2, e2, "spec" }, { s3, e3, "key" } }) do
        if c[1] and (not best or c[1] < best) then best, be, kind = c[1], c[2], c[3] end
    end
    return best, be, kind
end

local function Tokens(t)
    local out, pos = {}, 1
    while true do
        local s, e, kind = NextToken(t, pos)
        if not s then out[#out + 1] = { "lit", t:sub(pos) } break end
        if s > pos then out[#out + 1] = { "lit", t:sub(pos, s - 1) } end
        out[#out + 1] = { kind, t:sub(s, e) }
        pos = e + 1
    end
    return out
end

local function Codes(t)
    t = t:gsub(KEYM, "")
    local c = {}
    for _, code in ipairs({ "|c", "|r", "|T", "|t", "|H", "|h", "|n" }) do
        local _, n = t:gsub(code:gsub("|", "%%|"), "")
        c[#c + 1] = n
    end
    return table.concat(c, ",")
end

local function SpecList(toks)
    local s = {}
    for _, tk in ipairs(toks) do if tk[1] == "spec" then s[#s + 1] = tk[2]:sub(-1) end end
    return table.concat(s)
end

-- ── DialogueUI's English as hashes ───────────────────────────────────────────────────────────

local function KeyOf(s) return #s .. ":" .. U.Hash(s) end

-- A template's English side: each literal piece's length and hash, what each slot holds, which slot
-- each [KEY:..] is (by the markup's hash), the % spec letters and | codes (the fit check) and how many
-- literal bytes it has. nil without a slot.
local KIND = { s = "s", d = "d", i = "d", f = "f" }
local function Pieces(en)
    local toks = Tokens(en)
    local len, hash, kinds, keys, piece, lit = {}, {}, {}, {}, "", 0
    local function Close() len[#len + 1], hash[#hash + 1], piece = #piece, U.Hash(piece), "" end
    for _, tk in ipairs(toks) do
        if tk[1] == "lit" then piece, lit = piece .. tk[2], lit + #tk[2]
        elseif tk[1] == "pct" then piece = piece .. "%"
        else
            Close()
            if tk[1] == "key" then
                kinds[#kinds + 1] = "t"
                local h = U.Hash(tk[2])
                keys[h] = keys[h] or #kinds
            else
                kinds[#kinds + 1] = KIND[tk[2]:sub(-1)]
            end
        end
    end
    if #kinds == 0 then return nil end
    Close()
    return { len = len, hash = hash, kinds = kinds, keys = next(keys) and keys or nil, sp = SpecList(toks),
        c = Codes(en), lit = lit }
end

-- What ui/hashes.lua keeps of an English text: e the whole text; x shown as it is (no % value), then
-- p with "%%" shown as "%" and u upper-cased; t its template. tools/make_dui_data.py makes the same.
function W.Shape(en)
    if type(en) ~= "string" or en == "" then return nil end
    local s = { e = KeyOf(en) }
    if not en:gsub("%%%%", ""):find(SPEC) then
        s.x = true
        local shown, up = en:gsub("%%%%", "%%"), en:upper()
        if shown ~= en then s.p = KeyOf(shown) end
        if up ~= en then s.u = KeyOf(up) end
    end
    if en:find("%", 1, true) or en:find("[KEY:", 1, true) then s.t = Pieces(en) end
    return s
end

-- The English side of a key: from the game's global when DialogueUI shows that one, else hashes.lua.
local function English(key)
    local s = ns.DUI_HASH and ns.DUI_HASH[key]
    if type(s) ~= "table" then return nil end
    local g = s.g and rawget(_G, s.g)
    if type(g) == "string" then return W.Shape(g) end
    return s
end

-- A TextIndex template: the English side `st` with our Ukrainian `uk` as pieces, or nil when they do
-- not fit (other % specs or | codes, a [KEY:..] the English lacks, or under 3 literal bytes).
local function Template(key, st, uk)
    if not st or st.lit < 3 then return nil end
    local ut = Tokens(uk)
    if SpecList(ut) ~= st.sp or Codes(uk) ~= st.c then return nil end
    local order = {}           -- the k-th % spec of the English is slot order[k]
    for i, kind in ipairs(st.kinds) do if kind ~= "t" then order[#order + 1] = i end end
    local parts, k = {}, 0
    local function Put(x)
        if type(x) == "string" and type(parts[#parts]) == "string" then parts[#parts] = parts[#parts] .. x
        elseif x ~= "" then parts[#parts + 1] = x end
    end
    for _, tk in ipairs(ut) do
        if tk[1] == "lit" then Put(tk[2])
        elseif tk[1] == "pct" then Put("%")
        elseif tk[1] == "key" then
            local slot = st.keys and st.keys[U.Hash(tk[2])]
            if not slot then return nil end
            Put(slot)
        else
            k = k + 1
            Put(order[k])
        end
    end
    return { id = key, len = st.len, hash = st.hash, kinds = st.kinds, uk = parts }
end

-- ── The index ────────────────────────────────────────────────────────────────────────────────

function W.Build()
    wipe(memo) wipe(memoBody) wipe(dupes) ns.Slots.Reset()
    memoSize, count = 0, 0
    local UA = ns.UA or {}
    local keys = {}
    for key in pairs(UA) do keys[#keys + 1] = key end
    table.sort(keys)
    local exact, upper, templates = {}, {}, {}
    for _, key in ipairs(keys) do
        local uk, s = UA[key], English(key)
        if s and type(uk) == "string" and uk ~= "" and not Skipped(key) and KeyOf(uk) ~= s.e then
            count = count + 1
            templates[#templates + 1] = Template(key, s.t, uk)
            if s.x then
                if exact[s.e] == nil then exact[s.e] = uk
                elseif exact[s.e] ~= uk then dupes[#dupes + 1] = key end
                if s.p and exact[s.p] == nil then exact[s.p] = uk end
                if s.u and upper[s.u] == nil then upper[s.u] = W.Upper(uk) end
            end
        end
    end
    for k, uk in pairs(upper) do                 -- a text that is some key's English as it is wins
        if exact[k] == nil then exact[k] = uk end
    end
    index = U.TextIndex({ exact = exact, templates = templates })
    if #dupes > 0 and U.debug then               -- once per build, for us only
        print(("UADD DialogueUI: %d English texts have other Ukrainian under a second key: %s"):format(#dupes,
            table.concat(dupes, ", ", 1, math.min(#dupes, 5))))
    end
end

local One
local SlotFill = ns.Slots.Filler(function(t) return One(t) end)
local function Filler(k, v, d)      -- a %s kept as it is: one name or a value, else no fit (Shape.lua)
    local r = SlotFill(k, v, d)
    if r == nil and d.kinds[k] == "s" and type(v) == "string" and not ns.Shape.OneName(v) then return false end
    return r
end
local function BodyFit(k, _, d) if d.kinds[k] == "s" then return false end end

-- One text that is a single L value (or one in colour) in Ukrainian, or nil. `body`: quest text.
One = function(t, body)
    if body and (#t > MAX_BODY or t:find("\n", 1, true)) then return nil end
    local uk = index:Exact(t)
    if uk then return uk end
    if #t > 600 then return nil end
    uk = index:Text(t, body and BodyFit or Filler)
    if uk then return uk end
    local code, inner = t:match("^(|c%x%x%x%x%x%x%x%x)(.-)|r$")
    if code and not inner:find("|r", 1, true) then
        uk = One(inner, body)
        if uk then return code .. uk .. "|r" end
    end
    return nil
end

-- Lines joined with "\n": the longest runs of lines that are one L value each. A line with English words
-- that is in no such run keeps the whole text English (never a half text: CLAUDE.md "No half translations").
local function Joined(t)
    local lines = {}
    for line in (t .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = line end
    if #lines > 30 then return nil end
    local out, any, i = {}, false, 1
    while i <= #lines do
        local done = false
        for j = #lines, i, -1 do
            local piece = table.concat(lines, "\n", i, j)
            local uk = piece ~= "" and One(piece)
            if uk then
                out[#out + 1], any, i, done = uk, true, j + 1, true
                break
            end
        end
        if not done then
            if ns.Shape.HasWords(lines[i]) then return nil end
            out[#out + 1] = lines[i]
            i = i + 1
        end
    end
    return any and table.concat(out, "\n") or nil
end

-- A text DialogueUI showed, in Ukrainian, or nil when nothing in it is an L value. `body`: it is on
-- a quest or book page (Screen.IsBody). Texts with Ukrainian letters (DialogueUI - UALL's names and
-- titles) are never touched.
function W.Text(t, body)
    if not index or type(t) ~= "string" or t == "" or t:find(CYR) then return nil end
    local m = body and memoBody or memo
    local hit = m[t]
    if hit ~= nil then return hit or nil end
    local S = ns.Slots
    hit = S.Soon(t, body)
    if hit ~= nil then return hit or nil end
    S.Begin()
    local uk = One(t, body) or (not body and t:find("\n", 1, true) and Joined(t)) or nil
    if S.unsure then S.Keep(t, body, uk) return uk end
    if memoSize > 2000 then wipe(memo) wipe(memoBody) memoSize = 0 end
    m[t], memoSize = uk or false, memoSize + 1
    return uk
end

-- For the status line: how many L values we can show in Ukrainian.
function W.Count() return count end

-- For the checks: keys whose English an earlier key already has, with other Ukrainian.
function W.Dupes() return dupes end
