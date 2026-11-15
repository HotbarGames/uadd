-- The parts of OpenMap's lines, for Words.lua and Tooltip.lua: names (dungeons, wings, zones),
-- colour pieces, and lines OpenMap builds from our words in L and its own parts.
--   * OpenMap joins L's words (ours, so Ukrainian) with a zone name the game gives in English
--     ("New note · Orgrimmar", "To Orgrimmar"), a version ("v0.8.9") or a player's own note.
--     P.Built makes such a line whole Ukrainian: each part is ours, a value, a name kept as it is
--     (an addon's, a version, the player's note) or a name other modules saved (UALL's zone names);
--     a part with no Ukrainian leaves the line as OpenMap built it.
--   * The player's own text (a pin's note, maybe another player's) is never changed, and reading a
--     line never backtracks over its words: the work is linear and capped (WORK).

local _, ns = ...
local U = UADD
local P = {}
ns.Parts = P

local G = U.Glossary and U.Glossary.Text or function() return nil end
local Lc = ns.Locale
local C = "|c%x%x%x%x%x%x%x%x"
local NAMES = { OpenMap = true, Questie = true, ["(Questie)"] = true }   -- addons' names, as they are
local NOTE = "|cffffffff"   -- after " · ": the player's own note on a pin (OpenMap's pin list)
local DOT = " \194\183 "   -- OpenMap's " · " (bytes: we only match it, never draw it)
P.DOT = DOT
local CYR = "[\208\209]"

-- A name kept as it is: an addon's, or a version ("v0.8.9", "1.2.3", "dev").
function P.Free(s)
    return NAMES[s] or s == "dev" or s:find("^v?%d+%.%d+[%.%w%-]*$") ~= nil
end

local function Wing(word)
    local e = U.Glossary and U.Glossary.entries and U.Glossary.entries["wing." .. word:lower()]
    return e and e.uk or nil
end

-- A dungeon, a wing ("Stratholme: Living", "Dire Maul - East") or a zone, or nil.
function P.Dungeon(en)
    if type(en) ~= "string" or en == "" then return nil end
    local uk = U.CachedName("zones", en)
    if uk then return uk end
    local base, wing = en:match("^(.-): (.+)$")
    if not base then base, wing = en:match("^(.-) %- (.+)$") end
    if not base then return nil end
    uk = U.CachedName("zones", base .. ": " .. wing)
    if uk then return uk end
    local b, w = U.CachedName("zones", base), Wing(wing) or U.CachedName("zones", wing)
    return b and w and (b .. ": " .. w) or nil
end

-- Text pieces at the top: colour blocks (|c........ ... |r, which may hold more blocks) and the
-- plain runs between them; nil when a |r closes nothing or a block is left open. "||" is a "|".
function P.Pieces(t)
    local out, pos, start, depth = {}, 1, 1, 0
    while true do
        local s = t:find("|", pos, true)
        if not s then break end
        local k = t:sub(s + 1, s + 1)
        if k == "r" then
            if depth == 0 then return nil end
            depth, pos = depth - 1, s + 2
            if depth == 0 then out[#out + 1], start = t:sub(start, s + 1), s + 2 end
        elseif k == "c" and t:find("^" .. C, s) then
            if depth == 0 and s > start then out[#out + 1] = t:sub(start, s - 1) end
            if depth == 0 then start = s end
            depth, pos = depth + 1, s + 10
        else
            pos = s + 2   -- "||", "|T...|t" and the like stay in the text as they are
        end
    end
    if depth > 0 then return nil end
    if start <= #t then out[#out + 1] = t:sub(start) end
    return out
end

-- One word or name that is whole as it is or has Ukrainian: a value, a kept name, "Level", a place.
local function Atom(s)
    if Lc.IsValue(s) or P.Free(s) then return s end
    if s == "Level" then return G"game.level" end
    return P.Dungeon(s)
end

-- The work one line may take: parts looked at, at most. A line can come from another player (a
-- shared pin's note, 160 bytes), so it must never cost more than this; past it, it stays as it is.
local WORK, work, depth = 200, 0, 0
local function Spent()
    work = work + 1
    return work > WORK
end

-- L's own word, English or Ukrainian, as `uk` wants it (Ukrainian), or nil: "Куди:", "Note".
local function Word(s, uk)
    if uk then return Lc.entries[s] or ((Lc.Ours(s) or Lc.English(s)) and s) or nil end
    return Lc.English(s)
end

-- The first words of `body` (1 to 4) that `ok` takes, and the rest; nil when none does. Only the
-- shortest is tried, never another after it: the work stays linear in the words.
local function Head(body, ok)
    local n = 0
    for i in body:gmatch("() ") do
        n = n + 1
        if n > 4 then return nil end
        local l = ok(body:sub(1, i - 1))
        if l then return l, body:sub(i + 1) end
    end
end

-- A part between " · " and wide gaps, whole Ukrainian, or nil.
local Seg
Seg = function(s)
    if Spent() then return nil end
    local lead, body, trail = s:match("^(%s*)(.-)(%s*)$")
    if body == "" then return s end
    local a = Atom(body) or Lc.Ours(body) and body   -- ours as it is ("Підземелля", two keys share it)
    if not a then
        local en = Lc.English(body)   -- one of L's texts, a free slot filled ("Поділився: Thrall")
        a = en and P.Line(en) or not body:find(CYR) and P.Line(body)   -- or English ("Shared by Thrall")
    end
    local inner = not a and body:match("^%((.+)%)$")   -- "(drawing)"
    if inner then
        a = Seg(inner)
        a = a and ("(" .. a .. ")")
    end
    if not a then   -- one of L's words (or a name) and the rest: "Куди: Orgrimmar", "Note #3"
        local l, rest = Head(body, function(w) return Atom(w) or Word(w, true) end)
        local r = l and Seg(rest)
        a = r and (l .. " " .. r)
    end
    return a and (lead .. a .. trail) or nil
end

-- A part back in English: L's words (or one of its texts, a slot filled) around English as it is.
local SegEn
SegEn = function(s)
    if not s:find(CYR) then return s end
    if Spent() then return nil end
    local lead, body, trail = s:match("^(%s*)(.-)(%s*)$")
    local a = Lc.English(body)
    local inner = not a and body:match("^%((.+)%)$")   -- "(малюнок)"
    if inner then
        a = SegEn(inner)
        a = a and ("(" .. a .. ")")
    end
    if not a then   -- "Нотатка #3"
        local l, rest = Head(body, Word)
        local r = l and SegEn(rest)
        a = r and (l .. " " .. r)
    end
    return a and (lead .. a .. trail) or nil
end

-- A plain run, each part through `seg`, the gaps kept.
local function Run(p, seg)
    local out, pos = {}, 1
    while pos <= #p do
        local s, e = p:find(DOT, pos, true)
        local s2, e2 = p:find("%s%s+", pos)
        if s2 and (not s or s2 < s) then s, e = s2, e2 end
        local part = seg(p:sub(pos, (s or #p + 1) - 1))
        if not part then return nil end
        out[#out + 1] = part .. (s and p:sub(s, e) or "")
        if not s then break end
        pos = e + 1
    end
    return table.concat(out)
end

-- true when piece i is the player's own note (white, right after " · "): kept as written, on or off.
function P.Note(pieces, i)
    return i > 1 and pieces[i]:sub(1, #NOTE) == NOTE and pieces[i - 1]:sub(-#DOT) == DOT
end

-- Each colour piece and plain run of a line through `seg`; the player's note kept as written.
local Walk
Walk = function(t, seg)
    local pieces = P.Pieces(t)
    if not pieces then return nil end
    for i, p in ipairs(pieces) do
        local code, inner = p:match("^(" .. C .. ")(.*)|r$")
        local out
        if P.Note(pieces, i) then
            out = p
        elseif code then
            out = Walk(inner, seg)
            out = out and (code .. out .. "|r")
        else
            out = Run(p, seg)
        end
        if not out then return nil end
        pieces[i] = out
    end
    return table.concat(pieces)
end

-- f(t), within WORK for the outermost call (Seg can reach P.Line, and that P.Built again).
local function Bounded(f, t)
    if depth == 0 then work = 0 end
    depth = depth + 1
    local ok, out = pcall(f, t)
    depth = depth - 1
    if not ok then error(out, 0) end
    return out
end

local function Whole(t)
    local en = Lc.English(t)   -- one of L's texts as it is (colour codes, names): ours, maybe filled
    return en and P.Line(en) or Walk(t, Seg)
end

-- A line OpenMap built from L and its own parts, whole Ukrainian (maybe the same text), or nil.
function P.Built(t) return Bounded(Whole, t) end

-- The same line back in English (the hold key, "/uadd openmap off"), or nil when nothing changes.
function P.English(t)
    local out = Bounded(function(s) return Walk(s, SegEn) end, t)
    return out ~= t and out or nil
end
