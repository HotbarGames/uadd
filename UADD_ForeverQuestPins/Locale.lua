-- UADD_ForeverQuestPins: our Ukrainian put into Forever Quest Pins' own locale table, in place.
-- Forever Quest Pins keeps one table, ForeverQuestPins.L, empty on an English client: a metatable gives back
-- the key, so L["Pins enabled."] is the English. Every file reads it at each call, so most words follow it on
-- their own. Install writes our words with rawset (only where the key is still English), Uninstall puts back
-- only the keys that still hold our word, so off or the hold key leaves L as Forever Quest Pins made it.
-- A word is written only when its format specs and its escapes (|c, |r, |T, |H, |n, line breaks) match the
-- English key; a word that does not match is left out and the English shows.
-- Keys whose slot holds a game name (a quest title, a zone) are never written: their lines are built whole in
-- Breadcrumb.lua and Chat.lua, all Ukrainian or all English (CLAUDE.md "No half translations").
local _, ns = ...
local U = UADD
local Lc = {}
ns.Locale = Lc

-- For a hook that gives English back, or must work again after the module was turned off for errors and "on"
-- again: U.Safe stays dead for the session then, so not U.Safe (lesson 19). An error is reported and counted the
-- same way (5 turn the module off); the hook checks ns.On() / ns.WordsWanted() itself.
function Lc.Guard(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if ok then return end
        err = tostring(err)
        pcall(U.ReportError, err)
        if type(U.Fault) == "function" then pcall(U.Fault, "foreverquestpins", err) end
    end
end

local SPEC = "%%[%d%$%-%+#0]*%.?%d*[%a%%]"
local ESC = { "|c", "|r", "|T", "|t", "|H", "|h", "|n", "\n" }

-- Slot marks for the checks (like OpenMap's Lc.FREE): every other key's slots hold only values (numbers, a
-- version) or our own words (L's "on"/"off"). Key -> what its slots hold; never written into L.
Lc.NAMES = {
    ["You accepted %s without completing its breadcrumb quest %s."] = "two quest titles, one with its zone",
    ["Abandon it from the quest log to set a waypoint to the breadcrumb."] = "no slot: glued after the line above",
    ["Abandoned %s."] = "a quest title",
    ["Skipped breadcrumb notice for %s: the dialog queue is full."] = "a quest title (debug)",
    ["Quest %d skipped breadcrumbs: %s"] = "quest IDs (debug)",
    ["Quest %s%s: %s (%s)"] = "a quest title (debug)",
}
-- Its What's New lines and their login header are not ours: they stay English (lesson 43).

local entries, rev, count = {}, {}, 0      -- en -> uk; uk -> en (false: two English share it)
local pats = {}                             -- { en, uk, enPat, ukPat } for keys with number slots only
local wrote, saved = {}, {}                 -- en -> uk we wrote; en -> { what was there }
local LABELS = { "TrackerSortLabels", "TrackerFilterLabels" }
local labels = {}                           -- table name -> { key -> { en, uk } } we switched
local built = false

local function Specs(s)
    local out = {}
    for spec in s:gmatch(SPEC) do out[#out + 1] = spec end
    return out
end

local function Count(s, what)
    local n, at = 0, 1
    while true do
        local i = s:find(what, at, true)
        if not i then return n end
        n, at = n + 1, i + #what
    end
end

-- true when uk has the same format specs, in order, and the same escapes as en.
function Lc.Usable(en, uk)
    if type(en) ~= "string" or type(uk) ~= "string" or en == "" or uk == "" then return false end
    local a, b = Specs(en), Specs(uk)
    if #a ~= #b then return false end
    for i = 1, #a do if a[i] ~= b[i] then return false end end
    for _, e in ipairs(ESC) do if Count(en, e) ~= Count(uk, e) then return false end end
    return true
end

-- A number slot as a capture; nil for any other slot (%s: the line is never matched on screen).
local function Slot(spec)
    local kind = spec:sub(-1)
    if kind == "%" then return "%%" end
    if kind == "d" or kind == "i" then return "([%+%-]?%d+)" end
    if kind == "f" then return "([%+%-]?%d+%.?%d*)" end
    return nil
end

-- An anchored pattern for a template with number slots only, or nil.
local function Pattern(t)
    local out, at, slots = { "^" }, 1, 0
    while true do
        local i, j = t:find(SPEC, at)
        local lit = t:sub(at, (i or 0) - 1)
        if not i then lit = t:sub(at) end
        out[#out + 1] = (lit:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
        if not i then break end
        local cap = Slot(t:sub(i, j))
        if not cap then return nil end
        if cap ~= "%%" then slots = slots + 1 end
        out[#out + 1] = cap
        at = j + 1
    end
    if slots == 0 then return nil end
    out[#out + 1] = "$"
    return table.concat(out)
end

-- The template with its number slots filled by the captured strings, as they were on screen.
local function Fill(t, caps)
    local n = 0
    return (t:gsub(SPEC, function(spec)
        if spec == "%%" then return "%" end
        n = n + 1
        return caps[n] or ""
    end))
end

local function Build()
    if built then return end
    built = true
    for en, uk in pairs(ns.UK or {}) do
        if not Lc.NAMES[en] and Lc.Usable(en, uk) then
            entries[en] = uk
            count = count + 1
            if rev[uk] == nil then rev[uk] = en elseif rev[uk] ~= en then rev[uk] = false end
            if en:find("%", 1, true) then
                local ep, up = Pattern(en), Pattern(uk)
                if ep and up then pats[#pats + 1] = { en, uk, ep, up } end
            end
        end
    end
end

function Lc.Count() Build() return count end

-- Our word for a whole text, or nil. Formatted texts with number slots too ("Pin size: 80%").
function Lc.Uk(t)
    Build()
    if type(t) ~= "string" or t == "" then return nil end
    local uk = entries[t]
    if uk then return uk end
    if not t:find("%d") then return nil end
    for _, p in ipairs(pats) do
        local caps = { t:match(p[3]) }
        if caps[1] then return Fill(p[2], caps) end
    end
    return nil
end

-- The English for a text that is still our word, or nil (another addon's or a changed text stays: lesson 23).
function Lc.En(t)
    Build()
    if type(t) ~= "string" or t == "" then return nil end
    local en = rev[t]
    if en then return en end
    if not t:find("%d") then return nil end
    for _, p in ipairs(pats) do
        local caps = { t:match(p[4]) }
        if caps[1] then return Fill(p[1], caps) end
    end
    return nil
end

function Lc.Word(en) Build() return entries[en] end

-- Our Ukrainian for a key whose slots hold game names (Lc.NAMES), when it fits; never in L.
function Lc.Template(en)
    local uk = ns.UK and ns.UK[en]
    if Lc.Usable(en, uk) then return uk end
    return nil
end

-- An anchored pattern for a template: each %s a capture, the rest as it is.
function Lc.Shape(t)
    local p = t:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"):gsub("%%%%s", "(.-)")
    return "^" .. p .. "$"
end

-- The template with each %s filled in order (a name with a % in it stays as it is).
function Lc.Put(t, ...)
    local args, n = { ... }, 0
    return (t:gsub("%%s", function() n = n + 1 return args[n] or "" end))
end

local function Target()
    local fqp = rawget(_G, "ForeverQuestPins")
    return type(fqp) == "table" and fqp or nil
end
Lc.Target = Target

local function Install()
    Build()
    local fqp = Target()
    local L = fqp and fqp.L
    if type(L) ~= "table" then return end
    for en, uk in pairs(entries) do
        if wrote[en] == nil then
            local had = rawget(L, en)
            if had == nil or had == en then
                saved[en] = { had }
                rawset(L, en, uk)
                wrote[en] = uk
            end
        end
    end
    -- Its tracker's sort and filter names: tables its Config.lua fills from L once, at load (before our words
    -- came in); its settings drop-downs and Tracker.lua's menu read them there, so they are switched in place.
    for _, name in ipairs(LABELS) do
        local t = fqp[name]
        if type(t) == "table" then
            labels[name] = labels[name] or {}
            for k, v in pairs(t) do
                local uk = type(v) == "string" and entries[v]
                if uk and not labels[name][k] then
                    labels[name][k] = { v, uk }
                    t[k] = uk
                end
            end
        end
    end
end

local function Uninstall()
    local fqp = Target()
    local L = fqp and fqp.L
    if type(L) == "table" then
        for en, uk in pairs(wrote) do
            if rawget(L, en) == uk then rawset(L, en, saved[en][1]) end
        end
    end
    wipe(wrote)
    wipe(saved)
    for name, done in pairs(labels) do
        local t = fqp and fqp[name]
        for k, pair in pairs(done) do
            if type(t) == "table" and t[k] == pair[2] then t[k] = pair[1] end
        end
        labels[name] = nil
    end
end

function Lc.Written() local n = 0 for _ in pairs(wrote) do n = n + 1 end return n end

-- Our words in L while they are wanted, the English otherwise.
function Lc.Sync()
    if ns.WordsWanted() then Install() else Uninstall() end
end
function Lc.Restore() Uninstall() end
