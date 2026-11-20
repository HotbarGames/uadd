-- Stand-in for Scrap_Merchant (tools/harness/flow_scrap.py): the junk list window. Like Scrap's, two tabs
-- (an icon, then a word), a button to forget an item and one to add or remove it, whose width follows its
-- text, and a list of item names (an icon and a name per row). Its words come from Scrap's own locale table.
-- The items are made up; one is named like a tab (the flow hands over that English at test time).

local L = LibStub("AceLocale-3.0"):GetLocale("Scrap")
local S = ScrapStandIn
local V = Scrap:NewModule("Visualizer", CreateFrame("Frame", "ScrapVisualizer", UIParent))

local function Fit(b) b:SetWidth(b:GetTextWidth() + 20) end

V.Tab1, V.Tab2 = S.Button(V), S.Button(V)
V.Tab1:SetText("|TInterface\\Icons\\Quix_Up:16|t " .. L.NotJunk)
V.Tab2:SetText("|TInterface\\Icons\\Quix_Down:16|t " .. L.Junk)
V.ForgetButton, V.ToggleButton = S.Button(V), S.Button(V)
V.ForgetButton:SetText(L.Forget)
Fit(V.ForgetButton)

function V:UpdateButtons()
    self.ToggleButton:SetText(self.tab == 2 and L.Remove or L.Add)
    Fit(self.ToggleButton)
end

function V:SetTab(i)
    self.tab = i
    self:UpdateButtons()
end

V.items = {}
for i, name in ipairs({ "Quix Blade", rawget(_G, "ScrapStandInItem") or "QUIX" }) do
    local b = CreateFrame("Button", nil, V)
    b.Icon = b:CreateTexture(nil, "ARTWORK")
    b.Text = S.Text(b)
    b.name = name
    V.items[i] = b
end

-- Like Scrap's list: its rows (Scroll.buttons), named again from the item each time it updates.
V.Scroll = { buttons = V.items }
function V.Scroll.update()
    for _, b in ipairs(V.items) do b.Text:SetText(b.name) end
end
V.Scroll.update()

V:SetTab(1)
V:Hide()
