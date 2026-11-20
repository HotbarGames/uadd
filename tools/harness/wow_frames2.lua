-- Harness Blizzard frames, part 2: more hidden windows and their text regions.
local function window(name, parent)
    local f = CreateFrame("Frame", name, parent or UIParent)
    f:Hide()
    return f
end
for _, name in ipairs({ "DurabilityFrame", "QuestTimerFrame", "CharacterFrame", "FriendsFrame", "MerchantFrame",
    "ItemTextFrame", "QuestInfoFrame", "QuestInfoRewardsFrame", "ColorPickerFrame", "ReputationFrame", "SkillsFrame",
    "PaperDollFrame", "CastingBarFrame", "RaidFrame", "QueueStatusFrame", "PVPRankFrame", "QuestScrollFrame",
    "QuestLogDetailScrollFrame", "SpellBookFrame", "TradeFrame", "TaxiFrame", "StaticPopup1", "StaticPopup2",
    "StaticPopup3", "StaticPopup4" }) do
    window(name)
end
for _, name in ipairs({ "QuestFrameGreetingPanel", "QuestFrameProgressPanel", "QuestFrameRewardPanel" }) do
    window(name, QuestFrame)
end
GossipFrameGreetingPanel = GossipFrame.GreetingPanel
QuestLogListScrollFrame = CreateFrame("ScrollFrame", "QuestLogListScrollFrame", QuestLogFrame)
for _, name in ipairs({ "ItemTextPageText", "QuestInfoDescriptionText", "QuestInfoObjectivesText", "QuestInfoRewardText",
    "QuestProgressText", "QuestProgressTitleText", "QuestProgressRequiredItemsText", "QuestLogObjectivesText",
    "QuestLogQuestTitle", "QuestLogQuestDescription", "QuestInfoDescriptionHeader", "QuestInfoObjectivesHeader",
    "ItemTextFrameTitleText", "QuestGreetingText", "GreetingText", "CurrentQuestsText", "AvailableQuestsText" }) do
    UIParent:CreateFontString(name)
end
CreateFont("GameTooltipHeaderText")
-- Since Questie 12.8 an options tab scrolls in the client's scroll box (QuestieOptionsEngine.lua:204-230):
-- the "EventFrame" frame type, the settings page's width, the scroll view and ScrollUtil.
HARNESS.frameTypes.EventFrame = 1
SettingsPanel.Container = CreateFrame("Frame", nil, SettingsPanel)
SettingsPanel.Container.SettingsCanvas = CreateFrame("Frame", nil, SettingsPanel.Container)
SettingsPanel.Container.SettingsCanvas:SetSize(635, 570)
function CreateScrollBoxLinearView() return { SetPadding = function() end, SetPanExtent = function() end } end
ScrollUtil = { InitScrollBoxWithScrollBar = function() end, AddManagedScrollBarVisibilityBehavior = function() end }
-- Its controls (QuestieOptionsControls.lua): box art, label sizes and the client's menu dropdown.
NineSliceUtil = { ApplyLayoutByName = function() end, ApplyLayout = function() end }
function HARNESS.Widget:SetFontHeight(h)
    local path, _, flags = self:GetFont()
    if path then self:SetFont(path, h, flags) end
end
HARNESS.frameTypes.DropdownButton = 1
-- WowStyle1DropdownTemplate: SetupMenu keeps the menu's generator and runs it at once; the text
-- shows the selected radio entry, as in the client. An open menu is one frame shared by every
-- dropdown (the client's menu pools its entry frames too): each entry's font is set up again,
-- then its text, as the client does when it reuses an entry frame.
local function drawMenu(d, texts)
    local m = rawget(_G, "HarnessMenu") or CreateFrame("Frame", "HarnessMenu", UIParent)
    m.entries = m.entries or {}
    m:SetPoint("CENTER")
    for i, t in ipairs(texts) do
        local e = m.entries[i]
        if not e then
            e = CreateFrame("Button", nil, m)
            e.fontString = e:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            m.entries[i] = e
        end
        e.fontString:SetFontObject("GameFontHighlightSmall")
        e.fontString:SetText(t)
        e:Show()
    end
    for i = #texts + 1, #m.entries do m.entries[i]:Hide() end
    m:Show()
    d.menu = m
end
local function generate(d)
    local selected, texts = nil, {}
    local function entry() return { AddInitializer = function() end, SetEnabled = function() end } end
    local root = { SetScrollMode = function() end, CreateDivider = entry, CreateTitle = entry, CreateButton = entry,
        CreateCheckbox = entry, CreateSpacer = entry }
    function root:CreateRadio(text, isSelected, _, data)
        if not selected and isSelected(data) then selected = text end
        texts[#texts + 1] = text
        return entry()
    end
    if d.__menuGen then d.__menuGen(d, root) end
    d.Text:SetText(selected or d.__default or "")
    if d.__menuOpen then drawMenu(d, texts) end
end
function HARNESS.menuDropdown(d)
    d.Text = d:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    d.SetDefaultText = function(self, t) self.__default, self.defaultText = t, t generate(self) end
    d.SetupMenu = function(self, gen) self.__menuGen = gen generate(self) end
    d.GenerateMenu = generate
    d.OpenMenu = function(self) self.__menuOpen = true generate(self) end
    d.CloseMenu = function(self)
        self.__menuOpen = false
        if self.menu then self.menu:Hide() self.menu = nil end
    end
    d.IsMenuOpen = function(self) return self.__menuOpen == true end
    d.GetText = function(self) return self.Text:GetText() end
end
-- The settings window's layout of a category (SettingsPanel:GetLayout(category):GetFrame() is its canvas).
SettingsPanel.GetLayout = function(_, cat) return { GetFrame = function() return cat and cat.frame end } end
-- The client's Menu and MenuUtil, opt in (a flow calls HARNESS.menuApi() before its game starts): other modules
-- check for MenuUtil, so a global one would change their flows. HARNESS.menuOpen(tag) runs each ModifyMenu
-- callback of that tag on a fresh root and returns its element descriptions; HARNESS.menuThrow makes
-- MenuUtil.SetElementText fail.
function HARNESS.menuApi()
    local callbacks = {}
    local Root = {}
    Root.__index = Root
    local function Desc(text) return { text = text, SetEnabled = function() end } end
    function Root:CreateDivider() self.items[#self.items + 1] = Desc(nil) end
    function Root:CreateTitle(t) self.items[#self.items + 1] = Desc(t) end
    function Root:Insert(d) self.items[#self.items + 1] = d end
    function Root:EnumerateElementDescriptions() return ipairs(self.items) end
    MenuUtil = { CreateCheckbox = function(text) return Desc(text) end,
        GetElementText = function(d) return d.text end,
        SetElementText = function(d, t)
            if HARNESS.menuThrow then error("stand-in: SetElementText failed") end
            d.text = t
        end }
    Menu = { ModifyMenu = function(tag, fn)
        callbacks[tag] = callbacks[tag] or {}
        table.insert(callbacks[tag], fn)
    end }
    function HARNESS.menuOpen(tag)
        local root = setmetatable({ items = {} }, Root)
        for _, fn in ipairs(callbacks[tag] or {}) do fn(nil, root) end
        return root.items
    end
end
-- The fonts of the Questie options tab header (QuestieOptionsEngine.lua:179-191).
CreateFont("GameFontNormalHuge"):SetFont("Fonts\\FRIZQT__.TTF", 20, "")
CreateFont("Game13Font"):SetFont("Fonts\\FRIZQT__.TTF", 13, "")
-- The font of AceGUI's dropdown list items (AceGUIWidget-DropDown-Items.lua:179).
CreateFont("GameFontNormalSmall"):SetFont("Fonts\\FRIZQT__.TTF", 10, "")
-- The client's global string Questie's icons tab joins to a menu entry (NativeOptionsIcons.lua:1043).
SETTINGS = rawget(_G, "SETTINGS") or "Settings"
-- The fonts of Questie 12.8's controls (QuestieOptionsControls.lua) and of the client's menu entries.
for name, size in pairs({ GameFontNormalMed1 = 14, GameFontHighlightSmall = 10, GameFontNormal = 12,
    GameFontNormalSmall2 = 11, GameFontDisableTiny = 9, GameFontHighlight = 12 }) do
    if not rawget(_G, name) then CreateFont(name):SetFont("Fonts\\FRIZQT__.TTF", size, "") end
end
-- Cast bars (CastingBarFrame.xml): hidden while nothing is cast; .Text, and .unit for the unit they show.
for name, unit in pairs({ PlayerCastingBarFrame = "player", OverlayPlayerCastingBarFrame = "player",
    PetCastingBarFrame = "pet", TargetFrameSpellBar = "target", FocusFrameSpellBar = "focus" }) do
    local bar = window(name)
    bar.unit = unit
    bar.Text = bar:CreateFontString(name .. "Text")
end
TargetFrame.spellbar = TargetFrameSpellBar
