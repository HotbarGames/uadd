-- Not Pawn: a small stand-in for tools/harness/flow_pawn.py, shaped like Pawn where UADD_Pawn touches it.
-- Pawn's licence allows none of its English here: every word is read from PawnLocal and the UI globals,
-- which the flow made by running the installed Pawn's Localization.lua and UIStrings.lua first.
--   * PawnUIFrame (hidden until opened): labels made from UI globals, as XML text= does; a nested page;
--     a hidden page shown later (a tab switch); tabs; a header; an EditBox; a scale selector built on
--     first open (provider header lines, scale lines with ScaleName).
--   * Labels set once on first open (PawnUI_EnsureLoaded): the show-scale label (player's name), the
--     credits line (a made-up line of code, keyed by its hash), and the About version label on show.
--   * Saved scales whose Header is Pawn's provider text, saved again at each login (S.SaveScales).
--   * PawnAddTooltipLine splits at the last ": " when numbers align right; PawnUIFrame_TooltipOn shows a
--     control's label and help.
local S = {}
PawnStandIn = S
local FONT = "Fonts\\FRIZQT__.TTF"
local L = PawnLocal

S.THANKS = "Quix thanks the wobbly gizmo crew."   -- made up: a fixed line in Pawn's code
S.MINE = L.UI.ValuesTab                            -- a scale the player named like one of Pawn's texts
S.order = { "\"Starter\":Quix", "\"Robot\":Quix", "Mine" }

local function Fs(parent, name, g)
    local fs = parent:CreateFontString(name)
    fs:SetFont(FONT, 12, "")
    if g then fs:SetText(_G[g]) end
    return fs
end

local function Btn(parent, name, kind)
    local b = CreateFrame(kind or "Button", name, parent)
    b:SetFontString(Fs(b))
    return b
end

-- Saved data: built-in scales keep Pawn's provider text as their Header, saved again at each login.
PawnCommon = { AlignNumbersRight = true, Scales = {} }
function S.SaveScales()
    local sc = PawnCommon.Scales
    sc[S.order[1]] = { Header = PawnLocal.UI.StarterProvider, LocalizedName = "Quixwood Tank" }
    sc[S.order[2]] = { Header = PawnLocal.UI.AskMrRobotProvider, LocalizedName = "Quixwood Healer" }
    sc.Mine = sc.Mine or { LocalizedName = S.MINE }
end
S.SaveScales()

PawnUIOpenedYet = false
PawnUICurrentScale = L.NoScale
PawnUICurrentTabNumber = 1
PawnUITotalScaleLines = 0

-- The window, made at load like Pawn's XML.
local ui = CreateFrame("Frame", "PawnUIFrame", UIParent)
ui:Hide()
Fs(ui, "PawnUIFrame_BestItemsHeader", "PawnUIFrame_BestItemsHeader_Text")
Fs(ui, "PawnUIHeader")
Fs(ui, "PawnUIFrame_ShowScaleCheck_Label")
Fs(ui, "PawnUIFrame_ScaleNameLabel")
local page = CreateFrame("Frame", "PawnUIFrame_OptionsPage", ui)
local check = Btn(page, "PawnUIFrame_AlignRightCheck", "CheckButton")
check:SetText(PawnUIFrame_AlignRightCheck_Text)
local about = CreateFrame("Frame", "PawnUIFrame_AboutPage", ui)
about:Hide()
Fs(about, "PawnUIFrame_AboutTranslationLabel", "PawnUIFrame_AboutTranslationLabel_Text")
Fs(about, "PawnUIFrame_AboutVersionLabel")
Fs(about, "PawnUIFrame_MrRobotLabel")
local box = CreateFrame("EditBox", "PawnUIFrame_ScaleNameBox", ui)
box:SetText(S.MINE)
local selector = CreateFrame("Frame", "PawnUIScaleSelector", ui)
for i = 1, 7 do
    local tab = Btn(ui, "PawnUIFrameTab" .. i)
    tab:SetText(PawnUITabLabels[i])
end

-- The settings page.
local opt = CreateFrame("Frame", "PawnInterfaceOptionsFrame", UIParent)
Fs(opt, "PawnInterfaceOptionsFrame_OptionsHeaderLabel", "PawnInterfaceOptionsFrame_OptionsHeaderLabel_Text")

function PawnUIUpdateHeader()
    local fmt = PawnUIHeaders[PawnUICurrentTabNumber]
    if not fmt then return end
    local name = PawnLocal.NoScale
    if PawnUICurrentScale ~= PawnLocal.NoScale then
        name = "|cff8ec3e6" .. PawnCommon.Scales[PawnUICurrentScale].LocalizedName .. "|r"
    end
    PawnUIHeader:SetText(format(fmt, name))
end

function PawnUIFrame_ScaleSelector_Refresh()
    local n, seen = 0, {}
    local function Line(text, scale)
        n = n + 1
        local b = _G["PawnUIScaleLine" .. n] or Btn(selector, "PawnUIScaleLine" .. n)
        b.ScaleName = scale
        b:SetText(text)
        b:Show()
    end
    for _, key in ipairs(S.order) do
        local s = PawnCommon.Scales[key]
        if s.Header and not seen[s.Header] then seen[s.Header] = true; Line(s.Header) end
        Line(s.LocalizedName, key)
    end
    PawnUITotalScaleLines = n
end

function PawnUI_ScalesTab_Refresh()
    local s = PawnCommon.Scales[PawnUICurrentScale]
    PawnUIFrame_ScaleNameLabel:SetText(s and s.LocalizedName or PawnLocal.NoScale)
end

function PawnUI_EnsureLoaded()
    if PawnUIOpenedYet then return end
    PawnUIOpenedYet = true
    PawnUIFrame_ScaleSelector_Refresh()
    PawnUIFrame_ShowScaleCheck_Label:SetText(format(PawnUIFrame_ShowScaleCheck_Label_Text, UnitName("player")))
    PawnUIFrame_MrRobotLabel:SetText(S.THANKS)
end

ui:SetScript("OnShow", function()
    PawnUI_EnsureLoaded()
    PawnUIFrame_AboutVersionLabel:SetText(format(PawnUIFrame_AboutVersionLabel_Text,
        C_AddOns.GetAddOnMetadata("Pawn", "Version")))
    PawnUI_ScalesTab_Refresh()
    PawnUIUpdateHeader()
end)

function S.Open() ui:Show() end
function S.Close() ui:Hide() end
function S.ShowAbout(on) if on then about:Show() else about:Hide() end end

-- Tooltips: with numbers aligned right, a line splits at its last ": " into a left and a right part; the
-- right part starts with the line's colour code (its first 10 characters).
function PawnAddTooltipLine(tip, text, r, g, b)
    if PawnCommon.AlignNumbersRight then
        local at, from = nil, 1
        while true do
            local p = text:find(": ", from, true)
            if not p then break end
            at, from = p, p + 1
        end
        if at then
            tip:AddDoubleLine(text:sub(1, at - 1), text:sub(1, 10) .. text:sub(at + 2):gsub("^%s+", ""), r, g, b, r, g, b)
            return
        end
    end
    tip:AddLine(text, r, g, b)
end

function PawnUIFrame_TooltipOn(self)
    local name = self:GetName()
    local help = _G[name .. "_Tooltip"]
    local label = _G[name .. "_Label"] or _G[name .. "_Text"] or self:GetText()
    if type(label) == "table" then label = label:GetText() end
    if not help then return end
    GameTooltip:ClearLines()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:AddLine(label)
    GameTooltip:AddLine(help)
    GameTooltip:Show()
end

-- An item's lines as Pawn adds them: a word with its value, and a scale's value with an annotation.
function S.ItemTip(tip)
    tip:ClearLines()
    tip:SetOwner(UIParent, "ANCHOR_RIGHT")
    PawnAddTooltipLine(tip, "|cff8ec3e6" .. PawnLocal.BaseValueWord .. ":  |cffffffff45.6", 1, 1, 1)
    PawnAddTooltipLine(tip, "|cff8ec3e6Quixwood Tank:  12.3 " .. format(PawnLocal.TooltipBestAnnotation, ""), 1, 1, 1)
    tip:Show()
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function() S.SaveScales() end)
