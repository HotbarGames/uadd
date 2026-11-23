-- Harness stand-in for OneForAll (not the addon): a few of its global frame names, made-up English.
-- Shaped as the addon where UADD_OneForAll looks: the addon table is _G.OneForAll (FLT), its chat lines go through
-- FLT.Msg (DEFAULT_CHAT_FRAME:AddMessage with its coloured name, never print), its language is FLT.Language()
-- from OneForAllDB.language ("game": the client's), and the player's profiles are OneForAllDB.profiles[name].
-- S.T        the made-up texts by role (the flow reads them; real English is fed at run time by flow_ofa.py)
-- S.Late()   one of its named windows made after login; S.Pin() a map pin (game names: left alone)
-- S.Tip()    GameTooltip lines from this file; S.Say(text) one chat line; S.Redraw() every text set again
local ADDON, FLT = ...
_G[ADDON] = FLT
FLT.DISPLAY_NAME = "OneForAll"
FLT.LANGUAGES = { { key = "enUS" }, { key = "deDE" }, { key = "frFR" }, { key = "esES" }, { key = "ptBR" } }
FLT.DUNGEONS = {}

OneForAllDB = OneForAllDB or {}
OneForAllDB.profiles = OneForAllDB.profiles or { Zorp = {} }

function FLT.Language()
    local lang = OneForAllDB.language or "game"
    if lang == "game" then lang = GetLocale() end
    for _, l in ipairs(FLT.LANGUAGES) do if l.key == lang then return lang end end
    return "enUS"
end

function FLT.Msg(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccff" .. tostring(FLT.DISPLAY_NAME or "OneForAll") .. ":|r " .. tostring(text))
end

local S = {}
OneForAllStandIn = S
S.T = { title = "Wobbly gizmo board", tab = "Plonk tab", button = "Plonk the gizmo", late = "Wobbly late gizmo",
    pin = "Gizmo pin", say = "Gizmo plonked", tip = "Click to plonk a gizmo", profile = "Zorp" }

local function Label(parent, text, y)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, y)
    fs:SetText(text)
    return fs
end

function S.Build()
    if S.main then return end
    local f = CreateFrame("Frame", "OneForAllFrame", UIParent)
    f:SetSize(400, 300)
    f:SetPoint("CENTER")
    S.main = f
    S.title = Label(f, S.T.title, -8)
    local tab = CreateFrame("Button", "OneForAllFrameTab1", f)
    tab:SetSize(80, 20)
    tab:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, 0)
    tab.fs = Label(tab, S.T.tab, -2)
    S.tab = tab
    S.button = Label(f, S.T.button, -40)
    S.profile = Label(f, S.T.profile, -70)          -- the chosen profile's name, as the player typed it
    f:Show()
end

function S.Redraw()
    S.title:SetText(S.T.title)
    S.tab.fs:SetText(S.T.tab)
    S.button:SetText(S.T.button)
    S.profile:SetText(S.T.profile)
end

function S.Late()
    if not S.late then
        local f = CreateFrame("Frame", "OneForAllWelcome", UIParent)     -- its welcome window: made on first open
        f:SetSize(200, 60)
        f:SetPoint("TOP")
        S.late = f
        S.lateText = Label(f, S.T.late, -8)
    end
    S.late:Show()
    return S.lateText
end

function S.Pin()
    if not S.pin then
        local f = CreateFrame("Frame", "OneForAllMapPin1", S.main)       -- inside a walked window, so only the skip keeps it
        f:SetSize(20, 20)
        f:SetPoint("BOTTOM")
        S.pin = f
        S.pinText = Label(f, S.T.pin, -2)
    end
    S.pin:Show()
    return S.pinText
end

-- Its news window, made later inside a walked window, with a word that is ours on the main window's button.
function S.News()
    if not S.news then
        local f = CreateFrame("Frame", "OneForAllWhatsNew", S.main)
        f:SetSize(20, 20)
        f:SetPoint("TOP")
        S.news = f
        S.newsText = Label(f, S.T.button, -2)
    end
    S.news:Show()
    return S.newsText
end

function S.Tip()
    GameTooltip:SetOwner(UIParent)
    GameTooltip:AddLine(S.T.tip)
    GameTooltip:Show()
end

function S.Say(text) FLT.Msg(text) end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function() S.Build() end)
