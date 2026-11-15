-- Attune's FontStrings: each keeps its own English (the text Attune set), so the hold key and
-- "/uadd attune off" put exactly that back (the same way as UADD_Auctionator/Texts.lua).
--   * Screen.lua finds the FontStrings and calls T.Hook once per FontString: hooksecurefunc on its own
--     SetText and SetFormattedText (never the shared FontString metatable). Texts set before we
--     looked are put right when Screen.lua first sees them. Claim.lua hooks the texts of Attune's new
--     AceGUI widgets as they are made, so they are ours before Attune measures them.
--   * A text that already reads like our words when we first see it, but that we did not put there
--     (a name a player typed, say), has no English we know: the hold key leaves it as it is.
--   * Attune rebuilds about a hundred step boxes when an attunement is picked, and the Next window on
--     every bag change. The hook is cheap: a number costs one test in Words.lua; a known text, one
--     memo lookup.
--   * A text is changed only when Words.lua knows it. Player names, numbers and any text with
--     Ukrainian letters stay as set. Attune never reads a FontString back, so what it saves, compares,
--     sends and exports stays English.
--   * AceGUI widgets are pooled and given to other addons later. A FontString that is no longer
--     Attune's (not claimed and not inside its frames: Claim.Ours) is forgotten at its next SetText,
--     and Screen.lua and Claim.lua forget the ones of a widget the moment AceGUI releases it.
local _, ns = ...
local U = UADD
local T = {}
ns.Texts = T

local orig = {}       -- FontString -> the text Attune set
local mine = {}       -- FontString -> the text we put in its place
local hooked = {}     -- FontString -> true once its SetText is hooked
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

-- One FontString as it should be now: our words while they are wanted, its own otherwise.
-- quick (the hold key): the font is fixed only when our words were just put in.
-- combat: a cheap look only (Words.Quick: memo, exact, hint), so known texts stay Ukrainian.
function T.Apply(fs, quick, combat)
    local now = UADD.Plain(fs:GetText())   -- nil for a secret text (combat): nothing of it is kept
    if mine[fs] == nil or now ~= mine[fs] then   -- its own text (new, or set again)
        if now ~= nil and lastUk[fs] == now then orig[fs], mine[fs] = lastEn[fs], now   -- what we put here
        elseif now ~= nil and back[now] ~= nil then orig[fs], mine[fs] = false, now
            -- reads like our words, but we did not put it here: left as it is, never guessed
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
        if orig[fs] and orig[fs] ~= now then Put(fs, orig[fs]) end   -- only the English we saw here
        mine[fs] = nil
        ns.Fonts.Back(fs)
    end
end

-- One FontString no longer Attune's (an AceGUI widget back in the pool): its English and font back
-- (unless its new owner already set a text), then forgotten.
function T.Forget(fs, keepText)
    if not keepText and mine[fs] and orig[fs] and UADD.Plain(fs:GetText()) == mine[fs] then Put(fs, orig[fs]) end
    orig[fs], mine[fs], lastUk[fs], lastEn[fs] = nil, nil, nil, nil
    if keepText then ns.Fonts.Drop(fs) else ns.Fonts.Back(fs) end
end
function T.Known(fs) return orig[fs] ~= nil end

local function OnText(fs)
    if guard or type(fs) ~= "table" then return end
    hookCalls = hookCalls + 1
    mine[fs] = nil
    if not ns.On() then return end
    if not ns.Claim.Ours(fs) then
        if orig[fs] ~= nil then T.Forget(fs, true) end
        return
    end
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

-- Every text we know, as it should be now (after the hold key or combat), hidden ones too: a panel
-- inside a window can show later without any OnShow we hook, and must not keep the other language.
-- One memo lookup and one SetText per text that changes.
function T.Sync()
    for fs in pairs(orig) do U.SafeCall(T.Apply, fs, true) end
end

-- New names from Names.lua: a text in our words is worked out again (a name inside may be known
-- now); texts still English are tried again by T.Sync. Not in combat (the caller checks).
function T.Renew()
    for fs, t in pairs(mine) do
        if UADD.Plain(fs:GetText()) == t and orig[fs] then
            local uk = ns.Words.Text(orig[fs], fs)
            if uk and uk ~= t then
                Put(fs, uk)
                mine[fs] = uk
                Remember(fs, uk, orig[fs])
                U.SafeCall(ns.Fonts.Fix, fs)
            end
        end
    end
    T.Sync()
end

-- "/uadd attune off": every text back to its own, then forget them.
function T.Restore()
    for fs, t in pairs(mine) do
        if orig[fs] and UADD.Plain(fs:GetText()) == t then
            guard = true
            pcall(fs.SetText, fs, orig[fs])
            guard = false
        end
    end
    wipe(mine) wipe(orig)
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
function T.HookCalls() return hookCalls end
