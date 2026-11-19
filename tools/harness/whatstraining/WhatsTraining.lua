-- Not What's Training?: a small stand-in for tools/harness/flow_whatstraining.py. None of its code or
-- words: only the shape UADD_WhatsTraining relies on.
--   * Named windows: WhatsTrainingOverlay > WhatsTrainingFrame made at load (font strings, and an
--     unnamed button whose label is set through the button), WhatsTrainingSettings made later (S.Later),
--     WhatsTrainingFloatingFrame made from a template on first open (S.Open).
--   * A frame of another addon showing the same texts, and its Broker text: never ours.
--   * Its own tooltip (WhatsTrainingTrainerTooltip, lines written as the client writes them), game
--     tooltip lines and chat lines (print, no name in front) from this file's own code.
-- Every English text comes from the flow (WhatsTrainingStandInFeed, set before the game starts), read
-- from the installed What's Training? at test time.

local S = { texts = {}, other = {} }
WhatsTrainingStandIn = S
local PATH = "Fonts\\FRIZQT__.TTF"
S.PATH = PATH

local function Text(parent, size)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(PATH, size or 12, "")
    return fs
end

-- One fed text: on a font string of the window, or as an unnamed button's label.
local function Put(parent, row)
    local fs
    if row.how == "button" then
        local b = CreateFrame("Button", nil, parent)
        fs = Text(b, row.size)
        b:SetFontString(fs)
        S.button = b
        b:SetText(row.text)
    else
        fs = Text(parent, row.size)
        fs:SetText(row.text)
    end
    S.texts[row.name] = fs
    return fs
end

local feed = rawget(_G, "WhatsTrainingStandInFeed") or {}
local overlay = CreateFrame("Frame", "WhatsTrainingOverlay", UIParent)
local main = CreateFrame("Frame", "WhatsTrainingFrame", overlay)
main:SetSize(600, 400)
for _, row in ipairs(feed.load or {}) do Put(main, row) end

-- Another addon's frame with the same texts (a Broker bar showing our Broker text too).
local bar = CreateFrame("Frame", "BrokerBarStandIn", UIParent)
for _, row in ipairs(feed.load or {}) do
    local fs = Text(bar, 12)
    fs:SetText(row.text)
    S.other[row.name] = fs
end
S.broker = { type = "data source", text = feed.broker or "" }
S.other.broker = Text(bar, 12)
S.other.broker:SetText(S.broker.text)

-- A window made after login: its font strings get their text right after they are made.
function S.Later()
    local f = CreateFrame("Frame", "WhatsTrainingSettings", UIParent)
    for _, row in ipairs(feed.later or {}) do Put(f, row) end
    return f
end

-- Its main window on Forever (WhatsTrainingFloatingFrame), made on first open: from a template, so its
-- title is the template's region (not made by CreateFontString); a page in it makes one font string in
-- Lua; then it is shown at once.
function S.Open()
    local f = S.floating
    if not f then
        f = CreateFrame("Frame", "WhatsTrainingFloatingFrame", UIParent, "UIPanelDialogTemplate")
        f:Hide()
        S.floating = f
        f.Title:SetText(feed.title)
        local page = CreateFrame("Frame", "$parentSpells", f)
        page.count = page:CreateFontString(nil, "OVERLAY")
    end
    if not f:IsShown() then f:Show() end
    return f
end

function S.Set(name, text) S.texts[name]:SetText(text) end
function S.Label(text) S.button:SetText(text) end

-- Its own tooltip, lines written as the client writes them.
local tipName = "WhatsTrainingTrainerTooltip"
local tip = CreateFrame("GameTooltip", tipName, UIParent)
for i = 1, 8 do
    for _, side in ipairs({ "Left", "Right" }) do
        local fs = rawget(_G, tipName .. "Text" .. side .. i) or tip:CreateFontString(tipName .. "Text" .. side .. i)
        fs:SetFont(PATH, 12, "")
    end
end
local function Clear(self)
    for i = 1, 8 do _G[tipName .. "TextLeft" .. i]:SetText(nil) _G[tipName .. "TextRight" .. i]:SetText(nil) end
    self.__lines = 0
    local f = self:GetScript("OnTooltipCleared")
    if f then f(self) end
end
local function Add(self, l, r)
    self.__lines = (self.__lines or 0) + 1
    _G[tipName .. "TextLeft" .. self.__lines]:SetText(l)
    _G[tipName .. "TextRight" .. self.__lines]:SetText(r)
end
tip.ClearLines = Clear
tip.SetOwner = function(self, owner) self.__owner = owner Clear(self) end
tip.AddLine = function(self, t) Add(self, t) end
tip.AddDoubleLine = function(self, l, r) Add(self, l, r) end
S.tip = tip

function S.OwnTip(left, right)
    tip:SetOwner(UIParent, "ANCHOR_NONE")
    if right then tip:AddDoubleLine(left, right) else tip:AddLine(left, 1, 1, 1, false) end
    tip:Show()
end

-- Its minimap / Broker tooltip: lines on the game tooltip.
function S.Tip(left, right)
    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    if right then GameTooltip:AddDoubleLine(left, right) else GameTooltip:AddLine(left) end
    GameTooltip:Show()
end

function S.Print(text) print(text) end
