-- Not ForeverXP Bar: a small stand-in for tools/harness/flow_fxpb.py, shaped like it where UADD
-- touches it: named frames (bar, minimap button, options, record, race), the bar's per-tick texts in
-- FRIZQT and in one of its own Latin-only font files, panel labels in ARIALN, a nameless page for the
-- game's Settings window, a tooltip on its minimap button, printMsg chat lines, what it sends to
-- other players, an edit box and a scanning tooltip it reads back, a nameless feature guide and
-- drop-down list (made with the options window), a second Settings page made at PLAYER_ENTERING_WORLD,
-- a StaticPopup question, and another addon's nameless dialog. Its texts are a few of its real
-- labels (UADD_ForeverXPBar/data/words.lua has their hashes).
local S = {}
ForeverXPbarStandIn = S

local BAR_FONT = "Fonts\\FRIZQT__.TTF"
local OWN_FONT = "Interface\\AddOns\\ForeverXPbar\\Fonts\\BigNoodleToo.ttf"
local PANEL_FONT = "Fonts\\ARIALN.TTF"
local PREFIX = "|cff8ee6deForeverXP Bar|r "
S.PREFIX, S.OWN_FONT, S.BAR_FONT = PREFIX, OWN_FONT, BAR_FONT
S.sent = {}      -- what it sent to other players: { kind, text }
S.texts = {}     -- name -> FontString
S.fonts = {}     -- name -> { file, size, flags }: the font it set (the checks compare ours with it)

local function Text(parent, name, font, size, flags, text)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(font, size, flags)
    S.fonts[name] = { font, size, flags }
    if text then fs:SetText(text) end
    S.texts[name] = fs
    return fs
end

-- printMsg, as in ForeverXPBar.lua.
function S.printMsg(msg) DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg) end

-- ── The bar ───────────────────────────────────────────────────────────────────────────────────
local main = CreateFrame("Frame", "ForeverXPBarMainFrame", UIParent)
main:SetSize(600, 30)
main:SetPoint("TOP", UIParent, "TOP", 0, -20)
local bar = CreateFrame("Frame", "ForeverXPBarBarFrame", main)
bar:SetAllPoints(main)
Text(bar, "right", BAR_FONT, 12, "OUTLINE", "0 / 1,000 (0.0%)")
Text(bar, "underLeft", OWN_FONT, 14, "", "")
Text(bar, "rate", BAR_FONT, 11, "OUTLINE", "-- XP/Hour")
Text(bar, "lock", PANEL_FONT, 12, "", "Lock Bar")
local insights = CreateFrame("Frame", "ForeverXPBarInsights", main)
insights:SetAllPoints(main)
insights:Hide()
Text(insights, "kills", BAR_FONT, 12, "", "Kills to level")

-- One bar update, as its OnUpdate driver does: three texts with the numbers of tick n.
local function Short(v) return v >= 1000 and ("%.1fK"):format(v / 1000) or tostring(v) end
function S.Tick(n)
    local xp, max = (n * 37) % 100000, 100000
    S.texts.right:SetText(("%s / %s (%.1f%%)"):format(xp, max, xp / max * 100))
    local rate = (n % 50 == 0) and "-- XP/Hour" or ("%s XP/Hour"):format(Short(20000 + n * 13))
    S.texts.rate:SetText(rate)
    S.texts.underLeft:SetText(("Leveling in: %s (%s)"):format(("%dh %02dm"):format(n % 5, n % 60), rate))
end
S.Tick(1)

-- The bar's right-hand line under it (one part, or both joined), and the countdown under a camp
-- buff icon: a text that is only the time. Both in its own Latin-only font (so a font swap shows).
Text(bar, "underRight", OWN_FONT, 12, "", "")
Text(bar, "camp", OWN_FONT, 10, "OUTLINE", "36m")
local DONE = "|cff%02x%02x%02xCompleted: %.1f%%|r"
local REST = "|cFF66B2FFRested: %.1f%%|r"
function S.Under(done, rest)
    if done and rest then
        S.texts.underRight:SetText((DONE .. " |cFFFFFFFF\226\128\162|r " .. REST):format(255, 189, 71, done, rest))
    else
        S.texts.underRight:SetText(done and DONE:format(255, 189, 71, done) or rest and REST:format(rest) or "")
    end
end
function S.Camp(t) S.texts.camp:SetText(t) end

-- ── Minimap button and its tooltip ────────────────────────────────────────────────────────────
local mm = CreateFrame("Button", "ForeverXPBarMinimapButton", Minimap)
mm:SetSize(31, 31)
mm:SetPoint("TOPLEFT", Minimap, "TOPLEFT")
function S.Hover()
    GameTooltip:SetOwner(mm, "ANCHOR_LEFT")
    GameTooltip:SetText(("ForeverXP Bar - Level %s"):format(12))
    GameTooltip:AddLine("Left-click: settings", 1, 1, 1)
    GameTooltip:AddDoubleLine("Kills to level", "42")
    GameTooltip:AddLine("Right-click: lock/unlock bar", 1, 1, 1)
    GameTooltip:Show()
end
function S.Leave() GameTooltip:Hide() end
-- Its reputation strip since 0.9.1: nameless, movable, right on UIParent. Unlocked, it shows a drag
-- tooltip (the title is a template plus one of its own texts); `short` puts a short word of its own there instead.
local repStrip = CreateFrame("Frame", nil, UIParent)
repStrip.__movable = true
function S.HoverRep(short)
    GameTooltip:SetOwner(repStrip, "ANCHOR_TOP")
    GameTooltip:SetText(short and "Options" or ("Drag to move " .. "reputation bar" .. " freely"))
    if not short then GameTooltip:AddLine("Lock it again in Tracking settings.", 0.75, 0.85, 1) end
    GameTooltip:Show()
end

-- ── Options window (ARIALN labels, a tab shown later) ────────────────────────────────────────
local opt = CreateFrame("Frame", "ForeverXPBarOptionsFrame", UIParent)
opt:SetSize(400, 300)
opt:SetPoint("CENTER")
Text(opt, "options", PANEL_FONT, 16, "", "Options")
Text(opt, "lockOpt", PANEL_FONT, 12, "", "Lock Bar")
local tab = CreateFrame("Frame", nil, opt)
tab:SetAllPoints(opt)
tab:Hide()
Text(tab, "leveling", PANEL_FONT, 12, "", "Leveling info")
opt:Hide()
function S.OpenOptions() opt:Show() end
function S.CloseOptions() opt:Hide() end
function S.Tab(show) if show then tab:Show() else tab:Hide() end end

-- ── Record window (hidden at first) ───────────────────────────────────────────────────────────
local rec = CreateFrame("Frame", "ForeverXPBarRecordFrame", UIParent)
rec:SetSize(300, 200)
rec:SetPoint("CENTER")
Text(rec, "record", BAR_FONT, 14, "OUTLINE", "ForeverXP Bar - Record")
Text(rec, "time", BAR_FONT, 12, "", ("Time this level: %s"):format("1h 2m"))
Text(rec, "since", BAR_FONT, 12, "", ("+%d level%s since you started"):format(3, "s"))
rec:Hide()
function S.Record(show) if show then rec:Show() else rec:Hide() end end

-- ── A nameless page for the game's Settings window ───────────────────────────────────────────
local page = CreateFrame("Frame")
page.name = "ForeverXP Bar"
Text(page, "pageTitle", PANEL_FONT, 16, "", "ForeverXP Bar")
Text(page, "pageFlight", PANEL_FONT, 12, "", "Flight travel")
page:SetParent(UIParent)
page:SetAllPoints(UIParent)
page:Hide()
S.page = page
function S.Page(show) if show then page:Show() else page:Hide() end end

-- ── Race window: a code box and what it sends ────────────────────────────────────────────────
local race = CreateFrame("Frame", "ForeverXPBarRace", UIParent)
race:SetSize(300, 200)
race:SetPoint("CENTER")
local box = CreateFrame("EditBox", nil, race)
box:SetText("Lock Bar")
S.box = box
Text(race, "raceInfo", PANEL_FONT, 12, "", ("Race created: %s | Code: %s. Share the code with friends."):format("Speed", "AB12"))

-- Its scanning tooltip: lines are read back to find item stats.
local scan = CreateFrame("GameTooltip", "ForeverXPBarScanTip", UIParent)
local scanLine = scan:CreateFontString("ForeverXPBarScanTipTextLeft1")
scanLine:SetFont(BAR_FONT, 12, "")
function S.Scan()
    scanLine:SetText("Lock Bar")
    return scanLine:GetText()
end

-- What it sends: an addon message and a chat line ("[FXPB] ..."), made from its English.
function S.Send()
    local msg = "LVL:12:Lock Bar"
    local line = "[FXPB] " .. ("ForeverXP Bar - Level %s"):format(12)
    S.sent[#S.sent + 1] = { "addon", msg }
    C_ChatInfo.SendAddonMessage("FXPB", msg, "CHANNEL")
    S.sent[#S.sent + 1] = { "chat", line }
    SendChatMessage(line, "CHANNEL")
    -- Its chat filter reads such a line back from another player.
    DEFAULT_CHAT_FRAME:AddMessage(line)
    return msg, line
end

-- Its read-back: the edit box's code and the scanning tooltip's line.
function S.ReadBack() return box:GetText(), S.Scan() end

-- ── Made with the options window: a drop-down's list and the feature guide, nameless on UIParent
local dd = CreateFrame("Button", nil, opt)
dd:SetPoint("TOPLEFT", opt, "TOPLEFT", 10, -40)
local pop = CreateFrame("Frame", nil, UIParent)
pop:SetFrameStrata("FULLSCREEN_DIALOG")
pop:SetPoint("TOPLEFT", dd, "BOTTOMLEFT", 0, -2)
Text(CreateFrame("Button", nil, pop), "popRow", PANEL_FONT, 11, "", "Lock Bar")   -- short: found by its anchor alone
pop:Hide()
local guide = CreateFrame("Frame", nil, UIParent)
guide:SetFrameStrata("FULLSCREEN_DIALOG")
guide:SetPoint("CENTER", UIParent, "CENTER", 0, 25)
Text(guide, "guideTitle", BAR_FONT, 13, "", "|cff8ee6deXP|r Bar  |cff8a8a8aWhat's New|r")
Text(CreateFrame("Button", nil, guide), "guideOk", BAR_FONT, 12, "", "I understand")
guide:Hide()
-- Another addon's nameless dialog with a short word ForeverXP Bar has too: not ForeverXP Bar's.
local other = CreateFrame("Frame", nil, UIParent)
other:SetFrameStrata("FULLSCREEN_DIALOG")
other:SetPoint("CENTER")
Text(other, "otherText", PANEL_FONT, 12, "", "Options")
other:Hide()
local shown = { pop = pop, guide = guide, other = other }
function S.Show(what, show) if show then shown[what]:Show() else shown[what]:Hide() end end

-- ── Its second Settings page, made at PLAYER_ENTERING_WORLD (text in a font object, left-justified)
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function()
    if shown.page2 then return end
    local p = CreateFrame("Frame")
    p.name = "Forever Challenge XP"
    local desc = p:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetJustifyH("LEFT")
    desc:SetText("Optional challenges, races, leaderboards, level-up cards and Played records.")
    S.texts.pageDesc = desc
    p:SetParent(UIParent)
    p:SetAllPoints(UIParent)
    p:Hide()
    shown.page2 = p
end)

-- The reload question in the game's StaticPopup, as Fx._askReload.
function S.AskReload()
    StaticPopupDialogs["FOREVERXPBAR_RELOAD_UI"] = StaticPopupDialogs["FOREVERXPBAR_RELOAD_UI"] or {
        text = "ForeverXP Bar: the minimap icon setting changed.\n\nReload the UI now to apply and save it?",
        button1 = "Reload UI", button2 = "Later" }
    StaticPopup_Show("FOREVERXPBAR_RELOAD_UI")
end
