-- Lines the journal builds itself with item and boss names in our words:
--   * the red line over a quest for a boss you must summon, and the button under it
--     (FDJ 2.0.9: FDJ.PlaceSummonHelp, quest.summonHelp; keys SUMMON_QUEST_NOTE, HOW_TO_SUMMON);
--   * the small row under an item that is joined with another into a third (FDJ 2.0.8:
--     FDJ.ShowLootChild, item.makes): its type line (LOOT_COMBINE_WITH) and its tooltip line
--     (LOOT_MADE_FROM, kept in the row's fdjSourceText).
-- The journal puts the item names in English (and a boss name UALL may lack). Both functions are
-- hooked: right after the journal draws, the line is written again with the Ukrainian names from
-- UALL (Names.lua). If any of its names is missing, the whole line is written in English, so it is
-- never half Ukrainian. With the module off, Shift held or another language the hooks do nothing:
-- the journal draws the page again then, all in its own English.
-- The item's own name line on that row is a line of its own (Screen.lua swaps it).

local _, ns = ...
local B = {}
ns.Built = B

local hooked = false
local SEP = "  |  "

local function FDJ() return rawget(_G, "ForeverDungeonJournal_NS") end

local function English(key, ...)
    local F = FDJ()
    local en = F and F.Locales and F.Locales.enUS and F.Locales.enUS[key]
    return type(en) == "string" and en:format(...) or nil
end

-- The Ukrainian boss name, or nil when UALL has none.
local function Boss(en)
    local F = FDJ()
    local uk = type(en) == "string" and F and F.LocalizeBossName and F.LocalizeBossName(en)
    return type(uk) == "string" and uk ~= en and uk or nil
end

local function Item(en)
    return type(en) == "string" and ns.Names.Item(en) or nil
end

local function Set(fs, text)
    if text and type(fs) == "table" and fs.SetText then fs:SetText(text) end
end

local function Active() return ns.Lang and ns.Lang.Active() end

-- The summon line and its button, for the quest the journal just drew.
function B.Summon(quest)
    local help = type(quest) == "table" and quest.summonHelp
    local f = rawget(_G, "ForeverDungeonJournalFrame")
    if type(help) ~= "table" or type(f) ~= "table" or not Active() then return end
    local en = type(help.itemName) == "string" and help.itemName or ""
    local boss, item = Boss(help.boss), Item(en)
    if boss and item then
        Set(f.questSummonNote, FDJ().L("SUMMON_QUEST_NOTE", boss, item))
    else
        Set(f.questSummonNote, English("SUMMON_QUEST_NOTE", tostring(help.boss), en))
    end
    local button = f.questSummonButton
    if not boss and type(button) == "table" and button.SetText then
        Set(button, English("HOW_TO_SUMMON", tostring(help.boss)))
        local fs = button.GetFontString and button:GetFontString()
        local w = fs and fs.GetStringWidth and fs:GetStringWidth() or 90
        button:SetWidth(math.max(112, math.min(240, math.ceil(w + 24))))
    end
end

-- The row under an item that makes another: the type line and the tooltip line.
function B.Child(child, item)
    local made = type(item) == "table" and item.makes
    if type(made) ~= "table" or type(child) ~= "table" or not Active() then return end
    local F = FDJ()
    local other, en, uk, all = nil, {}, {}, true
    for _, half in ipairs(type(made.from) == "table" and made.from or {}) do
        local name = type(half[2]) == "string" and half[2] or ""
        local ukName, ukBoss = Item(name), half[3] and Boss(half[3])
        if tonumber(half[1]) ~= tonumber(item[1]) then other = { name, ukName } end
        all = all and ukName ~= nil and (half[3] == nil or ukBoss ~= nil)
        en[#en + 1] = half[3] and (name .. " (" .. tostring(half[3]) .. ")") or name
        uk[#uk + 1] = ukName and half[3] and ukBoss and (ukName .. " (" .. ukBoss .. ")") or ukName or ""
    end
    local slot = child.slot
    local text = other and slot and slot.GetText and UADD.Plain(slot:GetText())
    if text then
        local head = text:match("^(.-)" .. SEP:gsub("|", "%%|"))
        if other[2] and head then
            Set(slot, head .. SEP .. F.L("LOOT_COMBINE_WITH", other[2]))
        else
            local combine = English("LOOT_COMBINE_WITH", other[1])
            Set(slot, combine and (tostring(made[3] or "") .. SEP .. combine))
        end
    end
    if #en >= 2 and child.fdjSourceText ~= nil then
        child.fdjSourceText = all and F.L("LOOT_MADE_FROM", uk[1], uk[2]) or English("LOOT_MADE_FROM", en[1], en[2])
    end
end

function B.Install()
    local F = FDJ()
    if hooked or type(F) ~= "table" then return end
    if type(F.PlaceSummonHelp) ~= "function" or type(F.ShowLootChild) ~= "function" then return end
    hooked = true
    hooksecurefunc(F, "PlaceSummonHelp", function(quest) UADD.SafeCall(B.Summon, quest) end)
    hooksecurefunc(F, "ShowLootChild", function(child, item) UADD.SafeCall(B.Child, child, item) end)
end
