-- Not LiteMount: the rest of the stand-in (LiteMount.lua, Copies.lua, Globals.lua): the texts the owner's shots
-- showed English or as boxes (2026-11-21), built the way the installed LiteMount (GPL-2.0) builds them:
--   * the Profiles page's buttons (UI/PanelTemplate.xml LiteMountUIButtonTemplate): a ButtonText that inherits
--     GameFontNormal; the harness's FontStrings have a font without Ukrainian letters, as that label in the game;
--   * the Mounts and Macros page titles (MOUNTS, MACROS), the Groups column header (GROUP), the search box's grey
--     hint (SearchBoxTemplate: SEARCH), the macro tabs (UNAVAILABLE, COMBAT) and labels (ENABLE, ENTER_MACRO_LABEL);
--   * the counts line (UI/Mounts.lua) and the character count (UI/Macro.lua), set again at each refresh;
--   * the Falling rows (a scroll list of LiteMountItemSpellMixin rows), each with a Delete button (DELETE);
--   * L.LM_PRIORITY_DESC0 = DISABLE and L.LM_PRIORITY_DESC4 = ALWAYS (Localization.lua).
local _, LM = ...
local S = LiteMountStandIn
local L = LM.L or {}                    -- the game without L (noL) still loads
local EN = { MOUNTS = "Mounts", MACROS = "Macros", GROUP = "Group", UNAVAILABLE = "Unavailable", COMBAT = "Combat",
    ENABLE = "Enable", ENTER_MACRO_LABEL = "Enter Macro Commands:", SEARCH = "Search", TOTAL = "Total",
    COLLECTED = "Collected", MACROFRAME_CHAR_LIMIT = "%d/255 Characters Used", DISABLE = "Disable", ALWAYS = "Always" }
for g, en in pairs(EN) do if rawget(_G, g) == nil then _G[g] = en end end
if rawget(L, "LM_PRIORITY_DESC0") == nil then rawset(L, "LM_PRIORITY_DESC0", DISABLE) end
if rawget(L, "LM_PRIORITY_DESC4") == nil then rawset(L, "LM_PRIORITY_DESC4", ALWAYS) end

local T = {}
S.shots = T
local function Text(f, g) local fs = f:CreateFontString(nil, "ARTWORK", "GameFontNormal") fs:SetText(_G[g]) return fs end

-- The Profiles buttons: their label's font object is GameFontNormal (ButtonText inherits="GameFontNormal").
T.profiles = {}
local profiles = rawget(_G, "LiteMountProfilesPanel")
for _, k in ipairs({ "NewProfile", "ResetProfile", "DeleteProfile", "ExportProfile", "ImportProfile" }) do
    local b = CreateFrame("Button", nil, profiles)
    b:SetText(L["LM_" .. k:upper():gsub("PROFILE", "_PROFILE")] or k)
    local fs = b:GetFontString()
    if fs and rawget(_G, "GameFontNormal") then fs:SetFontObject(GameFontNormal) end
    profiles[k] = b
    T.profiles[#T.profiles + 1] = b
end

local mounts, macro = rawget(_G, "LiteMountMountsPanel"), rawget(_G, "LiteMountMacroPanel")
local groups = rawget(_G, "LiteMountGroupsPanel")
T.texts = { Text(mounts, "MOUNTS"), Text(macro, "MACROS"), Text(groups, "GROUP") }
local search = CreateFrame("Frame", nil, mounts)                 -- an EditBox in the game (SearchBoxTemplate)
search.GetObjectType = function() return "EditBox" end
search.Instructions = Text(search, "SEARCH")
mounts.Search = search
T.texts[#T.texts + 1] = search.Instructions
for i, g in ipairs({ "UNAVAILABLE", "COMBAT" }) do
    local tab = CreateFrame("Button", "LiteMountMacroPanelTab" .. i, macro)
    tab:SetText(_G[g])
    T.texts[#T.texts + 1] = tab:GetFontString()
end
T.texts[#T.texts + 1] = Text(macro.Macro, "ENABLE")
T.texts[#T.texts + 1] = Text(macro.Macro, "ENTER_MACRO_LABEL")
T.globals = { "MOUNTS", "MACROS", "GROUP", "SEARCH", "UNAVAILABLE", "COMBAT", "ENABLE", "ENTER_MACRO_LABEL" }

-- The lines set again at each refresh.
mounts.Counts = mounts:CreateFontString(nil, "ARTWORK", "GameFontNormal")
macro.Macro.Count = macro.Macro:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
local function White(n) return "|cffffffff" .. n .. "|r" end
function T.refresh()
    mounts.Counts:SetText(string.format('%s: %s %s: %s %s: %s', TOTAL, White(120), COLLECTED, White(64),
        tostring(L.LM_USABLE), White(31)))
    macro.Macro.Count:SetText(format(MACROFRAME_CHAR_LIMIT, 42))
end
T.refresh()

-- The Falling rows: made from the mixin when the list shows (after login), each with its name and Delete button.
-- A spell's name comes later (ContinueOnSpellLoad: T.flush()), an item's at once; a slot row is "<slot> (<item>)".
-- The names are made up; UALL Forever's stand-in knows some (flow_litemount_shots.lua).
T.NAME = { ["spell:130"] = "Quix Drift", ["spell:2"] = "Quix Glide", ["item:3"] = "Quix Plume",
    ["slot:15"] = "Back (Quix Cloak)" }
T.pending = {}
function T.flush() local p = T.pending T.pending = {} for _, f in ipairs(p) do f() end end
LiteMountItemSpellMixin = {}
function LiteMountItemSpellMixin:Initialize(elementData)
    self.data = elementData
    local name = T.NAME[elementData]
    if elementData:find("^spell:") then T.pending[#T.pending + 1] = function() self.Name:SetText(name) end
    else self.Name:SetText(name) end
end
T.rows = {}
function T.row(data)
    local b = CreateFrame("Button", nil, rawget(_G, "LiteMountFallingPanel"))
    Mixin(b, LiteMountItemSpellMixin)
    b.Name = b:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    b.DeleteButton = CreateFrame("Button", nil, b)
    b.DeleteButton:SetText(DELETE)
    b:Initialize(data or "spell:130")
    T.rows[#T.rows + 1] = b
    return b
end

-- The Mounts list rows (UI/MountListButtonTemplate.lua): the list mixin calls the common mixin's Initialize, which
-- sets the mount's name, then its font object (grey when not collected).
LiteMountMountCommonButtonMixin = {}
function LiteMountMountCommonButtonMixin:Initialize(mount)
    self.mount = mount
    self.Name:SetText(mount.name)
    local fo = not mount.collected and rawget(_G, "GameFontDisable") or rawget(_G, "GameFontNormal")
    if fo then self.Name:SetFontObject(fo) end
end
T.mountRows = {}
function T.mount(name, collected)
    local b = CreateFrame("Button", nil, mounts)
    b.Name = b:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    function b:Initialize(m) LiteMountMountCommonButtonMixin.Initialize(self, m) end
    b:Initialize({ name = name, collected = collected })
    T.mountRows[#T.mountRows + 1] = b
    return b
end
