-- Fonts on the journal's texts. Screen.lua finds the texts; this file changes and restores them.
--   * A FontString whose font file has no Ukrainian letters gets UADD's Cyrillic font file, at the
--     size and with the flags (OUTLINE, ...) it has now: fs:SetFont on that one FontString.
--   * The journal sets fonts again on every draw (SetFont / SetFontObject), so both are hooked on
--     each FontString we changed (hooksecurefunc, once per FontString) and the Cyrillic file goes
--     back at once. The hooks cannot be removed, so with the module off or another language picked
--     they do nothing.
--   * Another language or "/uadd dj off" puts back exactly what the journal had: the font object,
--     the file, the size and the flags.
-- Blizzard's shared font objects are never changed.

local _, ns = ...
local F = {}
ns.Fonts = F

local copies = {}         -- shared font object -> our copy (only for our own menu entry)
local changed = {}        -- FontString -> its font before ours (UADD.SaveFont, lesson 18)
local hookedFont = {}     -- FontString -> true once its SetFont and SetFontObject are hooked
local count = 0
local guard = false       -- up while we set a font ourselves, so our SetFont does not come back

local function Copy(base)
    if copies[base] then return copies[base] end
    local path = UADD.CyrFontPath()
    if not path then return nil end
    local _, size, flags = base:GetFont()
    count = count + 1
    local name = "UADD_DJFont" .. count
    local f = rawget(_G, name) or CreateFont(name)
    pcall(f.SetFont, f, path, size or 12, flags or "")      -- gives back nothing in the client
    if not UADD.IsCyrFont((f:GetFont())) then return nil end
    f:SetTextColor(base:GetTextColor())
    f:SetShadowColor(base:GetShadowColor())
    f:SetShadowOffset(base:GetShadowOffset())
    copies[base] = f
    return f
end

-- A private copy of a shared font object with our font file, for a FontString of our own.
function F.FontFor(baseName)
    local base = rawget(_G, baseName)
    return base and Copy(base) or nil
end

local Fix

local function OnFont(fs)
    if guard then return end
    -- Our language is off: the journal's own new font is on it, nothing of ours to put back.
    if not (ns.Lang and ns.Lang.Wants()) then changed[fs] = nil return end
    UADD.SafeCall(Fix, fs, true)
end

-- Decided by the font file the FontString really uses now: the journal sets a file directly
-- (fs:SetFont) on some texts, while their font object stays the same.
-- `byJournal`: called from a hook, so the font now set is the journal's own latest choice.
Fix = function(fs, byJournal)
    local path = UADD.CyrFontPath()
    if not path then return end
    local p, size, flags = fs:GetFont()
    if not p then return end
    if UADD.IsCyrFont(p) then
        -- The journal itself chose a font with Ukrainian letters: nothing of ours to put back.
        if byJournal then changed[fs] = nil end
        return
    end
    -- The journal's latest choice, all of it, so F.Restore can put it back exactly.
    changed[fs] = UADD.SaveFont(fs)
    guard = true
    local ok, err = pcall(fs.SetFont, fs, path, size or 12, flags or "")
    guard = false
    if not ok then
        changed[fs] = nil
        error(err, 0)
    end
    if not hookedFont[fs] then
        hookedFont[fs] = true
        hooksecurefunc(fs, "SetFont", OnFont)
        hooksecurefunc(fs, "SetFontObject", OnFont)
    end
end
F.Fix = Fix

-- Does this FontString carry our font, kept there by its hooks? Then a look can pass it by: each
-- SetFont / SetFontObject of the journal puts ours back at once, and F.Restore forgets them all.
-- (The journal never changes its font objects after it made them.)
function F.Kept(fs)
    return changed[fs] ~= nil and hookedFont[fs] == true
end

-- ── The journal's buttons (docs/LESSONS4.md lesson 46) ─────────────────────────────────────────
-- A button's label takes the font object of the button's state from the client itself (normal, under the
-- mouse, disabled), and there the journal's own objects draw no Cyrillic. Our words on its buttons showed as
-- boxes from the moment the journal set them until our next look (the mode chooser's button, the back
-- button; harness, 2026-11-26). So every button the journal makes gets the core's Cyrillic copies of its
-- state objects (UADD.ButtonCyr) at once, before any text is on it: the journal passes each one through its
-- own FDJ.OwnFonts, hooked here. A button made before the hook is met by the look (Screen.lua). A state
-- object the journal sets later gets our copy from the core's own state hooks (UADD/ButtonFont.lua). They go
-- back (UADD.ButtonBack) only once the label shows no Cyrillic: English first, then the old font (lesson 45).
local seen = setmetatable({}, { __mode = "k" })    -- a frame the journal made -> true (a button) or false
local mine = setmetatable({}, { __mode = "k" })    -- a button whose states carry our copies
local behind = false                              -- a button seen while our language was off, or given back

local function IsButton(b)
    if type(b) ~= "table" or type(b.GetObjectType) ~= "function" then return false end
    local ok, kind = pcall(b.GetObjectType, b)
    return ok and (kind == "Button" or kind == "CheckButton") and type(b.GetNormalFontObject) == "function"
end

local function PutStates(btn)
    if not (ns.Lang and ns.Lang.Wants()) then behind = true return end
    if UADD.ButtonCyr(btn) then mine[btn] = true end
end

function F.Button(f)
    local known = seen[f]
    if known == false then return end
    if known then
        if not mine[f] then PutStates(f) end
        return
    end
    seen[f] = IsButton(f)
    if not seen[f] then return end
    PutStates(f)
end

local maker = false
function F.HookMaker(fdj)
    if maker or type(fdj) ~= "table" or type(fdj.OwnFonts) ~= "function" then return end
    maker = true
    hooksecurefunc(fdj, "OwnFonts", function(object) UADD.SafeCall(F.Button, object) end)
end

-- Our language is on again: the buttons seen while it was off get our copies, before the journal redraws.
function F.Buttons()
    if not behind or not (ns.Lang and ns.Lang.Wants()) then return end
    behind = false
    for b, yes in pairs(seen) do
        if yes and not mine[b] then PutStates(b) end
    end
end

local function ShowsCyr(btn)
    local fs = btn.GetFontString and btn:GetFontString()
    local t = fs and UADD.Plain(fs:GetText())
    return t ~= nil and t:find("[\208\209\210][\128-\191]") ~= nil
end

local function ButtonsBack()
    for b in pairs(mine) do
        if not ShowsCyr(b) then
            mine[b] = nil
            behind = true
            UADD.ButtonBack(b)
        end
    end
end

-- For the checks: is this button's every state ours now?
function F.Mine(btn) return mine[btn] == true end

-- One FontString as the journal left it (UADD.FontBack): its font object, always, so the family's
-- Cyrillic letters come back; then the file, size and flags when the journal had set them by hand.
local Put = UADD.FontBack

-- The journal's fonts back, exactly as they were before we changed them (the hooks keep `changed`
-- up to date with each new choice of the journal).
function F.Restore()
    pcall(ButtonsBack)
    for fs, old in pairs(changed) do
        if UADD.IsCyrFont((fs:GetFont())) then
            guard = true
            pcall(Put, fs, old)
            guard = false
        end
    end
    wipe(changed)
end

-- For the checks: how many FontStrings carry our font file now.
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
