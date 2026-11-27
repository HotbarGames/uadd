-- Fonts for our words on DialogueUI's windows (the same way as UADD_OpenMap/Fonts.lua).
--   * DialogueUI's default font file (its Fonts/frizqt__.ttf) has no Ukrainian letters. A FontString
--     that shows our words and has such a font gets UADD's Cyrillic font file at the size and with the
--     flags it has now: fs:SetFont on that one FontString. The shared DUIFont_* objects and Blizzard's
--     font objects are never changed.
--   * A font that already has Ukrainian letters is left alone: ours, DialogueUI's own Cyrillic files
--     (frizqt___cyr, ARIALN, TrajanPro3), or one DialogueUI - UALL put on DUIFont_*.
--   * DialogueUI resets its font objects when the player changes the font or its size; Texts.lua
--     calls F.Fix again on every text it shows (ours then takes the object's new size and flags),
--     and the hooks below catch a new SetFont at once (a Cyrillic one from DialogueUI: we let go).
--   * "/uadd dialogueui off" puts back exactly what DialogueUI had: font object, file, size, flags.
--     So does the hold key, once its English is back (F.Back); the release puts ours on again.

local _, ns = ...
local F = {}
ns.Fonts = F

local changed = {}        -- FontString -> { path, size, flags, object }: its font before ours
local hookedFont = {}     -- FontString -> true once its SetFont and SetFontObject are hooked
local guard = false       -- up while we set a font ourselves

-- A font file with Ukrainian letters.
local function HasCyr(p)
    if UADD.IsCyrFont(p) then return true end
    p = type(p) == "string" and p:lower() or ""
    return p:find("_cyr", 1, true) or p:find("arialn", 1, true) or p:find("trajanpro3", 1, true) or false
end

local Fix

local function OnFont(fs)
    if guard or not changed[fs] or not ns.WordsWanted() or ns.Screen.WaitCombat() then return end
    UADD.SafeCall(Fix, fs, true)
end

-- The size and flags of the FontString's font object now, or nil.
local function ObjectFont(fs)
    local o = fs:GetFontObject()
    if type(o) ~= "table" or not o.GetFont then return nil end
    local p, size, flags = o:GetFont()
    return p, size, flags or ""
end

local function SamePath(a, b)
    if type(a) ~= "string" or type(b) ~= "string" then return false end
    return (a:gsub("/", "\\"):lower()) == (b:gsub("/", "\\"):lower())
end

-- `byDUI`: called from a hook, so the font now set is DialogueUI's own latest choice.
Fix = function(fs, byDUI)
    local t = UADD.Plain(fs:GetText())
    if type(t) ~= "string" or not t:find("[\208-\210]") then return end   -- only texts in Ukrainian
    local path = UADD.CyrFontPath()
    if not path then return end
    local p, size, flags = fs:GetFont()
    if not p then return end
    if HasCyr(p) then
        if byDUI then changed[fs] = nil return end    -- DialogueUI chose a Cyrillic font itself
        if not (changed[fs] and changed[fs].follows) or not UADD.IsCyrFont(p) then return end
        -- Ours, on a FontString that followed its font object. DialogueUI's FontUtil changes the
        -- DUIFont_* objects' size; after our SetFont the FontString no longer follows, so it gets
        -- the object's size and flags again here.
        local op, osize, oflags = ObjectFont(fs)
        if not op or (osize == size and oflags == (flags or "")) then return end
        size, flags = osize, oflags
    else
        local op, osize, oflags = ObjectFont(fs)
        local was = changed[fs]
        local o = was and was.back and was.follows and op and was.object
        if type(o) == "table" and UADD.SafeFontObject(fs) == o and SamePath((o:GetFont()), p) then
            -- Its own font given back on the hold key (F.Back): it still follows its object, whose size
            -- may have changed while held (that FontString kept the file and size put back by hand).
            -- Only while the record still holds: DialogueUI may have set another object or its own file
            -- while held (OnFont skips it then); then a fresh record below.
            was.back, size, flags = nil, osize, oflags
        else
            changed[fs] = { path = p, size = size, flags = flags, object = UADD.SafeFontObject(fs),
                follows = SamePath(op, p) and osize == size and oflags == (flags or "") }
        end
    end
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

-- One FontString as DialogueUI left it. When it followed its font object: that object again, so it
-- gets the object's font now (a size changed since then included). Otherwise DialogueUI had set a
-- font on it: that file, size and flags. SetFontObject may reset the text colour, so it is kept.
local function Put(fs, old)
    if old.object then
        local r, g, b, a = fs:GetTextColor()
        UADD.SetFontObject(fs, old.object)        -- lesson 47: only an object that may go back
        if r then fs:SetTextColor(r, g, b, a) end
        if old.follows then
            local p, size, flags = fs:GetFont()
            local op, osize, oflags = ObjectFont(fs)
            if op and (p ~= op or size ~= osize or (flags or "") ~= oflags) then fs:SetFont(op, osize, oflags) end
            return
        end
    end
    fs:SetFont(old.path, old.size or 12, old.flags or "")
end

-- The hold key (Texts.lua, after its English is back): its own font again, its record kept, so the
-- release (Texts.Apply -> F.Fix) puts ours on at DialogueUI's latest size (lessons 32, 45). Never while
-- the text shows Cyrillic (DialogueUI - UALL's): that stays in our file. Never in combat (callers).
function F.Back(fs)
    local old = changed[fs]
    if not old or old.back then return end
    local t = UADD.Plain(fs:GetText())
    if type(t) ~= "string" or t:find("[\208-\211]") or not UADD.IsCyrFont((fs:GetFont())) then return end
    guard = true
    local ok, err = pcall(Put, fs, old)
    guard = false
    if not ok then error(err, 0) end
    old.back = true
end

-- Every font we changed back as DialogueUI left it.
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
