-- Texts made of several of Auctionator's texts, for Words.lua: each piece is translated on its own.
--   * Joined: texts joined by a blank line ("\n\n"), as its purchase dialogs show them:
--     a warning word, a sentence and the unit price line, each one of Auctionator's texts. Each piece
--     is translated as a whole text, else by a template. A piece may start with a colour code whose
--     |r is in a later piece (a red colour opened in the first piece and closed in a later one): the
--     codes stay where they are.
--   * Slot: a %s that is two texts, "1g (5g pending)": split at its first " (".
-- A piece we cannot translate may only be money, numbers or an item link (no letters of its own):
-- else the whole text stays English, never half English and half Ukrainian.
-- Only from Words.lua's search (never in combat); its memo keeps the answer, found or not.

local _, ns = ...
local P = {}
ns.Parts = P

local BREAK = "\n\n"
local CODE = "^|c%x%x%x%x%x%x%x%x"

-- True when `s` has no letters once its money icons (|T..|t), item links (|H..|h[name]|h) and
-- colour codes are taken out: a price, a count or an item.
local function Neutral(s)
    s = s:gsub("|T.-|t", ""):gsub("|H.-|h.-|h", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return not s:find("%a")
end
P.Neutral = Neutral

-- One piece in Ukrainian, or nil. A |r at its start and a colour code that is not closed in it are
-- kept as they are; the rest is translated.
local function Piece(s, depth)
    local lead = ""
    if s:sub(1, 2) == "|r" then lead, s = "|r", s:sub(3) end
    local code = s:match(CODE)
    if code and not s:find("|r", 1, true) then lead, s = lead .. code, s:sub(#code + 1) end
    local uk = ns.Words.Text(s, nil, depth)
    return uk and lead .. uk or nil
end

-- `t` (with a blank line in it) in Ukrainian, or nil.
function P.Joined(t, depth)
    if not t:find(BREAK, 1, true) then return nil end
    local out, any, pos = {}, false, 1
    while true do
        local s, e = t:find(BREAK, pos, true)
        local piece = t:sub(pos, s and s - 1 or -1)
        local uk = Piece(piece, depth)
        if uk then any = true
        elseif not Neutral(piece) then return nil end
        out[#out + 1] = uk or piece
        if not s then break end
        out[#out + 1] = BREAK
        pos = e + 1
    end
    return any and table.concat(out) or nil
end

-- A %s Words.lua found no text for: its Ukrainian as two texts, or nil (keep it as it is), or false
-- (a text with a line break that is not money or an item: the template must not match).
function P.Slot(c, depth)
    if c:find("\n", 1, true) then
        if Neutral(c) then return nil end
        return false
    end
    local i = c:find(" (", 1, true)
    if not i then return nil end
    local a, b = c:sub(1, i - 1), c:sub(i + 1)
    local ua, ub = ns.Words.Text(a, nil, depth), ns.Words.Text(b, nil, depth)
    if (ua or ub) and (ua or Neutral(a)) and (ub or Neutral(b)) then return (ua or a) .. " " .. (ub or b) end
    return nil
end
