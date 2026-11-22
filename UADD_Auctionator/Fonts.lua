-- Fonts for our words on Auctionator's frames (the same way as UADD_ForeverXPBar/Fonts.lua).
--   * Auctionator's texts use the game's font objects (GameFontNormal, GameFontHighlight ...): on an
--     English client those have no "і", "ї", "є", "ґ". A FontString that shows our words gets UADD's
--     Cyrillic font file at the size and with the flags it has now: fs:SetFont on that one
--     FontString. Shared font objects are never changed, so colour, justify and shadow stay its own.
--   * A font that already has Ukrainian letters is left alone.
--   * If something sets a font on such a FontString while it shows our words, the hooks below put
--     ours on again at the new size and flags.
--   * "/uadd auctionator off" puts back exactly what was there: font object, file, size, flags.
local _, ns = ...
local F = {}
ns.Fonts = F

local changed = {}        -- FontString -> { path, size, flags, object, follows }: its font before ours
local hookedFont = {}     -- FontString -> true once its SetFont and SetFontObject are hooked
local guard = false       -- up while we set a font ourselves
local MENU = "Auctionator menu"   -- the game's menu rows: through UADD.AceFont only (lesson 38)

-- A font file with Ukrainian letters.
local function HasCyr(p)
    if UADD.IsCyrFont(p) then return true end
    p = type(p) == "string" and p:lower() or ""
    return p:find("_cyr", 1, true) or p:find("arialn", 1, true) or false
end

local Fix

local function OnFont(fs)
    if guard or not changed[fs] or not ns.WordsWanted() or ns.Screen.WaitCombat() then return end
    UADD.SafeCall(Fix, fs, true)
end

-- The size and flags of the FontString's font object now, or nil.
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

-- `byAddon`: called from a hook, so the font now set is the latest choice of its owner.
Fix = function(fs, byAddon)
    local t = UADD.Plain(fs:GetText())
    if type(t) ~= "string" or not t:find("[\208-\210]") then return end   -- only texts in Ukrainian
    if UADD.Locked(fs) then return UADD.AceFont.Set(fs, MENU) end      -- SetFont is forbidden there
    local path = UADD.CyrFontPath()
    if not path then return end
    local p, size, flags = fs:GetFont()
    if not p or p == path and not byAddon then return end   -- ours already (the per-tick case)
    if HasCyr(p) then
        if byAddon then changed[fs] = nil return end    -- Auctionator chose a Cyrillic font itself
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

-- One FontString as Auctionator left it. When it followed its font object: that object again.
-- Otherwise a font had been set on it: that file, size and flags. SetFontObject also sets
-- the object's colour, justify, shadow and line spacing, so the FontString's own are kept.
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
    if not old then return UADD.AceFont.Back(fs) end       -- a menu row (or nothing of ours)
    if UADD.IsCyrFont((fs:GetFont())) then
        guard = true
        pcall(Put, fs, old)
        guard = false
    end
    changed[fs] = nil
end

-- Every font we changed back as Auctionator left it.
function F.Restore()
    for fs in pairs(changed) do F.Back(fs) end
    UADD.AceFont.Stop(MENU)
end

-- For the status line and the checks: how many FontStrings carry our font file now.
function F.Count()
    local n = UADD.AceFont.Count(MENU)
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
