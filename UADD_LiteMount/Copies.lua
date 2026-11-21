-- UADD_LiteMount: four more places where LiteMount keeps a copy of its words, switched both ways (lesson 15).
-- 1. Its Mounts panel's filter menu (LiteMountFilter.FilterDropdown): a file-local list copies four of L's words
--    at load; the menu is built from it each time it opens. As with the Falling dropdown (Tables.lua), our
--    generator builds it through a stand-in for the menu root that swaps only those four words, and only when
--    the text is exactly their English. Group, type and flag names sit in the submenus, which the stand-in
--    never touches (lesson 13). The menu's order stays LiteMount's (sorted by its English). Each opening is
--    whole: their generator runs dry first, and if it throws, the menu is built English and stays so.
-- 2. Its General page in the game's options (LiteMountGeneralPanel): the Settings registrar builds its option
--    names once, from L. With the module on at login they are built with our words; the page's initializers
--    are switched on every on/off and hold change. A name is changed only while it is exactly the English or
--    our word for one of its keys. A page already open shows the change the next time it is opened.
-- 3. Its rule errors: they are formatted when a rule set is compiled and printed later with LM_ERR_BAD_RULE
--    around them. Its compiled sets are dropped on every change (as LiteMount does on a profile change), so the
--    next compile and its print read the same L: the line is whole English or whole Ukrainian.
-- 4. Lines glued to a game global (Lc.GLUED): the "Announce via" option (section 2) and the uidebug chat line.
-- Putting the English back (Restore) runs also when the module is off for errors, under plain pcall.
local _, ns = ...
local U = UADD
local Lc = ns.Locale
local C = {}
ns.Copies = C

local function Want() return ns.WordsWanted() end

-- ── 1. The filter menu ──────────────────────────────────────────────────────────────────────────

local FILTER = { "LM_HIDDEN", "LM_ZONEMATCH", "LM_PRIORITY", "LM_GROUP" }
local MAKERS = { CreateButton = true, CreateCheckbox = true, CreateRadio = true }
local theirs, ours, broken = nil, nil, false

local function FilterWord(text)
    for _, k in ipairs(FILTER) do
        local w = Lc.Word(k)
        if w and text == Lc.En(k) then return w end
    end
    return text
end

local function Stand(root)
    return setmetatable({}, { __index = function(_, k)
        local v = root[k]
        if MAKERS[k] and type(v) == "function" then
            return function(_, text, ...) return v(root, FilterWord(text), ...) end
        end
        if type(v) == "function" then return function(_, ...) return v(root, ...) end end
        return v
    end })
end

-- A menu root that builds nothing: each of its methods gives it back, so a dry run touches no menu.
local DRY = setmetatable({}, { __index = function(t) return function() return t end end })

local function FilterDropdown()
    local f = rawget(_G, "LiteMountFilter")
    local dd = type(f) == "table" and rawget(f, "FilterDropdown")
    if type(dd) == "table" and type(dd.SetupMenu) == "function" then return dd end
    return nil
end

local function Filter()
    if broken then return end
    local dd = FilterDropdown()
    local g = dd and rawget(dd, "menuGenerator")
    if type(g) ~= "function" then return end
    if g ~= ours then
        theirs = g
        ours = function(owner, root)
            if broken or not Want() then return theirs(owner, root) end
            -- All or nothing: a dry run first, so a generator that throws part-way builds the menu whole English.
            if not pcall(theirs, owner, Stand(DRY)) then broken = true return theirs(owner, root) end
            local ok = pcall(theirs, owner, Stand(root))
            if not ok then broken = true end
        end
        dd:SetupMenu(ours)
    end
end

local function FilterBack()
    local dd = FilterDropdown()
    if dd and theirs and rawget(dd, "menuGenerator") == ours then dd:SetupMenu(theirs) end
end

-- ── 2. The General page ─────────────────────────────────────────────────────────────────────────

local GENERAL = { "LM_COPY_TARGETS_MOUNT", "LM_ADD_MOUNTS_AT_PRIORITY_0", "LM_INSTANT_ONLY_MOVING",
    "LM_RESTORE_FORMS", "LM_ADD_TO_TOOLTIP", "LM_SUMMON_STYLE", "LM_RANDOM_PERSISTENCE", "LM_ANNOUNCE_MOUNTS",
    "LM_COLOR_BY_PRIORITY", "LM_ANNOUNCE_FLIGHT_STYLE" }
local TIMER = "LM_MOUNTSPECIAL_TIMER"         -- its name is format(L.LM_MOUNTSPECIAL_TIMER, EMOTE171_CMD1)

local function Pairs()
    local out = {}
    for _, k in ipairs(GENERAL) do
        local w = Lc.Word(k)
        if w then out[#out + 1] = { Lc.En(k), w } end
    end
    local w, cmd = Lc.Word(TIMER), rawget(_G, "EMOTE171_CMD1")
    if w and type(cmd) == "string" then
        local okE, en = pcall(string.format, Lc.En(TIMER), cmd)
        local okU, uk = pcall(string.format, w, cmd)
        if okE and okU then out[#out + 1] = { en, uk } end
    end
    return out
end

local function Initializers()
    local p = rawget(_G, "LiteMountGeneralPanel")
    local layout = type(p) == "table" and rawget(p, "layout")
    if type(layout) ~= "table" then return nil end
    if type(layout.GetInitializers) == "function" then
        local ok, list = pcall(layout.GetInitializers, layout)
        if ok and type(list) == "table" then return list end
    end
    local list = rawget(layout, "initializers")
    return type(list) == "table" and list or nil
end

-- A dropdown's option list is rebuilt from L each time it is drawn (data.options, its GetSettings): ours runs
-- theirs, then makes a glued entry ("Announce via": CHAT + our word) whole English (Lc.Unglue). Given back when off.
local theirsOf, oursOf = {}, {}

local function Labels(list)
    if type(list) ~= "table" then return end
    for _, e in ipairs(list) do
        local t = type(e) == "table" and rawget(e, "label")
        if type(t) == "string" then e.label = Lc.Unglue(t) end
    end
end

local function Options(data, want)
    local f = rawget(data, "options")
    if type(f) ~= "function" then return end
    if not want then
        if theirsOf[f] then data.options = theirsOf[f] end
        return
    end
    if theirsOf[f] then return end
    local o = oursOf[f] or function(...)
        local list = f(...)
        pcall(Labels, list)
        return list
    end
    oursOf[f], theirsOf[o] = o, f
    data.options = o
end

local function General(want)
    local list = Initializers()
    if not list then return end
    local from = {}
    for _, pr in ipairs(Pairs()) do
        if want then from[pr[1]] = pr[2] else from[pr[2]] = pr[1] end
    end
    for _, init in ipairs(list) do
        local data = type(init) == "table" and rawget(init, "data")
        if type(data) == "table" then Options(data, want) end
        local name = type(data) == "table" and rawget(data, "name")
        local new = type(name) == "string" and from[name]
        if new then
            data.name = new
            local s = rawget(data, "setting")
            if type(s) == "table" and rawget(s, "name") == name then s.name = new end
        end
    end
end

-- ── 3. Rule errors ──────────────────────────────────────────────────────────────────────────────

local last = nil

local function Rules(want)
    if want == last then return end
    last = want
    local LM = Lc.Target()
    local O = type(LM) == "table" and rawget(LM, "Options")
    local cache = type(O) == "table" and rawget(O, "cachedRuleSets")
    if type(cache) == "table" then wipe(cache) end
end

-- ── 4. Its chat lines ───────────────────────────────────────────────────────────────────────────

-- LM.Print gets the whole line; one glued to a game global (uidebug: BUG_CATEGORY5 + our word) is made whole
-- English there (Lc.Unglue). Lines with format args pass as they are. Given back when off.
local print0, printOurs = nil, nil

local function Print(want)
    local LM = Lc.Target()
    if type(LM) ~= "table" then return end
    local p = rawget(LM, "Print")
    if want then
        if type(p) ~= "function" or p == printOurs then return end
        print0 = p
        printOurs = function(msg, ...)
            if select("#", ...) == 0 then
                local ok, t = pcall(Lc.Unglue, msg)
                if ok then msg = t end
            end
            return print0(msg, ...)
        end
        LM.Print = printOurs
    elseif p == printOurs and print0 then
        LM.Print = print0
    end
end

-- ── Sync / Restore ──────────────────────────────────────────────────────────────────────────────

function C.Sync()
    if ns.On() then U.SafeCall(Filter) end
    local want = Want()
    U.SafeCall(General, want)
    U.SafeCall(Rules, want)
    U.SafeCall(Print, want)
end

function C.Restore()
    pcall(FilterBack)
    pcall(General, false)
    pcall(Rules, false)
    pcall(Print, false)
end
