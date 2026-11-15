-- Not Attune: a harness stand-in for tools/harness/flow_att.py, with the globals, functions, frame
-- names, texts and table shapes UADD_Attune hooks, copied in spirit from Attune 16001's Attune.lua
-- (the real libraries are run from the installed Attune's embeds.xml by the check). The main window:
-- an AceGUI Frame with the tree and the step graph, node tooltips, the quest-giver tip, the settings
-- (AceConfig, in the game's Settings), the minimap button (LDB + LibDBIcon), the [Attune] chat lines.
local L = LibStub("AceLocale-3.0"):GetLocale("Attune")
AttuneLang = L
local AceGUI = LibStub("AceGUI-3.0")
local ACR = LibStub("AceConfigRegistry-3.0")
local Attune = LibStub("AceAddon-3.0"):NewAddon("Attune", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0")
local SI = { selects = 0, picked = {}, sent = {} }     -- for the checks
AttuneStandIn = SI
local VERSION = "16001-40"
local frame, tree, graph, statusText, charKey, giverTip

function SI.Print(text) print("|cffff00ff[Attune]|r " .. text) end
local Print = SI.Print

function SI.Toon() return Attune_DB.toons[charKey] end

local function LogText()
    local keys, out = {}, {}
    for t in pairs(Attune_DB.logs) do keys[#keys + 1] = t end
    table.sort(keys)
    for _, t in ipairs(keys) do out[#out + 1] = date("%d %b %Y - %H:%M", t) .. " - " .. Attune_DB.logs[t] .. "\n" end
    if #out == 0 then return "None yet..." end
    return table.concat(out)
end

local options = { type = "group", name = "Attune", childGroups = "tab", args = {
    tab1 = { type = "group", name = L["GeneralSettings"], order = 1, args = {
        minimap = { type = "toggle", name = L["MinimapButton_TEXT"], desc = L["MinimapButton_DESC"], width = "full",
            order = 1, get = function() return not Attune_DB.minimap.hide end,
            set = function(_, v) Attune_DB.minimap.hide = not v end },
        other = { type = "toggle", name = L["ShowOther_TEXT"], desc = L["ShowOther_DESC"], width = "full", order = 2,
            get = function() return Attune_DB.showOtherChat end, set = function(_, v) Attune_DB.showOtherChat = v end },
        url = { type = "input", name = "Database Website URL", desc = "URL of a World of Warcraft database website",
            width = "full", order = 3, get = function() return Attune_DB.websiteUrl end,
            set = function(_, v) Attune_DB.websiteUrl = v end },
    } },
    tab2 = { type = "group", name = L["Survey Log"], order = 2, args = {
        logs = { type = "description", name = "", fontSize = "medium", order = 1 },
    } },
} }

function Attune_UpdateLogs()
    options.args.tab2.args.logs.name = LogText()
    ACR:NotifyChange("Attune")
end

function Attune:OnInitialize()
    charKey = UnitName("player") .. "-" .. GetRealmName()
    Attune_DB = Attune_DB or {}
    local d = Attune_DB
    d.toons = d.toons or {}
    d.toons[charKey] = d.toons[charKey] or { done = {}, attuned = { ["20"] = 0, ["30"] = 0, ["160"] = 0 },
        status = "None", role = "None", class = "WARRIOR", race = "Orc", level = 60, guild = "" }
    d.logs = d.logs or { [1762000000] = (L["ReceivedRequestFrom"]:gsub("##FROM##", "Someone-Harness")) }
    d.minimap = d.minimap or { hide = false }
    d.willnotdo = d.willnotdo or { ["160"] = true }
    d.websiteUrl = d.websiteUrl or "https://www.wowhead.com/classic"
    if d.showOtherChat == nil then d.showOtherChat = true end
    if d.showStepReached == nil then d.showStepReached = true end
    if d.announceGuild == nil then d.announceGuild = true end
    TreeExpandStatus = TreeExpandStatus or { groups = {}, treewidth = 265 }
    AttuneLastViewed = AttuneLastViewed or ""
    Attune_UpdateLogs()
    LibStub("AceConfig-3.0"):RegisterOptionsTable("Attune", options)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Attune", "Attune")
    self:RegisterChatCommand("attune", "Slash")
    self:RegisterComm("Attune_Channel")
    local ldb = LibStub("LibDataBroker-1.1"):NewDataObject("Attune_Broker", { type = "data source",
        label = "Attune", text = "Click me!", icon = "Interface\\AddOns\\Attune\\Images\\icon",
        OnClick = function(_, button) if button == "RightButton" then Attune_ShowSettings() else Attune_Frame() end end,
        OnTooltipShow = function(t)
            t:AddLine("|cFFffffffAttune v" .. VERSION .. "|r")
            t:AddLine(" ")
            t:AddLine(" ")
            t:AddLine("|cffffd100" .. L["LeftClick"] .. "|r" .. L["OpenAttune"] .. "\n|cffffd100" .. L["RightClick"]
                .. "|r" .. L["OpenSettings"])
        end })
    LibStub("LibDBIcon-1.0"):Register("Attune_Broker", ldb, d.minimap)
end

function Attune:OnEnable()
    if Attune_DB.showOtherChat then Print((L["Splash"]:gsub("##VERSION##", VERSION))) end
    self:RegisterEvent("BAG_UPDATE", function() Attune_NextFrameRefresh() end)
end

function Attune_ShowSettings() SI.settings = (SI.settings or 0) + 1 end

function Attune:OnCommReceived(prefix, msg, dist, sender) SI.got = { prefix, msg, dist, sender } end

-- The slash words stay English: they are values, not display texts.
function Attune:Slash(input)
    local cmd = (input or ""):lower():match("^(%S*)")
    SI.slash = cmd
    if cmd == "help" then Print(L["Help1"])
    elseif cmd == "survey" then Attune_ShowResultList()
    elseif cmd == "export" then Attune_ExportToWeb()
    else Attune_Frame() end
end

local function OnGroup(_, _, path)
    AttuneLastViewed = path
    local leaf = path:match("([^\001]+)$")
    SI.picked[#SI.picked + 1] = leaf
    if leaf == L["Archived"] then SI.archived = true return end
    if leaf == "Will not do" or leaf == L["WillNotDo"] then SI.willnotdo = true return end
    for _, a in ipairs(Attune_Data.attunes) do
        if a.ID == leaf then return Attune_Select(a.ID) end
        if a.GROUP == leaf then SI.group = leaf return end
        if a.EXPAC == leaf then SI.expac = leaf return end
    end
end

function Attune_Frame()
    if frame then frame:Show() return Attune_LoadTree() end
    frame = Attune_AceCreate("Frame")
    frame:SetTitle("  Attune")
    statusText = (L["Version"]:gsub("##VERSION##", VERSION))
    frame:SetStatusText(statusText)
    frame:SetLayout("Flow")
    frame:SetWidth(900); frame:SetHeight(600)
    _G["Attune_MainFrame"] = frame.frame
    SI.frame = frame
    local survey = Attune_AceCreate("Button")
    survey:SetText(L["Survey"])
    survey:SetWidth(100)
    survey:SetCallback("OnEnter", function() frame:SetStatusText(L["Survey_DESC"]) end)
    survey:SetCallback("OnLeave", function() frame:SetStatusText(statusText) end)
    survey:SetCallback("OnClick", function() Attune_ShowSurveyMenu() end)
    frame:AddChild(survey)
    SI.survey = survey
    tree = Attune_AceCreate("TreeGroup")
    tree:SetFullWidth(true); tree:SetFullHeight(true)
    tree:SetStatusTable(TreeExpandStatus)
    tree:SetCallback("OnGroupSelected", OnGroup)
    frame:AddChild(tree)
    SI.tree = tree
    graph = CreateFrame("Frame", "Attune_GraphRoot", tree.content)
    graph:SetSize(600, 500); graph:SetPoint("TOPLEFT")
    Attune_LoadTree()
end

function Attune_DisplayName(a)
    if a.LEVELS and a.LEVELS ~= "" then return a.NAME .. " (" .. a.LEVELS .. ")" end
    return a.NAME
end

function Attune_LoadTree()
    local expac = { value = L["World of Warcraft"], text = L["World of Warcraft"], children = {} }
    local groups, skipped = {}, {}
    for _, a in ipairs(Attune_Data.attunes) do
        if a.FACTION == "Both" or a.FACTION == "Horde" then
            local node = { value = a.ID, text = Attune_DisplayName(a), icon = a.ICON }
            if Attune_DB.willnotdo[a.ID] then
                skipped[#skipped + 1] = node
            else
                if not groups[a.GROUP] then
                    groups[a.GROUP] = { value = a.GROUP, text = "|cffA0A0A0" .. a.GROUP .. "|r", children = {} }
                    expac.children[#expac.children + 1] = groups[a.GROUP]
                end
                table.insert(groups[a.GROUP].children, node)
            end
        end
    end
    expac.children[#expac.children + 1] = { value = L["Archived"], text = "|cff00ff00" .. L["Archived"] .. "|r",
        children = { { value = "x1", text = "|cff00ff00" .. Attune_DisplayName(Attune_Data.attunes[1]) .. "|r" } } }
    expac.children[#expac.children + 1] = { value = L["WillNotDo"], text = "|cff808080" .. L["WillNotDo"] .. "|r",
        children = skipped }
    SI.treeData = { expac }
    tree:SetTree(SI.treeData)
end

function Attune_ReloadAttuneTree() Attune_LoadTree() end

local function StepLabel(s)
    if s.TYPE == "Item" then
        local need = tonumber(s.COUNT) or 1
        if need == 1 then return L["I_" .. s.ID_WOWHEAD] end
        return GetItemCount(tonumber(s.ID_WOWHEAD)) .. "/" .. need .. " " .. L["I_" .. s.ID_WOWHEAD]
    elseif s.TYPE == "Kill" or s.TYPE == "Interact" then return L["N1_" .. s.ID_WOWHEAD]
    elseif s.TYPE == "Quest" or s.TYPE == "Pick Up" or s.TYPE == "Turn In" then return L["Q1_" .. s.ID_WOWHEAD] end
    return s.STEP
end
Attune_NextStepLabel = StepLabel

function Attune_HideQuestGiverTip() if giverTip then giverTip:Hide() end end

local function GiverTip(anchor, s)
    local loc = Attune_Data.questGivers[tonumber(s.ID_WOWHEAD)]
    local name = loc and loc[4] or L["Q1_" .. s.ID_WOWHEAD]
    if not giverTip then
        giverTip = CreateFrame("GameTooltip", "AttuneGiverTip", UIParent, "GameTooltipTemplate")
        giverTip:SetFrameStrata("TOOLTIP")
    end
    giverTip:SetOwner(anchor, "ANCHOR_NONE")
    giverTip:ClearLines()
    giverTip:SetText("|cffffffff" .. L["Starts at"] .. " |r" .. name)
    giverTip:AddLine(L["Click to show map"], 0.6, 0.6, 0.6, true)
    giverTip:Show()
    GameTooltip:Show()
end

local function NodeEnter(node, s)
    local id = s.ID_WOWHEAD
    if s.TYPE == "Item" then
        frame:SetStatusText(StepLabel(s))
        GameTooltip:SetOwner(node, "ANCHOR_NONE")
        GameTooltip:SetHyperlink("item:" .. id)
    elseif s.TYPE == "Quest" or s.TYPE == "Pick Up" or s.TYPE == "Turn In" then
        frame:SetStatusText(L["Q1_" .. id])
        GameTooltip:SetOwner(node, "ANCHOR_NONE")
        local q = Attune_Data.quests[tonumber(id)]
        if q == nil then
            GameTooltip:SetText(L["Quest information not found"] .. " (ID " .. id .. ")", 1, 0.5, 0.5, 1)
        else
            GameTooltip:SetText(L["Q1_" .. id])
            GameTooltip:AddLine(L["Requires level"] .. " " .. q[1] .. "\n\n", 0.5, 0.5, 0.5, 1)
            if q[2] == 1 then GameTooltip:AddLine(L["Solo quest"] .. "\n\n", 0.373, 0.729, 0.275, 1)
            else GameTooltip:AddLine(L["Party quest"]:gsub("##NB##", q[2]) .. "\n\n", 0.851, 0.608, 0, 1) end
            GameTooltip:AddLine(L["Q2_" .. id], 1, 1, 1, 1, true)
        end
        GameTooltip:Show()
        if s.TYPE == "Pick Up" then GiverTip(node, s) end
    elseif s.TYPE == "Kill" or s.TYPE == "Interact" then
        frame:SetStatusText(L["N1_" .. id])
        GameTooltip:SetOwner(node, "ANCHOR_NONE")
        local npc = Attune_Data.npcs[tonumber(id)]
        GameTooltip:SetText(L["N1_" .. id])
        GameTooltip:AddLine(L["Level"] .. " " .. npc[1] .. " " .. npc[2] .. " " .. npc[3] .. "\n", 0.851, 0.608, 0, 1)
        GameTooltip:AddLine("\n" .. L["N2_" .. id], 1, 1, 1, 1, true)
        GameTooltip:Show()
    elseif s.TYPE == "Level" then
        frame:SetStatusText(UnitLevel("player") .. "/" .. s.ID_WOWHEAD .. " " .. (s.STEP or ""))
    end
end

function Attune_Select(id)
    SI.selects = SI.selects + 1
    if SI.Header then SI.Header(id) end
    for _, n in ipairs(SI.nodes or {}) do n:Hide() end
    SI.nodes, SI.shown = {}, id
    local i = 0
    for _, s in ipairs(Attune_Data.steps) do
        if s.ID_ATTUNE == id then
            i = i + 1
            local name = "Attune_Node_" .. s.ID
            local node = _G[name] or CreateFrame("Button", name, graph, "BackdropTemplate")
            node:SetSize(170, 48)
            node:SetPoint("TOPLEFT", 20, -20 - i * 60)
            local t = _G["Attune_Title_" .. s.ID] or node:CreateFontString("Attune_Title_" .. s.ID, "OVERLAY", "GameFontNormal")
            t:SetWidth(120); t:SetHeight(16)
            t:SetJustifyH("LEFT")
            if s.TYPE == "End" then
                t:SetFont(GameFontNormal:GetFont(), 12, "")
                t:SetText(SI.Toon().done[id .. "-" .. s.ID] and L["Attuned"] or L["Not attuned"])
            else
                t:SetFont(GameFontNormal:GetFont(), 11, "")
                t:SetText(StepLabel(s))
                local kind = "|cffffd100" .. L[s.TYPE] .. "|r"
                if s.TYPE == "Level" then kind = "|cffffd100" .. L["Required level"] .. "|r"
                elseif s.LOCATION ~= "" then kind = kind .. "|c60808080 " .. L["in"] .. " " .. L[s.LOCATION] .. "|r" end
                local ft = _G["Attune_Type_" .. s.ID] or node:CreateFontString("Attune_Type_" .. s.ID)
                ft:SetWidth(120); ft:SetHeight(16)
                ft:SetFont(GameFontNormal:GetFont(), 9, "")
                ft:SetText(kind)
                ft:Show()
            end
            t:Show()
            node:SetScript("OnEnter", function(self) NodeEnter(self, s) end)
            node:SetScript("OnLeave", function() GameTooltip:Hide() Attune_HideQuestGiverTip() frame:SetStatusText(statusText) end)
            node:Show()
            SI.nodes[#SI.nodes + 1] = node
        end
    end
end

-- A step done: the chat lines (ours to show), the guild announce and the addon message (English).
function Attune_MarkStepDone(aid, sid)
    local toon = SI.Toon()
    toon.done[aid .. "-" .. sid] = true
    local a, s
    for _, x in ipairs(Attune_Data.attunes) do if x.ID == aid then a = x end end
    for _, x in ipairs(Attune_Data.steps) do if x.ID_ATTUNE == aid and x.ID == sid then s = x end end
    if s.TYPE == "End" then
        toon.attuned[aid] = 100
        Print((L["AttuneComplete"]:gsub("##NAME##", a.NAME)))
        if Attune_DB.announceGuild then
            SendChatMessage("[Attune] " .. L["AttuneCompleteGuild"]:gsub("##NAME##", a.NAME), "GUILD")
        end
    else
        Print((L["CompletedStep"]:gsub("##TYPE##", L[s.TYPE]):gsub("##STEP##", StepLabel(s)):gsub("##NAME##", a.NAME)))
    end
    Attune:SendCommMessage("Attune_Channel", charKey .. "|DONE|" .. aid .. "-" .. sid, "GUILD")
    Attune_NextFrameRefresh()
end
