-- Lua side of the live-names checks (flow_live.py): names found in a running game must reach
-- Questie's own quest, NPC and item objects in the same session, with no /reload.
-- Strings are UTF-8 bytes here; flow_live.py converts them.
local H = HARNESS
local F = H.flow

local function M(name) return QuestieLoader:ImportModule(name) end

-- The quests of flow_tracker.lua's quest log.
F.logIds = { 97291, 867, 4921, 7, 8386, 33 }

-- Counts Questie's rebuilds (QuestieQuest:SmoothReset) from now on.
function F.spyReset()
    if F.resets then return end
    F.resets = 0
    local QQ = M("QuestieQuest")
    local real = QQ.SmoothReset
    QQ.SmoothReset = function(...)
        F.resets = F.resets + 1
        return real(...)
    end
end

-- A logged quest whose title UALL Forever does not have, while its target does. Chosen at run time from
-- the installed UALL Forever and QuestieDB, so a UALLF update that adds the title cannot break the step
-- (7381 "The Return of Korrak" served until UALLF 1.0.18 added it): the lowest quest id that
--   * UALLF has neither by id (src.quests) nor by English title (src.questTitles), and UADD's own route
--     (UALL.Quest) gives nil too, so the title stays English by design;
--   * has exactly one objective, an item UALLF names (src.itemNames), dropped by 1-5 NPCs that all have
--     spawns and all have UALLF names (src.npcNames), so the map pins turn Ukrainian.
-- F.extra = { id, title, item, itemName, npcs = { [npcId] = English name } }, or nil when no quest fits.
local function Fits(src, U, Q, I, Nd, id)
    local en = Q.Get(id, "name")
    if src.quests[id] or type(en) ~= "string" or src.questTitles[en] then return end
    local o = Q.Get(id, "objectives")
    if type(o) ~= "table" or type(o[3]) ~= "table" or #o[3] ~= 1 then return end
    for _, k in ipairs({ 1, 2, 5, 6 }) do if type(o[k]) == "table" and #o[k] > 0 then return end end
    if o[4] then return end
    local item = o[3][1][1]
    local itemName = I.Get(item, "name")
    if type(itemName) ~= "string" or not src.itemNames[itemName] then return end
    local drops = I.Get(item, "npcDrops")
    if type(drops) ~= "table" or #drops < 1 or #drops > 5 then return end
    local npcs = {}
    for _, n in ipairs(drops) do
        local name, spawns = Nd.Get(n, "name"), Nd.Get(n, "spawns")
        if type(name) ~= "string" or not src.npcNames[name] or type(spawns) ~= "table" or not next(spawns) then
            return
        end
        npcs[n] = name
    end
    local uk, wait = U.Quest(id, en)          -- last: the costliest test
    if uk or wait then return end
    return { id = id, title = en, item = item, itemName = itemName, npcs = npcs, level = Q.Get(id, "questLevel") }
end

function F.pickExtra()
    local lib, src, U = _G.LibQuestieDB, H.ns.UALLF, H.ns.UADD_Questie.UALL
    local ids = {}
    for _, id in ipairs(lib.Quest.GetAllIds()) do ids[#ids + 1] = id end
    table.sort(ids)
    for _, id in ipairs(ids) do
        local ok, e = pcall(Fits, src, U, lib.Quest, lib.Item, lib.Npc, id)
        if ok and e then return e end
    end
end

function F.addExtraQuest()
    F.extra = F.pickExtra()
    F.extraId = F.extra and F.extra.id
    if not F.extra then return end
    local e, log = F.extra, {}
    for i, q in ipairs(F.questLog) do log[i] = q end
    local level = type(e.level) == "number" and e.level > 0 and e.level or 60
    log[#log + 1] = { title = e.title, level = level, questID = e.id, objectives = {
        { text = "0/1 " .. e.itemName, type = "item", numFulfilled = 0, numRequired = 1, finished = false } } }
    H.keys.SHIFT = true                    -- UALL says "not now", so the collection waits meanwhile
    H.questLog = log
    H.fire("QUEST_LOG_UPDATE")
    H.pump(400, nil, 0.05)
    H.keys.SHIFT = false
end

-- Pumps until Questie's rebuild is over, then 5 s more for the tracker update it queues.
function F.settle()
    local QQ = M("QuestieQuest")
    local frames, done = H.pump(4000, function() return not QQ._isResetting end, 0.05)
    H.pump(100, nil, 0.05)
    return frames, done
end

-- The game's quest log gets the quests; Questie picks them up while frames go on.
function F.fillLog()
    H.questLog = F.questLog
    H.fire("QUEST_LOG_UPDATE")
end

-- What Questie itself holds now, one "what=name" line each. A quest-log object that is not
-- the one QuestieDB.GetQuest hands out now is marked "(stale)".
function F.questieNames()
    local DB, AQ = M("QuestieDB"), M("ActiveQuests")
    local out = {}
    local q = DB.GetQuest(2)
    out[#out + 1] = "quest 2=" .. tostring(q and q.name)
    for _, id in ipairs(F.logIds) do
        local a = AQ.Get(id)
        local fresh = a and a.quest and a.quest == DB.GetQuest(id)
        out[#out + 1] = "log " .. id .. "=" .. tostring(a and a.quest and a.quest.name) .. (fresh and "" or " (stale)")
    end
    local npc, item = DB:GetNPC(6), DB:GetItem(5064)
    out[#out + 1] = "npc 6=" .. tostring(npc and npc.name)
    out[#out + 1] = "item 5064=" .. tostring(item and item.name)
    return out
end

-- Combat starts the moment the collection ends, once: the first combat question asked after the
-- job is gone is the end's own (Module.lua, TryApply), just before it asks Questie to rebuild.
function F.combatAtFinish()
    local N, real = H.ns.UADD_Questie.Names, InCombatLockdown
    local running = N.Progress() ~= nil
    InCombatLockdown = function(...)
        if N.Progress() ~= nil then
            running = true
        elseif running then                 -- the job is gone: this is the end's own question
            InCombatLockdown, H.combat = real, true
        end
        return real(...)
    end
end

-- What Questie's quest log holds for one quest: its title, the names in its objectives' spawn
-- lists (map pins), special objectives, and whether each tooltip points at its current objectives.
function F.objectiveNames(qid)
    local DB, AQ, TT = M("QuestieDB"), M("ActiveQuests"), M("QuestieTooltips")
    local out, mine = {}, {}
    local a = AQ.Get(qid)
    local q = a and a.quest
    if not q then return out end
    out[#out + 1] = "title=" .. tostring(q.name) .. (q == DB.GetQuest(qid) and "" or " (stale)")
    for _, o in pairs(q.Objectives or {}) do
        mine[o] = true
        for id, s in pairs(o.spawnList or {}) do out[#out + 1] = "spawn " .. id .. "=" .. tostring(s.Name) end
    end
    for id, o in pairs(q.SpecialObjectives or {}) do
        mine[o] = true
        out[#out + 1] = "special " .. id .. "=" .. tostring(o.Description)
    end
    for _, key in ipairs(TT.lookupKeysByQuestId[qid] or {}) do
        for _, t in pairs(TT.lookupByKey[key] or {}) do
            if t.questId == qid and t.objective then
                out[#out + 1] = "tooltip " .. key .. (mine[t.objective] and " fresh" or " stale")
            end
        end
    end
    return out
end

-- Questie's rebuild never ends (true), or works again (false).
function F.stuckReset(on)
    local QQ = M("QuestieQuest")
    if on then
        F.savedReset = QQ.SmoothReset
        QQ.SmoothReset = function() F.resets = F.resets + 1; QQ._isResetting = true end
    else
        QQ.SmoothReset, QQ._isResetting = F.savedReset, nil
    end
end

-- Questie has not started (true), or has (false).
function F.notStarted(on)
    if on then
        F.savedStarted = { Questie.started, Questie.API.isReady }
        Questie.started, Questie.API.isReady = false, false
    else
        Questie.started, Questie.API.isReady = F.savedStarted[1], F.savedStarted[2]
    end
end

-- The end of the next collection fails once: Questie's rebuild raises an error.
function F.failAtFinish()
    local QQ = M("QuestieQuest")
    local real = QQ.SmoothReset
    QQ.SmoothReset = function()
        QQ.SmoothReset = real
        error("harness: Questie's rebuild failed")
    end
end

-- Takes away (true) or gives back (false) the Questie function the live path needs.
function F.breakLive(on)
    local DB = M("QuestieDB")
    if on then
        F.savedRefresh = DB.RefreshAfterCorrectionApply
        DB.RefreshAfterCorrectionApply = nil
    else
        DB.RefreshAfterCorrectionApply = F.savedRefresh
    end
end
