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
--     gets it from the mixin; the hook hooks its FontString and puts our words on it at once.
-- Cost: a cell or header seen before costs one table lookup per fill (the weak table `looked`). A new
-- one: a walk up its parents (Screen.Inside) and one hook per FontString, once. Never a walk over
-- frames. A cell found outside our roots is asked again only after Screen.lua finds a new root
-- (R.Forget): its window may be made after its first cells.

local _, ns = ...
local U = UADD
local R = {}
ns.Rows = R

local looked = setmetatable({}, { __mode = "k" })   -- cell or header -> true: hooked; false: outside our roots
local installed, cells, headers = false, 0, 0

-- A new cell: hook its FontStrings (its own SetText comes right after this hook).
local function OnCell(cell)
    if looked[cell] ~= nil or not ns.On() then return end
    looked[cell] = ns.Screen.Inside(cell)
    if not looked[cell] or not cell.GetRegions then return end
    for _, g in ipairs({ cell:GetRegions() }) do
        if g.GetObjectType and g:GetObjectType() == "FontString" then
            ns.Texts.Hook(g)
            cells = cells + 1
        end
    end
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
        hooksecurefunc(head, "Init", function(self) U.SafeCall(OnHeader, self) end)
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
