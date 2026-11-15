-- Auctionator's English texts -> our Ukrainian. The repo keeps none of Auctionator's English:
--   * ui/locale.lua: our Ukrainian by Auctionator's locale key (ns.UA). The English of a key is read
--     here from Auctionator's own AUCTIONATOR_L_<KEY> global (read only). ns.UA_MADE: texts it joins
--     in its code from those (their English is made here the same way).
--   * ui/text.lua (ns.UA_TEXT): the English it writes straight in its code (slash command help, chat
--     lines), by hash, found through UADD.TextIndex (UADD/Hash.lua). A text missing there stays English.
--   * Exact: a text as Auctionator shows it -> its Ukrainian.
--   * Template: a text with %s / %d becomes a pattern; what it captures goes into the Ukrainian in the
--     same order. A captured %s that is itself one of Auctionator's texts is translated too. Only when
--     the % slots and the |c |r |T |t |H |h |n codes of the two match.
--   * A text in one colour (|cff..text|r) is translated inside the colour.
--   * A date "Tuesday, February 25" becomes "Вівторок, 25 лютого" (Date below).
--   * Several texts joined by a blank line ("\n\n"), and a %s that is two texts ("X (Y pending)"):
--     Parts.lua translates each piece on its own.
-- Speed: the results tables set their cells many times a second while a scan runs, so
--   * a text with no letters (prices, "45%", counts) is skipped at once;
--   * every answer is kept (memo, wiped past MEMO_MAX); a miss tries the template that matched the
--     same FontString last time first (hint), then the rest, longest English first. A matching hint
--     still loses to a longer template that matches too (its rivals).
--   * In combat (W.Quick): the memo, the exact table and the hint only. W.Key: one key only.
-- Never translated: texts with Ukrainian letters, keys whose Ukrainian is the English, and NEVER below.

local _, ns = ...
local W = {}
ns.Words = W

local CYR = "[\208-\210]"
local exact, formats = {}, {}
local nlFormats = {}      -- the templates whose English has a line break (the only ones a text with one tries)
local byKey = {}          -- KEY -> { en = English, uk = Ukrainian } or { f = template }
local memo, memoSize = {}, 0
local hint = setmetatable({}, { __mode = "k" })   -- FontString -> the template it matched last
local count = 0
local MEMO_MAX, MAX_LEN, MAX_DEPTH = 3000, 600, 3
local lit = UADD.TextIndex({})   -- ui/text.lua's hashed texts (made in W.Build)
local P = ns.Patterns            -- Patterns.lua: a template -> its pattern

-- Texts Auctionator compares with what a widget shows: never ours.
--   EXTENDED_SEARCH_ACTIVE_TEXT: put in the search box and read back from it (SearchOptions.lua).
local NEVER = { EXTENDED_SEARCH_ACTIVE_TEXT = true }
-- The game's own words Auctionator puts on its buttons (ACCEPT, CANCEL, BACK ...): an exact text equal
-- to one of them stays English everywhere, Auctionator's own "Cancel" too (the two look the same).
local BLIZZARD = { "ACCEPT", "CANCEL", "BACK", "NOT_BOUND", "EMPTY" }
local blizzard = {}
local days, months = {}, {}   -- English weekday (DAY_1..7) / month (MONTH_1..12) -> our Ukrainian

local Text, Quick

local function Fill(f, caps, depth, quick)
    local out, k = {}, 0
    for _, tk in ipairs(f.uk) do
        if tk[1] == "lit" then out[#out + 1] = tk[2]
        elseif tk[1] == "pct" then out[#out + 1] = "%"
        else
            k = k + 1
            local c = caps[k]
            if f.kinds[k] == "s" and depth < MAX_DEPTH then
                f.slots[k] = f.slots[k] or {}             -- this slot's hint key
                local uk = (quick and Quick or Text)(c, f.slots[k], depth + 1)
                if uk == nil and not quick then uk = ns.Parts.Slot(c, depth + 1) end
                if uk == false then return nil end        -- English text with a line break: no match
                c = uk or c
            end
            out[#out + 1] = c
        end
    end
    return table.concat(out)
end

-- ── The tables ───────────────────────────────────────────────────────────────────────────────
-- One English text and its Ukrainian into the tables. key: Auctionator's locale key, or nil.
local function Add(en, uk, key)
    if type(en) ~= "string" or en == "" then return end
    local good = type(uk) == "string" and uk ~= "" and uk ~= en
    if P.IsTemplate(en) then
        local f = good and P.Build(en, uk) or nil
        if f then
            formats[#formats + 1], count = f, count + 1
            if key then byKey[key] = { f = f } end
        end
    elseif good and not blizzard[en] then
        if exact[en] == nil then exact[en], count = uk, count + 1 end
        if key then byKey[key] = { en = en, uk = uk } end
    end
end

-- Auctionator's English for a locale key, as it set it at load (its enUS texts on an English client).
local function EN(key)
    local v = rawget(_G, "AUCTIONATOR_L_" .. key)
    return type(v) == "string" and v or nil
end

-- The English of a ns.UA_MADE entry, made as Auctionator makes it, or nil when a piece is missing.
local function Made(m)
    if m.join then
        local a, b = EN(m.join[1]), EN(m.join[2])
        return a and b and (a .. " " .. b) or nil
    end
    local en = m.key and EN(m.key)
    return en and (en:gsub(m.from, m.to)) or nil
end

function W.Build()
    wipe(exact) wipe(formats) wipe(nlFormats) wipe(memo) wipe(byKey)
    wipe(blizzard)
    for _, name in ipairs(BLIZZARD) do
        local v = rawget(_G, name)
        if type(v) == "string" then blizzard[v] = true end
    end
    memoSize, count = 0, 0
    local UA = ns.UA or {}
    local keys = {}
    for key in pairs(UA) do keys[#keys + 1] = key end
    table.sort(keys)                            -- the same English under two keys: the first key wins
    for _, key in ipairs(keys) do
        local uk = UA[key]
        if type(uk) == "string" then uk = (uk:gsub("\\n", "\n")) end   -- a written \n is a break (as Auctionator's AddNewLines)
        if not NEVER[key] then Add(EN(key), uk, key) end
    end
    for _, m in ipairs(ns.UA_MADE or {}) do Add(Made(m), m.uk) end
    lit = UADD.TextIndex(ns.UA_TEXT)
    wipe(days) wipe(months)
    for _, d in ipairs({ { days, "DAY_", 7 }, { months, "MONTH_", 12 } }) do
        for i = 1, d[3] do
            local en, uk = EN(d[2] .. i), UA[d[2] .. i]
            if type(en) == "string" and type(uk) == "string" and uk ~= "" then d[1][en] = uk end
        end
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

-- Auctionator's dates (Utilities/PrettyDate.lua): weekday .. ", " .. month .. " " .. day, all three
-- from its own DAY_n / MONTH_n words. Ukrainian puts the day before the month: "Вівторок, 25 лютого"
-- (our months are in the "of" form). Only a whole text made of those words; nil for anything else.
local function Date(t)
    local d, m, n = t:match("^(%a+), (%a+) (%d%d?)$")
    if not d or not days[d] or not months[m] then return nil end
    return days[d] .. ", " .. n .. " " .. months[m]
end

-- A ui/text.lua text in Ukrainian, or nil. A template's %s that is itself one of Auctionator's texts
-- is translated too (as Fill does).
local function Hashed(t, depth)
    return lit:Text(t, function(k, v, d)
        if d.kinds[k] ~= "s" or depth >= MAX_DEPTH then return nil end
        local uk = Text(v, nil, depth + 1)
        if uk == nil then uk = ns.Parts.Slot(v, depth + 1) end
        return uk                                 -- false: English text with a line break, no match
    end)
end

-- One text in Ukrainian, or nil. `fs`: the FontString (or slot) it is for (its last template first).
local function One(t, fs, depth)
    local uk = exact[t] or lit:Exact(t) or Date(t)
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
    uk = Hashed(t, depth)
    if uk then return uk end
    local code, inner = t:match("^(|c%x%x%x%x%x%x%x%x)(.-)|r$")
    if code and not inner:find("|r", 1, true) then
        uk = One(inner, nil, depth)
        if uk then return code .. uk .. "|r" end
    end
    if nl then return ns.Parts.Joined(t, depth) end
    return nil
end

-- A text Auctionator showed, in Ukrainian, or nil when it is none of its texts.
-- A text with no letters ("1,234", "45%") returns at once and is not kept.
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

-- In combat: the memo, the exact table and the hint only (no search). Not kept: a %s inside may
-- have stayed English here that a search would translate.
Quick = function(t, fs, depth)
    if type(t) ~= "string" or not t:find("%a") then return nil end
    local hit = memo[t]
    if hit ~= nil then return hit or nil end
    local uk = exact[t] or lit:Exact(t)
    if uk then return uk end
    if not fs or #t > MAX_LEN or t:find(CYR) then return nil end
    return Hinted(t, fs, depth or 0, true)
end
W.Quick = Quick

-- `t` as the text of one locale key only (exact, or that key's template; its %s stays as it is),
-- or nil. Cheap: one lookup or one match. For tooltip lines, also in combat.
function W.Key(key, t)
    local k = byKey[key]
    if not k or type(t) ~= "string" then return nil end
    if k.f then
        local caps = { t:match(k.f.pat) }
        if caps[1] == nil then return nil end
        return Fill(k.f, caps, MAX_DEPTH)
    end
    return t == k.en and k.uk or nil
end

-- The English of one locale key (for the checks and Tooltip.lua).
function W.English(key) return EN(key) end

-- For the status line: how many texts we can show in Ukrainian.
function W.Count()
    local e, t = lit:Count()
    return count + e + t
end

-- For the checks: how many texts the memo holds.
function W.MemoSize() return memoSize end
