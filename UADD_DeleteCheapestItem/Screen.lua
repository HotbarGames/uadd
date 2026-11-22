-- UADD - DeleteCheapestItem Reloaded: its windows (the main window, the ignored items window, its settings page
-- with the profiles part), and whose tooltip a line is on (for Words.Maybe).
--
-- Its windows are found by their own frame names (the main window, the ignored items window made on first open,
-- the settings canvas and panel, the profiles part). Each text of theirs gets a SetText hook once: each English
-- text we know gets ours, with our font read back (lesson 2); a text the font cannot draw keeps its English.
-- New parts (rows made on a later update, the ignored items window) are found when the game makes a frame whose
-- name starts so, or whose parent is one we know: one walk on the next frame, never in combat (lesson 35).
--   * Off and the hold key: each text goes back to its English only while it still shows ours (lesson 23).
--   * Its hooks run under ns.Guard, not U.Safe: they put the English back after an off for errors too (lesson 19).
--     They are put on only while the module is on (lesson 37); off only gives things back.
--   * The player's profile names stay as typed (lesson 13): its profile picker and the name box are not walked.
--   * Forbidden and protected frames, text boxes and tooltips are not walked (tooltips: U.TipLines).
-- The frame names are the addon's own; none is ever built from our words.

local _, ns = ...
local U = UADD
local A = UADD.AceFont
local S = {}
ns.Screen = S

local W = ns.Words
local find = string.find
local CYR = "[\208-\210]"
local APP = "DeleteCheapestItem"
local MAXFRAMES = 4000                     -- frames one walk visits at most (its main window holds 100 rows)
local ROOTS = { "DCIFrame", "DCI_IgnoredItemsFrame", "DCI_ConfigCanvas", "DCI_ConfigPanel", "DCI_ProfileControls" }
local SKIP = { DCI_ProfileSelect = true, DCI_ProfileName = true }     -- the player's profile names (lesson 13)
local PREFIX = "DCI_"

local rec = setmetatable({}, { __mode = "k" })       -- font string -> { en, uk } while it shows ours
local hooked = setmetatable({}, { __mode = "k" })    -- font strings with our SetText hook
local known = setmetatable({}, { __mode = "k" })     -- frames of its windows met on a walk
local fonted = setmetatable({}, { __mode = "k" })
local shown = {}                                      -- roots with our OnShow hook
local busy, pending, capped, frameHook = false, false, false, false
local count = 0
local tipOwner, tipAns

local function Wanted() return ns.WordsWanted() end
local function Forbidden(f) return type(f) ~= "table" or (f.IsForbidden and f:IsForbidden()) end

-- Our font on a text, read back; true when it can draw Cyrillic now.
local function Font(fs)
    if fonted[fs] then
        local ok, path = pcall(fs.GetFont, fs)
        if ok and U.IsCyrFont(path) then return true end
    end
    if A and A.Set then pcall(A.Set, fs, APP) end
    local ok, path = pcall(fs.GetFont, fs)
    if ok and U.IsCyrFont(path) then fonted[fs] = true return true end
    return false
end
local function Unfont(fs) if fonted[fs] then fonted[fs] = nil if A and A.Back then pcall(A.Back, fs) end end end
S.Font, S.Unfont = Font, Unfont

local function Put(fs, t)
    busy = true
    local ok = pcall(fs.SetText, fs, t)
    busy = false
    return ok
end

-- One text as it should be now: ours (font read back) or the addon's English.
local function Apply(fs)
    if busy then return end
    local ok, t = pcall(fs.GetText, fs)
    if not ok then return end
    t = U.Plain(t)
    local r = rec[fs]
    if Wanted() then
        if r and t == r.uk then
            if Font(fs) then return end
            Put(fs, r.en)                             -- the font cannot draw it now: the English, no boxes
            rec[fs] = nil
            Unfont(fs)
            return
        end
        rec[fs] = nil
        if not t or t == "" then Unfont(fs) return end
        if find(t, CYR) then return end               -- another addon's Ukrainian, or a name: left as it is
        local uk = W.Translate(t)
        if not uk then Unfont(fs) return end
        Put(fs, uk)
        if Font(fs) then
            rec[fs] = { en = t, uk = uk }
            count = count + 1
            return
        end
        Put(fs, t)
        Unfont(fs)
    else
        if r and t == r.uk then Put(fs, r.en) end     -- only while it is still ours (lesson 23)
        rec[fs] = nil
        Unfont(fs)                                    -- the English first, then its font
    end
end

local OnSet = ns.Guard(function(self) Apply(self) end)

local function Hook(fs)
    if not hooked[fs] and ns.On() then
        hooked[fs] = true
        hooksecurefunc(fs, "SetText", OnSet)
        if fs.SetFormattedText then hooksecurefunc(fs, "SetFormattedText", OnSet) end
    end
    Apply(fs)
end

-- A button's own SetText draws into its label without the label's SetText (its delete or sell button, drawn
-- again while the window is shown): the label is put right after each call.
local buttons = setmetatable({}, { __mode = "k" })    -- buttons with our SetText hook
local OnButton = ns.Guard(function(self)
    local fs = self.GetFontString and self:GetFontString()
    if type(fs) ~= "table" or Forbidden(fs) then return end
    if ns.On() then Hook(fs) else Apply(fs) end
end)
local function HookButton(f)
    if buttons[f] or not ns.On() or type(f.GetFontString) ~= "function" then return end
    buttons[f] = true
    hooksecurefunc(f, "SetText", OnButton)
    if f.SetFormattedText then hooksecurefunc(f, "SetFormattedText", OnButton) end
end

local function Name(f)
    local ok, n = pcall(function() return f.GetName and f:GetName() end)
    return ok and U.Plain(n) or nil
end

local function Walk(f, depth, seen)
    if depth > 12 or Forbidden(f) then return end
    if seen.n >= MAXFRAMES then
        if not capped then
            capped = true
            if U.debug then U.Print("DeleteCheapestItem Reloaded: обхід вікна зупинився на " .. MAXFRAMES .. " рамках") end
        end
        return
    end
    seen.n = seen.n + 1
    local name = Name(f)
    if name and SKIP[name] then return end
    if f.IsProtected and f:IsProtected() then return end
    if f.GetObjectType and f:GetObjectType() == "EditBox" then return end
    if type(f.AddLine) == "function" then return end                   -- a tooltip: U.TipLines has it
    known[f] = true
    local kind = f.GetObjectType and f:GetObjectType()
    if kind == "Button" or kind == "CheckButton" then
        HookButton(f)
        OnButton(f)
    end
    for _, r in ipairs(U.Regions(f)) do
        if not Forbidden(r) and r.GetObjectType and r:GetObjectType() == "FontString" then
            if ns.On() then Hook(r) else Apply(r) end
        end
    end
    for _, c in ipairs(U.Children(f)) do Walk(c, depth + 1, seen) end
end

-- Off walks only the texts it already knows: it never hooks anything new.
local function WalkAll()
    if not ns.On() then
        for fs in pairs(hooked) do U.SafeCall(Apply, fs) end
        return
    end
    local seen = { n = 0 }
    for _, name in ipairs(ROOTS) do
        local f = rawget(_G, name)
        if type(f) == "table" and not Forbidden(f) then
            if not shown[f] and f.HookScript then
                shown[f] = true
                pcall(f.HookScript, f, "OnShow", ns.Guard(function() if ns.On() then S.Later() end end))
            end
            Walk(f, 0, seen)
        end
    end
end

-- One walk on the next frame, after combat.
function S.Later()
    if pending then return end
    pending = true
    local function Run()
        if U.AfterCombat(Run) then return end
        pending = false
        if ns.On() then U.SafeCall(WalkAll) end
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, Run) else Run() end
end

-- The game made a frame: is it a part of its windows? (its name, or a parent we know; no lookup)
local function OnNewFrame(_, name, parent)
    if not ns.On() then return end
    name = U.Plain(name)
    if name then
        if name:sub(1, #PREFIX) ~= PREFIX then return end
    elseif type(parent) ~= "table" or not known[parent] then
        return
    end
    S.Later()
end

-- Is GameTooltip's owner its main window (its info button, its rows) or its minimap button? (a few parent
-- steps, no lookups; the answer is kept for the same owner)
function S.OwnsTip()
    local tip = GameTooltip
    local ok, o = pcall(function() return tip and tip.GetOwner and tip:GetOwner() end)
    if not ok or not o then return false end
    if o == tipOwner then return tipAns end
    local first, yes = o, false
    local main = rawget(_G, "DCIFrame")
    for _ = 1, 12 do
        if Forbidden(o) then break end
        if o == main or known[o] then yes = true break end
        local name = Name(o)
        if name and find(name, "DeleteCheapestItem", 1, true) then yes = true break end   -- its minimap button
        o = o.GetParent and o:GetParent()
        if not o then break end
    end
    tipOwner, tipAns = first, yes
    return yes
end

-- ── On, off, the hold key ─────────────────────────────────────────────────────────────────────

function S.Install()
    if not ns.On() then return end
    if not frameHook then frameHook = U.OnNewFrame(OnNewFrame) end
    tipOwner = nil
    WalkAll()
end

-- Now as it should be: ours or the English, in every text of its windows.
function S.Sync()
    tipOwner = nil
    for fs in pairs(hooked) do U.SafeCall(Apply, fs) end
    if ns.On() then WalkAll() end
end

-- Off: everything back as the addon draws it.
function S.Remove()
    for fs in pairs(hooked) do U.SafeCall(Apply, fs) end
    for fs in pairs(fonted) do Unfont(fs) end
    if A and A.Stop then pcall(A.Stop, APP) end
    tipOwner = nil
    count = 0
end

function S.Count() return count end
function S.Shown()
    local n = 0
    for _ in pairs(rec) do n = n + 1 end
    return n
end
