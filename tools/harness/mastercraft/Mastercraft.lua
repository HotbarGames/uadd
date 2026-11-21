-- Not Mastercraft: a small stand-in for tools/harness/flow_mastercraft.py. None of Mastercraft's code
-- or words: only the shape UADD_Mastercraft relies on.
--   * Font strings like Mastercraft's own: the game's setters kept as mcSetText / mcSetFont, the text it
--     was given in mcRaw (on English it shows that text as it is), its font in mcPath / mcSize / mcFlags,
--     a heading in capitals keeps its text in mcUpper, a button label the button in mcFitTo.
--   * Named windows: MastercraftFrame made at load, MastercraftGoals made later (S.Later).
--   * Tooltip lines and chat lines (its blue name, two spaces) from this file's own code.
-- Every English text comes from the flow (MastercraftStandInFeed, set before the game starts), read
-- from the installed Mastercraft at test time.

local S = { texts = {}, fit = {} }
MastercraftStandIn = S
local PATH = "Fonts\\FRIZQT__.TTF"
S.PREFIX = "|cff4da6ffMastercraft|r  "

local function Text(parent, name, size)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    local set, font = fs.SetText, fs.SetFont
    fs.mcSetText, fs.mcSetFont = set, font
    fs.mcPath, fs.mcSize, fs.mcFlags = PATH, size or 12, ""
    font(fs, PATH, fs.mcSize, "")
    fs.SetText = function(self, t)
        rawset(self, "mcRaw", t)
        return set(self, t)
    end
    fs.SetFont = function(self, p, s, f)
        self.mcPath, self.mcSize, self.mcFlags = p, s, f or ""
        return font(self, p, s, f)
    end
    S.texts[name] = fs
    return fs
end
S.Text = Text

-- One fed text on a font string: as it is, as a heading in capitals, or as a button's label.
local function Put(parent, row)
    local fs = Text(parent, row.name, row.size)
    if row.how == "upper" then
        fs.mcUpper = row.text
        fs:SetText(row.text:upper())
    elseif row.how == "fit" then
        local b = CreateFrame("Button", nil, parent)
        b:SetSize(row.width, 22)
        fs.mcFitTo, fs.mcMinSize = b, row.min
        S.fit[row.name] = b
        fs:SetText(row.text)
    else
        fs:SetText(row.text)
    end
    return fs
end

local feed = rawget(_G, "MastercraftStandInFeed") or {}
local main = CreateFrame("Frame", "MastercraftFrame", UIParent)
main:SetSize(600, 400)
for _, row in ipairs(feed.load or {}) do Put(main, row) end

-- A window made after login: its font strings get their text right after they are made.
function S.Later()
    local f = CreateFrame("Frame", "MastercraftGoals", UIParent)
    for _, row in ipairs(feed.later or {}) do Put(f, row) end
    return f
end

function S.Set(name, text) S.texts[name]:SetText(text) end

-- A leveling guide's step row (its Professions page), made by the flow with S.Text: the recipe's name,
-- a gap (three spaces on the open row, two on a closed one) and its count in grey, one SetText. Rows are
-- reused: a later call puts another step on the same row.
function S.Step(name, title, count, open)
    S.texts[name]:SetText(title .. (open and "   " or "  ") .. ("|cff8a93a6x%d|r"):format(count))
end

-- Like its RawText (text that stays as it is: a player's name, a note): no mc* fields, its own
-- SetText / SetFont wrappers on the string.
local function RawText(parent, size)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    local set, font = fs.SetText, fs.SetFont
    font(fs, PATH, size, "")
    fs.SetFont = function(self, p, s, f) return font(self, p, s, f) end
    fs.SetText = function(self, t) return set(self, t) end
    return fs
end

-- Its Crafters hub, made after login: a profile card (class icon, name, line under it, note) and a tile
-- (big number, two lines, its "nothing here" text in emptyText). S.hub.card / S.hub.tile.
function S.Hub(empty)
    local hub = CreateFrame("Frame", nil, MastercraftFrame)
    local card = CreateFrame("Frame", nil, hub)
    card.cls = card:CreateTexture(nil, "ARTWORK")
    card.name, card.profs, card.note = RawText(card, 14), RawText(card, 11), RawText(card, 10)
    local tile = CreateFrame("Frame", nil, hub)
    tile.num, tile.l1, tile.l2 = RawText(tile, 22), RawText(tile, 11), RawText(tile, 10)
    tile.emptyText = empty
    S.hub = { card = card, tile = tile }
    return S.hub
end

function S.Tip(left, right)
    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    if right then GameTooltip:AddDoubleLine(left, right) else GameTooltip:AddLine(left) end
    GameTooltip:Show()
end

function S.TipAdd(left) GameTooltip:AddLine(left) end    -- its block at the bottom of an item's tooltip

function S.Print(text) DEFAULT_CHAT_FRAME:AddMessage(S.PREFIX .. text) end

-- Its craft orders board and cards (2.0.8), made after login, every cell a RawText, found by its fields:
-- a board row, a recipe found while posting, the post, offer, mine and deal cards, an offer on yours.
-- S.orders.row / sug / post / offer / mine / mrow / deal.
function S.Orders()
    local board = CreateFrame("Frame", nil, MastercraftFrame)
    local function Make(fields, parent)
        local f = CreateFrame("Frame", nil, parent or board)
        for _, k in ipairs(fields) do f[k] = RawText(f, 11) end
        return f
    end
    local row = Make({ "name", "sub", "qty", "mats", "tip", "buyer", "age" })
    row.btn = CreateFrame("Button", nil, row)
    local sug = Make({ "text" })
    sug.dark, sug.edge, sug.hl, sug.icon = sug:CreateTexture(), sug:CreateTexture(), sug:CreateTexture(), sug:CreateTexture()
    local post = Make({ "selName", "selSub", "qtyText" })
    post.sugs = { sug }
    local offer = Make({ "item", "info" })
    offer.price, offer.note = CreateFrame("EditBox", nil, offer), CreateFrame("EditBox", nil, offer)
    for _, b in ipairs({ offer.price, offer.note }) do b:SetAutoFocus(false) b:ClearFocus() end   -- as Mastercraft's
    offer.send, offer.withdraw = CreateFrame("Button", nil, offer), CreateFrame("Button", nil, offer)
    local mrow = Make({ "name", "sub" })
    mrow.bg = mrow:CreateTexture()
    mrow.yes, mrow.no = CreateFrame("Button", nil, mrow), CreateFrame("Button", nil, mrow)
    local mine = Make({ "info", "none" })
    mine.rows, mine.cancel = { mrow }, CreateFrame("Button", nil, mine)
    local deal = Make({ "body" })
    deal.invite, deal.whisper, deal.done = CreateFrame("Button", nil, deal), CreateFrame("Button", nil, deal),
        CreateFrame("Button", nil, deal)
    S.orders = { row = row, sug = sug, post = post, offer = offer, mine = mine, mrow = mrow, deal = deal }
    return S.orders
end

-- Its new-order toast: a named window made the first time an order comes in, one of its own strings.
function S.Toast(text)
    local f = rawget(_G, "MastercraftOrderToast")
    if not f then
        f = CreateFrame("Frame", "MastercraftOrderToast", UIParent)
        f.text = Text(f, "toast", 12)
    end
    f.text:SetText(text)
    f:Show()
    return f
end
