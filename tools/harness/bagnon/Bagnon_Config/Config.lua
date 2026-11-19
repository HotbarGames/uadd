-- Not Bagnon_Config: a stand-in shaped like it, for tools/harness/flow_bagnon.py. Before this file runs,
-- the flow runs the installed BagBrother's config/localization/en.lua under the name "Bagnon_Config".
-- As in BagBrother's optionsPanel.lua, each page reads its title (the root page: icons and the addon's
-- name; the others: L[id] and icons) and its subtitle (L[id .. "Description"], formatted with the
-- addon's name) once, while it is made. Its rows read L each time the page shows; the Help page shows
-- the first two FAQ lines with ADDON replaced by the addon's name.
local CONFIG = ...
local L = LibStub("AceLocale-3.0"):GetLocale(CONFIG)
local NAME = "Bagnon"
local Addon = _G[NAME]
local S = BagnonStandIn
S.ICON = "|TInterface\\Icons\\INV_Misc_Bag_07:14|t"
S.ROWS = {
    GeneralOptions = { "Enabled", "EnabledTip", "Tooltips", "BagToggle" },
    FrameOptions = { "Appearance", "Columns", "Scale" },
    DisplayOptions = { "DisplayInventory", "CloseInventory" },
    SlotOptions = { "GlowQuality", "EmptySlots" },
    Help = { "faq1", "faq2", "AskCommunity" },
    Patrons = { "JoinUs" },
}
S.PAGES = { "GeneralOptions", "FrameOptions", "DisplayOptions", "SlotOptions", "Help", "Patrons" }

local function Text(parent, size)
    local fs = parent:CreateFontString(nil, "ARTWORK")
    fs:SetFont("Fonts\\FRIZQT__.TTF", size or 12, "")
    return fs
end

local function Row(key)
    local i = key:match("^faq(%d)$")
    if i then return (L.FAQ[tonumber(i)]:gsub("ADDON", NAME)) end
    return L[key]
end

for n, id in ipairs(S.PAGES) do
    local f = CreateFrame("Frame", nil, UIParent)
    f.title = n == 1 and (S.ICON .. " " .. NAME) or (L[id] .. "  " .. S.ICON)
    f.subtitle = L[id .. "Description"]:format(NAME)
    f.head, f.sub, f.rows = Text(f, 16), Text(f, 12), {}
    S.texts["page:" .. id .. ":head"], S.texts["page:" .. id .. ":sub"] = f.head, f.sub
    for _, key in ipairs(S.ROWS[id]) do
        f.rows[key] = Text(f)
        S.texts["page:" .. id .. ":" .. key] = f.rows[key]
    end
    f.UpdateChildren = function(self)
        self.head:SetText(self.title)
        self.sub:SetText(self.subtitle)
        for key, fs in pairs(self.rows) do fs:SetText(Row(key)) end
    end
    f:SetScript("OnShow", function(self) self:UpdateChildren() end)
    f:Hide()
    Addon[id] = f
end
