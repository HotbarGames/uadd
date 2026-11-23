-- Fonts for our words on Attune's frames.
--   * Attune's texts use the game's font objects (GameFontNormal, GameFontHighlight ...): on an
--     English client those have no "і", "ї", "є", "ґ". A FontString that shows our words gets UADD's
--     Cyrillic font through the core helper (U.CyrFix: our font object first, the file by hand only
--     with proof, read back). Shared font objects are never changed.
--   * A font that already has Ukrainian letters is left alone.
--   * If Attune sets a font on such a FontString while it shows our words, the hooks below save its
--     new choice and put ours on again.
--   * The font follows the text: while a line shows Cyrillic, no font without it goes on (U.FontBack);
--     once its English is back, Attune's exact old font goes back.
local _, ns = ...
local F = {}
ns.Fonts = F

local changed = {}        -- FontString -> U.SaveFont record: its font before ours (U.CyrFix's `kept`)
local hookedFont = {}     -- FontString -> true once its SetFont and SetFontObject are hooked
local guard = false       -- up while we set a font ourselves

-- A font file with Ukrainian letters.
local function HasCyr(p)
    if UADD.IsCyrFont(p) then return true end
    p = type(p) == "string" and p:lower() or ""
    return p:find("_cyr", 1, true) or p:find("arialn", 1, true) or false
end

local function ShowsCyr(fs)
    local t = UADD.Plain(fs:GetText())
    return type(t) == "string" and t:find("[\208-\210][\128-\191]") ~= nil
end

local Fix

local function OnFont(fs)
    if guard or not changed[fs] then return end
    if not ns.Claim.Ours(fs) then changed[fs] = nil return end   -- a pooled widget now used elsewhere
    if not ns.WordsWanted() or ns.Screen.WaitCombat() then return end
    UADD.SafeCall(Fix, fs, true)
end

local function Hook(fs)
    if hookedFont[fs] then return end
    hookedFont[fs] = true
    hooksecurefunc(fs, "SetFont", OnFont)
    if fs.SetFontObject then hooksecurefunc(fs, "SetFontObject", OnFont) end
end

-- `byAddon`: called from a hook, so the font now set is the latest choice of its owner.
Fix = function(fs, byAddon)
    if not ShowsCyr(fs) then return end                  -- only texts in Ukrainian
    local p = fs:GetFont()
    if not p then return end
    if HasCyr(p) then return end      -- ours already (the per-tick case), or Attune chose a Cyrillic font itself
    -- Latin now. Attune set a font over ours: that is its latest choice, saved anew below.
    changed[fs] = nil
    guard = true
    local ok, took = pcall(UADD.CyrFix, fs, changed)
    guard = false
    if ok and took then Hook(fs) end
end
F.Fix = Fix

-- One FontString's font back (the hold key, or a text that is English again). While it still shows
-- Cyrillic (Attune drew one of our L words itself) and our words are wanted, the font follows the text.
function F.Back(fs)
    if not changed[fs] then
        if ns.WordsWanted() then Fix(fs) end
        return
    end
    if ShowsCyr(fs) and ns.WordsWanted() then return end
    guard = true
    pcall(UADD.CyrUnfix, fs, changed)
    guard = false
end

-- Forget one FontString without touching it (its text is someone else's now).
function F.Drop(fs) changed[fs] = nil end

-- Every font we changed back as Attune left it.
function F.Restore()
    for fs in pairs(changed) do
        guard = true
        pcall(UADD.CyrUnfix, fs, changed)
        guard = false
    end
end

-- For the status line and the checks: how many FontStrings carry our font now.
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
