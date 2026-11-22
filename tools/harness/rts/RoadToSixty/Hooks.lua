-- Prints, one tooltip, the three popups and the 4 game-wide hooks the real addon installs (lesson 35).
-- S.Say(msg)   print with the real prefix "|cff33ff99RoadToSixty|r: " (the folder name, kept as it is)
-- S.Tip()      GameTooltip with one line (its stack points into AddOns/RoadToSixty)
-- S.Popups()   the names of its three StaticPopupDialogs
-- S.sent       the identity of each hook right after login: S.SentNow() builds the same table to compare
-- Hooks: a chat filter (ERR_CHAT_PLAYER_NOT_FOUND_S), a SetItemRef hook, a StartDuel hook, MuteChats (unregisters
-- TIME_PLAYED_MSG on every chat frame). The flow makes StartDuel, the filter list and the events before login.
local S = RTSStandIn
local T = S.T

function S.Say(msg) print("|cff33ff99RoadToSixty|r: " .. msg) end

function S.Tip()
    GameTooltip:SetOwner(RoadToSixtyMinimapButton or UIParent)
    GameTooltip:AddLine(T.mini)
    GameTooltip:AddLine(T.tipLine)
    GameTooltip:Show()
end

StaticPopupDialogs.ROADTOSIXTY_RESET = { text = T.reset, button1 = T.yes, button2 = T.no,
    OnAccept = function() S.accepted = "reset" end }
StaticPopupDialogs.ROADTOSIXTY_DELETE_CHARACTER = { text = T.del, button1 = T.yes, button2 = T.no,
    OnAccept = function() S.accepted = "delete" end }
StaticPopupDialogs.ROADTOSIXTY_REMOVE_FRIEND = { text = T.rem, button1 = T.yes, button2 = T.no,
    OnAccept = function() S.accepted = "remove" end }
function S.Popups() return { "ROADTOSIXTY_RESET", "ROADTOSIXTY_DELETE_CHARACTER", "ROADTOSIXTY_REMOVE_FRIEND" } end

S.filter = function() return false end   -- the chat filter: a sentinel, never called by the harness
S.duels, S.refs = 0, 0

function S.SentNow()
    local muted = true
    for _, name in ipairs(CHAT_FRAMES) do
        local f = _G[name]
        if f and f:IsEventRegistered("TIME_PLAYED_MSG") then muted = false end
    end
    return { SetItemRef = SetItemRef, StartDuel = StartDuel, filter = S.filter, muted = muted,
        filters = RTSFilters and RTSFilters.CHAT_MSG_SYSTEM and RTSFilters.CHAT_MSG_SYSTEM[1] }
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
    ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", S.filter)
    hooksecurefunc("SetItemRef", function() S.refs = S.refs + 1 end)
    hooksecurefunc("StartDuel", function() S.duels = S.duels + 1 end)
    for _, name in ipairs(CHAT_FRAMES) do
        local f = _G[name]
        if f then f:UnregisterEvent("TIME_PLAYED_MSG") end
    end
    S.sent = S.SentNow()
end)
