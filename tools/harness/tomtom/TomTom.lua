-- Not TomTom: a small stand-in for tools/harness/flow_tomtom.py. None of its code or words: only the
-- shape UADD_TomTom relies on.
--   * The global TomTom with L (each key is its English; a missing key gives the key) and private, whose
--     settings makers (CreateSettingsPage, CreateUnregisteredSetting, CreateTextInitializer,
--     CreateColorInitializer) BuildSettings calls at login, through private (so a wrapper is seen),
--     with a profile row whose dropdown lists a profile the player named.
--     A page's rows are made when it shows, and each row goes to ScrollUtil.AddInitializedFrameCallback's
--     callbacks (the flow adds that function: the harness lacks it).
--   * TomTomCrazyArrow with status, title and tta; TomTomTooltip (a pin's lines, then the update that
--     writes the distance line again with SetFormattedText); its pop-ups, defined at load from L.
--   * Chat: Printf (name in front, through print) and plain ChatFrame1 lines, from this file's code.
--   * Made late: the paste window TomTomPaste (on first open) and a settings page (S.LatePage).
-- Every English text comes from the flow (TomTomStandInFeed, set before the game starts), read from the
-- installed TomTom at test time.

local feed = TomTomStandInFeed or { L = {}, settings = {}, popups = {}, paste = {}, late = {} }
local S = { pages = {} }
TomTomStandIn = S

local L = setmetatable({}, { __index = function(_, k) return k end })
for _, en in ipairs(feed.L or {}) do rawset(L, en, en) end
local P = {}
local addon = { L = L, private = P }
TomTom = addon

function addon:Printf(msg, ...) print(format("|cFF33FF99%s|r: " .. msg, "TomTom", ...)) end
function S.Printf(en, ...) addon:Printf(L[en], ...) end
function S.Chat(en, ...) ChatFrame1:AddMessage(format(L[en], ...)) end

-- ── Settings ──────────────────────────────────────────────────────────────────────────────────

local function Rows(page)
    if page.rows then return end
    page.rows = {}
    for i, init in ipairs(page.inits) do
        local d = init.data or {}
        local row = CreateFrame("Frame", nil, page)
        local fs = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        local text = d.name or d.text
        if type(d.textFunc) == "function" then text = d.textFunc() end
        fs:SetText(text)
        page.rows[init.role or i] = fs
        if d.buttonText then
            local b = CreateFrame("Button", nil, row)
            b:SetText(d.buttonText)
            page.rows[(init.role or i) .. ":button"] = b:GetFontString()
        end
        for _, c in ipairs(page.List.ScrollBox.__onRow or {}) do c[1](c[2], row, init) end
    end
end

function P.CreateSettingsPage(name, parent)
    local page = CreateFrame("Frame", nil, UIParent)
    page.name, page.parent, page.inits = name, parent, {}
    page.List = { ScrollBox = CreateFrame("Frame", nil, page) }
    function page:AddInitializer(init) self.inits[#self.inits + 1] = init end
    page:SetScript("OnShow", Rows)
    page.category = Settings.RegisterCanvasLayoutCategory(page, name)
    S.pages[#S.pages + 1] = page
    return page
end
function P.CreateUnregisteredSetting(category, variable, varType, name, default)
    return { category = category, variable = variable, varType = varType, name = name, default = default }
end
function P.CreateTextInitializer(data) return { data = data } end
function P.CreateColorInitializer(setting, tooltip) return { data = { name = setting.name, tooltip = tooltip } } end

local function Add(page, role, init) init.role = role page:AddInitializer(init) return init end

function P.BuildSettings()
    local s = feed.settings or {}
    local page = addon.private.CreateSettingsPage(L[s.page], nil)
    local opt = s.option
    local set = addon.private.CreateUnregisteredSetting(page.category, "one", "boolean", L[s.row], true)
    Add(page, "row", { data = { name = set.name, tooltip = L[s.tip],
        options = function() return { { label = opt, text = opt } } end } })
    Add(page, "text", addon.private.CreateTextInitializer({ text = L[s.text] }))
    Add(page, "button", { data = { name = L[s.label], buttonText = L[s.button] } })
    local col = addon.private.CreateUnregisteredSetting(page.category, "two", "table", L[s.color], nil)
    Add(page, "color", addon.private.CreateColorInitializer(col, L[s.colorTip]))
    -- A profile row: its dropdown lists the player's own profile names (one named exactly like a text).
    local prof = addon.private.CreateUnregisteredSetting(page.category, "TOMTOM_PROFILE_OPTIONS", "string",
        L[s.row], nil)
    Add(page, "profile", { data = { setting = prof, name = prof.name,
        options = function() return { { value = opt, label = opt, text = opt } } end } })
    S.page = page
end

-- A page made after login (one TomTom adds when asked), opened through the game's settings window.
function S.LatePage()
    local l = feed.late or {}
    local page = addon.private.CreateSettingsPage(L[l.page], S.page and S.page.category)
    Add(page, "row", { data = { name = L[l.row] } })
    S.late = page
    SettingsPanel:Show()
    SettingsPanel:SelectCategory(page.category)
    return page
end

-- ── The arrow and its tooltip ─────────────────────────────────────────────────────────────────

local arrow = CreateFrame("Button", "TomTomCrazyArrow", UIParent)
arrow.status = arrow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
arrow.title = arrow:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
arrow.tta = arrow:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
arrow:Show()
function S.Status(en, ...) arrow.status:SetText(format(L[en], ...)) end

local tipName = "TomTomTooltip"
local tip = CreateFrame("GameTooltip", tipName, UIParent)
for i = 1, 8 do                                 -- the game makes these with the tooltip
    for _, side in ipairs({ "TextLeft", "TextRight" }) do
        if not rawget(_G, tipName .. side .. i) then tip:CreateFontString(tipName .. side .. i) end
    end
end
tip:Hide()
-- The harness's tooltip only counts lines; the game's writes them into TextLeftN.
function tip:ClearLines()
    self.__n = 0
    for i = 1, 8 do _G[tipName .. "TextLeft" .. i]:SetText(nil) end
end
function tip:NumLines() return self.__n or 0 end
function tip:AddLine(t)
    self.__n = (self.__n or 0) + 1
    _G[tipName .. "TextLeft" .. self.__n]:SetText(t)
end
function tip:SetText(t) self:ClearLines() self:AddLine(t) end
tip.lines = {}
for i = 1, 8 do tip.lines[i] = _G[tipName .. "TextLeft" .. i] end
S.tip = tip

-- A pin's tooltip: its title, the distance, the zone and the place, where it came from.
function S.Pin(title, dist, yards, coords, zone, x, y)
    tip:SetOwner(UIParent, "ANCHOR_NONE")
    tip:SetText(title)
    tip:AddLine(format(L[dist], yards), 1, 1, 1)
    tip:AddLine(format(L[coords], zone, x, y), 0.7, 0.7, 0.7)
    tip:Show()
end
-- The update while the pin stays under the mouse: the distance line written again.
function S.PinUpdate(dist, yards) tip.lines[2]:SetFormattedText(L[dist], yards) end

-- This file's code showing the game's GameTooltip with one L text (the harness's tooltip only counts
-- lines, so the line is written into TextLeft1 too, as the game does).
function S.GameTip(en)
    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    GameTooltip:AddLine(L[en])
    GameTooltipTextLeft1:SetText(L[en])
    GameTooltip:Show()
end

-- ── Pop-ups ───────────────────────────────────────────────────────────────────────────────────

for which, d in pairs(feed.popups or {}) do
    StaticPopupDialogs[which] = { text = d.text and L[d.text], button1 = d.button1 and L[d.button1],
        button2 = d.button2 and L[d.button2], timeout = 30, whileDead = true, hideOnEscape = true }
end

-- ── The paste window, made on first open ──────────────────────────────────────────────────────

function S.OpenPaste()
    local f = rawget(_G, "TomTomPaste")
    if not f then
        f = CreateFrame("Frame", "TomTomPaste", UIParent)
        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.title:SetText(L[(feed.paste or {}).title])
        f.button = CreateFrame("Button", nil, f)
        f.button:SetText(L[(feed.paste or {}).button])
        f.edit = CreateFrame("EditBox", nil, f)
    end
    f:Show()
    S.paste = f
    return f
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function() addon.private.BuildSettings() end)
