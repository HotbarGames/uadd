-- Not WhatTheWhisper: a made-up window drawn the way it draws, after its own locale, date, sound and export
-- files ran (read only). Which keys its built-once texts use comes from flow_wtw.py at run time
-- (WhatTheWhisperStandInFeed, read from the installed code), so no text of the addon is here.
--   * the main window: one line per enUS key, L[key], redrawn by Options.Apply("appearance.locale")
--   * the key binding names (set once at load), the options stub (game fonts), dialogs and the emoji
--     picker's tabs (built once, never redrawn), the picker built only when first opened.
-- WhatTheWhisperStandIn.throw = n: the redraw throws while n > 0 (the module's 5-error guard, lesson 19).
local _, ns = ...
local L = ns.L
local feed = WhatTheWhisperStandInFeed or {}
local S = { throw = 0, redraws = 0, lines = {}, dialogs = {} }
WhatTheWhisperStandIn = S

-- The enUS table as it was before any other addon loaded: "off" must give back exactly this.
S.enUS = {}
for k, v in pairs(ns.LocaleData.enUS) do S.enUS[k] = v end
S.weekdays = {}
for _, d in ipairs({ "SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY" }) do
    S.weekdays[d] = _G["WEEKDAY_" .. d]
end

local font = CreateFont("WhatTheWhisperFont")
font:SetFont("Interface\\AddOns\\WhatTheWhisper\\Media\\Fonts\\Manrope-Regular.ttf", 12, "")

local main = CreateFrame("Frame", "WhatTheWhisperStandInWindow", UIParent)
main:SetSize(400, 400)
S.main = main
local keys = {}
for k in pairs(ns.LocaleData.enUS) do keys[#keys + 1] = k end
table.sort(keys)
S.keys = keys
for _, k in ipairs(keys) do
    local fs = main:CreateFontString(nil, "ARTWORK")
    fs:SetFontObject(font)
    S.lines[k] = fs
end

local function Draw()
    for k, fs in pairs(S.lines) do fs:SetText(L[k]) end
end
Draw()

ns.UI = ns.UI or {}
function ns.UI.Relocalize()
    S.redraws = S.redraws + 1
    Draw()
end

-- Its Options.Apply: the language picker's path redraws every text (Theme, layout, lists, Relocalize).
ns.Options = ns.Options or {}
function ns.Options.Apply(path)
    if path == "appearance.locale" then ns.UI.Relocalize() end
end
function ns.Options.ApplyAll() ns.UI.Relocalize() end

-- S.trap(n): the first export format's label throws on its next n reads, in the reader's own code (level 2,
-- so the error names the module's file when the module reads it).
function S.trap(n)
    local e = ns.Export.FORMATS[1]
    S.throw = n
    if n > 0 and rawget(e, "label") ~= nil then
        e._label, e.label = e.label, nil
        setmetatable(e, { __index = function(t, k)
            if k ~= "label" then return nil end
            if S.throw > 0 then S.throw = S.throw - 1 error("harness: a label that throws", 2) end
            return rawget(t, "_label")
        end })
    elseif n == 0 and getmetatable(e) then
        if rawget(e, "label") == nil then e.label = rawget(e, "_label") end
        e._label = nil
        setmetatable(e, nil)
    end
end

-- Key bindings: copied once at load.
for name, key in pairs(feed.bindings or {}) do _G["BINDING_NAME_WHATTHEWHISPER_" .. name] = L[key] end

-- Its buttons: a label FontString in its own font, SetText on the label.
ns.Button = ns.Button or {}
function ns.Button.Text(parent, o)
    local b = CreateFrame("Button", nil, parent)
    b.label = b:CreateFontString(nil, "OVERLAY")
    b.label:SetFontObject(font)
    function b:SetText(t) self.label:SetText(t) end
    function b:GetText() return self.label:GetText() end
    b:SetText(o and o.text or "")
    return b
end

-- The options stub in the game's own fonts (their name in the title, a line and a button through L).
local function BuildStub()
    local stub = feed.stub or {}
    local panel = CreateFrame("Frame", "WhatTheWhisperOptionsPanel", UIParent)
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetText("WhatTheWhisper")
    local body = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    body:SetText(stub.body and L[stub.body] or "")
    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetText(stub.button and L[stub.button] or "")
    S.stub = { panel = panel, title = title, body = body, button = button }
    ns.Compat.RegisterOptionsPanel(panel, "WhatTheWhisper")
    return panel
end
ns.Options.panel = BuildStub()

-- A dialog: a named frame with its buttons as fields, built once.
function S.buildDialog(i)
    local d = feed.dialogs and feed.dialogs[i]
    if not d or _G[d.name] then return _G[d and d.name or ""] end
    local f = CreateFrame("Frame", d.name, UIParent)
    for _, b in ipairs(d.buttons) do f[b[1]] = ns.Button.Text(f, { text = L[b[2]] }) end
    S.dialogs[i] = f
    return f
end

-- Its emoji list, as Modules/Emoticons.lua has it: each category's id and English label ("recent" is not one).
ns.Emoticons = ns.Emoticons or { CATEGORIES = {} }
for i = 2, #(feed.emoji or {}) do
    local t = feed.emoji[i]
    ns.Emoticons.CATEGORIES[#ns.Emoticons.CATEGORIES + 1] = { id = t[1], label = t[2] }
end

-- The emoji picker: built when first opened; tabs are buttons with .categoryID, label L[...].
function S.openPicker()
    local f = _G.WhatTheWhisperEmojiPicker
    if f then f:Show() return f end
    f = CreateFrame("Frame", "WhatTheWhisperEmojiPicker", UIParent)
    S.tabs = {}
    for _, t in ipairs(feed.emoji or {}) do
        local b = ns.Button.Text(f, { text = L[t[2]] })
        b.categoryID = t[1]
        S.tabs[#S.tabs + 1] = b
    end
    f:Show()
    return f
end

-- The first half of the dialogs exist before the module loads; the rest are built later (flow_wtw).
for i = 1, math.floor(#(feed.dialogs or {}) / 2) do S.buildDialog(i) end
