-- UADD - What's Training?: our words on its own font strings and buttons, with a font that has
-- Ukrainian letters.
--
-- How we get in. What's Training? keeps its addon table private and puts no mark of its own on a font
-- string, but every window of its is a named frame whose name starts with "WhatsTraining" (or sits under
-- one). A font string is ours when its frame, or a frame above it (at most 15 up), has such a name. Its
-- tooltips (GameTooltip kind) are not: UADD/Lines.lua does their lines. We find the font strings:
--   * a post-hook on CreateFontString of the frame kinds (Frame, Button, ...): the frame that made one is
--     looked at on the next frame (by then it has its parent);
--   * its named windows, once after login (made before us), and again when they show.
-- Each one gets its own hooksecurefunc on SetText, SetFormattedText, SetFont and SetFontObject (never a
-- shared metatable); each of its buttons one on SetText (a button sets its label from the game's side,
-- past the label's own SetText). We keep the English it was given, write our Ukrainian over it and give
-- that one font string UADD's Cyrillic font at its own size (read back: S.Count counts only those that
-- really have it; no Cyrillic font: the English stays). The size is never made smaller (lesson 5).
-- Off, or the hold key: its English and its own font (font object or font) again.

local _, ns = ...
local U = UADD
local W = ns.Words
local S = {}
ns.Screen = S

local CYR = "[\208-\210]"
local function Weak() return setmetatable({}, { __mode = "k" }) end
local hooked = Weak()     -- fs -> true: our hooks are on it
local raw = Weak()        -- fs -> the English What's Training? gave it
local mine = Weak()       -- fs -> true: it shows our Ukrainian
local fonted = Weak()     -- fs -> { font object, path, size, flags } it had before ours
local buttons = Weak()    -- button -> true: our SetText hook is on it
local owned = Weak()      -- frame -> true: it is What's Training?'s
local walked = Weak()
local shown = {}
local busy = false
local queue, queued = {}, false
local ROOTS = { "WhatsTrainingOverlay", "WhatsTrainingFrame", "WhatsTrainingSettings",
    "WhatsTrainingTrainerController", "WhatsTrainingTrainAllConfirmation", "WhatsTrainingTrainAllButton",
    "WhatsTrainingFloatingFrame", "WhatsTrainingCraftingPage" }
local KINDS = { "Frame", "Button", "CheckButton", "StatusBar", "ScrollFrame", "Slider", "EditBox" }

local function Is(f, kind) return f.IsObjectType and f:IsObjectType(kind) end

-- What's Training?'s frame: a name starting "WhatsTraining" on it or above it; never a tooltip, never a
-- forbidden frame. Only a yes is remembered (a frame can get its parent later).
local function Owned(f)
    if type(f) ~= "table" then return false end
    if owned[f] then return true end
    local p, n = f, 0
    while type(p) == "table" and n < 15 do
        if (p.IsForbidden and p:IsForbidden()) or Is(p, "GameTooltip") then return false end
        local name = p.GetName and p:GetName()
        if type(name) == "string" and name:find("^WhatsTraining") then
            owned[f] = true
            return true
        end
        p = p.GetParent and p:GetParent() or nil
        n = n + 1
    end
    return false
end
S.Owned = Owned

local function Restore(fs)
    local was = fonted[fs]
    if not was then return end
    fonted[fs] = nil
    if was[1] then fs:SetFontObject(was[1])
    elseif was[2] and was[3] then fs:SetFont(was[2], was[3], was[4] or "") end
end

-- UADD's Cyrillic font at the size the font string has (or `was`: the font What's Training? just gave
-- it). True only when it really has it now.
local function Cyr(fs, was)
    local path = U.CyrFontPath()
    if not path then return false end
    if not was then
        was = fonted[fs]
        if not was then
            local p, s, f = fs:GetFont()
            was = { fs.GetFontObject and fs:GetFontObject() or nil, p, s, f }
        end
    end
    if not was[3] then return false end
    fonted[fs] = was
    fs:SetFont(path, was[3], was[4] or "")
    if U.IsCyrFont((fs:GetFont())) then return true end
    Restore(fs)
    return false
end

local function Put(fs)
    local en = raw[fs]
    local uk = ns.WordsWanted() and type(en) == "string" and W.Translate(en) or nil
    local cyr = uk ~= nil and (U.Plain(uk) or ""):find(CYR) ~= nil
    local nofont = cyr and not U.CyrFontPath()
    if uk and cyr and not Cyr(fs) then uk = nil end
    if uk then
        if not cyr then Restore(fs) end
        fs:SetText(uk)
        mine[fs] = true
    else
        if mine[fs] then
            mine[fs] = nil
            fs:SetText(en)
        end
        Restore(fs)
        if not nofont and type(en) == "string" and ns.WordsWanted() and en:find("%a%a%a") then
            U.Missed("whatstraining", en, fs)
        end
    end
end

local function Apply(fs)
    if busy then return end
    busy = true
    local ok, err = pcall(Put, fs)
    busy = false
    if not ok and geterrorhandler then geterrorhandler()(err) end
end
S.Apply = Apply

local function OnText(fs, text)
    if busy then return end
    raw[fs] = type(text) == "string" and text or fs:GetText()
    U.SafeCall(Apply, fs)
end

local function OnFormatted(fs) if not busy then OnText(fs, fs:GetText()) end end

-- What's Training? changed the font of one that shows ours: that is the font to go back to; ours again.
local function OnFont(fs, byObject)
    if busy or not mine[fs] or not fonted[fs] then return end
    local p, s, f = fs:GetFont()
    busy = true
    pcall(Cyr, fs, { byObject and fs:GetFontObject() or nil, p, s, f })
    busy = false
end

local function Hook(fs)
    if hooked[fs] or type(fs) ~= "table" or not fs.SetText or (fs.IsForbidden and fs:IsForbidden()) then return end
    hooked[fs] = true
    hooksecurefunc(fs, "SetText", OnText)
    if fs.SetFormattedText then hooksecurefunc(fs, "SetFormattedText", OnFormatted) end
    hooksecurefunc(fs, "SetFont", function(self) OnFont(self, false) end)
    if fs.SetFontObject then hooksecurefunc(fs, "SetFontObject", function(self) OnFont(self, true) end) end
    raw[fs] = raw[fs] or fs:GetText()
    if ns.On() then U.SafeCall(Apply, fs) end
end
S.Hook = Hook

local function HookButton(b)
    if buttons[b] or not b.GetFontString then return end
    buttons[b] = true
    hooksecurefunc(b, "SetText", function(self, text)
        if busy then return end
        local fs = self:GetFontString()
        if not fs then return end
        Hook(fs)
        OnText(fs, text)
    end)
    local fs = b:GetFontString()
    if fs then Hook(fs) end
end

local function Regions(f)
    if not Owned(f) then return end
    if Is(f, "Button") then HookButton(f) end
    if not f.GetRegions then return end
    for _, r in ipairs({ f:GetRegions() }) do
        if not hooked[r] and Is(r, "FontString") then Hook(r) end
    end
end

-- A frame and everything in it, once (later font strings come in through CreateFontString).
local function Walk(f, budget)
    if type(f) ~= "table" or walked[f] or budget[1] <= 0 then return end
    walked[f] = true
    budget[1] = budget[1] - 1
    if (f.IsForbidden and f:IsForbidden()) or Is(f, "GameTooltip") then return end
    Regions(f)
    if f.GetChildren then
        for _, c in ipairs({ f:GetChildren() }) do Walk(c, budget) end
    end
end

-- A window made after the last scan (on Forever the main window, WhatsTrainingFloatingFrame, is made on
-- first open): its template texts and buttons are not made by CreateFontString, so scan it as a root.
local function NewRoot()
    for _, name in ipairs(ROOTS) do
        local f = rawget(_G, name)
        if type(f) == "table" and not shown[f] then return true end
    end
    return false
end

local function Flush()
    queued = false
    local list = queue
    queue = {}
    if not ns.On() then return end
    for f in pairs(list) do U.SafeCall(Regions, f) end
    if NewRoot() then U.SafeCall(S.Scan) end
end

local function OnCreate(self)
    if queue[self] then return end
    queue[self] = true
    if not queued then
        queued = true
        C_Timer.After(0, Flush)
    end
end

local installed = false
function S.Install()
    if installed then return end
    installed = true
    local done = {}
    for _, kind in ipairs(KINDS) do
        local ok, f = pcall(CreateFrame, kind)
        local mt = ok and f and getmetatable(f)
        local t = mt and type(mt.__index) == "table" and mt.__index or nil
        if t and not done[t] and type(t.CreateFontString) == "function" then
            done[t] = true
            hooksecurefunc(t, "CreateFontString", OnCreate)
        end
    end
end

-- Every window of What's Training? we can reach now (after login, when it shows, after "on").
function S.Scan()
    local budget = { 20000 }
    for _, name in ipairs(ROOTS) do
        local f = rawget(_G, name)
        if type(f) == "table" then
            walked[f] = nil
            Walk(f, budget)
            if f.HookScript and not shown[f] then
                shown[f] = true
                f:HookScript("OnShow", function(self)
                    if not ns.On() then return end
                    wipe(walked)
                    U.SafeCall(Walk, self, { 5000 })
                    U.SafeCall(ns.Tips.Install)
                end)
            end
        end
    end
end

-- Redo every hooked font string: ours when wanted, the English when not.
function S.Sync()
    for fs in pairs(hooked) do Apply(fs) end
end

function S.Count()
    local n = 0
    for fs in pairs(fonted) do if mine[fs] and U.IsCyrFont((fs:GetFont())) then n = n + 1 end end
    return n
end

function S.Hooked()
    local n = 0
    for _ in pairs(hooked) do n = n + 1 end
    return n
end
