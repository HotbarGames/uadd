-- What a %s in one of DialogueUI's formats may hold, for Words.lua. A %s that only takes any text
-- would turn another text that merely starts or ends like the format into a half-translated line
-- ("Рівень 60, Elite"). So a %s must hold one of these, or the format does not fit:
--   * a number or an amount, or only a picture (IsValue);
--   * a time from DialogueUI's API.SecondsToTime: its units go into Ukrainian (Time);
--   * one of DialogueUI's own texts: translated too (a widget name, "not bound");
--   * what SLOTS says that key's %s holds (a game name, an addon name, a key binding, an item link).
-- A value with a line break or ". " in it, or over MAX_CAP bytes, is prose: it never fits.
-- Words.lua tries the next format then, and in the end leaves the whole text English.

local _, ns = ...
local U = UADD
local S = { unsure = false }   -- unsure: UALL said "not now" while filling; Words.lua keeps no memo then
ns.Slots = S

local CYR = "[\208-\210]"
local MAX_CAP = 60

-- ── What a %s may hold ───────────────────────────────────────────────────────────────────────

-- What DialogueUI puts in the %s of these keys (read from its code). A key not here takes only a
-- number, a time or one of its own texts (a widget name, "not bound").
--   name   a game name: a faction, a title, a quest, an NPC (starts with a capital letter)
--   quest  a quest title or link; npc an NPC name; item an item link: the name inside goes through
--          UALL Forever (UADD.UALL) when it is on, and stays English when UALL has none
--   list   game names joined with ", "
--   addon  an addon's name; player a character's name
--   key    a key binding ("SPACE", "CTRL-F1")
local SLOTS = {
    ["Format Reputation Reward Tooltip"] = "name", ["Format Reward Title"] = "name",
    ["Format Quest Accepted"] = "quest", ["Format Quest Completed"] = "quest",
    ["Block Auto Pushed Quest Alert Format"] = "quest", ["Format Monster Say"] = "npc",
    ["Format Replace Item"] = "item", ["Format Breadcrumb Quests Available"] = "list",
    ["Format Functionality Handled By"] = "addon", ["ItemEvaluator ThirdParty Missing Format"] = "addon",
    ["ItemEvaluator ThirdParty Found Format"] = "addon", ["VO Provider Format"] = "addon",
    ["VO No File Format"] = "addon", ["Format RP Name Example"] = "player",
    ["Press Key To Use Item Desc Generic"] = "key", ["Instruction Open Settings Keybind Format"] = "key",
}

-- Colour codes and pictures out.
local function Bare(c) return (c:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")) end

-- A %s value that is a name (a quest, an item, a faction), not a piece of prose.
local function NameLike(c)
    if c:find("\n", 1, true) or c:find(". ", 1, true) then return false end
    c = c:gsub("|T.-|t", "T"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return #c <= MAX_CAP
end

-- A value DialogueUI puts in a %s as it is: no letters but a unit of 1 to 3 right after a digit
-- ("1,234", "12.3k", "--"), or only a picture.
local function IsValue(c)
    c = Bare(c)
    local from = 1
    while true do
        local a, b = c:find("%a+", from)
        if not a then return true end
        if b - a > 2 or a == 1 or not c:find("^%d", a - 1) then return false end
        from = b + 1
    end
end

-- DialogueUI's times (API.SecondsToTime: "2 |4Hr:Hr; 5 |4Min:Min;", in red when past) in Ukrainian.
local UNIT = { day = "д", days = "д", hr = "год", hrs = "год", hour = "год", hours = "год", min = "хв",
    mins = "хв", minute = "хв", minutes = "хв", sec = "с", secs = "с", second = "с", seconds = "с" }
local function Unit(w)
    local a, b = w:match("^|4([^:;]+):([^;]+);$")
    if a then
        a, b = UNIT[a:lower()], UNIT[b:lower()]
        return a == b and a or nil
    end
    return UNIT[w:lower()]
end
local function Time(c)
    local code, s = c:match("^(|c%x%x%x%x%x%x%x%x)(.-)|r$")
    s = s or c
    local words, out = {}, {}
    for w in s:gmatch("%S+") do words[#words + 1] = w end
    if #words == 0 or #words % 2 == 1 or #words > 8 or table.concat(words, " ") ~= s then return nil end
    for i = 1, #words, 2 do
        local u = Unit(words[i + 1])
        if not u or not words[i]:find("^%-?%d+$") then return nil end
        out[#out + 1] = words[i] .. " " .. u
    end
    local uk = table.concat(out, " ")
    return code and code .. uk .. "|r" or uk
end

-- A name from UALL Forever (UADD.UALL), or nil. Asked only when UALL is on; "not now" (combat, the
-- show-original key) leaves it English this time and keeps the answer out of the memo.
local function FromUALL(how, ...)
    local A = U.UALL
    local ok, on = pcall(function() return A and A.IsAvailable and A.IsAvailable() end)
    if not ok or not on or type(A[how]) ~= "function" then return nil end
    local uk, wait = A[how](...)
    if wait then S.unsure = true end
    if type(uk) == "string" and uk:find(CYR) then return uk end
    return nil
end

-- A game name: no prose (NameLike) and starts with a capital letter (a quote or bracket may come first).
local function GameName(c) return Bare(c):find("^[\"'%[(]?%u") ~= nil end

-- A link's name in Ukrainian through `how` (or as it is), or nil when c is not a link of this kind.
local function Link(c, kind, how)
    local head, id, mid, name, tail = c:match("^(|c%x%x%x%x%x%x%x%x|H" .. kind .. ":)(%d*)([^|]*|h%[)(.-)(%]|h|r)$")
    if not head or name == "" then return nil end
    local uk = FromUALL(how, how == "Quest" and tonumber(id) or name, how == "Quest" and name or nil)
    return head .. id .. mid .. (uk or name) .. tail
end

local function Quest(c)
    local link = Link(c, "quest", "Quest")
    if link then return link end
    if not GameName(c) then return false end
    return FromUALL("Quest", nil, c)
end

-- What a %s of kind `kind` holding c becomes: a new value, nil to keep it, false when it cannot be that.
local CHECK = {
    name = function(c) if not GameName(c) then return false end end,
    quest = Quest,
    npc = function(c)
        if not GameName(c) then return false end
        return FromUALL("Npc", c)
    end,
    item = function(c) return Link(c, "item", "Item") or false end,
    list = function(c)
        local out, changed = {}, false
        for piece in (c .. ", "):gmatch("(.-), ") do
            local uk = Quest(piece)
            if uk == false then return false end
            out[#out + 1], changed = uk or piece, changed or uk ~= nil
        end
        return changed and table.concat(out, ", ") or nil
    end,
    addon = function(c) if #c > 40 or not Bare(c):find("^%w") then return false end end,
    player = function(c) if #c > 40 or not GameName(c) then return false end end,
    key = function(c) if #c > 24 or c:find("[%l%s|]") then return false end end,
}

-- ── Bounds on the hot path ────────────────────────────────────────────────────────────────────

-- A text whose name UALL said "not now" for stays out of Words.lua's memo, so it is kept here for a
-- short while instead: until combat, a modifier key or login changes (what UALL waits on), and at most
-- 2 seconds (UALL checks its route again). Then it is asked once more, so a wrong English answer is
-- never kept for good, and a text shown on every frame in combat does not search every time.
local soon, soonBody, soonState = {}, {}, nil
local function On(f) return f and f() and "1" or "0" end
local function State()
    return On(InCombatLockdown) .. On(IsShiftKeyDown) .. On(IsControlKeyDown) .. On(IsAltKeyDown)
        .. On(IsLoggedIn) .. math.floor((GetTime and GetTime() or 0) / 2)
end

-- Words.lua's answer for t kept by S.Keep in the same state: Ukrainian, false (English) or nil.
function S.Soon(t, body)
    local state = State()
    if state ~= soonState then wipe(soon) wipe(soonBody) soonState = state end
    return (body and soonBody or soon)[t]
end
function S.Keep(t, body, uk) (body and soonBody or soon)[t] = uk or false end

-- A %s that is one of DialogueUI's own texts may hold a format again, and so on: two levels at most
-- (cut), and each value is looked up once (own) unless UALL said "not now" or the cut was reached.
local MAX_DEPTH = 2
local depth, cut, own, ownSize = 0, false, {}, 0
function S.Begin() S.unsure, cut, depth = false, false, 0 end
function S.Reset() wipe(own) ownSize = 0 wipe(soon) wipe(soonBody) end

local function Own(one, v)
    local hit = own[v]
    if hit ~= nil then return hit or nil end
    if depth >= MAX_DEPTH then cut = true return nil end
    local wasUnsure, wasCut = S.unsure, cut
    S.unsure, cut, depth = false, false, depth + 1
    local uk = one(v)
    depth = depth - 1
    local unsure, gotCut = S.unsure, cut
    S.unsure, cut = wasUnsure or unsure, wasCut or gotCut
    if not unsure and not gotCut then
        if ownSize > 1000 then wipe(own) ownSize = 0 end
        own[v], ownSize = uk or false, ownSize + 1
    end
    return uk
end

-- The fill check for Words.lua's templates (Hash.lua): a new value for slot k, nil to keep it, or
-- false: this template does not fit, the next best is tried. `one` translates a text that is one of
-- DialogueUI's own (a widget name inside a sentence).
function S.Filler(one)
    return function(k, v, d)
        if d.kinds[k] ~= "s" then return nil end
        if not NameLike(v) then return false end
        local tm = Time(v)
        if tm then return tm end
        if IsValue(v) then return nil end
        local uk = Own(one, v)
        if uk then return uk end
        local check = CHECK[SLOTS[d.id]]
        if not check then return false end
        return check(v)
    end
end
