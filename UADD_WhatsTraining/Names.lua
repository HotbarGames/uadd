-- UADD - What's Training?: a whole text that is one game name (a spell row, a trainer's name), from UALL
-- Forever (docs/LESSONS.md, lesson 9: game names are its, never ours). Screen.lua asks this after our own
-- words (ns.Words) gave nothing.
--   * Only a short one-line text that starts with a capital: a sentence or a label of What's Training? is
--     never asked (its UI words are ours, keyed by meaning).
--   * Asked of UADD.UALL's spell, NPC, zone and item routes (ns.Words.Name); a name it lacks keeps the
--     English. Each answer is kept, so a row set again costs no lookup and makes no garbage.
--   * "Not now" (combat, the hold key): English, asked again the next time the text is set, a second later.

local _, ns = ...

local CYR = "[\208-\210]"
local BARE = { "Spell", "Npc", "Zone", "Item" }
local named, count = {}, 0      -- English -> its Ukrainian, or false: UALL Forever's answer, asked once
local again = {}                -- English -> when to ask again after "not now"
local LIMIT = 4000

-- UALL Forever's Ukrainian for en, a text that is one game name, or nil.
function ns.GameName(en)
    if type(en) ~= "string" or #en > 64 or en:find("[|\n]") or not en:find("^%u") then return nil end
    local hit = named[en]
    if hit ~= nil then return hit or nil end
    local now = GetTime and GetTime() or 0
    if again[en] and now < again[en] then return nil end
    local uk, wait = ns.Words.Name(en, BARE)
    if type(uk) == "string" and uk ~= en and uk:find(CYR) then
        named[en], again[en] = uk, nil
        return uk
    end
    if wait then again[en] = now + 1 return nil end
    if count >= LIMIT then wipe(named) count = 0 end
    named[en], again[en], count = false, nil, count + 1
    return nil
end
