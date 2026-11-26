-- UADD_LiteMount: fonts for our words on LiteMount's panels (the same way as UADD_AutoPotion/Fonts.lua).
--   * Its buttons (UI/PanelTemplate.xml LiteMountUIButtonTemplate: the Profiles page's six buttons, the rule
--     editor's dropdowns) draw their label with a ButtonText that inherits GameFontNormal. In the game that
--     label showed our Ukrainian as boxes (the owner, 2026-11-21), so a FontString of its panels that shows our
--     words gets UADD's Cyrillic font through the core (U.CyrFix, UADD/Font.lua): our font object at the size
--     and with the flags it has now, by hand only with proof (lesson 44). Shared font objects are never changed,
--     and the size is never made smaller.
--   * A button's label: the core gives each of its states' objects our copy and looks at the label again on
--     every state change (UADD/ButtonFont.lua, lesson 46). A button that gets a new label later (its SetText)
--     is hooked here (F.HookButton): ours goes on again.
--   * The change is read back (fs:GetFont): F.Fix says false when no Cyrillic font took, and F.Count counts only
--     the FontStrings in our font now (docs/LESSONS.md, lesson 2). On false, a text that shows Ukrainian gets its
--     English back first, then LiteMount's font (lesson 45): a failed fix is never watched by the box guard.
--   * A Cyrillic font chosen by someone else is left alone.
--   * The English again (the hold key, "/uadd litemount off") puts back what LiteMount had (U.CyrUnfix: its
--     font object, never a file by its path, lesson 18).

local _, ns = ...
local F = {}
ns.Fonts = F

local changed = setmetatable({}, { __mode = "k" })   -- FontString -> U.SaveFont record: its font before ours
local hookedFont = {}     -- FontString or Button -> true once its setters are hooked
local guard = false       -- up while we set a font ourselves

local function HasCyr(p)
    if UADD.IsCyrFont(p) then return true end
    p = type(p) == "string" and p:lower() or ""
    return p:find("_cyr", 1, true) or p:find("arialn", 1, true) or false
end

local function Cyrillic(fs)
    local t = UADD.Plain(fs:GetText())
    return type(t) == "string" and t:find("[\208-\210]") ~= nil
end

local Fix, Fixed

local function OnFont(fs)
    if guard or not changed[fs] or not ns.WordsWanted() then return end
    Fixed(fs, true)
end

-- Our font on fs while it shows Ukrainian. True when it can draw it now (or there is nothing to fix); false: no
-- Cyrillic font took, and its own font is back.
-- `byAddon`: called from a hook, so the font now set is LiteMount's (or the game's) latest choice.
Fix = function(fs, byAddon)
    if not Cyrillic(fs) then return true end                             -- only texts in Ukrainian
    local p = fs:GetFont()
    if not p then return false end
    if HasCyr(p) and not UADD.IsCyrFont(p) then                          -- a Cyrillic font chosen by someone else
        if byAddon then changed[fs] = nil end
        return true
    end
    guard = true
    local ok, took = pcall(UADD.CyrFix, fs, changed)
    guard = false
    if not ok then error(took, 0) end
    if not hookedFont[fs] then
        hookedFont[fs] = true
        hooksecurefunc(fs, "SetFont", OnFont)
        if fs.SetFontObject then hooksecurefunc(fs, "SetFontObject", OnFont) end
    end
    return took == true
end
F.Fix = Fix

-- One FontString's font back (the hold key, or a text that is English again; the caller put the English on).
function F.Back(fs)
    if not changed[fs] then return end
    guard = true
    pcall(UADD.CyrUnfix, fs, changed)
    guard = false
end

-- Fix, and when no Cyrillic font took (or it threw) on a text that shows Ukrainian: its English back first, as
-- LiteMount's own setter puts it (a Falling or counts line: Rows.English; the rest: Screen.English, as the walk
-- sets it), then its font (F.Back). A text whose English we do not know keeps ours (U.FontBack: no box).
Fixed = function(fs, byAddon)
    local ok, took = UADD.SafeCall(Fix, fs, byAddon)
    if ok and took then return true end
    if Cyrillic(fs) then
        for _, m in ipairs({ ns.Rows, ns.Screen }) do
            local put = type(m) == "table" and m.English
            if type(put) == "function" and select(2, pcall(put, fs)) == true then break end
        end
        F.Back(fs)
    end
    return false
end

-- After a text was set: our font while it shows Ukrainian (ours, or another addon's), LiteMount's when English.
-- false: no Cyrillic font took, and the English went back (Fixed).
function F.Settle(fs)
    if type(fs) ~= "table" or type(fs.GetText) ~= "function" or type(fs.GetFont) ~= "function" then return true end
    if Cyrillic(fs) then
        if ns.WordsWanted() or changed[fs] then return Fixed(fs) end
    else
        F.Back(fs)
    end
    return true
end

local function OnButton(b)
    if guard then return end
    local fs = b.GetFontString and b:GetFontString()
    if type(fs) == "table" then
        if ns.WordsWanted() then Fixed(fs, true) else pcall(F.Settle, fs) end
    end
end

-- A button draws its new label without the label's own SetText. Its states' fonts: the core's (ButtonFont.lua).
function F.HookButton(b)
    if type(b) ~= "table" or hookedFont[b] or type(b.GetFontString) ~= "function" then return end
    hookedFont[b] = true
    if b.SetText then hooksecurefunc(b, "SetText", OnButton) end
end

function F.Restore()
    local list = {}
    for fs in pairs(changed) do list[#list + 1] = fs end
    for _, fs in ipairs(list) do F.Back(fs) end
end

-- For the status line and the checks: how many FontStrings carry our font file now (read back).
function F.Count()
    local n = 0
    for fs in pairs(changed) do
        if UADD.IsCyrFont((fs:GetFont())) then n = n + 1 end
    end
    return n
end

-- For the checks: what we remember of one FontString (path, size, flags, font object), or nil.
function F.Original(fs)
    local old = changed[fs]
    if old then return old.path, old.size, old.flags, old.object end
end
