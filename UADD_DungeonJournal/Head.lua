-- The dungeon header's level line. FDJ writes the level (its short word and the range) and the red
-- notes beside it in code, not through its locale, so the three functions that make them are
-- wrapped (by Language.lua's Install, through H.Install). They share a row with the dungeon's title:
-- as short as the English (docs/LESSONS.md, lesson 5).

local _, ns = ...
local H = {}
ns.Head = H

H.WORDS = {
    level = "Рів. %s",              -- the range as FDJ wrote it after its own short word
    itemsSome = "Здобич неповна",   -- some loot listed, the table not complete yet (game.loot)
    itemsNone = "Здобич невідома",  -- no loot listed yet
    quests = "Не всі завдання",     -- the Quests tab of a dungeon whose quests are still being found
}

local orig = {}
local on = false
local function FDJ() return rawget(_G, "ForeverDungeonJournal_NS") end
local function Frame() return rawget(_G, "ForeverDungeonJournalFrame") end

-- Each English text these made and our words for it, both ways: the hold key and off switch the
-- header's texts in place (FDJ's page redraw, Language.lua's L.Light, does not redo the header).
local toUk, toEn = {}, {}
local function Pair(en, uk)
    if type(en) ~= "string" or not uk or en == uk then return en end
    toUk[en], toEn[uk] = uk, en
    if on and ns.Lang.Active() then return uk end
    return en
end

-- Our part runs under UADD.Safe (docs/LESSONS2.md lesson 19): an error of ours is counted for the
-- module and FDJ gets its own English back, never the error.
local Level = UADD.Safe("dj", function(en)
    local range = type(en) == "string" and en:match("^%S+ (.+)$")
    return Pair(en, range and H.WORDS.level:format(range))
end)
local Items = UADD.Safe("dj", function(en, name)
    local fdj = FDJ()
    local d = fdj and type(fdj.DB) == "table" and fdj.DB[name]
    return Pair(en, (type(d) == "table" and d.fullItemsTBD) and H.WORDS.itemsSome or H.WORDS.itemsNone)
end)

local function HomeLevelText(...)
    local en = orig.HomeLevelText(...)
    local out = Level(en)
    if out == nil then return en end
    return out
end

local function ItemsTBDText(name, ...)
    local en = orig.ItemsTBDText(name, ...)
    local out = Items(en, name)
    if out == nil then return en end
    return out
end

-- The quests note's text is set once when the window is made; FDJ only places and shows it later.
local function QuestsLabel()
    local f = Frame()
    local label = f and f.questsTBD
    if label and label.GetText then Pair(label:GetText(), toEn[label:GetText()] and nil or H.WORDS.quests) end
end

-- The header's texts in the language of the moment (on, off, the hold key).
local TEXTS = { "dungeonMeta", "stockadeItemsTBD", "stockadeLootTBD", "questsTBD" }
function H.Texts()
    local f = Frame()
    if not f then return end
    QuestsLabel()
    local uk = on and ns.Lang.Active()
    for _, key in ipairs(TEXTS) do
        local fs = rawget(f, key)
        local now = type(fs) == "table" and fs.GetText and fs:GetText()
        local want = type(now) == "string" and (uk and toUk[now] or not uk and toEn[now])
        if want then fs:SetText(want) end
    end
end

local function UpdateQuestsTBD(...)
    orig.UpdateQuestsTBD(...)          -- it returns nothing
    UADD.SafeCall(H.Texts)
end

local WRAPS = { HomeLevelText = HomeLevelText, ItemsTBDText = ItemsTBDText, UpdateQuestsTBD = UpdateQuestsTBD }

-- Only the functions this journal has.
function H.Install(fdj)
    for name, wrap in pairs(WRAPS) do
        if type(fdj[name]) == "function" and fdj[name] ~= wrap then orig[name], fdj[name] = fdj[name], wrap end
    end
    on = true
end

-- Puts FDJ's functions back where nobody wrapped ours since, and the header's English back (the
-- quests note is never set again by FDJ).
function H.Uninstall(fdj)
    for name, wrap in pairs(WRAPS) do
        if orig[name] and fdj[name] == wrap then fdj[name] = orig[name] end
    end
    on = false
    UADD.SafeCall(H.Texts)
end
