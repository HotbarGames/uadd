-- UADD - Wowhead Quick Link: its link popup, its two key binding names and its /wql window in Ukrainian.
--
-- Ours are keyed by UADD.Hash of each English text (data/text01.lua). The link popup (U.Popups): our header
-- ("Wowhead: <type>") or a site name as it is; a header or type with no word keeps the whole popup English. The
-- two key binding names: the globals the key bindings page reads. The /wql window's title and labels, on our
-- font; what the player typed and the URL are never touched (lesson 13). Off and the hold key: English and fonts
-- back, only where ours still shows (lesson 23). Not an English client: nothing. No English of it is stored here.

local ADDON, ns = ...
local U = UADD
local db
local ready = false
local KEY, TARGET, TITLE = "wql", "WowheadQuickLink", "Wowhead Quick Link"
local POPUP, CONFIG = "WowheadQuickLinkUrl", "WowheadQuickLinkConfig_Frame"
local URL = "WowheadQuickLinkConfig_FinalUrlText"
local BINDINGS = { "BINDING_NAME_WOWHEAD_QUICK_LINK_NAME", "BINDING_NAME_WOWHEAD_QUICK_LINK_RAIDERIO_NAME" }
local CYR = "[\208-\211][\128-\191]"

local T = ns.AL or {}
ns.AL = T
-- By the hash of the English: site-name headers (as they are), a type kept as it is, headers left English on
-- purpose (the whole popup stays English: the lead, 2026-11-22), and which Code keys are what.
local SITE = { a7caebbf = true, ["4a342bc2"] = true }
local ASIS = { ["0b880946"] = true }
local STAY = { ["194c866e"] = true, ["489b05d0"] = true }
local BUTTON = { ["0cf88a3b"] = true }
local BIND = { ["95cb26ed"] = true, e49fab7b = true }
local LABEL = { ["62c3ca66"] = true, ["69fa1a2d"] = true, ["54d63e75"] = true, b0a39822 = true }
local MAXLEN = 200

local function Say(msg) U.Print(TITLE .. ": " .. msg) end
local function EnglishClient()
    local l = type(GetLocale) == "function" and GetLocale() or "enUS"
    return l == "enUS" or l == "enGB"
end
local function Loaded(name)
    local ok, yes = pcall((C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded, name) return ok and yes and true or false
end

function ns.On() return ready and db ~= nil and db.enabled == true and EnglishClient() end
function ns.WordsWanted() return ns.On() and not U.originalShown end

local function Code(en, set)
    local h = U.Hash(en)
    return h and set[h] and T["Code." .. h] or nil
end

-- ── Words ─────────────────────────────────────────────────────────────────────────────────────

local function Fill(tpl, v)       -- tpl with its one %s filled by v (no pattern: v may hold any sign)
    local a = tpl:find("%s", 1, true)
    if not a or type(v) ~= "string" then return nil end
    return tpl:sub(1, a - 1) .. v .. tpl:sub(a + 2)
end

-- The popup's header in our words: a site name as it is, else our head words and our link type; nil if any
-- part has no Ukrainian.
local function Head(h)
    local hh = U.Hash(h)
    if not hh then return nil end
    if SITE[hh] then return h end
    local q = h:find(" ", 1, true)
    if not q then return nil end
    local tpl = T["Head." .. U.Hash(h:sub(1, q) .. "%s")]
    local word = h:sub(q + 1)
    local wh = U.Hash(word)
    local w = wh and (T["Type." .. wh] or (ASIS[wh] and word))
    if not tpl or not w then return nil end
    return Fill(tpl, w)
end

-- (template, header) of the popup's text: its first line is the header, then the template's words.
local function Split(now)
    if type(now) ~= "string" or #now > MAXLEN then return nil end
    local nl = now:find("\n", 1, true) or #now
    local p = now:find(" ", 1, true)
    while p and p < nl do
        local tpl = T["Pop." .. U.Hash("%s" .. now:sub(p))]
        if tpl then return tpl, now:sub(1, p - 1) end
        p = now:find(" ", p + 1, true)
    end
end

local function Stays(now)
    local _, h = Split(now)
    return h ~= nil and STAY[U.Hash(h)] == true
end
local function Popup(now)
    local tpl, h = Split(now)
    local head = tpl and Head(h)
    return head and Fill(tpl, head) or nil
end
local function Translate(now) return Code(now, BUTTON) or Popup(now) end

-- ── Fonts: ours on a text that shows our words, its own back after ──────────────────────────

-- Lessons 18, 38, 44: its own font saved first (never while ours is on), then our Cyrillic font OBJECT; only on its
-- window's labels, where that does not take, the file by hand (U.CyrOnOwn). The popup gets an object only.
local saved = {}
local function IsCyr(fs) local ok, p = pcall(fs.GetFont, fs) return ok and U.IsCyrFont(p) end
local function On(fs, byhand)
    if IsCyr(fs) then return true end           -- ours on already (saved), or a font with our letters
    local okS, was = pcall(U.SaveFont, fs)
    if not okS or type(was) ~= "table" then return false end
    local ok, took = pcall(U.CyrOnLocked, fs)
    if byhand and not (ok and took) and not U.Locked(fs) then ok, took = pcall(U.CyrOnOwn, fs, was) end
    if ok and took and IsCyr(fs) then saved[fs] = was return true end
    pcall(U.FontBack, fs, was)                  -- whole English, never half a font
    return false
end
local function CyrOn(fs) return On(fs, true) end local function PopFont(fs) return On(fs, false) end
local function FontBack(fs)
    local o = saved[fs]
    if o and IsCyr(fs) then pcall(U.FontBack, fs, o) end   -- U.FontBack keeps ours while it still shows Cyrillic:
    if not (o and IsCyr(fs) and not U.IsCyrFont(o.path)) then saved[fs] = nil end   -- then the record stays too
end
ns.saved = saved

-- ── The link popup ───────────────────────────────────────────────────────────────────────────

-- The core helper asks its text first, then its button: the button is ours only after a text of ours.
local back, nback, popOurs = {}, 0, false
local function PopText(now)
    -- The core helper sets the text without looking at the font: no Cyrillic font, no Ukrainian.
    if type(U.CyrFontPath) ~= "function" or type(U.CyrFontPath()) ~= "string" then return nil end
    local uk = Code(now, BUTTON)
    if uk and not popOurs then return nil end
    if not uk then uk = Popup(now) popOurs = uk ~= nil end
    if uk then
        if nback >= 50 then back, nback = {}, 0 end
        if back[uk] == nil then nback = nback + 1 end
        back[uk] = now
    elseif U.MissedOn() and not Stays(now) then
        U.Missed(KEY, now)
    end
    return uk
end
local function PopEnglish(uk) return back[uk] end

local popupsOk = type(U.Popups) == "table" and type(U.Popups.Register) == "function"
if popupsOk then
    U.Popups.Register(KEY, {
        names = { [POPUP] = true }, text = PopText, english = PopEnglish, wanted = ns.WordsWanted, fix = PopFont, back = FontBack,
    })
end

-- ── Key binding names ────────────────────────────────────────────────────────────────────────

local bound = {}         -- global name -> its English, while our word is in it
local function Bind(want)
    for _, name in ipairs(BINDINGS) do
        local now = U.Plain(rawget(_G, name))
        local en = bound[name]
        local uk = en and Code(en, BIND)
        if want and now and not now:find(CYR) then
            local mine = Code(now, BIND)
            if mine then _G[name], bound[name] = mine, now end
        elseif not want and en then
            if now == uk then _G[name] = en end          -- still ours: its English back; else theirs stays
            bound[name] = nil
        end
    end
end
local function Bound()
    local n = 0
    for name, en in pairs(bound) do if rawget(_G, name) == Code(en, BIND) then n = n + 1 end end
    return n
end

-- ── The /wql window ──────────────────────────────────────────────────────────────────────────

-- Its title and labels: the window's own texts but the URL, and in each box the label above it (anchored at
-- its top left, upwards); the box's typed text is never a label (lesson 13).
local C = { en = {} }
local function Label(fs, out)
    if type(fs) ~= "table" or not fs.GetText or not fs.SetText or not fs.GetFont then return end
    if fs.GetObjectType and fs:GetObjectType() ~= "FontString" then return end
    local t = U.Plain(fs:GetText())
    if t and Code(t, LABEL) then out[#out + 1], C.en[fs] = fs, t end
end
local function Labels()
    if C.list then return C.list end
    local f, out = rawget(_G, CONFIG), {}
    if type(f) ~= "table" then return out end
    for _, r in ipairs(U.Regions(f)) do
        if not (r.GetName and r:GetName() == URL) then Label(r, out) end
    end
    for _, b in ipairs(U.Children(f)) do
        if b.GetObjectType and b:GetObjectType() == "EditBox" then
            for _, r in ipairs(U.Regions(b)) do
                local ok, p, _, _, _, y = pcall(r.GetPoint, r, 1)
                if ok and p == "TOPLEFT" and type(y) == "number" and y > 0 then Label(r, out) end
            end
        end
    end
    if out[1] then C.list = out end
    return out
end

local function Apply()
    local want = ns.WordsWanted()
    for _, fs in ipairs(Labels()) do
        local en = C.en[fs]
        local uk, now = Code(en, LABEL), U.Plain(fs:GetText())
        if want and uk and (now == en or now == uk) and CyrOn(fs) then
            if now == en then fs:SetText(uk) end
        else
            if uk and now == uk then fs:SetText(en) end
            FontBack(fs)
        end
    end
end
local function Shown()
    local n = 0
    for _, fs in ipairs(C.list or {}) do if U.Plain(fs:GetText()) == Code(C.en[fs], LABEL) then n = n + 1 end end
    return n
end

local hooked = false
local function Hook()
    local f = rawget(_G, CONFIG)
    if hooked or type(f) ~= "table" or not f.HookScript then return end
    hooked = f:HookScript("OnShow", U.Safe(KEY, Apply)) or true
end

-- ── On and off ───────────────────────────────────────────────────────────────────────────────

local function Sync()
    U.SafeCall(Bind, ns.WordsWanted())
    U.SafeCall(Apply)
    if popupsOk then U.SafeCall(U.Popups.Sync, KEY) end
end
local function Begin() if ns.On() then U.SafeCall(Hook) Sync() end end
local function End()              -- off (db.enabled is false by now): everything of ours out
    U.SafeCall(Bind, false)
    if popupsOk then U.SafeCall(U.Popups.Off, KEY) end
    U.SafeCall(Apply)
end
ns.Sync, ns.Begin, ns.End = Sync, Begin, End
ns.Translate, ns.Labels, ns.Bound, ns.Shown = Translate, Labels, Bound, Shown

local function Ready()
    if ready or not db or not Loaded(TARGET) then return end
    ready = true
    U.SafeCall(U.MissedModule, KEY, { addon = TARGET, keep = function(t) return Stays(t) end,
        test = function(t) return Translate(t) ~= nil or Code(t, BIND) ~= nil or Code(t, LABEL) ~= nil end })
    Begin()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name ~= ADDON then return end
        db = U.DB(KEY) ns.db = db
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
    if not db then return "ще не завантажено" end
    if not EnglishClient() then return "не працює: клієнт не англійський" end
    if not ready then return "чекає: " .. TITLE .. " не завантажено" end
    if not db.enabled then return "вимкнено (/uadd wql on)" end
    local pops = popupsOk and (U.Popups.Count(KEY) + U.Popups.FieldCount(KEY)) or 0
    return ("увімкнено: %s українською; у вікні посилання: %d, назв клавіш: %d, підписів у вікні /wql: %d")
        :format(TITLE, pops, Bound(), Shown())
end

local HELP = { "/uadd wql on - " .. TITLE .. " українською", "/uadd wql off - вимкнути, " .. TITLE .. " знову англійською" }
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
        Say("вимкнено. " .. TITLE .. " знову англійською.")
    else
        Say(Status())
        for _, line in ipairs(HELP) do U.Print("  " .. line) end
    end
end

U.RegisterModule(KEY, { title = TITLE, Status = Status, Command = Command })
