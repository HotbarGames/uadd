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
