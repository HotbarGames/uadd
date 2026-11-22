-- UADD - LootTriage: the game's drop-down menu that its settings window's dropdowns open (Blizzard's Menu API).
-- Its dropdowns build that menu from row.choices() when it opens, so it shows our names (Screen.lua), but the
-- menu is the game's: pooled, used by every menu, and not under its window, so the window walk never fonts it.
-- The same way as UADD_Auctionator/Menu.lua (there is no core helper for menus):
--   * hooksecurefunc on the game's menu manager (Menu.GetManager(): OpenMenu, OpenContextMenu). After a menu
--     opens, only when its owner is inside its window (a forbidden frame stops the climb) and the menu shows
--     our names (Cyrillic), each such text gets our font, read back (Screen.Font, lesson 2).
--   * The menu's FontStrings are never hooked. When the menu hides, each font we set goes back
--     (Screen.Unfont: UADD.FontBack, lesson 18).
--   * The hold key and off: the English name (row.choices() gives the English then) goes back on each text that
--     still shows ours, before its font. A text our font cannot take, or that has no English, closes the menu:
--     never Ukrainian in a font without its letters.
--   * Hooks run under UADD.SafeCall (lesson 19). An off for errors runs Restore through the module's off.
-- Nothing is written into the menu's description or into LootTriage's tables.

local _, ns = ...
local U = UADD
local M = {}
ns.Menu = M

local CYR = "[\208-\210]"
local open = {}            -- menu frame -> { owner = its dropdown, list = { { fs, uk, en } } }
local hookedHide = {}      -- menu frame -> true once its OnHide is hooked
local installed = false

local function Forbidden(f) return type(f) ~= "table" or (f.IsForbidden and f:IsForbidden()) end
local function Fighting() local ok, yes = pcall(InCombatLockdown) return ok and yes == true end

-- Can our font be set now? Read back on a hidden text of ours, then given back (lesson 2). Screen's choices wrap
-- asks it: without it our names would draw as boxes in its dropdown and this menu, so they stay English then.
local probe
function M.CanFont()
    if not probe then
        local ok, fs = pcall(UIParent.CreateFontString, UIParent, nil, "ARTWORK", "GameFontHighlight")
        if not ok or not fs then return false end
        fs:Hide()
        probe = fs
    end
    local ok = ns.Screen.Font(probe)
    ns.Screen.Unfont(probe)
    return ok
end

-- Is the owner a part of its window? (a few parent steps)
local function Inside(o)
    local win = ns.Screen.Window()
    if not win then return false end
    for _ = 1, 12 do
        if Forbidden(o) then return false end
        if o == win then return true end
        o = o.GetParent and o:GetParent()
        if not o then return false end
    end
    return false
end

-- Our name -> its English, from the owner's choices (English while ours are not wanted).
local function English(owner)
    local map = {}
    local row = not Forbidden(owner) and owner.row
    if type(row) ~= "table" or type(row.choices) ~= "function" then return map end
    local ok, list = pcall(row.choices)
    if not ok or type(list) ~= "table" then return map end
    for _, c in ipairs(list) do
        local en = type(c) == "table" and U.Plain(c[2])
        local uk = en and not en:find(CYR) and ns.Words.Translate(en)
        if uk then map[uk] = en end
    end
    return map
end

-- Ours (uk) or the English on each text we hold. True when a text would be left in Ukrainian without our font.
local function Show(r, uk)
    local map = not uk and English(r.owner) or nil
    local left = false
    for _, p in ipairs(r.list) do
        local fs = p.fs
        local t = U.Plain(fs:GetText())
        if uk then
            if p.en and t == p.en then pcall(fs.SetText, fs, p.uk) t = p.uk end
            if t == p.uk and not ns.Screen.Font(fs) then
                if p.en then pcall(fs.SetText, fs, p.en) ns.Screen.Unfont(fs) else left = true end
            end
        else
            p.en = p.en or map[p.uk]
            if t == p.uk and p.en then pcall(fs.SetText, fs, p.en) t = p.en end
            if t == p.uk then left = true else ns.Screen.Unfont(fs) end
        end
    end
    return left
end

-- The menu hid (or is no longer ours): every font we set on it back, and forgotten.
local function Forget(menu)
    local r = open[menu]
    if not r then return end
    open[menu] = nil
    for _, p in ipairs(r.list) do ns.Screen.Unfont(p.fs) end
end

local function Close(menu)
    pcall(menu.Hide, menu)
    Forget(menu)
end

local function Collect(f, out, depth)
    if depth > 6 or Forbidden(f) then return end
    for _, g in ipairs(U.Regions(f)) do
        if g.GetObjectType and g:GetObjectType() == "FontString" and g:IsVisible() then out[#out + 1] = g end
    end
    for _, c in ipairs(U.Children(f)) do
        if not Forbidden(c) and c.IsVisible and c:IsVisible() and not (c.IsObjectType and c:IsObjectType("EditBox")) then
            Collect(c, out, depth + 1)
        end
    end
end

local function Look(menu, owner)
    if Forbidden(menu) or not menu.IsVisible or not menu:IsVisible() or not ns.WordsWanted() then return end
    local r = open[menu]
    if r and r.owner ~= owner then Forget(menu) r = nil end
    r = r or { owner = owner, list = {} }
    local done, list = {}, {}
    for _, p in ipairs(r.list) do done[p.fs] = true end
    Collect(menu, list, 0)
    for _, fs in ipairs(list) do
        local t = not done[fs] and U.Plain(fs:GetText())
        if t and t:find(CYR) then r.list[#r.list + 1] = { fs = fs, uk = t } end
    end
    if not r.list[1] then return end
    open[menu] = r
    if not hookedHide[menu] and menu.HookScript then
        hookedHide[menu] = true
        menu:HookScript("OnHide", function(self) U.SafeCall(Forget, self) end)
    end
    if Show(r, true) then Close(menu) end
end

local function OnOpen(manager, owner)
    if not ns.WordsWanted() or Fighting() or not Inside(owner) then return end
    local menu = manager.GetOpenMenu and manager:GetOpenMenu()
    if not menu then return end
    Look(menu, owner)
    C_Timer.After(0, function() U.SafeCall(Look, menu, owner) end)   -- its rows may be laid out a frame later
end

function M.Install()
    if installed then return end
    local Menu = rawget(_G, "Menu")
    local manager = type(Menu) == "table" and type(Menu.GetManager) == "function" and Menu.GetManager()
    if type(manager) ~= "table" then return end
    installed = true
    for _, name in ipairs({ "OpenMenu", "OpenContextMenu" }) do
        if type(manager[name]) == "function" then
            hooksecurefunc(manager, name, function(self, owner) U.SafeCall(OnOpen, self, owner) end)
        end
    end
end

-- The hold key: English or ours on the open menus.
function M.Sync()
    local uk = ns.WordsWanted()
    for menu, r in pairs(open) do
        if not Forbidden(menu) and menu:IsVisible() then
            local ok, left = U.SafeCall(Show, r, uk)
            if not ok or left then Close(menu) end
        else
            Forget(menu)
        end
    end
end

-- Off (before Screen.Remove): the English and the game's fonts back on the open menus.
function M.Restore()
    for menu, r in pairs(open) do
        local ok, left = U.SafeCall(Show, r, false)
        if not ok or left then Close(menu) else Forget(menu) end
    end
end

-- For the checks: menu texts that show our words in our font now.
function M.Count()
    local n = 0
    for _, r in pairs(open) do
        for _, p in ipairs(r.list) do
            if U.Plain(p.fs:GetText()) == p.uk and U.IsCyrFont((p.fs:GetFont())) then n = n + 1 end
        end
    end
    return n
end
