-- Lua helpers for flow_qtag.py: the level letter in Questie's quest lines ("[40D] "). Reached from Python as
-- HARNESS.qtag. Run before the game starts.
local H = HARNESS
local M = {}
H.qtag = M

-- The proof that a step has teeth: with M.cut set, UADD_Questie's Module.lua or Tracker.lua runs without one fix
-- (in memory only). always: the guard goes in only when UADD gives Questie its language (the old code);
-- level: no guard on the level string; pcall: an error in our part reaches Questie.
local CUTS = {
    always = { "Module.lua", "    U.SafeCall(T.InstallSuffix)", "\n", "\n" },
    level = { "Tracker.lua", "    if not levelDone and type(level) == \"function\" then", "\n", "    if false then\n" },
    pcall = { "Tracker.lua", "    local ok, out = pcall(clean, s, questId)", "\n",
        "    local ok, out = true, clean(s, questId)\n" },
}
M.cut, M.wasCut = nil, false
local runFile = H.runFile
function H.runFile(addon, path, code)
    local c = M.cut and CUTS[M.cut]
    if addon == "UADD_Questie" and c and path == c[1] then
        local a = code:find(c[2], 1, true)
        local b = a and select(2, code:find(c[3], a + #c[2], true))   -- the rest of c[2]'s line goes too
        if a and b then code, M.wasCut = code:sub(1, a - 1) .. c[4] .. code:sub(b + 1), true end
    end
    return runFile(addon, path, code)
end

-- Quest 1956 "Power in Uldaman" (level 40, a dungeon quest: Questie's tag 81, "Dungeon") in the quest log.
function M.addQuest()
    local F = H.flow
    local log = {}
    for _, e in ipairs(F.fullLog) do log[#log + 1] = e end
    log[#log + 1] = { title = "Uldaman", isHeader = true }
    log[#log + 1] = { title = "Power in Uldaman", level = 40, questID = 1956,
        objectives = { { text = "0/1 Obsidian Power Source", type = "item", numFulfilled = 0, numRequired = 1,
            finished = false } } }
    F.questLog = log
end

local function Lib() return QuestieLoader:ImportModule("QuestieLib") end
local function DB() return QuestieLoader:ImportModule("QuestieDB") end

function M.state()
    local ns = H.ns.UADD_Questie
    local o = rawget(_G, "QUESTIE_LOCALES_OVERRIDE")
    return tostring(ns and ns.Locale and ns.Locale.state), tostring(type(o) == "table" and o.locale),
        tostring(QuestieLoader:ImportModule("l10n"):GetUILocale())
end

-- Questie's own calls, under pcall: ok, suffix, level string.
function M.level(questId)
    local lib = Lib()
    local ok, s = pcall(lib.GetQuestTypeSuffix, lib, questId)
    local ok2, l = pcall(lib.GetLevelString, lib, questId, 40)
    return ok and ok2, tostring(s), tostring(l)
end

-- Made-up tags with Ukrainian names, as any addon could give: 990001 an unknown tag, 990002 a raid, 990003 elite.
function M.oddTags()
    local db = DB()
    local orig = db.GetQuestTagInfo
    db.GetQuestTagInfo = function(q, ...)
        if q == 990001 then return 999, "Щось" end
        if q == 990002 then return db.questTagIds.RAID, "Рейд" end
        if q == 990003 then return db.questTagIds.ELITE, "Елітне" end
        return orig(q, ...)
    end
    local out = {}
    for i, q in ipairs({ 990001, 990002, 990003 }) do out[i] = select(3, M.level(q)) end
    db.GetQuestTagInfo = orig
    return out[1], out[2], out[3]
end

-- Another addon that wraps the suffix after us and gives a whole Cyrillic word.
function M.laterBuilder()
    local lib = Lib()
    local ours = lib.GetQuestTypeSuffix
    lib.GetQuestTypeSuffix = function() return "Під" end
    local ok, _, l = M.level(1956)
    lib.GetQuestTypeSuffix = ours
    return ok, l
end

-- Our part throws: Questie's own output, and no error reaches Questie.
function M.ourError()
    local T = H.ns.UADD_Questie.Tracker
    local cs, cl = T.CleanSuffix, T.CleanLevel
    local function boom() error("made-up error in our part") end
    T.CleanSuffix, T.CleanLevel = boom, boom
    local ok, s, l = M.level(1956)
    T.CleanSuffix, T.CleanLevel = cs, cl
    return ok, s, l
end
