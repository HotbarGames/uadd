-- LayerSwap's FontStrings: each keeps its own English (the text LayerSwap set), so the hold key and
-- "/uadd layerswap off" put exactly that back (the same way as UADD_ForeverXPBar/Texts.lua).
--   * Screen.lua finds the FontStrings and calls T.Hook once per FontString: hooksecurefunc on its own
--     SetText and SetFormattedText (never the shared FontString metatable).
--   * A Button's SetText does not go through its FontString's SetText, so each button gets its own
--     hook too (T.HookButton). It runs right after the button's text is set and before LayerSwap
--     measures that text, so a long Ukrainian label is measured (and gets the smaller font) as English would.
--   * The panel sets its texts every second. The hook is cheap: a number-only text costs one memo
--     lookup in Words.lua; a text we already know costs one more. Our font goes on once.
--   * A text is changed only when Words.lua knows it. Player names, zone names, numbers and any text
--     with Ukrainian letters stay as set.
--   * LayerSwap never reads its FontStrings back, so what it sends and parses stays English.

local _, ns = ...
local U = UADD
local T = {}
ns.Texts = T

local orig = {}       -- FontString -> the text LayerSwap set
local mine = {}       -- FontString -> the text we put in its place
local hooked = {}     -- FontString or Button -> true once its SetText is hooked
local stale = {}      -- FontString -> true: hidden at the last Sync, put right when it shows (T.Flush)
local guard = false   -- up while we set a text ourselves
local lastUk, lastEn = {}, {}   -- per FontString: the last Ukrainian we put there, and its English
local back, backSize = {}, 0    -- our Ukrainian -> its English, any FontString
local hookCalls = 0             -- for the checks: how often a SetText hook ran

local function Put(fs, text)
    guard = true
    local ok, err = pcall(fs.SetText, fs, text)
    guard = false
    if not ok then error(err, 0) end
end

local function Remember(fs, uk, en)
    lastUk[fs], lastEn[fs] = uk, en
    if back[uk] == nil then
        if backSize > 2000 then wipe(back) backSize = 0 end
        back[uk], backSize = en, backSize + 1
    end
end

-- No Cyrillic font took on our words (Fonts.Fix false; also from its font hook, Fonts.lua): LayerSwap's English
-- back first, then its font (lesson 45). A failed fix is never watched by the box guard.
function T.English(fs)
    if mine[fs] and UADD.Plain(fs:GetText()) == mine[fs] then Put(fs, orig[fs]) end
    mine[fs] = nil
    ns.Fonts.Back(fs)
end

-- One FontString as it should be now: our words while they are wanted, LayerSwap's otherwise.
-- quick (the hold key): the font is fixed only when our words were just put in.
-- combat: a cheap look only (Words.Quick: memo, exact, hint), so known texts stay Ukrainian.
function T.Apply(fs, quick, combat)
    stale[fs] = nil
    local now = UADD.Plain(fs:GetText())   -- nil for a secret text (combat): nothing of it is kept
    if mine[fs] == nil or now ~= mine[fs] then   -- LayerSwap's own text (new, or set again)
        local en = now ~= nil and (lastUk[fs] == now and lastEn[fs] or back[now])
        if en then orig[fs], mine[fs] = en, now
        else orig[fs], mine[fs] = now, nil end
    end
    if ns.WordsWanted() then
        if not mine[fs] then
            local uk = (combat and ns.Words.Quick or ns.Words.Text)(orig[fs], fs)
            if not uk then                                  -- an English text: its own font again
                if not combat then U.Missed("layerswap", orig[fs], fs) end
                return ns.Fonts.Back(fs)
            end
            Put(fs, uk)
            mine[fs] = uk
            Remember(fs, uk, orig[fs])
        elseif quick then return end
        if not ns.Fonts.Fix(fs) and mine[fs] then T.English(fs) end   -- no Cyrillic font took (lesson 45)
    elseif mine[fs] then
        if orig[fs] ~= now then Put(fs, orig[fs]) end
        mine[fs] = nil
        ns.Fonts.Back(fs)
    end
end

local function OnText(fs)
    if guard or type(fs) ~= "table" then return end
    hookCalls = hookCalls + 1
    mine[fs] = nil
    if not ns.On() then return end
    -- In combat a cheap look only; after combat, a look puts the rest in.
    U.SafeCall(T.Apply, fs, false, ns.Screen.WaitCombat())
end

function T.Hook(fs)
    if hooked[fs] then return end
    hooked[fs] = true
    hooksecurefunc(fs, "SetText", OnText)
    if fs.SetFormattedText then hooksecurefunc(fs, "SetFormattedText", OnText) end
end
function T.Hooked(fs) return hooked[fs] == true end

-- A Button (or CheckButton): its SetText goes to its FontString as well.
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
    if b.SetFormattedText then hooksecurefunc(b, "SetFormattedText", OnButton) end
    -- its states' fonts: the core's (UADD/ButtonFont.lua, lesson 46)
end

-- Every shown text we know, as it should be now (after the hold key or combat). A hidden one is
-- left as it is and marked: T.Flush puts it right when its frame shows (Screen.lua's OnShow).
function T.Sync()
    for fs in pairs(orig) do
        if fs:IsVisible() then U.SafeCall(T.Apply, fs, true) else stale[fs] = true end
    end
end

-- The marked texts that show now, as they should be.
function T.Flush()
    if next(stale) == nil then return end
    for fs in pairs(stale) do
        if fs:IsVisible() then U.SafeCall(T.Apply, fs, true) end
    end
end

-- "/uadd layerswap off": every text back to LayerSwap's, then forget them.
function T.Restore()
    for fs, t in pairs(mine) do
        if UADD.Plain(fs:GetText()) == t then
            guard = true
            pcall(fs.SetText, fs, orig[fs])
            guard = false
        end
    end
    wipe(mine) wipe(orig) wipe(stale)
    wipe(lastUk) wipe(lastEn) wipe(back)
    backSize = 0
end

-- For the status line and the checks: how many texts show our words now.
function T.Count()
    local n = 0
    for fs, t in pairs(mine) do if UADD.Plain(fs:GetText()) == t then n = n + 1 end end
    return n
end

-- For the checks.
function T.Original(fs) return orig[fs] end
function T.Stale(fs) return stale[fs] == true end
function T.HookCalls() return hookCalls end
