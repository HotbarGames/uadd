-- The words on OpenMap's windows, in Ukrainian, for texts L (Locale.lua) does not reach.
--   * OpenMap reads some texts once, while its files load (tab names, Credits lines, ...), and
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
local Lc = ns.Locale
local CYR = "[\208\209]"
local C = "|c%x%x%x%x%x%x%x%x"

local orig = {}       -- FontString -> the English text OpenMap set
local mine = {}       -- FontString -> the text we put in its place
local hooked = {}     -- FontString or Button -> true once its SetText is hooked
local stale = {}      -- FontString -> true: hidden at the last Sync, put right when it shows (W.Flush)
local guard = false   -- up while we set a text ourselves

local function Wing(word)
    local e = U.Glossary and U.Glossary.entries and U.Glossary.entries["wing." .. word:lower()]
    return e and e.uk or nil
end

-- A dungeon, a wing ("Stratholme: Living", "Dire Maul - East") or a zone, or nil.
function W.Dungeon(en)
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

-- Text pieces: colour blocks (|c........ ... |r) and the plain runs between them.
local function Pieces(t)
    local out, pos = {}, 1
    while pos <= #t do
        local s, e = t:find(C .. ".-|r", pos)
        if not s then out[#out + 1] = t:sub(pos) break end
        if s > pos then out[#out + 1] = t:sub(pos, s - 1) end
        out[#out + 1] = t:sub(s, e)
        pos = e + 1
    end
    return out
end

-- One line in Ukrainian, or nil when nothing in it is ours to change.
local Line
Line = function(t)
    if t == "" or t:find(CYR) then return nil end
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
    if rest and G"game.level" then return G"game.level" .. " " .. (Line(rest) or rest) end
    local f = Lc.Forward(t, W.Dungeon)                -- "Floor %d", "Back to %s", "Map by %s", ...
    if f then return f end
    local name, range = t:match("^(.-)(  %d+%-%d+)$")
    if name and W.Dungeon(name) then return W.Dungeon(name) .. range end
    if t:find(", ", 1, true) then                       -- the card's title: "Name, Name"
        local parts, any = {}, false
        for part in (t .. ", "):gmatch("(.-), ") do
            local uk = W.Dungeon(part)
            any = any or uk ~= nil
            parts[#parts + 1] = uk or part
        end
        if any then return table.concat(parts, ", ") end
    end
    if t:find("|c", 1, true) then
        local pieces, any = Pieces(t), false
        if #pieces == 1 and not pieces[1]:find("^" .. C) then return nil end
        for i, p in ipairs(pieces) do
            local code, inner = p:match("^(" .. C .. ")(.-)|r$")
            local uk = code and Line(inner) or (not code and Line(p))
            if uk then
                pieces[i] = code and (code .. uk .. "|r") or uk
                any = true
            end
        end
        if any then return table.concat(pieces) end
    end
    return nil
end
W.Line = Line

-- One line of ours back in English, or nil: a word, a formatted text, or in colour pieces.
local function Back(t)
    local en = Lc.English(t)
    if en then return en end
    local lead, body, trail = t:match("^(%s*)(.-)(%s*)$")
    if (lead ~= "" or trail ~= "") and body ~= "" then
        en = Back(body)
        return en and (lead .. en .. trail) or nil
    end
    if not t:find("|c", 1, true) then return nil end
    local pieces, any = Pieces(t), false
    for i, p in ipairs(pieces) do
        local code, inner = p:match("^(" .. C .. ")(.-)|r$")
        local e = Lc.English(code and inner or p)
        if e then
            pieces[i] = code and (code .. e .. "|r") or e
            any = true
        end
    end
    return any and table.concat(pieces) or nil
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

-- Finished texts: English -> Ukrainian, or false for "nothing to change". They hold while the word
-- lists (Lc.gen) and the saved name tables are the same tables: the modules that save names put in
-- a new table each time, so a new name means a new table here, and the memo starts again.
local memo, memoSize, stamp, slot, changed = {}, 0, {}, 0, false
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
    if changed then wipe(memo) memoSize = 0 end
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

-- One FontString as it should be now: our words while they are wanted, OpenMap's otherwise.
-- `fresh`: OpenMap has just set its text (the SetText hook), so the key it read from L is known.
function W.Apply(fs, fresh)
    stale[fs] = nil
    local now = UADD.Plain(fs:GetText())   -- nil for a secret text (combat): nothing of it is kept
    if mine[fs] == nil or now ~= mine[fs] then   -- OpenMap's own text (new, or set again)
        local en = not fresh and Kept(fs, now) or W.English(now)   -- from L: already our words
        orig[fs], mine[fs] = en or now, en and now or nil
    end
    if ns.WordsWanted() then
        if mine[fs] then return end
        local uk = W.Text(orig[fs])
        if uk then
            if uk ~= now then Put(fs, uk) end
            mine[fs] = uk
        end
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
