-- UADD - Dungeon Journal: start-up, the status line and "/uadd dj ...".
--
-- At our ADDON_LOADED (after FDJ's, it is a dependency) we load the saved names and wrap FDJ's
-- language (Language.lua). FDJ builds its window at PLAYER_LOGIN; a frame later we add
-- «Українська» to its language menu and hook its search. A few seconds after login we collect
-- the names UALL Forever knows, in the background; each kind shows as soon as it is done.

local ADDON, ns = ...
local U = UADD
local N, L, Screen, Search = ns.Names, ns.Lang, ns.Screen, ns.Search
local db
local loggedIn = false

local function Say(msg) U.Print("Журнал підземель: " .. msg) end

-- Names arrived: a new content table, then the open page again.
function ns.OnNames()
    L.NewNames()
    if L.Active() then L.Light() end
end

local function Collect(all)
    local started, why = N.Start(db, all, function(partial)
        if partial then Say("назви збиралися надто довго, решту доберу при наступному вході.") end
    end)
    return started, why
end

local function AfterLogin()
    if not (db and db.enabled) then return end
    U.SafeCall(L.AddEntry)
    U.SafeCall(Search.Install)
    U.SafeCall(ns.Prose.HookNotes)
    Screen.Schedule()
end

local function Init()
    db = U.DB("dj")
    ns.db = db
    if db.enabled == nil then db.enabled = true end
    U.SafeCall(U.RegisterFont)
    N.Load(db)
    if db.enabled and not L.Install() then
        Say("не знайшов Dungeon Journal, лишаю його як є.")
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name ~= ADDON then return end
        self:UnregisterEvent("ADDON_LOADED")
        U.SafeCall(Init)
    else
        loggedIn = true
        C_Timer.After(0, AfterLogin)
        C_Timer.After(3, function()
            if db and db.enabled then U.SafeCall(Collect, false) end
        end)
    end
end)

if U.OnOriginal then U.OnOriginal(function(show) U.SafeCall(L.OnOriginal, show) end) end

-- ── Status ────────────────────────────────────────────────────────────────────────────────────

local function Status()
    if not db then return "ще не завантажено" end
    if not db.enabled then return "вимкнено (/uadd dj on)" end
    local parts = { L.Wants() and "мова журналу: українська" or "у журналі вибрано іншу мову" }
    if not U.Collector.IsAvailable() then
        parts[#parts + 1] = "назви: англійською (немає ні UALL Forever, ні ClassicUA)"
    else
        local c = N.Counts()
        parts[#parts + 1] = ("назви: підземелля %d з %d, боси й НІП %d, завдання %d, предмети %d")
            :format(c.dungeons, c.dungeonsTotal, c.Npc, c.Quest, c.Item)
        local asked, total = N.Progress()
        if asked then parts[#parts + 1] = ("збираю: %d з %d"):format(asked, total) end
    end
    return table.concat(parts, "; ")
end

-- ── Commands ──────────────────────────────────────────────────────────────────────────────────

local HELP = {
    "/uadd dj on - увімкнути українську в журналі підземель",
    "/uadd dj off - вимкнути, журнал знову такий, як без UADD",
    "/uadd dj rebuild - заново зібрати назви з UALL Forever або ClassicUA",
}

local function Command(args)
    if not db then return Say("ще не завантажено.") end
    local cmd = args:lower():match("^(%S*)")
    if cmd == "on" then
        if db.enabled then return Say("вже увімкнено.") end
        db.enabled = true
        L.Install()
        if loggedIn then
            AfterLogin()
            U.SafeCall(L.Redraw)
            U.SafeCall(Collect, false)
        end
        Say(L.Wants() and "увімкнено." or "увімкнено. Українську можна вибрати в меню мов журналу.")
    elseif cmd == "off" then
        if not db.enabled then return Say("вже вимкнено.") end
        db.enabled = false
        N.Stop()
        ns.held = false
        ns.Fonts.Restore()
        U.SafeCall(L.Redraw)           -- the wrappers pass FDJ's answers through from now on
        L.Uninstall()
        Say("вимкнено. Журнал знову такий, як без UADD.")
    elseif cmd == "rebuild" then
        if not db.enabled then return Say("спершу увімкніть: /uadd dj on.") end
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

U.RegisterModule("dj", { title = "Dungeon Journal", Status = Status, Command = Command })
