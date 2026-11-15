-- Harness game API, part 2: C_ namespaces. Answers are "nothing known" unless a test sets them.
local H = HARNESS

-- ── Quest/map/misc C_ namespaces (answers are "nothing known") ───────────────────────────────
H.questTitles = {}       -- questId -> title the client would return (cache)
-- The quest log, in log order, as C_QuestLog.GetInfo returns it. Empty unless a test fills it:
-- { title=, level=, isHeader=, questID=, objectives={ {text=, type=, numFulfilled=, numRequired=, finished=} } }
H.questLog = {}
local function logEntry(id)
    for i, e in ipairs(H.questLog) do if not e.isHeader and e.questID == id then return e, i end end
end
C_QuestLog = {
    GetTitleForQuestID = function(id) return H.questTitles[id] end,
    IsQuestFlaggedCompleted = function() return false end,
    GetQuestObjectives = function(id)
        local e, out = logEntry(id), {}
        for i, o in ipairs(e and e.objectives or {}) do
            out[i] = { text = o.text, type = o.type, numFulfilled = o.numFulfilled, numRequired = o.numRequired,
                finished = o.finished or false }
        end
        return out
    end,
    GetNumQuestLogEntries = function()
        local quests = 0
        for _, e in ipairs(H.questLog) do if not e.isHeader then quests = quests + 1 end end
        return #H.questLog, quests
    end,
    GetInfo = function(i)
        local e = H.questLog[i]
        if not e then return nil end
        return { title = e.title, level = e.level or 0, isHeader = e.isHeader or false, isCollapsed = false,
            questID = e.questID or 0, frequency = 0, isHidden = false, isTask = false, isOnMap = false }
    end,
    GetQuestIDForLogIndex = function(i) local e = H.questLog[i]; return e and not e.isHeader and e.questID or nil end,
    GetLogIndexForQuestID = function(id) return select(2, logEntry(id)) end,
    IsComplete = function(id) local e = logEntry(id); return e and e.isComplete or false end,
    IsOnQuest = function(id) return logEntry(id) ~= nil end,
    GetQuestTagInfo = function() return nil end,
    GetMaxNumQuestsCanAccept = function() return 20 end,
    GetAllCompletedQuestIDs = function() return {} end,
    RequestLoadQuestByID = function() end,
    GetQuestWatchType = function() return nil end,
    AddQuestWatch = function() return true end,
    RemoveQuestWatch = function() return true end,
    GetNumQuestWatches = function() return 0 end,
    ShouldShowQuestRewards = function() return true end,
}
C_QuestLog.GetQuestInfo = C_QuestLog.GetTitleForQuestID
-- The client has data for every quest in the stub log (they are all "loaded").
function HaveQuestData(id) return logEntry(id) ~= nil end
C_Map = {
    GetBestMapForUnit = function() return 1453 end,
    GetPlayerMapPosition = function() return nil end,
    -- A small tree (zone -> continent 1415 -> world 947), so parent walks end.
    GetMapInfo = function(id)
        if id == 947 then return { mapID = 947, name = "Azeroth", mapType = 1, parentMapID = 0 } end
        if id == 1415 then return { mapID = 1415, name = "Eastern Kingdoms", mapType = 2, parentMapID = 947 } end
        return { mapID = id, name = "Stormwind City", mapType = 3, parentMapID = 1415 }
    end,
    GetMapChildrenInfo = function() return {} end,
    GetWorldPosFromMapPos = function() return 0, { x = 0, y = 0 } end,
    GetMapRectOnMap = function() return 0, 1, 0, 1 end,
    GetMapGroupID = function() return nil end,
    GetMapArtID = function() return 0 end,
    GetAreaInfo = function() return nil end,
    GetMapWorldSize = function() return 1, 1 end,
}
C_Item = { GetItemInfo = GetItemInfo, GetItemInfoInstant = GetItemInfoInstant, GetItemCount = GetItemCount,
    RequestLoadItemDataByID = function() end, DoesItemExistByID = function() return true end,
    IsItemDataCachedByID = function() return false end, GetItemNameByID = function() return nil end,
    GetItemQualityByID = function() return nil end, GetItemIconByID = function() return nil end }
C_Spell = { GetSpellInfo = function() return nil end, GetSpellName = function() return nil end,
    IsSpellDataCached = function() return false end, RequestLoadSpellData = function() end,
    DoesSpellExist = function() return false end }
C_Container = { GetContainerNumSlots = function() return 0 end, GetContainerItemInfo = function() return nil end,
    GetContainerItemID = function() return nil end, GetContainerItemLink = function() return nil end }
C_GossipInfo = { GetFriendshipReputation = function() return nil end, GetText = function() return "" end, GetAvailableQuests = function() return {} end,
    GetActiveQuests = function() return {} end, GetOptions = function() return {} end,
    GetNumAvailableQuests = function() return 0 end, GetNumActiveQuests = function() return 0 end }
C_TaxiMap = { GetAllTaxiNodes = function() return {} end, GetTaxiNodesForMap = function() return {} end }
C_Reputation = { GetNumFactions = function() return 0 end, GetFactionDataByIndex = function() return nil end,
    GetFactionDataByID = function() return nil end }
C_Seasons = { HasActiveSeason = function() return false end, GetActiveSeason = function() return nil end }
C_GameRules = { IsHardcoreActive = function() return false end, IsSelfFoundAllowed = function() return false end,
    IsGameRuleActive = function() return false end }
C_Engraving = { IsEngravingEnabled = function() return false end }
C_PlayerInfo = { GetPlayerMythicPlusRatingSummary = function() return nil end, GUIDIsPlayer = function() return false end,
    IsPlayerEligibleForHardcore = function() return false end }
C_DateAndTime = { GetCurrentCalendarTime = function() local d = os.date("*t")
    return { year = d.year, month = d.month, monthDay = d.day, weekday = d.wday, hour = d.hour, minute = d.min } end,
    GetServerTimeLocal = function() return os.time() end, GetSecondsUntilDailyReset = function() return 3600 end,
    GetSecondsUntilWeeklyReset = function() return 86400 end }
C_Calendar = { GetDate = C_DateAndTime.GetCurrentCalendarTime, OpenCalendar = function() end, SetMonth = function() end,
    GetMonthInfo = function() local d = os.date("*t") return { month = d.month, year = d.year, numDays = 30, firstWeekday = 1 } end,
    GetNumDayEvents = function() return 0 end, GetHolidayInfo = function() return nil end }
function UIDropDownMenu_HandleGlobalMouseEvent() end
C_MapExplorationInfo = { GetExploredMapTextures = function() return {} end }
C_Minimap = { GetNumTrackingTypes = function() return 0 end, GetTrackingInfo = function() return nil end }
C_Texture = { GetAtlasInfo = function() return nil end }
C_UnitAuras = { GetAuraDataByIndex = function() return nil end, GetPlayerAuraBySpellID = function() return nil end }
C_LFGList = { GetActivityInfoTable = function() return nil end }
C_BattleNet = { GetFriendAccountInfo = function() return nil end }
C_FriendList = { GetNumFriends = function() return 0 end, GetNumOnlineFriends = function() return 0 end }
C_Social = {}
C_Console = {}
C_SettingsUtil = {}
C_XMLUtil = { GetTemplateInfo = function() return nil end }
C_Widget = { IsFrameWidget = function() return true end, IsWidget = function() return true end }
C_SuperTrack = { GetSuperTrackedQuestID = function() return 0 end, SetSuperTrackedQuestID = function() end }
C_PetJournal = {}
C_VoiceChat = { SpeakText = function() end, StopSpeakingText = function() end, GetTtsVoices = function() return {} end }
C_TTSSettings = { GetVoiceOptionID = function() return 0 end, GetSpeechRate = function() return 0 end,
    GetSpeechVolume = function() return 100 end }
C_StorePublic = { IsEnabled = function() return false end }

-- ── Odds and ends found by running the addons ─────────────────────────────────────────────────
function UnitNameUnmodified(u) return UnitName(u) end
function GetAppropriateTooltip() return GameTooltip end
function BNSendGameData() end
function BNSendWhisper() end
function GetPlayerFacing() return 0 end
function ClearCursor() end
function GetCursorInfo() return nil end
function SetItemRef() end
function IsItemInRange() return nil end
function GetCurrentEnvironment() return _G end
function SetDesaturation() end
-- "Secret" strings like the client's in combat: H.Secret(true) makes H.secret's strings throw when
-- indexed (s:match and the like) and issecretvalue true for them; H.Secret(false) undoes it.
-- (Plain Lua cannot make == throw too; the module asks issecretvalue first, so this covers it.)
H.secret = {}
local stringMeta = getmetatable("")
local plainIndex = stringMeta.__index
function issecretvalue(v) return type(v) == "string" and H.secret[v] == true end
function H.Secret(on)
    if on then
        stringMeta.__index = function(s, k)
            if H.secret[s] then error("attempt to index a secret string value", 2) end
            return plainIndex[k]
        end
    else
        stringMeta.__index = plainIndex
        H.secret = {}
    end
end
function CreateVector2D(x, y)
    return { x = x, y = y, GetXY = function(s) return s.x, s.y end, SetXY = function(s, a, b) s.x, s.y = a, b end }
end
C_Map.GetWorldPosFromMapPos = function(_, pos) return 0, CreateVector2D(pos and pos.x or 0, pos and pos.y or 0) end
H.cvars.minimapZoom, H.cvars.minimapInsideZoom, H.cvars.rotateMinimap = "0", "0", "0"
QUEST_MONSTERS_KILLED, QUEST_ITEMS_NEEDED, QUEST_OBJECTS_FOUND = "%s slain: %d/%d", "%s: %d/%d", "%s: %d/%d"
QUEST_FACTION_NEEDED, QUEST_PLAYERS_KILLED = "%s: %s / %s", "Players slain: %d/%d"
STATICPOPUP_NUMDIALOGS, INBOXITEMS_TO_DISPLAY = 4, 7
for i = 0, 4 do _G["EXPANSION_NAME" .. i] = "Expansion " .. i end
Settings.VarType = { Boolean = "boolean", String = "string", Number = "number" }
Settings.RegisterVerticalLayoutSubcategory = function(parent, name) return Settings.RegisterCanvasLayoutCategory(nil, name) end
-- Like the client: a setting with no saved value starts at its default.
Settings.RegisterAddOnSetting = function(_, variable, key, tbl, kind, name, default)
    if tbl and key ~= nil and tbl[key] == nil then tbl[key] = default end
    return { GetValue = function() return tbl and tbl[key] end, SetValue = function(_, v) if tbl then tbl[key] = v end end,
        SetValueChangedCallback = function() end, GetVariable = function() return variable end }
end
Settings.CreateDropdown = function() return {} end
Settings.CreateControlTextContainer = function()
    local c = { data = {} }
    function c:Add(v, label) self.data[#self.data + 1] = { value = v, label = label } end
    function c:GetData() return self.data end
    return c
end
C_KeyBindings = { GetBindingByKey = function() return nil end }
C_PetBattles = { IsInBattle = function() return false end }
C_DateAndTime.GetTodaysDate = C_DateAndTime.GetCurrentCalendarTime
