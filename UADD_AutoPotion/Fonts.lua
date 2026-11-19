-- Fonts for our words on Auto Potion's settings pages (the same way as UADD_LayerSwap/Fonts.lua).
--   * Its texts use the game's font objects (GameFontNormalHuge, GameFontHighlight, GameFontNormalSmall
--     and friends; FRIZQT: Latin letters only). A FontString that shows our words in such a font gets
--     UADD's Cyrillic font file at the size and with the flags it has now: fs:SetFont on that one
--     FontString. Shared font objects are never changed, and the size is never made smaller.
--   * The change is read back (fs:GetFont) where it counts: F.Count counts only the FontStrings whose
--     font file really is ours now, since SetFont gives no sign when it fails (docs/LESSONS.md, lesson 2).
--   * A font that already has Ukrainian letters is left alone.
--   * Buttons get their font objects again when their label is set or greyed out, which does not go
--     through the FontString's own SetFont, so each button's Set{Normal,Highlight,Disabled}FontObject
--     is hooked too (F.HookButton): ours goes on again at the new size.
--   * "/uadd autopotion off" and the hold key put back exactly what Auto Potion had.

local _, ns = ...
local F = {}
ns.Fonts = F

local changed = {}        -- FontString -> { path, size, flags, object, follows }: its font before ours
local hookedFont = {}     -- FontString or Button -> true once its font setters are hooked
local guard = false       -- up while we set a font ourselves

local function HasCyr(p)
    if UADD.IsCyrFont(p) then return true end
    p = type(p) == "string" and p:lower() or ""
    return p:find("_cyr", 1, true) or p:find("arialn", 1, true) or false
end

local Fix

local function OnFont(fs)
    if guard or not changed[fs] or not ns.WordsWanted() then return end
    UADD.SafeCall(Fix, fs, true)
end

-- The font of the FontString's font object now, or nil.
local function ObjectFont(fs)
    local o = fs.GetFontObject and fs:GetFontObject()
    if type(o) ~= "table" or not o.GetFont then return nil end
    local p, size, flags = o:GetFont()
    return p, size, flags or ""
end

local function SamePath(a, b)
    if type(a) ~= "string" or type(b) ~= "string" then return false end
    return (a:gsub("/", "\\"):lower()) == (b:gsub("/", "\\"):lower())
end

-- `byAddon`: called from a hook, so the font now set is Auto Potion's (or the game's) latest choice.
Fix = function(fs, byAddon)
    local t = UADD.Plain(fs:GetText())
    if type(t) ~= "string" or not t:find("[\208-\210]") then return end   -- only texts in Ukrainian
    local path = UADD.CyrFontPath()
    if not path then return end
    local p, size, flags = fs:GetFont()
    if not p or p == path and not byAddon then return end
    if HasCyr(p) then
        if byAddon and p ~= path then changed[fs] = nil return end   -- a Cyrillic font chosen by someone else
        if not (changed[fs] and changed[fs].follows) or not UADD.IsCyrFont(p) then return end
        local op, osize, oflags = ObjectFont(fs)
        if not op or (osize == size and oflags == (flags or "")) then return end
        size, flags = osize, oflags
    else
        local op, osize, oflags = ObjectFont(fs)
        changed[fs] = { path = p, size = size, flags = flags, object = fs.GetFontObject and fs:GetFontObject(),
            follows = SamePath(op, p) and osize == size and oflags == (flags or "") }
    end
    guard = true
    local ok, err = pcall(fs.SetFont, fs, path, size or 12, flags or "")
    guard = false
    if not ok then error(err, 0) end
    if not hookedFont[fs] then
        hookedFont[fs] = true
        hooksecurefunc(fs, "SetFont", OnFont)
        if fs.SetFontObject then hooksecurefunc(fs, "SetFontObject", OnFont) end
    end
end
F.Fix = Fix

local function OnButtonFont(b)
    if guard or not ns.WordsWanted() then return end
    local fs = b.GetFontString and b:GetFontString()
    if type(fs) == "table" then UADD.SafeCall(Fix, fs, true) end
end

local BUTTON_SETTERS = { "SetNormalFontObject", "SetHighlightFontObject", "SetDisabledFontObject" }

function F.HookButton(b)
    if hookedFont[b] or not b.SetNormalFontObject then return end
    hookedFont[b] = true
    for _, m in ipairs(BUTTON_SETTERS) do
        if b[m] then hooksecurefunc(b, m, OnButtonFont) end
    end
end

-- One FontString as Auto Potion left it. When it followed its font object: that object again, with
-- the FontString's own colour, justify, shadow and spacing kept. Otherwise its file, size and flags.
local LOOKS = { { "GetTextColor", "SetTextColor" }, { "GetJustifyH", "SetJustifyH" },
    { "GetJustifyV", "SetJustifyV" }, { "GetShadowColor", "SetShadowColor" },
    { "GetShadowOffset", "SetShadowOffset" }, { "GetSpacing", "SetSpacing" } }

local function Put(fs, old)
    if old.object and old.follows then
        local keep = {}
        for i, m in ipairs(LOOKS) do
            if fs[m[1]] and fs[m[2]] then keep[i] = { fs[m[1]](fs) } end
        end
        fs:SetFontObject(old.object)
        for i, m in ipairs(LOOKS) do
            if keep[i] and keep[i][1] ~= nil then fs[m[2]](fs, unpack(keep[i])) end
        end
        local p, size, flags = fs:GetFont()
        local op, osize, oflags = ObjectFont(fs)
        if op and (p ~= op or size ~= osize or (flags or "") ~= oflags) then fs:SetFont(op, osize, oflags) end
        return
    end
    fs:SetFont(old.path, old.size or 12, old.flags or "")
end

-- One FontString's font back (the hold key, or a text that is English again).
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

function F.Restore()
    for fs in pairs(changed) do F.Back(fs) end
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
