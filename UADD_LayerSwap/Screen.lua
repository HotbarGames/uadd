-- Finds LayerSwap's FontStrings and buttons and hands them to Texts.lua (hook once, then our words).
-- The roots are its named frames (NAMED): the panel, the small bar and its logo button, the layer
-- menu, the settings menu and the options window (its page in the game's Settings window). Its
-- minimap button (TIPS) only counts as a tooltip owner: it has no text of its own.
-- LayerSwap makes some frames late (the menus and their rows when first opened, the panel's rows as
-- layers are seen). Three ways catch them:
--   * a hook on CreateFrame: a frame named LayerSwap..., or made inside one of its frames, means a
--     look on the next frame (C_Timer.After(0)), after LayerSwap has set its text. The hook runs on
--     every frame the game makes, so it is cheap: the name first, then the parent (each parent looked
--     up once, kept in a weak table). A new frame with LayerSwap in its name (its minimap button too)
--     also marks the root set for a fresh look (S.RootSet);
--   * OnShow of each root: a look at that window, and texts the hold key skipped while hidden;
--   * every TICK seconds: a look at the shown windows (the panel refreshes itself every second).
-- Once hooked, each FontString's and button's SetText swaps the words itself, so the per-second
-- texts need no look. In combat only a cheap look (Texts.lua); a full look waits until it ends.
-- Never entered: edit boxes' text, secure frames.

local _, ns = ...
local U = UADD
local S = {}
ns.Screen = S
if type(UADD) == "table" then UADD.LayerSwapScreen = S end   -- for the checks (tools/harness)

local TICK = 1
local NAMED = { "LayerSwapPanel", "LayerSwapMini", "LayerSwapMenu", "LayerSwapSettingsMenu", "LayerSwapOptions" }
local TIPS = { "LibDBIcon10_LayerSwap" }
local OURS = {}
for _, name in ipairs(NAMED) do OURS[name] = true end

local roots, rootSet, seen, hookedRoot = {}, {}, {}, {}
local ticker, soon, createHooked = nil, false, false
local rootsStale = true                                -- a frame with LayerSwap in its name was made
local parentOurs = setmetatable({}, { __mode = "k" })  -- parent frame -> InOurs(parent), looked up once

local function Visible(f) return type(f) == "table" and f.IsVisible and f:IsVisible() or false end

-- In combat only known texts change (Texts.lua's cheap look); the rest waits until combat ends.
local waiter = CreateFrame("Frame")
local function CombatOver(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    if not ns.On() then return S.Restore() end
    U.SafeCall(ns.Texts.Sync)
    U.SafeCall(ns.Tooltip.Sync, U.originalShown)
    U.SafeCall(S.Scan)
end
waiter:SetScript("OnEvent", function(self) U.SafeCall(CombatOver, self) end)

function S.WaitCombat()
    if not (InCombatLockdown and InCombatLockdown()) then return false end
    waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
    return true
end

-- f, or a frame it is inside, is one of LayerSwap's named frames.
local function InOurs(f)
    for _ = 1, 30 do
        if type(f) ~= "table" then return false end
        local name = f.GetName and f:GetName()
        if name and OURS[name] then return true end
        f = f.GetParent and f:GetParent()
    end
    return false
end

local OnRoot

local function Collect()
    rootsStale = false
    wipe(roots) wipe(rootSet)
    for _, name in ipairs(NAMED) do
        local f = rawget(_G, name)
        if type(f) == "table" and not rootSet[f] then
            roots[#roots + 1], rootSet[f] = f, true
            if not hookedRoot[f] and f.HookScript then
                hookedRoot[f] = true
                f:HookScript("OnShow", function(self) U.SafeCall(OnRoot, self) end)
            end
        end
    end
    for _, name in ipairs(TIPS) do
        local f = rawget(_G, name)
        if type(f) == "table" then rootSet[f] = true end   -- tooltips only: never walked
    end
end

-- The set of root frames (Tooltip.lua: is a tooltip's owner one of LayerSwap's frames?). It runs on
-- every tooltip the game shows, so the set is kept: looked up again only after a frame with LayerSwap
-- in its name was made (the menus and the minimap button may come after the last look; OnCreate).
function S.RootSet()
    if rootsStale then Collect() end
    return rootSet
end

local function Walk(f)
    if seen[f] or not Visible(f) then return end
    seen[f] = true
    if f.IsProtected and f:IsProtected() then return end
    local kind = f.GetObjectType and f:GetObjectType()
    if (kind == "Button" or kind == "CheckButton") and f.GetFontString then ns.Texts.HookButton(f) end
    if f.GetRegions then
        for _, g in ipairs({ f:GetRegions() }) do
            if g.GetObjectType and g:GetObjectType() == "FontString" then
                ns.Texts.Hook(g)                       -- hidden ones too: their next SetText is caught
                if g:IsVisible() then ns.Texts.Apply(g) end
            end
        end
    end
    if f.GetChildren then
        for _, c in ipairs({ f:GetChildren() }) do Walk(c) end
    end
end

-- Runs now: our words on every shown text of the shown roots.
function S.Scan()
    if not ns.On() or S.WaitCombat() then return end
    Collect()
    wipe(seen)
    local ok, err = pcall(function()
        for _, f in ipairs(roots) do Walk(f) end
    end)
    wipe(seen)
    if not ok then error(err, 0) end
end

-- A window shows: texts the hold key skipped while hidden are put right at once, new ones hooked.
OnRoot = function(f)
    if not ns.On() or (InCombatLockdown and InCombatLockdown()) then return end
    U.SafeCall(ns.Texts.Flush)
    if rootSet[f] then
        wipe(seen)
        U.SafeCall(Walk, f)
        wipe(seen)
    end
end

-- A look on the next frame (many frames made at once: one look).
local function Soon()
    if soon then return end
    soon = true
    C_Timer.After(0, function()
        soon = false
        if ns.On() and not (InCombatLockdown and InCombatLockdown()) then U.SafeCall(S.Scan) end
    end)
end

local function OnCreate(_, name, parent)
    if type(name) == "string" and name:find("LayerSwap", 1, true) then
        rootsStale = true
        if ns.On() and name:find("^LayerSwap") then Soon() end
        return
    end
    if type(parent) ~= "table" or not ns.On() then return end
    local ours = parentOurs[parent]
    if ours == nil then
        local ok, yes = pcall(InOurs, parent)          -- a table that is no frame: not ours, no error (lesson 35)
        ours = ok and yes == true
        parentOurs[parent] = ours
    end
    if ours then Soon() end
end

local function Tick()
    if not ns.On() or (InCombatLockdown and InCombatLockdown()) then return end
    U.SafeCall(S.Scan)
end

local function SafeTick() U.SafeCall(Tick) end    -- an error of ours never reaches the game

-- Once LayerSwap is loaded and the module is on.
function S.Install()
    if not ns.On() then return end
    if not createHooked and type(CreateFrame) == "function" then
        createHooked = true
        U.OnNewFrame(OnCreate)                    -- one core hook, each call under U.SafeCall (lesson 35)
    end
    if not ticker then ticker = C_Timer.NewTicker(TICK, SafeTick) end
end

-- Every text and font back as LayerSwap had it (module off).
function S.Restore()
    U.SafeCall(ns.Texts.Restore)
    U.SafeCall(ns.Fonts.Restore)
    U.SafeCall(ns.Tooltip.Sync, true)
    U.SafeCall(ns.Tooltip.Stop)
end

function S.Stop()
    if ticker then ticker:Cancel() ticker = nil end
end
