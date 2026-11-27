-- UADD - OneForAll: W.Routed, lines whose one game name needs its own route (a spell, a vendor, a class, a recipe
-- item), and W.Headed, Words.lua's cheap gate for tooltip lines (W.Maybe). Loaded after Joined.lua, whose pieces
-- (W.Pieces: Class, Npc, Spell, Slot, TAG) it uses.

local _, ns = ...
local U = UADD
local find, sub = string.find, string.sub
local W = ns.Words
local P = W.P
local J = W.Pieces
local Class, Npc, Spell, Slot, TAG = J.Class, J.Npc, J.Spell, J.Slot, J.TAG

-- Lines whose one game-name slot needs a route other than the Item route Shapes asks (lesson 20), tried before
-- Shapes (after a whole text of ours): each by its head; a name no source knows keeps the whole line English.
local CAST, USE, SOLD, LEVEL = "Click: cast ", "Click: use ", "Sold by ", "Level "
local QM = "Code.1dfdac9d"                        -- its "profession quartermaster", put in when no vendor is known
-- FLT.RECIPE_PREFIX: a recipe's item name is the prefix and the recipe ("Pattern: <recipe>"), a whole item name.
local RECIPE = { "Pattern: ", "Plans: ", "Formula: ", "Schematic: ", "Recipe: " }

-- One of these templates at a..b of s: its line filled with get(name), or false (the name unknown: the whole line
-- stays English, never a name asked through another route); nil when s is not that template.
local function Decide(s, a, b, get)
    local k = "Code." .. U.Hash(sub(s, 1, a - 1) .. "%s" .. sub(s, b + 1))
    if type(ns.OFA[k]) ~= "string" or ns.SORT[k] ~= "n" then return nil end
    local x = sub(s, a, b)
    return Slot(s, a, b, "n", find(x, "^%d+$") and x or get(x)) or false   -- digits kept, as Shapes keeps them
end

local function Quartermaster(x)                   -- a vendor, or its own word when it knows none
    local uk = Npc(x)
    if not uk and "Code." .. U.Hash(x) == QM and type(ns.OFA[QM]) == "string" then uk = ns.OFA[QM] end
    return uk
end

local function Cast(s)                            -- the buff reminder's button: "Click: cast <spell>"
    if sub(s, 1, #CAST) ~= CAST then return nil end
    return Decide(s, #CAST + 1, #s, Spell)
end

local function Use(s)                             -- "Click: use <item> on your main hand" (or off hand)
    if sub(s, 1, #USE) ~= USE then return nil end
    local e = find(s, " on your ", #USE + 1, true)
    if not e then return nil end
    P.asked = true                                -- a game name, as in Zone
    return Decide(s, #USE + 1, e - 1, function(x) return x ~= "" and P.Item(x) or nil end)
end

local function Sold(s)                            -- "Sold by <vendor>": an NPC, or its own word for a quartermaster
    if sub(s, 1, #SOLD) ~= SOLD then return nil end
    return Decide(s, #SOLD + 1, #s, Quartermaster)
end

local function Level(s)                           -- a guild member on the map: "Level 40 Hunter" (the class: glossary)
    if sub(s, 1, #LEVEL) ~= LEVEL then return nil end
    local lvl, cls = s:match("^Level ([%d%?]+) (%u[%a ]-)$")
    local k = "Code." .. U.Hash(LEVEL .. "%s %s")
    local t = ns.OFA[k]
    if not cls or type(t) ~= "string" or ns.SORT[k] ~= "vn" then return nil end
    local uk = Class(cls)
    if not uk then return false end               -- a class the glossary lacks: never asked as an item
    local ok, out = pcall(string.format, t, lvl, uk)
    return ok and out or false
end

local function Recipe(s)                          -- a recipe's item, whole: the Item route (ClassicUA first)
    for i = 1, #RECIPE do
        if sub(s, 1, #RECIPE[i]) == RECIPE[i] then
            local uk = #s > #RECIPE[i] and P.Item(s)
            return uk and uk ~= s and uk or nil
        end
    end
    return nil
end

-- Ours, false (its template, a name no source knows: the whole line English), or nil (none of these lines).
local ROUTED = { Cast, Use, Sold, Level, Recipe }
function W.Routed(s)
    for i = 1, #ROUTED do
        local r = ROUTED[i](s)
        if r ~= nil then return r end
    end
    return nil
end

-- Cheap (lesson 12): does a tooltip line start with a head its code fills or glues? By its first bytes only.
local HEADS = { "Drops from: ", "Target: ", "On your wishlist: ", "Killed after ", "Quests in your log: ",
    "Instances this hour: ", "The game lets you enter ", "Sort by ", "Last scan here: ",
    "Ready again in about ", "Coordinates: ", "Object: ", "Territory: ", "Flight time: ", "Guild: ", "Twinks: ", CAST, USE, SOLD,
    TAG }
for i = 1, #RECIPE do HEADS[#HEADS + 1] = RECIPE[i] end

-- "Level <n> <class>": only with a class the glossary knows (the game's "Level 12 Beast" lines are not asked).
local function LevelHead(s)
    if sub(s, 1, #LEVEL) ~= LEVEL then return false end
    local cls = s:match("^Level [%d%?]+ (%u[%a ]-)$")
    local G = U.Glossary
    if not cls or type(G) ~= "table" or type(G.entries) ~= "table" then return false end
    return G.entries["class." .. (string.lower(cls):gsub(" ", "_"))] ~= nil
end

function W.Headed(s)
    for i = 1, #HEADS do
        if sub(s, 1, #HEADS[i]) == HEADS[i] then return true end
    end
    return LevelHead(s)
end
