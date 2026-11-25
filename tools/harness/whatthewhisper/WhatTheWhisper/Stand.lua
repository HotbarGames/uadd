-- Not WhatTheWhisper: a made-up window drawn the way it draws, after its own locale, date, sound and export
-- files ran (read only). Which keys its built-once texts use comes from flow_wtw.py at run time
-- (WhatTheWhisperStandInFeed, read from the installed code), so no text of the addon is here.
--   * the main window: one line per enUS key, L[key], redrawn by Options.Apply("appearance.locale")
--   * the key binding names (set once at load), the options stub (game fonts), dialogs and the emoji
--     picker's tabs (built once, never redrawn), the picker built only when first opened.
--   * the profile panel (main window and popouts: rows through L, some keys its enUS lacks) and the settings
--     schema (the History page's size line, captions its enUS lacks), redrawn with the rest.
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

-- Its profile panel (UI/ProfilePanel.lua): New copies the methods onto a hidden frame; Refresh draws one row
-- label per field through L (rows reused), and skips a hidden panel. The fields' labels come from the feed.
local P = {}
function P:Refresh()
    if not self:IsShown() then return end
    for i, k in ipairs(feed.profile or {}) do
        local row = self.rows[i]
        if not row then
            row = { label = self:CreateFontString(nil, "ARTWORK") }
            row.label:SetFontObject(font)
            self.rows[i] = row
        end
        row.label:SetText(L[k])
    end
end
function P:Relocalize() self:Refresh() end
ns.ProfilePanel = ns.ProfilePanel or {}
function ns.ProfilePanel.New(parent)
    local panel = CreateFrame("Frame", nil, parent)
    for k, fn in pairs(P) do panel[k] = fn end
    panel.rows = {}
    panel:Hide()
    return panel
end

-- The main window's panel, made before the module loads; popouts (each with its own panel) made later.
S.window = { view = { profile = ns.ProfilePanel.New(main) } }
S.window.view.profile:Show()
S.window.view.profile:Refresh()
ns.MainWindow = { Existing = function() return S.window end }
S.popouts = {}
ns.Popout = { Each = function(fn)
    for id, w in pairs(S.popouts) do if w:IsShown() then fn(id, w) end end
end }
function S.popout(id)
    local w = CreateFrame("Frame", nil, UIParent)
    w.view = { profile = ns.ProfilePanel.New(w) }
    S.popouts[id] = w
    w:Show()
    w.view.profile:Show()
    w.view.profile:Refresh()
    return w
end

-- Its settings schema (Core/Options.lua BuildSchema), fresh on each call: the History page's size line (an info
-- row whose value formats its template with Format.Bytes) and a toggle per caption the feed names. S.raw: a size
-- text of another kind, put in the slot as it is.
S.bytes, S.raw = 456, nil
ns.Options.BuildSchema = function()
    local rows = {}
    if feed.size then
        rows[1] = { type = "info", label = L[feed.size], value = function()
            return L[feed.size]:format(S.raw or ns.Format.Bytes(S.bytes))
        end }
    end
    for _, c in ipairs(feed.captions or {}) do rows[#rows + 1] = { type = "toggle", path = "x", caption = L[c] } end
    return { { id = "history", cards = { { rows = rows } } } }
end
-- Its settings window: on each build it draws what the schema holds (an info row's value is called then).
S.settings = { caps = {} }
function S.render()
    S.schema = ns.Options.BuildSchema()
    S.settings.size, S.settings.caps = nil, {}
    for _, row in ipairs(S.schema[1].cards[1].rows) do
        if row.type == "info" then S.settings.size = row.value()
        else S.settings.caps[#S.settings.caps + 1] = row.caption end
    end
end
S.render()

S.print = ns.Print          -- its own, from before any module

-- The icon picker and the export window: each writes its texts when it opens (keys from the feed), not redrawn.
local function Opened(name)
    local f = _G[name] or CreateFrame("Frame", name, UIParent)
    f.title = f.title or f:CreateFontString(nil, "ARTWORK")
    f.title:SetFontObject(font)
    f:Show()
    return f
end
ns.IconPicker = { Open = function(shown)
    local d, k = Opened("WhatTheWhisperIconDialog"), feed.icon or {}
    for _, field in ipairs({ "hint", "empty" }) do
        d[field] = d[field] or d:CreateFontString(nil, "ARTWORK")
        d[field]:SetFontObject(font)
    end
    d.title:SetText(L[k.title])
    d.hint:SetText(L[k.hint]:format(shown))
    d.empty:SetText(L[k.empty])
    d.reset = d.reset or ns.Button.Text(d)
    d.reset:SetText(L[k.reset])
end }
ns.Dialogs = ns.Dialogs or {}
function ns.Dialogs.ShowExport(conv)
    local d = Opened("WhatTheWhisperCopyDialog")
    d.conv = conv
    d.title:SetText(L[feed.export] .. " \194\183 " .. (conv.name or conv.id))
end
ns.GroupChat = ns.GroupChat or {}
function ns.GroupChat.Target(id)
    if id:sub(1, 5) == "CH:C:" then return "CHANNEL", id:sub(6) end
    return id:sub(1, 3) == "CH:" and id:sub(4) or nil
end

-- The language redraw also relocalizes the profile panels (the main one, each shown popout) and the settings.
local relocalize = ns.UI.Relocalize
function ns.UI.Relocalize()
    relocalize()
    S.window.view.profile:Relocalize()
    ns.Popout.Each(function(_, w) w.view.profile:Relocalize() end)
    S.render()
end
