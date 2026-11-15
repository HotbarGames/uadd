-- Harness game API: the client functions and tables the addons call, with fixed answers for an
-- enUS Forever client (Interface 16001), a level-60 character in Stormwind, out of combat.
local H = HARNESS

function GetLocale() return H.locale or "enUS" end
function GetBuildInfo() return "1.60.1", "69913", "Oct 1 2026", 16001 end
WOW_PROJECT_ID, WOW_PROJECT_MAINLINE, WOW_PROJECT_CLASSIC = 1, 1, 2
WOW_PROJECT_BURNING_CRUSADE_CLASSIC, WOW_PROJECT_WRATH_CLASSIC, WOW_PROJECT_CATACLYSM_CLASSIC = 5, 11, 14
WOW_PROJECT_MISTS_CLASSIC = 19
LE_EXPANSION_LEVEL_CURRENT, LE_EXPANSION_CLASSIC = 0, 0
function GetExpansionLevel() return 0 end
function GetMaxPlayerLevel() return 60 end
function GetClassicExpansionLevel() return 0 end
function IsLoggedIn() return H.loggedIn end
function InCombatLockdown() return H.combat end
function UnitAffectingCombat() return H.combat end
function IsShiftKeyDown() return H.keys.SHIFT end
function IsControlKeyDown() return H.keys.CTRL end
function IsAltKeyDown() return H.keys.ALT end
function IsModifierKeyDown() return H.keys.SHIFT or H.keys.CTRL or H.keys.ALT end
function GetCVar(k) return H.cvars[k] end
function GetCVarBool(k) local v = H.cvars[k] return v == "1" or v == true end
function SetCVar(k, v) H.cvars[k] = v and tostring(v) end
function GetCVarDefault(k) return H.cvars[k] end
H.cvars = { portal = "EU", textLocale = "enUS", audioLocale = "enUS" }
C_CVar = { GetCVar = GetCVar, GetCVarBool = GetCVarBool, SetCVar = SetCVar,
    RegisterCVar = function() end, GetCVarDefault = GetCVarDefault }
function GetRealmName() return "Harness" end
function GetNormalizedRealmName() return "Harness" end
function GetCurrentRegion() return 3 end
function GetCurrentRegionName() return "EU" end
function UnitName(u) if u == "player" then return "Tester", nil end return nil end
function GetUnitName(u) return (UnitName(u)) end
function UnitFullName(u) if u == "player" then return "Tester", "Harness" end end
function UnitGUID(u) if u == "player" then return "Player-1-00000001" end end
function UnitLevel(u) if u == "player" then return 60 end return 0 end
function UnitEffectiveLevel(u) return UnitLevel(u) end
function UnitClass(u) if u == "player" then return "Warrior", "WARRIOR", 1 end end
function UnitClassBase(u) return "WARRIOR", 1 end
function UnitRace(u) if u == "player" then return "Human", "Human", 1 end end
function UnitFactionGroup(u) return "Alliance", "Alliance" end
function UnitSex() return 2 end
function UnitExists(u) return u == "player" end
function UnitIsDeadOrGhost() return false end
function UnitIsDead() return false end
function UnitIsGhost() return false end
function UnitOnTaxi() return false end
function UnitInParty() return false end
function UnitInRaid() return nil end
function UnitIsUnit(a, b) return a == b end
function UnitIsPlayer(u) return u == "player" end
function UnitHealth() return 100 end
function UnitHealthMax() return 100 end
function UnitXP() return 0 end
function UnitXPMax() return 1 end
function UnitPosition() return 0, 0, 0, 0 end
function UnitBuff() end
function UnitAura() end
function IsInGroup() return false end
function IsInRaid() return false end
function IsInGuild() return false end
function IsInInstance() return false, "none" end
function GetNumGroupMembers() return 0 end
function GetNumSubgroupMembers() return 0 end
function IsResting() return true end
function IsMounted() return false end
function IsFlying() return false end
function IsSpellKnown() return false end
function IsPlayerSpell() return false end
function GetSpellInfo(id) return nil end
function GetItemInfo(id) return nil end
function GetItemInfoInstant(id) return nil end
function GetItemCount() return 0 end
function GetProfessions() return nil end
function GetNumSkillLines() return 0 end
function GetSkillLineInfo() end
function GetNumFactions() return 0 end
function GetFactionInfo() end
function GetFactionInfoByID() end
function GetQuestsCompleted() return {} end
function GetQuestLogTitle() return nil end
function GetNumQuestLogEntries() return 0, 0 end
function GetQuestLogSelection() return 0 end
function SelectQuestLogEntry() end
function GetQuestLogLeaderBoard() end
function GetNumQuestLeaderBoards() return 0 end
function IsQuestComplete() return false end
function GetQuestLink() end
function GetQuestID() return 0 end
function GetTitleText() return "" end
function GetNumGossipActiveQuests() return 0 end
function GetNumGossipAvailableQuests() return 0 end
function GetActiveTitle() return nil end      -- no quest greeting window is open
function GetAvailableTitle() return nil end
function GetMoney() return 0 end
function GetZoneText() return "Stormwind City" end
function GetRealZoneText() return "Stormwind City" end
function GetSubZoneText() return "" end
function GetMinimapZoneText() return "Stormwind City" end
function GetZonePVPInfo() return nil end
function GetFramerate() return 60 end
function GetNetStats() return 0, 0, 20, 20 end
function GetScreenWidth() return 1920 end
function GetScreenHeight() return 1080 end
function GetPhysicalScreenSize() return 1920, 1080 end
function GetAddOnMemoryUsage() return 0 end
function UpdateAddOnMemoryUsage() end
function GetAddOnCPUUsage() return 0 end
function GetCursorPosition() return 0, 0 end
function GetMouseFocus() return nil end
function GetMouseFoci() return {} end
function PlaySound() end
function PlaySoundFile() end
function StopSound() end
function GetBindingKey() end
function SetOverrideBindingClick() end
function ClearOverrideBindings() end
function CreateMacro() end
function RequestTimePlayed() end
function GetGameTime() return 12, 0 end
function GetInventoryItemID() end
function GetContainerNumSlots() return 0 end
function GetChannelList() return end
function GetChannelName() return 0 end
function JoinTemporaryChannel() end
function LeaveChannelByName() end
function SendChatMessage() end
function SendAddonMessage() return true end
function RegisterAddonMessagePrefix() return true end
C_ChatInfo = { SendAddonMessage = function() return true end, RegisterAddonMessagePrefix = function() return true end,
    IsAddonMessagePrefixRegistered = function() return true end, GetChannelName = function() return 0 end,
    SendChatMessage = function() end, SendAddonMessageLogged = function() return true end }
BNGetInfo = function() return nil end
BNFeaturesEnabledAndConnected = function() return false end
function ChatFrame_AddMessageEventFilter() end
function ChatFrame_RemoveMessageEventFilter() end
function ChatFrame_OpenChat() end
function GetNumBindings() return 0 end
function IsAddonMessagePrefixRegistered() return true end
function hooksecurefunc_exists() return true end
function GetClassColor() return 1, 1, 1, "ffffffff" end
function GetQuestDifficultyColor() return { r = 1, g = 1, b = 0 } end
function GetDifficultyColor() return { r = 1, g = 1, b = 0 } end
function ReloadUI() H.reloadRequested = true end
function StaticPopup_Show() end
function StaticPopup_Hide() end
function UIFrameFadeIn() end
function UIFrameFadeOut() end
function ShowUIPanel(f) if f then f:Show() end end
function HideUIPanel(f) if f then f:Hide() end end
function ToggleFrame(f) if f then f:SetShown(not f:IsShown()) end end
function UIDropDownMenu_Initialize() end
function CloseDropDownMenus() end
function EasyMenu() end
function InterfaceOptions_AddCategory(frame) if frame and frame.Hide then frame:Hide() end end
function InterfaceOptionsFrame_OpenToCategory() end
function GetText(t) return t end
function BreakUpLargeNumbers(n) return tostring(n) end
function FormatLargeNumber(n) return tostring(n) end
function SecondsToTime(s) return tostring(s) .. " sec" end
function GetCoinTextureString(n) return tostring(n) end
function Mixin(o, ...) for i = 1, select("#", ...) do for k, v in pairs((select(i, ...))) do o[k] = v end end return o end
function CreateFromMixins(...) return Mixin({}, ...) end
function CreateAndInitFromMixin(m, ...) local o = Mixin({}, m) if o.Init then o:Init(...) end return o end
function CreateColor(r, g, b, a)
    return { r = r, g = g, b = b, a = a or 1, GetRGB = function(s) return s.r, s.g, s.b end,
        GetRGBA = function(s) return s.r, s.g, s.b, s.a end,
        WrapTextInColorCode = function(s, t) return t end,
        GenerateHexColor = function() return "ffffffff" end }
end
NORMAL_FONT_COLOR, HIGHLIGHT_FONT_COLOR = CreateColor(1, 0.82, 0), CreateColor(1, 1, 1)
RED_FONT_COLOR, GREEN_FONT_COLOR, GRAY_FONT_COLOR = CreateColor(1, 0.1, 0.1), CreateColor(0.1, 1, 0.1), CreateColor(0.5, 0.5, 0.5)
YELLOW_FONT_COLOR, WHITE_FONT_COLOR, DISABLED_FONT_COLOR = CreateColor(1, 1, 0), CreateColor(1, 1, 1), CreateColor(0.5, 0.5, 0.5)
RAID_CLASS_COLORS = setmetatable({}, { __index = function() return CreateColor(1, 1, 1) end })
FACTION_BAR_COLORS = setmetatable({}, { __index = function() return CreateColor(1, 1, 1) end })
ITEM_QUALITY_COLORS = setmetatable({}, { __index = function() return CreateColor(1, 1, 1) end })
LOCALE_enUS, LOCALE_ruRU = true, nil
STANDARD_TEXT_FONT, UNIT_NAME_FONT, DAMAGE_TEXT_FONT, NAMEPLATE_FONT = "Fonts\\FRIZQT__.TTF", "Fonts\\FRIZQT__.TTF",
    "Fonts\\FRIZQT__.TTF", "Fonts\\FRIZQT__.TTF"
NUM_CONTAINER_FRAMES, NUM_BAG_SLOTS, NUM_GROUP_LOOT_FRAMES, MAX_PARTY_MEMBERS = 13, 4, 4, 4
NUM_CHAT_WINDOWS, MAX_QUESTS, MAX_QUESTLOG_QUESTS = 10, 20, 20
UISpecialFrames, UIPanelWindows, CHAT_FRAMES = {}, {}, {}
StaticPopupDialogs = {}
SlashCmdList = {}
hash_SlashCmdList = {}
ChatTypeInfo = setmetatable({}, { __index = function() return { r = 1, g = 1, b = 1 } end })
ERR_QUEST_ACCEPTED_S, ERR_QUEST_COMPLETE_S = "Quest accepted: %s", "%s completed."
ERR_QUEST_OBJECTIVE_COMPLETE_S, ERR_QUEST_UNKNOWN_COMPLETE = "%s (Complete)", "Objective Complete."
OKAY, CANCEL, YES, NO, ACCEPT, DECLINE, CLOSE = "Okay", "Cancel", "Yes", "No", "Accept", "Decline", "Close"
LEVEL, NAME, QUESTS_LABEL, TRACK_QUEST, UNTRACK_QUEST = "Level", "Name", "Quests", "Track", "Untrack"
FONT_COLOR_CODE_CLOSE, NORMAL_FONT_COLOR_CODE, HIGHLIGHT_FONT_COLOR_CODE = "|r", "|cffffd200", "|cffffffff"
RED_FONT_COLOR_CODE, GREEN_FONT_COLOR_CODE = "|cffff2020", "|cff20ff20"
SOUNDKIT = setmetatable({}, { __index = function() return 0 end })
Enum = setmetatable({}, { __index = function(t, k)
    local e = setmetatable({}, { __index = function() return 0 end }) rawset(t, k, e) return e end })
Constants = setmetatable({}, { __index = function(t, k)
    local e = setmetatable({}, { __index = function() return 0 end }) rawset(t, k, e) return e end })

-- ── AddOn info: the runner fills H.addons = { name -> { meta = {...}, loaded = bool } } ──────────
H.addons, H.addonOrder = {}, {}
local function find(name)
    if type(name) == "number" then name = H.addonOrder[name] end
    if type(name) ~= "string" then return nil end
    local a = H.addons[name]
    if a then return a, name end
    for n, x in pairs(H.addons) do if n:lower() == name:lower() then return x, n end end
end
local function meta(name, field)
    local a = find(name)
    if not a or type(field) ~= "string" then return nil end
    local v = a.meta[field]
    if v == nil then v = a.metaLower[field:lower()] end
    return v
end
local function loaded(name) local a = find(name) if not a then return false, false end
    return a.loading == true or a.loaded == true, a.loaded == true end
local function info(name)
    local a, n = find(name)
    if not a then return nil, nil, nil, false, "MISSING", "INSECURE", false end
    return n, meta(n, "Title"), meta(n, "Notes"), true, nil, "INSECURE", false
end
C_AddOns = {
    GetAddOnMetadata = meta,
    IsAddOnLoaded = loaded,
    GetAddOnInfo = info,
    GetNumAddOns = function() return #H.addonOrder end,
    GetAddOnEnableState = function(name) return find(name) and 2 or 0 end,
    IsAddOnLoadOnDemand = function() return false end,
    LoadAddOn = function(name) local a = find(name) if a then return a.loaded == true, nil end return false, "MISSING" end,
    EnableAddOn = function() end, DisableAddOn = function() end,
    DoesAddOnExist = function(name) return find(name) ~= nil end,
    GetAddOnDependencies = function() return end,
    GetAddOnOptionalDependencies = function() return end,
}
GetAddOnMetadata, IsAddOnLoaded, GetAddOnInfo = meta, loaded, info
GetNumAddOns, LoadAddOn = C_AddOns.GetNumAddOns, C_AddOns.LoadAddOn
GetAddOnEnableState = function(_, name) return C_AddOns.GetAddOnEnableState(name) end

