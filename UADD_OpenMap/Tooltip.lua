-- Tooltips over OpenMap's windows: about 75 of their lines come from L (Locale.lua), so they show
-- our words. GameTooltip draws them with the client's standard fonts, which have no "і", "ї",
-- "є", "ґ" on an English client, and UALLF changes only the quest fonts, not the tooltip's.
-- So while GameTooltip is owned by one of OpenMap's frames (or the World Map), each of its lines
-- that shows Cyrillic gets our font file on that one FontString (UADD/AceFont.lua), and the old
-- font goes back exactly when the tooltip is cleared or hidden. The shared font objects are never
-- changed. Nothing is changed in combat; nothing runs per frame (only on the tooltip's Show).

local _, ns = ...
local T = {}
ns.Tooltip = T

local APP = "OpenMapTip"
local CYR = "[\208-\210]"   -- the first byte of a Cyrillic letter in UTF-8
local hooked = false

-- The owner, or one of its parents, is one of OpenMap's windows.
local function Ours(owner)
    local set, f = ns.Screen.RootSet(), owner
    for _ = 1, 30 do
        if type(f) ~= "table" then return false end
        if set[f] then return true end
        f = f.GetParent and f:GetParent() or nil
    end
    return false
end

local function OnShow(tip)
    if not ns.On() or (InCombatLockdown and InCombatLockdown()) then return end
    if not (tip.GetOwner and Ours(tip:GetOwner())) then return end
    local name = tip:GetName()
    for i = 1, (tip.NumLines and tip:NumLines()) or 0 do
        for _, side in ipairs({ "Left", "Right" }) do
            local fs = rawget(_G, name .. "Text" .. side .. i)
            local t = type(fs) == "table" and fs.GetText and UADD.Plain(fs:GetText())
            if type(t) == "string" and t:find(CYR) then UADD.AceFont.Set(fs, APP) end
        end
    end
end

-- Every tooltip line back to its own font.
function T.Stop() UADD.AceFont.Stop(APP) end

function T.Install()
    local tip = rawget(_G, "GameTooltip")
    if hooked or type(tip) ~= "table" or not tip.HookScript then return end
    hooked = true
    hooksecurefunc(tip, "Show", function(self) UADD.SafeCall(OnShow, self) end)
    pcall(tip.HookScript, tip, "OnTooltipCleared", T.Stop)
    tip:HookScript("OnHide", T.Stop)
end

-- For the checks: tooltip lines in our font now.
function T.Count() return UADD.AceFont.Count(APP) end
