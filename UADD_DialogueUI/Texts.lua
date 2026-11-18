-- DialogueUI's FontStrings: each keeps its own English (the text DialogueUI set), so the hold key and
-- "/uadd dialogueui off" put exactly that back.
--   * Screen.lua finds the FontStrings and calls T.Hook once per FontString: hooksecurefunc on its own
--     SetText and SetFormattedText (never the shared FontString metatable). DialogueUI's pools set new
--     texts on the same FontStrings, and the hook swaps in our words right after, before DialogueUI
--     measures the text.
--   * A text is changed only when Words.lua knows it (a DialogueUI L value). Quest titles, NPC names,
--     reward names and counts, and any text with Ukrainian letters (DialogueUI - UALL's) stay as set.
--   * A FontString that shows our words gets a font with Ukrainian letters (Fonts.lua).

local _, ns = ...
local U = UADD
local T = {}
ns.Texts = T

local orig = {}       -- FontString -> the text DialogueUI set
local mine = {}       -- FontString -> the text we put in its place
local hooked = {}     -- FontString -> true once its SetText is hooked
local stale = {}      -- FontString -> true: hidden at the last Sync, put right when it shows (T.Flush)
local guard = false   -- up while we set a text ourselves
-- Our Ukrainian -> the English it stands for. When something sets our own words again (for example
-- fs:SetText(fs:GetText()), or a text copied to another FontString), the English is still known.
local lastUk, lastEn = {}, {}   -- per FontString: the last Ukrainian we put there, and its English
local back, backSize = {}, 0    -- any FontString

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

-- One FontString as it should be now: our words while they are wanted, DialogueUI's otherwise.
-- quick (the hold key): the font is fixed only when our words were just put in.
function T.Apply(fs, quick)
    stale[fs] = nil
    local now = UADD.Plain(fs:GetText())   -- nil for a secret text (combat): nothing of it is kept
    if mine[fs] == nil or now ~= mine[fs] then   -- DialogueUI's own text (new, or set again)
        local en = now ~= nil and (lastUk[fs] == now and lastEn[fs] or back[now])
        if en then orig[fs], mine[fs] = en, now  -- our own words, set again: the English stays
        else orig[fs], mine[fs] = now, nil end
    end
    if ns.WordsWanted() then
        if not mine[fs] then
            local body = ns.Screen.IsBody(fs)
            local uk = ns.Words.Text(orig[fs], body)
            if not uk then                -- quest and book text is the game's prose: never noted
                if not body then U.Missed("dialogueui", orig[fs], fs) end
                return
            end
            Put(fs, uk)
            mine[fs] = uk
            Remember(fs, uk, orig[fs])
        elseif quick then return end
        ns.Fonts.Fix(fs)              -- again each time: DialogueUI resets fonts on a size change
    elseif mine[fs] then
        if orig[fs] ~= now then Put(fs, orig[fs]) end
        mine[fs] = nil
    end
end

local function OnText(fs)
    if guard or type(fs) ~= "table" then return end
    mine[fs] = nil
    if not ns.On() then return end
    if ns.Screen.WaitCombat() then return end      -- after combat, a look puts our words in
    U.SafeCall(T.Apply, fs)
end

function T.Hook(fs)
    if hooked[fs] then return end
    hooked[fs] = true
    hooksecurefunc(fs, "SetText", OnText)
    if fs.SetFormattedText then hooksecurefunc(fs, "SetFormattedText", OnText) end
end

-- Every shown text we know, as it should be now (after the hold key or combat). A hidden one is
-- left as it is and marked: T.Flush puts it right when its window shows (Screen.lua's OnShow).
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

-- "/uadd dialogueui off": every text back to DialogueUI's, then forget them.
function T.Restore()
    for fs, t in pairs(mine) do
        if UADD.Plain(fs:GetText()) == t then
            guard = true
            pcall(fs.SetText, fs, orig[fs])
            guard = false
        end
    end
    wipe(mine)
    wipe(orig)
    wipe(stale)
    wipe(lastUk) wipe(lastEn) wipe(back)
    backSize = 0
end

-- For the status line and the checks: how many texts show our words now.
function T.Count()
    local n = 0
    for fs, t in pairs(mine) do if UADD.Plain(fs:GetText()) == t then n = n + 1 end end
    return n
end

-- For the checks: the English DialogueUI set on one FontString.
function T.Original(fs) return orig[fs] end
