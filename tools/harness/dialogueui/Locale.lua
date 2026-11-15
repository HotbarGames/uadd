-- A stand-in for DialogueUI's locale in the harness. Written for the checks, not taken from
-- DialogueUI: a few of its English texts (Locales/enUS.lua) under the same keys, in its private
-- L table, and a formatter that turns "[KEY:device:button]" into a key picture once at load, the
-- way DialogueUI's LocaleFormatter does (so the shown English differs from enUS.lua there).
local _, addon = ...
local L = {}
addon.L = L

-- The quest window.
L["Quest Type Repeatable"] = "Repeatable"
L["Quest Difficulty Hard"] = "Hard"
L["Your Level"] = "Your Level"
L["Quest Level"] = "Quest Level"
L["Format Suggested Players"] = "Suggested Players [%d]"
L["Format Your Progress"] = "Your progress: |cffffffff%d/%d|r"
L["Format Player XP"] = "XP: %d/%d (%d%%)"
L["Press Tab To Select Reward Desc"] = "Press [KEY:PC:TAB] to cycle through choosable rewards when you turn in the quest."
L["Use Default Control Key Alert"] = "We will still use [KEY:PC:SPACE] as the Confirm Button."
L["Interact Key Not Set"] = "[KEY:PC:INVALID] You haven't set an Interact Key."
-- Quest text (the body pool) and chat formats whose %s could swallow quest prose.
L["Rewards"] = "Rewards"
L["Format Quest Completed"] = "%s completed."
L["Format Reward Title"] = "Title: %s"
-- Option buttons (pooled).
L["Format Quest Accepted"] = "Quest accepted: %s"
L["Format Time Left"] = "Time Left: %s"
L["Format And More"] = "and %d more..."
L["Widget Is Docked Named"] = "%s is docked with other pop-ups."
-- Settings.
L["UI"] = "UI"
L["Gameplay"] = "Gameplay"
L["Accessibility"] = "Accessibility"
L["Font Size"] = "Font Size"
L["Font Size Desc"] = "Set the font size for the UI.\n\nDefault: 12"
L["BookUI Darken Screen"] = "Darken Screen"
L["BookUI Darken Screen Desc"] = "Darken the area below the UI to help you concentrate on the content."
L["Option Enabled"] = "Enabled"
L["BookUI Keep UI Open"] = "Keep Window Open"
L["BookUI Keep UI Open Desc"] = "Keep the window open when you move away from the object.\n\nPress Escape or right-click on the UI to close it."
L["Default Font"] = "Default Font"
-- The custom tooltip.
L["Format Item Level"] = "Item Level %d"
L["Item Level"] = "Item Level"
L["Format Reputation Reward Tooltip"] = "Awards %d reputation with the %s"
L["Format You Have X"] = "- You have |cffffffff%s|r"
L["Format Gold Amount"] = "%d Gold"
-- Book UI and chat.
L["BookUI TTS Click To Read"] = "Click Paragraph To Read"
L["Auto Select"] = "Auto Select"
L["Quest Unblocked Alert"] = "Quest unblocked. The quest window will appear the next time the game automatically offers you this quest."

local KEYS = "Interface/AddOns/DialogueUI/Art/Keys/"
local TAB = "|TInterface/AddOns/DialogueUI/Art/Keys/PC-TAB.png:16:29:0:-4:64:32:0:58:0:32:|t"

-- "[KEY:PC:SPACE]" -> "|T<keys>PC-SPACE.png:16:16:0:0|t" (Tab has its own wider picture).
function addon.KeyMarkup(text)
    for _ = 1, 4 do
        local device, button = text:match("%[KEY:(%w+):(%w+)%]")
        if not device then break end
        local picture = button == "TAB" and TAB or ("|T%s%s-%s.png:16:16:0:0|t"):format(KEYS, device, button)
        text = text:gsub("%[KEY:%w+:%w+%]", (picture:gsub("%%", "%%%%")), 1)
    end
    return text
end

for key, text in pairs(L) do
    if text:find("[KEY:", 1, true) then L[key] = addon.KeyMarkup(text) end
end
