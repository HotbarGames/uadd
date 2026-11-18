-- Result rows Auctionator makes after our last look, in Ukrainian on their first draw.
-- Its results tables (Source/Components/ResultsListing) make cells only when a row first scrolls into
-- view. Screen.lua finds cells that exist when it looks; a cell made later would stay English until
-- the next look. So two hooks catch each new cell and column header as it is filled:
--   * Every cell kind (string, price, item, tooltip cells) first calls AuctionatorCellMixin.Populate
--     through the global table, and only then sets its own text. hooksecurefunc on that one function
--     (it puts a wrapper in that field, the same way the game does; nothing else of Auctionator's
--     changes) runs before the cell's SetText: the cell's FontStrings get Texts.lua's hook there, so
--     that very first SetText already shows our words.
--   * Column headers: AuctionatorStringColumnHeaderTemplateMixin:Init sets the header's name with the
--     button's SetText (which does not call the FontString's SetText). A header made after the hook
--     gets it from the mixin; the hook hooks its FontString and puts our words on it at once. A
--     header named before its window was a root (or before this hook) gets our words when
--     Screen.lua's walk meets it (R.Header), shown or hidden.
-- Cost: a cell or header seen before costs one table lookup per fill (the weak table `looked`). A new
-- one: a walk up its parents (Screen.Inside) and one hook per FontString, once. Never a walk over
-- frames. A cell found outside our roots is asked again only after Screen.lua finds a new root
-- (R.Forget): its window may be made after its first cells.
-- Item names: the item column (AuctionatorItemKeyCellTemplate: its Text next to its Icon; Shopping
-- and Cancelling lists) shows the item's name in its quality colour. That FontString asks UALL
-- Forever for the name (UADD.UALL.Item: UADD/uall.lua), the colour and a tail with no letters (an
-- item level " (35)", after the colour or inside it as Forever's Auctionator puts it) kept. No
-- answer, or a tail with letters: the whole text stays English. "Not now" from UALL: English for
-- now, asked again RETRY seconds later (never kept). In combat: names already found only. UALL
-- Forever itself never touches Auctionator's frames, so a name is never translated twice.
-- The same words on two more FontStrings that show one item's name (R.Item, met by Screen.lua's
-- walk): the Selling tab's item (SaleItem.lua: TitleArea.Text) and the buy panel's item
-- (Buying/ItemTooltip.lua: its Text).
-- Bag group titles (Selling tab): AuctionatorGroupsViewGroupMixin:SetName sets a pooled group's
-- title with the button's SetText, so a post-hook on it puts our words on the title's FontString:
-- the game's item class names (Class: ns.UA_CLASS keeps our Ukrainian by the Enum.ItemClass name,
-- the English comes from GetItemClassInfo), else Auctionator's own texts (its Favourites group).
-- A number box's label (Selling tab: "Label" inside the edit box): Screen.lua never enters edit
-- boxes, so it hands the box here (R.BoxLabel); only that FontString changes, never what is typed.

local _, ns = ...
local U = UADD
local R = {}
ns.Rows = R

local looked = setmetatable({}, { __mode = "k" })   -- cell or header -> true: hooked; false: outside our roots
local named = setmetatable({}, { __mode = "k" })    -- a frame whose item name FontString is hooked (R.Item)
local installed, cells, headers, groups, names = false, 0, 0, 0, 0
local CYR = "[\208-\210]"
local RETRY, ITEM_MAX = 1, 2000
local items, itemCount = {}, 0                       -- a cell's item text -> its Ukrainian, or false
local waiting = setmetatable({}, { __mode = "k" })   -- FontStrings UALL said "not now" for
local retrying, availAt, avail = false, -10, false
local headInit                                       -- the header mixin's Init before our hook

-- Is UALL Forever there and on? Asked at most once a second (a row redraw must stay cheap).
local function Available()
    local now = GetTime()
    if now - availAt >= 1 then
        availAt = now
        local A = U.UALL
        local ok, yes = pcall(function() return A and A.IsAvailable and A.IsAvailable() end)
        avail = ok and yes == true
    end
    return avail
end

local Retry
-- The item column's text in Ukrainian, or nil (Texts.lua calls it in place of Words.lua).
local function ItemName(text, fs, combat)
    if type(text) ~= "string" or text == "" then return nil end
    local hit = items[text]
    if hit ~= nil then return hit or nil end
    if combat or not Available() then return nil end
    local c, name, rest = text:match("^(|c%x%x%x%x%x%x%x%x)(.-)|r(.*)$")
    if not c then name, rest = text, "" end
    local base, level = name:match("^(.-)( %(%d+%))$")   -- the item level inside the colour
    if base then name = base else level = "" end
    local uk, wait
    if name ~= "" and not name:find("|", 1, true) and not name:find(CYR) and not rest:find("[%a|\128-\255]") then
        local ok
        ok, uk, wait = pcall(U.UALL.Item, name)
        if not ok then uk, wait = nil, nil end
    end
    if wait then
        waiting[fs] = true
        Retry()
        return nil
    end
    uk = type(uk) == "string" and uk ~= "" and (uk .. level) or nil
    local out = uk and ((c and (c .. uk .. "|r") or uk) .. rest) or false
    if itemCount >= ITEM_MAX then wipe(items) itemCount = 0 end
    items[text], itemCount = out, itemCount + 1
    return out or nil
end

-- UALL said "not now" (a loot window open, Shift held, combat): those names are asked again later.
Retry = function()
    if retrying then return end
    retrying = true
    C_Timer.After(RETRY, function()
        retrying = false
        if not ns.On() then return end
        local list = {}
        for fs in pairs(waiting) do list[#list + 1] = fs end
        wipe(waiting)
        for _, fs in ipairs(list) do
            if fs:IsVisible() then U.SafeCall(ns.Texts.Apply, fs, false, ns.Screen.WaitCombat()) end
        end
    end)
end

-- The item column's FontString: its Text, with an Icon next to it (the string cells have neither).
local function ItemText(cell)
    local t = rawget(cell, "Text")
    return rawget(cell, "Icon") and type(t) == "table" and t or nil
end

-- A new cell: hook its FontStrings (its own SetText comes right after this hook).
local function OnCell(cell)
    if looked[cell] ~= nil or not ns.On() then return end
    looked[cell] = ns.Screen.Inside(cell)
    if not looked[cell] or not cell.GetRegions then return end
    local item = ItemText(cell)
    for _, g in ipairs({ cell:GetRegions() }) do
        if g.GetObjectType and g:GetObjectType() == "FontString" then
            ns.Texts.Hook(g, nil, g == item and ItemName or nil)
            cells = cells + 1
        end
    end
end

-- The game's item class name -> our Ukrainian, made on first use.
local classes
local function Classes()
    if classes then return classes end
    classes = {}
    local IC = type(Enum) == "table" and Enum.ItemClass
    local info = (type(C_Item) == "table" and C_Item.GetItemClassInfo) or rawget(_G, "GetItemClassInfo")
    for name, uk in pairs(type(IC) == "table" and type(info) == "function" and ns.UA_CLASS or {}) do
        local ok, en = pcall(info, IC[name])
        if ok and type(en) == "string" and en ~= "" and type(uk) == "string" and uk ~= "" and uk ~= en then
            classes[en] = uk
        end
    end
    return classes
end

-- A class name as Auctionator shows it ("Name", or "Name2" when two classes share a name), in
-- Ukrainian; nil for any other text. One lookup.
local function Class(t)
    local c = Classes()
    if c[t] then return c[t] end
    local base, n = t:match("^(.-)(%d+)$")
    return base and c[base] and (c[base] .. n) or nil
end

-- A bag group's title: the game's item class name, else one of Auctionator's texts.
local function GroupName(text, fs, combat)
    if type(text) ~= "string" then return nil end
    return Class(text) or (combat and ns.Words.Quick or ns.Words.Text)(text, fs)
end

-- A group was given its name: our words on its title now.
local function OnGroup(group)
    if not ns.On() then return end
    local b = rawget(group, "GroupTitle")
    local fs = type(b) == "table" and (b.GetFontString and b:GetFontString() or b) or nil
    if type(fs) ~= "table" or not (fs.GetObjectType and fs:GetObjectType() == "FontString") then return end
    if looked[group] == nil then
        looked[group] = ns.Screen.Inside(group)
        if not looked[group] then return end
        ns.Texts.Hook(fs, nil, GroupName)
        groups = groups + 1
    elseif not looked[group] then
        return                                     -- a group outside our roots
    end
    ns.Texts.Apply(fs, false, ns.Screen.WaitCombat())
end

-- A header was given its name: our words on it now (and its next names through the hook).
local function OnHeader(header)
    if not ns.On() then return end
    local fs = header.GetFontString and header:GetFontString()
    if type(fs) ~= "table" or not fs.SetText then return end
    local was = looked[header]
    if was == nil then
        looked[header] = ns.Screen.Inside(header)
        if not looked[header] then return end
        ns.Texts.Hook(fs)
        headers = headers + 1
    elseif not was or not ns.Texts.Hooked(fs) then
        return                                     -- a header outside our roots
    end
    ns.Texts.Apply(fs, false, ns.Screen.WaitCombat())
end

-- Screen.lua's walk met f inside a root: when f is a column header, our words on it now, even while
-- it is hidden. A header gets its name once (Init, when its table is built), often before its window
-- is one of our roots or inside a hidden panel (the Selling tab's two history tables): with no later
-- SetText, a hook alone would leave it English when that panel shows.
function R.Header(f)
    if looked[f] or not headInit then return end
    local i = rawget(f, "Init")
    if i == nil or (i ~= headInit and i ~= rawget(AuctionatorStringColumnHeaderTemplateMixin, "Init")) then return end
    local fs = f.GetFontString and f:GetFontString()
    if type(fs) ~= "table" or not fs.SetText then return end
    looked[f] = true
    ns.Texts.Hook(fs)
    headers = headers + 1
    ns.Texts.Apply(fs, false, ns.Screen.WaitCombat())
end

-- Frames that show one item's name, known by their mixin: { mixin, one of its functions (the frame
-- holds that very function), the path from the frame to its FontString }.
local NAMED = { { "AuctionatorSaleItemMixin", "SetItemName", "TitleArea", "Text" },
    { "AuctionatorBuyingItemTooltipMixin", "ReceiveEvent", "Text" } }

-- Screen.lua's walk met f inside a root: when f shows one item's name, that FontString gets the item
-- column's words (hooked here; the walk puts them on it when it meets it, and its next SetText too).
function R.Item(f)
    if named[f] then return end
    for _, n in ipairs(NAMED) do
        local m = rawget(_G, n[1])
        local fn = type(m) == "table" and rawget(m, n[2]) or nil
        if fn ~= nil and rawget(f, n[2]) == fn then
            local g = f
            for i = 3, #n do g = type(g) == "table" and rawget(g, n[i]) or nil end
            if type(g) ~= "table" or not (g.GetObjectType and g:GetObjectType() == "FontString") then return end
            named[f] = true
            ns.Texts.Hook(g, nil, ItemName)
            names = names + 1
            return
        end
    end
end

-- Screen.lua's walk met an edit box f (it never enters one): its own "Label" FontString only gets
-- our words (hooked; shown now if it is shown).
function R.BoxLabel(f)
    if not (f.IsObjectType and f:IsObjectType("EditBox")) or (f.IsProtected and f:IsProtected()) then return end
    local g = rawget(f, "Label")
    if type(g) ~= "table" or not (g.GetObjectType and g:GetObjectType() == "FontString") then return end
    ns.Texts.Hook(g)
    if g:IsVisible() then ns.Texts.Apply(g) end
end

-- Once Auctionator is loaded and the module is on. The hooks stay; while the module is off they
-- return at once.
function R.Install()
    if installed then return end
    local cell = rawget(_G, "AuctionatorCellMixin")
    local head = rawget(_G, "AuctionatorStringColumnHeaderTemplateMixin")
    if type(cell) == "table" and type(rawget(cell, "Populate")) == "function" then
        installed = true
        hooksecurefunc(cell, "Populate", function(self) U.SafeCall(OnCell, self) end)
    end
    if type(head) == "table" and type(rawget(head, "Init")) == "function" then
        installed = true
        headInit = rawget(head, "Init")
        hooksecurefunc(head, "Init", function(self) U.SafeCall(OnHeader, self) end)
    end
    local group = rawget(_G, "AuctionatorGroupsViewGroupMixin")
    if type(group) == "table" and type(rawget(group, "SetName")) == "function" then
        installed = true
        hooksecurefunc(group, "SetName", function(self) U.SafeCall(OnGroup, self) end)
    end
end

-- Screen.lua found a new root: the cells and headers found outside are asked again.
function R.Forget()
    for f, v in pairs(looked) do
        if not v then looked[f] = nil end
    end
end

-- For the checks: FontStrings of new cells and headers hooked here.
function R.Count() return cells, headers end
-- For the checks: bag group titles hooked here.
function R.Groups() return groups end
-- For the checks: one-item name FontStrings hooked here (R.Item).
function R.Names() return names end
