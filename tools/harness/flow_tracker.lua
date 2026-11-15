-- Lua side of the tracker checks (flow_tracker.py): a quest log the game would return, drawn by
-- Questie's real tracker. Strings are UTF-8 bytes here; flow_tracker.py converts them.
local H = HARNESS
local F = H.flow

local function Q(title, level, id, objectives)
    return { title = title, level = level, questID = id, objectives = objectives }
end
local function O(text, kind, have, need)
    return { text = text, type = kind, numFulfilled = have, numRequired = need, finished = have >= need }
end

-- Real quest IDs with their English titles, headers and objective texts. Forever's client puts the
-- count first ("0/8 Witchwing Talon"); one row is in the "Name: N/M" shape other clients use.
-- The lines that must stay English (an unknown item, a free-text objective, an unknown zone) use
-- made-up "Zzyzx Harness" names: UALL translates Questie's tracker on its own too (UALLF
-- QuestieHooks.lua, 2026-11-13), and a real name may get into its tables with any update.
F.fullLog = {
    { title = "Ruins of Lordaeron", isHeader = true },
    Q("Unending Torment", 21, 97291, { O("0/1 Zzyzx Harness Skullcap", "item", 0, 1), O("0/5 Essence of Agony", "item", 0, 5) }),
    { title = "The Barrens", isHeader = true },
    Q("Harpy Raiders", 15, 867, { O("Witchwing Talon: 3/8", "item", 3, 8) }),
    Q("Lost in Battle", 20, 4921, { O("0/1 Find Zzyzx Harness Wife", "event", 0, 1) }),
    { title = "Elwynn Forest", isHeader = true },
    Q("Kobold Camp Cleanup", 4, 7, { O("0/10 Kobold Vermin slain", "monster", 0, 10) }),
    { title = "Warsong Gulch", isHeader = true },
    Q("Fight for Warsong Gulch", 19, 8386, { O("2/3 Warsong Gulch Mark of Honor", "item", 2, 3) }),
    { title = "Zzyzx Harness Vale", isHeader = true },
    Q("Wolves Across the Border", 6, 33, { O("0/8 Zzyzx Harness Pelt", "item", 0, 8) }),
}

F.questLog = F.fullLog

-- A smaller log (the unknown zone, then Lost in Battle), so Questie reuses its lines.
function F.useSmallLog() F.questLog = { F.fullLog[10], F.fullLog[11], F.fullLog[5] } end
function F.resetQuestLog() F.questLog = F.fullLog end

local function Pool() return QuestieLoader:ImportModule("TrackerLinePool") end

-- The shown tracker lines, top to bottom.
function F.trackerLines()
    local out, pool = {}, Pool()
    for i = 1, pool.GetHighestIndex() do
        local line = pool.GetLine(i)
        if line and line:IsShown() and line.label then out[#out + 1] = line.label:GetText() or "" end
    end
    return out
end

-- Fills the quest log (or empties it), lets Questie notice, and redraws the tracker.
-- Returns the shown lines and every text set on a tracker line while drawing.
function F.drawTracker(fill)
    H.questLog = fill and F.questLog or {}
    local mark = #H.textLog
    H.fire("QUEST_LOG_UPDATE")
    H.pump(200, nil, 0.05)
    QuestieLoader:ImportModule("QuestieTracker"):Update()
    H.pump(200, nil, 0.05)
    local labels, set = {}, {}
    local pool = Pool()
    for i = 1, pool.GetHighestIndex() do
        local line = pool.GetLine(i)
        if line and line.label then labels[line.label] = true end
    end
    for i = mark + 1, #H.textLog do
        local fs, text = H.textLog[i][1], H.textLog[i][2]
        if labels[fs] then set[#set + 1] = text or "" end
    end
    return F.trackerLines(), set
end
