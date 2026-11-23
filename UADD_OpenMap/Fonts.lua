-- Fonts on OpenMap's windows. Screen.lua finds the texts; this file changes and restores them.
--   * OpenMap draws every text with the client's standard font file, which has no Ukrainian
--     letters, so Ukrainian quest titles (from Questie, through UADD_Questie) showed as squares.
--   * A FontString whose font file has no Ukrainian letters gets UADD's Cyrillic font, at the size
--     and with the flags (OUTLINE, ...) it has now: first through UADD's own font object
--     (UADD.CyrOnLocked); OpenMap sets most of its fonts by hand (ns.Look:Font), and the client keeps
--     a hand-set file over any font object, so when the object does not take, the Cyrillic file goes
--     on by hand (UADD.CyrOnOwn, lesson 44). Always read back (lesson 2).
--     This does not depend on our words: it is needed for Questie's titles alone.
--   * OpenMap may set a font again (SetFont / SetFontObject), so both are hooked on each FontString
--     we changed (hooksecurefunc, once per FontString) and the Cyrillic font goes back at once. The
--     hooks cannot be removed, so with the module off they do nothing.
--   * "/uadd openmap off" puts back exactly what OpenMap had (UADD.FontBack): the font object, and
--     the file, size and flags it had set by hand.
--   * The game's shared lines (StaticPopup texts and buttons, GameTooltip lines) never get a font by
--     hand: only UADD's font object (F.Shared), and the saved object back (F.Back). No hooks on them.
--   * The options window is not done here: its widgets are shared with other addons' windows
--     (UADD/AceFont.lua does it).
-- Blizzard's shared font objects are never changed.

local _, ns = ...
local F = {}
ns.Fonts = F

local changed = {}        -- FontString -> its font before ours (UADD.SaveFont, lesson 18)
local shared = {}         -- a game's shared line -> its font before ours (font object only)
local hookedFont = {}     -- FontString -> true once its SetFont and SetFontObject are hooked
local guard = false       -- up while we set a font ourselves

local Fix

-- OpenMap set a font again. Ours goes back on while the module is on; on, off or in combat, a line that shows
-- Cyrillic always gets it (the font follows the text, lesson 32: never boxes).
local function OnFont(fs)
    if guard then return end
    local t = UADD.Plain(fs:GetText())
    local cyr = type(t) == "string" and t:find("[\208\209]") ~= nil
    if cyr or changed[fs] and ns.On() and not ns.Screen.WaitCombat() then UADD.SafeCall(Fix, fs, true) end
end

-- Ours on fs through UADD's font object, else by hand (not on a shared line); true when it took (read back).
local function On(fs, was, byObjectOnly)
    guard = true
    local ok, took = pcall(UADD.CyrOnLocked, fs)
    if not (ok and took) and not byObjectOnly then ok, took = pcall(UADD.CyrOnOwn, fs, was) end
    guard = false
    return ok and took and UADD.IsCyrFont((fs:GetFont())) or false
end

local function Back(fs, was)
    guard = true
    pcall(UADD.FontBack, fs, was)
    guard = false
end

-- `byOpenMap`: called from a hook, so the font now set is OpenMap's own latest choice.
Fix = function(fs, byOpenMap)
    if not UADD.CyrFontPath() then return end
    local p = fs:GetFont()
    if not p then return end
    if UADD.IsCyrFont(p) then
        if byOpenMap then changed[fs] = nil end    -- OpenMap chose a Cyrillic font itself
        return
    end
    local was = UADD.SaveFont(fs)                  -- ours is not on it now: its own font (lesson 32)
    changed[fs] = was
    if not On(fs, was) then
        Back(fs, was)                              -- its own font whole, never half of ours
        changed[fs] = nil
        return
    end
    if not hookedFont[fs] then
        hookedFont[fs] = true
        hooksecurefunc(fs, "SetFont", OnFont)
        hooksecurefunc(fs, "SetFontObject", OnFont)
    end
end
F.Fix = Fix

-- A game's shared line (a StaticPopup's text or button, a GameTooltip line): UADD's font object only,
-- never SetFont by hand (lesson 18). True when a Cyrillic font is on it now.
function F.Shared(fs)
    if not UADD.CyrFontPath() then return false end
    local p = fs:GetFont()
    if not p then return false end
    if UADD.IsCyrFont(p) then return true end      -- ours (or a Cyrillic face) is on: keep what we saved
    local was = UADD.SaveFont(fs)                  -- saved only while ours is not on it (lesson 32)
    if On(fs, was, true) then
        shared[fs] = was
        return true
    end
    Back(fs, was)
    return false
end

-- One FontString back as it was (a StaticPopup's or a tooltip line: shared with other addons),
-- only while ours is still on it (never over a font set since).
function F.Back(fs)
    local old = changed[fs] or shared[fs]
    if not old then return end
    if UADD.IsCyrFont((fs:GetFont())) then Back(fs, old) end
    changed[fs], shared[fs] = nil, nil
end

-- Every font we changed back as OpenMap (or the game) left it.
function F.Restore()
    for _, t in ipairs({ changed, shared }) do
        for fs, old in pairs(t) do
            if UADD.IsCyrFont((fs:GetFont())) then Back(fs, old) end
            t[fs] = nil
        end
    end
end

-- For the status line and the checks: how many FontStrings carry our font now.
function F.Count()
    local n = 0
    for _, t in ipairs({ changed, shared }) do
        for fs in pairs(t) do
            if UADD.IsCyrFont((fs:GetFont())) then n = n + 1 end
        end
    end
    return n
end

-- For the checks: what we remember of one FontString (path, size, flags, font object), or nil.
function F.Original(fs)
    local old = changed[fs] or shared[fs]
    if old then return old.path, old.size, old.flags, old.object end
end
