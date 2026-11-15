-- Texts Attune builds from pieces, translated piece by piece. Words.lua calls this only when the whole
-- text is none of our texts, names or templates; its memo keeps the answer.
--   * Several lines: each line on its own (an empty line stays empty; a web address stays).
--   * Two texts glued with a blank line: each half on its own.
--   * Spaces, line breaks and colons around a text stay where they are; the text inside is translated.
--   * Colours: "|cffffd100Quest|r|c60808080 in Orgrimmar|r": each coloured part and each plain part.
--   * A count before the text: "3/5 Dark Iron Ore" (Attune's "count/needed item").
--   * A part in brackets at the end: "Raid quest (40-man) (ID 1234)".
--   * A phrase of known pieces: "Honored with" + "Argent Dawn", "Level" + "60" + "Elite" + "Dragonkin".
--     Every lettered piece must be one of our texts or names, else the whole text stays English.
-- A part with no letters (numbers, icons, "??"), or an attunement's short tag ("Ony"), is kept as it
-- is. Nothing is half translated: one unknown part and the answer is nil.

local _, ns = ...
local S = {}
ns.Shape = S

local MAX_DEPTH, MAX_WORDS, MAX_SPAN = 6, 14, 6

-- No letters once icons, links and colour codes are taken out.
local function Neutral(s)
    s = s:gsub("|T.-|t", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return not s:find("%a")
end
S.Neutral = Neutral

local Line

-- One piece of a phrase: our text or a name, or the same with a colon after it ("Requires:").
local function Piece(w)
    local uk = ns.Words.Exact(w)
    if uk then return uk end
    local head = w:match("^(.-):$")
    uk = head and head ~= "" and ns.Words.Exact(head)
    return uk and (uk .. ":") or nil
end

-- Words split on single spaces (two spaces in a row give an empty word, kept as it is).
local function Split(s)
    local words, pos = {}, 1
    while true do
        local e = s:find(" ", pos, true)
        if not e then words[#words + 1] = s:sub(pos) break end
        words[#words + 1] = s:sub(pos, e - 1)
        pos = e + 1
    end
    return words
end

-- Known pieces one after the other, the longest piece first. At least one piece must have letters.
local function Phrase(s)
    if #s > 120 then return nil end
    local w = Split(s)
    if #w < 2 or #w > MAX_WORDS then return nil end
    local out, i, any = {}, 1, false
    while i <= #w do
        local hit, last
        for j = math.min(#w, i + MAX_SPAN - 1), i, -1 do
            local uk = Piece(table.concat(w, " ", i, j))
            if uk then hit, last = uk, j break end
        end
        if hit then
            any = true
        elseif Neutral(w[i]) then
            hit, last = w[i], i
        else
            return nil
        end
        out[#out + 1] = hit
        i = last + 1
    end
    return any and table.concat(out, " ") or nil
end

-- Plain and coloured parts of a line, each translated; nil when one lettered part is unknown.
local function Colours(s, depth)
    local out, pos = {}, 1
    local function Part(p)
        if p == "" or Neutral(p) or ns.Words.Tag(p) then return p end
        return Line(p, depth + 1)
    end
    while pos <= #s do
        local cs, ce = s:find("|c%x%x%x%x%x%x%x%x", pos)
        if not cs then
            local uk = Part(s:sub(pos))
            if not uk then return nil end
            out[#out + 1] = uk
            break
        end
        local before = Part(s:sub(pos, cs - 1))
        if not before then return nil end
        local rs, re = s:find("|r", ce + 1, true)
        local inner = s:sub(ce + 1, (rs or #s + 1) - 1)
        local uk = Part(inner)
        if not uk then return nil end
        out[#out + 1] = before .. s:sub(cs, ce) .. uk .. (rs and "|r" or "")
        pos = (re or #s) + 1
    end
    return table.concat(out)
end

-- One line (no line break) in Ukrainian, or nil.
Line = function(s, depth)
    if depth > MAX_DEPTH then return nil end
    local uk = ns.Words.Exact(s)
    if uk then return uk end
    local lead, core, trail = s:match("^([%s:]*)(.-)([%s:]*)$")
    if lead ~= "" or trail ~= "" then
        if core == "" then return nil end
        uk = ns.Words.Exact(core) or Line(core, depth + 1)
        return uk and (lead .. uk .. trail) or nil
    end
    if s:find("|c", 1, true) then return Colours(s, depth) end
    local count, rest = s:match("^(%d+/%d+ )(.+)$")
    if count then
        uk = Line(rest, depth + 1)
        return uk and (count .. uk) or nil
    end
    local head, inner = s:match("^(.-) %((.-)%)$")
    if head and head ~= "" then
        local a = Line(head, depth + 1)
        local b = (Neutral(inner) or inner:match("^ID %d+$")) and inner or Line(inner, depth + 1)
        return a and b and (a .. " (" .. b .. ")") or nil
    end
    return Phrase(s)
end

-- A whole text in Ukrainian, or nil. depth: how deep Words.lua already is.
function S.Text(t, depth)
    if type(t) ~= "string" or depth > MAX_DEPTH then return nil end
    if not t:find("\n", 1, true) then return Line(t, depth) end
    -- Two texts glued with a blank line, the first with its own line breaks ("...from:\n\n##PLAYER##"
    -- .. "\n\n" .. "Could be slow"): the first split where both halves are known.
    local at = 1
    while true do
        local s, e = t:find("\n\n", at, true)
        if not s then break end
        local a = s > 1 and ns.Words.One(t:sub(1, s - 1), depth + 1)
        local b = a and e < #t and ns.Words.One(t:sub(e + 1), depth + 1)
        if a and b then return a .. "\n\n" .. b end
        at = e + 1
    end
    local out, pos = {}, 1
    while true do
        local e = t:find("\n", pos, true)
        local line = t:sub(pos, (e or #t + 1) - 1)
        if line ~= "" and not Neutral(line) and not line:find("^%a+://%S+$") then   -- a web address stays
            line = ns.Words.One(line, depth + 1)
            if not line then return nil end
        end
        out[#out + 1] = line
        if not e then break end
        pos = e + 1
    end
    return table.concat(out, "\n")
end
