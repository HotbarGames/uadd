-- Tooltips over OpenMap's windows: about 75 of their lines come from L (Locale.lua), so they show
-- our words. GameTooltip draws them with the client's standard fonts, which have no "і", "ї",
-- "є", "ґ" on an English client, and UALLF changes only the quest fonts, not the tooltip's.
-- So while GameTooltip is owned by one of OpenMap's frames (or the World Map), each of its lines
-- that shows Cyrillic gets our font file on that one FontString (UADD/AceFont.lua), and the old
-- font goes back exactly when the tooltip is cleared or hidden. The shared font objects are never
-- changed. Nothing is changed in combat; nothing runs per frame (only on the tooltip's Show).
-- A line OpenMap built from its own English and our words gets the rest in Ukrainian when it is
-- only that and values ("Level 25  (від 20)": Words.Line), or our words and a zone name UALL saved
-- ("Куди: Orgrimmar": Parts.lua), so it is never half English.
-- A pin's note is the player's own text (maybe another player's): a line that is the note of the
-- pin the tooltip is over (its data, not its shape) is never changed, only drawn in our font.

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

-- The note of the pin the owner shows (OpenMap: a map pin's .data, a pin list row's .pin), or nil.
local function Note(owner)
    local pin = type(owner) == "table" and (rawget(owner, "data") or rawget(owner, "pin"))
    local n = type(pin) == "table" and rawget(pin, "note")
    return type(n) == "string" and n ~= "" and n or nil
end

local function OnShow(tip)
    if not ns.On() or (InCombatLockdown and InCombatLockdown()) then return end
    local owner = tip.GetOwner and tip:GetOwner()
    if not Ours(owner) then return end
    local note, name = Note(owner), tip:GetName()
    for i = 1, (tip.NumLines and tip:NumLines()) or 0 do
        for _, side in ipairs({ "Left", "Right" }) do
            local fs = rawget(_G, name .. "Text" .. side .. i)
            local t = type(fs) == "table" and fs.GetText and UADD.Plain(fs:GetText())
            local mine = note and (t == note or t == UADD.Plain(note))   -- the player's: as written
            if type(t) == "string" and t:find(CYR) then
                local uk = not mine and (ns.Words.Line(t)   -- "Level 25  (від 20)": English around L
                    or not ns.Words.Whole(t) and ns.Words.English(t))   -- "Куди: Nowhere": all English
                if uk and uk ~= t then fs:SetText(uk) end
                UADD.AceFont.Set(fs, APP)
            end
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
