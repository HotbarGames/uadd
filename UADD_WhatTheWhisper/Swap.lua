-- Our words in WhatTheWhisper's own locale table, and its English back.
--   * Its locale keys are its English (enUS: value = key). Our data is keyed by "L." .. UADD.Hash(key), so
--     no English is stored here: the keys are read from its table at run time.
--   * Only the enUS table gets ours, and only while enUS is the language in force (ns.ActiveLocale): the
--     other languages fall back to enUS for what they lack, so ours would mix into them. No key is ever
--     added (that would lower the other languages' share in its language list), and its L (a proxy that
--     refuses writes) is never written.
--   * STAY: texts it saves into its data or sends to other players (the four quick-reply starters, the
--     saved fallback for a friend's name): kept English, never ours (lesson 14). A template whose slot holds a
--     game name or English units (sort n or u in ns.SORT) stays English as a whole (no half lines).
--   * Its "save to a file" runs with its English in (W.WithEnglish below): what it saves stays English.
--   * Copies it made at load get ours too, and their English back: three key binding names, the export
--     format labels, and the sound list labels (written in its code, keyed "X." .. hash of the English).

local _, ns = ...
local U = UADD
local W = {}
ns.Swap = W

local STAY = { ["L.0ef7ef99"] = true, ["L.11637a9d"] = true, ["L.704a7759"] = true, ["L.d116cdfc"] = true,
    ["L.e0beab2e"] = true }
local BINDINGS = {
    BINDING_NAME_WHATTHEWHISPER_TOGGLE = "L.675ca07c", BINDING_NAME_WHATTHEWHISPER_EXPOSE = "L.ee627ce9",
    BINDING_NAME_WHATTHEWHISPER_REPLY = "L.270fcac7",
}

local keyOf = {}           -- "L." .. hash -> its English key
local rev, back = {}, {}   -- English key -> ours, ours -> English key
local other = {}           -- a text in one of its other languages -> its English key (false: none)
local swapped = {}         -- English key -> ours, while ours is in the enUS table
local bound = {}           -- binding global -> what it held before ours
local sounds = {}          -- sound list entry -> its English label, while ours is in it
local built, on = false, false

function W.Addon()
    local a = rawget(_G, "WhatTheWhisper")
    return type(a) == "table" and a or nil
end

local function Tables()
    local a = W.Addon()
    local d = a and a.LocaleData
    return type(d) == "table" and d or nil
end

function W.Base()
    local d = Tables()
    local t = d and d.enUS
    return type(t) == "table" and t or nil
end

-- The language in force in it now ("enUS" when unknown).
function W.Active()
    local a = W.Addon()
    local ok, code = U.SafeCall(a and a.ActiveLocale)
    return ok and type(code) == "string" and code or "enUS"
end

-- True for a data key that stays English on purpose.
function W.Skip(h)
    if STAY[h] then return true end
    local s = ns.SORT[h]
    return type(s) == "string" and s:find("[nu]") ~= nil
end

local function Build()
    local base = W.Base()
    if built or not base then return end
    for k in pairs(base) do
        if type(k) == "string" then
            local h = "L." .. U.Hash(k)
            keyOf[h] = k
            local ua = not W.Skip(h) and ns.AL[h]
            if type(ua) == "string" and ua ~= "" then
                rev[k] = ua
                -- Two of its keys with the same Ukrainian: ours alone cannot tell which (false).
                if back[ua] == nil or back[ua] == k then back[ua] = k else back[ua] = false end
            end
        end
    end
    built = true
end
W.Build = Build

-- Ours for one English text of it (a locale text, or one its code writes itself), or nil.
function W.Translate(en)
    en = U.Plain(en)
    if not en or en == "" then return nil end
    Build()
    return rev[en] or ns.AL["X." .. U.Hash(en)]
end

-- Its English key for one text of ours from its locale table, or nil (also when two of its keys share it).
function W.English(ua)
    ua = U.Plain(ua)
    return ua and back[ua] or nil
end

-- True for a text of ours from its locale table (also one that two of its keys share).
function W.Ours(ua)
    ua = U.Plain(ua)
    return ua ~= nil and back[ua] ~= nil
end

-- True for one of its English keys that has ours.
function W.Has(k) Build() return type(k) == "string" and rev[k] ~= nil end

-- The English key of a text it shows now: ours, its English, or the same text in another of its languages.
-- Only keys that have ours: a text without ours is never touched. A text that two keys share (ours, or one of
-- its other languages) gives nil: the caller uses what it knew of the text before (Screen.lua).
function W.KeyOf(text)
    text = U.Plain(text)
    if not text or text == "" then return nil end
    Build()
    if back[text] ~= nil then return back[text] or nil end
    if rev[text] then return text end
    if other[text] ~= nil then return other[text] or nil end
    local found = nil
    for code, t in pairs(Tables() or {}) do
        if code ~= "enUS" and type(t) == "table" then
            for k in pairs(rev) do
                if t[k] == text and found ~= k then
                    if found ~= nil then found = false break end
                    found = k
                end
            end
        end
        if found == false then break end
    end
    other[text] = found or false
    return found or nil
end

-- What its L gives for a key now (ours while ours is in, else the language in force), or nil.
function W.Word(k)
    local a = W.Addon()
    local L = a and a.L
    if type(L) ~= "table" or type(k) ~= "string" then return nil end
    local ok, v = pcall(function() return L[k] end)
    return ok and type(v) == "string" and v or nil
end

local function PutGlobal(name, v) _G[name] = v end

-- Its export format labels, made at load in its English: each one's key is kept from when it was last known, so
-- ours that two keys share still finds its way back. A text that is not ours and not known is left as it is.
local labelKey = setmetatable({}, { __mode = "k" })
local function Labels()
    local a = W.Addon()
    local E = a and a.Export
    for _, f in ipairs(type(E) == "table" and type(E.FORMATS) == "table" and E.FORMATS or {}) do
        local k = type(f) == "table" and W.KeyOf(f.label)
        if k then labelKey[f] = k elseif type(f) == "table" and W.Ours(f.label) then k = labelKey[f] end
        local w = k and W.Word(k)
        if w and w ~= f.label then f.label = w end
    end
end

local function SoundList()
    local a = W.Addon()
    local S = a and a.Sounds
    local list = type(S) == "table" and S.LIBRARY
    return type(list) == "table" and list or {}
end

-- Texts it never shows translated now, for U.Missed (only while "/uadd missed on").
local function NoteMissed()
    if not U.MissedOn() then return end
    for h, k in pairs(keyOf) do
        if not rev[k] and not W.Skip(h) then U.Missed("wtw", k) end
    end
end

function W.SwapIn()
    local base = W.Base()
    if not base then return end
    Build()
    for k, ua in pairs(rev) do
        if rawget(base, k) == k then
            rawset(base, k, ua)
            swapped[k] = ua
        end
    end
    for name, h in pairs(BINDINGS) do
        local k = keyOf[h]
        local ua = k and rev[k]
        local now = rawget(_G, name)
        if ua and now == k and bound[name] == nil then
            bound[name] = now
            PutGlobal(name, ua)
        end
    end
    for _, e in ipairs(SoundList()) do
        local en = type(e) == "table" and sounds[e] == nil and U.Plain(e.label)
        local ua = en and ns.AL["X." .. U.Hash(en)]
        if ua then sounds[e], e.label = en, ua end
    end
    on = true
    Labels()
    NoteMissed()
end

function W.SwapOut()
    local base = W.Base()
    if base then
        for k, ua in pairs(swapped) do
            if rawget(base, k) == ua then rawset(base, k, k) end
        end
    end
    wipe(swapped)
    for name, was in pairs(bound) do
        local k = keyOf[BINDINGS[name]]
        if k and rawget(_G, name) == rev[k] then PutGlobal(name, was) end
    end
    wipe(bound)
    for e, en in pairs(sounds) do
        if e.label == ns.AL["X." .. U.Hash(en)] then e.label = en end
    end
    wipe(sounds)
    on = false
    Labels()
end

-- True while ours is in its table.
function W.On() return on end

-- ── Its saved file stays English (lesson 14) ──────────────────────────────────────────────────
-- Its "save to a file" (Export.ToFile) writes a whole conversation, with its words for the player's side and
-- the day lines, into its saved data. For the length of that one call its English is in its table and the
-- day names are its own (Days.lua asks W.Saving), then ours goes back: the export on screen stays ours, the
-- file is whole English. Only values that still hold ours are switched, both ways. No U.Safe here: it must
-- also work after the module went off for errors.

local saving = false
local saves                         -- { orig = its ToFile, fn = ours }

function W.Saving() return saving end

function W.WithEnglish(fn, ...)
    local base = W.Base()
    if saving or not base then return fn(...) end
    local put = {}
    for k, ua in pairs(swapped) do
        if rawget(base, k) == ua then
            rawset(base, k, k)
            put[k] = ua
        end
    end
    saving = true
    local function Finish(ok, ...)
        saving = false
        for k, ua in pairs(put) do
            if rawget(base, k) == k and swapped[k] == ua then rawset(base, k, ua) end
        end
        if not ok then error((...), 0) end      -- its own error, as without us
        return ...
    end
    return Finish(pcall(fn, ...))
end

function W.Install()
    local a = W.Addon()
    local E = a and a.Export
    if saves or type(E) ~= "table" or type(E.ToFile) ~= "function" then return end
    local orig = E.ToFile
    local function fn(...) return W.WithEnglish(orig, ...) end
    saves = { orig = orig, fn = fn }
    E.ToFile = fn
end

-- Off: its own function back, unless someone wrapped it after us (ours then has nothing to switch).
function W.Remove()
    local a = W.Addon()
    local E = a and a.Export
    if saves and type(E) == "table" and E.ToFile == saves.fn then
        E.ToFile = saves.orig
        saves = nil
    end
end

-- Texts of ours in its tables and copies now.
function W.Count()
    local n = 0
    for _ in pairs(swapped) do n = n + 1 end
    for _ in pairs(bound) do n = n + 1 end
    for _ in pairs(sounds) do n = n + 1 end
    return n
end
