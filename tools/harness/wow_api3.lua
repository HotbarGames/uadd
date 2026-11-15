-- Harness API, part 3: classic quest log, watch list and unit helpers. The quest log is empty.
local function none() return nil end
local function zero() return 0 end
local function no() return false end
local function noop() end

for name, fn in pairs({
    SetBinding = noop, GetQuestLogIndexByID = zero, GetNumQuestWatches = zero, IsQuestWatched = no,
    GetQuestGreenRange = function() return 8 end, GetQuestIDFromLogIndex = none, GetNumAutoQuestPopUps = zero,
    GetInstanceInfo = function() return "Eastern Kingdoms", "none", 0, "", 5, 0, false, 0 end,
    UnitIsConnected = function() return true end, UnitInBattleground = none, IsModifiedClick = no,
    IsMouseButtonDown = no, MouseIsOver = no, GetMinimapShape = function() return "ROUND" end,
    GetPlayerMapPosition = function() return 0.5, 0.5 end, GetQuestTimers = none,
    GetDailyQuestsCompleted = zero, GetQuestResetTime = function() return 3600 end, GetGuildInfo = none,
    ChatFrameAddMessageEventFilter = noop, ChatFrameRemoveMessageEventFilter = noop,
    FauxScrollFrame_GetOffset = zero, QuestLog_Update = noop, QuestWatch_Update = noop, WatchFrame_Update = noop,
    GetItemIcon = none, UnitIsEnemy = no, UnitIsFriend = function() return true end, UnitCastingInfo = none,
    UnitChannelInfo = none, GetWorldElapsedTime = none, IsQuestFlaggedCompleted = no,
    GetTrackedAchievements = none, RemoveQuestWatch = noop, GetQuestIndexForWatch = none,
    GetNumQuestChoices = zero, GetQuestLogTimeLeft = none, GetQuestLogSpecialItemInfo = none,
    GetAchievementInfo = none, GetContainerItemInfo = none, GetItemCooldown = function() return 0, 0, 1 end,
    QuestLog_SetSelection = noop, GameTooltip_SetTitle = noop, GameTooltip_AddNormalLine = noop,
}) do
    if rawget(_G, name) == nil then rawset(_G, name, fn) end
end
LinkUtil = { handlers = {} }
function LinkUtil.RegisterLinkHandler(kind, fn) LinkUtil.handlers[kind] = fn end
function LinkUtil.SplitLink(link) return link:match("|H([^|]+)|h(.-)|h") end
-- Blizzard UI functions the addons hook (hooksecurefunc errors on a missing target, as in the client).
for _, name in ipairs({ "AddQuestWatch", "AuctionHouseFilterButton_SetUp", "AutoQuestWatch_Insert",
    "CalendarDayButton_OnEnter", "ChatEdit_InsertLink", "ChatFrame_OnHyperlinkShow", "ClassTrainerFrame_InitCategoryButton",
    "ClassTrainerFrame_InitServiceButton", "DeleteCursorItem", "GameTooltip_AddInstructionLine", "GuildNewsButton_SetText",
    "InspectPaperDollItemSlotButton_OnEnter", "LFGBrowseSearchEntryTooltip_UpdateAndShow", "LFGListingCategorySelection_AddButton",
    "ManageFramePositions", "Minimap_OnUpdate", "MountJournal_InitMountButton", "NavBar_AddButton", "PetJournal_InitPetButton",
    "PetJournal_UpdatePetCard", "QuestFrameGreetingPanel_OnShow", "QuestInfo_Display", "QuestLogQuests_Update",
    "RaidInfoFrame_InitButton", "ScrollFrame_OnScrollRangeChanged", "TimeManagerClockButton_UpdateTooltip",
    "ToySpellButton_UpdateButton", "UIParent_ManageFramePositions" }) do
    if rawget(_G, name) == nil then rawset(_G, name, noop) end
end
-- Classic-style globals behind QuestieCompat (each has no C_ twin in the harness).
for name, fn in pairs({
    AbandonQuest = noop, ExpandFactionHeader = noop, GetAbandonQuestItems = none, GetAbandonQuestName = none,
    GetActiveQuestID = none, GetGossipActiveQuests = none, GetGossipAvailableQuests = none, GetQuestTagInfo = none,
    GetQuestUiMapID = none, GetStablePetFoodTypes = none, QuestLog_UpdateQuestDetails = noop,
    SelectGossipActiveQuest = noop, SelectGossipAvailableQuest = noop, SetAbandonQuest = noop, StaticPopup_Resize = noop,
    ActionStatus_DisplayMessage = noop, GetNumSkillLines = zero, ExpandSkillHeader = noop, GetSkillLineInfo = none,
    IsSpellKnown = no, GetItemSpell = none, IsEquippableItem = no, GetQuestLink = none, GetNumQuestLeaderBoards = zero,
}) do
    if rawget(_G, name) == nil then rawset(_G, name, fn) end
end
-- Modern C_ calls on the Forever path of QuestieCompat (empty quest log, no timers, no nameplates).
local function empty() return {} end
local function fill(t, fns) for k, v in pairs(fns) do if t[k] == nil then t[k] = v end end end
fill(C_QuestLog, { GetNumQuestObjectives = zero, GetQuestIDForQuestWatchIndex = none, GetQuestLink = none,
    GetQuestTimers = empty, GetSelectedQuest = zero, SetSelectedQuest = noop, IsFailed = no, AbandonQuest = noop,
    GetAbandonQuestItems = empty, GetAbandonQuestName = none, SetAbandonQuest = noop, GetNextWaypoint = none })
fill(C_Item, { GetItemCooldown = function() return 0, 0, true end, GetItemSpell = none, IsEquippableItem = no,
    IsItemInRange = none })
fill(C_Container, { GetBagName = none, GetItemCooldown = function() return 0, 0, 1 end })
fill(C_GossipInfo, { SelectActiveQuest = noop, SelectAvailableQuest = noop })
fill(C_Map, { GetMapGroupMembersInfo = empty, OpenWorldMap = noop })
fill(C_Minimap, { GetViewRadius = function() return 233 end })
C_NamePlate = C_NamePlate or { GetNamePlates = empty, GetNamePlateForUnit = none }
C_Secrets = C_Secrets or { ShouldAurasBeSecret = no }
C_StringUtil = C_StringUtil or { WrapString = function(s) return s end, TruncateWhenZero = function(n) return n end }
C_SpellBook = C_SpellBook or {}
fill(C_SpellBook, { IsSpellKnown = no })
function WorldMapFrame:OnMapChanged() end

-- EnumerateFrames(): every frame in creation order (FontStrings, textures and font objects are not
-- frames); EnumerateFrames(f) gives the one after f.
local enumAt = setmetatable({}, { __mode = "k" })
function EnumerateFrames(f)
    local all = HARNESS.widgets()
    local i = 0
    if f ~= nil then
        i = enumAt[f]
        if not i then
            for j, w in ipairs(all) do if w == f then i = j break end end
            if not i then return nil end
        end
    end
    for j = i + 1, #all do
        local w = all[j]
        local ok, kind = pcall(w.GetObjectType, w)
        if ok and HARNESS.frameTypes[kind] then enumAt[w] = j return w end
    end
end
