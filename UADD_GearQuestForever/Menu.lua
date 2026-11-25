-- UADD - GearQuest Forever: its right-click menu on a hunt, its box to copy a name, its short notices (since 1.3.4).
--
-- Their words come from its locale table (Locale.lua), so they are ours already; this file gives them a face with
-- Cyrillic (lessons 32, 45) and switches them on the hold key, off and on.
--   * The menu is the game's shared list (DropDownList1). Only while it is open for GearQuest's own menu frame are its
--     rows touched; when it hides, or another menu opens, each row gets its English and its own font back first, so
--     no other menu ever gets our words or our font.
--   * The copy box: only its title. The name in its text box (what the player copies) is never read or set.
--   * A notice: GearQuest sizes it by the text in its own font, so it is sized again, its way, after our font.
-- Each hook runs under a plain pcall, counts its errors (U.Fault) and follows the state (lesson 19). A line that can
-- not get a Cyrillic face goes back to its whole English. No English of GearQuest is stored here.

local _, ns = ...
local U = UADD
local G = ns.Glued

local Mn = {}
ns.Menu = Mn

local KEY = "gq"
local MENU, LIST, MAXROWS = "GearQuestHuntRowMenu", "DropDownList1", 32
local CYR = "[\208-\211]"
local GetText, SetRaw, Shown, InForce = G.GetText, G.SetRaw, G.Shown, G.InForce

local kept = setmetatable({}, { __mode = "k" })    -- text -> its own font, while ours is on it
local rows = {}                                    -- a row's text of its open menu -> what we left on it
local listHooked, installed = false, false

-- One text on the side of now, its font with it. Returns the text it shows.
local function Side(fs, on)
    local t = GetText(fs)
    if not t or t == "" then return nil end
    local other = ns.Screen.Other(t, not on)
    if other and other ~= t and SetRaw(fs, other) then t = other end
    if t:find(CYR) then
        local ok, yes = pcall(U.CyrFix, fs, kept)
        if ok and yes then return t end
        local en = ns.Screen.Other(t, true)            -- no face for it: its English
        if en and SetRaw(fs, en) then t = en end
    end
    pcall(U.CyrUnfix, fs, kept)
    return t
end

-- ── The right-click menu ───────────────────────────────────────────────────────────────────────

local function RowsBack()
    for fs, was in pairs(rows) do
        rows[fs] = nil
        local t = GetText(fs)
        local en = t and t == was and ns.Screen.Other(t, true)
        if en and en ~= t then SetRaw(fs, en) end
        pcall(U.CyrUnfix, fs, kept)
    end
end

local function SyncRows(on)
    local list = rawget(_G, LIST)
    for i = 1, math.min(tonumber(rawget(list, "numButtons")) or 0, MAXROWS) do
        local fs = rawget(_G, LIST .. "Button" .. i .. "NormalText")
        if type(fs) == "table" then rows[fs] = Side(fs, on) end
    end
end

local function OnMenu(level, _, frame)
    if frame == nil or frame ~= rawget(_G, MENU) then
        if next(rows) ~= nil then RowsBack() end
        return
    end
    local list = rawget(_G, LIST)
    if (tonumber(level) or 1) ~= 1 or not Shown(list) then return end
    if not listHooked and type(list.HookScript) == "function" then
        listHooked = true
        list:HookScript("OnHide", G.Guard(function() if next(rows) ~= nil then RowsBack() end end))
    end
    if listHooked then SyncRows(InForce()) end
end

-- ── The copy box and the notices ───────────────────────────────────────────────────────────────

local function Part(owner, field, text)
    local g = ns.Loc.Addon()
    local o = g and rawget(g, owner)
    local f = type(o) == "table" and rawget(o, field)
    local fs = type(f) == "table" and rawget(f, text)
    if type(fs) == "table" then return fs, f end
end

local function SyncTitle(on)
    local fs = Part("Log", "copyNameBox", "title")
    if fs then Side(fs, on) end
end

local function SyncNotice(on)
    local fs, frame = Part("Orders", "notice", "text")
    if not fs or not Side(fs, on) then return end
    local w = (tonumber(fs:GetStringWidth()) or 180) + 56          -- as GearQuest sizes it
    frame:SetWidth(math.max(240, math.min(520, w)))
end

-- ── Install and switch ─────────────────────────────────────────────────────────────────────────

local function Hook(owner, name, fn)
    local o = rawget(ns.Loc.Addon(), owner)
    if type(o) == "table" and type(rawget(o, name)) == "function" then
        hooksecurefunc(o, name, G.Guard(function() fn(InForce()) end))
    end
end

function Mn.Install()
    if installed or not ns.Loc.Addon() then return end
    installed = true
    Hook("Log", "CopyHuntName", SyncTitle)
    Hook("Orders", "ShowNotice", SyncNotice)
    if type(rawget(_G, "ToggleDropDownMenu")) == "function" then
        hooksecurefunc("ToggleDropDownMenu", G.Guard(OnMenu))
    end
end

-- After Screen.lua's pass (Module.lua, out of combat): these follow, whether that pass reached them or not.
function Mn.Sync(on)
    if not installed then return end
    for _, fn in ipairs({ SyncTitle, SyncNotice, function() if next(rows) ~= nil then SyncRows(on) end end }) do
        local ok, err = pcall(fn, on)
        if not ok then
            pcall(U.ReportError, tostring(err))
            pcall(U.Fault, KEY, tostring(err))
        end
    end
end
