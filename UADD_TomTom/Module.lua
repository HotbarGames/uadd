-- UADD - TomTom: start-up, the status line and "/uadd tomtom ...".
--
-- TomTom keeps its words in TomTom.L (each key is its English) and stays on English. We change what it
-- shows with UADD's shared engine, by three routes:
--   * Into L (ns.SwapIn): a text with no slots, and a template whose slots hold only values or free
--     names and whose Ukrainian has no plural (the swap list S made by tools/make_tt_text.py), is put
--     into TomTom.L itself, when our addon loads (before TomTom builds its settings at login). TomTom
--     then shows it everywhere. The keep list K stays English in L: TomTom also shows those texts in
--     its data feed, in another addon's bar and font.
--   * Whole lines (ns.Words, UADD/Words.lua over data/*.lua): a template with a game name, our own
--     word or a plural in a slot stays English in L and is translated as a finished line where it
--     shows: its chat lines (ns.Chat), its tooltip lines (ns.Tips), the arrow's distance line (here).
--   * After load: its pop-ups (ns.Popups in Settings.lua), defined when TomTom loads, before our words
--     are in L. Settings.lua translates what its settings pages get from code, not from L; Fonts.lua gives every
--     shown Ukrainian text a font with Ukrainian letters (read back, lesson 2).
-- Zone and quest names come from UALL Forever; without one the whole line stays English. Waypoint titles
-- and other text the player wrote stay as they are; a title that is its waypoint's map name (OpenMap's pin
-- with no note) is that map's name from ClassicUA or UALL Forever, on the arrow and the pin's tooltip
-- (Title.lua). The words /way and /ttpaste read stay English.
-- While the hold key is held (UADD/Original.lua) new texts are English. "/uadd tomtom off" puts TomTom.L
-- and the pop-ups back as TomTom had them; settings pages built already change after /reload. On a client
-- that is not English the module does nothing.

local ADDON, ns = ...
local U = UADD
local db
local ready = false
local TARGET = "TomTom"
local FROM = "AddOns[/\\]TomTom[/\\]"
local PREFIX = "|cFF33FF99TomTom|r: "         -- what TomTom puts in front of its chat lines

ns.TT = ns.TT or { exact = {}, templates = {}, swap = {}, keep = {} }
ns.TT.swap = ns.TT.swap or {}
ns.TT.keep = ns.TT.keep or {}
ns.Words = U.NewWords(ns.TT)
ns.FROM = FROM

local function Say(msg) U.Print("TomTom: " .. msg) end

local function EnglishClient()
    local l = type(GetLocale) == "function" and GetLocale() or "enUS"
    return l == "enUS" or l == "enGB"
end

local function Loaded(name)
    local fn = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    local ok, yes = pcall(fn, name)
    return ok and yes and true or false
end

local function Addon() local a = rawget(_G, TARGET) return type(a) == "table" and a or nil end
ns.Addon = Addon

function ns.On() return ready and db ~= nil and db.enabled == true and EnglishClient() end
function ns.WordsWanted() return ns.On() and not U.originalShown end

local function Key(s) return #s .. ":" .. U.Hash(s) end

-- Our Ukrainian for one of TomTom's L texts, as it goes into L (the same slots), or nil.
local function Swap(en)
    if type(en) ~= "string" or en == "" then return nil end
    local k = Key(en)
    if ns.TT.keep[k] then return nil end
    local ix = ns.Words.Index()
    local uk = ix and ix.Exact and ix:Exact(en)
    if type(uk) ~= "string" then uk = ns.TT.swap[k] end
    if type(uk) == "string" and uk ~= "" and uk ~= en then return uk end
    return nil
end
ns.Swap = Swap

-- ── TomTom.L ──────────────────────────────────────────────────────────────────────────────────

local saved, swapped = {}, 0                   -- key -> TomTom's own value; how many are ours now

function ns.SwapIn()
    local A = Addon()
    local L = A and rawget(A, "L")
    if type(L) ~= "table" or not ns.WordsWanted() then return end
    local n = 0
    for en, v in pairs(L) do
        if type(en) == "string" then
            local own = saved[en]
            if own == nil then own = v end
            local uk = (type(own) == "string" or own == true) and Swap(en)
            if uk then
                saved[en] = own
                rawset(L, en, uk)
                n = n + 1
            end
        end
    end
    swapped = n
end

function ns.SwapOut()
    local A = Addon()
    local L = A and rawget(A, "L")
    if type(L) ~= "table" then return end
    for en, own in pairs(saved) do rawset(L, en, own) end
    wipe(saved)
    swapped = 0
end

function ns.Swapped() return swapped end

-- ── The arrow's distance line ─────────────────────────────────────────────────────────────────

-- TomTom writes it on every frame, mostly the same text: the last English and its Ukrainian (false: none)
-- are kept, so a frame with the same text costs one compare, not a translate (lesson 12).
local Arrow = { busy = false, hooked = false, count = 0, en = nil, uk = false }
ns.Arrow = Arrow

function Arrow.OnStatus(fs, text)
    if Arrow.busy then return end
    text = U.Plain(text)                            -- a secret string is no text of ours (no compare on it)
    if not text or not ns.WordsWanted() then return end
    if text ~= Arrow.en then
        local ok, uk = pcall(ns.Words.Translate, text)
        Arrow.en, Arrow.uk = text, ok and type(uk) == "string" and uk ~= text and uk or false
    end
    local uk = Arrow.uk
    if not uk then return end
    Arrow.busy = true                               -- TomTom just wrote the English: ours back on it
    pcall(fs.SetText, fs, uk)
    Arrow.busy = false
    Arrow.count = Arrow.count + 1
end

function Arrow.Install()
    local w = rawget(_G, "TomTomCrazyArrow")
    local fs = type(w) == "table" and w.status
    if Arrow.hooked or type(fs) ~= "table" or not fs.SetText then return end
    Arrow.hooked = true
    hooksecurefunc(fs, "SetText", function(f, t) U.SafeCall(Arrow.OnStatus, f, t) end)
end

-- The arrow's title (a waypoint named after its map): Title.lua, loaded before this file.
local Title = ns.Title

-- ── Tooltips and chat ─────────────────────────────────────────────────────────────────────────

-- The pin tooltip's "zone (x, y)" line (tools/tt_rules.py SORTS 15) has no word to find it by, so it is read
-- by its shape: UALL Forever's zone name, else the line stays English.
local COORDS = "^(.-)( %(%-?%d+%.%d%d, %-?%d+%.%d%d%))$"
local function Coords(s)
    local zone, xy = s:match(COORDS)
    local ua = zone and zone ~= "" and ns.Words.Name and ns.Words.Name(zone)
    return ua and ua ~= zone and (ua .. xy) or nil
end
-- Maybe: the cheap first test on every line of the game's tooltips (lesson 12): our words, or the
-- coordinates line's shape. A line that fails it never reaches Translate.
ns.Tips = U.TipLines({ tips = { "GameTooltip" }, own = { "TomTomTooltip" }, from = FROM, wanted = ns.WordsWanted,
    missed = "tomtom", words = {
        Translate = function(s) return ns.Words.Translate(s) or Coords(s) or ns.TipPlace(s) end,
        Maybe = function(s) return ns.Words.Maybe(s) or (type(s) == "string" and s:find(COORDS) ~= nil) end } })
ns.Chat = U.ChatLines({ prefix = PREFIX, words = ns.Words, wanted = ns.WordsWanted })
ns.ChatPlain = U.ChatLines({ from = FROM, words = ns.Words, wanted = ns.WordsWanted })

-- ── On and off ────────────────────────────────────────────────────────────────────────────────

local function Begin()
    if not ns.On() then return end
    U.SafeCall(ns.SwapIn)
    U.SafeCall(ns.Popups.Apply)
    U.SafeCall(ns.Settings.Install)
    U.SafeCall(Arrow.Install)
    U.SafeCall(Title.Install)
    U.SafeCall(ns.Tips.Install)
    U.SafeCall(ns.Chat.Install)
    U.SafeCall(ns.ChatPlain.Install)
    U.SafeCall(ns.Fonts.Install)
    U.SafeCall(ns.Fonts.Scan)
    U.SafeCall(Title.Redo)
    U.SafeCall(ns.Fonts.Sync)
end

local function End()
    U.SafeCall(Title.Restore)
    U.SafeCall(ns.SwapOut)
    U.SafeCall(ns.Popups.Restore)
    U.SafeCall(ns.Fonts.Sync)
    U.SafeCall(ns.Fonts.Restore)
    U.SafeCall(ns.Tips.Restore)
    U.SafeCall(ns.ChatPlain.Restore)
    U.SafeCall(ns.Chat.Restore)
end
ns.Begin, ns.End = Begin, End

-- Texts it keeps English on purpose, for U.Missed: one word alone (a name, a key), a number.
local function Keep(_, plain)
    return type(plain) == "string" and not plain:find("%s")
end

local function Ready()
    if ready or not db or not Loaded(TARGET) or not Addon() then return end
    ready = true
    U.SafeCall(U.MissedModule, "tomtom", { addon = TARGET, keep = Keep,
        test = function(t) return Swap(t) ~= nil or ns.Words.Translate(t) ~= nil end })
    Begin()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == ADDON then
            db = U.DB("tomtom")
            ns.db = db
            if db.enabled == nil then db.enabled = true end
            U.SafeCall(Ready)
        end
    else
        U.SafeCall(Ready)
        if ns.On() then
            U.SafeCall(ns.Popups.Apply)
            U.SafeCall(Arrow.Install)
            U.SafeCall(Title.Install)
            U.SafeCall(Title.Redo)
            U.SafeCall(ns.Chat.Install)
            U.SafeCall(ns.ChatPlain.Install)
            U.SafeCall(ns.Tips.Install)
            U.SafeCall(ns.Fonts.Install)
            U.SafeCall(ns.Fonts.Scan)
        end
    end
end)

-- The hold key: the English in L and the pop-ups while it is held, our words again after.
if U.OnOriginal then
    U.OnOriginal(function()
        if not ns.On() then return end
        if U.originalShown then
            U.SafeCall(Title.Restore)
            U.SafeCall(ns.SwapOut)
            U.SafeCall(ns.Popups.Restore)
        else
            U.SafeCall(ns.SwapIn)
            U.SafeCall(ns.Popups.Apply)
            U.SafeCall(Title.Redo)
        end
        U.SafeCall(ns.Fonts.Sync)
    end, "TomTom")
end

-- ── Status ────────────────────────────────────────────────────────────────────────────────────

local function Status()
    if not db then return "ще не завантажено" end
    if not EnglishClient() then return "не працює: клієнт не англійський" end
    if not ready then return "чекає: TomTom не завантажено" end
    if not db.enabled then return "вимкнено (/uadd tomtom on)" end
    return ("увімкнено: TomTom українською; текстів: %d, у TomTom.L наших: %d, на екрані з нашим шрифтом: %d")
        :format(ns.Words.Count(), swapped, ns.Fonts.Count())
end

-- ── Commands ──────────────────────────────────────────────────────────────────────────────────

local HELP = {
    "/uadd tomtom on - TomTom українською",
    "/uadd tomtom off - вимкнути, TomTom знову англійською",
    "Сторінки налаштувань змінюються після /reload.",
}

local function Command(args)
    if not db then return Say("ще не завантажено.") end
    local cmd = (args or ""):lower():match("^(%S*)")
    if cmd == "on" then
        if db.enabled then return Say("вже увімкнено.") end
        db.enabled = true
        Begin()
        Say("увімкнено. Сторінки налаштувань будуть українською після /reload.")
    elseif cmd == "off" then
        if not db.enabled then return Say("вже вимкнено.") end
        db.enabled = false
        End()
        Say("вимкнено. TomTom знову англійською; сторінки налаштувань після /reload.")
    else
        Say(Status())
        for _, line in ipairs(HELP) do U.Print("  " .. line) end
    end
end

U.RegisterModule("tomtom", { title = "TomTom", Status = Status, Command = Command })
