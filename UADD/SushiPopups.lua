-- UADD.SushiPopups: the game's button words (OKAY, CANCEL, YES, ...) on a translated addon's own Sushi-3.2
-- pop-ups (docs/LESSONS3.md, "Lesson 1 again, in Bagnon and Scrap's popups"). One helper for every module
-- whose addon opens pop-ups through that library (Bagnon, Scrap).
--
-- Sushi-3.2 is one library for every addon that carries it (Bagnon's BagBrother, Scrap, others): one Popup
-- class, its frames pooled and given to any addon. A library shared by several addons is shared game state,
-- so only this core file hooks it, once, for all modules:
--   * A module registers the folders its addon's code lives in (owners). A pop-up is that module's when the
--     first file in the stack of its Popup:New that is not a library (".../libs/...") nor UADD's lies in one
--     of them. Every other pop-up, and one a library opens on its own (StaleCheck), is never touched.
--   * A button (its field on the pop-up and the button shown) shows our word only while it holds the game
--     global's English, and the English again only while it holds our word. The globals are never written;
--     one already Cyrillic (another addon set it) is left as it is.
--   * The body flips only as a whole text the module knows both ways (uk, en); a body with a player's
--     name in it stays as the addon built it. The edit box (what the player typed or pastes) is never read.
--   * A shown pop-up flips both ways on the hold key, off and on (P.Sync). A released frame is forgotten,
--     so the pool never carries ours to another addon.
--   * A module's work runs under UADD.Safe(key): 5 errors turn the module off, and the English comes back
--     under a plain pcall (P.Off, also when the module is off for errors). Any error leaves the English.
local U = UADD
local P = {}
U.SushiPopups = P

local CYR = "[\208-\211][\128-\191]"
-- The game's globals on Sushi pop-ups -> glossary id.
local WORDS = { OKAY = "ui.ok", CANCEL = "ui.cancel", ACCEPT = "ui.accept", YES = "ui.yes", NO = "ui.no",
    UNLOCK = "ui.unlock", CHAT_LEAVE = "ui.leave" }
local FIELDS = { "button1", "button2", "text" }

local specs = {}                                 -- module key -> spec
local order = {}                                 -- module keys, in register order
local seen = setmetatable({}, { __mode = "k" })  -- pop-up frame -> true: looked at once (any addon's)
local mine = setmetatable({}, { __mode = "k" })  -- pop-up frame -> the spec of the module it belongs to
local kept = setmetatable({}, { __mode = "k" })  -- pop-up or FontString -> { slot -> { en, uk } } we wrote
local hooked = false

local function Popup()
    local S = LibStub and LibStub("Sushi-3.2", true)
    local C = S and rawget(S, "Popup")
    return type(C) == "table" and C or nil
end

-- en, uk for one global while it is English and the glossary has a word for it.
local function Word(g)
    local en, id = rawget(_G, g), WORDS[g]
    if type(en) ~= "string" or en == "" or en:find(CYR) then return nil end
    local uk = U.Glossary and U.Glossary.Text and U.Glossary.Text(id)
    if type(uk) ~= "string" or uk == "" or uk == en then return nil end
    return en, uk
end

local function Pair(t)
    for g in pairs(WORDS) do
        local en, uk = Word(g)
        if en and (t == en or t == uk) then return en, uk end
    end
end

-- The text a slot should show now (nil: leave it), and the pair it belongs to.
local function Next(s, t, want, rec)
    if type(t) ~= "string" or t == "" then return nil end
    local en, uk = Pair(t)
    if en and not want and t == uk and not (rec and rec[2] == t) then return nil end  -- our word we did not write
    if not en and rec and (t == rec[1] or t == rec[2]) then en, uk = rec[1], rec[2] end
    if not en and want and s.uk then uk = s.uk(t) en = uk and t end
    if not en and not want and s.en then en = s.en(t) uk = en and t end
    if type(en) ~= "string" or type(uk) ~= "string" or en == uk then return nil end
    return want and uk or en, en, uk
end

local function Slot(s, obj, slot, cur, want, put)
    local k = kept[obj]
    local to, en, uk = Next(s, cur, want, k and k[slot])
    if not to or to == cur then return end
    put(to)
    kept[obj] = k or {}
    kept[obj][slot] = { en, uk }
end

-- The FontStrings of the buttons Sushi shows (the body's Header and the RedButtons; not the edit box).
local function Shown(f, out, depth)
    local list = rawget(f, "Children")
    for _, c in ipairs(type(list) == "table" and list or {}) do
        if type(c) == "table" and type(c.GetObjectType) == "function" then
            if c:GetObjectType() == "Button" and c.GetFontString then
                local fs = c:GetFontString()
                if fs then out[#out + 1] = fs end
            end
            if depth < 3 then Shown(c, out, depth + 1) end
        end
    end
    return out
end

local function Fill(f, s, want)
    for _, k in ipairs(FIELDS) do
        Slot(s, f, k, rawget(f, k), want, function(v) f[k] = v end)
    end
    for _, fs in ipairs(Shown(f, {}, 1)) do
        Slot(s, fs, 1, fs:GetText(), want, function(v) fs:SetText(v) end)
        -- Also a text the addon set itself from its locale (our body): the font that can draw it.
        if s.decide then U.SafeCall(s.decide, fs) end
    end
end

local function Wanted(s)
    local ok, yes = pcall(s.wanted)
    return ok and yes and true or false
end

-- The addon folder that opened this pop-up, or nil (a library alone, UADD, the game).
local function Owner()
    local ok, st = pcall(debugstack, 2, 30, 0)
    if not ok or type(st) ~= "string" then return nil end
    for line in st:gmatch("[^\n]+") do
        local folder, rest = line:match("AddOns[/\\]([^/\\]+)[/\\]([^:\"%]]*)")
        if folder and not folder:find("^UADD") and not ("/" .. rest:lower()):find("[/\\]libs?[/\\]") then
            return folder
        end
    end
end

-- The spec whose owners hold this folder (the first registered, if two name it), or nil.
local function OwnerSpec(folder)
    if type(folder) ~= "string" then return nil end
    for _, key in ipairs(order) do
        if specs[key].owners[folder] then return specs[key] end
    end
end

local function OnNew()
    local C = Popup()
    local A = C and rawget(C, "Active")
    local f = type(A) == "table" and A[#A]
    if type(f) ~= "table" or seen[f] then return end   -- New made nothing (a duplicate, too many): not new
    seen[f] = true
    local s = OwnerSpec(Owner())
    if not s then return end
    mine[f] = s
    s.new(f)
end

local function OnRelease(f)
    if type(f) ~= "table" then return end
    seen[f], mine[f], kept[f] = nil, nil, nil
end

-- One hook on the library's Popup class for every module, once, when the library is there.
local function Install()
    if hooked or not hooksecurefunc then return end
    local C = Popup()
    if not C or type(C.New) ~= "function" or type(C.Release) ~= "function" then return end
    hooked = true
    hooksecurefunc(C, "New", function() pcall(OnNew) end)
    hooksecurefunc(C, "Release", function(f) pcall(OnRelease, f) end)
end

-- key: the module (for U.Safe). spec: owners = { Folder = true } (the folders its addon's code lives in);
-- wanted() -> our words now; uk(t) / en(t): a whole body both ways (optional); decide(fs): the module's
-- font for that FontString (optional). Registering again (each "/uadd <key> on") updates the spec in place.
function P.Register(key, spec)
    local s = specs[key]
    if not s then
        s = { key = key }
        specs[key] = s
        order[#order + 1] = key
        s.new = U.Safe(key, function(f) if Wanted(s) then Fill(f, s, true) end end)
        s.sync = U.Safe(key, function()
            for f, o in pairs(mine) do
                if o == s and type(f.IsShown) == "function" and f:IsShown() then Fill(f, s, true) end
            end
        end)
    end
    s.owners = type(spec.owners) == "table" and spec.owners or {}
    s.wanted = spec.wanted or function() return false end
    s.uk, s.en, s.decide = spec.uk, spec.en, spec.decide
    pcall(Install)
end

-- Off (also after the module went off for errors): every shown pop-up of the module English again, only
-- where it still holds our word.
function P.Off(key)
    local s = specs[key]
    if not s then return end
    for f, o in pairs(mine) do
        if o == s and type(f.IsShown) == "function" and f:IsShown() then pcall(Fill, f, s, false) end
    end
end

-- On, the hold key, off: every shown pop-up of the module as it should be now.
function P.Sync(key)
    local s = specs[key]
    if not s then return end
    pcall(Install)
    if Wanted(s) then s.sync() else P.Off(key) end
end

-- For the checks: the module's pop-ups shown now.
function P.Count(key)
    local n = 0
    for f, o in pairs(mine) do
        if o == specs[key] and type(f.IsShown) == "function" and f:IsShown() then n = n + 1 end
    end
    return n
end
