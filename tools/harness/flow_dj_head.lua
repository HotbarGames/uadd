-- Helpers for flow_dj_head.py: the dungeon header's level line (the level and the red notes beside
-- it, made in FDJ's code: Head.lua wraps the three functions) and the quest giver lines
-- ("Name, Town, Zone": NPC and zone names from UALL, Content.lua's places). Reached as HARNESS.djh.
-- No English of the journal is kept here: it is read from the journal while the flow runs.
local H = HARNESS
local D = {}
H.djh = D
local function ns() return H.ns.UADD_DungeonJournal end
local function F() return ForeverDungeonJournal_NS end
local function Frame() return rawget(_G, "ForeverDungeonJournalFrame") end

local function Shown(fs)
    return fs ~= nil and fs:IsShown() and (not fs:GetParent() or fs:GetParent():IsVisible()) or false
end

-- One header text: what it shows, whether it shows, whether its font has Ukrainian letters.
local function Read(key)
    local fs = Frame()[key]
    if not fs then return nil, false, false end
    return fs:GetText(), Shown(fs), UADD.IsCyrFont((fs:GetFont())) and true or false
end

-- "meta|shown|cyr" for the level line and its two notes, one per line.
function D.head()
    local out = {}
    for _, key in ipairs({ "dungeonMeta", "stockadeItemsTBD", "questsTBD" }) do
        local t, shown, cyr = Read(key)
        out[#out + 1] = key .. "\t" .. tostring(t) .. "\t" .. tostring(shown) .. "\t" .. tostring(cyr)
    end
    return table.concat(out, "\n")
end

-- The notes' maker called straight, as the header calls it (not "items": lupa's tables have that).
function D.lootNote(key) return F().ItemsTBDText(key) end

-- A dungeon with some loot listed and the table not full, and one without that mark.
function D.tbdKeys()
    local some, none
    for key, d in pairs(F().DB) do
        if type(d) == "table" and d.level then
            if d.fullItemsTBD then some = some or key else none = none or key end
        end
    end
    return some, none
end

local function Parts(text)
    local out = {}
    for part in text:gmatch("[^,]+") do out[#out + 1] = (part:gsub("^%s+", ""):gsub("%s+$", "")) end
    return out
end

-- Every quest giver and taker line in the journal, through FDJ's own free-text path. A line whose
-- every part with Latin letters has a Ukrainian name in our places must show each part as that
-- name; any other line must stay exactly English (never half: docs/LESSONS.md lesson 6). Returns
-- lines, changed, kept (left English though some part has a name), bad ("English => shown" lines),
-- and the zone parts in Ukrainian.
function D.givers()
    local places = F().ContentLocales.ukUA.places
    local seen, lines, changed, kept, zones, bad = {}, 0, 0, 0, 0, {}
    local Z = ns().Names.Zones()
    for _, d in pairs(F().DB) do
        for _, q in ipairs(type(d) == "table" and type(d.quests) == "table" and d.quests or {}) do
            for _, field in ipairs({ "pickup", "turnin" }) do
                local en = q[field]
                if type(en) == "string" and en ~= "" and not seen[en] and not en:find(" — ", 1, true) then
                    seen[en] = true
                    lines = lines + 1
                    local got = F().LocalizeFreeText(en)
                    local parts, all, some, z = Parts(en), true, false, 0
                    for i, p in ipairs(parts) do
                        if places[p] then
                            some, parts[i] = true, places[p]
                            if i > 1 and Z[p] then z = z + 1 end
                        elseif p:find("%a") then all = false end
                    end
                    local want = (all and some) and table.concat(parts, ", ") or en
                    if all and some then zones = zones + z elseif some then kept = kept + 1 end
                    if got ~= en then changed = changed + 1 end
                    if got ~= want and #bad < 8 then bad[#bad + 1] = en .. " => " .. tostring(got) end
                end
            end
        end
    end
    return lines, changed, kept, table.concat(bad, "\n"), zones
end

-- A made-up line through the same path (a known name beside one nobody has).
function D.free(text) return F().LocalizeFreeText(text) end

-- One line through the same path, and what each of its two names is in UALL (nil: it lacks it).
function D.giver(text, npc, zone)
    return F().LocalizeFreeText(text), ns().Names.Boss(npc), ns().Names.Dungeon(zone)
end
