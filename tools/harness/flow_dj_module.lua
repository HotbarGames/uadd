-- Helpers for flow_dj_module.py: UADD_DungeonJournal next to the real Dungeon Journal.
-- Loaded after dj_load.lua; reached from Python as HARNESS.djm.
local H = HARNESS
local M = {}
H.djm = M
local function ns() return H.ns.UADD_DungeonJournal end
function M.collect(maxFrames)
    local N, t0 = ns().Names, H.time
    H.pump(maxFrames, function() return H.time > t0 + 4 and N.Progress() == nil end, 0.05)
    return N.Progress() == nil
end
function M.counts()
    local c = ns().Names.Counts()
    return c.dungeons, c.dungeonsTotal, c.Npc, c.Quest, c.Item
end
function M.totals()
    local s = ns().Names.Sources()
    return #s.zones, #s.Npc, #s.Quest, #s.Item
end
function M.name(kind, key)
    local N = ns().Names
    if kind == "dungeon" then return N.Dungeon(key) end
    if kind == "boss" then return N.Boss(key) end
    if kind == "quest" then return N.Quest(key) end
    return N.Item(key)
end
-- An NPC from the journal that UALL has no Ukrainian for, and what FDJ shows for it.
function M.missingBoss()
    local N = ns().Names
    for _, e in ipairs(N.Sources().Npc) do
        if not N.Boss(e.en) then return e.en, ForeverDungeonJournal_NS.LocalizeBossName(e.en) end
    end
end
-- The first loot item of a boss on the open page with a Ukrainian name.
function M.lootItem(dungeon)
    local N = ns().Names
    for _, b in ipairs(ForeverDungeonJournal_NS.DB[dungeon].bosses or {}) do
        for _, it in ipairs(b.loot or {}) do
            if type(it[2]) == "string" and N.Item(it[2]) then return b.name, it[2], N.Item(it[2]) end
        end
    end
end
function M.key(down)
    H.keys.SHIFT = down
    H.fire("MODIFIER_STATE_CHANGED", "LSHIFT", down and 1 or 0)
end
function M.wait(seconds) for _ = 1, math.ceil(seconds / 0.05 - 1e-6) do H.step(0.05) end end
function M.uadd(msg) return H.call("/uadd " .. msg, SlashCmdList.UADD, msg) end
function M.search(text)
    local f = ForeverDungeonJournalFrame
    f.searchEditBox:SetText(text)
    f.RefreshSearchResults(text)
    local r = {}
    for _, row in ipairs(H.dj.buttons(f.searchResultsFrame)) do
        if row:IsShown() and row.name then r[#r + 1] = row.name.__text or "" end
    end
    return r
end
function M.fonts()
    local r = {}
    for _, name in ipairs(M.SHARED) do
        local o = _G[name]
        if o then
            local p, s, fl = o:GetFont()
            r[#r + 1] = name .. "=" .. tostring(p) .. "/" .. tostring(s) .. "/" .. tostring(fl)
        end
    end
    return table.concat(r, ";")
end
function M.ourFonts() return ns().Fonts.Count() end
function M.language() return ForeverDungeonJournal_NS.GetLanguage() end
function M.tables()
    local F = ForeverDungeonJournal_NS
    return F.Locales.ukUA ~= nil, F.ContentLocales.ukUA ~= nil
end
-- Is «Українська» among the menu rows that would show?
function M.entryShown()
    for _, o in ipairs(H.dj.languageOptions()) do
        if o.label == "Українська" and o.button:IsShown() then return true end
    end
    return false
end
-- Clicks the first shown button under the journal whose .name text starts with `text`.
function M.clickNamed(text)
    local seen = {}
    local function walk(f)
        if seen[f] then return nil end
        seen[f] = true
        if f.__type == "Button" and f:IsVisible() and type(f.name) == "table" and f.name.__text
            and f.name.__text:sub(1, #text) == text then return f end
        for _, c in ipairs({ f:GetChildren() }) do
            local hit = walk(c)
            if hit then return hit end
        end
    end
    local b = walk(ForeverDungeonJournalFrame)
    if b then H.dj.click(b) end
    return b ~= nil
end
-- Shown texts under the journal that are English item names we have Ukrainian for.
function M.englishItems()
    local S, r = ns().Screen, {}
    local list = H.dj.visible(ForeverDungeonJournalFrame)
    for i = 1, H.count(list) do
        local t = list[i]
        if S.ItemText(t) then r[#r + 1] = t end
    end
    return r
end
-- Clicks the first shown search result.
function M.clickResult()
    for _, row in ipairs(H.dj.buttons(ForeverDungeonJournalFrame.searchResultsFrame)) do
        if row:IsShown() then H.dj.click(row) return true end
    end
    return false
end
-- ── Fonts ────────────────────────────────────────────────────────────────────────────────────
-- One FontString's font as "file/size/flags/object", and whether the file is one of UADD's.
local function fontText(fs)
    local p, s, fl = fs:GetFont()
    local o = fs:GetFontObject()
    o = type(o) == "table" and o.GetName and o:GetName() or tostring(o)
    return tostring(p) .. "/" .. tostring(s) .. "/" .. tostring(fl) .. "/" .. tostring(o)
end
local function cyr(fs) return UADD.IsCyrFont((fs:GetFont())) end
local function originalText(fs)
    local p, s, fl, o = ns().Fonts.Original(fs)
    if not p then return nil end
    o = type(o) == "table" and o.GetName and o:GetName() or tostring(o)
    return tostring(p) .. "/" .. tostring(s) .. "/" .. tostring(fl) .. "/" .. tostring(o)
end
-- The title's font now, whether it is UADD's, and what we remember of the journal's.
function M.titleFont()
    local t = ForeverDungeonJournalFrame.dungeonTitle
    return fontText(t), cyr(t), originalText(t)
end
-- A text of the journal's window with its own font object, file, size and OUTLINE, as a test
-- piece: the journal redraws its own texts, this one only we change.
function M.probe()
    if not M.probeFs then
        local fs = ForeverDungeonJournalFrame:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(GameFontNormalHuge)
        fs:SetFont("Fonts\\FRIZQT__.TTF", 17, "OUTLINE")
        fs:SetText("probe")
        M.probeFs = fs
        M.probeBefore = fontText(fs)
    end
    return M.probeBefore
end
-- Now, what we remember of it, and whether it has our file.
function M.probeNow()
    local fs = M.probeFs
    return fontText(fs), originalText(fs), cyr(fs)
end
-- The journal sets a font on the test piece, as it does on each draw.
function M.probeSet(size, flags)
    M.probeFs:SetFont("Fonts\\FRIZQT__.TTF", size, flags)
    return fontText(M.probeFs), cyr(M.probeFs)
end
-- The SetFont functions on the test piece and the title: the same after more looks means our
-- hooks were installed once, not once per look.
function M.setFontFns()
    return tostring(M.probeFs.SetFont) .. " " .. tostring(ForeverDungeonJournalFrame.dungeonTitle.SetFont)
end
-- Every changed text keeps its size and flags.
function M.sizesKept()
    local S, bad, n = ns().Fonts, {}, 0
    local seen = {}
    local function walk(f)
        if seen[f] then return end
        seen[f] = true
        for _, r in ipairs({ f:GetRegions() }) do
            local p, s, fl = S.Original(r)
            if p then
                n = n + 1
                local _, s2, fl2 = r:GetFont()
                if s2 ~= s or (fl2 or "") ~= (fl or "") then bad[#bad + 1] = tostring(s) .. tostring(fl) .. "->" .. tostring(s2) .. tostring(fl2) end
            end
        end
        for _, c in ipairs({ f:GetChildren() }) do walk(c) end
    end
    walk(ForeverDungeonJournalFrame)
    return n, table.concat(bad, "; ")
end

-- ── Item rows ────────────────────────────────────────────────────────────────────────────────
-- A row under the journal with a .name text, first as a boss row (no item fields).
function M.row(en)
    if not M.testRow then
        local row = CreateFrame("Button", nil, ForeverDungeonJournalFrame)
        row.name = row:CreateFontString(nil, "OVERLAY")
        row:Show()
        M.testRow = row
    end
    M.testRow.item = nil
    M.testRow.name:SetText(en)
    ns().Screen.Schedule()
end
-- The row's text after the journal writes `en` with the row as an item row (`item`) or not.
function M.rowSet(en, item)
    M.testRow.item = item
    M.testRow.name:SetText(en)
    return M.testRow.name:GetText()
end
function M.rowText() return M.testRow.name:GetText() end
function M.rowDone() M.testRow:Hide() end

-- ── Looks ────────────────────────────────────────────────────────────────────────────────────
local ROOTS = { "ForeverDungeonJournalFrame", "ForeverDungeonJournalRunTracker", "ForeverDungeonJournalRunLog",
    "ForeverDungeonJournalFavourites", "ForeverDungeonJournalLootFilterResults",
    "ForeverDungeonJournalOptionsPanel", "ForeverDungeonJournalModeChooser" }
-- Counts the looks from now on.
function M.countLooks()
    local S = ns().Screen
    if not M.lookWrapped then
        local orig = S.Scan
        S.Scan = function(...) M.looks = M.looks + 1 return orig(...) end
        M.lookWrapped = true
    end
    M.looks = 0
end
function M.looksSince() return M.looks end
function M.hideAll()
    for _, name in ipairs(ROOTS) do
        local f = rawget(_G, name)
        if f and f.Hide then f:Hide() end
    end
end
function M.anyShown()
    for _, name in ipairs(ROOTS) do
        local f = rawget(_G, name)
        if f and f.IsShown and f:IsShown() then return true end
    end
    return false
end
-- `n` reads of the names table, as the journal's quest tracker does on every quest log update.
function M.burst(n)
    local b = ForeverDungeonJournal_NS.ContentLocales.ukUA.bosses
    for _ = 1, n do local _ = b["Charlga Razorflank"] end
end

-- ── Start-up ─────────────────────────────────────────────────────────────────────────────────
function M.wants() return ns().Lang.Wants() end
function M.routeOff(kind) return UADD.UALL.RouteOff(kind) end
function M.zonesSaved() return ns().db.cache ~= nil and ns().db.cache.zones ~= nil end

function M.choice() return ns().db and ns().db.choice end
function M.plural(n, word) return ns().Screen.Plural(n, word) end
function M.countText(t) return ns().Screen.CountText(t) end
