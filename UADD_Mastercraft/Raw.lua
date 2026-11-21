-- UADD - Mastercraft: its own words on the Crafters page's "raw" font strings (ns.RawText).
--
-- RawText is Mastercraft's string for text that stays as it is in every language (a player's name, a
-- recipe), so it has none of the mc* fields Screen.lua looks for. A few of them still show Mastercraft's
-- own words, built in its code: the profile card's line under the name (level, class, professions with
-- their skill) and its note line (our words around the player's own note, which stays as typed), and
-- the hub tiles' two lines when they are the tile's "nothing here" text, a count ("<n> available") or
-- "<player> can make <recipe> - online now". Raw.Look(frame) (from Screen.lua, for each frame it looks
-- at) finds these by their fields and gives them what Screen.lua wants:
--   * mcSetText / mcSetFont: the font string kind's own setters (not RawText's wrappers);
--   * mcRaw: set by a hook that runs before Screen.lua's, only for a text of the kinds above. Any other
--     text (a favourite's name, a recipe with its time) gets no mcRaw: Screen.lua leaves it as it is,
--     whatever it says, so a player named like one of Mastercraft's texts keeps the name (lesson 13).
--   * mcWords (the craft orders board and its cards, Mastercraft 2.0.8): a reader for a line that glues
--     our words to a player's name, a note or money. It knows the line's layout, so the name and the note
--     stay as they are and every other part must be ours, or the whole line stays English. Recipe names
--     on their own (a row's name, a card's item) are not marked: game names, as Mastercraft keeps them.

local _, ns = ...
local W = ns.Words
local R = {}
ns.Raw = R

local marked = setmetatable({}, { __mode = "k" })

local function Method(fs, name)
    local mt = getmetatable(fs)
    local t = type(mt) == "table" and mt.__index
    return type(t) == "table" and t[name] or nil
end

local function Always() return true end

local function Plain(s) return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

-- A tile line that is Mastercraft's own words: the tile's empty text (grey), a count, a watched recipe.
local function TileOwn(empty)
    local grey = "|cff8c8c8c" .. empty .. "|r"
    return function(text)
        if text == grey then return true end
        local p = Plain(text)
        return p:find("^%d+ %a") ~= nil or p:find(" %- online now$") ~= nil
    end
end

-- ── Readers for the orders board (mcWords): each returns (Ukrainian or nil, waited) ─────────────────

local wait = false                                  -- a game name had to wait for UALL Forever

local function Try(s)
    local uk, w = W.Try(s)
    if w then wait = true end
    return uk
end

-- One part: as it is when it has no English (money, a count, "-"); our words for it; or our words, then a
-- bare value ("<profession> 150", "<tip> <money>"). False when English would be left.
local function Piece(p)
    if p == "" or not W.HasLatin(p) then return p end
    local t = Try(p)
    if t then return t end
    -- a value is short (money is at most three coins): only the last few gaps are tried, left to right,
    -- so a long line costs a few looks, never one per gap (docs/LESSONS2.md lesson 22)
    local gaps, from = {}, 1
    while true do
        local a = p:find(" ", from, true)
        if not a then break end
        gaps[#gaps + 1] = a
        if #gaps > 4 then table.remove(gaps, 1) end
        from = a + 1
    end
    for _, a in ipairs(gaps) do
        local tail = p:sub(a)
        if not W.HasLatin(tail) then
            local head = p:sub(1, a - 1)
            t = head ~= "" and Try(head)
            return t and (t .. tail) or false
        end
    end
    return false
end

-- Parts joined by sep: every part, or false.
local function Pieces(s, sep)
    local out = {}
    for part in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do
        local t = Piece(part)
        if not t then return false end
        out[#out + 1] = t
    end
    return table.concat(out, sep)
end

-- "<label>: <rest>" at the first ": " (a plain find): the label has a letter, the rest is not empty.
local function Label(p)
    local a = p:find(": ", 1, true)
    if not a or a == 1 or a + 2 > #p then return end
    local label = p:sub(1, a - 1)
    if not label:find("%a") then return end
    return label, p:sub(a + 2)
end

-- "<label>: <who>": our label, the player's name as it is. A player's name is one word ("Name" or
-- "Name-Realm"): a gap, a line break or a quote in it means more text glued on (other parts, maybe English
-- we lack), so the line is not this layout and stays English (lesson 7).
local function Who(p)
    local label, who = Label(p)
    if not label or who:find('[%s"]') then return false end
    local t = Try(label)
    return t and (t .. ": " .. who) or false
end

-- "<label>: <what>": ours whole, or our label and every part of what (" + " joins a price and a tip).
local function Labelled(line)
    local t = Try(line)
    if t then return t end
    local label, rest = Label(line)
    local a = label and Try(label)
    local b = a and Pieces(rest, "  + ")
    return b and (a .. ": " .. b) or false
end

local function Done(uk, s)
    if uk and uk ~= s and s:find("%a") then return uk, wait end    -- (no letters: nothing of ours there)
    return nil, wait
end

-- A row's age: "<h>", "<min>" or both, on one line or two; each part is one of our texts.
local function Age(s)
    wait = false
    local a, gap, b = s:match("^(%d+ %a+)([ \n])(%d+ %a+)$")
    if not a then return Done(not s:find("\n", 1, true) and Try(s) or nil, s) end   -- one part, one line
    local x = Try(a)
    local y = x and Try(b)
    return Done(y and (x .. gap .. y), s)
end

-- Parts with a wide gap between them, then maybe the player's note in quotes (after the gap or on its
-- own line): the note as typed, every other part ours. first: how to read the first part.
local function Gapped(first)
    return function(s)
        wait = false
        local head, gap, note = s, "", ""
        local q = s:find('"', 1, true)              -- our parts and a name hold no quote: the note starts here
        if q then
            local h = s:sub(1, q - 1)
            gap = (h:sub(-1) == "\n" and "\n") or (h:sub(-3) == "   " and "   ") or nil
            if not gap or s:sub(-1) ~= '"' or #s == q then return nil, wait end
            head, note = h:sub(1, #h - #gap), s:sub(q)
        end
        local out = {}
        for part in (head .. "   "):gmatch("(.-)   ") do
            local t = (#out == 0 and first or Piece)(part)
            if not t then return nil, wait end
            out[#out + 1] = t
        end
        return Done(table.concat(out, "   ") .. gap .. note, s)
    end
end

-- The deal card: who (a name), the recipe and its count ("<recipe>  x<n>": a game name, its own line: as
-- it is), then lines of "<label>: <what>" (game names there, as the materials, come from UALL Forever or
-- ClassicUA through Words.lua, every one). All of them, or the whole card stays English: a card that is
-- not this layout (fewer lines, a recipe line without its count) stays English too.
local function Recipe(line)
    return line:find("%S  x%d+$") ~= nil and line
end

local function Deal(s)
    wait = false
    local out = {}
    for line in (s .. "\n"):gmatch("(.-)\n") do
        local n = #out + 1
        local t = (n == 1 and Who(line)) or (n == 2 and Recipe(line)) or (n > 2 and Labelled(line))
        if not t then return nil, wait end
        out[n] = t
    end
    if #out < 3 then return nil, wait end
    return Done(table.concat(out, "\n"), s)
end

R.Reader = { Piece = function(s) wait = false; return Done(Piece(s) or nil, s) end, Age = Age,
    Gapped = Gapped, Who = Who, Deal = Deal }

local function Mark(fs, own, words)
    if type(fs) ~= "table" or marked[fs] or rawget(fs, "mcSetText") ~= nil then return end
    if not (fs.GetObjectType and fs:GetObjectType() == "FontString") then return end
    local set, font = Method(fs, "SetText"), Method(fs, "SetFont")
    if type(set) ~= "function" or type(font) ~= "function" then return end
    marked[fs] = true
    rawset(fs, "mcSetText", set)
    rawset(fs, "mcSetFont", font)
    if words then rawset(fs, "mcWords", words) end
    local function Take(self, text)
        rawset(self, "mcRaw", (UADD.Plain(text) and own(text)) and text or nil)
    end
    Take(fs, fs:GetText())
    hooksecurefunc(fs, "SetText", Take)       -- before Screen.lua's hook, so it reads this mcRaw
    ns.Screen.Hook(fs)
end

function R.Look(f)
    if type(f) ~= "table" then return end
    local profs, note = rawget(f, "profs"), rawget(f, "note")
    if profs and note and rawget(f, "name") and rawget(f, "cls") then
        Mark(profs, Always)
        Mark(note, Always)
    end
    local l1, l2, empty = rawget(f, "l1"), rawget(f, "l2"), rawget(f, "emptyText")
    if l1 and l2 and type(empty) == "string" and rawget(f, "num") then
        local own = TileOwn(empty)
        Mark(l1, own)
        Mark(l2, own)
    end
    R.LookOrders(f)
end

local function Has(f, ...)
    for i = 1, select("#", ...) do
        if rawget(f, (select(i, ...))) == nil then return false end
    end
    return true
end

local OnePart, Gaps, Info = R.Reader.Piece, Gapped(), Gapped(Who)

-- The orders board and its cards (Orders.lua), found by their fields.
function R.LookOrders(f)
    if Has(f, "name", "sub", "qty", "mats", "tip", "buyer", "age", "btn") then        -- a board row
        Mark(f.sub, Always, OnePart)
        Mark(f.mats, Always)
        Mark(f.age, Always, Age)
        -- "you" on your own order; any other text there is the buyer's name, as it is
        local row = f
        Mark(f.buyer, function() return rawget(row, "mine") ~= nil end)
    end
    -- (a recipe found while posting is the recipe, then its profession and skill in one cell: the recipe is
    -- a game name Mastercraft keeps in English, so that cell is left as it is, never half Ukrainian)
    if Has(f, "selName", "selSub", "qtyText", "sugs") then Mark(f.selSub, Always, OnePart) end
    if Has(f, "item", "info", "price", "note", "send", "withdraw") then Mark(f.info, Always, Info) end
    if Has(f, "info", "rows", "none", "cancel") then Mark(f.info, Always, Gaps) end
    if Has(f, "bg", "name", "sub", "yes", "no") then Mark(f.sub, Always, Gaps) end      -- an offer on yours
    if Has(f, "body", "invite", "whisper", "done") then Mark(f.body, Always, Deal) end
end

function R.Count()
    local n = 0
    for _ in pairs(marked) do n = n + 1 end
    return n
end
