-- ForeverXP Bar's FontStrings: each keeps its own English (the text ForeverXP Bar set), so the hold
-- key and "/uadd fxpb off" put exactly that back (the same way as UADD_DialogueUI/Texts.lua).
--   * Screen.lua finds the FontStrings and calls T.Hook once per FontString: hooksecurefunc on its own
--     SetText and SetFormattedText (never the shared FontString metatable).
--   * The XP bar sets its texts on every tick. The hook is cheap: a number-only text costs one
--     memo lookup in Words.lua; a text we already know costs one more. Our font goes on once.
--   * A text is changed only when Words.lua knows it. Player names, zone names, numbers and any text
--     with Ukrainian letters stay as set.
--   * ForeverXP Bar never reads its FontStrings back (GetText is used only on edit boxes and its
--     scanning tooltip, which we never touch), so what it sends and parses stays English.

local _, ns = ...
local U = UADD
local T = {}
ns.Texts = T

local orig = {}       -- FontString -> the text ForeverXP Bar set
local mine = {}       -- FontString -> the text we put in its place
local hooked = {}     -- FontString -> true once its SetText is hooked
local stale = {}      -- FontString -> true: hidden at the last Sync, put right when it shows (T.Flush)
local guard = false   -- up while we set a text ourselves
local lastUk, lastEn = {}, {}   -- per FontString: the last Ukrainian we put there, and its English
local back, backSize = {}, 0    -- our Ukrainian -> its English, any FontString
local hookCalls = 0             -- for the checks: how often the SetText hook ran

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

-- One FontString as it should be now: our words while they are wanted, ForeverXP Bar's otherwise.
-- quick (the hold key): the font is fixed only when our words were just put in.
-- combat: a cheap look only (Words.Quick: memo, exact, hint), so known texts stay Ukrainian.
function T.Apply(fs, quick, combat)
    stale[fs] = nil
    local now = UADD.Plain(fs:GetText())   -- nil for a secret text (combat): nothing of it is kept
    if mine[fs] == nil or now ~= mine[fs] then   -- ForeverXP Bar's own text (new, or set again)
        local en = now ~= nil and (lastUk[fs] == now and lastEn[fs] or back[now])
        if en then orig[fs], mine[fs] = en, now
        else orig[fs], mine[fs] = now, nil end
    end
    if ns.WordsWanted() then
        if not mine[fs] then
            local uk = (combat and ns.Words.Quick or ns.Words.Text)(orig[fs], fs)
            if not uk then return ns.Fonts.Back(fs) end    -- an English text: its own font again
            Put(fs, uk)
            mine[fs] = uk
            Remember(fs, uk, orig[fs])
        elseif quick then return end
        ns.Fonts.Fix(fs)
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

-- "/uadd fxpb off": every text back to ForeverXP Bar's, then forget them.
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
