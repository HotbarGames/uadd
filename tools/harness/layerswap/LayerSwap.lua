-- Not LayerSwap: a small stand-in for tools/harness/flow_lsw.py, shaped like it where UADD touches it:
-- its named panel with a heading, a layer line and a button whose label it sets every second (font
-- object first, then the text, then a smaller font object when the label is too wide), two menus made
-- only when first opened (the layer menu with an age column, the settings menu with a tooltip on its
-- row) and its chat lines through print with its name in front. Its texts are a few of its real
-- labels, kept in one table (EN) so the checks read them from here (UADD_LayerSwap/data/words.lua
-- has their hashes).
local S = {}
LayerSwapStandIn = S

local PREFIX = "|cff7fd4ffLayerSwap|r: "
local EN = {
    heading = "YOUR LAYER", swap = "Swap layer", leave = "Leave group", layer = "Layer ",
    ago = " min ago", now = "just now", options = "Options...", shift = "Shift + click to switch",
    nobody = "nobody to remove.",
}
S.PREFIX, S.EN = PREFIX, EN
S.texts = {}     -- name -> FontString (or a button's)

-- Its say(): print with its name in front (print goes to DEFAULT_CHAT_FRAME:AddMessage).
function S.say(msg) print(PREFIX .. msg) end

-- Its setButtonText.
local function setFonts(button, o)
    button:SetNormalFontObject(o)
    button:SetHighlightFontObject(o)
    button:SetDisabledFontObject(o)
end
local function setButtonText(button, text)
    setFonts(button, "GameFontNormal")
    button:SetText(text)
    local fs = button:GetFontString()
    if (fs:GetStringWidth() or 0) > button:GetWidth() - 14 then setFonts(button, "GameFontNormalSmall") end
end

-- ── The panel (hidden at first, refreshed every second while shown) ─────────────────────────
local p = CreateFrame("Frame", "LayerSwapPanel", UIParent)
p:SetSize(260, 200)
p:SetPoint("CENTER")
p.h1 = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
p.h1:SetText(EN.heading)
p.layer = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
p.swapButton = CreateFrame("Button", "LayerSwapPanelSwapButton", p, "UIPanelButtonTemplate")
p.swapButton:SetSize(114, 24)
S.texts.heading, S.texts.layer, S.texts.swap = p.h1, p.layer, p.swapButton:GetFontString()
S.swapButton = p.swapButton
p:Hide()

S.state = { letter = "B", grouped = false }
function S.Refresh()
    p.layer:SetText(EN.layer .. S.state.letter)
    setButtonText(p.swapButton, S.state.grouped and EN.leave or EN.swap)
end
C_Timer.NewTicker(1, function() if p:IsShown() then S.Refresh() end end)
function S.Panel(show)
    if show then p:Show() S.Refresh() else p:Hide() end
end

-- ── The layer menu: made when first opened, a row with a layer and an age ───────────────────
local menu
function S.Menu(show, minutes)
    if not menu then
        menu = CreateFrame("Frame", "LayerSwapMenu", UIParent)
        menu:SetSize(200, 40)
        local b = CreateFrame("Button", nil, menu)
        b:SetSize(190, 18)
        b.name = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.age = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        S.texts.menuName, S.texts.menuAge = b.name, b.age
        menu:Hide()
    end
    if not show then return menu:Hide() end
    S.texts.menuName:SetText(EN.layer .. "C")
    S.texts.menuAge:SetText(minutes and minutes > 0 and (minutes .. EN.ago) or EN.now)
    menu:Show()
end

-- ── The settings menu: made when first opened, a row with a tooltip ─────────────────────────
local settings, row
function S.Settings(show)
    if not settings then
        settings = CreateFrame("Frame", "LayerSwapSettingsMenu", UIParent)
        settings:SetSize(200, 40)
        settings:Hide()
    end
    if not show then return settings:Hide() end
    settings:Show()
    if not row then
        row = CreateFrame("Button", nil, settings)
        row:SetSize(190, 18)
        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.label:SetText(EN.options)
        S.texts.options = row.label
        row:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(EN.shift, 1, 1, 1)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
end
function S.Hover() row:GetScript("OnEnter")(row) end
function S.Leave() row:GetScript("OnLeave")(row) end
