-- Harness stand-in for GearQuest Forever: not the addon. Same globals, font calls and SetText calls as the parts
-- UADD_GearQuestForever touches. Its locale file is the installed addon's own Locales/Locale.lua, run at test time
-- (GearQuestStandInLocale); every English text comes from GearQuestStandInFeed (tools/harness/flow_gq.py). No English
-- of GearQuest here.
-- S.Open()       the main window: labels (calmed by file), tabs, option labels (its locale font), the language box
-- S.Late()       a window made after login, the same way
-- S.Guide(i)     its guide bubble on page i (as its GUIDE:Refresh)
-- S.Orders(list) its Orders page painted with list = { { name, skill, who } } (who: the player's name, as typed)
-- S.NoHunts(slot, preview)   its "no upgrade hunts" chat line for slot ("head" or an unknown one)
-- S.Choices()    its language list, as its Log:LanguageChoices (F.langs: nil = pack addon never seen,
--                "on" = there and on, "off" = there but off); its button and list as Log:CreateLanguageDropdown
local addonName, GQ = ...
_G.GearQuest = GQ
GQ.ADDON_NAME = addonName
local F = GearQuestStandInFeed or { win = {}, tabs = {}, opts = {}, pages = {} }
local S = {}
GearQuestStandIn = S

if GearQuestStandInLocale then
    assert(loadstring(GearQuestStandInLocale, "@AddOns/GearQuestForever/Locales/Locale.lua"))(addonName, GQ)
else
    GQ.L = setmetatable({}, { __index = function(_, k) return k end })
    GQ.LocalePacks = {}
    GQ.ApplyLanguageSetting = function() end
    GQ.LocaleTable = function(t) return t end
end
local L = GQ.L
function GQ:LocalePackSeen() return F.langs ~= nil end
function GQ:LocalePackAvailable() return F.langs == "on" end
function GQ:LoadLocalePack() if F.langs ~= "on" then GQ.ActiveLocale, GQ.LocaleActive = "enUS", false end end

-- Built at load, with the words of that moment (as its Spec, source and slot tables).
GQ.Spec = { CLASS_SPECS = { WARRIOR = { { label = L[F.spec or "?"] } } } }
local SOURCES = GQ.LocaleTable({ vendor = L[F.source or "?"] })
local SLOTS = GQ.LocaleTable({ head = L[F.slot or "?"] })
function GQ:GetSourceTag(kind) return "|cffffcc00" .. (SOURCES[kind] or kind) .. "|r" end

function GQ:Chat(...)
    local s = GearQuestForeverDB and GearQuestForeverDB.settings
    if s and s.hideChat then return end
    print(...)
end

-- Its font helpers: by file, from the face the text has (CalmFont drops the shadow).
function GQ:LocaleFontFace(face) return face end
function GQ:CalmFont(w)
    local face, size = w:GetFont()
    w:SetFont(face, size, "")
    if w.SetShadowOffset then w:SetShadowOffset(0, 0) end
end
function GQ:FitCalmFont(w) self:CalmFont(w) end
function GQ:SetLocaleFont(w, face, size, flags) w:SetFont(self:LocaleFontFace(face), size, flags or "") end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(_, _, name)
    if name ~= addonName then return end
    GearQuestForeverDB = GearQuestForeverDB or {}
    GearQuestForeverDB.settings = GearQuestForeverDB.settings or {}
    GQ.db = GearQuestForeverDB
    if not GQ._languageApplied then
        GQ._languageApplied = true
        GQ.ApplyLanguageSetting(GearQuestForeverDB.settings)
    end
end)

local function Labels(parent, keys, how)
    local out = {}
    for i, key in ipairs(keys) do
        local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetText(L[key])
        if how == "calm" then GQ:CalmFont(fs) elseif how == "fit" then GQ:FitCalmFont(fs, 200, 8)
        else GQ:SetLocaleFont(fs, "Fonts\\FRIZQT__.TTF", 12, "") end
        out[i] = fs
    end
    return out
end

-- ── Its language list (as Log:LanguageChoices and its box) ───────────────────────────────────────
function S.Choices()
    local options = { { value = "enUS", text = "English" } }
    local packs = GQ.LocalePacks or {}
    local seen, available = GQ:LocalePackSeen(), GQ:LocalePackAvailable()
    if available or not seen then
        for i = 1, #packs do options[#options + 1] = { value = packs[i].id, text = packs[i].name } end
    end
    return options
end
local function LangText()
    local id = GQ.ActiveLocale
    if not id or id == "enGB" then id = "enUS" end
    for _, o in ipairs(S.Choices()) do if o.value == id then return o.text end end
    return "English"
end

-- As its Log:CreateLanguageDropdown: only with 2 or more choices, once; a button (its label inherits GameFontNormal)
-- with the language's name, and a list of rows on GameFontHighlight.
GQ.Log = {}
function GQ.Log:CreateLanguageDropdown(frame)
    if frame.settingsLanguageDrop then return frame.settingsLanguageDrop:SetText(LangText()) end
    local options = S.Choices()
    if #options < 2 then return end
    local btn = CreateFrame("Button", "GearQuestLanguageButton", frame.frame)
    btn:SetText(LangText())
    frame.settingsLanguageDrop = btn
    local menu = CreateFrame("Frame", "GearQuestLanguageMenu", UIParent)
    menu.rows = {}
    for i, o in ipairs(options) do
        local row = CreateFrame("Button", nil, menu)
        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.label:SetText(o.text)
        menu.rows[i] = row
    end
    menu:Show()
    frame.settingsLanguageMenu = menu
end

function S.Open()
    local W = S.W
    if not W then
        local f = CreateFrame("Frame", "GearQuestFrame", UIParent)
        W = { frame = f }
        W.labels = Labels(f, F.win, "calm")
        W.opts = Labels(f, F.opts, "locale")
        W.tabs = {}
        for i, key in ipairs(F.tabs) do
            local b = CreateFrame("Button", "GearQuestFrameTab" .. i, f)
            b:SetText(L[key])
            GQ:FitCalmFont(b:GetFontString(), 80, 8)
            W.tabs[i] = b
        end
        S.W = W
    end
    GQ.Log:CreateLanguageDropdown(W)
    W.frame:Show()
    return W
end

function S.Late()
    local f = CreateFrame("Frame", "GearQuestLateFrame", UIParent)
    S.late = Labels(f, F.late or {}, "fit")
    f:Show()
    return S.late
end

-- ── Its guide (as GUIDE:Refresh) ─────────────────────────────────────────────────────────────────
local GUIDE = { page = 1 }
GQ.PortraitGuide = GUIDE
function GUIDE:Refresh()
    local bubble = self.bubble
    if not bubble then return end
    local index = math.max(1, math.min(self.page or 1, #F.pages))
    self.page = index
    local page = F.pages[index]
    bubble.body:SetText(page or "")
    local h = bubble.body:GetStringHeight() or 0
    if h < 20 then h = 84 end
    bubble:SetHeight(h + 40)
end
function S.Guide(i)
    local b = GUIDE.bubble
    if not b then
        b = CreateFrame("Frame", "GearQuestGuideBubble", UIParent)
        b.body = b:CreateFontString(nil, "OVERLAY", "QuestFont")
        b.body:SetWidth(260)
        GQ:CalmFont(b.body)
        GUIDE.bubble = b
    end
    GUIDE.page = i or GUIDE.page
    b:Show()
    GUIDE:Refresh()
    return b
end

-- ── Its Orders page (as Orders:Paint): a header per asker ("asked by <name>", no item id), then its rows ──
local Orders = {}
GQ.Orders = Orders
S.list = {}
function Orders:Paint()
    local page = self.page
    local used, last = 0, nil
    local function Row()
        used = used + 1
        local row = page.rows[used]
        if not row then
            row = CreateFrame("Button", nil, page)
            row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            page.rows[used] = row
        end
        row:Show()
        return row
    end
    for i, d in ipairs(S.list) do
        local who = d[3] or "?"
        if who ~= last then
            last = who
            local header = Row()
            header.itemId = nil
            header.text:SetText(string.format(L[F.asked or "%s"], who))
        end
        local row = Row()
        row.itemId, row.who = 1000 + i, who
        local line = d[1]
        if type(d[2]) == "number" and d[2] > 1 then
            line = d[1] .. "  |cffb0b0b0" .. string.format(L[F.skill or "%d"], d[2]) .. "|r"
        end
        row.text:SetText(line)
    end
    for i = used + 1, #page.rows do page.rows[i]:Hide() end
end
function S.Orders(list)
    if not Orders.page then
        Orders.page = CreateFrame("Frame", "GearQuestOrdersPage", UIParent)
        Orders.page.rows = {}
    end
    S.list = list or S.list
    Orders.page:Show()
    Orders:Paint()
    return Orders.page
end

-- ── Its "no upgrade hunts" line (as its slot popup) ──────────────────────────────────────────────
function S.NoHunts(slot, preview)
    local hint = preview and "" or L[F.hint or ""]
    GQ:Chat("|cff66ccffGearQuest|r: " .. string.format(L[F.none or "%s"], SLOTS[slot] or slot) .. hint)
end
