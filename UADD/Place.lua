-- UADD core: a waypoint named after its map.
--
-- A waypoint with no name of the player's is often named with its map's name, which the game gives in English
-- (C_Map.GetMapInfo(mapID).name): Waypoint UI's own pins, and OpenMap's pins with no note through TomTom (OpenMap
-- gives TomTom the map's name as the title). It is a game name, so it is ours only from ClassicUA or UALL Forever
-- (lessons 9, 20, 25); English when neither has it. It counts only when it is the name of one of the given maps
-- (the waypoint's own, ...) or of the player's map, or of a map up to 5 levels above one of them: told apart by
-- where it comes from, not by what it says (lesson 13). So a title the player typed stays as typed, unless it is
-- exactly such a map's name (then it is that name anyway).
local U = UADD

local function Names(...)
    local names = {}
    if type(C_Map) ~= "table" or type(C_Map.GetMapInfo) ~= "function" then return names end
    local function Add(id)
        for _ = 1, 5 do
            if type(id) ~= "number" or id <= 0 then return end
            local info = C_Map.GetMapInfo(id)
            if type(info) ~= "table" then return end
            if type(info.name) == "string" then names[info.name] = true end
            id = info.parentMapID
        end
    end
    for i = 1, select("#", ...) do Add((select(i, ...))) end
    if type(C_Map.GetBestMapForUnit) == "function" then Add(C_Map.GetBestMapForUnit("player")) end
    return names
end

-- The Ukrainian of a map's name, or nil; nil, true: not known yet (ask again later, do not keep the answer).
-- zone: the route to ask, UADD.UALL.Zone, passed on each call by the module (so its own file names the route
-- it needs: tools/test_uall_routes.py). ...: map IDs the text may be named after (nil ones are skipped).
-- Only a plain one-line text with Latin letters, at most 120 bytes, is looked at.
function U.Place(en, zone, ...)
    en = U.Plain(en)
    if not en or en == "" or #en > 120 or not U.HasLatin(en) or en:find("[\n|]") then return nil end
    if type(zone) ~= "function" then return nil end
    local ok, names = pcall(Names, ...)
    if not ok or not names[en] then return nil end
    local ok2, uk, wait = pcall(zone, en)
    if not ok2 then return nil end
    if type(uk) ~= "string" or uk == "" or uk == en or U.HasLatin(uk) or not uk:find("[\208\209]") then
        return nil, wait and true or nil
    end
    return uk
end
