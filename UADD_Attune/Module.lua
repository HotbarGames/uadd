-- UADD - Attune: start-up, the status line and "/uadd attune ...".
--
-- Attune's own words (its window, step boxes, tree, Next window, quest panels, settings pages,
-- tooltips, dialogs and chat lines) in Ukrainian on an English client. Attune itself is never changed:
--   * ui/locale.lua, ui/notes.lua and data/hashed.lua hold our Ukrainian only, by Attune's keys or by
--     hashes (tools/make_att_text.py); Pairs.lua reads the English from AttuneLang. Words.lua turns a
--     shown English text into Ukrainian.
--   * Names.lua asks UALL Forever for quest, NPC, item and zone names in the background, a few
--     seconds after login, and keeps them in UADD_DB; a SetText never asks UALL.
--   * Screen.lua finds its FontStrings; Texts.lua hooks each one's SetText and keeps its English;
--     Fonts.lua gives our words a font with Ukrainian letters; Chat.lua does its chat lines,
--     Tooltip.lua its tooltip lines, Popup.lua its StaticPopup dialogs.
--   * AttuneLang, Attune_Data, Attune_DB, the step types it saves, what it sends to other players,
--     the export string and the Survey Log stay English: only what is drawn on screen changes.
-- While the hold key is held (UADD/Original.lua) the words are English again. "/uadd attune off"
-- puts everything back as Attune had it. On a client that is not English the module does nothing.

local ADDON, ns = ...
local U = UADD
local N = ns.Names
local db
local ready = false        -- Attune is loaded and the tables are built
local TARGET = "Attune"

local function Say(msg) U.Print("Attune: " .. msg) end

local function EnglishClient()
    local l = type(GetLocale) == "function" and GetLocale() or "enUS"
    return l == "enUS" or l == "enGB"
end

local function Loaded(name)
    local fn = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    local ok, yes = pcall(fn, name)
    return ok and yes and true or false
end

function ns.On() return ready and db ~= nil and db.enabled == true and EnglishClient() end
function ns.WordsWanted() return ns.On() and not U.originalShown end

-- New names from UALL Forever: the shown texts once more (not in combat: then after it).
function ns.OnNames()
    if not ns.On() or ns.Screen.WaitCombat() then return end
    U.SafeCall(ns.Texts.Renew)
    ns.Screen.Queue(false)
end

local function Begin()
    if not ns.On() then return end
    U.SafeCall(ns.Chat.Start)
    U.SafeCall(ns.Tooltip.Install)
    U.SafeCall(ns.Popup.Install)
    U.SafeCall(ns.Screen.Install)
    U.SafeCall(ns.Screen.Scan)
end

local function End()
    N.Stop()
    U.SafeCall(ns.Chat.Stop)
    if not ns.Screen.WaitCombat() then ns.Screen.Restore() end   -- else when combat ends
end

local function Collect(all)
    if not ns.On() then return false, "off" end
    return N.Start(db, all, function(partial)
        if partial then Say("назви збиралися надто довго, решту доберу при наступному вході.") end
    end)
end

-- Attune is there (loaded before us, or now): build the word tables once, the saved names, start.
local function Ready()
    if ready or not db or not Loaded(TARGET) or not EnglishClient() then return end
    ready = true
    U.SafeCall(ns.Words.Build)
    -- English texts it shows without our words are noted (UADD/Missed.lua); fixed ones go now.
    -- Names from Attune's own tables (quests, items, NPCs, zones, attunements) are not misses.
    local own
    U.SafeCall(U.MissedModule, "attune", { addon = TARGET, test = function(t) return ns.Words.Text(t) end,
        keep = function(_, c)
            own = own or N.Own()
            return own[c:match("^%s*(.-)%s*$")] == true
        end })
    U.SafeCall(function() N.Use(N.LoadCache(db)) end)
    Begin()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name == ADDON then
            db = U.DB("attune")
            ns.db = db
            if db.enabled == nil then db.enabled = true end
        end
        if name == ADDON or name == TARGET then U.SafeCall(Ready) end
    else
        U.SafeCall(Ready)
        if ns.On() then U.SafeCall(ns.Screen.Install) end   -- Attune makes some frames at login
        if ready then self:UnregisterEvent("ADDON_LOADED") end
        C_Timer.After(3, function() U.SafeCall(Collect, false) end)
    end
end)

-- The hold key: every known text changes now, hidden ones too; not in combat.
if U.OnOriginal then
    U.OnOriginal(function(show)
        if not ns.On() or ns.Screen.WaitCombat() then return end
        ns.Texts.Sync()
        ns.Tooltip.Sync(show)
        ns.Popup.Sync()
    end, "Attune")
end

-- ── Status ────────────────────────────────────────────────────────────────────────────────────

local function Status()
    if not db then return "ще не завантажено" end
    if not EnglishClient() then return "не працює: клієнт не англійський" end
    if not ready then return "чекає: Attune не завантажено" end
    if not db.enabled then return "вимкнено (/uadd attune on)" end
    local parts = { ("увімкнено: Attune українською; слів: %d, текстів перекладено: %d, шрифтів виправлено: %d")
        :format(ns.Words.Count(), ns.Texts.Count(), ns.Fonts.Count()) }
    if not N.IsAvailable() then
        parts[#parts + 1] = "назви: англійською (немає ні UALL Forever, ні ClassicUA)"
    else
        local c = N.counts
        parts[#parts + 1] = ("назви: завдання %d, НІП %d, предмети %d, зони %d, інше %d")
            :format(c.Quest, c.Npc, c.Item, c.zones, c.Text)
        local asked, total = N.Progress()
        if asked then parts[#parts + 1] = ("збираю: %d з %d"):format(asked, total) end
    end
    return table.concat(parts, "; ")
end

-- ── Commands ──────────────────────────────────────────────────────────────────────────────────

local HELP = {
    "/uadd attune on - Attune українською",
    "/uadd attune off - вимкнути, Attune знову такий, як без UADD",
    "/uadd attune rebuild - заново зібрати назви з UALL Forever або ClassicUA",
}

local function Command(args)
    if not db then return Say("ще не завантажено.") end
    local cmd = args:lower():match("^(%S*)")
    if cmd == "on" then
        if db.enabled then return Say("вже увімкнено.") end
        db.enabled = true
        Begin()
        U.SafeCall(Collect, false)
        Say("увімкнено.")
    elseif cmd == "off" then
        if not db.enabled then return Say("вже вимкнено.") end
        db.enabled = false
        End()
        Say("вимкнено. Attune знову такий, як без UADD.")
    elseif cmd == "rebuild" then
        if not ns.On() then return Say("спершу увімкніть: /uadd attune on.") end
        local started, why = Collect(true)
        if started then
            Say("збираю назви заново, у фоні.")
        elseif why == "busy" then
            Say("вже збираю, зачекайте.")
        else
            Say("ні UALL Forever, ні ClassicUA не завантажено, або їхній переклад вимкнено. Назви лишаються англійською.")
        end
    else
        Say(Status())
        for _, line in ipairs(HELP) do U.Print("  " .. line) end
    end
end

U.RegisterModule("attune", { title = "Attune", Status = Status, Command = Command })
