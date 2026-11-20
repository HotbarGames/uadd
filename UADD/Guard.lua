-- UADD guard: puts right three kinds of game-wide breakage, if any UADD code ever causes them, and
-- says so once per kind a session (a chat line, UADD_DB.health.guard, /uadd).
--   * A tooltip line pinned to the Latin file of its own font object. The game's tooltip lines use
--     font FAMILIES (one file per alphabet). fs:SetFont(<that same file>) pins the line to the Latin
--     file, and UALL Forever's Ukrainian on it shows boxes (docs/LESSONS2.md lesson 18). Nobody pins
--     a line to the file it already had on purpose, so such a pin gets its font object back. A line
--     set to another file (ours while it shows our words, or another addon's font) is left alone.
--   * The same pin on any FontString that UADD ever gave its font (AceFont.Set calls U.GuardWatch):
--     once it shows Cyrillic while pinned to its own object's Latin file (an old "put back" by path,
--     the boxes seen in TomTom's arrow title), it gets its font object back.
--   * A shared font object (GameFontNormal, GameTooltipText, ...) changed by UADD's code: it gets its
--     own font back from a copy made when UADD loaded. Changes made by other addons are theirs.
--   * The keyboard held by a text box nobody can see (hidden, or with no parent and no size): Enter
--     would not open chat (lesson 16). The box lets go of it.
-- Cheap: the tooltip lines are looked at one frame after a tooltip is cleared (once per frame at
-- most, up to 40 lines each); a font object is looked at only when someone sets its font; the
-- keyboard and the pinned watched FontStrings once a second. Nothing runs per frame. Each step is under pcall: the guard never throws.

local U = UADD
local TIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2" }
local OBJECTS = { "GameFontNormal", "GameFontHighlight", "GameFontNormalSmall", "GameFontHighlightSmall",
    "GameFontNormalLarge", "GameFontDisable", "GameTooltipText", "GameTooltipHeaderText", "GameTooltipTextSmall",
    "ChatFontNormal", "NumberFontNormal", "SystemFont_Shadow_Med1", "QuestFont" }
local MAX_LINES = 40
local SAY = {
    tip = "підказка показувала б квадрати замість літер: шрифт рядка повернуто.",
    line = "напис показував квадрати замість літер: його шрифт повернуто.",
    font = "код UADD змінив спільний шрифт гри: його повернуто.",
    focus = "клавіатуру тримало невидиме поле вводу: її звільнено, Enter знову відкриває чат.",
}
local pin = setmetatable({}, { __mode = "k" })     -- tooltip line -> file set by SetFont since its last object
local hookedLine = setmetatable({}, { __mode = "k" })
local watched = setmetatable({}, { __mode = "k" })    -- FontStrings UADD gave its font (AceFont.Set)
local keep, fixedObj = {}, {}                    -- font object name -> its copy at load / true once put back
local fixed, said = {}, {}                       -- kind -> times put right / reported this session
local queued, stuck = false, nil

local function SamePath(a, b)
    return type(a) == "string" and type(b) == "string" and (a:gsub("/", "\\"):lower()) == (b:gsub("/", "\\"):lower())
end

local function Note(kind)
    fixed[kind] = (fixed[kind] or 0) + 1
    if type(UADD_DB) == "table" then
        local h = U.DB().health
        if type(h) ~= "table" then h = {} U.DB().health = h end
        h.guard = type(h.guard) == "table" and h.guard or {}
        h.guard[kind] = (tonumber(h.guard[kind]) or 0) + 1
    end
    if said[kind] then return end
    said[kind] = true
    U.Print("|cffffd200вартовий:|r " .. SAY[kind] .. " Повідомте автору UADD, будь ласка.")
end
U.GuardNote = Note

local function Forbidden(f) return type(f) ~= "table" or (f.IsForbidden and f:IsForbidden()) end

-- A frame's regions / child frames as a list; empty for a forbidden frame (any call on one throws).
-- Module walks over the game's frames use these (tools/test_shared_state.py, kind "walk").
function U.Regions(f)
    if Forbidden(f) or not f.GetRegions then return {} end
    return { f:GetRegions() }
end
function U.Children(f)
    if Forbidden(f) or not f.GetChildren then return {} end
    return { f:GetChildren() }
end

-- ── Tooltip lines ─────────────────────────────────────────────────────────────────────────────

local function OnSetFont(fs, path) pin[fs] = path end
local function OnSetObject(fs) pin[fs] = nil end

local function Line(fs, kind)
    if type(fs) ~= "table" or not fs.SetFont then return end
    if not hookedLine[fs] then
        hookedLine[fs] = true
        hooksecurefunc(fs, "SetFont", OnSetFont)
        hooksecurefunc(fs, "SetFontObject", OnSetObject)
        return
    end
    local p = pin[fs]
    if not p or (U.IsCyrFont and U.IsCyrFont(p)) then return end
    local o = fs.GetFontObject and fs:GetFontObject()
    if type(o) ~= "table" or not o.GetFont or not SamePath((o:GetFont()), p) then return end
    U.FontBack(fs, { object = o })             -- its object again, colour and the rest kept
    pin[fs] = nil
    Note(kind or "tip")
end

-- A FontString UADD gave its font: its pins are seen from now on (hooked before ours is set).
function U.GuardWatch(fs)
    if type(fs) ~= "table" or watched[fs] then return end
    watched[fs] = true
    pcall(Line, fs)
end

local function ShowsCyr(fs)
    local t = fs.GetText and fs:GetText()
    return type(t) == "string" and t:find("[\208\209\210][\128-\191]") ~= nil
end

-- Once a second: only watched FontStrings pinned (by SetFont since their last object) to a Latin file.
local function Watched()
    local list = {}
    for fs, p in pairs(pin) do
        if watched[fs] and not U.IsCyrFont(p) then list[#list + 1] = fs end
    end
    for _, fs in ipairs(list) do
        if ShowsCyr(fs) then pcall(Line, fs, "line") end
    end
end

local function Lines()
    queued = false
    for _, name in ipairs(TIPS) do
        local tip = rawget(_G, name)
        if not Forbidden(tip) then
            for i = 1, MAX_LINES do
                local l = rawget(_G, name .. "TextLeft" .. i)
                if not l then break end
                Line(l)
                Line(rawget(_G, name .. "TextRight" .. i))
            end
        end
    end
end

local function SafeLines() pcall(Lines) end
local function OnCleared()
    if queued then return end
    queued = true
    C_Timer.After(0, SafeLines)
end

-- ── Shared font objects ───────────────────────────────────────────────────────────────────────

-- Did UADD's code make the call? The first addon file on the stack that is not this one decides.
local function Ours(st)
    for line in st:gmatch("[^\n]+") do
        local folder = not line:find("Guard%.lua") and line:match("AddOns[/\\]([^/\\]+)[/\\]")
        if folder then return folder:find("^UADD") ~= nil end
    end
    return false
end

local function OnObjectFont(name)
    if fixedObj[name] then return end           -- put back once; again means someone wants it so
    local ok, st = pcall(debugstack, 3, 8, 0)
    if not ok or type(st) ~= "string" or not Ours(st) then return end
    fixedObj[name] = true
    C_Timer.After(0, function()
        pcall(function()
            local o, copy = rawget(_G, name), keep[name]
            o:CopyFontObject(copy)
            Note("font")
        end)
    end)
end

for i, name in ipairs(OBJECTS) do
    local o = rawget(_G, name)
    if type(o) == "table" and o.SetFont and o.CopyFontObject and CreateFont then
        local ok, copy = pcall(CreateFont, "UADDGuardFont" .. i)
        if ok and copy and pcall(copy.CopyFontObject, copy, o) then
            keep[name] = copy
            hooksecurefunc(o, "SetFont", function() pcall(OnObjectFont, name) end)
        end
    end
end

-- ── Keyboard ──────────────────────────────────────────────────────────────────────────────────

local function Unseen(f)
    if not f:IsVisible() then return true end
    local w, h = f.GetWidth and f:GetWidth() or 1, f.GetHeight and f:GetHeight() or 1
    return f:GetParent() == nil and ((w or 0) < 1 or (h or 0) < 1)
end

local function Keyboard()
    local f = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
    if not f or Forbidden(f) or not f.ClearFocus or not Unseen(f) then stuck = nil return end
    if stuck ~= f then stuck = f return end      -- the same box on two looks in a row
    stuck = nil
    f:ClearFocus()
    Note("focus")
end

-- ── Start ─────────────────────────────────────────────────────────────────────────────────────

function U.GuardLines()
    local out = {}
    for kind, n in pairs(fixed) do out[#out + 1] = ("  вартовий: %s (%d раз)"):format(SAY[kind], n) end
    return out
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
    for _, name in ipairs(TIPS) do
        local tip = rawget(_G, name)
        if not Forbidden(tip) and tip.HookScript then pcall(tip.HookScript, tip, "OnTooltipCleared", OnCleared) end
    end
    SafeLines()                                   -- hooks the lines there are now
    if C_Timer and C_Timer.NewTicker then C_Timer.NewTicker(1, function() pcall(Keyboard) pcall(Watched) end) end
end)
