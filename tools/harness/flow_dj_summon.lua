-- Helpers for flow_dj_summon.py: the lines the journal builds with names in our words (Built.lua):
-- the summon line over a quest and its button, and the row under an item that makes another.
-- Every English name comes from the journal's own data at run time. Reached as HARNESS.djx.
local H = HARNESS
local X = {}
H.djx = X
local function F() return ForeverDungeonJournal_NS end
local function Frame() return rawget(_G, "ForeverDungeonJournalFrame") end
local function ns() return H.ns.UADD_DungeonJournal end

-- The first quest with summon help: dungeon key, quest id, boss and item (English).
function X.summonQuest()
    for key, d in pairs(F().DB) do
        for _, q in ipairs(type(d) == "table" and type(d.quests) == "table" and d.quests or {}) do
            local h = type(q) == "table" and q.summonHelp
            if type(h) == "table" then return key, q.id, h.boss, h.itemName end
        end
    end
end

-- The first loot item that makes another, and its boss: the item, the made one, its halves.
local function Maker()
    for _, d in pairs(F().DB) do
        for _, b in ipairs(type(d) == "table" and type(d.bosses) == "table" and d.bosses or {}) do
            for _, it in ipairs(type(b.loot) == "table" and b.loot or {}) do
                if type(it) == "table" and type(it.makes) == "table" then return it, b end
            end
        end
    end
end

-- The halves of the real joined item, English: own name, own boss, other name, other boss.
function X.halves()
    local it = Maker()
    local own, other
    for _, h in ipairs(it.makes.from) do
        if h[1] == it[1] then own = h else other = h end
    end
    return own[2], own[3], other[2], other[3]
end

-- The note and button text the summon line gets for these names (the journal's real function).
function X.summon(boss, item)
    local help = { boss = boss, itemName = item, page = "x", quest = 1 }
    F().PlaceSummonHelp({ summonHelp = help }, 0)
    local f = Frame()
    return f.questSummonNote:GetText(), f.questSummonButton:GetText()
end
function X.shown()
    local f = Frame()
    local n, b = f.questSummonNote, f.questSummonButton
    return n and n:IsShown() and n:GetText() or nil, b and b:IsShown() and b:GetText() or nil
end

-- What our Ukrainian line is for the real names (nil when UALL lacks one).
function X.summonWant(boss, item)
    local b, i = F().LocalizeBossName(boss), ns().Names.Item(item)
    if not (i and b ~= boss) then return nil end
    return F().L("SUMMON_QUEST_NOTE", b, i), F().L("HOW_TO_SUMMON", b)
end

-- A row of our own, drawn by the journal's real function for a joined item whose halves have these
-- names and bosses (a boss may be nil). Unknown item ids, so the journal uses the names given.
local row
function X.child(ownName, ownBoss, otherName, otherBoss)
    local it = Maker()
    if not row then
        row = CreateFrame("Button", nil, UIParent)
        row.icon = row:CreateTexture()
        row.name = row:CreateFontString()
        row.slot = row:CreateFontString()
    end
    local made = { 990003, it.makes[2], it.makes[3], it.makes[4],
                   from = { { 990001, ownName, ownBoss }, { 990002, otherName, otherBoss } } }
    F().ShowLootChild(row, { 990001, ownName, it[3], it[4], makes = made }, { name = "x" }, 0, 0, 388, nil, false)
    local slot = row.slot:GetText() or ""
    row:Hide()
    return slot:match("^.-  |  (.*)$") or slot, row.fdjSourceText
end
