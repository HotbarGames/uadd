-- Auto Potion's FontStrings: each keeps its own English (the text Auto Potion set), so the hold key and
-- "/uadd autopotion off" put exactly that back (the same way as UADD_LayerSwap/Texts.lua).
--   * Auto Potion sets its labels once, at its own ADDON_LOADED (before this module runs), and the
--     class spell headers at PLAYER_LOGIN. Screen.lua finds those FontStrings when a page shows and calls
--     T.Hook once per FontString: hooksecurefunc on its own SetText (never the shared metatable), so a
--     text set again later (the Info page's "installed" marks) is caught too.
--   * A Button's SetText does not go through its FontString's SetText, so each button gets a hook too.
--   * A text is changed only when Words.lua knows it. Spell, item and class names, the macro names and
--     any text with Ukrainian letters stay as set.
--   * After a change the box around the text is fitted again (Screen.Refit): the Reset button's width,
--     and the click area of a check box with an icon, both measured the way Auto Potion measures them.

local _, ns = ...
local U = UADD
local T = {}
ns.Texts = T

local orig = {}       -- FontString -> the text Auto Potion set
local mine = {}       -- FontString -> the text we put in its place
local hooked = {}     -- FontString or Button -> true once its SetText is hooked
local stale = {}      -- FontString -> true: hidden at the last Sync, put right when it shows (T.Flush)
local guard = false   -- up while we set a text ourselves
local enWidth = {}    -- FontString -> the width of Auto Potion's text in its own font (for Screen.Refit)
local ukWidth = {}    -- FontString -> the width of our words in our font, as the box was fitted to them

local function Put(fs, text)
    local w = fs.GetStringWidth and fs:GetStringWidth() or 0
    guard = true
    local ok, err = pcall(fs.SetText, fs, text)
    guard = false
    if not ok then error(err, 0) end
    return w
end

-- Missed texts (UADD/Missed.lua): a check box's label is a spell or item name from the game, unless it
-- is one of the addon's own (those are all in the data), so check box labels are not noted.
local function Note(fs, en)
    local p = fs.GetParent and fs:GetParent()
    if p and p.GetObjectType and p:GetObjectType() == "CheckButton" then return end
    U.Missed("autopotion", en, fs)
end

-- One FontString as it should be now: our words while they are wanted, Auto Potion's otherwise.
-- quick (the hold key): the font is fixed only when our words were just put in.
function T.Apply(fs, quick)
    stale[fs] = nil
    local now = U.Plain(fs:GetText())   -- nil for a secret text: nothing of it is kept
    if mine[fs] == nil or now ~= mine[fs] then   -- Auto Potion's own text (new, or set again)
        orig[fs], mine[fs] = now, nil
    end
    if ns.WordsWanted() then
        if not mine[fs] then
            local uk = ns.Words.Text(orig[fs])
            if not uk then
                if orig[fs] then Note(fs, orig[fs]) end
                return ns.Fonts.Back(fs)
            end
            local w = Put(fs, uk)
            mine[fs], enWidth[fs] = uk, w
            ns.Fonts.Fix(fs)
            ukWidth[fs] = fs:GetStringWidth()
            return ns.Screen.Refit(fs, w, ukWidth[fs])
        elseif quick then return end
        ns.Fonts.Fix(fs)
    elseif mine[fs] then
        if orig[fs] ~= now then
            local w = Put(fs, orig[fs])
            ns.Screen.Refit(fs, ukWidth[fs] or w, enWidth[fs])
        end
        mine[fs], ukWidth[fs] = nil, nil
        ns.Fonts.Back(fs)
    end
end

local function OnText(fs)
    if guard or type(fs) ~= "table" then return end
    mine[fs] = nil
    if not ns.On() then return end
    U.SafeCall(T.Apply, fs, false)
end

function T.Hook(fs)
    if hooked[fs] then return end
    hooked[fs] = true
    hooksecurefunc(fs, "SetText", OnText)
    if fs.SetFormattedText then hooksecurefunc(fs, "SetFormattedText", OnText) end
end
function T.Hooked(fs) return hooked[fs] == true end

local function OnButton(b)
    if guard or type(b) ~= "table" or not b.GetFontString then return end
    local fs = b:GetFontString()
    if type(fs) ~= "table" then return end
    T.Hook(fs)
    OnText(fs)
end

function T.HookButton(b)
    if hooked[b] or not b.GetFontString then return end
    hooked[b] = true
    hooksecurefunc(b, "SetText", OnButton)
    ns.Fonts.HookButton(b)
end

-- Every shown text we know, as it should be now (after the hold key). A hidden one is marked:
-- T.Flush puts it right when its page shows.
function T.Sync()
    for fs in pairs(orig) do
        if fs:IsVisible() then U.SafeCall(T.Apply, fs, true) else stale[fs] = true end
    end
end

function T.Flush()
    if next(stale) == nil then return end
    for fs in pairs(stale) do
        if fs:IsVisible() then U.SafeCall(T.Apply, fs, true) end
    end
end

-- "/uadd autopotion off": every text back to Auto Potion's, its box fitted again, then forget them.
-- The box is fitted from the width our words had when they were put (ukWidth): by now the font may be
-- Auto Potion's again (Screen.Restore), so measuring now would give another width.
function T.Restore()
    for fs, t in pairs(mine) do
        if U.Plain(fs:GetText()) == t then
            local ok, w = pcall(Put, fs, orig[fs])
            if ok then U.SafeCall(ns.Screen.Refit, fs, ukWidth[fs] or w, enWidth[fs]) end
        end
    end
    wipe(mine) wipe(orig) wipe(stale) wipe(enWidth) wipe(ukWidth)
end

-- For the status line and the checks: how many texts show our words now.
function T.Count()
    local n = 0
    for fs, t in pairs(mine) do if U.Plain(fs:GetText()) == t then n = n + 1 end end
    return n
end

-- For the checks.
function T.Original(fs) return orig[fs] end
function T.Stale(fs) return stale[fs] == true end
