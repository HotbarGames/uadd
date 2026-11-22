-- UADD - BugSack: its words. Ours are keyed by UADD.Hash of each English text (data/text01.lua).
--
-- BugSack's locale table is shared by all its files and read at run time, so ours goes into it by the hash of
-- each value (its English kept here only in memory, read from the table at start). The session line is built from
-- formats copied at load: it is turned as a whole (time, our word, the sender's name as it is, the count) or stays
-- whole English. The Lua error text, its stack and locals, the font size menu and the player's text stay as they
-- are. No English of it is stored here. Screen.lua: its window; Module.lua: popup, on/off, commands.

local _, ns = ...
local U = UADD
ns.KEY, ns.TARGET, ns.TITLE = "bs", "BugSack", "BugSack"
ns.FRAME, ns.TEXT, ns.POPUP = "BugSackFrame", "BugSackScrollText", "BugSackSendBugs"
local CYR = "[\208-\211][\128-\191]"
ns.CYR = CYR
local MAXLEN = 300
local TARGET = ns.TARGET

local T = ns.AL or {}
ns.AL = T
-- By the hash of the English: which values are what, and the texts left English on purpose (the font size menu's
-- rows, the text it raises as a Lua error).
local H = {
    today = "0e2d9ee6", nobugs = "60fc61d4", loc = "71531c39", sent = "3034da1b", pop = "45e5f276",
    send = "7c8c4f2f", word = "0f6321ef", options = "d2a8b871",
}
ns.H = H
ns.STAY = { ["0e1a623e"] = true, c2d88c26 = true, ["0d9569d0"] = true, e8530db5 = true, ["9e12cf6b"] = true }
-- The session line's marks between its parts (colour codes only).
local A1, A2 = " - |cffff4411", "|r - |cff44ff44"

ns.st = { db = nil, ready = false }
local st = ns.st
function ns.EnglishClient()
    local l = type(GetLocale) == "function" and GetLocale() or "enUS"
    return l == "enUS" or l == "enGB"
end
function ns.On() return st.ready and st.db ~= nil and st.db.enabled == true and ns.EnglishClient() end
function ns.WordsWanted() return ns.On() and not U.originalShown end

-- A hook that must work again after "on" (lesson 19 again): pcall, reported and counted.
function ns.Guard(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if ok then return end
        err = tostring(err)
        pcall(U.ReportError, err)
        if type(U.Fault) == "function" then pcall(U.Fault, ns.KEY, err) end
    end
end

local A, L
local ENL = {}            -- hash -> its English, read from its table at start
local EN, UK = {}, {}     -- its English -> ours, ours -> its English (exact texts of its window)
ns.EN, ns.UK, ns.ENL = EN, UK, ENL
local OPT_EN, OPT_UK

local function Build()
    for _, v in pairs(L) do
        local p = U.Plain(v)
        local h = p and not p:find(CYR) and U.Hash(p)
        local uk = h and T["L." .. h]
        if uk then
            ENL[h], EN[p], UK[uk] = p, uk, p
            EN[p .. ":"], UK[uk .. ":"] = uk .. ":", p .. ":"
        end
    end
    local o = U.Plain(rawget(_G, "OPTIONS"))
    local uk = T["Game." .. H.options]
    if o and uk and U.Hash(o) == H.options then OPT_EN, OPT_UK, EN[o], UK[uk] = o, uk, uk, o end
end
function ns.Bind(a, l)    -- its addon table and its locale table, once at start
    A, L = a, l
    ns.A = a
    Build()
end

local function EndsWith(s, e) return e == "" or s:sub(-#e) == e end
ns.EndsWith = EndsWith
local function Parts(tpl)         -- tpl split at each %s (no pattern: plain finds)
    local out, i = {}, 1
    while true do
        local a = tpl:find("%s", i, true)
        if not a then out[#out + 1] = tpl:sub(i) return out end
        out[#out + 1] = tpl:sub(i, a - 1)
        i = a + 2
    end
end
local function Fill(tpl, vals)    -- tpl with its %s filled in order (no pattern: a value may hold any sign)
    local p = Parts(tpl)
    if #p ~= #vals + 1 then return nil end
    local out = p[1]
    for i, v in ipairs(vals) do out = out .. v .. p[i + 1] end
    return out
end
local function Word(w) return U.Hash(w) == H.word and T["Word." .. H.word] or nil end

-- The session line's source part: ours, or nil (the whole line stays English).
local function Source(src)
    local loc, sent = ENL[H.loc], ENL[H.sent]
    if loc and T["L." .. H.loc] then
        local p = Parts(loc)
        if #p == 2 and #src > #p[1] + #p[2] and src:sub(1, #p[1]) == p[1] and EndsWith(src, p[2]) then
            local w = Word(src:sub(#p[1] + 1, #src - #p[2]))
            if w then return Fill(T["L." .. H.loc], { w }) end
        end
    end
    if sent and T["L." .. H.sent] then
        local p = Parts(sent)
        if #p == 3 and #src > #p[1] + #p[3] and src:sub(1, #p[1]) == p[1] and EndsWith(src, p[3]) then
            local inner = src:sub(#p[1] + 1, #src - #p[3])
            local m = p[2] ~= "" and inner:find(p[2], 1, true)
            local name = m and inner:sub(1, m - 1)
            local w = m and Word(inner:sub(m + #p[2]))
            if w and name ~= "" and not name:find("[|\n]") then return Fill(T["L." .. H.sent], { name, w }) end
        end
    end
end

-- The whole session line: time, source, count. Its time is the clock (AM/PM dropped: ours is 24 h) or a date.
local function Line(t)
    local a = t:find(A1, 1, true)
    if not a then return nil end
    local d, rest = t:sub(1, a - 1), t:sub(a + #A1)
    local b = rest:find(A2, 1, true)
    if not b then return nil end
    local src, tail = rest:sub(1, b - 1), rest:sub(b + #A2)
    if not tail:match("^%d+|r$") then return nil end
    if d:match("^%d%d:%d%d:%d%d [AP]M$") then d = d:sub(1, 8)
    elseif not d:match("^%d%d%d%d/%d%d/%d%d %d%d:%d%d:%d%d$") then return nil end
    local s = Source(src)
    return s and (d .. A1 .. s .. A2 .. tail) or nil
end

local sback, nsback = {}, 0       -- ours -> the English it was made from (a few lines)
local function ToUk(t)
    if type(t) ~= "string" or #t > MAXLEN or t:find(CYR) then return nil end
    if OPT_EN and t == TARGET .. " " .. OPT_EN then return OPT_UK .. " " .. TARGET end
    local tod, ukt = ENL[H.today], T["L." .. H.today]
    if tod and ukt and t:sub(1, #tod + 2) == tod .. " (" then
        local n = t:sub(#tod + 3):match("^(%d+)%)$")
        return n and (ukt .. " (" .. n .. ")") or nil
    end
    local uk = Line(t)
    if uk then
        if nsback >= 50 then sback, nsback = {}, 0 end
        if sback[uk] == nil then nsback = nsback + 1 end
        sback[uk] = t
    end
    return uk
end
local function ToEn(t)
    if type(t) ~= "string" or #t > MAXLEN or not t:find(CYR) then return nil end
    if sback[t] then return sback[t] end
    if OPT_EN and t == OPT_UK .. " " .. TARGET then return TARGET .. " " .. OPT_EN end
    local tod, ukt = ENL[H.today], T["L." .. H.today]
    if tod and ukt and t:sub(1, #ukt + 2) == ukt .. " (" then
        local n = t:sub(#ukt + 3):match("^(%d+)%)$")
        return n and (tod .. " (" .. n .. ")") or nil
    end
end
ns.ToUk, ns.ToEn = ToUk, ToEn
function ns.SessionShape(t) return t:match("^%d+$") or ToUk(t) or ToEn(t) end

-- The send popup's text (its template or as shown, with the session number) and its button.
local function PopUk(now)
    if type(now) ~= "string" or #now > MAXLEN then return nil end
    local h = U.Hash(now)
    if h == H.send or h == H.pop then return T["L." .. h] end
    local en, uk = ENL[H.pop], T["L." .. H.pop]
    local a = en and en:find("%d", 1, true)
    local b = uk and uk:find("%d", 1, true)
    if not a or not b then return nil end
    local pre, post = en:sub(1, a - 1), en:sub(a + 2)
    if #now <= #pre + #post or now:sub(1, #pre) ~= pre or not EndsWith(now, post) then return nil end
    local n = now:sub(#pre + 1, #now - #post)
    if not n:match("^%d+$") then return nil end
    return uk:sub(1, b - 1) .. n .. uk:sub(b + 2)
end
ns.PopUk = PopUk

function ns.Translate(t) return (type(t) == "string" and EN[t]) or ToUk(t) or PopUk(t) end
ns.Session, ns.Pop = ToUk, PopUk

-- ── Its locale table ─────────────────────────────────────────────────────────────────────────

local swapped = {}        -- key -> its English, while ours is in the table
function ns.Words(want)
    if type(L) ~= "table" then return end
    if want then
        for k, v in pairs(L) do
            local uk = swapped[k] == nil and type(v) == "string" and EN[v]
            if uk and ENL[U.Hash(v)] == v then swapped[k] = v L[k] = uk end
        end
    else
        for k, en in pairs(swapped) do
            if L[k] == EN[en] then L[k] = en end          -- still ours: its English back; else theirs stays
            swapped[k] = nil
        end
    end
end
function ns.AnySwapped() return next(swapped) ~= nil end
function ns.Swapped()
    local n = 0
    for k, en in pairs(swapped) do if L[k] == EN[en] then n = n + 1 end end
    return n
end
