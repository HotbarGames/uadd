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
-- that one font string UADD's Cyrillic font at its own size through the core (U.CyrFix: our font object
-- first, a file by hand only on a label whose font was set by hand; read back: S.Count counts only those
-- that really have it; no Cyrillic font: the English stays). The size is never made smaller (lesson 5).
-- When What's Training? sets its font again while ours is on (a pooled row takes another font object),
-- that font is its own now: saved, ours over it. Off, or the hold key: its English first, then its own
-- font back (U.CyrUnfix): the object it had last, and its own file at its latest size.

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
local kept = Weak()       -- fs -> its own font before ours (U.SaveFont, kept by U.CyrFix)
local buttons = Weak()    -- button -> true: our SetText hook is on it
local owned = Weak()      -- frame -> true: it is What's Training?'s
local walked = Weak()
local foreign = Weak()    -- frame -> true: looked at once, with a parent, not What's Training?'s (or forbidden):
                          -- its next CreateFontString leaves at once (an OnShow walk still finds a late one)
local shown = {}
local busy = false
local queue, queued = {}, false
local ROOTS = { "WhatsTrainingOverlay", "WhatsTrainingFrame", "WhatsTrainingSettings",
    "WhatsTrainingTrainerController", "WhatsTrainingTrainAllConfirmation", "WhatsTrainingTrainAllButton",
    "WhatsTrainingFloatingFrame", "WhatsTrainingCraftingPage" }

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

-- Its own font back (the caller puts the English back first: while ours still shows Cyrillic the core
-- keeps our font and the record, lesson 45).
local function Restore(fs)
    if kept[fs] then pcall(U.CyrUnfix, fs, kept) end
end

-- UADD's Cyrillic font at the size the font string has, through the core. True only when it really has
-- it now (read back); no take: its own font back.
local function Cyr(fs)
    if not U.CyrFontPath() then return false end
    local ok, took = pcall(U.CyrFix, fs, kept)
    return ok and took == true and U.IsCyrFont((fs:GetFont())) or false
end

-- Our words, else (a whole text that is one game name) UALL Forever's (Names.lua).
local function Put(fs)
    local en = raw[fs]
    local uk = ns.WordsWanted() and type(en) == "string" and (W.Translate(en) or ns.GameName(en)) or nil
    local cyr = uk ~= nil and (U.Plain(uk) or ""):find(CYR) ~= nil
    local nofont = cyr and not U.CyrFontPath()
    if uk and cyr and not Cyr(fs) then uk = nil end
    if uk then
        fs:SetText(uk)
        mine[fs] = true
        if not cyr then Restore(fs) end             -- text first, then the font (lesson 45)
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
    if not ok then error(err, 0) end          -- every caller runs it through U.SafeCall
end
S.Apply = Apply

local function OnText(fs, text)
    if busy then return end
    raw[fs] = type(text) == "string" and text or fs:GetText()
    U.SafeCall(Apply, fs)
end

local function OnTextHook(fs, text) U.SafeCall(OnText, fs, text) end
local function OnFormatted(fs) if not busy then U.SafeCall(OnText, fs, fs:GetText()) end end

-- What's Training? changed the font of one that shows ours. Ours still on (the client keeps a file set by
-- hand over SetFontObject): nothing to do. Ours gone: U.CyrFix saves that font as its own and puts ours
-- over it; no take: the English back, never Cyrillic in a Latin file.
local function OnFont(fs)
    if busy or not mine[fs] or not kept[fs] then return end
    busy = true
    local ok, took = pcall(Cyr, fs)             -- never left busy
    busy = false
    if not (ok and took) then U.SafeCall(Apply, fs) end
end

-- A new font object while our hand-set file stays (U.CyrOnOwn, or set by hand before us: the client keeps a file
-- set by hand over SetFontObject): that object is its own now, so held and off give it back, not the old one.
local function NewObject(fs)
    local was = kept[fs]
    if busy or not was or not (was.byhand or was.own) or not U.IsCyrFont((fs:GetFont())) then return end
    local o, unsafe = U.SafeFontObject(fs)
    local n = type(o) == "table" and o.GetName and o:GetName()
    if type(n) == "string" and n:find("^UADD_") then return end   -- one of ours: not the addon's choice
    was.object, was.unsafe = U.FontBase(o), unsafe or nil
end

local function OnSetFont(self) U.SafeCall(OnFont, self) end
local function OnSetFontObject(self)
    U.SafeCall(NewObject, self)
    U.SafeCall(OnFont, self)
end

local function Hook(fs)
    if hooked[fs] or type(fs) ~= "table" or not fs.SetText or (fs.IsForbidden and fs:IsForbidden()) then return end
    hooked[fs] = true
    hooksecurefunc(fs, "SetText", OnTextHook)
    if fs.SetFormattedText then hooksecurefunc(fs, "SetFormattedText", OnFormatted) end
    hooksecurefunc(fs, "SetFont", OnSetFont)
    if fs.SetFontObject then hooksecurefunc(fs, "SetFontObject", OnSetFontObject) end
    raw[fs] = raw[fs] or fs:GetText()
    if ns.On() then U.SafeCall(Apply, fs) end
end
S.Hook = Hook

local function OnButtonText(self, text)
    if busy then return end
    local fs = self:GetFontString()
    if not fs then return end
    Hook(fs)
    OnText(fs, text)
end

local function HookButton(b)
    if buttons[b] or not b.GetFontString then return end
    buttons[b] = true
    hooksecurefunc(b, "SetText", function(self, text) U.SafeCall(OnButtonText, self, text) end)
    local fs = b:GetFontString()
    if fs then Hook(fs) end
end

local function Forbidden(f)
    if not f.IsForbidden then return false end
    local ok, yes = pcall(f.IsForbidden, f)
    return not ok or yes
end

local function Regions(f)
    if Forbidden(f) or not Owned(f) then return end
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

local Flush
local function SafeFlush() U.SafeCall(Flush) end
local nQueued, QUEUE_MAX = 0, 2000                  -- more waiting than that: the rest found by the scans
Flush = function()
    if U.AfterCombat(SafeFlush) then return end     -- no look in combat (a BG): after it, every second
    queued = false
    local list = queue
    queue, nQueued = {}, 0
    if not ns.On() then return end
    for f in pairs(list) do
        -- "no": forbidden, or not What's Training?'s and with a parent (one with none yet may get one)
        local ok, own = pcall(function()
            if Forbidden(f) then return "no" end
            if Owned(f) then return "yes" end
            return f.GetParent and f:GetParent() and "no" or nil
        end)
        if ok and own == "yes" then U.SafeCall(Regions, f)
        elseif not ok or own == "no" then foreign[f] = true end
    end
    if NewRoot() then U.SafeCall(S.Scan) end
end

-- Every CreateFontString of the game passes here (core U.OnNewFontString, under U.SafeCall): table look-ups,
-- and the game's busy frames (nameplates, raid frames) by their name only (lesson 35).
local function OnCreate(self)
    if type(self) ~= "table" or foreign[self] or queue[self] or nQueued >= QUEUE_MAX then return end
    if U.GameMade(self) then foreign[self] = true return end
    queue[self], nQueued = true, nQueued + 1
    if not queued then
        queued = true
        C_Timer.After(0, SafeFlush)
    end
end

local installed = false
function S.Install()
    if installed then return end
    installed = true
    U.OnNewFontString(OnCreate)
end

local function OnRootShow(self)
    if not ns.On() then return end
    wipe(walked)
    U.SafeCall(Walk, self, { 5000 })
    U.SafeCall(ns.Tips.Install)
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
                f:HookScript("OnShow", function(self) U.SafeCall(OnRootShow, self) end)
            end
        end
    end
end

-- Redo every hooked font string: ours when wanted, the English when not.
function S.Sync()
    for fs in pairs(hooked) do U.SafeCall(Apply, fs) end   -- one bad string leaves the others done
end

function S.Count()
    local n = 0
    for fs in pairs(kept) do if mine[fs] and U.IsCyrFont((fs:GetFont())) then n = n + 1 end end
    return n
end

function S.Hooked()
    local n = 0
    for _ in pairs(hooked) do n = n + 1 end
    return n
end
