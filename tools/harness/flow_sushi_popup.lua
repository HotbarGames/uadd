-- Lua helpers for flow_sushi_popup.py: the game's button words on Bagnon's and Scrap's own Sushi pop-ups
-- (the core helper UADD/SushiPopups.lua, which UADD_Bagnon and UADD_Scrap register with). Runs before the
-- game starts, on stand-ins for Bagnon and Scrap that load together (as players have them). Sushi-3.2's
-- Popup is put in the shape the real one has (pooled frames, button fields, a Header and RedButtons), from a
-- file under Scrap's "libs" folder, so the stack the helper reads looks as in the game. No English of Bagnon
-- or Scrap is here.
local H = HARNESS
local P = {}
H.sushi = P

-- One fix cut out per mutant, in memory only (as in flow_auc_popup.lua), in the core file.
local CORE, FILE = "UADD", "SushiPopups.lua"
local CUTS = {
    fields = { "Slot(s, f, k, rawget(f, k), want, function(v) f[k] = v end)", "" },
    shown = { "for _, fs in ipairs(Shown(f, {}, 1)) do", "for _, fs in ipairs({}) do" },
    owner = { "    if not s then return end\n    mine[f] = s", "    s = s or specs[order[1]]\n    mine[f] = s" },
    cyr = { " or en:find(CYR)", "" },
    release = { "seen[f], mine[f], kept[f] = nil, nil, nil", "" },
    seen = { " or seen[f] then return end", " then return end" },
    body = { "if not en and not want and s.en then", "if false then" },
    sync = { "    if Wanted(s) then s.sync() else P.Off(key) end\n", "" },
}

local SUSHI = [==[
local Popup = LibStub("Sushi-3.2").Popup
local pool = {}
Popup.Active = {}
setmetatable(Popup, { __call = function(self, info) return self:New(info) end })
local function Button(parent, text)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(118, 20)
    b:SetText(text)
    return b
end
function Popup:GetActive(t)
    for i, f in ipairs(Popup.Active) do if f == t or f.id == t then return f, i end end
end
function Popup:New(input)
    local info = type(input) == "table" and input or { text = input }
    local id = info.id or info.text or input
    if id and self:GetActive(id) then return end
    local f = table.remove(pool) or CreateFrame("Frame", nil, UIParent)
    f.id, f.button1, f.button2, f.text = id, info.button1, info.button2, info.text or ""
    f.Release = function(me, why) return Popup.Release(me, why) end
    f.Children = { Button(f, f.text) }
    if info.editBox then
        local e = CreateFrame("EditBox", nil, f)
        e:SetText(info.editBox)
        f.Children[2], f.edit = e, e
    end
    local g = CreateFrame("Frame", nil, f)
    g.Children = {}
    if f.button1 then g.Children[#g.Children + 1] = Button(g, f.button1) end
    if f.button2 then g.Children[#g.Children + 1] = Button(g, f.button2) end
    f.Children[#f.Children + 1] = g
    f:Show()
    table.insert(Popup.Active, f)
    return f
end
function Popup:Release()
    local _, i = Popup:GetActive(self)
    if not i then return end
    table.remove(Popup.Active, i)
    self:Hide()
    for k, v in pairs(self) do if type(k) == "string" and k:find("^%l") and type(v) == "string" then self[k] = nil end end
    pool[#pool + 1] = self
end
]==]

local runFile = H.runFile
function H.runFile(addon, path, code)
    local c = P.cut and CUTS[P.cut]
    if c and addon == CORE and path == FILE then
        local a, b = code:find(c[1], 1, true)
        if a then code, P.wasCut = code:sub(1, a - 1) .. c[2] .. code:sub(b + 1), true end
    end
    local r = runFile(addon, path, code)
    if addon == "Scrap" and path == "Scrap.lua" then
        assert(loadstring(SUSHI, "@AddOns/Scrap/libs/Sushi-3.2/classes/groups/Popup.lua"))()
    end
    return r
end
function P.setCut(cut) P.cut, P.wasCut = cut, nil end

local CYR = "[\208-\211][\128-\191]"
local function C() return LibStub("Sushi-3.2").Popup end

-- A pop-up opened by code in AddOns/<folder>/<file> (a library file: "libs/..."), with the game's globals
-- by name and the body read from that addon's locale table by key (nil: no body).
function P.open(folder, file, b1, b2, app, key, id)
    local L = app and LibStub("AceLocale-3.0"):GetLocale(app, true)
    local info = { id = id, button1 = b1 and rawget(_G, b1), button2 = b2 and rawget(_G, b2),
        text = L and key and L[key] or nil }
    -- Not a tail call: the addon's own line must stay on the stack, as with Bagnon's and Scrap's real calls.
    local fn = assert(loadstring("local P, info = ... local f = P(info) return f", "@AddOns/" .. folder .. "/" .. file))
    return fn(C(), info)
end

-- What one pop-up shows: its fields "b1 / b2 / body" and its shown texts "body | b1 | b2", and whether each
-- shown text with Cyrillic has our font.
function P.view(f)
    local t, font = {}, true
    local function add(fs)
        local s = fs:GetText()
        t[#t + 1] = tostring(s)
        if s and s:find(CYR) and not UADD.IsCyrFont((fs:GetFont())) then font = false end
    end
    add(f.Children[1]:GetFontString())
    for _, b in ipairs(f.Children[#f.Children].Children) do add(b:GetFontString()) end
    return tostring(f.button1) .. " / " .. tostring(f.button2) .. " / " .. tostring(f.text),
        table.concat(t, " | "), font
end
function P.release(f) f:Release() end
-- The core helper's count of a module's shown pop-ups (nil: the helper is not loaded).
function P.count(key) return UADD.SushiPopups and UADD.SushiPopups.Count(key) end
function P.active() return #C().Active end

-- The words a pop-up should show: "uk" -> the glossary's word while the global is English, the global
-- itself while it is Cyrillic; "en" -> the global.
local IDS = { OKAY = "ui.ok", CANCEL = "ui.cancel", YES = "ui.yes", NO = "ui.no", ACCEPT = "ui.accept" }
function P.word(g, want)
    local en = rawget(_G, g)
    if want == "en" or en:find(CYR) then return en end
    return UADD.Glossary.Text(IDS[g])
end
function P.L(app, key) return LibStub("AceLocale-3.0"):GetLocale(app)[key] end
-- A key of the app's locale table whose text is ours now, whole (no slot, no colour): a body to flip.
function P.plainKey(app)
    local keys = {}
    for k, v in pairs(LibStub("AceLocale-3.0"):GetLocale(app)) do
        if type(v) == "string" and v:find(CYR) and not v:find("[%%|]") and #v > 20 then keys[#keys + 1] = k end
    end
    table.sort(keys)
    return keys[1]
end
for g, w in pairs({ OKAY = "Okay", CANCEL = "Cancel", YES = "Yes", NO = "No", ACCEPT = "Accept" }) do
    if rawget(_G, g) == nil then _G[g] = w end
end
function P.globals()
    local o = {}
    for _, g in ipairs({ "OKAY", "CANCEL", "YES", "NO", "ACCEPT", "UNLOCK", "CHAT_LEAVE" }) do
        o[#o + 1] = tostring(rawget(_G, g))
    end
    return table.concat(o, " / ")
end
function P.preset(g, word) _G[g] = word end
-- An error inside the glossary while a pop-up opens (on / off).
local text
function P.breakGlossary(on)
    text = text or UADD.Glossary.Text
    UADD.Glossary.Text = on and function() error("harness: glossary broken") end or text
end
