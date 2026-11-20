-- The stand-in's page in the game's options (UI.lua has the rest). Written for the checks, not taken
-- from DialogueUI: a nameless canvas made at load and given to Settings, a button (Button:SetText,
-- once) and an instruction line set on the first show, whose OnShow then replaces itself with
-- SetScript, as DialogueUI's does. Made at load, or later (S.MakeCanvas) when the flow sets
-- DUI_STANDIN_LATE_CANVAS before the game starts.
local _, addon = ...
local L = addon.L
local S = DialogueUIStandIn

function S.MakeCanvas()
    local canvas = CreateFrame("Frame")
    canvas:Hide()
    local open = CreateFrame("Button", nil, canvas)
    open:SetText(L["Open Settings"])
    local instruction = canvas:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    local function SetupInstruction() instruction:SetText(L["Instruction Open Settings"]) end
    canvas:SetScript("OnShow", function()
        SetupInstruction()
        canvas:SetScript("OnShow", SetupInstruction)
    end)
    S.canvas = canvas
    S.texts.canvasButton, S.recipes.canvasButton = open:GetFontString(), function(l) return l["Open Settings"] end
    S.texts.canvasText, S.recipes.canvasText = instruction, function(l) return l["Instruction Open Settings"] end
    S.canvasCategory = Settings.RegisterCanvasLayoutCategory(canvas, "Dialogue UI")
    Settings.RegisterAddOnCategory(S.canvasCategory)
end
if not rawget(_G, "DUI_STANDIN_LATE_CANVAS") then S.MakeCanvas() end
