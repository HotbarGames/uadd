-- Not Auctionator: a small stand-in for tools/harness/flow_auc.py. It builds its texts the way
-- Auctionator does (the file each part copies is named next to it):
--   * AUCTIONATOR_L_* globals with the real enUS words (Locales/enUS.lua) and Locales.Apply;
--   * texts given when a frame is made (XML text="..."), a label set in OnLoad from a KeyValue,
--     SetText(AUCTIONATOR_L_X) later, and :format templates;
--   * results lists whose rows and cells are made only when first needed, string cells that call
--     AuctionatorCellMixin.Populate through the global table, column headers with Button:SetText,
--     item cells (the Cancelling list) with the item's coloured name;
--   * chat lines with the coloured "Auctionator: " prefix, "/atr help", a StaticPopup question,
--     tooltip price lines and a column menu (its own dialogs and purchase dialogs: Dialogs.lua;
--     the Selling tab: Selling.lua).
-- Its fonts are its own (StandIn.ttf 13 OUTLINE), not the font UADD puts in, so "off" can be checked.
local S = { texts = {}, lists = {}, headers = {}, cellsMade = 0, setTexts = 0 }
AuctionatorStandIn = S
local FONT = "Interface\\AddOns\\Auctionator\\Fonts\\StandIn.ttf"
S.FONT = FONT

-- ── Locales (Locales/enUS.lua, Source/Locales/Main.lua) ─────────────────────────────────────
local EN = {
    NO_RESULTS = "No results found.", FETCHING_ITEM_INFO = "Fetching item info...",
    TOTAL_ON_SALE = "Total on sale: %s", TOTAL_PENDING = "(%s pending)",
    STACK_AUCTION_INFO = "%s for %s (at %s each)", BUYOUT_AUCTION_INFO = "%s buyout at %s",
    AUCTION = "Auction", AUCTION_AGE = "Auction Age", VENDOR = "Vendor", DISENCHANT = "Disenchant",
    UNKNOWN = "unknown", X_DAYS = "%s days", SEARCH = "Search",
    EXTENDED_SEARCH_ACTIVE_TEXT = "%extended search active%",
    RESULTS_PRICE_COLUMN = "Price", RESULTS_NAME_COLUMN = "Name", UNDERCUT_YES = "Yes", SKIP = "Skip",
    CONFIRM_POST_LOW_PRICE = "The price of %s looks a bit low. Are you sure you want to post at that price?",
    CONFIRM_UNHIDE_ALL = "Are you sure you want to unhide all hidden items?",
    TOTAL_ITEMS_COLORED = "Total |cFFAAAAFF %s items|r", TODAY = "Today",
    ITEM_LEVEL = "Item Level", ITEM_LEVEL_COLUMN = "Item Level",
}
local DAYS = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }
local MONTHS = { "January", "February", "March", "April", "May", "June", "July", "August",
    "September", "October", "November", "December" }
for i, d in ipairs(DAYS) do EN["DAY_" .. i] = d end
for i, m in ipairs(MONTHS) do EN["MONTH_" .. i] = m end
S.EN = EN
for k, v in pairs(EN) do _G["AUCTIONATOR_L_" .. k] = v end

Auctionator = { Locales = {}, Utilities = {}, Dialogs = {},
    Config = { Options = { SMALL_TABS = "small_tabs" }, Get = function() return false end } }
function Auctionator.Locales.Apply(s, ...)
    if EN[s] == nil then error("Unknown/missing locale string '" .. s .. "'") end
    return string.format(EN[s], ...)
end

-- ── Colours, money, messages (Utilities/Message.lua, CreateCountString.lua) ─────────────────
local function Blue(t) return "|cff4cb3ff" .. t .. "|r" end     -- LIGHTBLUE_FONT_COLOR
local function White(t) return "|cffffffff" .. t .. "|r" end    -- WHITE_FONT_COLOR
local function Money(c)                                          -- GetMoneyString(c, true)
    return ("%d|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t %d|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t")
        :format(math.floor(c / 10000), math.floor(c / 100) % 100)
end
S.Money = Money
function Auctionator.Utilities.Message(message) print(Blue("Auctionator: ") .. message) end
function Auctionator.Utilities.CreateCountString(n) return Blue(" x" .. n) end
S.LINK = "|cff1eff00|Hitem:2589::|h[Linen Cloth]|h|r"

-- Selling/Utilities: ComposeAuctionPostedMessage.
function S.Posted(quantity, unit)
    local link = S.LINK
    if quantity > 1 then
        Auctionator.Utilities.Message(Auctionator.Locales.Apply("STACK_AUCTION_INFO",
            link .. Auctionator.Utilities.CreateCountString(quantity), Money(unit * quantity), Money(unit)))
    else
        Auctionator.Utilities.Message(Auctionator.Locales.Apply("BUYOUT_AUCTION_INFO", link, Money(unit)))
    end
end

-- Source/SlashCmd: "/atr help".
local HELP = { { commands = "rt, resettimer", message = "Reset full scan timer." },
    { commands = "h, help", message = "Show this help message." } }
SLASH_AUCTIONATOR1 = "/atr"
SlashCmdList.AUCTIONATOR = function(msg)
    if msg == "help" or msg == "h" then
        for _, h in ipairs(HELP) do Auctionator.Utilities.Message(h.commands .. ": " .. h.message) end
    end
end

-- Utilities/PrettyDate.lua.
function Auctionator.Utilities.PrettyDate(when)
    local details, currentDay = date("*t", when), date("*t", time())
    local weekDay = Auctionator.Locales.Apply("DAY_" .. tostring(details.wday))
    if details.year == currentDay.year and details.month == currentDay.month and details.day == currentDay.day then
        return AUCTIONATOR_L_TODAY
    end
    return weekDay .. ", " .. Auctionator.Locales.Apply("MONTH_" .. tostring(details.month)) .. " " .. details.day
end

-- ── Mixins (Components/ResultsListing/Mixins) ───────────────────────────────────────────────
AuctionatorCellMixin = {}
function AuctionatorCellMixin:Populate(rowData, index)
    self.rowData = rowData
    self.index = index
end
S.origPopulate = AuctionatorCellMixin.Populate

AuctionatorStringCellTemplateMixin = CreateFromMixins(AuctionatorCellMixin)
function AuctionatorStringCellTemplateMixin:Init(columnName)
    self.columnName = columnName
    self.text:SetJustifyH("LEFT")
end
function AuctionatorStringCellTemplateMixin:Populate(rowData, index)
    AuctionatorCellMixin.Populate(self, rowData, index)
    self.text:SetText(rowData[self.columnName])
end

-- The item column (ItemKeyCell.lua): the item's name in its colour, next to its icon.
AuctionatorItemKeyCellTemplateMixin = CreateFromMixins(AuctionatorCellMixin)
function AuctionatorItemKeyCellTemplateMixin:Init() self.Text:SetJustifyH("LEFT") end
function AuctionatorItemKeyCellTemplateMixin:Populate(rowData, index)
    AuctionatorCellMixin.Populate(self, rowData, index)
    self.Text:SetText(rowData.itemName or "")
end

AuctionatorResultsRowTemplateMixin = {}
function AuctionatorResultsRowTemplateMixin:Populate(rowData, dataIndex)
    self.rowData = rowData
    self.dataIndex = dataIndex
end

AuctionatorStringColumnHeaderTemplateMixin = {}
function AuctionatorStringColumnHeaderTemplateMixin:Init(name)
    self:SetText(name)                                   -- the button's SetText, not the FontString's
    local fontString = self:GetFontString()
    fontString:SetJustifyH("LEFT")
    fontString:SetMaxLines(1)
end

-- ── Frames ──────────────────────────────────────────────────────────────────────────────────
local function Text(parent, key, text)
    local fs = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fs:SetFont(FONT, 13, "OUTLINE")
    if text then fs:SetText(text) end                    -- XML text="...": before anything hooks it
    if key then S.texts[key] = fs end
    return fs
end

local function Tab(name)
    local f = CreateFrame("Frame", name, UIParent)
    f:Hide()
    return f
end
S.Text, S.Tab = Text, Tab

-- A column header made from the template (mixin= copies the mixin's fields when it is made).
function S.Header(parent, key, name)
    local h = Mixin(CreateFrame("Button", nil, parent), AuctionatorStringColumnHeaderTemplateMixin)
    h:GetFontString():SetFont(FONT, 13, "OUTLINE")       -- the template's NormalFont
    h:Init(name)
    S.headers[key] = h
    return h
end

-- A results list: rows and their cells are made when a row is first needed (a ScrollBox's pool).
local function List(key, parent, columns)
    local l = CreateFrame("Frame", nil, parent)
    l.columns, l.rows = columns, {}
    l.HeaderContainer = CreateFrame("Frame", nil, l)
    l.ScrollArea = CreateFrame("Frame", nil, l)
    l.status = Text(l, key .. "Status", AUCTIONATOR_L_FETCHING_ITEM_INFO)
    S.lists[key] = l
    return l
end
S.List = List

local function Row(l, i)
    if l.rows[i] then return l.rows[i] end
    local r = Mixin(CreateFrame("Button", nil, l.ScrollArea), AuctionatorResultsRowTemplateMixin)
    r.cells = {}
    for c, column in ipairs(l.columns) do
        local cell
        if column == "item" then                         -- AuctionatorItemKeyCellTemplate
            cell = Mixin(CreateFrame("Frame", nil, r), AuctionatorItemKeyCellTemplateMixin)
            cell.Icon = cell:CreateTexture()
            cell.Text = Text(cell)
            cell:Init()
        else
            cell = Mixin(CreateFrame("Frame", nil, r), AuctionatorStringCellTemplateMixin)
            cell.text = Text(cell)
            cell:Init(column)
        end
        r.cells[c] = cell
        S.cellsMade = S.cellsMade + 1
    end
    l.rows[i] = r
    return r
end

-- New results: each row filled (made first when it is new), the rest hidden.
function S.ShowResults(key, data)
    local l = S.lists[key]
    for i, d in ipairs(data) do
        local r = Row(l, i)
        r:Show()
        r:Populate(d, i)
        for _, cell in ipairs(r.cells) do
            cell:Populate(d, i)
            S.setTexts = S.setTexts + 1
        end
    end
    for i = #data + 1, #l.rows do l.rows[i]:Hide() end
    if #data == 0 then
        l.status:SetText(AUCTIONATOR_L_NO_RESULTS)
        l.status:Show()
    else
        l.status:Hide()
    end
end

-- The Shopping tab: a search button, the search box, a skip label, a results list with headers.
local shop = Tab("AuctionatorShoppingFrame")
shop.SearchButton = CreateFrame("Button", nil, shop)
shop.SearchButton.buttonText = AUCTIONATOR_L_SEARCH                -- KeyValue
shop.SearchButton:GetFontString():SetFont(FONT, 13, "OUTLINE")
function shop.SearchButton:OnLoad() self:SetText(self.buttonText) end
shop.SearchButton:OnLoad()
S.texts.searchButton = shop.SearchButton:GetFontString()
shop.SearchBox = CreateFrame("EditBox", nil, shop)
shop.SearchBox:SetAutoFocus(false)
shop.SearchBox:SetText(AUCTIONATOR_L_EXTENDED_SEARCH_ACTIVE_TEXT)  -- SearchOptions.lua
local skip = CreateFrame("Frame", nil, shop)
skip.labelText = AUCTIONATOR_L_SKIP                                -- KeyValue, set in OnLoad
skip.Label = Text(skip, "skipLabel")
skip.Label:SetText(skip.labelText)
local shopList = List("shop", shop, { "name", "isOwned" })
S.Header(shopList.HeaderContainer, "name", AUCTIONATOR_L_RESULTS_NAME_COLUMN)
S.Header(shopList.HeaderContainer, "ilvl", AUCTIONATOR_L_ITEM_LEVEL)    -- a narrow column
Text(shop, "ilvlRange", AUCTIONATOR_L_ITEM_LEVEL)    -- the same English in a roomy place (Item.xml)

-- The export list: its check boxes are read back, so they must stay English.
local export = Tab("AuctionatorExportListFrame")
Text(export, "exportTitle", AUCTIONATOR_L_SEARCH)
export.ScrollBox = CreateFrame("Frame", nil, export)
local check = CreateFrame("CheckButton", nil, export.ScrollBox)
check.Text = Text(check, "exportCheck", AUCTIONATOR_L_SEARCH)

-- The Cancelling tab: the total line (Cancelling/Mixin.lua).
local cancel = Tab("AuctionatorCancellingFrame")
cancel.Total = Text(cancel, "total", "")
function S.Total(onSale, pending)
    local text = AUCTIONATOR_L_TOTAL_ON_SALE:format(Money(onSale))
    if pending > 0 then text = text .. " " .. AUCTIONATOR_L_TOTAL_PENDING:format(Money(pending)) end
    cancel.Total:SetText(text)
end

-- Its list of the player's auctions: the item column, then the quantity (Cancelling DataProvider).
List("cancel", cancel, { "item", "quantity" })

-- The item history: a list with a date column (PostingHistory/Mixin.lua).
local history = Tab("AuctionatorItemHistoryFrame")
List("history", history, { "date", "price" })

-- What the player reads back from widgets: the search box and the export check box.
function S.ReadBack()
    return shop.SearchBox:GetText() == AUCTIONATOR_L_EXTENDED_SEARCH_ACTIVE_TEXT,
        check.Text:GetText() == AUCTIONATOR_L_SEARCH
end

-- ── A StaticPopup question, tooltip lines, a menu ─────────────────────────────────────────────
StaticPopupDialogs.AUCTIONATOR_SELLING_CONFIRM_POST = { text = "", button1 = ACCEPT, button2 = CANCEL }
function S.ConfirmPost()                                           -- Selling/SaleItem.lua
    StaticPopupDialogs.AUCTIONATOR_SELLING_CONFIRM_POST.text = AUCTIONATOR_L_CONFIRM_POST_LOW_PRICE:format(S.LINK)
    StaticPopup_Show("AUCTIONATOR_SELLING_CONFIRM_POST")
end

-- Tooltips/Main.lua: the price lines under an item (owner: anything, the bag here).
function S.Tooltip(days)
    local count = Auctionator.Utilities.CreateCountString(5)
    GameTooltip:SetOwner(UIParent, "ANCHOR_RIGHT")
    GameTooltip:SetText("Linen Cloth")
    GameTooltip:AddDoubleLine(Auctionator.Locales.Apply("VENDOR") .. count, White(Money(500)))
    GameTooltip:AddDoubleLine(Auctionator.Locales.Apply("AUCTION") .. count, White(AUCTIONATOR_L_UNKNOWN .. "  "))
    GameTooltip:AddDoubleLine(AUCTIONATOR_L_AUCTION_AGE, White(AUCTIONATOR_L_X_DAYS:format(tostring(days or 3))))
    GameTooltip:AddDoubleLine(Auctionator.Locales.Apply("DISENCHANT"), White(Money(1250)))
    GameTooltip:AddDoubleLine(Auctionator.Locales.Apply("TOTAL_ITEMS_COLORED", 7), White(Money(3500)))
    GameTooltip:AddDoubleLine("Vendor Price", White(Money(5)))     -- another addon's line
    GameTooltip:Show()
end

-- The results table's column menu (right-click on a header: MenuUtil.CreateContextMenu).
function S.ColumnMenu()
    Menu.GetManager():OpenContextMenu(S.headers.name, { AUCTIONATOR_L_RESULTS_NAME_COLUMN, AUCTIONATOR_L_RESULTS_PRICE_COLUMN })
end

-- The auction house opens and closes.
S.tabs = { shop, export, cancel, history }                        -- Selling.lua adds its tab
local events = CreateFrame("Frame")
events:RegisterEvent("AUCTION_HOUSE_SHOW")
events:RegisterEvent("AUCTION_HOUSE_CLOSED")
events:SetScript("OnEvent", function(_, event)
    for _, f in ipairs(S.tabs) do
        if event == "AUCTION_HOUSE_SHOW" then f:Show() else f:Hide() end
    end
end)
