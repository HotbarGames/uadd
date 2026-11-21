-- UADD - Mastercraft: our words on Mastercraft's own font strings, with a font that has Ukrainian letters.
--
-- How we get in. Mastercraft keeps its addon table private and stays on English, but every text it
-- shows goes through its own font strings (ns.Text, UI.Label): each one carries mcSetText and mcSetFont
-- (the game's own setters, kept by Mastercraft), mcRaw (the English it was given) and mcSize/mcFlags.
-- No other addon puts those fields on a font string, so rawget(fs, "mcSetText") tells us it is
-- Mastercraft's. We find them three ways (Find.lua):
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
-- Off, or the hold key: Mastercraft's own text and font again (Restore: its English, or the language it
-- is on now, drawn by its own SetText; a text it changed since is left alone).

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
local busy = false

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
            was = U.SaveFont(fs)                -- its font object too (lesson 18)
            was[1], was[2], was[3] = was.path, was.size, was.flags
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
        elseif was.object then                  -- its font object back, never a pinned file
            U.FontBack(fs, { object = was.object })
            if was.own then fs.mcSetFont(fs, was[1], was[2], was[3] or "") end
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

-- A line that stayed English because UALL Forever said "not now" for a game name in it (in combat, at
-- login) is tried again a few seconds later, up to 3 times for the same English.
local retry = setmetatable({}, { __mode = "k" })   -- fs -> { English, tries }
local retrying = false
local Apply
local function Retry()
    retrying = false
    for fs, r in pairs(retry) do
        if rawget(fs, "mcRaw") == r[1] then U.SafeCall(Apply, fs) else retry[fs] = nil end
    end
end
local function Later(fs, raw)
    local r = retry[fs]
    if not r or r[1] ~= raw then r = { raw, 0 } retry[fs] = r end
    r[2] = r[2] + 1
    if r[2] > 3 then retry[fs] = nil return end
    if not retrying and C_Timer and C_Timer.After then
        retrying = true
        C_Timer.After(2, Retry)
    end
end
S.Retrying = function() return next(retry) ~= nil end

-- Our words off one font string: its text as Mastercraft would draw it now (lesson 19: never a wrong
-- language). Only a text that still is our Ukrainian is put back; one Mastercraft set since (its own
-- language picked outside its menu) stays as it is. On English: its English with the game's setter, as
-- always. In another of its languages: through Mastercraft's own SetText, which draws that language and
-- sets that language's font itself (Greek, Korean, ...); our font goes only where it is still ours.
local function Restore(fs)
    local wrote = mine[fs]
    mine[fs] = nil
    local raw = rawget(fs, "mcRaw")
    local still = type(wrote) == "string" and type(raw) == "string" and fs:GetText() == wrote
    if not ns.Lang or ns.Lang.MastercraftEnglish() then
        if still then fs.mcSetText(fs, raw) end
        Font(fs, false)
        return
    end
    if still then fs:SetText(raw) end
    if fonted[fs] and U.IsCyrFont((fs:GetFont())) then Font(fs, false) else fonted[fs] = nil end
end

-- Any error while we write: Mastercraft's text as it would draw it, in its own font (the worst we may do
-- is leave a text untranslated). The error is said once (U.SafeCall).
local function Back(fs)
    pcall(Restore, fs)
    mine[fs] = nil
    pcall(Font, fs, false)
end

-- Every write under busy (our own SetText / SetFont calls must not come back to us) goes through here:
-- busy is reset on every path, an error included, or off and the hold key would stop working.
local function Guarded(fs, fn, ...)
    busy = true
    local ok = U.SafeCall(fn, fs, ...)
    if not ok then Back(fs) end
    busy = false
end

local Write

-- After Mastercraft set a text (or when we redo one): ours when we have it, its English otherwise.
Apply = function(fs)
    if busy then return end
    local raw, up = English(fs)
    local uk, waited
    if ns.WordsWanted() and type(raw) == "string" then
        -- A raw cell whose words are glued to a player's name or note (Raw.lua) has its own reader, which
        -- knows the layout; any error there leaves Mastercraft's English.
        local own = rawget(fs, "mcWords")
        if type(own) == "function" then
            local ok, a, b = pcall(own, raw)
            if ok and (a == nil or type(a) == "string") then uk, waited = a, b and true or false end
        else
            uk, waited = W.Try(raw)
        end
    end
    if uk or not waited then retry[fs] = nil else Later(fs, raw) end
    if uk and up then uk = W.Upper(uk) end
    -- No Cyrillic font: Mastercraft's English stays (no boxes), and it is not a missed text.
    local nofont = uk ~= nil and (U.Plain(uk) or ""):find(CYR) ~= nil and not U.CyrFontPath()
    if nofont then uk = nil end
    Guarded(fs, Write, uk, raw, waited, nofont)
end
S.Apply = Apply

Write = function(fs, uk, raw, waited, nofont)
    if uk then
        fs.mcSetText(fs, uk)
        mine[fs] = uk                       -- what we wrote: off puts back only while it is still there
        if U.Plain(uk) and U.Plain(uk):find(CYR) then Font(fs, true) Fit(fs) else Font(fs, false) end
        local box = Box(fs)
        if box and box.HookScript and not fits[box] then
            fits[box] = true
            box:HookScript("OnSizeChanged", function(b) if ns.WordsWanted() then U.SafeCall(Refit, b) end end)
        end
    else
        if mine[fs] then Restore(fs) else Font(fs, false) end
        if not nofont and not waited and type(raw) == "string" and ns.WordsWanted() and raw:find("%a%a%a") then U.Missed("mastercraft", raw, fs) end
    end
end

local function Refont(fs)
    Font(fs, true)
    Fit(fs)
end

local function OnFont(fs)
    -- (not wanted: Mastercraft is switching to another language and sets its own font next)
    if busy or not mine[fs] or not ns.WordsWanted() then return end
    Guarded(fs, Refont)
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

-- Finding the strings: Find.lua (S.Install, S.Scan).

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
