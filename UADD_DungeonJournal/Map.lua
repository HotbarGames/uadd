-- The journal's own texts on the World Map, outside its window: inside a dungeon FDJ lends its
-- dungeon map (ForeverDungeonJournalFrame.dungeonMapPanel) to the World Map while the journal is
-- shut, with its "World Map" button and the Scarlet Monastery wing buttons (fdjWing). Their words
-- are FDJ's own and come from our strings; their fonts are fixed here, the way Screen.lua fixes
-- the journal's window (Fonts.lua, shown frames only, MIN_GAP apart).
-- OpenMap's dungeon view on the same map is another addon: UADD_OpenMap handles it.
-- Only frames FDJ made are touched; nothing of the World Map's own.

local _, ns = ...
local M = {}
ns.Map = M

local function Visible(f) return type(f) == "table" and f.IsVisible and f:IsVisible() end

local roots = {}

-- The frames FDJ put on the World Map, now.
local function Collect()
    wipe(roots)
    local journal = rawget(_G, "ForeverDungeonJournalFrame")
    roots[#roots + 1] = type(journal) == "table" and journal.dungeonMapPanel or nil
    roots[#roots + 1] = rawget(_G, "ForeverDungeonJournalWorldMapToggle")
    local map = rawget(_G, "WorldMapFrame")
    if not Visible(map) then return end
    for _, parent in ipairs({ map, map.ScrollContainer }) do
        for _, c in ipairs(type(parent) == "table" and parent.GetChildren and { parent:GetChildren() } or {}) do
            if c.fdjWing ~= nil then roots[#roots + 1] = c end
        end
    end
end

-- Is any of them shown? Each one found also brings a look when it is shown (Screen.WatchShow).
function M.AnyShown()
    Collect()
    local any = false
    for _, f in ipairs(roots) do
        ns.Screen.WatchShow(f)
        any = any or Visible(f)
    end
    return any
end

-- Called by Screen.Scan while our language is wanted: `walk` is Screen's own walk (fonts).
function M.Look(walk)
    Collect()
    for _, f in ipairs(roots) do if Visible(f) then walk(f) end end
end
