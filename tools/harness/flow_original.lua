-- Lua side of the show-original key checks (flow_original.py) and of the dungeon letter
-- after the level ("[34D]"). Strings are UTF-8 bytes here; flow_original.py converts them.
local H = HARNESS
local F = H.flow

local function M(name) return QuestieLoader:ImportModule(name) end

-- A Vengeful Fate (1102, Razorfen Kraul): its tag comes from Questie's own list,
-- {81, l10n("Dungeon")}, so the tag name is Ukrainian.
F.dungeonLog = {
    { title = "Razorfen Kraul", isHeader = true },
    { title = "A Vengeful Fate", level = 34, questID = 1102, objectives = {
        { text = "0/1 Razorfen Kraul Treasure", type = "item", numFulfilled = 0, numRequired = 1, finished = false } } },
}

-- Questie's tag id and name for 1102, its letter, and the tracker lines for the dungeon log.
function F.dungeon()
    local id, name = M("QuestieDB").GetQuestTagInfo(1102)
    local letter = M("QuestieLib"):GetQuestTypeSuffix(1102)
    F.questLog = F.dungeonLog
    local lines = F.drawTracker(true)
    F.resetQuestLog()
    return id, name, letter, lines
end

-- Presses (true) or lets go of (false) one modifier key, as the game reports it.
function F.key(name, down)
    H.keys[name] = down
    local side = name == "CTRL" and "LCTRL" or name == "ALT" and "LALT" or "LSHIFT"
    H.fire("MODIFIER_STATE_CHANGED", side, down and 1 or 0)
end

-- The key comes up with no event, as when it is let go outside the game window (Alt-Tab).
function F.keySilent(name, down) H.keys[name] = down end

-- Lets `seconds` of game time pass, 0.05 s a frame (timers and OnUpdate scripts run).
function F.wait(seconds)
    for _ = 1, math.ceil(seconds / 0.05 - 1e-6) do H.step(0.05) end
end

-- The text box that has the keyboard (chat while typing): F.focus, nil when none.
if rawget(_G, "GetCurrentKeyBoardFocus") == nil then
    function GetCurrentKeyBoardFocus() return F.focus end
end

-- What the core told its listeners since F.toldReset(): "T" for true, "F" for false.
F.told = {}
UADD.OnOriginal(function(show) F.told[#F.told + 1] = show and "T" or "F" end)
function F.toldReset() F.told = {} end
function F.toldText() return table.concat(F.told) end
function F.polling() return UADD.originalPoll ~= nil end

-- What Questie shows for quest `id` now: its coloured name with the level, and an l10n string.
function F.shown(id)
    return M("QuestieLib"):GetColoredQuestName(id, true, false), M("l10n")("General")
end

-- Every name we passed to QuestieDB, as "kind id=name" lines.
function F.publishedNames()
    local out, maps = {}, H.ns.UADD_Questie.Names.maps
    for _, kind in ipairs({ "Quest", "Npc", "Item" }) do
        for id, name in pairs(maps[kind] or {}) do out[#out + 1] = kind .. " " .. id .. "=" .. tostring(name) end
    end
    return out
end

function F.setOriginalKey(key)
    UALLFSettingsDB = UALLFSettingsDB or {}
    UALLFSettingsDB.originalKey = key
end

-- UALLF's reverse mode on (true) or off (nil), as the player sets it in UALLF's options.
function F.setReverse(on)
    UALLFSettingsDB = UALLFSettingsDB or {}
    UALLFSettingsDB.reverseOriginal = on
end

-- The game says UALLF is not loaded (true), or tells the truth again (false). Its saved settings stay.
local realLoaded
function F.hideUALLF(hide)
    if hide and not realLoaded then
        realLoaded = C_AddOns.IsAddOnLoaded
        C_AddOns.IsAddOnLoaded = function(name)
            if name == "UALLF" then return false, false end
            return realLoaded(name)
        end
    elseif not hide and realLoaded then
        C_AddOns.IsAddOnLoaded, realLoaded = realLoaded, nil
    end
end

-- A Questie pin tooltip under the mouse on the open world map when the key goes down and is held
-- (true) or comes up (false). Returns the title its last drawing showed.
-- MapIconTooltip.ShowOnTooltip is replaced by one that works like Questie's: the title (here an
-- l10n string) is built when the tooltip is shown, _Rebuild only draws that title again, and a
-- second show within 0.05 s of a shown tooltip does nothing.
function F.pinTooltip(down)
    local tip, before = GameTooltip, QuestieCompat
    local compat = before or {}
    local real, wasShown = compat.MouseIsOver, WorldMapFrame:IsShown()
    QuestieCompat, compat.MouseIsOver = compat, function() return true end
    WorldMapFrame:Show()
    local MIT = M("MapIconTooltip")
    local realShow, last, seen = MIT.ShowOnTooltip, -1, nil
    MIT.ShowOnTooltip = function(icon, t, owner, icons)
        if GetTime() - last < 0.05 and t:IsShown() then return end
        last = GetTime()
        t._owner, t._showOwner, t._showIcons, t._showData = icon, owner, icons, icon.data
        t:SetOwner(owner or icon, "ANCHOR_CURSOR")
        local title = M("l10n")("General")
        t._Rebuild = function(self) self:ClearLines(); seen = title; self:AddLine(title) end
        t:_Rebuild()
        t.ShownAsMapIcon = true
        t:Show()
    end
    local pin = CreateFrame("Frame")
    pin.data = { Id = 0 }
    pin.texture = { GetVertexColor = function() return 1, 1, 1, 1 end }
    -- Questie's GameTooltip OnUpdate (Tooltip.lua) asks what the tooltip shows while frames run:
    -- nothing (the harness tooltip has no such methods).
    local asks = {}
    for _, m in ipairs({ "GetUnit", "GetItem", "GetSpell" }) do
        if rawget(tip, m) == nil then asks[#asks + 1] = m; tip[m] = function() return nil end end
    end
    tip:Hide()
    MIT.ShowOnTooltip(pin, tip)
    F.key("SHIFT", down)
    if down then F.wait(0.3) end
    for _, m in ipairs(asks) do tip[m] = nil end
    MIT.ShowOnTooltip, compat.MouseIsOver, QuestieCompat = realShow, real, before
    tip._Rebuild, tip._owner, tip._showOwner, tip._showIcons, tip._showData = nil, nil, nil, nil, nil
    tip.ShownAsMapIcon = false
    tip:Hide()
    if not wasShown then WorldMapFrame:Hide() end
    return seen
end
