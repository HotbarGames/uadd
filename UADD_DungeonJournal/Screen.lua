-- What the journal's windows show, looked over one frame after the journal draws:
--   * fonts: each text gets a font with Ukrainian letters (Fonts.lua changes and restores them);
--   * item names: the journal writes them from the game's item data, past every hook of its own,
--     so the `.name` FontString of each item row is hooked (hooksecurefunc on that FontString) and
--     an English item name UALL knows is swapped for the Ukrainian one. Only item rows: a boss or a
--     quest with the same English name as an item keeps its own name.
--   * counts ("12 предметів" over the loot, "6 завдань" on the home page cards): the word is put
--     in the form for the number, the same way (hooksecurefunc on those FontStrings).
-- Only shown windows and shown frames are looked over, at most once per MIN_GAP seconds.
-- The hooks stay for the whole session; with the module off or another language they do nothing.

local _, ns = ...
local S = {}
ns.Screen = S
local Fonts = ns.Fonts

local ROOTS = { "ForeverDungeonJournalFrame", "ForeverDungeonJournalRunTracker", "ForeverDungeonJournalRunLog",
    "ForeverDungeonJournalFavourites", "ForeverDungeonJournalLootFilterResults",
    "ForeverDungeonJournalOptionsPanel",   -- its page in the game options window
    "ForeverDungeonJournalModeChooser",     -- the first-run choice of journal mode
    -- Edit Mode's two menus and its question for a controller
    "ForeverDungeonJournalOrderMenu", "ForeverDungeonJournalViewMenu", "ForeverDungeonJournalResetUIAsk" }
S.MIN_GAP = 0.1                    -- seconds between two looks, however often the journal reads

local hookedText = {}     -- FontString -> true once its SetText is hooked
local owner = setmetatable({}, { __mode = "k" })   -- an item row's .name FontString -> the row
local seen = {}           -- reused by every look
local guard = false       -- up while we set a text ourselves, so our SetText does not come back
local pending = false
local lastScan
local failed               -- the first error in this look, raised once the look is done

-- ── Item names ────────────────────────────────────────────────────────────────────────────────

local TIMES = "\195\151"                  -- "×" in "Name ×2"

function S.ItemText(text)
    if type(text) ~= "string" or text == "" then return nil end
    local N = ns.Names
    local uk = N.Item(text)
    if uk then return uk end
    local base, tail = text:match("^(.-)( " .. TIMES .. "%d+)$")
    uk = base and N.Item(base)
    if uk then return uk .. tail end
    local open, inner, close = text:match("^(|c%x%x%x%x%x%x%x%x)(.-)(|r)$")
    uk = inner and S.ItemText(inner)
    return uk and (open .. uk .. close) or nil
end

-- Does this row show an item now? The journal's own fields, read only: loot rows and quest reward
-- buttons carry .item, favourites .fdjFavouriteItemID or .slot, run log cards .link, and a search
-- result row .searchResult with kind "item". Each is set before the row's name is written.
function S.IsItemRow(row)
    if type(row) ~= "table" then return false end
    if row.item ~= nil or row.fdjFavouriteItemID ~= nil or row.link ~= nil or row.slot ~= nil then return true end
    local r = row.searchResult
    return type(r) == "table" and r.kind == "item"
end

local function OnText(fs, text)
    if guard or not (ns.Lang and ns.Lang.Active()) then return end
    if not S.IsItemRow(owner[fs]) then return end
    local uk = S.ItemText(UADD.Plain(text))   -- a secret text (combat): left as it is
    if uk then
        guard = true
        fs:SetText(uk)
        guard = false
    end
end

local function HookItem(row)
    local fs = row.name
    owner[fs] = row
    if not hookedText[fs] then
        hookedText[fs] = true
        hooksecurefunc(fs, "SetText", OnText)
    end
    OnText(fs, fs:GetText())
end

-- ── Counts: "12 предметів", "2/6 завдань" ─────────────────────────────────────────────────────
-- FDJ writes the number, a space and one word for any number above 1, so the word is put in the
-- form Ukrainian needs for that number: 2-4 предмети / завдання, 5-20 предметів / завдань.

local FORMS = {
    ["предметів"] = { "предмет", "предмети", "предметів" },
    ["завдань"] = { "завдання", "завдання", "завдань" },
}

function S.Plural(n, word)
    local f = FORMS[word]
    if not f then return word end
    local last, last2 = n % 10, n % 100
    if last == 1 and last2 ~= 11 then return f[1] end
    if last >= 2 and last <= 4 and (last2 < 12 or last2 > 14) then return f[2] end
    return f[3]
end

function S.CountText(text)
    if type(text) ~= "string" then return nil end
    local head, n, word = text:match("^(.-)(%d+) (\208[\128-\191][^ ]*)$")
    if not (n and FORMS[word]) then return nil end
    local right = S.Plural(tonumber(n), word)
    return right ~= word and (head .. n .. " " .. right) or nil
end

local function OnCount(fs, text)
    if guard or not (ns.Lang and ns.Lang.Active()) then return end
    local fixed = S.CountText(UADD.Plain(text))   -- a secret text (combat): left as it is
    if fixed then
        guard = true
        fs:SetText(fixed)
        guard = false
    end
end

local function HookCount(fs)
    if not hookedText[fs] then
        hookedText[fs] = true
        hooksecurefunc(fs, "SetText", OnCount)
    end
    OnCount(fs, fs:GetText())
end

-- ── Looking over the windows ──────────────────────────────────────────────────────────────────

local function IsFontString(x)
    return type(x) == "table" and x.GetObjectType and x:GetObjectType() == "FontString"
end

-- One FontString that cannot be changed must not stop the look over the rest of the window
-- (the item rows come after many other texts), so each change is guarded on its own.
local function Try(fn, x)
    local ok, err = pcall(fn, x)
    if not ok then failed = failed or err end
end

local Walk

local function Regions(...)
    for i = 1, select("#", ...) do
        local r = select(i, ...)
        if IsFontString(r) and not Fonts.Kept(r) then Try(Fonts.Fix, r) end
    end
end

local function Children(...)
    for i = 1, select("#", ...) do Walk((select(i, ...))) end
end

-- A hidden frame is skipped with all it holds: the journal draws a page before it shows it, and
-- that draw brings the next look.
Walk = function(f)
    if seen[f] then return end
    seen[f] = true
    if f.IsShown and not f:IsShown() then return end
    if IsFontString(f.name) then Try(HookItem, f) end
    if IsFontString(f.counts) then Try(HookCount, f.counts) end          -- home page cards
    if IsFontString(f.lootTitle) then Try(HookCount, f.lootTitle) end    -- "12 предметів"
    Try(ns.Buttons.Look, f)                                              -- YES, NO, OKAY (Buttons.lua)
    Try(Fonts.Button, f)                                                 -- a button's states (Fonts.lua)
    if f.GetRegions then Regions(f:GetRegions()) end
    if f.GetChildren then Children(f:GetChildren()) end
    local child = f.GetScrollChild and f:GetScrollChild()          -- loot and quest lists
    if type(child) == "table" then Walk(child) end
end

local function Shown(root)
    return type(root) == "table" and root.GetChildren and root.IsShown and root:IsShown()
end

-- The journal may draw a page just before it shows the window; that draw finds no window shown,
-- so each window, once it exists, also brings a look when it is shown (HookScript).
-- A name read while the journal builds its window brings the first hook before the journal sets
-- its own OnShow, and SetScript drops hooks: so the handler seen is kept, and a new one is hooked.
local hookedRoot = {}     -- window -> its OnShow handler when we hooked it
-- The journal window also gets its page and search redrawn when a switch came while it was shut.
local function OnRootShown(self)
    if ns.Lang and ns.Lang.OnShown then UADD.SafeCall(ns.Lang.OnShown, self) end
    S.Schedule()
end

function S.WatchShow(root)
    if type(root) ~= "table" or not (root.HookScript and root.GetScript) then return end
    local seen = hookedRoot[root]
    if seen ~= nil and seen == (root:GetScript("OnShow") or false) then return end
    root:HookScript("OnShow", OnRootShown)
    hookedRoot[root] = root:GetScript("OnShow") or false
end

-- The journal's windows, then its map panel on the World Map (Map.lua).
local function AnyShown()
    local any = false
    for _, name in ipairs(ROOTS) do
        local root = rawget(_G, name)
        S.WatchShow(root)
        if Shown(root) then any = true end
    end
    return ns.Map.AnyShown() or any
end

-- Runs now. Fonts and items when our language shows; old fonts back when it does not.
function S.Scan()
    pending = false
    lastScan = GetTime and GetTime() or 0
    local L = ns.Lang
    local wants = L and L.Wants()
    if ns.Prose then ns.Prose.HookNotes() end      -- in case every read came while a look was pending
    if not wants then return Fonts.Restore() end
    ns.Buttons.Sync()
    wipe(seen)
    failed = nil
    Try(Fonts.Buttons)
    for _, name in ipairs(ROOTS) do
        local root = rawget(_G, name)
        if Shown(root) then Walk(root) end
    end
    Try(function() ns.Map.Look(Walk) end)
    wipe(seen)
    if failed then
        local err = failed
        failed = nil
        error(err, 0)
    end
end

local function Run() UADD.SafeCall(S.Scan) end

-- Is a look already on its way? (Content.lua asks on every name the journal reads.)
function S.Pending() return pending end

-- At most one look per MIN_GAP, however many names the journal reads (its quest tracker reads on
-- every quest log update), and none while no journal window (or its map panel on the World Map) is shown.
function S.Schedule()
    if pending or not AnyShown() then return end
    pending = true
    local now = GetTime and GetTime() or 0
    local wait = lastScan and (lastScan + S.MIN_GAP - now) or 0
    C_Timer.After(wait > 0 and wait or 0, Run)
end
