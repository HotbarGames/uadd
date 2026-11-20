-- Stand-in for Scrap_Config (tools/harness/flow_scrap.py): four settings pages, shaped like Scrap's Sushi
-- OptionsGroups. A page keeps its name (title) and the line under it (subtitle) in fields, and on each
-- rebuild (UpdateChildren, also on show) adds a header from them, then its rows through Add (a method of
-- its class, not of the page, as in Sushi). Its words come from Scrap's own locale table; the four its
-- settings code writes itself the flow hands over at test time (ScrapStandInCode). Patron names, ranks and
-- the copyright line are made up. Each row carries a tag for the flow: "R" ours, "G" the game's words or
-- an addon's name, "N" names.

local L = LibStub("AceLocale-3.0"):GetLocale("Scrap")
local S = ScrapStandIn
local CODE = rawget(_G, "ScrapStandInCode") or {}
local function Game(name) return rawget(_G, name) or ("QUIX " .. name) end
local function Icon(atlas)
    local f = rawget(_G, "CreateAtlasMarkup")
    return f and f(atlas) or ("|A:" .. atlas .. ":0:0|a")
end

local Group = {}

function Group:Add(kind, text, tip, tag)
    self.n = self.n + 1
    local key = self.n .. kind
    local row = self.pool[key]
    if not row then
        row = kind == "RedButton" and S.Button(self) or S.Text(self)
        self.pool[key] = row
    end
    row.kind, row.tip, row.tag = kind, tip, tag or "R"
    row:SetText(text)
    row:Show()
    self.rows[self.n] = row
    return row
end

function Group:UpdateChildren()
    for _, row in pairs(self.pool) do row:Hide() end
    self.n, self.rows = 0, {}
    self:Add("Header", self.title, nil, self.tagTitle)
    self:Add("Text", self.subtitle)
    self:children()
end

local Options = Scrap:NewModule("Options", {})
function Options.GetCategory(g) return g.category end

-- A page: a frame whose class (Group, then the frame's own methods) is in its metatable.
local function Page(id, title, subtitle, children, tagTitle)
    local f = CreateFrame("Frame", nil, UIParent)
    local base, mt = getmetatable(f), {}
    for k, v in pairs(base) do mt[k] = v end
    mt.__index = function(t, k)
        local v = Group[k]
        if v ~= nil then return v end
        local i = base.__index
        if type(i) == "function" then return i(t, k) end
        return i and i[k]
    end
    setmetatable(f, mt)
    f.title, f.subtitle, f.children, f.tagTitle = title, subtitle, children, tagTitle
    f.pool, f.rows, f.n = {}, {}, 0
    f.category = { name = title }
    function f.category:GetName() return self.name end
    function f.category:SetName(name) self.name = name end
    f:SetScript("OnShow", function(self) self:UpdateChildren() end)
    f:Hide()
    rawset(Options, id, f)
    return f
end

local function Checks(g, keys)
    for _, k in ipairs(keys) do g:Add("Check", L[k], L[k .. "Tip"]) end
end

Page("Main", "Scrap", L.GeneralDescription, function(g)
    g:Add("RedButton", Game("SETTINGS_KEYBINDINGS_LABEL"), nil, "G")
    g:Add("Header", L.Behaviour)
    Checks(g, { "AutoSell", "AutoRepair", "GuildRepair", "DestroyWorthless", "SafeMode" })
    g:Add("Header", L.Visuals)
    Checks(g, { "Glow", "Icons", "SellPrices" })
end, "G")

Page("Filters", L.JunkList .. " " .. Icon("poi-workorders"), L.ListDescription, function(g)
    g:Add("Check", L.CharSpecific)
    g:Add("Header", Game("CALENDAR_FILTERS"), nil, "G")
    Checks(g, { "Learning", "LowConsumable", "LowEquip", "Unusable" })
    g:Add("Slider", L.iLevelTreshold, L.EquipLevelTip)
    g:Add("Slider", L.iLevelTreshold, L.ConsumableLevelTip)
end)

Page("Help", Game("HELP_LABEL") .. " " .. Icon("CampaignAvailableQuestIcon"), L.HelpDescription, function(g)
    local faq = L.FAQ
    for i = 1, #faq, 2 do
        g:Add("ExpandHeader", faq[i])
        if faq[i + 1] then g:Add("Text", faq[i + 1]) end
    end
    g:Add("RedButton", CODE.tutorial)
    g:Add("RedButton", CODE.community)
end, "G")

-- A patron is named like the button under the list: a name, never ours.
Page("Credits", (CODE.page or "QUIX") .. " " .. Icon("Coin-Gold"), L.PatronsDescription, function(g)
    g:Add("Header", "Quix Rank", nil, "N")
    for _, name in ipairs({ "Zorp Quixley", "Vel Ambry", CODE.join or "QUIX" }) do g:Add("Text", name, nil, "N") end
    g:Add("Text", "Copyright 2012-2026 Quix", nil, "N")
    g:Add("RedButton", CODE.join)
end)
