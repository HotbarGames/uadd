-- Lines of WhatTheWhisper with a name in them that our table alone cannot make whole.
--   * The zone alert (a chat line: a name, then the zone the game gives in English). Its template stays English in
--     the locale table (sort fu), so its own Print gets a whole English line; the wrap here knows that template,
--     asks the zone's name through UADD.UALL.Zone and prints ours. No name, or not known yet: whole English.
--   * The export window's title: our word, a dot and a group thread's name. That name is saved in English
--     (lesson 14, Groups.lua), so for a party, raid ... thread the title shows ours; the saved name never changes.
--   * The icon picker's texts, written once each time it opens: switched both ways while it is open (lesson 15).
--     The conversation's name in its hint (a nickname, a player or a channel) is kept as it is.
-- Ours only while ours is in its table. Plain pcall, not U.Safe: it must also work after an off for errors
-- (lesson 19). Off gives its own Print back, unless someone wrapped it after us. No English of it is stored here.

local _, ns = ...
local U = UADD
local N = {}
ns.Lines = N

local ZONE, HINT, EXPORT = "L.26a34d4a", "L.abf52159", "L.b18dc667"
local CYR = "[\208-\210]"           -- the first byte of a Cyrillic letter in UTF-8
local DOT = " \194\183 "            -- its own joint in the export title
local GROUP = { PARTY = "Група", RAID = "Рейд", INSTANCE_CHAT = "Підземелля", GUILD = "Гільдія", OFFICER = "Офіцери" }

local prints                        -- { orig = its Print, fn = ours } while ours wraps it
local hooked = false

local function Report(err)
    err = tostring(err)
    pcall(U.ReportError, err)
    if type(U.Fault) == "function" then pcall(U.Fault, "wtw", err) end
end

local function Want() return ns.On() and ns.Swap.On() and not ns.Swap.Saving() end

local function Frame(name)
    local f = rawget(_G, name)
    return type(f) == "table" and f or nil
end

-- ── The zone alert ────────────────────────────────────────────────────────────────────────────

-- The zone's Ukrainian, or nil (none, or not known yet). Never text with codes, links or edge spaces (lesson 25).
local function Zone(zone)
    if zone:find(CYR) then return zone end
    if #zone > 120 or zone:find("[%[%(|\n]") or zone:find("^%s") or zone:find("%s$") then return nil end
    local ok, ua, wait = pcall(U.UALL.Zone, zone)
    if not ok or wait or type(ua) ~= "string" or not ua:find(CYR) then return nil end
    return ua
end

-- Ours for a whole zone alert of its English, or nil. The zone is what follows the template's last middle part: a
-- nickname may hold those words, a zone does not.
local function ZoneLine(line)
    line = U.Plain(line)
    local en, ua = ns.Swap.KeyFor(ZONE), ns.AL[ZONE]
    if not line or type(en) ~= "string" or type(ua) ~= "string" then return nil end
    local a, m, z = en:match("^(.-)%%s(.-)%%s(.*)$")
    if not m or m == "" or #line <= #a + #m + #z then return nil end
    if line:sub(1, #a) ~= a or line:sub(#line - #z + 1) ~= z then return nil end
    local body = line:sub(#a + 1, #line - #z)
    local first, last, from = nil, nil, 1
    while true do
        local s, e = body:find(m, from, true)
        if not s then break end
        first, last, from = s, e, e + 1
    end
    if not first or first == 1 or last == #body then return nil end
    local zone = Zone(body:sub(last + 1))
    return zone and ua:format(body:sub(1, first - 1), zone) or nil
end

local function WrapPrint(a)
    if prints or type(a.Print) ~= "function" then return end
    local orig = a.Print
    local function fn(...)
        if select("#", ...) == 1 and Want() then
            local ok, ua = pcall(ZoneLine, (...))
            if not ok then Report(ua) elseif ua then return orig(ua) end
        end
        return orig(...)
    end
    prints = { orig = orig, fn = fn }
    a.Print = fn
end

-- ── The export window's title ─────────────────────────────────────────────────────────────────

-- The title it should have now, or nil when this title is not one of a group thread's export.
local function Title(d)
    local a, conv = ns.Swap.Addon(), d.conv
    local GC = a and a.GroupChat
    if type(conv) ~= "table" or not conv.isGroup or type(GC) ~= "table" or type(GC.Target) ~= "function" then return end
    local ours, name = GROUP[GC.Target(conv.id)], conv.name or conv.id
    local t, w = U.Plain(d.title:GetText()), ns.Swap.Word(ns.Swap.KeyFor(EXPORT))
    if not ours or type(name) ~= "string" or not t or not w then return end
    local theirs = t:sub(-#(DOT .. name)) == DOT .. name
    if not theirs and t:sub(-#(DOT .. ours)) ~= DOT .. ours then return end
    return w .. DOT .. (Want() and ours or name), t
end

local function ExportTitle()
    local d = Frame("WhatTheWhisperCopyDialog")
    if not d or type(d.title) ~= "table" or not d:IsShown() then return end
    local now, was = Title(d)
    if now and now ~= was then d.title:SetText(now) end
end

local function HookExport(a)
    local D = a.Dialogs
    if hooked or type(D) ~= "table" or type(D.ShowExport) ~= "function" then return end
    hooked = true
    hooksecurefunc(D, "ShowExport", function()
        if not Want() then return end
        local ok, err = pcall(ExportTitle)
        if not ok then Report(err) end
    end)
end

-- ── The icon picker ───────────────────────────────────────────────────────────────────────────

local function Whole(fs)
    if type(fs) ~= "table" or not fs.GetText then return end
    local t = U.Plain(fs:GetText())
    local k = t and ns.Swap.KeyOf(t)
    local w = k and ns.Swap.Word(k)
    if w and w ~= t then fs:SetText(w) end
end

-- The hint, with the name it shows kept: from ours or from its English, to what its L gives now.
local function Hint(fs)
    if type(fs) ~= "table" or not fs.GetText then return end
    local t, en, ua = U.Plain(fs:GetText()), ns.Swap.KeyFor(HINT), ns.AL[HINT]
    local w = ns.Swap.Word(en)
    for _, tpl in ipairs({ ua or "", en or "" }) do
        local a, z = tpl:match("^(.-)%%s(.*)$")
        if t and w and a and #t > #a + #z and t:sub(1, #a) == a and t:sub(#t - #z + 1) == z then
            local now = w:format(t:sub(#a + 1, #t - #z))
            if now ~= t then fs:SetText(now) end
            return
        end
    end
end

local function Icons()
    local d = Frame("WhatTheWhisperIconDialog")
    if not d or not d:IsShown() then return end
    Whole(d.title)
    Whole(d.empty)
    Hint(d.hint)
end

-- ── On and off ────────────────────────────────────────────────────────────────────────────────

function N.Install()
    local a = ns.Swap.Addon()
    if not a then return end
    WrapPrint(a)
    HookExport(a)
end

function N.Remove()
    local a = ns.Swap.Addon()
    if prints and a and a.Print == prints.fn then
        a.Print = prints.orig
        prints = nil
    end
end

-- After each swap, both ways: the open windows' texts as they should be now.
function N.Refresh()
    for _, fn in ipairs({ ExportTitle, Icons }) do
        local ok, err = pcall(fn)
        if not ok then Report(err) end
    end
end
