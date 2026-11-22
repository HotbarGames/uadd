-- UADD - DeleteCheapestItem Reloaded: our Ukrainian for one of its texts, found by the hash of its English (data/).
--
-- Its words live in a private table we cannot reach, so a text is swapped where it is drawn. A text is one of
-- its words, a format template (its slots found by shape in Slots.lua, never by words), or its words glued in
-- code with a few marks (a colour code, "* ", brackets, ": ", one space). The answer is a whole Ukrainian line,
-- or nil: the line stays as it came (no half lines).
--   * The game's globals it shows (the delete button, yes and no, the quest item mark) get the glossary's word
--     only while the global is still Latin (docs/LESSONS3.md, "Lesson 1 again"). The globals are never written.
--   * A piece that is already Cyrillic with no Latin letter (a name another addon translated) stays as it is.
-- No English of DeleteCheapestItem Reloaded is stored here: its texts are known by hash only.

local _, ns = ...
local U = UADD
local W = {}
ns.Words = W
local Sl = ns.Slots
local P = Sl.P
local Exact, Codes, InCode = P.Exact, P.Codes, P.InCode
local Numbers, N, Kept, Shapes = Sl.Numbers, Sl.N, Sl.Kept, Sl.Shapes
W.Exact = Exact

local find, sub, byte, match = string.find, string.sub, string.byte, string.match
local CYR = "[\208-\210]"
local MAXLEN = 600          -- longer texts are not its own
local MAXDEPTH = 5          -- nested pieces (a template in a template in brackets)
local MAXCUTS = 12          -- spaces tried per text
local GLOBALS = { DELETE = "ui.delete", YES = "ui.yes", NO = "ui.no", ITEM_BIND_QUEST = "item.quest" }

local Line, Part

-- The glossary's word for one of the game's globals it shows, while that global is Latin.
local function Global(s)
    for name, id in pairs(GLOBALS) do
        local g = rawget(_G, name)
        if g == s then
            if find(g, CYR) then return nil end
            local G = U.Glossary
            local uk = G and type(G.Text) == "function" and G.Text(id)
            if type(uk) == "string" and uk ~= "" and uk ~= s then return uk end
            return nil
        end
    end
    return nil
end
W.Global = Global

-- The last " (" of a text (outside codes), or nil.
local function LastOpen(s)
    local codes, at, i = Codes(s), nil, 1
    while true do
        local p = find(s, " (", i, true)
        if not p then break end
        if not InCode(codes, p, p + 1) then at = p end
        i = p + 1
    end
    return at
end

-- Colour codes that open and close in order (a link inside a colour wrap).
local function Balanced(s)
    local open, i = 0, 1
    while true do
        local p = find(s, "|[cr]", i)
        if not p then return open == 0 end
        if sub(s, p + 1, p + 1) == "c" then open = open + 1 else open = open - 1 end
        if open < 0 then return false end
        i = p + 2
    end
end

-- One line: itself, a global, its colour wrap, "* ", one group in brackets, its shape, a group in brackets at
-- its end, "word: rest", or two of our words glued with a space.
Line = function(s, d)
    d = (d or 0) + 1
    if d > MAXDEPTH or s == "" then return nil end
    local uk = Exact(s) or Global(s)
    if uk then return uk end
    if sub(s, 1, 2) == "|c" then
        local hex = match(s, "^|c(%x%x%x%x%x%x%x%x)")
        if hex then
            local body, tail = sub(s, 11), ""
            if sub(body, -2) == "|r" then body, tail = sub(body, 1, -3), "|r" end
            if body ~= "" and tail ~= "" and Balanced(body) or body ~= "" and not find(body, "|[cr]") then
                local i = Line(body, d)
                return i and "|c" .. hex .. i .. tail or nil
            end
        end
    end
    if sub(s, 1, 2) == "* " then
        local i = Line(sub(s, 3), d)
        return i and "* " .. i or nil
    end
    local last = byte(s, -1)
    if byte(s, 1) == 40 and last == 41 and not find(s, "(", 2, true) then
        local i = Part(sub(s, 2, -2), d)
        return i and "(" .. i .. ")" or nil
    end
    uk = Shapes(s, d)
    if uk then return uk end
    if last == 41 then
        local p = LastOpen(s)
        if p then
            local h = p - 1
            while h > 0 and byte(s, h) == 32 do h = h - 1 end
            if h > 0 then
                local a = Part(sub(s, 1, h), d)
                local b = a and Line(sub(s, p + 1), d)
                if a and b then return a .. sub(s, h + 1, p) .. b end
            end
        end
    end
    local c = find(s, ": ", 1, true)
    if c and c > 1 then
        local h = Exact(sub(s, 1, c - 1))
        local r = h and Part(sub(s, c + 2), d)
        if r then return h .. ": " .. r end
    end
    if #s <= 160 then
        local i, k = 1, 0
        while k < MAXCUTS do
            local p = find(s, " ", i, true)
            if not p then break end
            k = k + 1
            local a = p > 1 and Exact(sub(s, 1, p - 1))
            local b = a and (Exact(sub(s, p + 1)) or Global(sub(s, p + 1)))
            if a and b then return a .. " " .. b end
            i = p + 1
        end
    end
    return nil
end
Sl.Line = Line

-- A piece inside a line: ours, a link, a value, or already Cyrillic.
Part = function(x, d) return Line(x, d) or N(x) or Numbers(x) or Kept(x) end

W.Line = function(s) return Line(s, 0) end

-- Blocks glued with a blank line (a profile question and its note): each block alone.
local function Blocks(s)
    if not find(s, "\n\n", 1, true) then return Line(s, 0) end
    local out, i = {}, 1
    while true do
        local p = find(s, "\n\n", i, true)
        local part = sub(s, i, p and p - 1 or #s)
        local uk = part == "" and "" or Line(part, 0)
        if not uk then return nil end
        out[#out + 1] = uk
        if not p then break end
        i = p + 2
        if #out > 8 then return nil end
    end
    return table.concat(out, "\n\n")
end

-- ── Public ────────────────────────────────────────────────────────────────────────────────────

local cache, size = {}, 0

-- Our whole line, or nil; and whether a game-name route was asked (that answer is not kept: it may come later).
function W.Translate(s)
    s = U.Plain(s)
    if not s or s == "" or #s > MAXLEN or not find(s, "%a") then return nil, false end
    local hit = cache[s]
    if hit ~= nil then return hit or nil, false end
    P.asked = false
    local uk = Blocks(s)
    if uk == s or (uk and not find(uk, CYR)) then uk = nil end
    local asked = P.asked
    if not asked then
        if size >= 400 then cache, size = {}, 0 end
        cache[s], size = uk or false, size + 1
    end
    return uk, asked
end
function W.CacheSize() return size end
function W.Forget() cache, size = {}, 0 Sl.Forget() end

-- For the game's tooltip: is it the addon's now (its info button or its minimap button)? No lookup.
function W.Maybe() return ns.Screen ~= nil and ns.Screen.OwnsTip() end
