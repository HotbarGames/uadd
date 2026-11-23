-- A stand-in for OpenMap in the harness (the real addon is far too big to load here). Written for
-- the checks, not taken from OpenMap: it only has the shape UADD_OpenMap looks for.
--   * OpenMapDungeonView: a child of the World Map's scroll container, with a top bar (place
--     name, floor name, a Back button), a pin number in an outlined font, and a side panel with a
--     title, a level line, tab Buttons (each with .Text) and rows (left and right text).
--   * The card: a child of the World Map with a title, a fold button and a scroll child text.
-- Every text is drawn the way OpenMap draws it: SetFont(STANDARD_TEXT_FONT, size, flags).
-- OpenMapStandIn.Open(d) fills the texts (with the quest titles given) and shows it all. Like
-- OpenMap's Map/Dungeons.lua, it builds them from L and its own English ("Level", a level range in
-- colour), so a line can hold both: our words from L and English around them.

--   * OpenMap.L: its locale table, made as OpenMap's Core.lua makes it (English back when nothing
--     is set). One text a locale file of its own set ("Done"), to check it comes back exactly.
--   * Its map menu (OpenMapMenu: tab names read once at load, rows read from L each time), the
--     News window (OpenMapNews: a MORPHEUS title, a version line, Newer / Older buttons: it stays
--     English, lesson 43) and its page in the game's Settings (made at PLAYER_LOGIN, like OpenMap's Init.lua).

OpenMap = { L = setmetatable({}, { __index = function(_, k) return k end }) }
local L = OpenMap.L
L["Done"] = "Done here"
local TABS = { L["On the map"], L["Look"], L["More"] }   -- read once, as OpenMap's Panel.lua does

local S = {}
OpenMapStandIn = S
S.fontStrings = {}
S.otherStrings = {}   -- the menu's, News' and the Settings page's texts

local function Font(fs, size, flags)
    fs:SetFont(STANDARD_TEXT_FONT, size or 12, flags or "")
    local list = S.building and S.otherStrings or S.fontStrings   -- the dungeon view's texts apart
    list[#list + 1] = fs
    return fs
end

local function Text(parent, size, flags) return Font(parent:CreateFontString(nil, "OVERLAY"), size, flags) end

local function Button(parent, size)
    local b = CreateFrame("Button", nil, parent)
    b.Text = Text(b, size)
    b:SetFontString(b.Text)
    return b
end

S.Text, S.Button = Text, Button   -- for Built.lua

local view, card

local function Build()
    local map = WorldMapFrame
    view = CreateFrame("Frame", "OpenMapDungeonView", map.ScrollContainer)
    local bar = CreateFrame("Frame", nil, view)
    view.where = Text(bar, 12)
    view.floorName = Text(bar, 15)
    view.back = Button(bar, 12)
    view.credit = Text(view, 11)
    view.pinNum = Text(view, 11, "OUTLINE")
    view.hint = Text(view, 12)

    local side = CreateFrame("Frame", nil, view)
    view.side = side
    side.title = Text(side, 15)
    side.sub = Text(side, 12)
    side.tabs = {}
    for i, key in ipairs({ "Bosses", "Quests", "Loot", "Floors" }) do
        local b = Button(side, 12)
        b:SetText(L[key])
        b:SetWidth(b.Text:GetStringWidth() + 20)
        side.tabs[i] = b
    end
    side.scroll = CreateFrame("ScrollFrame", nil, side)
    side.child = CreateFrame("Frame", nil, side.scroll)
    side.rows = {}

    card = CreateFrame("Frame", nil, map)
    card.close = CreateFrame("Button", nil, card)
    card.fold = CreateFrame("Button", nil, card)
    card.title = Text(card, 13)
    card.scroll = CreateFrame("ScrollFrame", nil, card)
    card.child = CreateFrame("Frame", nil, card.scroll)
    card.text = Text(card.child, 12)
    S.view, S.card = view, card
end

local function Row(i)
    local row = view.side.rows[i]
    if not row then
        row = CreateFrame("Button", nil, view.side.child)
        row.left = Text(row, 13)
        row.right = Text(row, 13)
        view.side.rows[i] = row
    end
    row:Show()
    return row
end

-- A level range in its colour, as OpenMap's Range() writes it.
local function Range(r) return "|cffff8040" .. r .. "|r" end

-- d = { name, range, zone, boss, also = { name, range } (one more on the card),
--       quests = { { level, title, state = "done" | "log" | nil } } }
function S.Open(d)
    if not view then Build() end
    view.where:SetText(d.name)
    view.floorName:SetText(("|cffffd100%s|r%s"):format(L["Floor %d"]:format(1), ("  |cff998866%d / %d|r"):format(1, 2)))
    view.back:SetText("|cffffd100<|r  " .. L["Back to %s"]:format(d.zone))
    view.back:SetWidth(view.back.Text:GetStringWidth() + 24)
    view.credit:SetText(L["Map by %s"]:format("Someone"))
    view.pinNum:SetText("1")
    view.hint:SetText(L["|cffffd100Right-click|r or |cffffd100Esc|r to go back to the world map"])
    view.side.title:SetText("|cffffd100" .. d.name .. "|r")
    view.side.sub:SetText((LEVEL or "Level") .. " " .. Range(d.range) .. "   |cffbbbbbb" .. L["Raid"] .. "|r")
    Row(1).left:SetText(("|cff998866%d.|r  %s"):format(1, d.boss))
    Row(1).right:SetText("")
    for i, q in ipairs(d.quests or {}) do
        local row = Row(i + 1)
        row.left:SetText(("|cffffff00[%d] %s|r"):format(q.level, q.title))
        row.right:SetText(q.state == "done" and "|cff808080" .. L["done"] .. "|r"
            or q.state == "log" and "|cff80f070" .. L["in your log"] .. "|r" or "")
    end
    local head = { d.name .. "  " .. Range(d.range) }
    if d.also then head[2] = d.also.name .. "  " .. Range(d.also.range) end
    card.title:SetText("|cffffd100" .. table.concat(head, ", ") .. "|r")
    local lines = { "|cffe6c27a" .. L["Bosses"] .. "|r", ("|cff998866%d.|r %s"):format(1, d.boss), " ",
        "|cffe6c27a" .. L["Quests"] .. "|r  |cff998866(Questie)|r" }
    for _, q in ipairs(d.quests or {}) do lines[#lines + 1] = ("|cffffff00[%d] %s|r"):format(q.level, q.title) end
    card.text:SetText(table.concat(lines, "\n"))
    view:Show()
    card:Show()
end

-- OpenMap setting its fonts again (a redraw after a settings change).
function S.Refont()
    for _, fs in ipairs(S.fontStrings) do
        local _, size, flags = fs:GetFont()
        fs:SetFont(STANDARD_TEXT_FONT, size or 12, flags or "")
    end
end

function S.Close()
    if view then view:Hide() end
    if card then card:Hide() end
    if S.menu then S.menu:Hide() end
end

-- The map menu: built once, like OpenMap's Panel.lua (tabs from the load-time names, rows read
-- from L only then), so a menu built while L was ours keeps our words until UADD changes them.
function S.OpenMenu()
    S.building = true
    local m = S.menu
    if not m then
        m = CreateFrame("Frame", "OpenMapMenu", WorldMapFrame)
        m.tabs = {}
        for i, name in ipairs(TABS) do
            local b = Button(m, 12)
            b:SetText(name)
            m.tabs[i] = b
        end
        m.row = Text(m, 12)
        m.count = Text(m, 12)
        m.close = Button(m, 12)
        m.dungeon, m.dungeons = Text(m, 12), Text(m, 12)   -- two keys, one Ukrainian text
        m.row:SetText(L["Open OpenMap's settings"])
        m.count:SetText(L["%d bosses"]:format(3))
        m.close:SetText(L["Done"])
        S.menu = m
    end
    m.dungeon:SetText(L["Dungeon"])
    m.dungeons:SetText(L["Dungeons"])
    S.building = false
    m:Show()
end

-- A tooltip over the menu's Done button, its line read from L (like OpenMap's OnEnter handlers).
function S.Tip()
    local owner = S.menu and S.menu.close
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(L["Done"])
    local fs = _G.GameTooltipTextLeft1   -- OpenMap never sets a tooltip line's font: the game's object
    fs:SetText(L["Done"])
    fs:Show()
    GameTooltip:Show()
end

-- A quest row's tooltip, built like OpenMap's: its English "Level", the level and L["from %d"].
function S.QuestTip(level, req)
    GameTooltip:SetOwner(view.side.rows[1], "ANCHOR_RIGHT")
    local t = (LEVEL or "Level") .. " " .. level .. "  (" .. L["from %d"]:format(req) .. ")"
    GameTooltip:AddLine(t)
    local fs = _G.GameTooltipTextLeft1
    fs:SetText(t)
    fs:Show()
    GameTooltip:Show()
end

-- The News window, like OpenMap's News.lua: the title in MORPHEUS at 28, the rest from L.
-- It stays English, on, held and off (lesson 43): UADD has no Ukrainian for its words.
function S.OpenNews()
    S.building = true
    local f = S.news
    if not f then
        f = CreateFrame("Frame", "OpenMapNews", UIParent)
        f.title = f:CreateFontString(nil, "OVERLAY")
        f.title:SetFont("Fonts\\MORPHEUS.TTF", 28, "")
        f.version = f:CreateFontString(nil, "OVERLAY")
        f.version:SetFont("Fonts\\MORPHEUS.TTF", 20, "")
        f.head = Text(f, 18)
        f.newer, f.older, f.close = Button(f, 12), Button(f, 12), Button(f, 12)
        S.news = f
    end
    f.title:SetText(L["What's new in OpenMap"])
    f.version:SetText("OpenMap 1.2.0")
    f.head:SetText(L["%d versions"]:format(5))
    f.newer:SetText(L["Newer"])
    f.older:SetText(L["Older"])
    f.close:SetText(L["Close"])
    S.building = false
    f:Show()
end

-- At PLAYER_LOGIN: OpenMap's page in the game's Settings (a title and one button).
local login = CreateFrame("Frame")
login:RegisterEvent("PLAYER_LOGIN")
login:SetScript("OnEvent", function()
    S.building = true
    local panel = CreateFrame("Frame")
    panel.title = Text(panel, 16)
    panel.title:SetText("|cff33ccffOpen|rMap")
    panel.button = Button(panel, 12)
    panel.button:SetText(L["Open OpenMap's settings"])
    if Settings and Settings.RegisterCanvasLayoutCategory then
        Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(panel, "OpenMap"))
    end
    local pins = CreateFrame("Frame", "OpenMapPins", UIParent)
    pins.title = Text(pins, 14)
    pins.title:SetText(L["Map pins"])
    pins:Hide()
    S.pins = pins
    S.building = false
    S.panel = panel
end)
