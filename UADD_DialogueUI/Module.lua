-- UADD - DialogueUI: start-up, the status line and "/uadd dialogueui ...".
--
-- DialogueUI's own words (buttons, quest type labels, hints, settings, tooltips, book window, chat
-- lines) in Ukrainian. DialogueUI's locale table is private, so nothing of DialogueUI's is changed:
--   * ui/hashes.lua has hashes of DialogueUI's English for each key (made by tools/make_dui_data.py
--     from the installed DialogueUI), ui/locale.lua our Ukrainian. Words.lua turns a shown English
--     text into Ukrainian.
--   * Screen.lua finds DialogueUI's FontStrings; Texts.lua hooks each one's SetText and keeps its
--     English; Fonts.lua gives our words a font with Ukrainian letters; Chat.lua does chat lines.
--   * DialogueUI - UALL (quest text, titles, NPC names from UALL Forever) goes first: a text that
--     already has Ukrainian letters is never touched, nor are its fonts.
-- While the hold key is held (UADD/Original.lua) the words are English again. "/uadd dialogueui off"
-- puts everything back as DialogueUI had it. On a client that is not English the module does
-- nothing: DialogueUI then shows its own translation, and our English side would not match.

local ADDON, ns = ...
local U = UADD
local db
local ready = false        -- DialogueUI is loaded and the tables are built

local function Say(msg) U.Print("Dialogue UI: " .. msg) end

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

local function Begin()
    if not ns.On() then return end
    U.SafeCall(ns.Chat.Start)
    U.SafeCall(ns.Screen.Install)
    U.SafeCall(ns.Screen.Scan)
end

local function End()
    ns.Screen.Stop()
    U.SafeCall(ns.Chat.Stop)
    if not ns.Screen.WaitCombat() then ns.Screen.Restore() end   -- else when combat ends
end

-- DialogueUI is there (loaded before us, or now): build the word tables once and start.
local function Ready()
    if ready or not db or not Loaded("DialogueUI") then return end
    ready = true
    U.SafeCall(ns.Words.Build)
    Begin()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name == ADDON then
            db = U.DB("dialogueui")
            ns.db = db
            if db.enabled == nil then db.enabled = true end
        end
        if name == ADDON or name == "DialogueUI" then U.SafeCall(Ready) end
    else
        U.SafeCall(Ready)
        if ready then self:UnregisterEvent("ADDON_LOADED") end
    end
end)

-- The hold key: not in combat (the look after combat puts the right words in).
if U.OnOriginal then
    U.OnOriginal(function() if ns.On() and not ns.Screen.WaitCombat() then ns.Texts.Sync() end end,
        "DialogueUI")
end

-- ── Status ────────────────────────────────────────────────────────────────────────────────────

local function Status()
    if not db then return "ще не завантажено" end
    if not EnglishClient() then return "не працює: клієнт не англійський, Dialogue UI має свій переклад" end
    if not ready then return "чекає: Dialogue UI не завантажено" end
    if not db.enabled then return "вимкнено (/uadd dialogueui on)" end
    return ("увімкнено: Dialogue UI українською; слів: %d, текстів перекладено: %d, шрифтів виправлено: %d")
        :format(ns.Words.Count(), ns.Texts.Count(), ns.Fonts.Count())
end

-- ── Commands ──────────────────────────────────────────────────────────────────────────────────

local HELP = {
    "/uadd dialogueui on - Dialogue UI українською",
    "/uadd dialogueui off - вимкнути, Dialogue UI знову такий, як без UADD",
}

local function Command(args)
    if not db then return Say("ще не завантажено.") end
    local cmd = args:lower():match("^(%S*)")
    if cmd == "on" then
        if db.enabled then return Say("вже увімкнено.") end
        db.enabled = true
        Begin()
        Say("увімкнено.")
    elseif cmd == "off" then
        if not db.enabled then return Say("вже вимкнено.") end
        db.enabled = false
        End()
        Say("вимкнено. Dialogue UI знову такий, як без UADD.")
    else
        Say(Status())
        for _, line in ipairs(HELP) do U.Print("  " .. line) end
    end
end

U.RegisterModule("dialogueui", { title = "Dialogue UI", Status = Status, Command = Command })
