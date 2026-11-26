-- Fonts for our words on LayerSwap's frames (the same way as UADD_AutoPotion/Fonts.lua).
--   * Its texts use the game's font objects (GameFontNormal and friends, FRIZQT: Latin letters only). A
--     FontString that shows our words gets UADD's Cyrillic font through the core (U.CyrFix, UADD/Font.lua):
--     our font object at the size and with the flags it has now, by hand only with proof (lesson 44).
--     Shared font objects are never changed.
--   * Its buttons get their font objects again each time their label is set (normal, highlight and disabled),
--     and the smaller ones when the label is too wide. The core gives each state's object our copy at its own
--     size and looks at the label again on every state change (UADD/ButtonFont.lua, lesson 46).
--   * The change is read back (fs:GetFont): F.Fix says false when no Cyrillic font took (the caller puts the
--     English back), and F.Count counts only the FontStrings in our font now (lesson 2).
--   * A Cyrillic font LayerSwap chose itself is left alone.
--   * "/uadd layerswap off" puts back exactly what LayerSwap had (U.CyrUnfix: its font object, never a file
--     by its path, lesson 18).

local _, ns = ...
local F = {}
ns.Fonts = F

local changed = setmetatable({}, { __mode = "k" })   -- FontString -> U.SaveFont record: its font before ours
local hookedFont = {}     -- FontString -> true once its font setters are hooked
local guard = false       -- up while we set a font ourselves

-- A font file with Ukrainian letters.
local function HasCyr(p)
    if UADD.IsCyrFont(p) then return true end
    p = type(p) == "string" and p:lower() or ""
    return p:find("_cyr", 1, true) or p:find("arialn", 1, true) or false
end

local Fix

local function OnFont(fs)
    if guard or not changed[fs] or not ns.WordsWanted() or ns.Screen.WaitCombat() then return end
    local ok, took = UADD.SafeCall(Fix, fs, true)
    if not (ok and took) then UADD.SafeCall(ns.Texts.English, fs) end  -- English first, then its font (lesson 45)
end

-- Our font on fs while it shows Ukrainian. True when it can draw it now (or there is nothing to fix); false: no
-- Cyrillic font took, its own font is back and the caller puts the English back.
-- `byAddon`: called from a hook, so the font now set is LayerSwap's own latest choice.
Fix = function(fs, byAddon)
    local t = UADD.Plain(fs:GetText())
    if type(t) ~= "string" or not t:find("[\208-\210]") then return true end   -- only texts in Ukrainian
    local p = fs:GetFont()
    if not p then return false end
    if HasCyr(p) and not UADD.IsCyrFont(p) then              -- LayerSwap chose a Cyrillic font itself
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

-- One FontString's font back (a text that is English again; the caller put the English on).
function F.Back(fs)
    if not changed[fs] then return end
    guard = true
    pcall(UADD.CyrUnfix, fs, changed)
    guard = false
end

-- Every font we changed back as LayerSwap left it.
function F.Restore()
    local list = {}
    for fs in pairs(changed) do list[#list + 1] = fs end
    for _, fs in ipairs(list) do F.Back(fs) end
end

-- For the status line and the checks: how many FontStrings carry our font file now.
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
