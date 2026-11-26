-- UADD_LiteMount: the texts LiteMount puts on its frames once, switched both ways (lesson 15).
-- At OnLoad its panels copy L into their XML texts (AutoLocalize) and their titles, settings category names,
-- tab names and two labels; its macro panel copies a file-local help text at each redraw. Our module loads
-- after it, so these hold its English. Apply walks only its own named panels (U.Regions / U.Children, not into
-- scroll lists or edit boxes, where group, profile and mount names live, nor into the parts that show a name:
-- PLAYER below) and swaps a FontString only when its text is exactly one of the words below or our word for it.
-- Its filter menu, its General options page and its rule errors are copies too: Copies.lua switches them.
local _, ns = ...
local U = UADD
local Lc = ns.Locale
local Guard = Lc.Guard                                -- kept at load (Locale.lua)
local S = {}
ns.Screen = S

local DEPTH = 3
local ROOTS = { "LiteMountBasePanel", "LiteMountGroupsPanel", "LiteMountRulesPanel", "LiteMountMountsPanel",
    "LiteMountMacroPanel", "LiteMountAdvancedPanel", "LiteMountFallingPanel", "LiteMountFallingAdd",
    "LiteMountProfilesPanel", "LiteMountProfileExport", "LiteMountProfileImport", "LiteMountReportBugPanel",
    "LiteMountRuleEdit" }
-- The keys copied onto its frames at load: XML texts, panel titles, tabs, two labels, the macro help.
local KEYS = {
    "LM_ADVANCED_EXP", "LM_SETTINGS_TAGLINE", "LM_AUTHOR", "LM_HELP_TRANSLATE", "LM_TRANSLATORS",
    "LM_FALLING_EXP", "LM_DRAG_TO_REORDER", "LM_GROUPS_EXP", "LM_SHOW_ALL_MOUNTS", "LM_MACRO_NOT_ALLOWED",
    "LM_PRIORITY", "LM_EXPORT_PROFILE_EXP", "LM_IMPORT_PROFILE_EXP", "LM_PROFILES_EXP", "LM_CHANGE_PROFILE",
    "LM_NEW_PROFILE", "LM_RESET_PROFILE", "LM_DELETE_PROFILE", "LM_EXPORT_PROFILE", "LM_IMPORT_PROFILE",
    "LM_REPORT_BUG_EXP", "LM_CONDITIONS", "LM_ACTION", "LM_RULES_EXP",
    "LM_GROUPS", "LM_PROFILES", "LM_REPORT_BUG", "LM_ADD_SPELL_OR_ITEM", "LM_EDIT_RULE",
    "LM_LIST_VIEW", "LM_MODEL_VIEW", "LM_ACTIONS", "LM_MACRO_EXP", "LM_COMBAT_MACRO_EXP",
}
local TAIL = { ["LM_CURRENT_PROFILE"] = " :" }     -- "Current Profile :" (Profiles.lua OnLoad)
local IMPORT = "Import"                            -- its Import button: plain text in its XML
-- Game globals it puts on its own frames (Rules.xml, Falling.xml: a panel name `type="global"`; its buttons'
-- text="ADD"): UALL Forever leaves them English there. Ours only on these frames, while the global is not
-- Cyrillic; the global itself is never written (Lc.Global). Read again on each run.
local GLOBALS = { "BRAWL_TOOLTIP_RULES", "STRING_ENVIRONMENTAL_DAMAGE_FALLING", "ADD", "DELETE", "EDIT",
    "PET_RENAME", "CANCEL", "OKAY", "REVERT", "SETTINGS_DEFAULTS", "INSTANCE", "LEVEL", "BRAWL_TOOLTIP_MAP",
    "MOUNTS", "MACROS", "GROUP", "UNAVAILABLE", "COMBAT", "ENABLE", "ENTER_MACRO_LABEL", "SEARCH" }

local toUk, toEn = nil, nil
local gUk, gEn = {}, {}

local function GlobalMaps()
    wipe(gUk)
    wipe(gEn)
    for _, g in ipairs(GLOBALS) do
        local en, uk = Lc.Global(g, true)
        if uk then
            if Lc.Global(g) then gUk[en] = uk end   -- ours on while the global is not Cyrillic
            gEn[uk] = en                            -- the text back always
        end
    end
end
local seen, ours = 0, 0
local hooked = {}

local function Maps()
    if toUk then return end
    toUk, toEn = {}, {}
    for _, k in ipairs(KEYS) do
        local w = Lc.Word(k)
        if w then toUk[Lc.En(k)] = w toEn[w] = Lc.En(k) end
    end
    for k, tail in pairs(TAIL) do
        local w = Lc.Word(k)
        if w then toUk[Lc.En(k) .. tail] = w .. tail toEn[w .. tail] = Lc.En(k) .. tail end
    end
end

local function Turn(t, want)
    Maps()
    if want then return toUk[t] or gUk[t] end
    return toEn[t] or gEn[t]
end

local function Swap(fs, want)
    if type(fs) ~= "table" or type(fs.GetText) ~= "function" then return false end
    local t = U.Plain(fs:GetText())
    if type(t) ~= "string" or t == "" then return false end
    local new = Turn(t, want)
    if new then seen = seen + 1 end
    if new and new ~= t then
        fs:SetText(new)
        U.SafeCall(ns.Fonts.Settle, fs)                -- its font: ours for Ukrainian, LiteMount's for English
        if want then ours = ours + 1 end
        return true
    end
    if want and Turn(t, false) then seen, ours = seen + 1, ours + 1 end
    U.SafeCall(ns.Fonts.Settle, fs)
    return false
end
S.Swap = Swap

-- The English again on a text that shows our word, as the walk sets it (Fonts.lua: no Cyrillic font took on it).
function S.English(fs)
    local t = U.Plain(fs:GetText())
    local en = type(t) == "string" and (Turn(t, false) or Lc.Back(t) or Lc.GlobalBack(t))
    if not en or en == t then return false end
    fs:SetText(en)
    return true
end

-- Scroll lists (group, mount, profile and class names) and edit boxes (the player's text) are left alone.
local function Skip(c)
    if type(c.GetObjectType) == "function" and c:GetObjectType() == "EditBox" then return true end
    return type(c.GetDataProvider) == "function" or type(rawget(c, "ScrollTarget")) == "table"
end

-- Its parts that show a name, never one of its own words (LESSONS2 13): the Profiles page's current profile,
-- a rule's argument button (a group, flag, mount or typed name), and its Name labels (a spell, an item, a slot,
-- or the text typed in the add box). They are left alone by where they are, whatever their text says.
local PLAYER = { "CurrentProfile", "ArgDropDown", "Name" }

local function Theirs(f)
    local out = {}
    for _, k in ipairs(PLAYER) do
        local v = rawget(f, k)
        if type(v) == "table" then out[v] = true end
    end
    return out
end

local function Walk(f, depth, want)
    if type(f) ~= "table" or depth < 0 then return false end
    local changed = false
    local skip = Theirs(f)
    for _, r in ipairs(U.Regions(f)) do
        if not skip[r] and r.GetObjectType and r:GetObjectType() == "FontString" and Swap(r, want) then changed = true end
    end
    if type(f.GetFontString) == "function" then
        U.SafeCall(ns.Fonts.HookButton, f)             -- a label set later gets our font too
        if Swap(f:GetFontString(), want) then changed = true end
    end
    for _, c in ipairs(U.Children(f)) do
        if not skip[c] and not Skip(c) and Walk(c, depth - 1, want) then changed = true end
        -- A search box's grey hint (SearchBoxTemplate: SEARCH) is its own; the box's text is the player's.
        if not skip[c] and Skip(c) and Swap(rawget(c, "Instructions"), want) then changed = true end
    end
    return changed
end

-- A panel's .name and its settings category name (Groups, Profiles, Report Bug).
local function Name(f, want)
    local name = rawget(f, "name")
    local new = type(name) == "string" and Turn(name, want)
    if not new then return end
    f.name = new
    local cat = rawget(f, "category")
    if type(cat) ~= "table" then return end
    local ok, now = pcall(cat.GetName, cat)
    if not ok then now = rawget(cat, "name") end
    if now ~= name then return end
    if type(cat.SetName) == "function" then cat:SetName(new) else cat.name = new end
end

local function Import(f, want)
    local b = rawget(f, "ImportButton")
    if type(b) ~= "table" or type(b.GetText) ~= "function" then return end
    local uk = Lc.Extra(IMPORT, IMPORT)
    if not uk then return end
    local t = b:GetText()
    if want and t == IMPORT then b:SetText(uk)
    elseif not want and t == uk then b:SetText(IMPORT) end
end

-- Its tab buttons size themselves to their texts: let them fit again.
local function Tabs(f)
    local box = rawget(f, "ScrollBox")
    if type(PanelTemplates_ResizeTabsToFit) ~= "function" or type(box) ~= "table" then return end
    pcall(PanelTemplates_ResizeTabsToFit, f, box:GetWidth() - 32)
end

local function One(name, want)
    local f = rawget(_G, name)
    if type(f) ~= "table" then return end
    local changed = Walk(f, DEPTH, want)
    U.SafeCall(Name, f, want)
    if name == "LiteMountProfileImport" then U.SafeCall(Import, f, want) end
    if changed and name == "LiteMountMountsPanel" then Tabs(f) end
end

local function Run(want, only)
    U.SafeCall(GlobalMaps)
    if only then return One(only, want) end
    seen, ours = 0, 0
    for _, name in ipairs(ROOTS) do U.SafeCall(One, name, want) end
end

function S.Apply() Run(ns.WordsWanted()) end
function S.Restore()                               -- off: End runs before db.enabled is false
    Run(false)
    U.SafeCall(ns.Fonts.Restore)
end
function S.Count() return seen, ours end

-- Its panels redraw some texts on show; after that ours go back on. Like the English going back, this must
-- run once the module is off too, even after U.Safe turned it off for errors (lesson 19): then it only puts
-- the English back, and an error there is swallowed.
local function OnShowHook(name)
    local safe = Guard(function() Run(true, name) end)  -- not U.Safe: "on" after an off for errors brings it back
    return function()
        local ok, want = pcall(ns.WordsWanted)
        if ok and want then return safe() end
        pcall(Run, false, name)
    end
end

-- Its macro panel sets its help text at each redraw from a list made at load.
local function OnMacroRefresh(self)
    local ok, want = pcall(ns.WordsWanted)
    local fs = type(self) == "table" and type(self.Macro) == "table" and self.Macro.ExplainText
    if ok and want then pcall(Swap, fs, true) else pcall(Swap, fs, false) end
end

function S.Hook()
    for _, name in ipairs(ROOTS) do
        local f = rawget(_G, name)
        if not hooked[name] and type(f) == "table" and type(f.HookScript) == "function" then
            hooked[name] = true
            f:HookScript("OnShow", OnShowHook(name))
        end
    end
    local m = rawget(_G, "LiteMountMacroPanel")
    if not hooked.macro and type(m) == "table" and type(m.RefreshDisplay) == "function" then
        hooked.macro = true
        hooksecurefunc(m, "RefreshDisplay", OnMacroRefresh)
    end
end
