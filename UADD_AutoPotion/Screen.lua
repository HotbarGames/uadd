-- Finds Auto Potion's FontStrings and buttons and hands them to Texts.lua (hook once, then our words).
-- The roots are its six settings pages (NAMED), canvases in the game's Settings window: the Info page
-- and the Heal, Mana Potion, Food, Drink and Bandage pages. Auto Potion builds them at its own
-- ADDON_LOADED (the Heal page's class spell rows at PLAYER_LOGIN), so they are all there by the time
-- a page is opened. A look at a page:
--   * when it shows (OnShow of each root): every FontString inside is hooked, and the shown ones get our
--     words; texts the hold key skipped while hidden are put right (Texts.Flush);
--   * at PLAYER_LOGIN and when the module is turned on (S.Scan), for a page that is open already.
-- Once hooked, each FontString's SetText swaps the words itself. Never entered: edit boxes (the Info
-- page's links), protected frames.
-- S.Refit fits a box to a changed label, the way Auto Potion sized it for its English:
--   * a plain button (the Reset button): width = the label's width + 20, at least 120;
--   * a check box with an icon: its click area reaches past the icon (6 + 28 + 6) and the label. Only
--     a box whose click area still matches the label it had is changed, so other check boxes keep theirs.

local _, ns = ...
local U = UADD
local S = {}
ns.Screen = S
if type(UADD) == "table" then UADD.AutoPotionScreen = S end   -- for the checks (tools/harness)

local TARGET = "AutoPotion"
local NAMED = { TARGET, TARGET .. "Heal", TARGET .. "ManaPotion", TARGET .. "Food", TARGET .. "Drink",
    TARGET .. "Bandage" }
local BUTTON_PAD, BUTTON_MIN = 20, 120   -- Auto Potion's own numbers for its Reset button
local ICON_REACH = 6 * 2 + 28            -- gap, icon, gap: before the label of an icon check box

local roots, rootSet, seen, hookedRoot = {}, {}, {}, {}

local function Visible(f) return type(f) == "table" and f.IsVisible and f:IsVisible() or false end

local OnRoot

local function Collect()
    wipe(roots) wipe(rootSet)
    for _, name in ipairs(NAMED) do
        local f = rawget(_G, name)
        if type(f) == "table" and type(f.GetObjectType) == "function" and not rootSet[f] then
            roots[#roots + 1], rootSet[f] = f, true
            if not hookedRoot[f] and f.HookScript then
                hookedRoot[f] = true
                f:HookScript("OnShow", OnRoot)
            end
        end
    end
end

-- The set of the six pages (Tooltip.lua: is a tooltip's owner inside one of them?).
function S.RootSet()
    if next(rootSet) == nil then Collect() end
    return rootSet
end

local function Walk(f)
    if seen[f] or not Visible(f) then return end
    seen[f] = true
    if f.IsProtected and f:IsProtected() then return end
    local kind = f.GetObjectType and f:GetObjectType()
    if kind == "EditBox" then return end
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

local function Look(f)
    wipe(seen)
    local ok, err = pcall(Walk, f)
    wipe(seen)
    if not ok then error(err, 0) end
end

-- Our words on every shown text of the shown pages.
function S.Scan()
    if not ns.On() then return end
    Collect()
    for _, f in ipairs(roots) do Look(f) end
end

OnRoot = function(f)
    if not ns.On() then return end
    U.SafeCall(ns.Texts.Flush)
    if rootSet[f] then U.SafeCall(Look, f) end
end

function S.Install() Collect() end

-- The box around FontString fs fitted again: `from` is the label width it was fitted to, `to` the
-- width to fit now (our words in our font, or Auto Potion's English in its own font).
function S.Refit(fs, from, to)
    local b = fs.GetParent and fs:GetParent()
    if type(b) ~= "table" or not b.GetObjectType or type(from) ~= "number" or type(to) ~= "number" then return end
    local kind = b:GetObjectType()
    if kind == "Button" and b.GetFontString and b:GetFontString() == fs and b.SetWidth then
        b:SetWidth(math.max(BUTTON_MIN, to + BUTTON_PAD))
    elseif kind == "CheckButton" and b.GetHitRectInsets and b.SetHitRectInsets then
        local l, r, t, bottom = b:GetHitRectInsets()
        if type(r) == "number" and math.abs(r + ICON_REACH + from) < 1.5 then
            b:SetHitRectInsets(l, -(ICON_REACH + to), t, bottom)
        end
    end
end

-- Every text and font back as Auto Potion had it (module off). Fonts first; the boxes are fitted
-- from the widths Texts.lua kept when the words were put, so the order does not change them.
function S.Restore()
    U.SafeCall(ns.Fonts.Restore)
    U.SafeCall(ns.Texts.Restore)
    U.SafeCall(ns.Tooltip.Sync, true)
    U.SafeCall(ns.Tooltip.Stop)
end
