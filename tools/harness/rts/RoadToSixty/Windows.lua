-- The 4 named windows, the Options canvas, the tab row and a button, built on first open as the addon does.
-- S.OpenMap()      RoadToSixtyJourneyFrame: title, 3 tabs (SetFontObject on click), a UIPanelButtonTemplate button,
--                  S.infoText (per frame, S.Tick(n)), S.Redraw() sets every text again
-- S.Tick(n)        n updates of the info text; returns the last one
-- S.OpenCompare()  RoadToSixtyCompareWindow (a child of a stats view)   S.OpenNews()  RoadToSixtyWhatsNew
-- S.OpenOptions()  shows the Options canvas (S.panel, registered as a Settings category at PLAYER_LOGIN)
-- S.Title(name)    puts a character's name in the map title
local S = RTSStandIn
local T = S.T

local function Label(parent, text, key, font)
    local fs = parent:CreateFontString(nil, "ARTWORK", font or "GameFontNormal")
    S.Put(fs, text, key)
    return fs
end

local function TabOn(tab, on) tab.fs:SetFontObject(on and GameFontHighlight or GameFontNormal) end

function S.OpenMap()
    local f = RoadToSixtyJourneyFrame
    if not f then
        f = CreateFrame("Frame", "RoadToSixtyJourneyFrame", UIParent, "ButtonFrameTemplate")
        f:Hide()
        f:SetSize(600, 400)
        tinsert(UISpecialFrames, "RoadToSixtyJourneyFrame")
        S.title = Label(f, T.title, "title", "GameFontHighlight")
        S.tabs = {}
        for i, key in ipairs({ "tabA", "tabB", "tabC" }) do
            local tab = CreateFrame("Button", nil, f)
            tab:SetSize(84, 22)
            tab.fs = Label(tab, T[key], key)
            tab.fs:SetPoint("CENTER")
            tab:SetScript("OnClick", function() for _, o in ipairs(S.tabs) do TabOn(o, o == tab) end end)
            S.tabs[i] = tab
        end
        S.button = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        S.button:SetSize(80, 22)
        S.Put(S.button, T.button, "button")
        S.button:GetFontString():SetFontObject(GameFontNormal)
        S.infoText = Label(f, "", "info", "GameFontNormalSmall")
        S.Redraw()
    end
    f:Show()
    return f
end

function S.Tick(n)
    S.OpenMap()
    for i = 1, n do S.Put(S.infoText, S.Info(12, "Zorpvale", i .. "m"), "info") end
    return S.infoText:GetText()
end

function S.Redraw()
    S.Put(S.title, T.title, "title")
    for i, key in ipairs({ "tabA", "tabB", "tabC" }) do S.Put(S.tabs[i].fs, T[key], key) end
    S.Put(S.button, T.button, "button")
end

function S.Title(name) S.OpenMap() S.Put(S.title, name .. "'s " .. T.title, "title") end

function S.OpenCompare()
    if not RoadToSixtyCompareWindow then
        local view = CreateFrame("Frame", "RTSStandStatsView", UIParent)
        local win = CreateFrame("Frame", "RoadToSixtyCompareWindow", view, "BackdropTemplate")
        win:SetSize(400, 200)
        Label(win, T.compare, "compare")
    end
    RTSStandStatsView:Show()
    RoadToSixtyCompareWindow:Show()
    return RoadToSixtyCompareWindow
end

function S.OpenNews()
    if not RoadToSixtyWhatsNew then
        local f = CreateFrame("Frame", "RoadToSixtyWhatsNew", UIParent, "BasicFrameTemplateWithInset")
        f:Hide()
        tinsert(UISpecialFrames, "RoadToSixtyWhatsNew")
        Label(f, T.news, "news", "GameFontHighlight")
        Label(f, T.newsHead, "newsHead")
    end
    RoadToSixtyWhatsNew:Show()
    return RoadToSixtyWhatsNew
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
    local panel = CreateFrame("Frame")   -- nameless, as the addon's
    panel:Hide()
    panel.name = T.options
    panel:SetScript("OnShow", function(self)
        if self.built then return end
        self.built = true
        Label(self, T.optHead, "optHead", "GameFontHighlightLarge")
        Label(self, T.optCheck, "optCheck", "GameFontHighlight")
        local b = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
        S.Put(b, T.optButton, "optButton")
    end)
    S.panel = panel
    if Settings and Settings.RegisterCanvasLayoutCategory then
        S.category = Settings.RegisterCanvasLayoutCategory(panel, T.options)
        if Settings.RegisterAddOnCategory then Settings.RegisterAddOnCategory(S.category) end
    end
    local mini = CreateFrame("Button", "RoadToSixtyMinimapButton", Minimap)
    mini:SetSize(31, 31)
    mini:SetScript("OnEnter", function() S.Tip() end)
end)

function S.OpenOptions()
    S.panel:Show()
    return S.panel
end
