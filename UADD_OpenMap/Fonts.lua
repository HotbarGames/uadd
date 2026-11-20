-- Fonts on OpenMap's windows. Screen.lua finds the texts; this file changes and restores them.
--   * OpenMap draws every text with the client's standard font file, which has no Ukrainian
--     letters, so Ukrainian quest titles (from Questie, through UADD_Questie) showed as squares.
--   * A FontString whose font file has no Ukrainian letters gets UADD's Cyrillic font file, at the
--     size and with the flags (OUTLINE, ...) it has now: fs:SetFont on that one FontString.
--     This does not depend on our words: it is needed for Questie's titles alone.
--   * OpenMap may set a font again (SetFont / SetFontObject), so both are hooked on each FontString
--     we changed (hooksecurefunc, once per FontString) and the Cyrillic file goes back at once. The
--     hooks cannot be removed, so with the module off they do nothing.
--   * "/uadd openmap off" puts back exactly what OpenMap had: the font object, file, size and flags.
--   * The options window is not done here: its widgets are shared with other addons' windows
--     (UADD/AceFont.lua does it).
-- Blizzard's shared font objects are never changed.

local _, ns = ...
local F = {}
ns.Fonts = F

local changed = {}        -- FontString -> its font before ours (UADD.SaveFont, lesson 18)
local hookedFont = {}     -- FontString -> true once its SetFont and SetFontObject are hooked
local guard = false       -- up while we set a font ourselves

local Fix

local function OnFont(fs)
    if guard or not changed[fs] or not ns.On() or ns.Screen.WaitCombat() then return end   -- after combat, a look fixes it
    UADD.SafeCall(Fix, fs, true)
end

-- `byOpenMap`: called from a hook, so the font now set is OpenMap's own latest choice.
Fix = function(fs, byOpenMap)
    local path = UADD.CyrFontPath()
    if not path then return end
    local p, size, flags = fs:GetFont()
    if not p then return end
    if UADD.IsCyrFont(p) then
        if byOpenMap then changed[fs] = nil end    -- OpenMap chose a Cyrillic font itself
        return
    end
    changed[fs] = UADD.SaveFont(fs)
    guard = true
    local ok, err = pcall(fs.SetFont, fs, path, size or 12, flags or "")
    guard = false
    if not ok then error(err, 0) end
    if not hookedFont[fs] then
        hookedFont[fs] = true
        hooksecurefunc(fs, "SetFont", OnFont)
        hooksecurefunc(fs, "SetFontObject", OnFont)
    end
end
F.Fix = Fix

-- One FontString as OpenMap left it (UADD.FontBack): its font object, always, so the family's
-- Cyrillic letters come back; the file, size and flags only when OpenMap had set them by hand.
local Put = UADD.FontBack

-- One FontString back as it was (a StaticPopup's, shared with other addons: Popup.lua).
function F.Back(fs)
    local old = changed[fs]
    if not old then return end
    if UADD.IsCyrFont((fs:GetFont())) then
        guard = true
        pcall(Put, fs, old)
        guard = false
    end
    changed[fs] = nil
end

-- Every font we changed back as OpenMap left it.
function F.Restore()
    for fs, old in pairs(changed) do
        if UADD.IsCyrFont((fs:GetFont())) then
            guard = true
            pcall(Put, fs, old)
            guard = false
        end
        changed[fs] = nil
    end
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
