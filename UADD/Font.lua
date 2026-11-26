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
-- object's (set by hand before us), so the file, size and flags go back too. Never on a button's label: its
-- client changes the object with the state, so the two differing proves nothing there, and a Latin file put
-- back on it would stay (lesson 46). Only U.CyrOnOwn can prove a label's font was set by hand (`byhand`).
-- `unsafe`: no object of its chain may go back (lesson 47), so U.FontBack leaves the font as it is.
function U.SaveFont(fs)
    local p, s, f = fs:GetFont()
    local o, unsafe = U.SafeFontObject(fs)
    o = U.FontBase(o)
    local was = { object = o, path = p, size = s, flags = f, unsafe = unsafe or nil }
    if type(o) == "table" and o.GetFont and not U.LabelButton(fs) then
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

U.FontLooks = LOOKS                              -- ButtonFont.lua: the same looks on our copies

local function ObjectOn(fs, o)
    if not U.FontObjectOK(fs, o) then return false end   -- lesson 47 (FontObject.lua): nothing set
    local keep = {}
    for i, m in ipairs(LOOKS) do
        if fs[m[1]] and fs[m[2]] then keep[i] = { fs[m[1]](fs) } end
    end
    local set = U.SetFontObject(fs, o)
    for i, m in ipairs(LOOKS) do
        if keep[i] and keep[i][1] ~= nil then fs[m[2]](fs, unpack(keep[i])) end
    end
    return set
end
U.ObjectOn = ObjectOn                            -- the guard's repair (Guard.lua): an object as is (U.FontObjectOK)

-- ── Menu regions (docs/LESSONS3.md lesson 38) ─────────────────────────────────────────────────────
-- The game's menus (MenuUtil.CreateContextMenu, the new dropdowns: Blizzard_Menu) lend their
-- FontStrings out with a new metatable. Even READING "SetFont" from one reports "Use of function
-- 'SetFont' is disallowed", and so does calling what it gives back, inside pcall too. Such a region's
-- metatable has a TABLE __newindex (writes go to a side table); a plain FontString's has none. Only
-- SetFontObject may change its font, and the menu puts its own font back when the menu closes.
function U.Locked(fs)
    if type(fs) ~= "table" then return false end
    local ok, mt = pcall(getmetatable, fs)
    if not ok or type(mt) ~= "table" then return false end
    local okN, ni = pcall(rawget, mt, "__newindex")
    return okN and type(ni) == "table"
end

-- Our own font objects (UADD_CyrFontN): the Cyrillic file alone, one per size and flags. Never a shared font
-- object of the game's, nor a copy of one: a copied family keeps its members (lesson 46).
local cyrObjects, cyrMade = {}, 0

local function CyrObject(fs)
    local path = U.CyrFontPath()
    if not path or type(CreateFont) ~= "function" then return nil end
    local _, size, flags = fs:GetFont()
    size, flags = tonumber(size) or 12, flags or ""
    -- One object per file, size and flags (lesson 44): ObjectOn keeps the FontString's own colour, justify,
    -- shadow and spacing, so the base object adds nothing. Keyed by the base too, one module's many sizes and
    -- templates used up the 64 and every later label stayed English.
    local key = ("%s|%.1f|%s"):format(path, size, flags)
    if cyrObjects[key] then return cyrObjects[key] end
    if cyrMade >= 64 then return nil end                   -- never a heap of font objects
    cyrMade = cyrMade + 1
    local o = CreateFont("UADD_CyrFont" .. cyrMade)
    o:SetFont(path, size, flags)
    if not U.IsCyrFont((o:GetFont())) then return nil end  -- read back (lesson 2): no font, no change
    cyrObjects[key] = o
    return o
end

-- Our font on fs through font objects only (also a menu region, U.Locked); true when it really took. A button's
-- label: its states' own objects first (ButtonFont.lua), so no state puts another font on; a label that keeps a file
-- set by hand gets ours like any other text. A text the width check found boxes on twice (BoxGuard.lua) gets none.
function U.CyrOnLocked(fs)
    if U.BoxBad and U.BoxBad(fs) then return false end
    local btn = U.LabelButton(fs)
    local yes = btn and U.LabelCyr(btn, fs)
    if btn and yes == nil then return false end             -- a button we may not change: English
    if not yes then
        local o = CyrObject(fs)
        if not o then return false end
        ObjectOn(fs, o)
        yes = U.IsCyrFont((fs:GetFont()))
    end
    if yes and U.BoxWatch then U.BoxWatch(fs) end
    return yes
end

-- fs draws Cyrillic now (our font, or one of its own), and so do all the states of its button (a label only).
function U.CyrHolds(fs)
    if not U.IsCyrFont((fs:GetFont())) or (U.BoxBad and U.BoxBad(fs)) then return false end
    local btn = U.LabelButton(fs)
    return not btn or U.ButtonCyr(btn, true)
end

-- A label whose font was set by hand (SetFont, as OneForAll's buttons and nav do) can keep that file over any font
-- object (lesson 44); GetFont cannot tell it when the hand-set size is the object's own. Called only when our font
-- object did not take: the Cyrillic file goes on by hand, at the label's own size and flags, and U.FontBack puts the
-- addon's file back when its object does not. Never on a menu region (lesson 38). True when it took (read back).
function U.CyrOnOwn(fs, was)
    if type(was) ~= "table" or U.Locked(fs) or (U.BoxBad and U.BoxBad(fs)) then return false end
    local path = U.CyrFontPath()
    if not path then return false end
    local btn = U.LabelButton(fs)
    if btn and not U.ButtonCyr(btn) then return false end
    -- A hand-set file only with proof the label keeps one: the addon set it (`own`), or our object was put on
    -- and did not take. No object at all (the 64 cap, CreateFont failed) proves nothing: a line that follows its
    -- font family stays English, never gets a file by hand that U.FontBack would later pin back.
    if not was.own then
        local o = CyrObject(fs)
        if not o then return false end
        ObjectOn(fs, o)
        if U.IsCyrFont((fs:GetFont())) then return true end
    end
    was.byhand = true                             -- only such a label gets its file back by path (FontBack)
    fs:SetFont(path, tonumber(was.size) or 12, was.flags or "")
    local yes = U.IsCyrFont((fs:GetFont()))
    if yes and U.BoxWatch then U.BoxWatch(fs) end
    return yes
end

-- The font `was` (U.SaveFont) back on fs: its font object again, so the family's Cyrillic member is
-- back too; SetFont only with no object, or when the font was set by hand before us (`own`). A menu
-- region (U.Locked) gets its object only: SetFont is never even looked up on one.
-- The font follows the text: while the line still shows Cyrillic in our font, no font without Cyrillic goes on
-- (English in our font is safe; Ukrainian in a Latin file is boxes). The caller puts the English back first.
local function ShowsCyr(fs)
    local okV, vis = pcall(fs.IsVisible, fs)
    if not okV or not vis then return false end   -- hidden: nothing drawn; the game sets its text again on show
    local ok, t = pcall(fs.GetText, fs)
    t = ok and U.Plain(t) or nil
    return t ~= nil and t:find("[\208\209\210][\128-\191]") ~= nil
end
local function OursOn(fs)
    local o = fs.GetFontObject and fs:GetFontObject() or nil
    local n = type(o) == "table" and o.GetName and o:GetName()
    return type(n) == "string" and n:find("^UADD_CyrFont") ~= nil or U.IsCyrFont((fs:GetFont()))
end

function U.FontBack(fs, was)
    if type(was) ~= "table" then return end
    if not U.IsCyrFont(was.path) and ShowsCyr(fs) and OursOn(fs) then return end
    if U.Locked(fs) then
        if was.object then ObjectOn(fs, was.object) end
        return
    end
    local btn = U.LabelButton(fs)
    if btn then
        U.ButtonBack(btn)                         -- its states' own objects: the label follows them again
        local o = fs:GetFontObject()
        local own = U.FontBase(o)
        if own ~= o then U.LabelOn(fs, own) end   -- our copy still on: the object it stands for
        if not OursOn(fs) then return end
    end
    if was.object then
        ObjectOn(fs, was.object)
        -- the object took (or our file is not on): done. A label that keeps a hand-set file over its object
        -- (U.CyrOnOwn, lesson 44) gets its own file back below. Only such a label: a line that followed its
        -- object (a game tooltip line) never gets a file by path, which pins the Latin file (lesson 18 again).
        if not was.own and not (was.byhand and U.IsCyrFont((fs:GetFont())) and not U.IsCyrFont(was.path)) then
            return
        end
    end
    if was.unsafe and not was.own and not was.byhand then return end   -- lesson 47: no object may go back
    if was.path and was.size then fs:SetFont(was.path, was.size, was.flags or "") end
end

-- Our font on a line that is to show Ukrainian, its own saved first in `kept` (weak: fs -> U.SaveFont): our object,
-- by hand only with proof (U.CyrOnOwn), read back (lesson 2). No take: its own font back, false (the English stays).
-- Ours gone from the line since (the addon set its font again): that font is its own now, ours goes on over it.
function U.CyrFix(fs, kept)
    if kept[fs] and U.CyrHolds(fs) then return true end
    if kept[fs] and U.IsCyrFont((fs:GetFont())) then    -- ours on the label, not in every state of its button
        return U.CyrOnLocked(fs) == true
    end
    kept[fs] = nil
    local was = U.SaveFont(fs)
    local ok, took = pcall(U.CyrOnLocked, fs)
    if ok and not took then ok, took = pcall(U.CyrOnOwn, fs, was) end
    if ok and took and U.IsCyrFont((fs:GetFont())) then kept[fs] = was return true end
    pcall(U.FontBack, fs, was)
    return false
end

-- Its own font back on a line U.CyrFix fixed; the caller puts the English back first.
-- FontBack keeps ours while the line still shows Cyrillic (no box); then the record stays, so the next Unfix (once
-- English is on) still has the line's own font. Forget it only once ours is off the line.
function U.CyrUnfix(fs, kept)
    local was = kept[fs]
    if not was then return end
    pcall(U.FontBack, fs, was)
    local ok, still = pcall(OursOn, fs)
    if not (ok and still and not U.IsCyrFont(was.path)) then kept[fs] = nil end
end

-- The font follows the text on a line whose text we leave as it is (lesson 45): shown Cyrillic gets a font with it,
-- anything else (English, hidden) its own font back. fix(fs) / back(fs): a module's own font calls, when given.
function U.CyrFollow(fs, kept, fix, back)
    if type(fs) ~= "table" then return end
    if ShowsCyr(fs) then
        if fix then pcall(fix, fs) else U.CyrFix(fs, kept) end
    elseif back then pcall(back, fs) else U.CyrUnfix(fs, kept) end
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
