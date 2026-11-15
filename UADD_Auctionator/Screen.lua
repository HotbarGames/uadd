-- Finds Auctionator's FontStrings and hands them to Texts.lua (hook once, then our words).
-- The roots, all by name (no walk over every frame of the game):
--   * its four auction house tabs (Shopping, Info, Cancelling, Selling) and their tab buttons,
--     the buy panels, the shopping dialogs (add item, export, import, history, the two copy-text
--     dialogs: nameless, read with rawget), its own dialogs AuctionatorDialog1..N, its ten pages in
--     the game's Settings window, and the crafting search frames (when Forever has them);
--   * the auction house title: only Auctionator's four tab headers change there (Texts.Hook "only").
-- Never entered: edit boxes (what the player types), secure frames, and three lists whose text
-- Auctionator reads back or that hold the player's own words: the export list's check boxes, the
-- shopping lists and the recent searches.
-- When we look: a root shows (OnShow, now and again one frame later, when Auctionator has filled
-- it), and after the auction house sends new results (at most every RESULTS_GAP seconds, shown
-- roots only): pooled result rows get hooked then. Once hooked, each FontString's SetText swaps
-- the words itself. Its dialogs: a post-hook (hooksecurefunc) on each Auctionator.Dialogs.Show*
-- function puts our words on a new AuctionatorDialogN as it first shows (without them: a cheap check
-- every DIALOG_GAP while the auction house is open). In combat only a cheap look (Texts.lua); a full
-- look waits until it ends.

local _, ns = ...
local U = UADD
local S = {}
ns.Screen = S
if type(UADD) == "table" then UADD.AuctionatorScreen = S end   -- for the checks (tools/harness)

local RESULTS_GAP, DIALOG_GAP, MAX_DIALOGS = 0.5, 0.5, 50
local AH = { "AuctionatorShoppingFrame", "AuctionatorSellingFrame", "AuctionatorCancellingFrame",
    "AuctionatorConfigFrame", "AuctionatorBuyItemFrame", "AuctionatorBuyCommodityFrame",
    "AuctionatorShoppingTabItemFrame", "AuctionatorExportListFrame", "AuctionatorImportListFrame",
    "AuctionatorItemHistoryFrame", "AuctionatorTabs_Shopping", "AuctionatorTabs_Auctionator",
    "AuctionatorTabs_Cancelling", "AuctionatorTabs_Selling" }
local OTHER = { "AuctionatorTradeSkillSearch", "AuctionatorCraftingInfoProfessionsFrame",
    "AuctionatorCraftingInfoProfessionsOrderFrame", "AuctionatorCraftingInfoObjectiveTrackerFrame" }
local PANELS = { "BasicOptions", "Tooltips", "ShoppingAlt", "Selling", "SellingShortcuts",
    "SellingAllItems", "Quantities", "Cancelling", "Profile", "Advanced" }
local FIELDS = { { "AuctionatorShoppingFrame", "exportCSVDialog" }, { "AuctionatorExportListFrame", "copyTextDialog" } }
local NOT = { { "AuctionatorExportListFrame", "ScrollBox" }, { "AuctionatorShoppingFrame", "ListsContainer", "ScrollBox" },
    { "AuctionatorShoppingFrame", "RecentsContainer", "ScrollBox" } }
local TABS = { "AuctionatorTabs_Shopping", "AuctionatorTabs_Auctionator", "AuctionatorTabs_Cancelling", "AuctionatorTabs_Selling" }
local HEADERS = { "SHOPPING_TAB_HEADER_2", "INFO_TAB_HEADER", "SELLING_TAB_HEADER", "CANCELLING_TAB_HEADER" }
-- Buttons that take the width of their text (UIPanelDynamicResizeButtonTemplate), by their key.
local GROW = { ScanButton = true, OptionsButton = true, CancelNextButton = true, StartScanButton = true,
    Export = true, SelectAll = true, UnselectAll = true, Close = true, Import = true, Finished = true,
    SearchButton = true, acceptButton = true, cancelButton = true, altButton = true }

local roots, rootSet, ahSet, skip, seen, hookedRoot = {}, {}, {}, {}, {}, {}
local grow, tabs = {}, {}            -- buttons to size to their text again, tab buttons
local dialogs, titleHooked = 0, false
local pending, dialogTicker, dialogHooks = false, nil, false
local SHOW = { "ShowEditBox", "ShowConfirm", "ShowConfirmAlt", "ShowMoney" }   -- Auctionator.Dialogs

local function Visible(f) return type(f) == "table" and f.IsVisible and f:IsVisible() or false end

-- In combat only known texts change (Texts.lua's cheap look); the rest waits until combat ends.
local waiter = CreateFrame("Frame")
waiter:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    if not ns.On() then return S.Restore() end
    U.SafeCall(ns.Texts.Sync)
    U.SafeCall(ns.Tooltip.Sync, not ns.WordsWanted())
    U.SafeCall(ns.Popup.Sync)
    U.SafeCall(ns.Menu.Sync)
    U.SafeCall(S.Scan)
end)

function S.WaitCombat()
    if not (InCombatLockdown and InCombatLockdown()) then return false end
    waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
    return true
end

-- A frame by a path of names: the global, then fields (rawget: never Auctionator's metatables).
local function Path(p)
    local f = rawget(_G, p[1])
    for i = 2, #p do
        if type(f) ~= "table" then return nil end
        f = rawget(f, p[i])
    end
    return type(f) == "table" and f or nil
end

-- The auction house title: Auctionator's four headers only (the game's own title stays).
local function HookTitle()
    if titleHooked then return end
    local ah = rawget(_G, "AuctionHouseFrame")
    if type(ah) ~= "table" then return end
    local fs = ah.GetTitleText and ah:GetTitleText()
    if not fs then
        local c = rawget(ah, "TitleContainer")
        fs = type(c) == "table" and rawget(c, "TitleText") or nil
    end
    if type(fs) ~= "table" or not fs.SetText then return end
    local set = {}
    for _, key in ipairs(HEADERS) do
        local en = ns.Words.English(key)
        if en then set[en] = true end
    end
    titleHooked = true
    ns.Texts.Hook(fs, set)
    if fs:IsVisible() then ns.Texts.Apply(fs) end
end

local OnRoot

local function Collect()
    wipe(roots) wipe(rootSet) wipe(ahSet) wipe(skip)
    local new = false                  -- a root never seen before: Rows.lua asks its outside cells again
    local function Add(f, ah)
        if type(f) ~= "table" or rootSet[f] then return end
        roots[#roots + 1], rootSet[f] = f, true
        if ah then ahSet[f] = true end
        if not hookedRoot[f] then
            hookedRoot[f], new = true, true
            if f.HookScript then f:HookScript("OnShow", OnRoot) end
        end
    end
    for _, name in ipairs(AH) do Add(rawget(_G, name), true) end
    for _, p in ipairs(FIELDS) do Add(Path(p), true) end
    for i = 1, MAX_DIALOGS do
        local d = rawget(_G, "AuctionatorDialog" .. i)
        if type(d) ~= "table" then break end
        dialogs = math.max(dialogs, i)
        Add(d, true)
    end
    for _, name in ipairs(OTHER) do Add(rawget(_G, name), false) end
    for _, name in ipairs(PANELS) do Add(rawget(_G, "AuctionatorConfig" .. name .. "Frame"), false) end
    for _, p in ipairs(NOT) do
        local f = Path(p)
        if f then skip[f] = true end
    end
    wipe(tabs)
    for _, name in ipairs(TABS) do
        local t = rawget(_G, name)
        if type(t) == "table" then tabs[t] = true end
    end
    HookTitle()
    if new then ns.Rows.Forget() end
end

-- The set of root frames (Tooltip.lua and Menu.lua: is an owner one of Auctionator's frames?).
function S.RootSet()
    if next(rootSet) == nil then Collect() end
    return rootSet
end

-- f, or a frame it is inside, is one of the roots.
function S.Inside(f)
    local set = S.RootSet()
    for _ = 1, 30 do
        if type(f) ~= "table" then return false end
        if set[f] then return true end
        f = f.GetParent and f:GetParent() or nil
    end
    return false
end

local function Skipped(f)
    if skip[f] then return true end
    if f.IsProtected and f:IsProtected() then return true end
    if f.IsObjectType and f:IsObjectType("EditBox") then return true end
    return false
end

-- A shown root and everything in it, hidden frames too (a dialog inside a window sets its text and
-- then shows: its FontString must be hooked by then). Our words go on the shown texts now.
local function Walk(f, parent)
    if seen[f] or (not parent and not Visible(f)) then return end
    seen[f] = true
    if Skipped(f) then return end
    if parent then
        for key in pairs(GROW) do
            if rawget(parent, key) == f then grow[f] = true break end
        end
    end
    if f.GetRegions then
        for _, g in ipairs({ f:GetRegions() }) do
            if g.GetObjectType and g:GetObjectType() == "FontString" then
                ns.Texts.Hook(g)                       -- hidden ones too: their next SetText is caught
                if g:IsVisible() then ns.Texts.Apply(g) end
            end
        end
    end
    if f.GetChildren then
        for _, c in ipairs({ f:GetChildren() }) do Walk(c, f) end
    end
end

-- Buttons and tabs as wide as their text now (Ukrainian or English), as Auctionator sizes them.
function S.Resize()
    for b in pairs(grow) do
        if b:IsVisible() and type(DynamicResizeButton_Resize) == "function" then pcall(DynamicResizeButton_Resize, b) end
    end
    if type(PanelTemplates_TabResize) ~= "function" then return end
    local small = false
    pcall(function() small = Auctionator.Config.Get(Auctionator.Config.Options.SMALL_TABS) and true end)
    if small then return end                    -- Auctionator gives them one width itself
    for t in pairs(tabs) do
        if t:IsVisible() then pcall(PanelTemplates_TabResize, t, 20, nil, 70) end   -- as LibAHTab makes them
    end
end

local function WalkRoots(ahOnly)
    wipe(seen)
    local ok, err = pcall(function()
        for _, f in ipairs(roots) do
            if not ahOnly or ahSet[f] then Walk(f) end
        end
    end)
    wipe(seen)
    if not ok then error(err, 0) end
    S.Resize()
end

-- Runs now: our words on every shown text of the shown roots. ahOnly: the auction house ones only.
function S.Scan(ahOnly)
    if not ns.On() or S.WaitCombat() then return end
    Collect()
    WalkRoots(ahOnly)
end

local function WalkOne(f)
    if not ns.On() or (InCombatLockdown and InCombatLockdown()) or not rootSet[f] then return end
    wipe(seen)
    U.SafeCall(Walk, f)
    wipe(seen)
    S.Resize()
end

-- A window shows: new texts hooked and put right, and once more one frame later (Auctionator fills
-- some of them in its own OnShow).
OnRoot = function(f)
    if not ns.On() or (InCombatLockdown and InCombatLockdown()) then return end
    WalkOne(f)
    C_Timer.After(0, function() WalkOne(f) end)
end

-- New results in the auction house: one look at the shown tabs, RESULTS_GAP seconds later.
function S.Results()
    if pending or not ns.On() then return end
    pending = true
    C_Timer.After(RESULTS_GAP, function()
        pending = false
        U.SafeCall(S.Scan, true)
    end)
end

-- A new AuctionatorDialogN (made when first needed): hooked, and our words on it if it shows.
-- After each Auctionator.Dialogs.Show* call (the dialog shows with its text set), else on the ticker.
local function NewDialog()
    if not ns.On() or S.WaitCombat() then return end
    if dialogs >= MAX_DIALOGS or type(rawget(_G, "AuctionatorDialog" .. (dialogs + 1))) ~= "table" then return end
    Collect()
    for i = 1, dialogs do
        local d = rawget(_G, "AuctionatorDialog" .. i)
        if d and d:IsVisible() and not ns.Texts.Hooked(rawget(d, "text") or d) then WalkOne(d) end
    end
end

-- The auction house opens or closes (Module.lua's events).
function S.AuctionHouse(open)
    if dialogTicker then dialogTicker:Cancel() dialogTicker = nil end
    if not open or not ns.On() then return end
    if not dialogHooks then dialogTicker = C_Timer.NewTicker(DIALOG_GAP, function() U.SafeCall(NewDialog) end) end
    C_Timer.After(0, function() U.SafeCall(S.Scan, true) end)
    C_Timer.After(0.5, function() U.SafeCall(S.Scan, true) end)
end

-- Once Auctionator is loaded and the module is on.
function S.Install()
    Collect()
    local A = rawget(_G, "Auctionator")
    local D = type(A) == "table" and rawget(A, "Dialogs") or nil
    if dialogHooks or type(D) ~= "table" then return end
    for _, name in ipairs(SHOW) do
        if type(rawget(D, name)) == "function" then
            dialogHooks = true
            hooksecurefunc(D, name, function() U.SafeCall(NewDialog) end)
        end
    end
end

-- Every text and font back as Auctionator had it (module off).
function S.Restore()
    U.SafeCall(ns.Texts.Restore)
    U.SafeCall(ns.Popup.Restore)
    U.SafeCall(ns.Menu.Restore)
    U.SafeCall(ns.Fonts.Restore)
    U.SafeCall(ns.Tooltip.Sync, true)
    U.SafeCall(ns.Tooltip.Stop)
    U.SafeCall(S.Resize)
end

function S.Stop()
    if dialogTicker then dialogTicker:Cancel() dialogTicker = nil end
end

-- For the checks: the roots found so far; true when the dialog functions are hooked.
function S.Roots() return roots end
function S.DialogHooks() return dialogHooks end
