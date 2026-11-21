-- Lua helpers for flow_popups.py: the core popup helper (UADD/Popups.lua) in LiteMount, TomTom, Forever Quest Pins,
-- Attune, Dungeon Journal and ForeverXP Bar's games. Reached from Python as HARNESS.pops. Runs when the game starts, after each flow's own Lua.
-- The words we want are read from the glossary (UADD.Glossary.Text), never from a module.
local H = HARNESS
local P = {}
H.pops = P
local CYR = "[\208-\211][\128-\191]"

-- One fix cut out per mutant, in memory only: { addon, file, code, new }.
local CUTS = {
    fields = { "UADD", "Popups.lua", "if en and v == en then", "if false then" },
    shown = { "UADD", "Popups.lua", "if i > 1 then en, uk = Of(s, now) end", "" },
    restore = { "UADD", "Popups.lua", "    pcall(Fields, s, false)\n", "" },
    rescan = { "UADD", "Popups.lua", "    if uk and installed then Rescan(s) end\n", "" },
    unrecorded = { "UADD", "Popups.lua", "    if not uk then Unrecorded(s) end\n", "" },
    ours = { "UADD", "Popups.lua", 'if type(which) ~= "string" then return false end', "do return true end" },
    cyr = { "UADD", "Popups.lua", ' or en:find(CYR)', "" },
    names = { "UADD", "Popups.lua", "    if s.names[which] then return true end\n", "" },
    lmhold = { "UADD_LiteMount", "Module.lua", "        U.Popups.Sync(KEY)\n        U.SafeCall(ns.Tables.Sync)", "        U.SafeCall(ns.Tables.Sync)" },
    ttoff = { "UADD_TomTom", "Settings.lua", "    U.Popups.Off(KEY)\nend", "end" },
    fqpoff = { "UADD_ForeverQuestPins", "Module.lua", "    U.SafeCall(ns.Chat.Restore)\n    U.Popups.Off(KEY)\n",
               "    U.SafeCall(ns.Chat.Restore)\n" },
    english = { "UADD", "Popups.lua", "if not uk and s.english and now and now:find(CYR) then", "if false then" },
    djhold = { "UADD_DungeonJournal", "Module.lua", "        if db and db.enabled then ns.Popup.Sync() end\n", "" },
    djlang = { "UADD_DungeonJournal", "Popup.lua", "    forget(...)\n    P.Sync()\n", "    forget(...)\n" },
    fxglobals = { "UADD_ForeverXPBar", "Popup.lua", '    globals = { YES = "ui.yes", NO = "ui.no" },\n', "" },
}
local runFile = H.runFile
function H.runFile(addon, path, code)
    local c = P.cut and CUTS[P.cut]
    if c and addon == c[1] and path == c[2] then
        local a, b = code:find(c[3], 1, true)
        if a then code, P.wasCut = code:sub(1, a - 1) .. c[4] .. code:sub(b + 1), true end
    end
    return runFile(addon, path, code)
end
function P.setCut(cut) P.cut, P.wasCut = cut, nil end

DELETE = DELETE or "Delete"       -- the game's global, missing from wow_api.lua

-- StaticPopup1..4 with a text and four buttons, unless the flow's own Lua made them (Attune's does).
local pops = {}
for i = 1, 4 do
    local d = _G["StaticPopup" .. i]
    if not rawget(d, "button1") then
        d.text = d:CreateFontString("StaticPopup" .. i .. "Text", "ARTWORK", "GameFontHighlight")
        for b = 1, 4 do
            local btn = CreateFrame("Button", "StaticPopup" .. i .. "Button" .. b, d)
            btn:GetFontString():SetFontObject(GameFontNormal)
            d["button" .. b] = btn
        end
        d:Hide()
    end
    pops[i] = d
end
local own = rawget(StaticPopup1, "button4") ~= nil
if own then
    function StaticPopup_Show(which)
        local info = StaticPopupDialogs[which]
        if not info then return end
        local d = pops[1]
        for _, p in ipairs(pops) do if p.which == which or not p:IsShown() then d = p break end end
        d.which = which
        d.text:SetText(info.text)
        for b = 1, 4 do d["button" .. b]:SetText(info["button" .. b]) end
        d:Show()
        return d
    end
    function StaticPopup_Hide(which) for _, p in ipairs(pops) do if p.which == which then p:Hide() end end end
end

-- A button's source: "G:ACCEPT" (the game's global) or "L:Yes" (Attune's AttuneLang word).
local function Src(src)
    local kind, name = src:match("^(%a):(.+)$")
    if kind == "G" then return rawget(_G, name) end
    local t = rawget(_G, "AttuneLang")
    local v = type(t) == "table" and rawget(t, name)
    return type(v) == "string" and v or name
end

local defs = {}
-- An entry with these buttons ({ src, glossary id } each), made now or set again (as the addon makes it).
function P.define(which, s1, id1, s2, id2)
    defs[which] = { { s1, id1 }, s2 and { s2, id2 } or nil }
    local d = StaticPopupDialogs[which] or { text = "" }
    StaticPopupDialogs[which] = d
    d.button1, d.button2 = Src(s1), s2 and Src(s2) or nil
end

local function Join(a, b) return tostring(a) .. " / " .. tostring(b) end

-- What the buttons should say: "uk" our word while the source is English, the source itself when Cyrillic.
function P.expect(which, want)
    local out = {}
    for i = 1, 2 do
        local b = defs[which][i]
        if b then
            local en = Src(b[1])
            out[i] = (want == "en" or en:find(CYR)) and en or UADD.Glossary.Text(b[2])
        end
    end
    return Join(out[1], out[2])
end

function P.fields(which) local d = StaticPopupDialogs[which] return Join(d.button1, d.button2) end

local function Open(which) for _, p in ipairs(pops) do if p.which == which and p:IsShown() then return p end end end
function P.shown(which)
    local d = Open(which)
    if not d then return "not shown" end
    local b2 = StaticPopupDialogs[which].button2 and d.button2:GetText() or nil
    return Join(d.button1:GetText(), b2)
end
function P.show(which) StaticPopup_Show(which) return P.shown(which) end
function P.hide(which) StaticPopup_Hide(which) end

function P.globals() return table.concat({ ACCEPT, CANCEL, DELETE, OKAY, CLOSE, YES, NO }, " / ") end

-- Dungeon Journal: its real minimap question (the journal makes the entry and shows it), its text now, and the
-- journal's English for it (read from the journal in the game, never kept here).
local MINI = "FOREVERDUNGEONJOURNAL_HIDE_MINIMAP"
local function FDJ() return rawget(_G, "ForeverDungeonJournal_NS") end
function P.djAsk() FDJ().ConfirmHideMinimapButton() return P.shown(MINI) end
function P.djBody() local d = Open(MINI) return d and d.text:GetText() or "not shown" end
function P.djEnglish() return FDJ().Locales.enUS.MINIMAP_HIDE_CONFIRM end
-- Another language picked in the journal's menu (its own SetLanguage), or ours again.
function P.djLanguage(other)
    if other then FDJ().SetLanguage("deDE") else H.ns.UADD_DungeonJournal.Lang.Choose() end
end
function P.setGlobal(name, v) _G[name] = v end
function P.setL(k, v) rawget(_G, "AttuneLang")[k] = v end

-- Another addon's question with the game's words: never ours.
function P.other()
    StaticPopupDialogs.OTHERADDON_QUESTION = { text = "", button1 = ACCEPT, button2 = CLOSE }
    local got = P.show("OTHERADDON_QUESTION")
    P.hide("OTHERADDON_QUESTION")
    return got
end

function P.wait(seconds) for _ = 1, math.ceil(seconds / 0.05 - 1e-6) do H.step(0.05) end end
-- The hold key down or up, then a second (it counts after 0.25 s).
function P.hold(on) P.held = on UADD.KeyHeld = function() return P.held end UADD.CheckOriginal() P.wait(1) end
function P.combat(on) H.combat = on end
function P.uadd(msg) return H.call("/uadd " .. msg, SlashCmdList.UADD, msg) end
