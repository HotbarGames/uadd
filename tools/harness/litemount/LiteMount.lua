-- Not LiteMount: a small stand-in for tools/harness/flow_litemount.py (UADD_LiteMount). It has only the parts the
-- module touches, built the way the installed LiteMount (GPL-2.0) builds them:
--   * its namespace on the secure button: LiteMount.LM, with LM.L made by its own Localization.lua (the flow
--     reads that file from the installed addon and hands it over in LiteMountStandInFeed.locale);
--   * the copies made at load: condition names (LM.Conditions:GetCondition), action names and descriptions,
--     sort key texts, its dialogs (StaticPopupDialogs) and its four key binding names;
--   * the functions that show them: Conditions:ToDisplay, a rule line (RuleBoolean:ToDisplay, S.ruleLine),
--     Mount.FilterToDisplay, Actions:ToDisplay / GetDescription, UIFilter.GetSortKeyText;
--   * its 13 panels, their XML texts set from L at OnLoad (AutoLocalize), titles and settings categories, the
--     Mounts tabs (PanelTemplates_ResizeTabsToFit), the macro help set at each RefreshDisplay, the Profiles
--     labels, the Import button, and the Falling "add" box with its dropdown (DropdownButton: SetupMenu keeps
--     the generator in .menuGenerator and builds the menu; root:CreateRadio);
--   * three more copies made at load (Copies.lua): the Mounts filter menu, the General page, rule errors;
--   * the parts that show a name: a rule's argument button (ArgDropDown) and the add box's Name label.
-- It holds no English of LiteMount's beyond a few labels. With no feed (flow_focus, chaos) L gives its keys.
-- feed.noL: no LM.L at all (the module must wait). S.throw > 0: the Groups panel's "thrower" text fails that
-- many times, so the module's own code hits an error.
local ADDON, LM = ...
local feed = rawget(_G, "LiteMountStandInFeed") or {}
local S = { throw = 0, resized = 0, radios = {}, groups = {}, flags = {} }
LiteMountStandIn = S

if feed.locale then
    local chunk = assert(loadstring(feed.locale, "@AddOns/LiteMount/Localization.lua"))
    setfenv(chunk, HARNESS.envFor(ADDON))
    chunk(ADDON, LM)
elseif not feed.noL then
    LM.L = setmetatable({}, { __index = function(_, k) return k end })
end
local L = LM.L or setmetatable({}, { __index = function(_, k) return k end })

LiteMount = CreateFrame("Button", "LiteMount", UIParent)
LiteMount.LM = LM

-- ── Conditions, rule lines ────────────────────────────────────────────────────────────────────
local CONDS = {
    btn = "LM_MOUSE_BUTTON_CLICKED", covenant = "LM_COVENANT", equipped = "LM_ITEM_EQUIPPED",
    flightstyle = "LM_FLIGHT_STYLE", friend = "LM_FRIEND_IN_GROUP", gather = "LM_GATHERED_RECENTLY",
    group = "LM_PARTY_OR_RAID_GROUP", holiday = "LM_HOLIDAY", known = "LM_SPELL_KNOWN",
    mod = "LM_MODIFIER_KEY", mounted = "LM_MOUNTED", season = "LM_SEASON", sex = "LM_SEX",
}
local C = { list = {} }
LM.Conditions = C
for id, k in pairs(CONDS) do C.list[id] = { name = L[k], textentry = (id == "known" or id == "equipped") } end
C.list.harness = { name = "harness", textentry = true }      -- the flow sets its name (halves check)

function C:GetCondition(id) return self.list[id] end
function C:ToDisplay(text)
    local id, valuestr = strsplit(":", text, 2)
    local c = self.list[id]
    if not c or c.disabled then return end
    if not c.name then return ADVANCED_LABEL or "Advanced", text end
    if not c.toDisplay then return c.name, c.textentry and valuestr or nil end
    return c.name, c.toDisplay(valuestr)
end

-- RuleBoolean:ToDisplay: NOT computes its inner line first, then reads L.LM_NOT_FORMAT.
function S.ruleLine(s)
    if s:sub(1, 1) == "~" then
        local text = S.ruleLine(s:sub(2))
        return string.format(L.LM_NOT_FORMAT, text)
    end
    local c, a = LM.Conditions:ToDisplay(s)
    if a then return format("%s : %s", c, a) elseif c then return c end
    return s .. " |A:gmchat-icon-alert:15:15|a"
end

-- ── Mount filters, actions, sort keys ─────────────────────────────────────────────────────────
LM.Mount = {}
function LM.Mount.FilterToDisplay(f)
    if f:sub(1, 1) == "~" then return string.format(L.LM_NOT_FORMAT, LM.Mount.FilterToDisplay(f:sub(2))) end
    local p = f:match("^prio:(%d+)$")
    if p then return L.LM_PRIORITY .. " : " .. p end
    if S.groups[f] then return L.LM_GROUP .. " : " .. f end
    if S.flags[f] then return (TYPE or "Type") .. " : " .. L[f] end
    return f
end

local ACTS = {
    Limit = { name = L.LM_LIMIT_MOUNTS, description = L.LM_LIMITSET_DESCRIPTION },
    Mount = { name = L.LM_MOUNT_ACTION, description = L.LM_MOUNT_DESCRIPTION },
    Spell = { name = L.LM_SPELL_ACTION, description = L.LM_SPELL_DESCRIPTION },
}
LM.Actions = {}
function LM.Actions:ToDisplay(action, args) local a = ACTS[action] return a and a.name or action end
function LM.Actions:GetDescription(action) local a = ACTS[action] return a and a.description end

local SORT = { priority = L.LM_PRIORITY }
LM.UIFilter = {}
function LM.UIFilter.GetSortKeyText(k) return SORT[k] or UNKNOWN or "Unknown" end

-- ── Dialogs and key binding names ─────────────────────────────────────────────────────────────
StaticPopupDialogs.LM_OPTIONS_NEW_GROUP = { text = format("LiteMount : %s", L.LM_NEW_GROUP),
    button1 = L.LM_CREATE_PROFILE_GROUP, button2 = L.LM_CREATE_GLOBAL_GROUP, hasEditBox = 1 }
StaticPopupDialogs.LM_OPTIONS_RENAME_GROUP = { text = format("LiteMount : %s", L.LM_RENAME_GROUP),
    button1 = ACCEPT, button2 = CANCEL, hasEditBox = 1 }
StaticPopupDialogs.LM_OPTIONS_DELETE_GROUP = { text = format("LiteMount : %s", L.LM_DELETE_GROUP),
    button1 = OKAY, button2 = CANCEL }
StaticPopupDialogs.LM_OPTIONS_NEW_PROFILE = { text = format("LiteMount : %s", L.LM_NEW_PROFILE),
    button1 = ACCEPT, button2 = CANCEL, hasEditBox = 1 }
StaticPopupDialogs.LM_OPTIONS_RESET_PROFILE = { text = "LiteMount : " .. L.LM_RESET_PROFILE .. " %s",
    button1 = OKAY, button2 = CANCEL }
for n = 1, 4 do
    _G["BINDING_NAME_CLICK LM_B" .. n .. ":LeftButton"] = format("LiteMount %s %d", KEY_BINDING or "Key Binding", n)
end

-- ── Panels ────────────────────────────────────────────────────────────────────────────────────
-- AutoLocalize: an XML text is a key; it shows L's word when L has one.
local function Auto(fs, key) if rawget(L, key) then fs:SetText(L[key]) else fs:SetText(key) end return fs end
local function Label(f, key) return Auto(f:CreateFontString(nil, "ARTWORK", "GameFontNormal"), key) end
local function Button(f, key)
    local b = CreateFrame("Button", nil, f)
    Auto(b, key)
    return b
end

local base
local function Panel(name, labels, buttons, title)
    local f = CreateFrame("Frame", name, UIParent)
    for _, k in ipairs(labels or {}) do f[k] = Label(f, k) end
    for _, k in ipairs(buttons or {}) do f[k] = Button(f, k) end
    if title then
        f.name = title
        f.category = base and Settings.RegisterCanvasLayoutSubcategory(base.category, f, f.name)
            or Settings.RegisterCanvasLayoutCategory(f, f.name)
    end
    f:Hide()
    return f
end

base = Panel("LiteMountBasePanel", { "LM_SETTINGS_TAGLINE", "LM_AUTHOR", "LM_HELP_TRANSLATE" }, nil, "LiteMount")
Settings.RegisterAddOnCategory(base.category)

local groups = Panel("LiteMountGroupsPanel", { "LM_GROUPS_EXP" }, nil, L.LM_GROUPS)
groups.Groups = CreateFrame("Frame", nil, groups)                    -- its scroll list: the player's names
function groups.Groups:GetDataProvider() return nil end
groups.Groups.Name = groups.Groups:CreateFontString()
local thrower = groups:CreateFontString()
thrower:SetText("x")
local getText = thrower.GetText
thrower.GetText = function(self)
    if S.throw > 0 then S.throw = S.throw - 1 error("stand-in: its text cannot be read") end
    return getText(self)
end

Panel("LiteMountRulesPanel", { "LM_RULES_EXP" }, { "LM_CONDITIONS", "LM_ACTION" }, L.LM_RULES)

local mounts = Panel("LiteMountMountsPanel", { "LM_SHOW_ALL_MOUNTS", "LM_PRIORITY" }, nil, L.LM_MOUNTS)
mounts.Tab1 = Button(mounts, "LM_LIST_VIEW")
mounts.Tab2 = Button(mounts, "LM_MODEL_VIEW")
mounts.ScrollBox = CreateFrame("Frame", nil, mounts)
mounts.ScrollBox:SetWidth(400)
mounts.ScrollBox.ScrollTarget = CreateFrame("Frame", nil, mounts.ScrollBox)
mounts.ScrollBox.ScrollTarget.Name = mounts.ScrollBox.ScrollTarget:CreateFontString()
if not rawget(_G, "PanelTemplates_ResizeTabsToFit") then
    function PanelTemplates_ResizeTabsToFit(frame, width) S.resized = S.resized + 1 end
end

local help = L.LM_MACRO_EXP                                          -- a file-local copy made at load
local macro = Panel("LiteMountMacroPanel", { "LM_MACRO_NOT_ALLOWED" }, nil, L.LM_MACRO)
macro.Macro = CreateFrame("Frame", nil, macro)
macro.Macro.ExplainText = macro.Macro:CreateFontString()
function macro:RefreshDisplay() self.Macro.ExplainText:SetText(help) end
macro:SetScript("OnShow", function(self) self:RefreshDisplay() end)
macro:RefreshDisplay()

Panel("LiteMountAdvancedPanel", { "LM_ADVANCED_EXP" }, nil, L.LM_ADVANCED)
Panel("LiteMountFallingPanel", { "LM_FALLING_EXP" }, { "LM_ADD_SPELL_OR_ITEM" }, L.LM_FALLING)

-- The Falling "add" box: its dropdown is built in its OnShow from a file-local list, sorted by text.
local addTypeTexts = { item = HELPFRAME_ITEM_TITLE or "Item", slot = L.LM_EQUIPMENT_SLOT,
    spell = STAT_CATEGORY_SPELL or "Spell" }
local addTypeOptions = { "item", "slot", "spell" }
table.sort(addTypeOptions, function(a, b) return addTypeTexts[a] < addTypeTexts[b] end)
local add = CreateFrame("Frame", "LiteMountFallingAdd", UIParent)
add.EditBox = CreateFrame("EditBox", nil, add)
add.EditBox:SetAutoFocus(false)
add.Dropdown = CreateFrame("Frame", nil, add)
add.Dropdown.Text = add.Dropdown:CreateFontString()
local Root = {}
function Root:CreateRadio(text, isSelected, setSelected)
    S.radios[#S.radios + 1] = text
    if isSelected() then add.Dropdown.Text:SetText(text) end         -- the dropdown shows the selected one
    return {}
end
function add.Dropdown:SetupMenu(gen)
    self.menuGenerator = gen
    wipe(S.radios)
    gen(self, Root)
end
local function BindingGenerator(owner, root)
    local parent = owner:GetParent()
    for _, v in ipairs(addTypeOptions) do
        local function IsSelected() return parent.type == v end
        local function SetSelected() parent.type = v end
        root:CreateRadio(addTypeTexts[v], IsSelected, SetSelected)
    end
end
add:SetScript("OnShow", function(self)
    self.type = addTypeOptions[1]
    self.EditBox:SetText("")
    self.Dropdown:SetupMenu(BindingGenerator)
end)
add:Hide()
add.Name = add:CreateFontString()                                    -- the text typed in its box

local profiles = Panel("LiteMountProfilesPanel", { "LM_PROFILES_EXP", "LM_CHANGE_PROFILE" },
    { "LM_NEW_PROFILE", "LM_RESET_PROFILE", "LM_DELETE_PROFILE", "LM_EXPORT_PROFILE", "LM_IMPORT_PROFILE" },
    L.LM_PROFILES)
profiles.CurrentProfileLabel = profiles:CreateFontString()
profiles.CurrentProfileLabel:SetText(L.LM_CURRENT_PROFILE .. " :")
profiles.CurrentProfile = profiles:CreateFontString()                -- the player's profile name
function S.profile(name) profiles.CurrentProfile:SetText(name) end   -- its RefreshDisplay

Panel("LiteMountProfileExport", { "LM_EXPORT_PROFILE_EXP" })
local import = Panel("LiteMountProfileImport", { "LM_IMPORT_PROFILE_EXP" })
import.ImportButton = CreateFrame("Button", nil, import)
import.ImportButton:SetText("Import")
import.ProfileName = CreateFrame("EditBox", nil, import)             -- autoFocus as in its XML; the panel is hidden
import.ProfileData = CreateFrame("EditBox", nil, import)
import.ProfileData:SetAutoFocus(false)

Panel("LiteMountReportBugPanel", { "LM_REPORT_BUG_EXP" }, nil, L.LM_REPORT_BUG)
local edit = Panel("LiteMountRuleEdit", { "LM_EDIT_RULE" }, { "LM_CONDITIONS", "LM_ACTIONS" })
edit.Argument = CreateFrame("EditBox", nil, edit)
edit.Argument:SetAutoFocus(false)
local cond = CreateFrame("Frame", nil, edit)                         -- RuleEdit.xml: Conditions[i]
edit.Conditions = { cond }
cond.TypeDropDown = CreateFrame("Button", nil, cond)
cond.ArgDropDown = CreateFrame("Button", nil, cond)                  -- shows a group, flag or mount name

-- The flow's way in: the player's names in a list, a box, labels and a rule's argument button.
function S.names(group, typed, mount, arg, added)
    groups.Groups.Name:SetText(group)
    import.ProfileName:SetText(typed)
    mounts.ScrollBox.ScrollTarget.Name:SetText(mount)
    cond.ArgDropDown:SetText(arg)
    add.Name:SetText(added)
end
function S.namesNow()
    return groups.Groups.Name:GetText(), import.ProfileName:GetText(), mounts.ScrollBox.ScrollTarget.Name:GetText(),
        cond.ArgDropDown:GetText(), add.Name:GetText()
end
function S.radioText() return add.Dropdown.Text:GetText() end
S.panels = { base = base, groups = groups, mounts = mounts, macro = macro, profiles = profiles, import = import,
    add = add, edit = edit }
