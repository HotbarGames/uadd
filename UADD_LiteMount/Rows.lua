-- UADD_LiteMount: texts LiteMount sets again and again on its panels, out of Screen.lua's walk:
--   * the Falling page's rows (a scroll list): each row's Delete button (text="DELETE"), made when a row is made;
--   * the Mounts page's counts line (UI/Mounts.lua: TOTAL, a number, COLLECTED, a number, L.LM_USABLE, a number),
--     set at each refresh;
--   * the Macro page's character count (UI/Macro.lua: format(MACROFRAME_CHAR_LIMIT, n)), set at each key press.
--   * game names (docs/LESSONS.md lesson 9: never ours): a Falling row's spell or item name and a mount's name
--     in the Mounts list (LiteMountMountCommonButtonMixin), asked of UALL Forever / ClassicUA by the English
--     name (UADD.UALL.Spell, .Item: lesson 20). No answer, "not now" or an error: the name stays English, whole.
--     The search box and the player's own names are not touched (LESSONS2 13).
-- Each is ours only while its game globals are English (Lc.Global; never written) and only as a whole line: a
-- line that does not read as expected stays English. Held and off: a text we set goes back to the English it had,
-- while it still shows ours (lesson 23).
local _, ns = ...
local U = UADD
local Lc = ns.Locale
local R = {}
ns.Rows = R

local last = setmetatable({}, { __mode = "k" })    -- FontString -> { English, ours } we last set
local lines = setmetatable({}, { __mode = "k" })   -- FontString -> its builder
local rows = setmetatable({}, { __mode = "k" })    -- the Falling rows seen
local hooked = {}
local seenFs = setmetatable({}, { __mode = "k" })  -- FontStrings whose SetText we hooked
local busy = false

local function Wanted() local ok, w = pcall(ns.WordsWanted) return ok and w end

local function Value(s)
    s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return s:find("^%d+$") ~= nil
end

-- The counts line: our words for its three labels, the numbers as they are; nil when any part is not there.
local function Counts(t)
    local te, tu = Lc.Global("TOTAL")
    local ce, cu = Lc.Global("COLLECTED")
    local ue, uu = Lc.En("LM_USABLE"), Lc.Word("LM_USABLE")
    if not (tu and cu and uu) then return nil end
    local a = te .. ": "
    if t:sub(1, #a) ~= a then return nil end
    local mc, mu = " " .. ce .. ": ", " " .. ue .. ": "
    local b = t:find(mc, #a + 1, true)
    local c = b and t:find(mu, b + #mc, true)
    if not c then return nil end
    local x, y, z = t:sub(#a + 1, b - 1), t:sub(b + #mc, c - 1), t:sub(c + #mu)
    if not (Value(x) and Value(y) and Value(z)) then return nil end
    return tu .. ": " .. x .. " " .. cu .. ": " .. y .. " " .. uu .. ": " .. z
end

-- The character count: its one number kept; nil when the global is not one %d inside plain text.
local function Chars(t)
    local en, uk = Lc.Global("MACROFRAME_CHAR_LIMIT")
    if not uk then return nil end
    local a, b = en:find("%d", 1, true)
    if not a or en:find("%", b + 1, true) or en:find("%", 1, true) < a then return nil end
    local head, tail = en:sub(1, a - 1), en:sub(b + 1)
    if #t <= #head + #tail or t:sub(1, #head) ~= head or t:sub(#t - #tail + 1) ~= tail then return nil end
    local n = t:sub(#head + 1, #t - #tail)
    if not n:find("^%d+$") then return nil end
    return (uk:gsub("%%d", n, 1))
end

local function Set(fs, s)
    busy = true
    local ok = pcall(fs.SetText, fs, s)
    busy = false
    return ok
end

local function Put(fs, want)
    local t = fs:GetText()
    if type(t) ~= "string" then return end
    local l = last[fs]
    if want then
        local uk = lines[fs](t)
        if uk and uk ~= t and Set(fs, uk) then last[fs] = { t, uk } end
    elseif l and t == l[2] then
        Set(fs, l[1])
        last[fs] = nil
    end
    U.SafeCall(ns.Fonts.Settle, fs)
end
local SafePut = Lc.Guard(Put)        -- not U.Safe: after an off for errors, "on" brings it back (Locale.lua)

-- After LiteMount sets the line: ours on it while wanted; the English stays when held or off.
local function OnSet(fs)
    if busy or not lines[fs] then return end
    last[fs] = nil
    if Wanted() then SafePut(fs, true) else pcall(U.SafeCall, ns.Fonts.Settle, fs) end
end

-- A row may be used again for another kind of name: its line keeps one hook, and the builder is swapped.
local function Line(fs, build)
    if type(fs) ~= "table" or type(fs.SetText) ~= "function" then return end
    if not seenFs[fs] then seenFs[fs] = true hooksecurefunc(fs, "SetText", OnSet) end
    lines[fs] = build
end

-- Our text off a line, back to the English it had (before its builder is swapped).
local function Back(fs)
    local l = last[fs]
    if l and fs:GetText() == l[2] then Set(fs, l[1]) end
    last[fs] = nil
end

-- The English again on a line that shows ours (Fonts.lua: no Cyrillic font took on it); true when it went back.
function R.English(fs)
    local l = last[fs]
    if not (l and fs:GetText() == l[2]) then return false end
    Back(fs)
    return true
end

-- A game name, asked of UALL Forever / ClassicUA by its English (lesson 20). Only a Cyrillic answer counts; "not
-- now" and an error are not kept, so the next call asks again. Odd text (a code, a link, a long line) is not asked.
local function Game(route)
    local seen, n = {}, 0
    return function(t)
        local v = seen[t]
        if v ~= nil then return v or nil end
        if #t > 80 or t:find("[|\n%[%(]") or t ~= t:match("^%s*(.-)%s*$") then return nil end
        local f = type(U.UALL) == "table" and U.UALL[route]
        if type(f) ~= "function" then return nil end
        local ok, uk, later = pcall(f, t)
        if not ok or later then return nil end
        v = type(uk) == "string" and uk ~= t and uk:find("[\208\209]") ~= nil and uk or false
        if n >= 2000 then seen, n = {}, 0 end
        seen[t], n = v, n + 1
        return v or nil
    end
end
local function NONE() return nil end
local NAMES = { spell = Game("Spell"), item = Game("Item") }  -- a Falling row's kind: "spell:<id>", "item:<id>"

local function Row(b, want, data)
    rows[b] = true
    local n = type(b) == "table" and rawget(b, "Name")
    if data ~= nil and type(n) == "table" and type(n.GetText) == "function" then
        Back(n)
        local kind = type(data) == "string" and data:match("^(%a+):")
        Line(n, NAMES[kind] or NONE)                    -- a slot row ("slot (item)") stays English
        Put(n, want)
    end
    local d = type(b) == "table" and rawget(b, "DeleteButton")
    if type(d) ~= "table" or type(d.GetFontString) ~= "function" then return end
    U.SafeCall(ns.Fonts.HookButton, d)
    ns.Screen.Swap(d:GetFontString(), want)
end

local SafeRow = Lc.Guard(Row)
local function OnRow(b, data)
    local want = Wanted()
    if want then SafeRow(b, true, data) else pcall(Row, b, false, data) end
end

-- A mount's row in the Mounts list: its name is the mount's spell name.
local function Mount(b, want)
    local n = type(b) == "table" and rawget(b, "Name")
    if type(n) ~= "table" or type(n.GetText) ~= "function" then return end
    Line(n, NAMES.spell)
    Put(n, want)
end

local SafeMount = Lc.Guard(Mount)
local function OnMount(b)
    local want = Wanted()
    if want then SafeMount(b, true) else pcall(Mount, b, false) end
end

function R.Hook()
    local m = rawget(_G, "LiteMountMountsPanel")
    if type(m) == "table" then Line(rawget(m, "Counts"), Counts) end
    local mac = rawget(_G, "LiteMountMacroPanel")
    mac = type(mac) == "table" and rawget(mac, "Macro")
    if type(mac) == "table" then Line(rawget(mac, "Count"), Chars) end
    local mix = rawget(_G, "LiteMountItemSpellMixin")
    if not hooked.rows and type(mix) == "table" and type(mix.Initialize) == "function" then
        hooked.rows = true
        hooksecurefunc(mix, "Initialize", OnRow)        -- its rows are made later, from this mixin
    end
    local mm = rawget(_G, "LiteMountMountCommonButtonMixin")  -- the list and grid rows call its Initialize
    if not hooked.mounts and type(mm) == "table" and type(mm.Initialize) == "function" then
        hooked.mounts = true
        hooksecurefunc(mm, "Initialize", OnMount)
    end
end

function R.Sync(want)
    if want == nil then want = ns.WordsWanted() end    for fs in pairs(lines) do U.SafeCall(Put, fs, want) end
    for b in pairs(rows) do U.SafeCall(Row, b, want) end
end
function R.Restore() R.Sync(false) end
