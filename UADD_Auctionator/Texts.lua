-- Auctionator's FontStrings: each keeps its own English (the text Auctionator set), so the hold key
-- and "/uadd auctionator off" put exactly that back (the same way as UADD_ForeverXPBar/Texts.lua).
--   * Screen.lua finds the FontStrings and calls T.Hook once per FontString: hooksecurefunc on its own
--     SetText and SetFormattedText (never the shared FontString metatable). Its XML texts and the
--     labels it set before we loaded are put right when Screen.lua first looks at them.
--   * The results tables set their cells many times a second during a scan. The hook is cheap: a
--     price or number costs one test in Words.lua; a text we already know, one memo lookup.
--   * A text is changed only when Words.lua knows it. Player names, prices, any text with Ukrainian
--     letters and item names (but those in the item column: Rows.lua) stay as set.
--   * Auctionator reads back only edit boxes (never touched) and the export list's check boxes
--     (Screen.lua never enters that list), so what it saves, compares and exports stays English.
--   * T.Hook(fs, only): that FontString is not Auctionator's own (the auction house title); only the
--     English texts in the set `only` change on it, everything else the game puts there stays.
--   * T.Hook(fs, nil, by): this FontString's words come from by(text, fs, combat), not Words.lua
--     (Rows.lua: item names, bag group titles). by gives the Ukrainian or nil.
local _, ns = ...
local U = UADD
local T = {}
ns.Texts = T

local orig = {}       -- FontString -> the text Auctionator set
local mine = {}       -- FontString -> the text we put in its place
local hooked = {}     -- FontString -> true once its SetText is hooked
local guard = false   -- up while we set a text ourselves
local lastUk, lastEn = {}, {}   -- per FontString: the last Ukrainian we put there, and its English
local back, backSize = {}, 0    -- our Ukrainian -> its English, any FontString
local hookCalls = 0             -- for the checks: how often the SetText hook ran
local only = {}                -- FontString -> { [English] = true }: only these change on it
local by = {}                  -- FontString -> its own translate function (T.Hook's third argument)
local quiet = {}               -- FontString -> true: its texts are names, never noted as missed

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
        local en = now ~= nil and (lastUk[fs] == now and lastEn[fs] or back[now])
        if en then orig[fs], mine[fs] = en, now
        else orig[fs], mine[fs] = now, nil end
    end
    if ns.WordsWanted() then
        if not mine[fs] then
            local uk
            if by[fs] then uk = by[fs](orig[fs], fs, combat)
            else uk = (combat and ns.Words.Quick or ns.Words.Text)(orig[fs], fs) end
            if only[fs] and not only[fs][orig[fs] or ""] then uk = nil end
            if not uk then                                  -- an English text: its own font again
                if not combat and not quiet[fs] and not only[fs] then U.Missed("auctionator", orig[fs], fs) end
                return ns.Fonts.Back(fs)
            end
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

-- quiet: its texts are names (an item column), never noted as missed (UADD/Missed.lua).
function T.Hook(fs, set, fn, q)
    if set then only[fs] = set end
    if q then quiet[fs] = true end
    if fn then by[fs] = fn end
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

-- "/uadd auctionator off": every text back to its own, then forget them.
function T.Restore()
    for fs, t in pairs(mine) do
        if UADD.Plain(fs:GetText()) == t then
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
