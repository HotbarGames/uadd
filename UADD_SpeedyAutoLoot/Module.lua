-- UADD - Speedy AutoLoot (no locale table: its words are in its code). What we change:
--   * Chat (U.ChatLines, prefix mode): a line that starts with its name (FNAME) or a help line's start (HELP)
--     gets ours for the rest; any other line is let through before any lookup (lesson 12). The sound line's
--     number is put back into our template.
--   * The anchor's label: ours when on, its English back when off.
--   * The test entries shown while the anchor moves: only an entry the addon marks as a test; a real loot
--     line (the game's item name) is never ours.
-- Our words get a Ukrainian font (read back, lesson 2). data/text01.lua keeps only UADD.Hash of the English
-- (no licence file: all rights reserved). Off, or the hold key held: English. Not an English client: nothing.

local ADDON, ns = ...
local U = UADD
local db
local ready = false
local TARGET = "SpeedyAutoLoot"
local NAME = "Speedy AutoLoot"
local FNAME = "|cffEEE4AESpeedy AutoLoot:|r "     -- what the addon puts in front of its chat lines
local HELP = "  |cff58C6FA/sal "                   -- how each line of its /sal help starts
local ANCHOR = "SpeedyAutoLoot_LootDisplayAnchor"
local TEST = "^(|cffffffff%+%d+|r |c%x%x%x%x%x%x%x%x)(.-)(|r)$"   -- a test entry: count, colour, name

ns.AL = ns.AL or {}
ns.SORT = ns.SORT or {}
local T, S = ns.AL, ns.SORT

local function Say(msg) U.Print(NAME .. ": " .. msg) end

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

-- ── Words ─────────────────────────────────────────────────────────────────────────────────────

-- A text's shape: each number outside a colour code is a %s slot (a % is %%), and the numbers in order.
local function Shape(s)
    local parts, vals, i = {}, {}, 1
    while i <= #s do
        local a, b = s:find("|c%x%x%x%x%x%x%x%x", i)
        local seg = s:sub(i, (a or #s + 1) - 1)
        seg = seg:gsub("%%", "%%%%"):gsub("%d+", function(d) vals[#vals + 1] = d return "%s" end)
        parts[#parts + 1] = seg
        if not a then break end
        parts[#parts + 1] = s:sub(a, b)
        i = b + 1
    end
    return table.concat(parts), vals
end

-- Our Ukrainian for one of its texts, or nil (the line stays English). A template is filled only when each
-- of its slots holds a value (tools/sal_rules.py SORTS).
local function Lookup(s)
    s = U.Plain(s)
    if not s or s == "" then return nil end
    local k = "Code." .. U.Hash(s)
    if T[k] and not S[k] then return T[k] end
    if not s:find("%d") then return nil end
    local shape, vals = Shape(s)
    k = "Code." .. U.Hash(shape)
    local uk, sorts = T[k], S[k]
    if not uk or type(sorts) ~= "string" or #sorts ~= #vals or sorts:find("[^v]") then return nil end
    local ok, out = pcall(string.format, uk, (unpack or table.unpack)(vals))
    return ok and out or nil
end
ns.Lookup = Lookup

-- Words left once colour codes and slash commands are gone: a line with none is no text to translate.
local function Words(s)
    return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("/%w+", ""):find("%a%a")) ~= nil
end

local function Translate(s)
    local uk = Lookup(s)
    if not uk and U.MissedOn() and type(s) == "string" and Words(s) then U.Missed("sal", s) end
    return uk
end
ns.Translate = Translate

ns.Words = { Translate = Translate }      -- one table for both hooks (the harness counts its calls)
ns.ChatName = U.ChatLines({ prefix = FNAME, words = ns.Words, wanted = ns.WordsWanted })
ns.ChatHelp = U.ChatLines({ prefix = HELP, words = ns.Words, wanted = ns.WordsWanted })

-- ── The loot display ──────────────────────────────────────────────────────────────────────────

local D = { saved = {}, owner = {}, en = {}, count = 0, busy = false, label = nil, hooked = false }
ns.Display = D

local function Anchor()
    local a = rawget(_G, ANCHOR)
    return type(a) == "table" and a or nil
end

-- Our font on fs (its own kept); true when the font has Ukrainian letters.
local function CyrOn(fs)
    local path = U.CyrFontPath()
    local _, s, f = fs:GetFont()
    if not path or not s then return false end
    if not D.saved[fs] then D.saved[fs] = U.SaveFont(fs) end
    fs:SetFont(path, s, f or "")
    return U.IsCyrFont((fs:GetFont()))
end

local function FontBack(fs)
    local o = D.saved[fs]
    if not o then return end
    D.saved[fs] = nil
    U.FontBack(fs, o)          -- its font object, not a pinned file (lesson 18)
end

local function Put(fs, text)
    D.busy = true
    pcall(fs.SetText, fs, text)
    D.busy = false
end

-- An entry's text was just written. Cheap test first: only an entry the addon marks as a test is ours.
local function OnText(fs, text)
    if D.busy then return end
    local b = D.owner[fs]
    if not (b and b.isPermanent) then
        D.en[fs] = nil
        if D.saved[fs] then FontBack(fs) end
        return
    end
    text = U.Plain(text)
    local head, name, tail = nil, nil, nil
    if text then head, name, tail = text:match(TEST) end
    local uk = name and T["Code." .. U.Hash(name)]
    if not uk then
        D.en[fs] = nil
        FontBack(fs)
        return
    end
    D.en[fs] = text
    if not ns.WordsWanted() then FontBack(fs) return end
    if not CyrOn(fs) then return end
    Put(fs, head .. uk .. tail)
    D.count = D.count + 1
end
D.OnText = OnText

-- The frame that holds the entries: the one anchored to the anchor.
local function Holder(a)
    if type(UIParent) ~= "table" or not UIParent.GetChildren then return nil end
    for _, c in ipairs({ UIParent:GetChildren() }) do
        if c ~= a and type(c) == "table" and c.GetPoint then
            local ok, _, rel = pcall(c.GetPoint, c, 1)
            if ok and rel == a then return c end
        end
    end
end

function D.Install()
    local a = Anchor()
    if D.hooked or not a then return end
    local h = Holder(a)
    if not h or not h.GetChildren then return end
    local n = 0
    for _, b in ipairs({ h:GetChildren() }) do
        local fs = type(b) == "table" and b.Text
        if type(fs) == "table" and fs.SetText and not D.owner[fs] then
            D.owner[fs] = b
            hooksecurefunc(fs, "SetText", OnText)
            n = n + 1
        end
    end
    D.hooked = n > 0
end

-- The anchor's label and the shown test entries: ours when wanted, the English and its font otherwise.
function D.Apply()
    local a = Anchor()
    local fs = a and a.text
    if type(fs) == "table" and fs.GetText then
        if D.label == nil then D.label = U.Plain(fs:GetText()) or false end
        local en = D.label
        local uk = en and T["Code." .. U.Hash(en)]
        if uk and ns.WordsWanted() and CyrOn(fs) then
            fs:SetText(uk)
        elseif en then
            fs:SetText(en)
            FontBack(fs)
        end
    end
    local shown = {}
    for f, en in pairs(D.en) do shown[f] = en end
    for f, en in pairs(shown) do f:SetText(en) end     -- the hook puts ours on again, or the font back
end

function D.Count()
    local n = D.count
    local a = Anchor()
    if a and a.text and D.saved[a.text] then n = n + 1 end
    return n
end

-- ── On and off ────────────────────────────────────────────────────────────────────────────────

local function Begin()
    if not ns.On() then return end
    U.SafeCall(ns.ChatName.Install)
    U.SafeCall(ns.ChatHelp.Install)
    U.SafeCall(D.Install)
    U.SafeCall(D.Apply)
end

local function End()
    U.SafeCall(D.Apply)
    U.SafeCall(ns.ChatHelp.Restore)
    U.SafeCall(ns.ChatName.Restore)
end
ns.Begin, ns.End = Begin, End

-- Texts it keeps English on purpose, for U.Missed: a line with no words beyond slash commands.
local function Keep(_, plain)
    return type(plain) == "string" and not Words(plain)
end

local function Ready()
    if ready or not db or not Loaded(TARGET) then return end
    ready = true
    U.SafeCall(U.MissedModule, "sal", { addon = TARGET, keep = Keep,
        test = function(t) return Lookup(t) ~= nil end })
    Begin()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == ADDON then
            db = U.DB("sal")
            ns.db = db
            if db.enabled == nil then db.enabled = true end
            U.SafeCall(Ready)
        end
    else
        U.SafeCall(Ready)
        if ns.On() then U.SafeCall(D.Install) end      -- in case its frames came after us
    end
end)

-- The hold key: its English while it is held, ours again after.
if U.OnOriginal then
    U.OnOriginal(function()
        if not ns.On() then return end
        D.Apply()
    end, NAME)
end

-- ── Status ────────────────────────────────────────────────────────────────────────────────────

local function Status()
    if not db then return "ще не завантажено" end
    if not EnglishClient() then return "не працює: клієнт не англійський" end
    if not ready then return "чекає: Speedy AutoLoot не завантажено" end
    if not db.enabled then return "вимкнено (/uadd sal on)" end
    return ("увімкнено: Speedy AutoLoot українською; рядків чату наших: %d, на показі здобичі: %d")
        :format(ns.ChatName.Count() + ns.ChatHelp.Count(), D.Count())
end

-- ── Commands ──────────────────────────────────────────────────────────────────────────────────

local LINES = {
    "/uadd sal on - Speedy AutoLoot українською",
    "/uadd sal off - вимкнути, Speedy AutoLoot знову англійською",
    "Назви предметів лишаються такими, як їх дає гра. Команди /sal - англійською.",
}

local function Command(args)
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
        Say("вимкнено. Speedy AutoLoot знову англійською.")
    else
        Say(Status())
        for _, line in ipairs(LINES) do U.Print("  " .. line) end
    end
end

U.RegisterModule("sal", { title = NAME, Status = Status, Command = Command })
