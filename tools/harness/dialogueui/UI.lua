-- A stand-in for DialogueUI's windows in the harness. Written for the checks, not taken from
-- DialogueUI: it only puts words on screen the way DialogueUI does (docs/scratch-dui-map.md).
--   * Global font objects DUIFont_* in DialogueUI's own font (no Cyrillic). SetFontSize changes
--     them all, as its FontUtil does when the font size setting changes.
--   * DUIQuestFrame: the quest name (game text, read back for text-to-speech), labels from L,
--     SetFormattedText lines, key pictures, and pooled option buttons released and set again on
--     every QUEST_* / GOSSIP_* event.
--   * DUIDialogSettings: tab buttons, option names through string.upper, a description made of
--     description.."\n\n"..choice, a dropdown value.
--   * An anonymous tooltip frame with AddLeftLine; the item-level line is read back and parsed.
--   * DUIBookFrame with a label, and PrintMessage to chat.
--   * Its nameless page in the game's options (S.MakeCanvas, Canvas.lua), given to Settings.
-- DialogueUIStandIn.recipes[name](L, upper) gives the text a widget shows, so the checks can
-- build the English and the Ukrainian the same way.
local _, addon = ...
local L = addon.L

local S = { texts = {}, recipes = {}, formatted = {}, all = {}, options = {}, readBack = {} }
DialogueUIStandIn = S
S.L, S.KeyMarkup = L, addon.KeyMarkup
S.FONT = "Interface\\AddOns\\DialogueUI\\Fonts\\frizqt__.ttf"
S.QUEST = "The Defias Brotherhood"
S.ICON = "|TInterface\\AddOns\\DialogueUI\\Art\\Icons\\Logo:0:0|t"
S.DELTA = "|cff808080(|r|cff19ff19+3|r|cff808080)|r"
S.SERVER = "I want to browse your goods."

local OBJECTS = { DUIFont_Quest_Title_16 = 16, DUIFont_Quest_Paragraph = 12, DUIFont_Quest_Quest = 12,
    DUIFont_QuestType_Left = 10, DUIFont_Hotkey = 10, DUIFont_AlertFont = 12, DUIFont_Tooltip_Large = 12,
    DUIFont_Tooltip_Medium = 10, DUIFont_Item = 10 }
for name, size in pairs(OBJECTS) do
    CreateFont(name):SetFont(S.FONT, size, name == "DUIFont_AlertFont" and "OUTLINE" or "")
end
S.OBJECTS = OBJECTS

-- FontUtil:SetFontSizeByID: SetFont on every DUIFont_* object, flags kept.
function S.SetFontSize(size)
    for name in pairs(OBJECTS) do
        local _, _, flags = _G[name]:GetFont()
        _G[name]:SetFont(S.FONT, size, flags)
    end
end

local function Join(fmt, ...)
    if select("#", ...) > 0 then return fmt:format(...) end
    return fmt
end
S.Join = Join

local function Text(parent, object, name, recipe, formatted)
    local fs = parent:CreateFontString(nil, "OVERLAY", object)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    S.all[#S.all + 1] = { fs = fs, object = _G[object] }
    if name then S.texts[name], S.recipes[name], S.formatted[name] = fs, recipe, formatted end
    return fs
end

local function Put(name)
    local fs = S.texts[name]
    if S.formatted[name] then fs:SetFormattedText(S.recipes[name](L, string.upper))
    else fs:SetText(Join(S.recipes[name](L, string.upper))) end
end

-- ── The quest window ─────────────────────────────────────────────────────────────────────────
local quest = CreateFrame("Frame", "DUIQuestFrame", UIParent)
quest:SetPoint("CENTER")
quest:Hide()
quest.Header = CreateFrame("Frame", nil, quest)
quest.Header.Title = Text(quest.Header, "DUIFont_Quest_Title_16")
S.texts.title, S.readBack.title = quest.Header.Title, true
S.recipes.title = function() return S.QUEST end
local QUEST_TEXTS = {
    { "questType", "DUIFont_QuestType_Left", function(l) return l["Quest Type Repeatable"] end },
    { "difficulty", "DUIFont_QuestType_Left", function(l) return l["Quest Difficulty Hard"] end },
    { "yourLevel", "DUIFont_Quest_Paragraph", function(l) return l["Your Level"] end },
    { "questLevel", "DUIFont_Quest_Paragraph", function(l) return l["Quest Level"] end },
    { "suggested", "DUIFont_Quest_Paragraph", function(l) return l["Format Suggested Players"], 3 end, true },
    { "progress", "DUIFont_Quest_Paragraph", function(l) return l["Format Your Progress"], 2, 5 end, true },
    { "xp", "DUIFont_Quest_Paragraph", function(l) return l["Format Player XP"], 150, 400, 37 end },
    { "tabHint", "DUIFont_Hotkey", function(l) return l["Press Tab To Select Reward Desc"] end },
    { "spaceAlert", "DUIFont_AlertFont", function(l) return l["Use Default Control Key Alert"] end },
    { "interact", "DUIFont_AlertFont", function(l) return l["Interact Key Not Set"] end },
}
for _, t in ipairs(QUEST_TEXTS) do Text(quest, t[2], t[1], t[3], t[5]) end

-- A FontString made before it is first used and hidden until then (a pool's spare, a tooltip line).
quest.Spare = Text(quest, "DUIFont_Quest_Paragraph")
quest.Spare:Hide()
function S.UseSpare()
    S.texts.spare, S.recipes.spare = quest.Spare, function(l) return l["Quest Level"] end
    quest.Spare:Show()
    Put("spare")
end
-- Something sets a text to what it shows now (fs:SetText(fs:GetText())).
function S.SetAgain(name) local fs = S.texts[name] fs:SetText(fs:GetText()) end

-- The quest text: DialogueUI's fontStringPool on quest.ContentFrame. Paragraphs are the game's
-- prose (read back for text-to-speech); sub-headers and InsertParagraph lines are L values.
quest.ContentFrame = CreateFrame("Frame", nil, quest)
quest.ContentFrame:SetPoint("TOPLEFT", quest, "TOPLEFT", 0, 0)
local bodyFree, bodyUsed = {}, {}
local BODY = {
    { "body1", function() return "Kill the shaman before dawn so the ritual is completed." end },
    { "body2", function() return "Title: the Wardens of the Grove have long held this land. Speak to them first." end },
    { "bodyHeader", function(l) return l["Rewards"] end },
    { "bodySuggested", function(l) return l["Format Suggested Players"], 3 end },
}
S.readBack.body1, S.readBack.body2 = true, true
local function SetBody()
    for _, fs in ipairs(bodyUsed) do fs:SetText(nil) fs:Hide() fs:ClearAllPoints() bodyFree[#bodyFree + 1] = fs end
    bodyUsed = {}
    for _, b in ipairs(BODY) do
        local fs = table.remove(bodyFree) or Text(quest.ContentFrame, "DUIFont_Quest_Paragraph")
        fs:SetPoint("TOPLEFT", quest.ContentFrame, "TOPLEFT", 0, 0)
        fs:Show()
        bodyUsed[#bodyUsed + 1] = fs
        S.texts[b[1]], S.recipes[b[1]] = fs, b[2]
        fs:SetText(Join(b[2](L)))
    end
end

-- Option buttons come from a pool: released on every event, acquired again in another order.
local free, made = {}, 0
local function Acquire()
    local b = table.remove(free)
    if not b then
        made = made + 1
        b = CreateFrame("Button", nil, quest)
        b.Name = Text(b, "DUIFont_Quest_Quest")
        b.Hotkey = Text(b, "DUIFont_Hotkey")
        b:SetFontString(b.Name)
    end
    b:SetPoint("TOPLEFT", quest, "TOPLEFT", 0, 0)
    b:Show()
    return b
end
local function ReleaseAll()
    for i, b in ipairs(S.options) do
        b:Hide()
        b:ClearAllPoints()
        free[#free + 1] = b
        S.texts["option" .. i], S.recipes["option" .. i], S.formatted["option" .. i] = nil, nil, nil
    end
    S.options = {}
end
local function Server() return S.SERVER end
local VARIANTS = {
    detail = { Server, function(l) return l["Format Quest Accepted"], "Wanted: Hogger" end,
        function(l) return l["Format Time Left"], l == L and "5 |4Min:Min;" or "5 хв" end },   -- SecondsToTime
    gossip = { function(l) return l["Format And More"], 2 end, Server,
        function(l) return l["Widget Is Docked Named"], l["Quest Item Display"] end,
        function(l) return l["Format Quest Accepted"], "Wanted: Hogger" end },
}
local function SetOptions(list)
    ReleaseAll()
    for i, recipe in ipairs(list) do
        local b = Acquire()
        S.options[i] = b
        S.texts["option" .. i], S.recipes["option" .. i] = b.Name, recipe
        Put("option" .. i)                 -- DUIDialogOptionButtonMixin:SetButtonText
        b.Hotkey:SetText(tostring(i))
    end
end
function S.Made() return made end

local GOSSIP = { GOSSIP_SHOW = true }
local events = CreateFrame("Frame")
for _, e in ipairs({ "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "GOSSIP_SHOW", "QUEST_FINISHED",
    "GOSSIP_CLOSED" }) do events:RegisterEvent(e) end
events:SetScript("OnEvent", function(_, event)
    if event == "QUEST_FINISHED" or event == "GOSSIP_CLOSED" then quest:Hide() return end
    quest.Header.Title:SetText(S.QUEST)
    for _, t in ipairs(QUEST_TEXTS) do Put(t[1]) end
    SetBody()
    SetOptions(GOSSIP[event] and VARIANTS.gossip or VARIANTS.detail)
    quest:Show()
end)
-- Text-to-speech reads the quest name back from the header.
function S.TTSTitle() return quest.Header.Title:GetText() end

-- ── Settings ─────────────────────────────────────────────────────────────────────────────────
local settings = CreateFrame("Frame", "DUIDialogSettings", UIParent)
settings:SetPoint("CENTER")
settings:Hide()
for i, key in ipairs({ "UI", "Gameplay", "Accessibility" }) do
    local tab = CreateFrame("Button", nil, settings)
    tab:SetPoint("TOPLEFT", settings, "TOPLEFT", 0, 0)
    tab.Name = Text(tab, "DUIFont_Quest_Paragraph", "tab" .. i, function(l) return l[key] end)
end
local ROWS = { { "Font Size", "Font Size Desc" }, { "BookUI Darken Screen", "BookUI Darken Screen Desc", "Option Enabled" },
    { "BookUI Keep UI Open", "BookUI Keep UI Open Desc" } }
for i, row in ipairs(ROWS) do
    local f = CreateFrame("Frame", nil, settings)
    f:SetPoint("TOPLEFT", settings, "TOPLEFT", 0, 0)
    f.Label = Text(f, "DUIFont_Quest_Paragraph", "row" .. i, function(l, upper) return upper(l[row[1]]) end)
end
-- DUIDialogSettingsOptionMixin:SetData: the description, with the chosen value's tooltip after it.
Text(settings, "DUIFont_Quest_Paragraph", "description", function(l)
    return l[ROWS[2][2]] .. "\n\n" .. l[ROWS[2][3]]
end)
Text(settings, "DUIFont_Quest_Paragraph", "description1", function(l) return l[ROWS[1][2]] end)
Text(settings, "DUIFont_Quest_Paragraph", "description3", function(l) return l[ROWS[3][2]] end)
Text(settings, "DUIFont_Quest_Paragraph", "dropdown", function(l) return l["Default Font"] end)
local SETTINGS_TEXTS = { "tab1", "tab2", "tab3", "row1", "row2", "row3", "description", "description1",
    "description3", "dropdown" }
function DialogueUI_ShowSettingsFrame()
    for _, name in ipairs(SETTINGS_TEXTS) do Put(name) end
    settings:Show()
end
function S.HideSettings() settings:Hide() end

-- ── The tooltip: an anonymous frame, its lines are FontStrings set by AddLeftLine ─────────────
local tip = CreateFrame("Frame", nil, UIParent)
tip:SetPoint("CENTER")
tip:Hide()
tip.Content = CreateFrame("Frame", nil, tip)
tip.lines, tip.numLines = {}, 0
function tip:ClearLines()
    for _, fs in ipairs(self.lines) do fs:Hide() end
    self.numLines = 0
end
function tip:AddLeftLine(text)
    self.numLines = self.numLines + 1
    local fs = self.lines[self.numLines]
    if not fs then
        fs = Text(self.Content, self.numLines == 1 and "DUIFont_Tooltip_Large" or "DUIFont_Tooltip_Medium")
        self.lines[self.numLines] = fs
    end
    fs:SetText(text)
    fs:Show()
end
function tip:AddDoubleLine(left) self:AddLeftLine(left) end
function tip:ShowFrame() self:Show() end
function tip:HideFrame() self:Hide() end
function tip:GetLeftLineText(i) return self.lines[i] and self.lines[i]:GetText() end
function tip:OverwriteLeftLineText(i, text) self.lines[i]:SetText(text) end
-- SharedTooltip:AddDeltaToItemLevel: finds L["Item Level"] in line 2 and adds the difference.
function tip:AddDeltaToItemLevel()
    local lineText = self:GetLeftLineText(2)
    S.itemLevelParsed = lineText ~= nil and string.find(lineText, L["Item Level"]) ~= nil
    if S.itemLevelParsed then self:OverwriteLeftLineText(2, lineText .. "  " .. S.DELTA) end
end
S.tip = tip
local TIP = {
    { "tipName", function() return "Thunderfury, Blessed Blade of the Windseeker" end },
    { "itemLevel", function(l) return l["Format Item Level"], 45 end },
    { "tipRep", function(l) return l["Format Reputation Reward Tooltip"], 250, "Stormwind" end },
    { "tipHave", function(l) return l["Format You Have X"], "3" end },
    { "tipGold", function(l) return l["Format Gold Amount"], 12 end },
}
S.readBack.tipName, S.readBack.itemLevel = true, true
function S.ShowItemTooltip()
    tip:ClearLines()
    for _, t in ipairs(TIP) do tip:AddLeftLine(Join(t[2](L))) end
    tip:Show()
    tip:AddDeltaToItemLevel()
    for i, t in ipairs(TIP) do S.texts[t[1]], S.recipes[t[1]] = tip.lines[i], t[2] end
    local il = S.recipes.itemLevel
    S.recipes.itemLevel = function(l) return Join(il(L)) .. "  " .. S.DELTA end   -- always English
end
function S.HideTooltip() tip:Hide() end

-- ── Book UI and chat ─────────────────────────────────────────────────────────────────────────
local book = CreateFrame("Frame", "DUIBookFrame", UIParent)
book:SetPoint("CENTER")
book:Hide()
Text(book, "DUIFont_Quest_Paragraph", "bookLabel", function(l) return l["BookUI TTS Click To Read"] end)
function S.ShowBook() Put("bookLabel") book:Show() end
function S.HideBook() book:Hide() end

-- API.PrintMessage
local function PrintMessage(header, msg)
    print(S.ICON .. "|cffffd100" .. header .. "  |cffffffff" .. (msg or "") .. "|r")
end
S.chatRecipes = {
    function(l) return S.ICON .. "|cffffd100" .. l["Auto Select"] .. "  |cffffffffWanted: Hogger|r" end,
    function(l) return S.ICON .. "|cffffd100" .. l["Quest Unblocked Alert"] .. "  |cffffffff|r" end,
}
function S.Chat()
    PrintMessage(L["Auto Select"], "Wanted: Hogger")
    PrintMessage(L["Quest Unblocked Alert"])
end
