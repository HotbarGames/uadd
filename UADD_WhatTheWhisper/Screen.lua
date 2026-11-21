-- Texts WhatTheWhisper wrote once and never writes again when its language changes: ours in them, and its
-- words back (in the language in force) on off and while the hold key is held.
--   * Its own window frames redraw from its locale table (Module.lua asks it to); these do not:
--       - its page in the game's settings (WhatTheWhisperOptionsPanel): the line under the title and the
--         button. They use the game's fonts, which lack Ukrainian letters on an English client, so a
--         FontString that shows Cyrillic gets UADD's Cyrillic font (UADD/AceFont.lua), and its own font
--         back when it shows Latin again (lesson 32);
--       - the buttons of its dialogs made once (copy, confirm, quick replies, prompt);
--       - the category tabs of its emoji picker.
--     Those buttons use its own font, which has Ukrainian letters: no font change there.
--   * Each text is found by its English key (Swap.KeyOf: ours, its English, or another of its languages),
--     and gets what its L gives for that key now. A text without ours is never touched; so is the title,
--     the addon's name. Text the player wrote is never in these.

local _, ns = ...
local U = UADD
local S = {}
ns.Screen = S

local APP = "WhatTheWhisper"
local CYR = "[\208-\210]"           -- the first byte of a Cyrillic letter in UTF-8
local DIALOGS = {
    WhatTheWhisperCopyDialog = { "saveFile" },
    WhatTheWhisperConfirmDialog = { "cancel" },
    WhatTheWhisperQuickRepliesDialog = { "save", "cancel", "restore" },
    WhatTheWhisperPromptDialog = { "cancel" },
}
local keyFor = {}                   -- a FontString or button -> its English key
local changed = {}                  -- the same -> true while it shows ours
local backOnly = false              -- S.Restore: only texts that show ours get its words back

-- During S.Restore, a text that does not show ours is left as it is (lesson 23).
local function Skip(obj, t)
    if backOnly and not ns.Swap.Ours(t) then
        changed[obj] = nil
        return true
    end
    return false
end

local function Frame(name)
    local f = rawget(_G, name)
    return type(f) == "table" and f or nil
end

-- Its English key for one object: the one known before (kept from when it was first seen, mostly in its
-- English), else `hint` (its own English, where its frame keeps it), else what the text says. Ours that two
-- of its keys share says nothing (Swap.KeyOf gives nil): then only the key kept or the hint can tell, and an
-- object with neither is left as it is.
local function Key(obj, text, hint)
    local k = keyFor[obj]
    if k == nil then
        k = (ns.Swap.Has(hint) and hint) or ns.Swap.KeyOf(text) or false
        if k then keyFor[obj] = k end
    end
    return k or nil
end

local Decide
Decide = function(fs)
    if type(fs) ~= "table" or not fs.GetText then return end
    local t = U.Plain(fs:GetText())
    if ns.On() and t and t:find(CYR) then
        UADD.AceFont.Set(fs, APP, Decide)
    else
        UADD.AceFont.Back(fs)
    end
end
S.Decide = Decide

local function Note(obj, w)
    changed[obj] = ns.Swap.Ours(w) or nil
end

-- One button of its own kind (a frame with .label and its own SetText).
local function Button(b, hint)
    if type(b) ~= "table" or type(b.label) ~= "table" or not b.label.GetText or type(b.SetText) ~= "function" then
        return
    end
    local t = U.Plain(b.label:GetText())
    if not t or Skip(b, t) then return end
    local k = Key(b, t, hint)
    local w = k and ns.Swap.Word(k)
    if w and w ~= t then b:SetText(w) end
    if w then Note(b, w) end
end

-- One FontString of the game's kind, with the font decided after.
local function Line(fs)
    if type(fs) ~= "table" or not fs.GetText or not fs.SetText then return end
    local t = U.Plain(fs:GetText())
    if not t or Skip(fs, t) then return end
    local k = Key(fs, t)
    local w = k and ns.Swap.Word(k)
    if not w then return end
    if w ~= t then fs:SetText(w) end
    Note(fs, w)
    Decide(fs)
end

local function GameButton(b)
    if type(b) ~= "table" or not b.GetFontString or not b.SetText then return end
    local fs = b:GetFontString()
    local t = fs and U.Plain(fs:GetText())
    if not t or Skip(b, t) then return end
    local k = Key(b, t)
    local w = k and ns.Swap.Word(k)
    if not w then return end
    if w ~= t then b:SetText(w) end
    Note(b, w)
    Decide(b:GetFontString())
end

local function Panel()
    local p = Frame("WhatTheWhisperOptionsPanel")
    if not p then return end
    for _, r in ipairs(U.Regions(p)) do
        if r.GetObjectType and r:GetObjectType() == "FontString" then U.SafeCall(Line, r) end
    end
    for _, c in ipairs(U.Children(p)) do
        if c.GetObjectType and c:GetObjectType() == "Button" then U.SafeCall(GameButton, c) end
    end
end

local function Dialogs()
    for name, fields in pairs(DIALOGS) do
        local d = Frame(name)
        for _, field in ipairs(d and fields or {}) do U.SafeCall(Button, d[field]) end
    end
end

-- A tab's own English: the label of its category in its emoji list (the tab keeps the category's id).
local function Category(id)
    local a = ns.Swap.Addon()
    local E = a and a.Emoticons
    for _, c in ipairs(type(E) == "table" and type(E.CATEGORIES) == "table" and E.CATEGORIES or {}) do
        if type(c) == "table" and c.id == id and type(c.label) == "string" then return c.label end
    end
    return nil
end

local function Emoji()
    local f = Frame("WhatTheWhisperEmojiPicker")
    if not f then return end
    for _, c in ipairs(U.Children(f)) do
        if c.categoryID ~= nil then U.SafeCall(Button, c, Category(c.categoryID)) end
    end
end

-- Every text here as its L gives it now: call after each swap, both ways.
function S.Apply()
    U.SafeCall(Panel)
    U.SafeCall(Dialogs)
    U.SafeCall(Emoji)
    if not ns.Swap.On() then UADD.AceFont.Stop(APP) end
end

-- Off, held, or another language: the same walk (its words are back in its table by now), but only texts
-- that show ours change; one it shows in its English or another language stays. Every font of ours back.
function S.Restore()
    backOnly = true
    S.Apply()
    backOnly = false
    UADD.AceFont.Stop(APP)
end

-- Texts showing ours here now, and FontStrings in our font.
function S.Count()
    local n = 0
    for _ in pairs(changed) do n = n + 1 end
    return n
end

function S.Fonts() return UADD.AceFont.Count(APP) end
