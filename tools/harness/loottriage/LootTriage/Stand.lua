-- Harness stand-in for LootTriage (not LootTriage). It draws what LootTriage draws, in the same shapes: tooltip
-- lines from its own file, chat lines, its nameless settings window (Refresh with no self, pages, news, version, a
-- dropdown's row.choices), the Delete button on the loot window, its What's New dialog and its row in the game's
-- Settings panel. Its English is given at run time by tools/harness/flow_lt.py (LootTriageStandInFeed, read from
-- the installed addon): none of it is here.

local F = LootTriageStandInFeed or { en = {}, win = {}, choices = {}, news = {}, chat = {}, panel = {} }
local function E(k) return F.en[k] end
local S = {}
LootTriageStandIn = S
S.E = E

-- Its tooltip lines: AddLine (or AddDoubleLine for a pair) from this file, as Tooltip.lua and Loot.lua do.
function S.Tip(owner, lines)
    local tip = GameTooltip
    tip:SetOwner(owner, "ANCHOR_NONE")
    for _, l in ipairs(lines) do
        if type(l) == "table" then tip:AddDoubleLine(l[1], l[2]) else tip:AddLine(l, 0.6, 0.8, 1) end
    end
    tip:Show()
    local out = {}
    for i = 1, tip:NumLines() do out[i] = _G["GameTooltipTextLeft" .. i]:GetText() end
    return out
end

-- Its chat lines, as given (its Print puts its prefix on; help lines have none).
function S.Chat() for _, line in ipairs(F.chat) do DEFAULT_CHAT_FRAME:AddMessage(line) end end
function S.Say(line) DEFAULT_CHAT_FRAME:AddMessage(line) end

-- What's New: a nameless dialog, made on first show; each show sizes it after its text.
function S.News()
    local d = S.dialog
    if not d then
        d = CreateFrame("Frame", nil, UIParent)
        d:SetFrameStrata("FULLSCREEN_DIALOG")
        local border = d:CreateTexture()
        border:SetAtlas("UI-DiamondDialogBox-Border")
        d.text = d:CreateFontString()
        S.dialog = d
    end
    d:SetWidth(480)
    d.text:SetWidth(440)
    d.text:SetText(table.concat(F.news, "\n"))
    d:SetHeight(d.text:GetStringHeight() + 73)
    d:Show()
end

-- Its settings window: a nameless child of UIParent.
local win = CreateFrame("Frame", nil, UIParent)
win:Hide()
win.pages, win.labels = {}, {}
local page = CreateFrame("Frame", nil, win)
win.pages[1] = page
for i, k in ipairs(F.win) do win.labels[i] = { fs = page:CreateFontString(), key = k } end
local drop = CreateFrame("Frame", nil, page)
local function Choices()
    local t = {}
    for i, k in ipairs(F.choices) do t[i] = { i, E(k) } end
    return t
end
drop.row = { choices = Choices }
drop.text = drop:CreateFontString()
win.drop, win.sel, S.choices = drop, 2, Choices
-- Its "New" button: the game's word on its own label, the button sized to it, the label's font object set
-- again on hover (as its window file builds it).
local news = CreateFrame("Button", nil, win)
news.label = news:CreateFontString(nil, "ARTWORK", "GameFontNormal")
news.label:SetText(GAMEMENU_NEW_BUTTON)
news:SetWidth(18 + 5 + news.label:GetStringWidth())
news:SetScript("OnEnter", function(self) self.label:SetFontObject(GameFontHighlight) end)
news:SetScript("OnLeave", function(self) self.label:SetFontObject(GameFontNormal) end)
news:SetScript("OnClick", function() S.News() end)
win.news = news
win.version = win:CreateFontString()
win.version:SetText("v0")
function win.Refresh()
    for _, l in ipairs(win.labels) do l.fs:SetText(l.text or E(l.key)) end
    local list = drop.row.choices()
    drop.text:SetText(list[win.sel] and list[win.sel][2])
end
S.win = win

-- The game's menu (Menu.GetManager, as Blizzard_Menu): one pooled frame under UIParent, not under the window, its
-- texts in the game's font object. Its dropdown fills it from row.choices() when it opens (one radio per choice).
local manager, pool = {}, CreateFrame("Frame", nil, UIParent)
pool:Hide()
pool.rows = {}
function manager:OpenMenu(owner, gen)
    pool:Hide()
    local names = {}
    gen(owner, { CreateRadio = function(_, text) names[#names + 1] = text end })
    for i, t in ipairs(names) do
        pool.rows[i] = pool.rows[i] or pool:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        pool.rows[i]:SetText(t)
        pool.rows[i]:Show()
    end
    for i = #names + 1, #pool.rows do pool.rows[i]:Hide() end
    pool.owner = owner
    pool:Show()
    return pool
end
manager.OpenContextMenu = manager.OpenMenu
function manager:GetOpenMenu() return pool:IsShown() and pool or nil end
if type(rawget(_G, "Menu")) ~= "table" then Menu = {} end
if type(Menu.GetManager) ~= "function" then Menu.GetManager = function() return manager end end
S.menu = pool
function S.OpenDrop()
    Menu.GetManager():OpenMenu(drop, function(_, root)
        for _, c in ipairs(drop.row.choices()) do root:CreateRadio(c[2]) end
    end)
end
function S.CloseDrop() pool:Hide() end

-- The addon renames one label itself, with no Refresh (lesson 23).
function S.Rename(i, text)
    local l = win.labels[i]
    l.text = text
    l.fs:SetText(text)
end

SLASH_LOOTTRIAGE1 = "/lt"
SlashCmdList.LOOTTRIAGE = function(msg)
    if msg == "help" then S.Chat() return end
    win:Show()
    win.Refresh()
end

-- The Delete button on the loot window: a nameless button with the red atlas.
local del = CreateFrame("Button", nil, LootFrame)
local nt = del:CreateTexture()
nt:SetAtlas("128-RedButton-Delete")
del.GetNormalTexture = function() return nt end
S.delete = del

-- Its row in the game's Settings panel, and its "New" button on the panel's Defaults button.
local cat, layout = Settings.RegisterVerticalLayoutCategory("LootTriage")
if layout and layout.AddInitializer and CreateSettingsButtonInitializer and F.panel[1] then
    S.init = CreateSettingsButtonInitializer(E(F.panel[1]), E(F.panel[2]),
        function() SlashCmdList.LOOTTRIAGE("") end, E(F.panel[3]), true)
    layout:AddInitializer(S.init)
end
Settings.RegisterAddOnCategory(cat)
local list = SettingsPanel.Container and SettingsPanel.Container.SettingsList
local defaults = list and list.Header and list.Header.DefaultsButton
if defaults then
    local nb = CreateFrame("Button", nil, defaults)
    nb:SetWidth(96)
    nb:SetText(GAMEMENU_NEW_BUTTON)
    if nb.GetFontString and nb:GetFontString() then nb:GetFontString():SetFontObject(GameFontNormal) end
    nb:SetScript("OnClick", function() S.News() end)
    S.newButton = nb
end
