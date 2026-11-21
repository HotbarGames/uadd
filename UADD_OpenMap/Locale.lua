-- OpenMap's own locale table, _G.OpenMap.L, in Ukrainian while our words are wanted.
--   * OpenMap looks up nearly every text through L["English"] when it shows it. L is a table whose
--     metatable gives the key back (English) when nothing is set: setmetatable({}, { __index }).
--     Its locale files fill it with plain assignments, so we do the same for our words (rawset when
--     there is no __newindex, so nothing of OpenMap's runs) and keep what was there before: almost
--     always nothing, so English. The hold key, "/uadd openmap off" and a reload put it back.
--   * A Ukrainian text is used only when its %s/%d list and its |c |r |T |t |H |h |n escapes match
--     the English key: a wrong one would break string.format inside OpenMap. Else English stays.
--   * Words.lua uses the same words (Forward, English) for texts OpenMap read before we ran.
-- Nothing here runs in combat: a change asked for then waits for the end of combat.

local _, ns = ...
local Lc = {}
ns.Locale = Lc
if type(UADD) == "table" then UADD.OpenMapLocale = Lc end   -- for the checks (tools/harness)

local SPEC = "%%[%d%$%-%+#0]*%.?%d*[%a%%]"
local ESCAPES = { "|c", "|r", "|T", "|t", "|H", "|h", "|n", "\n" }

Lc.entries = {}     -- English -> Ukrainian: every usable word (MAP and LOADTIME)
Lc.skipped = {}     -- English -> true: a Ukrainian text whose specs do not match (English stays)
local rev = {}      -- Ukrainian -> English (false when two English texts share it)
local fwd, back = {}, {}   -- formatted texts: { pattern, template } English->Ukrainian and back
local saved = nil   -- English -> { what L held before } while our words are in L
local wrote = {}    -- English -> the Ukrainian we put in L
local before = {}   -- English -> what L gave before our words (kept after they go: for Words.lua)
local served = {}   -- English -> Ukrainian: keys that share a text, given through L's __index
local lastRead = {} -- shared Ukrainian -> the English key OpenMap read last (Words.lua)
local index = nil   -- { mt, its own __index, ours } while `served` keys go through L's metatable

local function Count(s, sub)
    local n, a, b = 0, s:find(sub, 1, true)
    while a do n, a, b = n + 1, s:find(sub, b + 1, true) end
    return n
end

local function Specs(s)
    local out, pos, positional = {}, 1, false
    while true do
        local a, b = s:find(SPEC, pos)
        if not a then break end
        local spec = s:sub(a, b)
        positional = positional or spec:find("$", 1, true) ~= nil
        out[#out + 1] = spec
        pos = b + 1
    end
    if positional then table.sort(out) end
    return out
end

-- true when `uk` can stand in for `en`: the same format specs (in order) and the same escapes.
function Lc.Usable(en, uk)
    if type(en) ~= "string" or type(uk) ~= "string" or uk == "" then return false end
    local a, b = Specs(en), Specs(uk)
    if #a ~= #b then return false end
    for i = 1, #a do if a[i] ~= b[i] then return false end end
    for _, e in ipairs(ESCAPES) do
        if Count(en, e) ~= Count(uk, e) then return false end
    end
    return true
end

local function Esc(s) return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")) end

-- A format ("Floor %d") as an anchored pattern with one capture per spec, or nil.
local function Pattern(fmt)
    local out, pos, n = { "^" }, 1, 0
    while true do
        local a, b = fmt:find(SPEC, pos)
        out[#out + 1] = Esc(fmt:sub(pos, a and a - 1 or -1))
        if not a then break end
        local spec = fmt:sub(a, b)
        if spec == "%%" then
            out[#out + 1] = "%%"
        elseif spec:find("$", 1, true) then
            return nil                                  -- positional: not read back
        else
            n = n + 1
            local kind = spec:sub(-1)
            out[#out + 1] = (kind == "d" or kind == "i") and "([%-%+]?%d+)"
                or (kind == "f" or kind == "g") and "([%-%+]?[%d%.]+)" or "(.-)"
        end
        pos = b + 1
    end
    out[#out + 1] = "$"
    return n > 0 and table.concat(out) or nil
end

-- %s slots OpenMap fills with a name as it is (addon, player, flight node, zone, version, date). Any other
-- %s must hold a value or a name Words.lua translates, or the line stays English (never half translated).
Lc.FREE = {
    ["addons' memory: %s"] = { 1 }, ["garbage a second: %.1f MB in all, of which %s"] = { 2 },
    ["Lua memory %.0f MB (%+.1f MB a minute), map pins %d (most: %s %d)"] = { 4 },
    ["%s is also changing the world map. Turn off its world map options (or the addon) so the two don't fight."] = { 1 },
    ["Leatrix Maps: turn off %s there; OpenMap does the same for its map."] = { 1 }, ["Released %s."] = { 1 },
    ["A map addon brings its own HereBeDragons (%s), which OpenMap doesn't know: its pins keep the game's own placement."] = { 1 },
    ["Back to %s"] = { 1 }, ["Map by %s"] = { 1 }, ["Somewhere in %s"] = { 1 }, ["Shared by %s"] = { 1 },
    ["From %s: about %s"] = { 1 }, ["No flight route from %s to %s."] = { 1, 2 }, ["Drawing on the pin: %s"] = { 1 },
    ["OpenMap %s is out (you have %s). Update through CurseForge."] = { 1, 2 },
    ["Updated to %s: see What's new in the OpenMap menu."] = { 1 }, ["%s shared %d map pin(s) with you:"] = { 1 }, ["Added %d map pin(s) from %s."] = { 2 },
    ["That isn't a code of map pins (it starts %s)."] = { 1 },
    ["Sharing %d map pin(s) with %s (players with OpenMap are asked whether to add them)."] = { 2 },
}

-- A value: no letters (a byte past ASCII is one: Cyrillic) but a unit of 1 to 3 right after a digit ("1:05").
function Lc.IsValue(c)
    c = c:gsub("||", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
    for a, w in c:gmatch("()([%a\128-\255]+)") do
        if #w > 3 or not c:sub(a - 1, a - 1):find("%d") then return false end
    end
    return true
end

-- `fmt` with its specs replaced by `caps`, in order; %s ones through Name when given, then nil if one
-- Name does not know is neither free (`free`: slot numbers) nor a value.
local function Fill(fmt, caps, Name, free)
    local i, fits = 0, true
    local out = fmt:gsub(SPEC, function(spec)
        if spec == "%%" then return "%" end
        i = i + 1
        local c = caps[i] or ""
        if not Name or spec:sub(-1) ~= "s" then return c end
        local uk = Name(c)
        fits = fits and (uk or Lc.IsValue(c) or (free and tContains(free, i))) and true
        return uk or c
    end)
    return fits and out or nil
end

local function ByLength(a, b) return #a[1] > #b[1] end

-- Builds the word lists from ui/locale.lua; `over` (English -> Ukrainian) replaces some, for the checks.
function Lc.Build(over)
    local was = saved ~= nil
    if was then Lc.Uninstall() end
    wipe(Lc.entries) wipe(Lc.skipped) wipe(rev) wipe(fwd) wipe(back) wipe(lastRead)
    local src = ns.locale or {}
    for _, t in ipairs({ src.MAP or {}, src.LOADTIME or {}, over or {} }) do
        for en, uk in pairs(t) do
            if Lc.Usable(en, uk) then Lc.entries[en], Lc.skipped[en] = uk, nil
            else Lc.entries[en], Lc.skipped[en] = nil, true end
        end
    end
    for en, uk in pairs(Lc.entries) do
        if rev[uk] == nil then rev[uk] = en elseif rev[uk] ~= en then rev[uk] = false end
        -- formatted texts with words of their own ("Floor %d"), not bare ones ("%s: %s")
        if en:find("%", 1, true) and en:gsub(SPEC, ""):find("%a%a")
            and uk:gsub(SPEC, ""):find("[\208\209]") then
            local pe, pu = Pattern(en), Pattern(uk)
            if pe and pu then
                fwd[#fwd + 1] = { pe, uk, Lc.FREE[en] }
                back[#back + 1] = { pu, en }
            end
        end
    end
    table.sort(fwd, ByLength)
    table.sort(back, ByLength)
    Lc.gen = (Lc.gen or 0) + 1      -- the word lists changed (Words.lua forgets its finished texts)
    if was then Lc.Install() end
end

-- What OpenMap shows for `en` without our words: its own text, or the English key.
local function Without(en)
    local had = before[en]
    return type(had) == "string" and had or en
end

local function Match(list, t, Name, Read)
    for _, p in ipairs(list) do
        local caps = { t:match(p[1]) }
        local out = caps[1] and Fill(Read and Read(p[2]) or p[2], caps, Name, p[3])
        if out then return out end
    end
end

-- One English line built from a formatted text ("Floor 2"), in Ukrainian, or nil.
function Lc.Forward(t, Name) return Match(fwd, t, Name) end

-- One line of our Ukrainian back in English (a whole word or a formatted one), or nil.
function Lc.English(t)
    if type(t) ~= "string" or t == "" then return nil end
    local en = rev[t]
    if en then return Without(en) end
    if en == false then                      -- two keys share it: the one OpenMap read last
        en = lastRead[t]
        return en and Without(en) or nil
    end
    if t:find("[\208\209]") then return (Match(back, t, nil, Without)) end
end

local function Table()
    local om = rawget(_G, "OpenMap")
    local L = type(om) == "table" and rawget(om, "L")
    return type(L) == "table" and L or nil
end

local function Plain(L)
    local mt = getmetatable(L)
    return not (type(mt) == "table" and mt.__newindex)
end

-- For the checks: true when `en`'s Ukrainian is shared with another key ("Dungeon", "Dungeons").
function Lc.Shared(en) return Lc.entries[en] ~= nil and rev[Lc.entries[en]] == false end

-- true when `t` is one of our texts as it is, shared or not ("Підземелля", "Куди:").
function Lc.Ours(t) return type(t) == "string" and rev[t] ~= nil end

-- A Ukrainian text two keys share ("Підземелля": "Dungeon", "Dungeons") cannot be read back to
-- its English. So those keys are not written into L: L's own __index (English back when nothing
-- is set) is wrapped while our words are wanted, gives our text and notes which key was read.
-- Words.lua keeps each FontString's English from that note, so the hold key and "off" put back
-- exactly what OpenMap set. With no metatable to wrap, they go into L like the other words.
local function Serve(L)
    local mt = getmetatable(L)
    if type(mt) ~= "table" or not next(served) then return false end
    local own = rawget(mt, "__index")
    local function ours(t, k)
        local uk = served[k]
        if uk then lastRead[uk] = k return uk end
        if type(own) == "function" then return own(t, k) end
        if type(own) == "table" then return own[k] end
    end
    index = { mt = mt, own = own, ours = ours }
    rawset(mt, "__index", ours)
    return true
end

function Lc.Install()
    local L = Table()
    if not L or saved then return end
    local plain = Plain(L)
    saved = {}
    wipe(served)
    for en, uk in pairs(Lc.entries) do
        local had = rawget(L, en)
        if rev[uk] == false and had == nil then
            served[en] = uk
        elseif not (type(had) == "string" and had:find("[\208\209]")) then
            saved[en] = { had }
            before[en] = had
            if plain then rawset(L, en, uk) else L[en] = uk end
            wrote[en] = uk
        end
    end
    if not Serve(L) then                       -- no metatable: in L like the rest
        for en, uk in pairs(served) do
            saved[en] = {}
            if plain then rawset(L, en, uk) else L[en] = uk end
            wrote[en] = uk
        end
        wipe(served)
    end
end

function Lc.Uninstall()
    local L = Table()
    if not saved then return end
    if index and rawget(index.mt, "__index") == index.ours then rawset(index.mt, "__index", index.own) end
    index = nil
    wipe(served)
    if L then
        local plain = Plain(L)
        for en, box in pairs(saved) do
            if rawget(L, en) == wrote[en] then                 -- still ours: what was there before
                if plain then rawset(L, en, box[1]) else L[en] = box[1] end
            end
        end
    end
    saved = nil
    wipe(wrote)
end
function Lc.Installed() return saved ~= nil end

-- How many of our words are in L now.
function Lc.Count()
    local L, n = Table(), 0
    if not (L and saved) then return 0 end
    for en, uk in pairs(wrote) do if rawget(L, en) == uk then n = n + 1 end end
    if index then for _ in pairs(served) do n = n + 1 end end
    return n
end

-- The options window OpenMap registers (AceConfig) draws again from L, if it is open.
local function Redraw()
    if type(LibStub) ~= "table" and type(LibStub) ~= "function" then return end
    local ok, ACD = pcall(LibStub, "AceConfigDialog-3.0", true)
    if not (ok and type(ACD) == "table" and type(ACD.OpenFrames) == "table" and ACD.OpenFrames.OpenMap) then return end
    local okR, reg = pcall(LibStub, "AceConfigRegistry-3.0", true)
    if okR and type(reg) == "table" and reg.NotifyChange then pcall(reg.NotifyChange, reg, "OpenMap") end
end

-- L as it should be now: our words while they are wanted (on, hold key up), OpenMap's otherwise.
function Lc.Sync()
    local want = ns.WordsWanted()
    if want == (saved ~= nil) or ns.Screen.WaitCombat() then return end
    if want then Lc.Install() else Lc.Uninstall() end
    Redraw()
end

Lc.Build()
