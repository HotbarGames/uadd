-- UADD - Mastercraft: our words on Mastercraft's own font strings, with a font that has Ukrainian letters.
--
-- How we get in. Mastercraft keeps its addon table private and stays on English, but every text it
-- shows goes through its own font strings (ns.Text, UI.Label): each one carries mcSetText and mcSetFont
-- (the game's own setters, kept by Mastercraft), mcRaw (the English it was given) and mcSize/mcFlags.
-- No other addon puts those fields on a font string, so rawget(fs, "mcSetText") tells us it is
-- Mastercraft's. We find them three ways:
--   * a post-hook on CreateFontString of the frame kinds (Frame, Button, ...): the frame that made one
--     is looked at on the next frame (Mastercraft fills the fields right after it makes the string);
--   * Mastercraft's named windows and every child of UIParent, once after login (made before us);
--   * the named windows again when they show.
-- Each one gets its own hooksecurefunc on SetText and SetFont (never a shared metatable). After
-- Mastercraft sets its English, we write our Ukrainian with mcSetText and give that one font string
-- UADD's Cyrillic font at Mastercraft's size (read back: S.Count counts only those that really have it).
-- Where Mastercraft would shrink a translated text to fit (mcFitTo, its button; or a one-line label that
-- is cut off), we shrink it the same way, one point at a time, to mcMinSize or 3/4 of its size.
-- Headings in capitals (ns.SetUpper: mcUpper) are translated from mcUpper and put in Ukrainian capitals.
-- Off, or the hold key: Mastercraft's English (mcRaw) and its own font again.

local _, ns = ...
local U = UADD
local W = ns.Words
local S = {}
ns.Screen = S

local CYR = "[\208-\210]"
local hooked = setmetatable({}, { __mode = "k" })   -- fs -> true: our hooks are on it
local mine = setmetatable({}, { __mode = "k" })     -- fs -> true: it shows our Ukrainian
local fonted = setmetatable({}, { __mode = "k" })   -- fs -> { path, size, flags } it had before ours
local fits = setmetatable({}, { __mode = "k" })     -- box -> true: refits on OnSizeChanged
local shown = {}                                    -- root window -> true: rescanned on OnShow
local busy = false
local queue, queued = {}, false
local walked = setmetatable({}, { __mode = "k" })
local ROOTS = { "MastercraftFrame", "MastercraftCompact", "MastercraftMinimapButton", "MastercraftFarmHUD",
    "MastercraftFishBar", "MastercraftFishRecap", "MastercraftFishWindow", "MastercraftGoals",
    "MastercraftLFGPanel", "MastercraftMiniGuide", "MastercraftNeverBank", "MastercraftRecipePanel",
    "MastercraftAltView", "MastercraftDetails", "MastercraftTradeBoard", "MastercraftConfirm" }
local KINDS = { "Frame", "Button", "CheckButton", "StatusBar", "ScrollFrame", "Slider", "EditBox" }

local function Ours(fs) return type(fs) == "table" and rawget(fs, "mcSetText") ~= nil end
S.Ours = Ours

-- The English Mastercraft wants shown, and whether it is a heading in capitals.
local function English(fs)
    local raw, up = rawget(fs, "mcRaw"), rawget(fs, "mcUpper")
    if type(up) == "string" and type(raw) == "string" and raw == up:upper() then return up, true end
    return raw, false
end

local function Font(fs, on)
    if on then
        local path = U.CyrFontPath()
        if not path then return end
        local was = fonted[fs]
        if not was then
            local p, s, f = fs:GetFont()
            was = { p, s, f }
        end
        local size = rawget(fs, "mcSize") or was[2]
        local flags = rawget(fs, "mcSize") and rawget(fs, "mcFlags") or was[3]
        if not size then return end
        fs.mcSetFont(fs, path, size, flags or "")
        local now = fs:GetFont()
        fonted[fs] = U.IsCyrFont(now) and was or nil
    elseif fonted[fs] then
        local was = fonted[fs]
        fonted[fs] = nil
        local size = rawget(fs, "mcSize")
        -- (Mastercraft's row fitter passes the font back to SetFont, so mcPath can be ours by now)
        local path = rawget(fs, "mcPath")
        if path and U.IsCyrFont(path) then path = nil end
        if size then
            fs.mcSetFont(fs, rawget(fs, "mcScript") or path or was[1] or STANDARD_TEXT_FONT,
                size, rawget(fs, "mcFlags") or "")
        elseif was[1] and was[2] then
            fs.mcSetFont(fs, was[1], was[2], was[3] or "")
        end
    end
end

-- The button a label must fit in: mcFitTo, or else the button whose .label it is. Mastercraft takes
-- mcFitTo off where it sizes the button itself, but some of those (Clear, Track, Chat alert) are sized
-- for the English word (ns.L on an English client), so our longer word would run out of the button.
local function Box(fs)
    local box = rawget(fs, "mcFitTo")
    if type(box) == "table" then return box end
    local p = fs.GetParent and fs:GetParent()
    if type(p) == "table" and rawget(p, "label") == fs and p.GetWidth then return p end
    return nil
end

-- Mastercraft's FitGreek, for our Ukrainian: a little smaller while it runs out of its button, or while
-- a one-line label is cut off. Never below mcMinSize (or 3/4 of the size, at least 8).
local function Fit(fs)
    local size = rawget(fs, "mcSize")
    if type(size) ~= "number" or not fonted[fs] then return end
    local box = Box(fs)
    local w = box and (box:GetWidth() - 10) or fs:GetWidth()
    if not w or w <= 1 then return end
    local wraps = fs.CanWordWrap and fs:CanWordWrap()
    if not box and wraps then return end
    local path, s, flags = fs:GetFont()
    local min = rawget(fs, "mcMinSize") or math.max(8, math.floor(size * 0.75))
    s = s or size
    local function TooWide()
        if not wraps and fs.IsTruncated and fs:IsTruncated() then return true end
        if box then
            return (fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth() or fs:GetStringWidth()) > w
        end
        return false
    end
    while s > min and TooWide() do
        s = s - 1
        fs.mcSetFont(fs, path, s, flags)
    end
end

local function Refit(box)
    for fs in pairs(mine) do
        if fonted[fs] and Box(fs) == box then
            Font(fs, true)
            Fit(fs)
        end
    end
end

-- After Mastercraft set a text (or when we redo one): ours when we have it, its English otherwise.
local function Apply(fs)
    if busy then return end
    local raw, up = English(fs)
    local uk = ns.WordsWanted() and type(raw) == "string" and W.Translate(raw) or nil
    if uk and up then uk = W.Upper(uk) end
    -- No Cyrillic font: Mastercraft's English stays (no boxes), and it is not a missed text.
    local nofont = uk ~= nil and (U.Plain(uk) or ""):find(CYR) ~= nil and not U.CyrFontPath()
    if nofont then uk = nil end
    busy = true
    if uk then
        fs.mcSetText(fs, uk)
        mine[fs] = true
        if U.Plain(uk) and U.Plain(uk):find(CYR) then Font(fs, true) Fit(fs) else Font(fs, false) end
        local box = Box(fs)
        if box and box.HookScript and not fits[box] then
            fits[box] = true
            box:HookScript("OnSizeChanged", function(b) if ns.WordsWanted() then U.SafeCall(Refit, b) end end)
        end
    else
        if mine[fs] then
            mine[fs] = nil
            if type(rawget(fs, "mcRaw")) == "string" then fs.mcSetText(fs, rawget(fs, "mcRaw")) end
        end
        Font(fs, false)
        if not nofont and type(raw) == "string" and ns.WordsWanted() and raw:find("%a%a%a") then U.Missed("mastercraft", raw, fs) end
    end
    busy = false
end
S.Apply = Apply

local function OnFont(fs)
    if busy or not mine[fs] then return end
    busy = true
    Font(fs, true)
    Fit(fs)
    busy = false
end

local function OnText(fs) U.SafeCall(Apply, fs) end

local function Hook(fs)
    if hooked[fs] or not Ours(fs) then return end
    hooked[fs] = true
    hooksecurefunc(fs, "SetText", OnText)
    hooksecurefunc(fs, "SetFont", OnFont)
    if ns.On() then OnText(fs) end
end
S.Hook = Hook

local function Regions(f)
    if not f.GetRegions then return end
    for _, r in ipairs({ f:GetRegions() }) do
        if not hooked[r] and Ours(r) then Hook(r) end
    end
end

-- A frame and everything in it, once (later font strings come in through CreateFontString).
local function Walk(f, budget)
    if type(f) ~= "table" or walked[f] or budget[1] <= 0 then return end
    walked[f] = true
    budget[1] = budget[1] - 1
    if f.IsForbidden and f:IsForbidden() then return end
    Regions(f)
    if f.GetChildren then
        for _, c in ipairs({ f:GetChildren() }) do Walk(c, budget) end
    end
end

local function Flush()
    queued = false
    local list = queue
    queue = {}
    for f in pairs(list) do U.SafeCall(Regions, f) end
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
        local t = U.WidgetMethods(kind)      -- never a new EditBox: it would take the keyboard
        if t and not done[t] and type(t.CreateFontString) == "function" then
            done[t] = true
            hooksecurefunc(t, "CreateFontString", OnCreate)
        end
    end
end

-- Every window of Mastercraft's we can reach now (after login, when it shows, after "on").
function S.Scan()
    local budget = { 30000 }
    for _, name in ipairs(ROOTS) do
        local f = rawget(_G, name)
        if type(f) == "table" then
            walked[f] = nil
            Walk(f, budget)
            if f.HookScript and not shown[f] then
                shown[f] = true
                f:HookScript("OnShow", function(self)
                    if ns.On() then walked[self] = nil U.SafeCall(Walk, self, { 5000 }) end
                end)
            end
        end
    end
    if UIParent and UIParent.GetChildren then
        for _, c in ipairs({ UIParent:GetChildren() }) do Walk(c, budget) end
    end
end

-- Redo every hooked font string: ours when wanted, Mastercraft's English when not.
function S.Sync()
    for fs in pairs(hooked) do OnText(fs) end
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
