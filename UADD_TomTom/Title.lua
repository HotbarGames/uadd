-- UADD - TomTom: the arrow's title and a pin tooltip's title, when it is a waypoint named after its map.
--
-- OpenMap gives TomTom its map's English name as the title of a pin with no note (C_Map.GetMapInfo().name).
-- It is a game name: ours from ClassicUA or UALL Forever (core U.Place), only when it is the name of the
-- arrow's waypoint map, the user waypoint's map or the player's map, or of a map above them (lesson 13). Any
-- other title stays as typed. A hijacking addon may set the title on every frame: the last English, its map
-- and the answer are kept, so the same text costs one compare (lesson 12). A "not known yet" answer is not
-- kept; the title is asked again a few times, a few seconds apart. Off and the hold key: the English back
-- while our Ukrainian still stands. Module.lua calls Install, Redo and Restore; ns.On, ns.WordsWanted and
-- ns.Addon are Module.lua's, read when called.
local _, ns = ...
local U = UADD

-- Not U.Safe: the title hook gives English back, and all three must work again after an off for errors and "on"
-- (U.Safe stays dead then, lesson 19). An error is reported and counted the same way; each checks ns.On() or
-- ns.WordsWanted() itself.
local function Guard(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if ok then return end
        err = tostring(err)
        pcall(U.ReportError, err)
        if type(U.Fault) == "function" then pcall(U.Fault, "tomtom", err) end
    end
end

local Title = { busy = false, hooked = false, arrow = false, count = 0, map = nil, en = nil, uk = nil,
    ken = nil, kmap = nil, kuk = false, wen = nil, later = false, tries = 0 }
ns.Title = Title

local function UserMap()
    if type(C_Map) ~= "table" or type(C_Map.GetUserWaypoint) ~= "function" then return nil end
    local ok, w = pcall(C_Map.GetUserWaypoint)
    return ok and type(w) == "table" and w.uiMapID or nil
end

local function WorldMap()                          -- the map the World Map shows (a pin's tooltip there)
    local f = rawget(_G, "WorldMapFrame")
    if type(f) ~= "table" or type(f.GetMapID) ~= "function" or type(f.IsShown) ~= "function" then return nil end
    local ok, shown, id = pcall(f.IsShown, f)
    if ok and shown then ok, id = pcall(f.GetMapID, f) end
    return ok and shown and id or nil
end

function ns.Place(en, ...) return U.Place(en, U.UALL and U.UALL.Zone, ...) end

-- A pin's title named after its map (OpenMap's, as on the arrow): ours when it is the name of the arrow's map,
-- the user waypoint's, the player's, the World Map's shown map, or one above them. Not known yet: English.
function ns.TipPlace(s)
    return (ns.Place(s, Title.map, UserMap(), WorldMap()))
end

local function TitleFs()
    local w = rawget(_G, "TomTomCrazyArrow")
    local fs = type(w) == "table" and w.title
    return type(fs) == "table" and fs.SetText and fs.GetText and fs or nil
end

local function CanWait() return Title.tries < 10 and C_Timer and C_Timer.After and true or false end

local function PutTitle(fs, text)
    Title.busy = true
    pcall(fs.SetText, fs, text)
    Title.busy = false
end

function Title.OnText(fs, text)
    if Title.busy then return end
    Title.en, Title.uk = U.Plain(text), nil
    local en = Title.en
    if not en or not ns.WordsWanted() then return end
    if en ~= Title.ken or Title.map ~= Title.kmap then
        if en == Title.wen and Title.later then return end          -- asked already; the timer asks again
        local uk, wait = ns.Place(en, Title.map, UserMap())
        if wait and CanWait() then                                  -- after 10 tries: English, kept
            Title.wen = en
            Title.Later()
            return
        end
        Title.ken, Title.kmap, Title.kuk = en, Title.map, uk or false
    end
    if not Title.kuk then return end
    PutTitle(fs, Title.kuk)
    Title.uk = Title.kuk
    Title.count = Title.count + 1
end

-- The title as it shows now, asked again (a new waypoint map, on, the hold key let go, the timer).
function Title.Redo()
    local fs = TitleFs()
    if not fs or not ns.WordsWanted() then return end
    local ok, t = pcall(fs.GetText, fs)
    t = ok and U.Plain(t) or nil
    if t then Title.OnText(fs, (Title.uk and t == Title.uk) and Title.en or t) end
end

function Title.Later()
    if Title.later or not CanWait() then return end
    Title.later, Title.tries = true, Title.tries + 1
    C_Timer.After(3, Guard(function()
        Title.later, Title.wen = false, nil
        if ns.On() then Title.Redo() end
    end))
end

function Title.Restore()
    local fs = TitleFs()
    if not fs or not Title.uk or not Title.en then return end
    local ok, t = pcall(fs.GetText, fs)
    if ok and t == Title.uk then PutTitle(fs, Title.en) end
    Title.uk = nil
end

-- The waypoint the arrow points to ({ mapID, x, y, title = ... }): its map, after TomTom set the title.
local function OnArrow(_, uid)
    Title.map = type(uid) == "table" and type(uid[1]) == "number" and uid[1] or nil
    Title.Redo()
end

function Title.Install()
    local fs = TitleFs()
    if fs and not Title.hooked then
        Title.hooked = true
        hooksecurefunc(fs, "SetText", Guard(Title.OnText))
    end
    local A = ns.Addon and ns.Addon()
    if A and not Title.arrow and type(rawget(A, "SetCrazyArrow")) == "function" then
        Title.arrow = true
        hooksecurefunc(A, "SetCrazyArrow", Guard(OnArrow))
    end
end
