-- UADD_WaypointUI fonts (lead decision 4; lessons 2, 18, 19). Waypoint UI makes its own font objects and pins
-- them to the game font's FILE (a Latin one: Cyrillic would be boxes). While its "Game Font" is chosen, each of
-- its own objects gets our Cyrillic file (U.CyrFontPath), read back after, and again after Waypoint UI sets
-- its fonts anew (a hook on the object's SetFont). A font the player picked from the font list is never
-- overridden: the texts drawn in it stay English, and one chat line says why. Off puts each object back as
-- it was, only where our file still stands (lesson 23). Game fonts are never touched here.
local _, ns = ...
local U = UADD

local F = { saved = {}, hooked = {}, odd = {} }   -- odd: objects in a font the player picked (no Cyrillic)
ns.Fonts = F
local busy = false
local OWN = { WUIFooterFont = true, WUIPinpointFont = true }

-- One of Waypoint UI's own font objects (its ui-font ones are named WaypointUIFont_<n>).
local function Ours(o)
    if type(o) ~= "table" or type(o.GetName) ~= "function" or type(o.GetFont) ~= "function" then return false end
    local ok, n = pcall(o.GetName, o)
    if not ok or type(n) ~= "string" then return false end
    return OWN[n] or n:find("^WaypointUIFont_%d+$") ~= nil
end

local function Norm(p) return type(p) == "string" and p:gsub("/", "\\"):lower() or nil end

-- The game font's file, the one Waypoint UI's "Game Font" choice copies.
local function GamePath()
    local g = _G["GameFontNormal"]
    if type(g) ~= "table" or type(g.GetFont) ~= "function" then return nil end
    local ok, p = pcall(g.GetFont, g)
    return ok and Norm(p) or nil
end

local function ObjectOf(f)
    local fs = type(f) == "table" and f.__Text
    if type(fs) ~= "table" or type(fs.GetFontObject) ~= "function" then return nil end
    local ok, o = pcall(fs.GetFontObject, fs)
    return ok and o or nil
end

local function Back(o)
    local was = F.saved[o]
    F.saved[o] = nil
    if not was then return end
    busy = true
    U.SafeCall(U.FontBack, o, was)
    busy = false
end

local function Note(path)
    local db = ns.db or {}
    if db.fontNote == path then return end
    db.fontNote = path
    U.Print("Waypoint UI: обраний у ньому шрифт не має українських літер, тож його тексти лишаються англійською. "
        .. "Обери в налаштуваннях Waypoint UI перший шрифт у списку, щоб бачити їх українською.")
end

-- Our Cyrillic file on one object, when the game font is chosen. true when it draws Cyrillic after.
local function Fix(o)
    local p, size, flags = o:GetFont()
    F.odd[o] = nil
    if U.IsCyrFont(p) then return true end
    local game = GamePath()
    if not game or Norm(p) ~= game then
        F.odd[o] = true
        Note(Norm(p) or "?")
        return false
    end
    local cyr = U.CyrFontPath()
    if not cyr or type(size) ~= "number" then return false end
    F.saved[o] = U.SaveFont(o)
    busy = true
    local ok = pcall(function() o:SetFont(cyr, size, flags or "") end)
    busy = false
    if ok and U.IsCyrFont((o:GetFont())) then return true end   -- read back (lesson 2)
    Back(o)
    return false
end

local function Refit(o)
    if busy or not ns.On() then return end
    local p, size, flags = o:GetFont()
    local was = F.saved[o]
    if was and U.IsCyrFont(p) then                  -- only its size or outline changed: keep that for off
        was.size, was.flags = size, flags
        return
    end
    F.saved[o] = nil                                -- Waypoint UI chose anew: that is its font now
    local ok, yes = U.SafeCall(Fix, o)
    if not (ok and yes) and ns.Screen then
        ns.Screen.Restore(function(f) return ObjectOf(f) == o end)
    elseif ns.Screen then
        ns.Screen.Apply()
    end
end

-- A Text frame the route found: its font object, when it is one of Waypoint UI's own.
function F.Collect(f)
    local o = ObjectOf(f)
    if not Ours(o) then return end
    if not F.hooked[o] then
        F.hooked[o] = true
        hooksecurefunc(o, "SetFont", U.Safe("waypointui", Refit))
    end
    if ns.On() and not F.saved[o] then U.SafeCall(Fix, o) end
end

-- false when the frame's text is drawn in one of Waypoint UI's own objects that has no Cyrillic file.
function F.CanDraw(f)
    local o = ObjectOf(f)
    if not Ours(o) then return true end
    local ok, p = pcall(o.GetFont, o)
    return ok and U.IsCyrFont(p) or false
end

function F.On()
    for o in pairs(F.hooked) do
        if not F.saved[o] then U.SafeCall(Fix, o) end
    end
end

function F.Off()
    for o in pairs(F.saved) do
        local ok, p = pcall(o.GetFont, o)
        if ok and U.IsCyrFont(p) then Back(o) else F.saved[o] = nil end
    end
end
