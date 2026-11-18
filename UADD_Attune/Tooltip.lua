-- Attune's tooltip lines in Ukrainian. Four tooltips:
--   * GameTooltip over Attune's own frames (step boxes, tree rows, buttons, the Next window): when it
--     shows, no item is in it and its owner is inside one of Attune's frames (Screen.Inside), every
--     line Words.lua knows changes.
--   * LibDBIconTooltip, LibDBIcon's own tooltip, over the minimap button LibDBIcon10_Attune_Broker
--     only (other addons' buttons share it).
--   * AttuneGiverTip, the small "Starts at <name>" tooltip next to a quest step. Attune makes it the
--     first time it is needed, then shows GameTooltip right after it; so on each GameTooltip show
--     (and each look of Screen.lua) we check whether it is there yet, hook its Show, and translate it
--     when it is shown. Its owner is the step box, so the same rule applies.
--   * AceConfigDialog's tooltip over Attune's settings pages (read with rawget, owner inside them).
-- Our Show hook runs before Attune measures the tooltip (it reads GetWidth right after Show to size
-- the "Starts at" tip): when a line changed, the hook shows the tooltip once more at once, so the
-- width Attune reads is the one of our words. A changed line gets UADD's Cyrillic font
-- (UADD/AceFont.lua, that one line only); the tooltip is laid out again one frame later. Fonts go
-- back exactly when the tooltip is cleared or hides. The hold key puts the English back on a shown
-- tooltip. Nothing in combat. No tooltip method is replaced, no field set.

local _, ns = ...
local T = {}
ns.Tooltip = T

local CYR = "[\208-\210]"
local BROKER = "LibDBIcon10_Attune_Broker"
local hooked, guard = {}, false
local tips = {}            -- tooltip -> { app = AceFont name, lines = { fs -> { en, uk } }, layout = pending }

local function Each(tip, fn)
    local name = tip:GetName()
    if not name then return end
    for i = 1, (tip.NumLines and tip:NumLines()) or 0 do
        for _, side in ipairs({ "Left", "Right" }) do
            local fs = rawget(_G, name .. "Text" .. side .. i)
            if type(fs) == "table" and fs.GetText then fn(fs) end
        end
    end
end

local function Layout(tip)
    local t = tips[tip]
    if t.layout then return end
    t.layout = true
    C_Timer.After(0, function()
        t.layout = false
        if not tip:IsVisible() then return end
        guard = true
        pcall(tip.Show, tip)
        guard = false
    end)
end

local function Put(tip, fs, en, uk)
    local t = tips[tip]
    guard = true
    pcall(fs.SetText, fs, uk)
    guard = false
    t.lines[fs] = { en = en, uk = uk }
    UADD.AceFont.Set(fs, t.app)
end

-- Every line we know.
local function Translate(tip)
    local t, any = tips[tip], false
    Each(tip, function(fs)
        local s = UADD.Plain(fs:GetText())
        local had = t.lines[fs]
        if had and s == had.uk then return end
        local en = (had and s == had.en) and had.en or s
        local uk = type(en) == "string" and not en:find(CYR) and ns.Words.Text(en)
        if uk then Put(tip, fs, en, uk) any = true else t.lines[fs] = nil UADD.Missed("attune", en, fs) end
    end)
    return any
end

-- Over Attune's frames and no item in it.
local function Ours(tip)
    if tip.GetItem and tip:GetItem() then return false end
    local owner = tip.GetOwner and tip:GetOwner()
    if owner ~= nil and owner == rawget(_G, BROKER) then return true end
    return ns.Screen.Inside(owner)
end

local function OnShow(tip)
    if guard or not ns.WordsWanted() or (InCombatLockdown and InCombatLockdown()) then return end
    if Ours(tip) and Translate(tip) then
        guard = true                -- sized to our words now, before Attune reads its width
        pcall(tip.Show, tip)
        guard = false
        Layout(tip)
    end
    if tip == rawget(_G, "GameTooltip") then T.Look() end   -- AttuneGiverTip may be new and shown
end

local function Clear(tip)
    if guard then return end
    local t = tips[tip]
    if not t then return end
    wipe(t.lines)
    UADD.AceFont.Stop(t.app)
end

local function Hook(tip, app)
    if type(tip) ~= "table" or not tip.HookScript or hooked[tip] then return false end
    hooked[tip] = true
    tips[tip] = { app = app, lines = {}, layout = false }
    hooksecurefunc(tip, "Show", function(self) UADD.SafeCall(OnShow, self) end)
    pcall(tip.HookScript, tip, "OnTooltipCleared", function(self) Clear(self) end)
    tip:HookScript("OnHide", function(self) Clear(self) end)
    return true
end

-- The tooltips Attune, LibDBIcon and AceConfigDialog make: hooked once they exist; a shown one now.
function T.Look()
    local giver = rawget(_G, "AttuneGiverTip")
    if Hook(giver, "ATTTip2") and giver:IsVisible() then UADD.SafeCall(OnShow, giver) end
    local dbi = type(LibStub) == "table" and LibStub("LibDBIcon-1.0", true)
    local icon = type(dbi) == "table" and rawget(dbi, "tooltip")
    if Hook(icon, "ATTTip4") and icon:IsVisible() then UADD.SafeCall(OnShow, icon) end
    local acd = type(LibStub) == "table" and LibStub("AceConfigDialog-3.0", true)
    local tip = type(acd) == "table" and rawget(acd, "tooltip")
    if Hook(tip, "ATTTip3") and tip:IsVisible() then UADD.SafeCall(OnShow, tip) end
end

-- Every tooltip line back to its own font; what we put in is forgotten (the lines are reused).
function T.Stop()
    for tip in pairs(tips) do Clear(tip) end
end

-- The hold key on a shown tooltip: English back (show) or our words again.
function T.Sync(show)
    for tip, t in pairs(tips) do
        if tip:IsVisible() then
            if show then
                guard = true
                for fs, l in pairs(t.lines) do
                    if UADD.Plain(fs:GetText()) == l.uk then pcall(fs.SetText, fs, l.en) end
                end
                guard = false
                UADD.AceFont.Stop(t.app)
                Layout(tip)
            elseif ns.WordsWanted() then
                local any = false
                for fs, l in pairs(t.lines) do
                    if UADD.Plain(fs:GetText()) == l.en then Put(tip, fs, l.en, l.uk) any = true end
                end
                if Ours(tip) and Translate(tip) then any = true end
                if any then Layout(tip) end
            end
        end
    end
end

function T.Install()
    Hook(rawget(_G, "GameTooltip"), "ATTTip1")
    T.Look()
end

-- For the checks: tooltip lines in our words, and in our font, now.
function T.Count()
    local n, f = 0, 0
    for _, t in pairs(tips) do
        for fs, l in pairs(t.lines) do if UADD.Plain(fs:GetText()) == l.uk then n = n + 1 end end
        f = f + UADD.AceFont.Count(t.app)
    end
    return n, f
end
