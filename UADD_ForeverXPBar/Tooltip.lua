-- Tooltips over ForeverXP Bar's frames (the bar, minimap button, options, race windows): their lines
-- come from AddLine / AddDoubleLine / SetText with the addon's English. While GameTooltip is owned by
-- one of its frames (Screen.RootSet, up the parent chain; or Loose below), each line we know is set
-- to our words when the tooltip shows, gets our font file (UADD/AceFont.lua, that one line only), and
-- the tooltip is laid out again. The hold key puts the English back on a shown tooltip; the font
-- goes back exactly when the tooltip is cleared or hidden. Other tooltips, and ForeverXPBarScanTip (its own
-- scanning tooltip that reads lines back), are never touched. Nothing is changed in combat.

local _, ns = ...
local T = {}
ns.Tooltip = T

local APP = "FXPBTip"
local CYR = "[\208-\210]"
local hooked, guard = false, false
local lines = {}          -- line FontString -> { en = English, uk = ours } on the shown tooltip
local tip                 -- GameTooltip

-- The owner, or one of its parents, is one of ForeverXP Bar's frames.
local function Ours(owner)
    local set, f = ns.Screen.RootSet(), owner
    for _ = 1, 30 do
        if type(f) ~= "table" then return false end
        if set[f] then return true end
        f = f.GetParent and f:GetParent() or nil
    end
    return false
end

-- Since 0.9.1 its reputation strip is a nameless movable frame right on UIParent (not under the
-- bar), and its drag tooltip is owned by it. Such an owner counts only while the tooltip's first line
-- is one of the addon's long texts (Words.Distinct), so other addons' nameless frames stay untouched.
local function Loose(owner)
    if type(owner) ~= "table" or not owner.GetParent or owner:GetParent() ~= rawget(_G, "UIParent") then
        return false
    end
    if owner.GetName and owner:GetName() then return false end
    if not (owner.IsMovable and owner:IsMovable()) then return false end
    local fs = rawget(_G, tip:GetName() .. "TextLeft1")
    return type(fs) == "table" and fs.GetText and ns.Words.Distinct(fs:GetText()) or false
end

local function Layout()
    guard = true
    pcall(tip.Show, tip)
    guard = false
end

local function Each(fn)
    local name = tip:GetName()
    for i = 1, (tip.NumLines and tip:NumLines()) or 0 do
        for _, side in ipairs({ "Left", "Right" }) do
            local fs = rawget(_G, name .. "Text" .. side .. i)
            if type(fs) == "table" and fs.GetText then fn(fs) end
        end
    end
end

-- Our words on every line we know (the tooltip is ForeverXP Bar's and shown).
local function Translate()
    local any = false
    Each(function(fs)
        local t = UADD.Plain(fs:GetText())
        local had = lines[fs]
        if had and t == had.uk then return end
        local en = (had and t == had.en) and had.en or t
        local uk = ns.Words.Text(en)
        if uk then
            fs:SetText(uk)
            lines[fs], any = { en = en, uk = uk }, true
        else
            lines[fs] = nil
        end
        local now = UADD.Plain(fs:GetText())
        if now and now:find(CYR) then UADD.AceFont.Set(fs, APP) end
    end)
    return any
end

local function OnShow(self)
    if guard or not ns.WordsWanted() or (InCombatLockdown and InCombatLockdown()) then return end
    local owner = self.GetOwner and self:GetOwner()
    if not (Ours(owner) or Loose(owner)) then return end
    if Translate() then Layout() end
end

-- Every tooltip line back to its own font; what we put in is forgotten (the lines are reused).
function T.Stop()
    if guard then return end
    wipe(lines)
    UADD.AceFont.Stop(APP)
end

-- The hold key on a shown tooltip: English back (show) or our words again.
function T.Sync(show)
    if not tip or not tip:IsVisible() or next(lines) == nil and show then return end
    if show then
        guard = true
        for fs, l in pairs(lines) do
            if UADD.Plain(fs:GetText()) == l.uk then pcall(fs.SetText, fs, l.en) end
        end
        guard = false
        UADD.AceFont.Stop(APP)
        Layout()
    elseif ns.WordsWanted() and (Ours(tip:GetOwner()) or Loose(tip:GetOwner())) then
        if Translate() then Layout() end
    end
end

function T.Install()
    tip = rawget(_G, "GameTooltip")
    if hooked or type(tip) ~= "table" or not tip.HookScript then return end
    hooked = true
    hooksecurefunc(tip, "Show", function(self) UADD.SafeCall(OnShow, self) end)
    pcall(tip.HookScript, tip, "OnTooltipCleared", T.Stop)
    tip:HookScript("OnHide", T.Stop)
end

-- For the checks: tooltip lines in our words, and in our font, now.
function T.Count()
    local n = 0
    for fs, l in pairs(lines) do if UADD.Plain(fs:GetText()) == l.uk then n = n + 1 end end
    return n, UADD.AceFont.Count(APP)
end
