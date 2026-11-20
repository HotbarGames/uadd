-- A font with Cyrillic letters, shared through LibSharedMedia as "UADD Cyrillic".
-- The English client's default font has no Cyrillic, so Ukrainian text shows as boxes.
-- We only register the font. We never change Blizzard's shared font objects.

local U = UADD

U.FONT_NAME = "UADD Cyrillic"

-- Built into the client (the files live in the game's own archive, not on disk).
local CANDIDATES = { "Fonts\\FRIZQT___CYR.TTF", "Fonts\\ARIALN.TTF" }

local probe

local function FontExists(path)
    if not probe then
        local holder = CreateFrame("Frame")
        holder:Hide()
        probe = holder:CreateFontString(nil, "BACKGROUND")
    end
    local ok = pcall(probe.SetFont, probe, path, 12, "")
    local okGet, applied = pcall(probe.GetFont, probe)
    return ok and okGet and type(applied) == "string" and applied ~= ""
end

-- The first candidate the client can open, or nil. Found once per session.
function U.CyrFontPath()
    if U.fontPath then return U.fontPath end
    for _, candidate in ipairs(CANDIDATES) do
        local ok, yes = pcall(FontExists, candidate)
        if ok and yes then
            U.fontPath = candidate
            return candidate
        end
    end
    return nil
end

-- true when `path` is one of the fonts above (any case, / or \): a font with Ukrainian letters.
function U.IsCyrFont(path)
    if type(path) ~= "string" then return false end
    path = path:gsub("/", "\\"):lower()
    for _, candidate in ipairs(CANDIDATES) do
        if path == candidate:lower() then return true end
    end
    return false
end

-- ── A FontString's own font, kept and put back (docs/LESSONS2.md lesson 18) ──────────────────────
-- The client's font objects (GameTooltipText, GameFontNormal, ...) are font FAMILIES: one file per
-- alphabet, a Cyrillic one too, while GetFont shows only the Latin file. fs:SetFont(path) pins the
-- FontString to that one file until a /reload, and UALL Forever's Ukrainian on it shows boxes. So a
-- FontString that followed its font object gets the object back (SetFontObject), never SetFont.

local function SamePath(a, b)
    return type(a) == "string" and type(b) == "string" and (a:gsub("/", "\\"):lower()) == (b:gsub("/", "\\"):lower())
end

-- What U.FontBack needs later: { object, path, size, flags, own }. `own`: the font differed from its
-- object's (set by hand before us), so the file, size and flags go back too.
function U.SaveFont(fs)
    local p, s, f = fs:GetFont()
    local o = fs.GetFontObject and fs:GetFontObject() or nil
    local was = { object = o, path = p, size = s, flags = f }
    if type(o) == "table" and o.GetFont then
        local op, osize, oflags = o:GetFont()
        was.own = not (SamePath(op, p) and type(osize) == "number" and type(s) == "number"
            and math.abs(osize - s) < 0.5 and (oflags or "") == (f or ""))
    end
    return was
end

-- SetFontObject also sets the object's colour, justify, shadow and spacing: the FontString's own stay.
local LOOKS = { { "GetTextColor", "SetTextColor" }, { "GetJustifyH", "SetJustifyH" },
    { "GetJustifyV", "SetJustifyV" }, { "GetShadowColor", "SetShadowColor" },
    { "GetShadowOffset", "SetShadowOffset" }, { "GetSpacing", "SetSpacing" } }

-- The font `was` (U.SaveFont) back on fs: its font object again, so the family's Cyrillic member is
-- back too; SetFont only with no object, or when the font was set by hand before us (`own`).
function U.FontBack(fs, was)
    if type(was) ~= "table" then return end
    if was.object then
        local keep = {}
        for i, m in ipairs(LOOKS) do
            if fs[m[1]] and fs[m[2]] then keep[i] = { fs[m[1]](fs) } end
        end
        fs:SetFontObject(was.object)
        for i, m in ipairs(LOOKS) do
            if keep[i] and keep[i][1] ~= nil then fs[m[2]](fs, unpack(keep[i])) end
        end
        if not was.own then return end
    end
    if was.path and was.size then fs:SetFont(was.path, was.size, was.flags or "") end
end

local function LSM()
    if type(LibStub) ~= "table" and type(LibStub) ~= "function" then return nil end
    local ok, lib = pcall(LibStub, "LibSharedMedia-3.0", true)
    return ok and lib or nil
end

-- Registers the font with LibSharedMedia when both are there. Safe to call any number of times.
-- Returns true when "UADD Cyrillic" is in LibSharedMedia's list.
function U.RegisterFont()
    if U.fontRegistered then return true end
    local lsm = LSM()
    if not lsm then return false end
    local path = U.CyrFontPath()
    if not path then return false end
    local mask = (lsm.LOCALE_BIT_western or 128) + (lsm.LOCALE_BIT_ruRU or 2)
    local ok = pcall(lsm.Register, lsm, "font", U.FONT_NAME, path, mask)
    if not ok then return false end
    local okFetch, got = pcall(lsm.Fetch, lsm, "font", U.FONT_NAME, true)
    U.fontRegistered = okFetch and got ~= nil
    return U.fontRegistered
end
