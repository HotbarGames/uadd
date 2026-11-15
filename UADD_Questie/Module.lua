-- UADD - Questie: start-up order, the status line and "/uadd questie ..." commands.
--
-- Our ADDON_LOADED comes after Questie's and QuestieDB's (they are our dependencies) and before
-- PLAYER_LOGIN, when Questie reads QUESTIE_LOCALES_OVERRIDE. Once Questie is fully loaded
-- (Questie.API.RegisterOnReady, Public/RegisterOnReady.lua:10) we collect the names UALL knows.

local ADDON, ns = ...
local U = UADD
local L, N, F, T = ns.Locale, ns.Names, ns.Font, ns.Tracker
local HF = ns.HeaderFont
local db

local function Say(msg) U.Print("Questie: " .. msg) end

local function Module(name)
    local ok, mod = pcall(function() return QuestieLoader:ImportModule(name) end)
    return ok and type(mod) == "table" and mod or nil
end

-- ── New names on screen without /reload ───────────────────────────────────────────────────────
-- LibQuestieDB has the names at once, but Questie keeps its own copies of quests, NPCs and items
-- (QuestieDB.lua:1514, 1890, 373), and LibQuestieDB's SetCorrection does not clear them
-- (QuestieDB src/l10n/overlay.lua:72). So, once per collection, we ask Questie to drop the copies
-- whose names changed (QuestieDB.RefreshAfterCorrectionApply, QuestieDB.lua:315) and to build its
-- quest log, map pins and tracker again from fresh copies (QuestieQuest:SmoothReset,
-- QuestieQuest.lua:352). Only once Questie has started (QuestieInit.lua:373) and never in combat.
-- Each collection has one "apply" table a: { token, partial, off, told, since }.

local START_WAIT = 120                      -- seconds we wait for Questie to start
local RESET_WAIT, POLL = 30, 0.5            -- seconds Questie's rebuild may take; how often we look
local applyToken = 0                        -- goes up on each collection, on "off" and when applied
local waiter = CreateFrame("Frame")
local waiting                               -- the apply that waits for the end of combat

local function QuestieStarted()
    return type(Questie) == "table" and (Questie.started == true
        or type(Questie.API) == "table" and Questie.API.isReady == true)
end

-- Drops Questie's copies and starts its rebuild. Returns QuestieQuest, or nil if Questie lacks
-- what we need. Every quest in the quest log is dropped too, not only those with a new title:
-- SmoothReset keeps a cached quest's objectives (QuestieQuest.lua:394-400, 1467) and their spawn
-- lists (:934, :1017), which hold NPC and item names (QuestieQuestPrivates.lua:111, QuestieDB.lua:1772).
local function ApplyNow()
    local DB, QQ, AQ = Module("QuestieDB"), Module("QuestieQuest"), Module("ActiveQuests")
    if not (DB and type(DB.RefreshAfterCorrectionApply) == "function"
        and QQ and type(QQ.SmoothReset) == "function") then return nil end
    local changed = N.changed
    N.changed = {}
    changed.Quest = changed.Quest or {}
    if AQ and type(AQ.Iterate) == "function" then
        for questId in AQ.Iterate() do changed.Quest[questId] = true end
    end
    for _, dt in ipairs(N.KINDS) do
        if changed[dt] and next(changed[dt]) then DB.RefreshAfterCorrectionApply(dt, changed[dt]) end
    end
    QQ:SmoothReset()
    return QQ
end

local OFF_WORDS = { zones = "місць", Quest = "завдань", Npc = "НІП", Item = "предметів" }

-- One line for the kinds whose route is off in UALL Forever (off = { "Item", ... }), or none.
local function SayOff(off)
    local words = {}
    for _, kind in ipairs(type(off) == "table" and off or {}) do words[#words + 1] = OFF_WORDS[kind] end
    if #words == 0 then return end
    local what = #words > 1 and "ці переклади" or "цей переклад"
    local last = table.remove(words)
    local list = #words > 0 and table.concat(words, ", ") .. " і " .. last or last
    Say("назви " .. list .. " лишаються англійською, бо в налаштуваннях UALL Forever " .. what .. " вимкнено.")
end

local function Ready(shown, partial, off)
    local c = N.counts
    local counts = ("завдання %d, НІП %d, предмети %d, місця %d"):format(tonumber(c.Quest) or 0,
        tonumber(c.Npc) or 0, tonumber(c.Item) or 0, tonumber(c.zones) or 0)
    if shown then
        Say("назви готові й уже видно в Questie: " .. counts .. ". Перезавантажувати гру не треба.")
    else
        Say("назви готові й збережені: " .. counts .. ". Questie не зміг одразу їх показати. "
            .. "Введіть /reload, і вони з'являться.")
    end
    SayOff(off)
    if partial then Say("UALL Forever довго не відповідав, тож решту назв доберу при наступному вході.") end
end

-- Tells the player how it went, once per collection, and nothing after /uadd questie off.
local function Tell(a, shown)
    if a.told then return end
    a.told = true
    if L.state == "on" then Ready(shown, a.partial, a.off) end
end

-- SmoothReset only starts a ticker (QuestieQuest.lua:463): the names show once it has run to the end.
local function WhenShown(a, QQ, waited)
    if not (QQ._isResetting or QQ._resetAgain) then return Tell(a, true) end
    if waited >= RESET_WAIT then return Tell(a, false) end
    C_Timer.After(POLL, function()
        if not U.SafeCall(WhenShown, a, QQ, waited + POLL) then Tell(a, false) end
    end)
end

local TryApply
local function Guarded(a)
    if not U.SafeCall(TryApply, a) then Tell(a, false) end
end

TryApply = function(a)
    if a.token ~= applyToken or L.state ~= "on" or not (db and db.enabled) then return end
    if InCombatLockdown and InCombatLockdown() then
        waiting = a
        waiter:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    if not QuestieStarted() then
        a.since = a.since or GetTime()
        if GetTime() - a.since >= START_WAIT then return Tell(a, false) end
        C_Timer.After(1, function() Guarded(a) end)
        return
    end
    applyToken = applyToken + 1             -- once per collection
    local QQ = ApplyNow()
    if QQ then WhenShown(a, QQ, 0) else Tell(a, false) end
end

waiter:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    local w = waiting
    waiting = nil
    if w then Guarded(w) end
end)

local function CancelApply()
    applyToken = applyToken + 1
    waiting = nil
    waiter:UnregisterEvent("PLAYER_REGEN_ENABLED")
end

-- ── After Questie is ready ────────────────────────────────────────────────────────────────────

local readyDone = false

-- The tracker reads our own names, so it shows them right away; Questie redraws it again after
-- its rebuild (QuestieQuest.lua:441). Any error here still ends with the /reload message.
local function EndOfCollection(a)
    db.collectedOnce = true
    T.Refresh()
    TryApply(a)
end

local function CollectNames(all)
    local a = { token = applyToken + 1 }
    local started, why = N.Start(db, all, function(partial, off)
        a.partial, a.off = partial, off
        if not U.SafeCall(EndOfCollection, a) then Tell(a, false) end
    end)
    if started then applyToken = a.token end
    if started and not db.collectedOnce then
        Say("беру назви завдань, НІП, предметів і місць з UALL Forever. Це йде у фоні, гра не гальмує.")
    end
    return started, why
end

local function OnReady()
    if readyDone then return end
    readyDone = true
    if L.state ~= "on" then return end
    if HF then U.SafeCall(HF.Scan) end                     -- the options tabs exist now
    if not L.IsActive() then
        Say("у налаштуваннях Questie вибрано іншу мову. Українська там зветься «" .. L.LOCALE_NAME .. "».")
        return
    end
    CollectNames(false)
    F.Auto(db)
    F.MaybeHint(db, Say)
end

local function WhenQuestieReady()
    local ok = pcall(function() Questie.API.RegisterOnReady(function() U.SafeCall(OnReady) end) end)
    if not ok then
        -- An older Questie without the API: wait a little after login instead.
        C_Timer.After(15, function() U.SafeCall(OnReady) end)
    end
end

-- ── Start-up ──────────────────────────────────────────────────────────────────────────────────

local function Init()
    db = U.DB("questie")
    if db.enabled == nil then db.enabled = true end
    U.SafeCall(U.RegisterFont)
    if not db.enabled then
        L.state = "off"
        return
    end
    local cache = N.LoadCache(db)
    local state = L.Prepare(cache.zones)
    if state == "on" then
        T.Install()
        N.PublishCached(cache)
        F.Auto(db)
        if HF then U.SafeCall(HF.Start) end
        WhenQuestieReady()
    elseif state == "conflict" then
        Say("інший аддон уже перекладає Questie (мова " .. tostring(L.otherLocale) .. "). UADD нічого не змінює.")
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, _, name)
    if name ~= ADDON then return end
    self:UnregisterEvent("ADDON_LOADED")
    U.SafeCall(Init)
end)

-- ── Status ────────────────────────────────────────────────────────────────────────────────────

local function Status()
    if not db then return "ще не завантажено" end
    if L.state == "off" then return "вимкнено (/uadd questie on)" end
    if L.state == "no-questie" then return "не знайдено Questie" end
    if L.state == "conflict" then return "не працює: Questie вже перекладає інший аддон" end
    local s, c = L.stats, N.counts
    local parts = { ("рядків меню: %d"):format(s.strings) }
    if not N.IsAvailable() then
        parts[#parts + 1] = "назви: англійською (немає UALL Forever)"
    else
        parts[#parts + 1] = ("назви: завдання %d, НІП %d, предмети %d, місця %d")
            :format(c.Quest, c.Npc, c.Item, math.max(c.zones, s.zones))
        local asked, total = N.Progress()
        if asked then parts[#parts + 1] = ("збираю: %d з %d"):format(asked, total) end
    end
    if readyDone and not L.IsActive() then parts[#parts + 1] = "Questie показує іншу мову" end
    if F.IsOn() then parts[#parts + 1] = "шрифт UADD" end
    return table.concat(parts, "; ")
end

-- ── Commands ──────────────────────────────────────────────────────────────────────────────────

local HELP = {
    "/uadd questie on - увімкнути (потім /reload)",
    "/uadd questie off - вимкнути, Questie знову англійською",
    "/uadd questie font - шрифт з кирилицею для списку завдань",
    "/uadd questie font off - повернути старий шрифт",
    "/uadd questie rebuild - заново зібрати назви з UALL Forever",
    "/uadd questie test - перевірити зв'язок з UALL Forever",
}

local function Command(args)
    if not db then return Say("ще не завантажено.") end
    local cmd, rest = args:lower():match("^(%S*)%s*(.-)$")
    if cmd == "on" then
        db.enabled = true
        if L.state == "on" then return Say("вже увімкнено.") end
        Say("увімкнено. Введіть /reload, щоб Questie заговорив українською.")
    elseif cmd == "off" then
        db.enabled = false
        if L.state ~= "on" then return Say("вже вимкнено.") end
        N.Stop()
        CancelApply()
        N.WithdrawAll()
        T.Uninstall()
        F.Off(db)
        if HF then U.SafeCall(HF.Stop) end
        L.SwitchOff()
        L.state = "off"
        T.Refresh()                             -- the tracker is English again at once
        Say("вимкнено. Введіть /reload, щоб уся англійська повернулась у кожне вікно.")
    elseif cmd == "font" then
        if rest == "off" then F.Off(db, Say) else F.On(db, Say) end
    elseif cmd == "rebuild" then
        if L.state ~= "on" then return Say("спершу увімкніть: /uadd questie on, потім /reload.") end
        local started, why = CollectNames(true)
        if started then
            Say("збираю назви заново, у фоні.")
        elseif why == "busy" then
            Say("вже збираю, зачекайте.")
        elseif why == "no-uall" then
            Say("UALL Forever не завантажено або його переклад вимкнено. Назви лишаються англійською.")
        end
    elseif cmd == "test" then
        if ns.UALL and type(ns.UALL.SelfTest) == "function" then
            U.SafeCall(ns.UALL.SelfTest)
        else
            Say("перевірка недоступна.")
        end
    else
        Say(Status())
        for _, line in ipairs(HELP) do U.Print("  " .. line) end
    end
end

U.RegisterModule("questie", { title = "Questie", Status = Status, Command = Command })
