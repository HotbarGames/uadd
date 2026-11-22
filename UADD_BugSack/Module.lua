-- UADD - BugSack: its sack window, options tab, tooltips, chat lines and send popup in Ukrainian.
--
-- Words.lua: our words and its locale table; Screen.lua: its window. Here: the send popup (U.Popups), on and off,
-- the hold key, status and commands. Off and the hold key: English and fonts back, only where ours still shows
-- (lesson 23). Not an English client: nothing.

local ADDON, ns = ...
local U = UADD
local st = ns.st
local KEY, TARGET, TITLE = ns.KEY, ns.TARGET, ns.TITLE

local function Say(msg) U.Print(TITLE .. ": " .. msg) end
local function Loaded(name)
    local fn = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    local ok, yes = pcall(fn, name)
    return ok and yes and true or false
end

-- ── The send popup ───────────────────────────────────────────────────────────────────────────

local back, nback = {}, 0
local function PopText(now)
    -- The core helper sets the text without looking at the font: no Cyrillic font, no Ukrainian.
    if type(U.CyrFontPath) ~= "function" or type(U.CyrFontPath()) ~= "string" then return nil end
    local uk = ns.PopUk(now)
    if uk then
        if nback >= 50 then back, nback = {}, 0 end
        if back[uk] == nil then nback = nback + 1 end
        back[uk] = now
    end
    return uk
end
local function PopEnglish(uk) return back[uk] end

local popupsOk = type(U.Popups) == "table" and type(U.Popups.Register) == "function"
if popupsOk then
    U.Popups.Register(KEY, {
        names = { [ns.POPUP] = true }, globals = { CLOSE = "ui.close" }, text = PopText, english = PopEnglish,
        wanted = ns.WordsWanted, fix = ns.CyrOn, back = ns.FontBack,
    })
end

-- ── On and off ───────────────────────────────────────────────────────────────────────────────

local function Sync()
    local want = ns.WordsWanted()
    U.SafeCall(ns.Words, want)
    U.SafeCall(ns.Apply, want)
    if popupsOk then U.SafeCall(U.Popups.Sync, KEY) end
end
local function Begin()
    if not ns.On() then return end
    U.SafeCall(ns.Wrap, "OpenSack")
    U.SafeCall(ns.Wrap, "OpenConfig")
    Sync()
end
local function End()              -- off (db.enabled is false by now): everything of ours out
    U.SafeCall(ns.Words, false)
    if popupsOk then U.SafeCall(U.Popups.Off, KEY) end
    U.SafeCall(ns.Apply, false)
end
ns.Sync, ns.Begin, ns.End = Sync, Begin, End

local function Ready()
    if st.ready or not st.db or not Loaded(TARGET) then return end
    local A = rawget(_G, TARGET)
    local L = type(A) == "table" and A.L or nil
    if type(L) ~= "table" then return end
    st.ready = true
    ns.Bind(A, L)
    U.SafeCall(U.MissedModule, KEY, { addon = TARGET, keep = function(t) return ns.STAY[U.Hash(t)] == true end,
        test = function(t) return ns.Translate(t) ~= nil or ns.UK[t] ~= nil end })
    Begin()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name ~= ADDON then return end
        local db = U.DB(KEY)
        st.db, ns.db = db, db
        if db.enabled == nil then db.enabled = true end
        U.SafeCall(Ready)
    else
        U.SafeCall(Ready)
        if ns.On() then C_Timer.After(0, function() U.SafeCall(Begin) end) end
    end
end)

-- The hold key: its English while it is held, ours again after.
if U.OnOriginal then U.OnOriginal(function() if ns.On() then Sync() end end, TITLE) end

-- ── Status and commands ──────────────────────────────────────────────────────────────────────

local function Status()
    local db = st.db
    if not db then return "ще не завантажено" end
    if not ns.EnglishClient() then return "не працює: клієнт не англійський" end
    if not st.ready then return "чекає: " .. TITLE .. " не завантажено" end
    if not db.enabled then return "вимкнено (/uadd bs on)" end
    local pops = popupsOk and (U.Popups.Count(KEY) + U.Popups.FieldCount(KEY)) or 0
    return ("увімкнено: %s українською; слів у його таблиці: %d, у вікні: %d, у вікні надсилання: %d")
        :format(TITLE, ns.Swapped(), ns.Shown(), pops)
end

local HELP = { "/uadd bs on - " .. TITLE .. " українською", "/uadd bs off - вимкнути, " .. TITLE .. " знову англійською" }
local function Command(args)
    local db = st.db
    if not db then return Say("ще не завантажено.") end
    local cmd = (args or ""):lower():match("^(%S*)")
    if cmd == "on" then
        if db.enabled then return Say("вже увімкнено.") end
        db.enabled = true
        Begin()
        Say("увімкнено.")
    elseif cmd == "off" then
        if not db.enabled then return Say("вже вимкнено.") end
        db.enabled = false
        End()
        Say("вимкнено. " .. TITLE .. " знову англійською.")
    else
        Say(Status())
        for _, line in ipairs(HELP) do U.Print("  " .. line) end
    end
end

U.RegisterModule(KEY, { title = TITLE, Status = Status, Command = Command })
