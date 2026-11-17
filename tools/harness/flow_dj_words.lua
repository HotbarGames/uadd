-- Helpers for flow_dj_words.py: the journal's short words that come from our tables — the
-- Favourites button (ui/strings_systems.lua), the search list's place line (Content.lua K.Location),
-- the loot type line (slotParts) and the "Trash Drops" row. Reached as HARNESS.djw.
local H = HARNESS
local W = {}
H.djw = W
local function ns() return H.ns.UADD_DungeonJournal end
local function F() return ForeverDungeonJournal_NS end

function W.fav()
    local f = rawget(_G, "ForeverDungeonJournalFrame")
    local b = f and f.favouritesButton
    return F().L("FAVOURITES"), b and b.text and b.text:GetText() or nil
end

-- Every dungeon's place line as the journal shows it: "English\tshown" lines, sorted.
function W.locations()
    local out = {}
    for key, d in pairs(F().DB) do
        if type(d) == "table" and type(d.location) == "string" and d.location ~= "" then
            out[#out + 1] = d.location .. "\t" .. tostring(F().LocalizeDungeonField(key, "location", d.location))
        end
    end
    table.sort(out)
    return table.concat(out, "\n")
end

function W.hallWant()
    local N = ns().Names
    local a, b = N.Dungeon("Ironforge"), N.Dungeon("Dun Morogh")
    return a and b and ("Під містом " .. a .. ", " .. b) or nil
end

function W.dungeon(en) return ns().Names.Dungeon(en) end
function W.item(en) return ns().Names.Item(en) end
function W.slot(text) return F().LocalizeItemSlot(text) end
function W.boss(en) return F().LocalizeBossName(en) end

-- Every comma word of every loot row's type line ({id, name, "Two-Hand, Axe", quality}) that
-- slotParts does not translate: "word (count)" lines.
function W.slotGaps()
    local words, seen = {}, {}
    local function walk(t)
        if seen[t] then return end
        seen[t] = true
        if type(t[1]) == "number" and type(t[2]) == "string" and type(t[3]) == "string" then
            for w in t[3]:gmatch("[^,]+") do
                w = w:gsub("^%s+", ""):gsub("%s+$", "")
                if w ~= "" then words[w] = (words[w] or 0) + 1 end
            end
        end
        -- An item made from two halves (FDJ 2.0.8+: item.makes) lists them in `from` as
        -- {id, name, boss}: the third field is a boss name there, not a type line.
        for k, v in pairs(t) do if type(v) == "table" and k ~= "from" then walk(v) end end
    end
    walk(F().DB)
    local gaps, n = {}, 0
    for w, c in pairs(words) do
        n = n + 1
        if F().LocalizeItemSlot(w) == w then gaps[#gaps + 1] = w .. " (" .. c .. ")" end
    end
    table.sort(gaps)
    return n, table.concat(gaps, "; ")
end
