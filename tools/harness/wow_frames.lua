-- Harness Blizzard frames: the named frames the addons look up or hook, plus EventRegistry,
-- Settings and the chat frame. Windows start hidden, like after login; zone text starts empty.
local H = HARNESS

UIParent = CreateFrame("Frame", "UIParent")
WorldFrame = CreateFrame("Frame", "WorldFrame")
for i = 1, NUM_CHAT_WINDOWS do
    local f = CreateFrame("ScrollingMessageFrame", "ChatFrame" .. i, UIParent)
    CreateFrame("EditBox", "ChatFrame" .. i .. "EditBox", f)
    CHAT_FRAMES[i] = "ChatFrame" .. i
end
DEFAULT_CHAT_FRAME, SELECTED_CHAT_FRAME = ChatFrame1, ChatFrame1
UIErrorsFrame = CreateFrame("MessageFrame", "UIErrorsFrame", UIParent)
-- print() hands its values to the print handler (getprinthandler / setprinthandler, as in the
-- client). The game's own handler joins them with spaces and goes to chat through
-- DEFAULT_CHAT_FRAME:AddMessage (an addon that wraps AddMessage sees printed lines too).
local function GamePrint(...)
    local t, n = { ... }, select("#", ...)
    for i = 1, n do t[i] = tostring(t[i]) end
    local msg, frame = table.concat(t, " ", 1, n), DEFAULT_CHAT_FRAME
    if type(frame) == "table" and type(frame.AddMessage) == "function" then frame:AddMessage(msg)
    else H.chat[#H.chat + 1] = msg end
end
local printHandler = GamePrint
function print(...) return printHandler(...) end
function getprinthandler() return printHandler end
function setprinthandler(f)
    if type(f) ~= "function" then error("Usage: setprinthandler(func)", 2) end
    printHandler = f
end
H.GamePrint = GamePrint

local function window(name, parent)
    local f = CreateFrame("Frame", name, parent or UIParent)
    f:Hide()
    return f
end

-- Tooltips.
local function tooltip(name)
    local t = CreateFrame("GameTooltip", name, UIParent)
    for i = 1, 8 do
        t:CreateFontString(name .. "TextLeft" .. i)
        t:CreateFontString(name .. "TextRight" .. i)
    end
    t:Hide()
    return t
end
tooltip("GameTooltip") tooltip("ItemRefTooltip") tooltip("ShoppingTooltip1") tooltip("ShoppingTooltip2")
tooltip("EmbeddedItemTooltip") tooltip("SettingsTooltip")
GameTooltip.ItemTooltip = { Tooltip = tooltip("GameTooltipItemTooltip") }

-- Zone text (ZoneHooks pins these at load).
ZoneTextFrame = CreateFrame("Frame", "ZoneTextFrame", UIParent)
ZoneTextString = ZoneTextFrame:CreateFontString("ZoneTextString")
SubZoneTextFrame = CreateFrame("Frame", "SubZoneTextFrame", UIParent)
SubZoneTextString = SubZoneTextFrame:CreateFontString("SubZoneTextString")
PVPInfoTextString = ZoneTextFrame:CreateFontString("PVPInfoTextString")
PVPArenaTextString = ZoneTextFrame:CreateFontString("PVPArenaTextString")
ZoneTextFrame:Hide() SubZoneTextFrame:Hide()

-- Quest and gossip windows: PortraitFrame title through GetTitleText().
QuestFrame = window("QuestFrame")
QuestFrame:SetTitle("")
GossipFrame = window("GossipFrame")
GossipFrame:SetTitle("")
GossipFrame.GreetingPanel = CreateFrame("Frame", nil, GossipFrame)
GossipFrame.GreetingPanel.ScrollBox = CreateFrame("Frame", nil, GossipFrame.GreetingPanel)
QuestLogFrame = window("QuestLogFrame")
QuestFrameDetailPanel = window("QuestFrameDetailPanel", QuestFrame)
QuestTitleText = QuestFrame:CreateFontString("QuestTitleText")
QuestInfoTitleHeader = QuestFrame:CreateFontString("QuestInfoTitleHeader")
QuestWatchFrame = window("QuestWatchFrame")

-- Group loot rolls: GroupLootFrameN.Name.
for i = 1, NUM_GROUP_LOOT_FRAMES do
    local f = window("GroupLootFrame" .. i)
    f.Name = f:CreateFontString("GroupLootFrame" .. i .. "Name")
end
LootFrame = window("LootFrame")
LootFrame:SetTitle("")

-- Bags, bank, mail.
for i = 1, NUM_CONTAINER_FRAMES do
    local f = window("ContainerFrame" .. i)
    f:SetTitle("")
    f.Name = f:GetTitleText()
end
ContainerFrameCombinedBags = window("ContainerFrameCombinedBags")
ContainerFrameCombinedBags:SetTitle("")
BankFrame = window("BankFrame")
BankFrame:SetTitle("")
for i = 1, 3 do CreateFrame("Button", "BankFrameTab" .. i, BankFrame):SetText("Tab " .. i) end
MailFrame = window("MailFrame")
MailFrame:SetTitle("")
for i = 1, 2 do CreateFrame("Button", "MailFrameTab" .. i, MailFrame):SetText("Tab " .. i) end
for i = 1, 7 do
    local b = CreateFrame("Button", "MailItem" .. i, MailFrame)
    b:CreateFontString("MailItem" .. i .. "Sender")
    b:CreateFontString("MailItem" .. i .. "Subject")
end
OpenMailFrame = window("OpenMailFrame")
OpenMailSender = CreateFrame("Frame", "OpenMailSender", OpenMailFrame)
OpenMailSender.Name = OpenMailSender:CreateFontString("OpenMailSenderName")
OpenMailSubject = OpenMailFrame:CreateFontString("OpenMailSubject")

-- Map, minimap, menus.
WorldMapFrame = window("WorldMapFrame")
WorldMapFrame.ScrollContainer = CreateFrame("ScrollFrame", nil, WorldMapFrame)
WorldMapFrame.ScrollContainer.Child = CreateFrame("Frame", nil, WorldMapFrame.ScrollContainer)
WorldMapFrame.BorderFrame = CreateFrame("Frame", nil, WorldMapFrame)
WorldMapFrame.overlayFrames, WorldMapFrame.dataProviders, WorldMapFrame.pinPools = {}, {}, {}
function WorldMapFrame:GetMapID() return 1453 end
function WorldMapFrame:AddDataProvider(p) self.dataProviders[p] = true if p.SetMap then p:SetMap(self) end end
function WorldMapFrame:RemoveDataProvider(p) self.dataProviders[p] = nil end
function WorldMapFrame:AddOverlayFrame() local f = CreateFrame("Frame", nil, self) return f end
function WorldMapFrame:GetCanvas() return self.ScrollContainer.Child end
function WorldMapFrame:GetCanvasContainer() return self.ScrollContainer end
function WorldMapFrame:EnumeratePinsByTemplate() return function() end end
function WorldMapFrame:RegisterCallback() end
function WorldMapFrame:SetMapID() end
function WorldMapFrame:RefreshAllDataProviders() end
function WorldMapFrame:GetPinFrameLevelsManager()
    return { AddFrameLevel = function() end, GetValidFrameLevel = function() return 1 end }
end
Minimap = CreateFrame("Minimap", "Minimap", UIParent)
function Minimap:GetZoom() return 0 end
function Minimap:GetZoomLevels() return 6 end
function Minimap:SetMaskTexture() end
MinimapCluster = CreateFrame("Frame", "MinimapCluster", UIParent)
MinimapZoneText = Minimap:CreateFontString("MinimapZoneText")
GameMenuFrame = window("GameMenuFrame")
InterfaceOptionsFrame = window("InterfaceOptionsFrame")
InterfaceOptionsFramePanelContainer = CreateFrame("Frame", "InterfaceOptionsFramePanelContainer", InterfaceOptionsFrame)
SettingsPanel = window("SettingsPanel")
ObjectiveTrackerFrame = window("ObjectiveTrackerFrame")
TargetFrame = window("TargetFrame")
PlayerFrame = CreateFrame("Frame", "PlayerFrame", UIParent)

-- EventRegistry: a callback registry keyed by event name.
EventRegistry = { callbacks = {} }
function EventRegistry:RegisterCallback(event, fn, owner, ...)
    local list = self.callbacks[event] or {}
    self.callbacks[event] = list
    list[owner or fn] = { fn = fn, owner = owner, args = { ... } }
    return owner or fn
end
function EventRegistry:UnregisterCallback(event, owner)
    if self.callbacks[event] then self.callbacks[event][owner] = nil end
end
function EventRegistry:RegisterFrameEventAndCallback(event, fn, owner, ...)
    return self:RegisterCallback(event, fn, owner, ...)
end
EventRegistry.UnregisterFrameEventAndCallback = EventRegistry.UnregisterCallback
function EventRegistry:TriggerEvent(event, ...)
    for _, c in pairs(self.callbacks[event] or {}) do
        if c.owner ~= nil then c.fn(c.owner, ...) else c.fn(event, ...) end
    end
end
function CreateCallbackRegistry() return setmetatable({ callbacks = {} }, { __index = EventRegistry }) end
CallbackRegistryMixin = {
    OnLoad = function(self) self.callbacks = {} end,
    SetUndefinedEventsAllowed = function() end,
    GenerateCallbackEvents = function(self, events)
        self.Event = self.Event or {}
        for _, e in ipairs(events) do self.Event[e] = e end
    end,
    RegisterCallback = EventRegistry.RegisterCallback,
    UnregisterCallback = EventRegistry.UnregisterCallback,
    TriggerEvent = EventRegistry.TriggerEvent,
}

-- Settings (the options window) and the old interface options.
local categories = {}
Settings = {
    RegisterCanvasLayoutCategory = function(frame, name)   -- the game hides the page until it is opened
        if frame and frame.Hide then frame:Hide() end
        local c = { name = name, frame = frame, ID = name, GetID = function(s) return s.ID end,
            GetName = function(s) return s.name end }
        categories[#categories + 1] = c
        return c, {}
    end,
    RegisterCanvasLayoutSubcategory = function(parent, frame, name) return Settings.RegisterCanvasLayoutCategory(frame, name) end,
    RegisterVerticalLayoutCategory = function(name) return Settings.RegisterCanvasLayoutCategory(nil, name) end,
    RegisterAddOnCategory = function() end,
    OpenToCategory = function() return true end,
    GetCategory = function(id) for _, c in ipairs(categories) do if c.ID == id then return c end end end,
    RegisterAddOnSetting = function() return { SetValueChangedCallback = function() end, GetValue = function() end } end,
    CreateCheckbox = function() end,
    SetOnValueChangedCallback = function() end,
}
SettingsPanel.GetCategoryList = function() return { GetCategory = Settings.GetCategory } end
-- Picking a category in the open window shows its page and hides the one shown before.
function SettingsPanel:SelectCategory(category)
    local old = self.__selected
    if old and old.frame and old ~= category then old.frame:Hide() end
    self.__selected = category
    if type(category) == "table" and category.frame then category.frame:Show() end
end
function H.settingsCategories() return categories end

-- Pools and mixins some libraries reach for.
function CreateFramePool(kind, parent, template, reset)
    local pool = { active = {}, inactive = {} }
    function pool:Acquire()
        local f = table.remove(self.inactive)
        local new = f == nil
        f = f or CreateFrame(kind or "Frame", nil, parent, template)
        self.active[f] = true
        return f, new
    end
    function pool:Release(f) self.active[f] = nil self.inactive[#self.inactive + 1] = f if reset then reset(self, f) end end
    function pool:ReleaseAll() for f in pairs(self.active) do self:Release(f) end end
    function pool:EnumerateActive() return pairs(self.active) end
    function pool:GetNumActive() local n = 0 for _ in pairs(self.active) do n = n + 1 end return n end
    return pool
end
CreateTexturePool = function(parent) return CreateFramePool("Frame", parent) end
CreateFontStringPool = CreateTexturePool
CreateObjectPool = function(create, reset)
    local pool = CreateFramePool()
    pool.Acquire = function(self) local o = create(self) self.active[o] = true return o, true end
    return pool
end
MapCanvasDataProviderMixin = {
    SetMap = function(self, map) self.owningMap = map end, GetMap = function(self) return self.owningMap end,
    OnAdded = function(self, map) self.owningMap = map end, OnRemoved = function() end,
    RefreshAllData = function() end, RemoveAllData = function() end, OnMapChanged = function() end,
}
MapCanvasPinMixin = { OnLoad = function() end, SetPosition = function() end, UseFrameLevelType = function() end }
BackdropTemplateMixin = { SetBackdrop = function() end, SetBackdropColor = function() end,
    SetBackdropBorderColor = function() end, ApplyBackdrop = function() end }
function WorldMapFrame:RemoveAllPinsByTemplate() end
function WorldMapFrame:AcquirePin(template) local p = CreateFrame("Frame", nil, self) return p end
function WorldMapFrame:RemovePin() end
function WorldMapFrame:IsMaximized() return false end
