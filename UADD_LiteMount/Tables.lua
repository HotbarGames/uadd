-- UADD_LiteMount: the words LiteMount copies out of L when its files load, switched both ways (lesson 15).
-- Conditions: each condition's .name, written in its own table (LM.Conditions:GetCondition).
-- Actions, sort keys, mount filters, condition lines: their tables are file-local, so the public functions
-- that hand them out are wrapped; a wrapper changes only a text that is exactly the English it copied,
-- does nothing while our words are not wanted, and is taken away on off when it is still ours.
-- Its dialogs (StaticPopupDialogs) and its four key binding names: the fields LiteMount wrote, only while
-- they still hold its English. The secure buttons (LiteMount, LM_B1..4) and its macro text are never touched.
local _, ns = ...
local U = UADD
local Lc = ns.Locale
local Guard = Lc.Guard                                -- kept at load (Locale.lua)
local T = {}
ns.Tables = T


-- Condition id -> its name key (the ones built with L at load; the area ones use a game word: English).
local CONDS = {
    btn = "LM_MOUSE_BUTTON_CLICKED", covenant = "LM_COVENANT", equipped = "LM_ITEM_EQUIPPED",
    flightstyle = "LM_FLIGHT_STYLE", friend = "LM_FRIEND_IN_GROUP", gather = "LM_GATHERED_RECENTLY",
    group = "LM_PARTY_OR_RAID_GROUP", holiday = "LM_HOLIDAY", known = "LM_SPELL_KNOWN",
    mod = "LM_MODIFIER_KEY", mounted = "LM_MOUNTED", season = "LM_SEASON", sex = "LM_SEX",
}
local ACT_NAMES = { "LM_LIMIT_MOUNTS", "LM_INCLUDE_MOUNTS", "LM_EXCLUDE_MOUNTS", "LM_SPELL_ACTION",
    "LM_PRECAST_ACTION", "LM_MOUNT_ACTION", "LM_SMARTMOUNT_ACTION", "LM_PRIORITYMOUNT_ACTION",
    "LM_FORCE_NEW_RANDOM_ACTION", "LM_USE_ACTION", "LM_PREUSE_ACTION", "LM_FALLING_ACTION" }
local ACT_DESCS = { "LM_LIMITSET_DESCRIPTION", "LM_LIMITINCLUDE_DESCRIPTION", "LM_LIMITEXCLUDE_DESCRIPTION",
    "LM_SPELL_DESCRIPTION", "LM_PRECAST_DESCRIPTION", "LM_MOUNT_DESCRIPTION", "LM_SMARTMOUNT_DESCRIPTION",
    "LM_PRIORITYMOUNT_DESCRIPTION", "LM_FORCE_NEW_RANDOM_DESCRIPTION", "LM_USE_DESCRIPTION",
    "LM_PREUSE_DESCRIPTION" }
-- Its dialogs: name, field, how LiteMount builds it from a word getter W.
local POPS = {
    { "LM_OPTIONS_NEW_GROUP", "text", function(W) return format("LiteMount : %s", W("LM_NEW_GROUP")) end },
    { "LM_OPTIONS_NEW_GROUP", "button1", function(W) return W("LM_CREATE_PROFILE_GROUP") end },
    { "LM_OPTIONS_NEW_GROUP", "button2", function(W) return W("LM_CREATE_GLOBAL_GROUP") end },
    { "LM_OPTIONS_RENAME_GROUP", "text", function(W) return format("LiteMount : %s", W("LM_RENAME_GROUP")) end },
    { "LM_OPTIONS_DELETE_GROUP", "text", function(W) return format("LiteMount : %s", W("LM_DELETE_GROUP")) end },
    { "LM_OPTIONS_NEW_PROFILE", "text", function(W) return format("LiteMount : %s", W("LM_NEW_PROFILE")) end },
    { "LM_OPTIONS_RESET_PROFILE", "text", function(W) return "LiteMount : " .. W("LM_RESET_PROFILE") .. " %s" end },
}
local BIND = "BINDING_NAME_CLICK LM_B%d:LeftButton"

local function Want() return ns.WordsWanted() end
local function Word(k) return assert(Lc.Word(k), k) end

-- Maps English -> key, built once.
local actEn, descEn
local function Maps()
    if actEn then return end
    actEn, descEn = {}, {}
    for _, k in ipairs(ACT_NAMES) do actEn[Lc.En(k)] = k end
    for _, k in ipairs(ACT_DESCS) do descEn[Lc.En(k)] = k end
end

-- A text with no English in it: no Latin letters once colour and icon codes are out, or one of our words.
local function NoEnglish(t)
    if type(t) ~= "string" then return t == nil end
    if Lc.IsOurs(t) then return true end
    local s = t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", "")
    return not s:find("%a")
end

-- ── Wrapped functions ─────────────────────────────────────────────────────────────────────────

local wraps = {}       -- { holder, field, original, wrapper }

local function Wrap(holder, field, make)
    if type(holder) ~= "table" then return end
    for _, w in ipairs(wraps) do
        if w[1] == holder and w[2] == field and holder[field] == w[4] then return end
    end
    local orig = rawget(holder, field)
    if type(orig) ~= "function" then return end
    local wrapper = make(orig)
    holder[field] = wrapper
    wraps[#wraps + 1] = { holder, field, orig, wrapper }
end

local function Unwrap()
    for i = #wraps, 1, -1 do
        local w = wraps[i]
        if w[1][w[2]] == w[4] then w[1][w[2]] = w[3] end
        wraps[i] = nil
    end
end

-- A condition line: its name and its value. Our name only when the value is ours or plain (a number);
-- with English in it the whole line stays English. "Not %s" follows the same choice (Lc.SetNot).
local function Leaf(c, a)
    if type(c) ~= "string" then return c, false end
    local en = Lc.Back(c) or Lc.GlobalBack(c)
    if not en then return c, false end
    if NoEnglish(a) then return c, true end
    return en, false
end

local function CondToDisplay(orig)
    return function(self, ...)
        local c, a = orig(self, ...)
        if not Want() then return c, a end
        local ok, c2, ours = pcall(Leaf, c, a)
        if ok then
            c = c2
            pcall(Lc.SetNot, ours)
        end
        return c, a
    end
end

-- A mount filter as LiteMount shows it, and whether it is ours ("Група : <name>", "Пріоритет : 3").
local function Ours(t)
    if type(t) ~= "string" then return false end
    if Lc.IsOurs(t) then return true end
    for _, k in ipairs({ "LM_GROUP", "LM_PRIORITY" }) do
        local w = Lc.Word(k)
        if w and t:sub(1, #w + 3) == w .. " : " then return true end
    end
    return false
end

local function FilterToDisplay(orig)
    local function Show(f)
        if type(f) == "string" and f:sub(1, 1) == "~" then
            local t, ours = Show(f:sub(2))
            local fmt = ours and Lc.Word("LM_NOT_FORMAT") or Lc.En("LM_NOT_FORMAT")
            return format(fmt, t), ours
        end
        local t = orig(f)
        return t, Ours(t)
    end
    return function(f, ...)
        if not (Want() and type(f) == "string" and f:sub(1, 1) == "~") then return orig(f, ...) end
        local ok, t = pcall(Show, f)
        if ok and type(t) == "string" then return t end
        return orig(f, ...)
    end
end

local function First(map)
    return function(orig)
        local function After(a, ...)
            if Want() and type(a) == "string" then
                Maps()
                local k = map()[a]
                local w = k and Lc.Word(k)
                if w then return w, ... end
            end
            return a, ...
        end
        return function(self, ...) return After(orig(self, ...)) end
    end
end

local function SortKeyText(orig)
    return function(k, ...)
        local r = orig(k, ...)
        if Want() and r == Lc.En("LM_PRIORITY") and Lc.Word("LM_PRIORITY") then return Lc.Word("LM_PRIORITY") end
        return r
    end
end

local function Install()
    local LM = Lc.Target()
    if not LM then return end
    Wrap(LM.Conditions, "ToDisplay", CondToDisplay)
    Wrap(LM.Mount, "FilterToDisplay", FilterToDisplay)
    Wrap(LM.Actions, "ToDisplay", First(function() return actEn end))
    Wrap(LM.Actions, "GetDescription", First(function() return descEn end))
    Wrap(LM.UIFilter, "GetSortKeyText", SortKeyText)
end

-- ── Fields written in place ───────────────────────────────────────────────────────────────────

local bindEn = {}

local function Fields(want)
    local LM = Lc.Target()
    if not LM then return end
    local C = LM.Conditions
    if type(C) == "table" and type(C.GetCondition) == "function" then
        for id, k in pairs(CONDS) do
            local okC, c = pcall(C.GetCondition, C, id)
            local w = Lc.Word(k)
            if okC and type(c) == "table" and w then
                if want and c.name == Lc.En(k) then c.name = w
                elseif not want and c.name == w then c.name = Lc.En(k) end
            end
        end
        -- Named by a game global (Instance, Level, Map, Falling): our word while the global is not Cyrillic.
        for id, g in pairs(Lc.GLOBAL_CONDS) do
            local okC, c = pcall(C.GetCondition, C, id)
            local en, uk = Lc.Global(g, not want)
            if okC and type(c) == "table" and uk then
                if want and c.name == en then c.name = uk
                elseif not want and c.name == uk then c.name = en end
            end
        end
    end
    local D = rawget(_G, "StaticPopupDialogs")
    for _, p in ipairs(POPS) do
        local d = type(D) == "table" and D[p[1]]
        local okE, en = pcall(p[3], Lc.En)
        local okU, uk = pcall(p[3], Word)
        if type(d) == "table" and okE and okU then
            if want and d[p[2]] == en then d[p[2]] = uk
            elseif not want and d[p[2]] == uk then d[p[2]] = en end
        end
    end
    for n = 1, 4 do
        local name = BIND:format(n)
        local now = rawget(_G, name)
        if bindEn[n] == nil and type(now) == "string" then bindEn[n] = now end
        local uk = bindEn[n] and Lc.Extra("BINDING_" .. n, bindEn[n])
        if uk then
            if want and now == bindEn[n] then _G[name] = uk
            elseif not want and now == uk then _G[name] = bindEn[n] end
        end
    end
end

-- Its "add a spell or item" box: a dropdown built in its OnShow from a file-local list; its one word of ours
-- (LM_EQUIPMENT_SLOT) is swapped as the menu is built, through a stand-in for the menu it fills.
local SLOT = "LM_EQUIPMENT_SLOT"
local theirs, ours, broken = nil, nil, false

local function Stand(root)
    return setmetatable({}, { __index = function(_, k)
        local v = root[k]
        if k == "CreateRadio" and type(v) == "function" then
            return function(_, text, ...)
                if Want() and text == Lc.En(SLOT) and Lc.Word(SLOT) then text = Lc.Word(SLOT) end
                return v(root, text, ...)
            end
        end
        if type(v) == "function" then return function(_, ...) return v(root, ...) end end
        return v
    end })
end

local function Dropdown()
    local f = rawget(_G, "LiteMountFallingAdd")
    local dd = type(f) == "table" and f.Dropdown
    if type(dd) == "table" and type(dd.SetupMenu) == "function" then return dd end
    return nil
end

function T.Falling()
    if broken or not Lc.Word(SLOT) then return end
    local dd = Dropdown()
    local g = dd and rawget(dd, "menuGenerator")
    if type(g) ~= "function" then return end
    if g ~= ours then
        theirs = g
        ours = function(owner, root)
            if not Want() then return theirs(owner, root) end
            local ok = pcall(theirs, owner, Stand(root))
            if not ok then broken = true end
        end
    end
    if Want() then dd:SetupMenu(ours) elseif g == ours then dd:SetupMenu(theirs) end
    if broken then dd:SetupMenu(theirs) end
end

local function FallingBack()
    local dd = Dropdown()
    if dd and theirs and rawget(dd, "menuGenerator") == ours then dd:SetupMenu(theirs) end
end

local hooked = false
local function Hook()
    if hooked then return end
    local f = rawget(_G, "LiteMountFallingAdd")
    if type(f) ~= "table" or type(f.HookScript) ~= "function" then return end
    hooked = true
    f:HookScript("OnShow", Guard(function() if Want() then T.Falling() end end))
end

function T.Sync()
    if ns.On() then
        U.SafeCall(Install)
        U.SafeCall(Hook)
    end
    local want = Want()
    U.SafeCall(Fields, want)
    local f = rawget(_G, "LiteMountFallingAdd")
    if type(f) == "table" and f.IsShown and f:IsShown() then U.SafeCall(T.Falling) end
    if not want then pcall(Lc.SetNot, false) end
end

function T.Restore()
    pcall(Unwrap)
    U.SafeCall(Fields, false)
    pcall(FallingBack)
end
