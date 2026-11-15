-- The game's drop-down and right-click menus (Blizzard's Menu API) that Auctionator opens: its
-- drop-downs in the Settings pages and search options, the results table's column menu, the bag
-- list's group menu. Best effort:
--   * hooksecurefunc on the game's menu manager (Menu.GetManager(): OpenMenu, OpenContextMenu).
--     After a menu opens, and only when its owner is inside one of Auctionator's frames
--     (Screen.Inside) and we are not in combat, each text of the open menu that Words.lua knows is
--     set to our words with a font with Ukrainian letters (that FontString only).
--   * The menu's FontStrings are the game's, pooled and used by every menu, so they are never
--     hooked: we set the text once, and when the menu hides our English goes back on each one we
--     changed (if it still shows ours) and so do the fonts.
--   * Not done: sub-menus that open later, and the menu's width (taken from the English).
--   * The hold key: English or ours on the open menu. "/uadd auctionator off": English back.
-- Nothing is written into the menu's description or into Auctionator's tables.

local _, ns = ...
local U = UADD
local M = {}
ns.Menu = M

local CYR = "[\208-\210]"
local open = {}            -- menu frame -> { { fs, en, uk } }
local hookedHide = {}      -- menu frame -> true once its OnHide is hooked
local installed = false

local function Show(rec, uk)
    for _, p in ipairs(rec) do
        local want, other = uk and p.uk or p.en, uk and p.en or p.uk
        if UADD.Plain(p.fs:GetText()) == other then pcall(p.fs.SetText, p.fs, want) end
        if uk then ns.Fonts.Fix(p.fs) else ns.Fonts.Back(p.fs) end
    end
end

-- The menu's texts as the game left them, and forgotten.
local function Forget(menu)
    local rec = open[menu]
    if not rec then return end
    open[menu] = nil
    Show(rec, false)
end

local function Collect(f, out, depth)
    if depth > 6 then return end
    if f.GetRegions then
        for _, g in ipairs({ f:GetRegions() }) do
            if g.GetObjectType and g:GetObjectType() == "FontString" and g:IsVisible() then out[#out + 1] = g end
        end
    end
    if f.GetChildren then
        for _, c in ipairs({ f:GetChildren() }) do
            if c.IsVisible and c:IsVisible() and not (c.IsObjectType and c:IsObjectType("EditBox")) then
                Collect(c, out, depth + 1)
            end
        end
    end
end

local function Translate(menu)
    if type(menu) ~= "table" or not menu.IsVisible or not menu:IsVisible() then return end
    local rec = open[menu] or {}
    local done = {}
    for _, p in ipairs(rec) do done[p.fs] = true end
    local list = {}
    Collect(menu, list, 0)
    for _, fs in ipairs(list) do
        local en = not done[fs] and UADD.Plain(fs:GetText())
        if type(en) == "string" and not en:find(CYR) then
            local uk = ns.Words.Text(en)
            if uk then rec[#rec + 1] = { fs = fs, en = en, uk = uk } end
        end
    end
    if not rec[1] then return end
    open[menu] = rec
    if not hookedHide[menu] and menu.HookScript then
        hookedHide[menu] = true
        menu:HookScript("OnHide", function(self) U.SafeCall(Forget, self) end)
    end
    Show(rec, true)
end

local function OnOpen(manager, owner)
    if not ns.WordsWanted() or (InCombatLockdown and InCombatLockdown()) then return end
    if not ns.Screen.Inside(owner) then return end
    local menu = manager.GetOpenMenu and manager:GetOpenMenu()
    if not menu then return end
    Translate(menu)
    C_Timer.After(0, function() U.SafeCall(Translate, menu) end)   -- its rows may be laid out a frame later
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
    for menu, rec in pairs(open) do
        if menu:IsVisible() then U.SafeCall(Show, rec, uk) else open[menu] = nil end
    end
end

-- "/uadd auctionator off": English and the fonts back.
function M.Restore()
    for menu in pairs(open) do U.SafeCall(Forget, menu) end
end

-- For the checks: how many menu texts show our words now.
function M.Count()
    local n = 0
    for _, rec in pairs(open) do
        for _, p in ipairs(rec) do if UADD.Plain(p.fs:GetText()) == p.uk then n = n + 1 end end
    end
    return n
end
