-- Not Attune: the stand-in's other windows for tools/harness/flow_att.py, by Attune's names: the
-- Next window (rows made when needed, rebuilt on every bag change), the survey menu and results list,
-- the quest reward and quest detail panels, the sync progress bar and the four StaticPopup dialogs.
local L = AttuneLang
local SI = AttuneStandIn
local Attune = LibStub("AceAddon-3.0"):GetAddon("Attune")

-- ── Next window ──────────────────────────────────────────────────────────────────────────────
local nextFrame = CreateFrame("Frame", "Attune_NextFrame", UIParent)
nextFrame:SetSize(260, 160)
nextFrame:SetPoint("CENTER")
local title = CreateFrame("Frame", nil, nextFrame)
title:SetSize(260, 18)
title:SetPoint("TOP")
title.text = title:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title.text:SetText(L["NextSteps_TITLE"] or "Attune: Next")
title:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(L["NextSteps_DRAG"] or "Drag to move")
    GameTooltip:Show()
end)
local empty = nextFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
empty:SetText(L["NextSteps_EMPTY"] or "Nothing to do right now")
empty:Hide()
nextFrame.rows = {}
SI.nextTitle, SI.nextEmpty = title.text, empty

local function RowEnter(row)
    local e = row.entry
    if not e or not e.attune then return end
    local a, s = e.attune, e.step
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:SetText(a.NAME or "")
    if a.LEVELS and a.LEVELS ~= "" then GameTooltip:AddLine(a.LEVELS, 0.75, 0.75, 0.75) end
    GameTooltip:AddLine(Attune_NextStepLabel(s), 1, 1, 1)
    if s.LOCATION ~= "" then
        GameTooltip:AddLine((L[s.TYPE] or "") .. " " .. (L["in"] or "in") .. " " .. s.LOCATION, 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end

local function Entries()
    local out, toon = {}, SI.Toon()
    for _, a in ipairs(Attune_Data.attunes) do
        if (a.FACTION == "Both" or a.FACTION == "Horde") and (toon.attuned[a.ID] or 0) < 100 then
            for _, s in ipairs(Attune_Data.steps) do
                if s.ID_ATTUNE == a.ID and not toon.done[a.ID .. "-" .. s.ID] and s.TYPE ~= "Level" then
                    local stepText = "|cffffffff" .. Attune_NextStepLabel(s) .. "|r"
                    local text = "|cffffd100" .. a.SHORT .. "|r  " .. stepText
                    if a.LEVELS and a.LEVELS ~= "" then text = "|cffaaaaaa" .. a.LEVELS .. "|r  " .. text end
                    out[#out + 1] = { text = text, attune = a, step = s }
                    break
                end
            end
        end
    end
    out[#out + 1] = { text = "|cffaaaaaa" .. L["NextSteps_LATER"]:gsub("##LEVEL##", "62") .. "|r", note = true }
    return out
end

function Attune_NextFrameLayout()
    local entries = SI.nextEntries or {}
    for i, e in ipairs(entries) do
        local row = nextFrame.rows[i]
        if not row then
            row = CreateFrame("Button", nil, nextFrame)
            row:SetSize(250, 14)
            row:SetPoint("TOPLEFT", 4, -20 - (i - 1) * 14)
            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            row.text:SetPoint("LEFT")
            row:SetScript("OnEnter", RowEnter)
            row:SetScript("OnLeave", function() GameTooltip:Hide() end)
            nextFrame.rows[i] = row
        end
        row.entry = e
        row.text:SetText(e.text or "")
        row:Show()
    end
    for i = #entries + 1, #nextFrame.rows do nextFrame.rows[i]:Hide() end
    if #entries == 0 then empty:Show() else empty:Hide() end
end

function Attune_NextFrameRefresh()
    SI.refreshes = (SI.refreshes or 0) + 1
    SI.nextEntries = Entries()
    Attune_NextFrameLayout()
end

function Attune_NextFrameSetMinimized(min)
    for _, r in ipairs(nextFrame.rows) do r:SetShown(not min) end
end

-- ── Survey menu and results ──────────────────────────────────────────────────────────────────
local menu = CreateFrame("Frame", "Attune_SurveyMenuFrame", UIParent)
menu:SetSize(140, 60)
menu:Hide()
local function MenuLine(text, y)
    local b = CreateFrame("Button", nil, menu)
    b:SetSize(130, 16)
    b:SetPoint("TOPLEFT", 4, y)
    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.text:SetText(text)
    return b
end
SI.menuGuild = MenuLine(L["Guild"], -4).text
SI.menuChar = MenuLine(L["Character"], -22).text

function Attune_ShowSurveyMenu() menu:Show() end

function Attune_ShowResultList()
    if not rawget(_G, "Attune_MainFrame") then Attune_Frame() end
    local f = rawget(_G, "Attune_ResultsFrame")
    if not f then
        f = CreateFrame("Frame", "Attune_ResultsFrame", Attune_MainFrame)
        f:SetSize(400, 200)
        f.head1 = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.head2 = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.row = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    end
    f.head1:SetText(L["Character"])
    f.head2:SetText(L["Results"])
    f.row:SetText("Tester - 60")
    f:Show()
    SI.results = f
end

-- ── Quest reward and detail panels ───────────────────────────────────────────────────────────
local reward = CreateFrame("Frame", "AttuneQuestRewardFrame", UIParent)
reward:SetSize(300, 200)
reward:Hide()
reward.title = reward:CreateFontString(nil, "OVERLAY", "GameFontNormal")
reward.line = reward:CreateFontString(nil, "OVERLAY", "GameFontHighlight")

function Attune_ShowQuestRewards(qid)
    reward.title:SetText(L["Choose one reward"])
    reward.line:SetText(L["Loading rewards"])
    reward:Show()
end

local detail = CreateFrame("Frame", "AttuneQuestDetail", UIParent)
detail:SetSize(300, 300)
detail:Hide()
detail.title = detail:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
detail.sub = detail:CreateFontString(nil, "OVERLAY", "GameFontNormal")
detail.giver = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
detail.body = detail:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
SI.detail = detail

function Attune_ShowQuestDetail(qid)
    local q = Attune_Data.quests[qid]
    if not q then
        detail.title:SetText(L["Quest information not found"] .. " (ID " .. qid .. ")")
        detail.giver:SetText("")
        detail.body:SetText("")
    else
        local giver = Attune_Data.questGivers[qid]
        detail.title:SetText(L["Q1_" .. qid])
        detail.giver:SetText(L["Starts at"] .. " " .. (giver and giver[4] or ""))
        detail.body:SetText(L["Q2_" .. qid])
    end
    detail.sub:SetText("Quest rewards")
    detail:Show()
end

-- ── Sync ─────────────────────────────────────────────────────────────────────────────────────
local sync = CreateFrame("Frame", "Attune_SyncProgress_Frame", UIParent)
sync:SetSize(240, 40)
sync:Hide()
sync.bar = CreateFrame("StatusBar", "Attune_SyncProgress_Bar", sync)
sync.text = sync.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
SI.sync = sync

function Attune_StartSync(target)
    SI.syncTarget = target
    StaticPopup_Show("SYNC_CONFIRM", nil, nil, target)
end

function SI.SyncShown(target)
    sync.text:SetText((L["Sending Sync Request"]:gsub("##PLAYER##", target)))
    sync:Show()
end

function SI.SyncOver(seconds)
    sync.text:SetText((L["Sync over"]:gsub("##DURATION##", seconds .. "s")))
end

-- ── Dialogs (as Attune declares them) ────────────────────────────────────────────────────────
StaticPopupDialogs["EXPORT_ATTUNE_GUILD"] = {
    text = L["Copy the text below, then upload it to"] .. "\n\nhttps://warcraftratings.com/attune/upload",
    button1 = L["Close"], hasEditBox = true, editBoxWidth = 350, timeout = 0, whileDead = true,
    OnShow = function(self) (self.EditBox or self.editBox):SetText(SI.export or "") end,
}
StaticPopupDialogs["SYNC_CONFIRM"] = {
    text = "", button1 = L["Accept"], button2 = L["Reject"], timeout = 0, whileDead = true,
    OnShow = function(self, data) end,
    OnAccept = function(self, data)
        SI.SyncShown(SI.syncTarget)
        Attune:SendCommMessage("Attune_Sync", "SYNCREQ", "WHISPER", SI.syncTarget)
    end,
}
StaticPopupDialogs["SYNC_ATTUNE"] = {
    text = "", button1 = L["Accept"], button2 = L["Reject"], timeout = 0, whileDead = true,
    OnAccept = function(self, t) Attune:SendCommMessage("Attune_Sync", "SYNCOK|1", "WHISPER", t) end,
    OnCancel = function(self, t) Attune:SendCommMessage("Attune_Sync", "SYNCNOK", "WHISPER", t) end,
}
StaticPopupDialogs["ATTUNE_SHOW_URL"] = {
    text = L["External link"], button1 = L["Close"], hasEditBox = true, editBoxWidth = 350, timeout = 0,
    OnShow = function(self) (self.EditBox or self.editBox):SetText(Attune_DB.websiteUrl .. "/" .. (SI.qstring or "")) end,
}

-- The two sync questions: Attune writes the text with the player's name just before showing them.
function SI.AskSync(target)
    StaticPopupDialogs["SYNC_CONFIRM"].text = L["Sending Sync Request"]:gsub("##PLAYER##", target) .. "\n\n"
        .. L["Could be slow"]
    Attune_StartSync(target)
end

function SI.SyncFrom(t)
    StaticPopupDialogs["SYNC_ATTUNE"].text = L["Sync Request From"]:gsub("##PLAYER##", t) .. "\n\n" .. L["Could be slow"]
    StaticPopup_Show("SYNC_ATTUNE", nil, nil, t)
end

function Attune_ExportToWeb()
    SI.Print((L["ExportingData"]:gsub("##COUNT##", "1")))
    local keys = {}
    for k in pairs(SI.Toon().done) do keys[#keys + 1] = k end
    table.sort(keys)
    SI.export = "16001-40|" .. table.concat(keys, ",") .. "|ENC"
    StaticPopup_Show("EXPORT_ATTUNE_GUILD")
end

function Attune_ShowWebsiteURL(qstring)
    SI.qstring = qstring
    StaticPopup_Show("ATTUNE_SHOW_URL")
end
