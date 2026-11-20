-- Stand-in for GatherMate2 (tools/harness/flow_gm.py). Every word comes from GatherMate2's own AceLocale
-- tables (its enUS files, run from the installed addon before this file). Its locale keys are its English,
-- so this file names none: the flow puts the keys it should use in GatherMate2StandInKeys before the game
-- starts (read from the installed addon at test time). Like GatherMate2, it copies the words at load into
-- its settings tables, its key binding names and its profession list; the pin menu and the chat lines read
-- the table each time they show.

local K = GatherMate2StandInKeys or { other = {}, prof = {}, pages = {} }
local AL = LibStub("AceLocale-3.0")
local L = AL:GetLocale("GatherMate2")
local NL = AL:GetLocale("GatherMate2Nodes")
local S = {}
GatherMate2StandIn = S

local GM = LibStub("AceAddon-3.0"):NewAddon("GatherMate2")
GatherMate2 = GM
GM.db = LibStub("AceDB-3.0"):New("GatherMate2StandInDB", { profile = { scale = 1 } }, "Default")
local function noop() end

-- Key binding names, copied at load (its Config.lua).
BINDING_NAME_TOGGLE_GATHERMATE2_MINIMAPICONS = L[K.bindMini]
BINDING_NAME_TOGGLE_GATHERMATE2_MAINMAPICONS = L[K.bindMain]

-- Profession names, kept at load to compare with the game's (its Constants.lua SetSkillProfession).
S.skills = {}
for i, k in ipairs(K.prof) do S.skills[i] = L[k] end

-- ── Settings tables, read at load ─────────────────────────────────────────────────────────────

local function Rows(from, to)
    local args, n = {}, #K.other
    for i = from, math.min(to, n) do
        args["o" .. i] = { type = "toggle", order = i, name = L[K.other[i]], desc = L[K.other[i % n + 1]],
            get = noop, set = noop }
    end
    return args
end

local half = math.floor(#K.other / 2)
S.root = { type = "group", name = "GatherMate2", args = Rows(1, half) }

local mini = { type = "group", name = "GatherMate2", args = Rows(half + 1, #K.other) }
-- The settings Delete button: the same locale key as the pin menu's line.
mini.args.del = { type = "execute", order = 900, name = L[K.del], desc = L[K.other[1]], func = noop,
    confirm = true, confirmText = L[K.other[2]] }
-- A list of professions (all ours), a list of node names (game names, one of its words among them) and a
-- list of zones (made-up names and one of its words).
local profs = {}
for i, k in ipairs(K.prof) do profs["p" .. i] = L[k] end
local nodes, n = { x = L[K.other[3]] }, 0
for k, v in pairs(NL) do
    n = n + 1
    if n <= 20 then nodes[k] = v end
end
mini.args.profs = { type = "select", order = 901, name = L[K.other[4]], values = profs, get = noop, set = noop }
mini.args.nodes = { type = "multiselect", order = 902, name = L[K.other[5]], values = nodes, get = noop, set = noop }
mini.args.zones = { type = "select", order = 903, name = L[K.other[6]], get = noop, set = noop,
    values = { a = "Quixwood Vale", b = "Zorp Hollow", c = L[K.other[7]] } }
S.mini = mini

local reg = LibStub("AceConfigRegistry-3.0")
reg:RegisterOptionsTable("GatherMate 2", S.root)
reg:RegisterOptionsTable("GM2/Minimap", mini)

-- Profiles tab: AceDBOptions' table for its db, and one for another addon's db (the shared args).
local dbo = LibStub("AceDBOptions-3.0")
S.profiles = dbo:GetOptionsTable(GM.db)
reg:RegisterOptionsTable("GM2/Profiles", S.profiles)
S.otherDb = LibStub("AceDB-3.0"):New("GatherMate2StandInOtherDB", { profile = {} }, "Default")
S.otherProfiles = dbo:GetOptionsTable(S.otherDb)

-- Its pages in the game's settings list, the way AceConfigDialog:AddToBlizOptions makes them.
local Acd = LibStub:NewLibrary("AceConfigDialog-3.0", 1)
Acd.BlizOptions, S.cats = {}, {}
for _, p in ipairs(K.pages) do
    local app, label = "GM2/" .. p[1], p[2]
    local frame = CreateFrame("Frame")
    local cat = Settings.RegisterCanvasLayoutCategory(frame, label)
    local group = { frame = frame, title = label }
    function group:SetTitle(t) self.title = t end
    frame.name = cat.ID
    Acd.BlizOptions[app] = { [app] = group }
    S.cats[app] = { cat = cat, group = group }
end

-- ── The pin menu (world map, right click), built each time it opens ───────────────────────────

S.pins = {}
local menu = CreateFrame("Frame", "GatherMate2_GenericDropDownMenu")
menu.displayMode = "MENU"
menu.initialize = function(_, level)
    if level ~= 1 then return end
    UIDropDownMenu_AddButton({ isTitle = 1, notCheckable = 1, text = L[K.title] }, level)
    for _, pin in ipairs(S.pins) do
        UIDropDownMenu_AddButton({ notCheckable = 1, func = noop, text = L[K.del] .. " :" .. pin.title }, level)
    end
end

function S.PinMenu(titles)
    S.pins = {}
    for i, t in ipairs(titles) do S.pins[i] = { title = t } end
    ToggleDropDownMenu(1, nil, menu, "cursor", 0, 0)
end

-- ── Chat lines ────────────────────────────────────────────────────────────────────────────────

-- Auto import: a data addon that loads gets a line with its folder name glued after the words.
function S.AutoImport(names)
    for _, k in ipairs(names) do
        local loaded = C_AddOns.LoadAddOn(k)
        if loaded then print(L[K.auto] .. k) end
    end
end

-- A data addon that does not load: the engine's reason token glued after the words.
function S.LoadData(name)
    local loaded, reason = C_AddOns.LoadAddOn(name)
    if not loaded then print(L[K.fail] .. tostring(reason)) end
end
