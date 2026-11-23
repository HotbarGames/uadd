-- The words on OpenMap's windows, in Ukrainian, for texts L (Locale.lua) does not reach.
--   * OpenMap reads some texts once, while its files load (tab names, key bindings, ...), and
--     sets others before we ran. So each text OpenMap sets is also swapped right after it is set:
--     SetText on its FontString (and on its Buttons, whose SetText does not go through the
--     FontString) is hooked once (hooksecurefunc), and the hook puts our words in.
--   * The English text is kept per FontString, so the hold key and "/uadd openmap off" put it
--     back. A text OpenMap took from L is already ours: its English is read back from the same
--     word list, or, for a text two keys share, from the key L last gave (Locale.lua).
--   * A text is read line by line. A line is a word from ui/locale.lua, or built around a name:
--     dungeon and boss names come from the names other modules already saved (UADD.CachedName).
--     A name nobody saved stays English; so does any text we do not know, and any line that
--     already has Ukrainian letters (a Questie title, say).

local _, ns = ...
local U = UADD
local W = {}
ns.Words = W

local G = U.Glossary and U.Glossary.Text or function() return nil end
local Lc, P = ns.Locale, ns.Parts
local CYR = "[\208\209]"
local C = "|c%x%x%x%x%x%x%x%x"
local JOIN = { To = true }   -- OpenMap's words it puts right before a zone name ("To Orgrimmar")
local Pieces = P.Pieces
W.Dungeon = P.Dungeon

local orig = {}       -- FontString -> the English text OpenMap set
local mine = {}       -- FontString -> the text we put in its place
local hooked = {}     -- FontString or Button -> true once its SetText is hooked
local stale = {}      -- FontString -> true: hidden at the last Sync, put right when it shows (W.Flush)
local guard = false   -- up while we set a text ourselves

-- Finished texts: English -> Ukrainian, or false for "nothing to change"; `built`: lines OpenMap
-- built from L (P.Built). They hold while the word lists (Lc.gen) and the saved name tables are the
-- same tables: the modules that save names put in a new table each time, so a new name means a new
-- table here, and the memo starts again.
local memo, memoSize, built, builtSize, stamp, slot, changed = {}, 0, {}, 0, {}, 0, false
local OWNERS = { "dj", "questie" }

local function Same(v)
    slot = slot + 1
    if stamp[slot] ~= v then stamp[slot], changed = v, true end
end

local function Fresh()
    local m = type(UADD_DB) == "table" and type(UADD_DB.modules) == "table" and UADD_DB.modules or nil
    slot, changed = 0, false
    Same(Lc.gen or 0)
    for _, key in ipairs(OWNERS) do
        local mod = m and m[key]
        local c = type(mod) == "table" and mod.cache or nil
        Same(mod or false) Same(c or false)
        Same(type(c) == "table" and c.zones or false) Same(type(c) == "table" and c.Npc or false)
    end
    if changed then wipe(memo) wipe(built) memoSize, builtSize = 0, 0 end
end

-- A line OpenMap built from L and its own parts, whole Ukrainian (maybe as it is), or nil.
local function Built(t)
    Fresh()
    local b = built[t]
    if b == nil then
        if builtSize > 2000 then wipe(built) builtSize = 0 end
        b = P.Built(t) or false
        built[t], builtSize = b, builtSize + 1
    end
    return b or nil
end

-- One line in Ukrainian, or nil when nothing in it is ours to change. All or nothing: a line that
-- would keep English other than a value or a free name stays English.
local Line
Line = function(t)
    if t == "" then return nil end
    if t:find(CYR) then   -- built by OpenMap from our words in L and its own parts ("Level", a zone)
        local b = Built(t)
        return b ~= t and b or nil
    end
    local w = Lc.entries[t]
    if w then return w end
    local lead, body, trail = t:match("^(%s*)(.-)(%s*)$")
    if body == "" then return nil end
    if lead ~= "" or trail ~= "" then
        local b = Line(body)
        return b and (lead .. b .. trail) or nil
    end
    local d = W.Dungeon(t)
    if d then return d end
    local num, boss = t:match("^(" .. C .. "%d+%.|r%s+)(.+)$")
    if num then
        local uk = U.CachedName("Npc", boss)
        return uk and (num .. uk) or nil
    end
    local rest = t:match("^Level (.+)$")
    local lv = rest and G"game.level" and (Line(rest) or Lc.IsValue(rest) and rest)  -- else English, not half
    if lv then return G"game.level" .. " " .. lv end
    local f = Lc.Forward(t, W.Dungeon)                -- "Floor %d", "Back to %s", "Map by %s", ...
    if f then return f end
    local word, place = t:match("^(%a+) (.+)$")
    d = JOIN[word] and Lc.entries[word] and W.Dungeon(place)
    if d then return Lc.entries[word] .. " " .. d end
    local name, tail = t:match("^(.-)(  .+)$")            -- a dungeon and its levels (maybe in colour)
    d = name and Lc.IsValue(tail) and W.Dungeon(name)
    if d then return d .. tail end
    if t:find(", ", 1, true) then                       -- the card's title: "Name, Name", all of them ours
        local parts = {}
        for part in (t .. ", "):gmatch("(.-), ") do
            local uk = Line(part)
            if not uk then parts = nil break end
            parts[#parts + 1] = uk
        end
        if parts then return table.concat(parts, ", ") end
    end
    if t:find(P.DOT, 1, true) then                     -- L's words around a zone ("New note · Orgrimmar")
        local b = Built(t)
        if b and b ~= t then return b end
    end
    if not t:find("|c", 1, true) then return nil end
    local pieces, any = Pieces(t), false                -- colour pieces: each ours or a value
    if not pieces or #pieces == 1 and not pieces[1]:find("^" .. C) then return nil end
    local note = {}   -- the player's note: kept as written
    for i in ipairs(pieces) do note[i] = P.Note(pieces, i) end
    for i, p in ipairs(pieces) do
        local code, inner = p:match("^(" .. C .. ")(.*)|r$")
        local uk = not note[i] and Line(code and inner or p)
        if note[i] then
        elseif uk then
            pieces[i], any = code and (code .. uk .. "|r") or uk, true
        elseif not (Lc.IsValue(p) or P.Free(code and inner or p)) then
            return nil
        end
    end
    return any and table.concat(pieces) or nil
end
W.Line = Line
P.Line = Line

-- One line of ours back in English, or nil: a word, a formatted text, or in colour pieces.
local function Back(t)
    local en = Lc.English(t)
    if en then return en end
    local lead, body, trail = t:match("^(%s*)(.-)(%s*)$")
    if (lead ~= "" or trail ~= "") and body ~= "" then
        en = Back(body)
        return en and (lead .. en .. trail) or nil
    end
    local pieces, any = t:find("|c", 1, true) and Pieces(t), false
    if not pieces or #pieces == 1 and not pieces[1]:find("^" .. C) then return P.English(t) end
    local note = {}   -- the player's note: as written, on or off
    for i in ipairs(pieces) do note[i] = P.Note(pieces, i) end
    for i, p in ipairs(pieces) do
        local code, inner = p:match("^(" .. C .. ")(.*)|r$")
        local e = not note[i] and Back(code and inner or p)
        if e then
            pieces[i] = code and (code .. e .. "|r") or e
            any = true
        end
    end
    local out = any and table.concat(pieces) or nil
    if out and not out:find(CYR) then return out end
    return P.English(t) or out   -- a line OpenMap built: "Мітка · Orgrimmar  ...  Поділився: Thrall"
end

-- A text OpenMap took from L (our Ukrainian) in English, or nil when no line of it is ours.
function W.English(text)
    if type(text) ~= "string" or not text:find(CYR) then return nil end
    local out, any = {}, false
    for line in (text .. "\n"):gmatch("(.-)\n") do
        local en = line:find(CYR) and Back(line)
        any = any or en ~= nil and en ~= false
        out[#out + 1] = en or line
    end
    return any and table.concat(out, "\n") or nil
end

-- A whole text (lines joined with "\n") in Ukrainian, or nil when nothing in it changes.
function W.Text(text)
    if type(text) ~= "string" or text == "" then return nil end
    Fresh()
    local known = memo[text]
    if known ~= nil then return known or nil end
    local out, any = {}, false
    for line in (text .. "\n"):gmatch("(.-)\n") do
        local uk = Line(line)
        any = any or uk ~= nil
        out[#out + 1] = uk or line
    end
    local uk = any and table.concat(out, "\n") or nil
    if memoSize > 2000 then wipe(memo) memoSize = 0 end
    memo[text], memoSize = uk or false, memoSize + 1
    return uk
end

local function Put(fs, text)
    guard = true
    local ok, err = pcall(fs.SetText, fs, text)
    guard = false
    if not ok then error(err, 0) end
end

-- The English this FontString had, when our words for it are exactly what it shows now: kept per
-- FontString, so a Ukrainian text two keys share ("Підземелля") goes back to the right one.
local function Kept(fs, now)
    local en = orig[fs]
    if en and en ~= now and type(now) == "string" and now:find(CYR) and W.Text(en) == now then return en end
end

-- Every line with Ukrainian in it is whole as it is (a text from L, maybe with a version or a free
-- name), not one OpenMap built from L and its own English ("Level 24-33 Рейд", "Куди: Orgrimmar"),
-- and no English line is one we have words for (the card's boss under L's "Боси").
local function Whole(text)
    for line in (text .. "\n"):gmatch("(.-)\n") do
        if line:find(CYR) then
            if Built(line) ~= line then return false end
        elseif Line(line) then
            return false
        end
    end
    return true
end
W.Whole = Whole

-- One FontString as it should be now: our words while they are wanted, OpenMap's otherwise.
-- `fresh`: OpenMap has just set its text (the SetText hook), so the key it read from L is known.
function W.Apply(fs, fresh)
    stale[fs] = nil
    local now = UADD.Plain(fs:GetText())   -- nil for a secret text (combat): nothing of it is kept
    if mine[fs] == nil or now ~= mine[fs] then   -- OpenMap's own text (new, or set again)
        local en = not fresh and Kept(fs, now) or W.English(now)   -- from L: already our words
        orig[fs], mine[fs] = en or now, en and now or nil
    end
    if ns.WordsWanted() then   -- L's words when whole; else ours, or English when we have none
        local uk = mine[fs]
        if not (uk and Whole(uk)) then uk = W.Text(orig[fs]) or uk and orig[fs] end
        if uk and uk ~= now then Put(fs, uk) end
        if not uk and fresh then U.Missed("openmap", orig[fs], fs) end   -- English: noted (UADD/Missed.lua)
        mine[fs] = uk ~= orig[fs] and uk or nil
    elseif mine[fs] then
        if orig[fs] ~= now then Put(fs, orig[fs]) end
        mine[fs] = nil
    end
end

local function OnText(fs)
    if guard or type(fs) ~= "table" then return end
    mine[fs] = nil
    if not ns.On() or ns.Screen.WaitCombat() then return end   -- after combat, a look puts our words in
    U.SafeCall(W.Apply, fs, true)
    local t = UADD.Plain(fs:GetText())
    if type(t) == "string" and t:find(CYR) then U.SafeCall(ns.Fonts.Fix, fs) end   -- Ukrainian needs it
    ns.Screen.Schedule()
end

function W.Hook(fs)
    if hooked[fs] then return end
    hooked[fs] = true
    hooksecurefunc(fs, "SetText", OnText)
end

function W.HookButton(b)
    if hooked[b] then return end
    hooked[b] = true
    hooksecurefunc(b, "SetText", function(self) OnText(self:GetFontString()) end)
end

-- Every text we know, as it should be now (after the hold key, "on" or "off"). While the module is
-- on, a hidden one is left as it is and marked: W.Flush puts it right when its window shows.
function W.Sync()
    local all = not ns.On()
    for fs in pairs(orig) do
        if all or fs:IsVisible() then U.SafeCall(W.Apply, fs) else stale[fs] = true end
    end
end

-- The marked texts that show now, as they should be (Screen.lua, when a window shows).
function W.Flush()
    if next(stale) == nil then return end
    for fs in pairs(stale) do
        if fs:IsVisible() then U.SafeCall(W.Apply, fs) end
    end
end

-- For the checks: how many texts show our words now.
function W.Count()
    local n = 0
    for fs, t in pairs(mine) do if UADD.Plain(fs:GetText()) == t then n = n + 1 end end
    return n
end

-- For the checks: the English text OpenMap set on one FontString.
function W.Original(fs) return orig[fs] end
