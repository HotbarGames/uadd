-- Not LiteMount: the rest of the stand-in (LiteMount.lua, Copies.lua): the game globals LiteMount shows on its own
-- frames, built the way the installed LiteMount (GPL-2.0) builds them:
--   * the Rules and Falling page names (UI/Rules.xml, UI/Falling.xml: KeyValue "name" type="global"; PanelTemplate
--     OnLoad sets .name, the Title and the settings category from it);
--   * its buttons' XML text="ADD" (DELETE, EDIT, PET_RENAME, CANCEL, OKAY) and each page's Defaults and Revert
--     buttons (UI/PanelTemplate.xml);
--   * the Rules and Advanced binding dropdowns: format('%s %s', KEY_BINDING, n) in their generator, set up in
--     OnLoad (SetupMenu keeps it in .menuGenerator); the dropdown shows the picked one;
--   * four conditions named by a game global (Conditions.lua: name = INSTANCE): instance and map show
--     "name (id)" for a known id, else the id (map: nothing).
-- The harness has none of these globals: each is set here, when absent, as the English client has it.
local _, LM = ...
local S = LiteMountStandIn
local EN = { BRAWL_TOOLTIP_RULES = "Rules", STRING_ENVIRONMENTAL_DAMAGE_FALLING = "Falling", ADD = "Add",
    DELETE = "Delete", EDIT = "Edit", PET_RENAME = "Rename", REVERT = "Revert", SETTINGS_DEFAULTS = "Defaults",
    KEY_BINDING = "Key Binding", INSTANCE = "Instance", LEVEL = "Level", BRAWL_TOOLTIP_MAP = "Map" }
for g, en in pairs(EN) do if rawget(_G, g) == nil then _G[g] = en end end

S.texts = {}                                                         -- { frame's text, its global } in order
local function Text(f, key, g)
    local b = CreateFrame("Button", nil, f)
    b:SetText(_G[g])
    f[key] = b
    S.texts[#S.texts + 1] = { b, g }
    return b
end

-- PanelTemplate: OnLoad sets the Title from .name; every page has a Defaults and a Revert button.
local function Template(name, global)
    local f = rawget(_G, name)
    if global then                                       -- L has no key for it: LiteMount.lua made no category
        f.name = _G[global]
        f.category = Settings.RegisterCanvasLayoutSubcategory(rawget(_G, "LiteMountBasePanel").category, f, f.name)
    end
    f.Title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    f.Title:SetText(f.name)
    Text(f, "DefaultsButton", "SETTINGS_DEFAULTS")
    Text(f, "RevertButton", "REVERT")
    return f
end

local rules = Template("LiteMountRulesPanel", "BRAWL_TOOLTIP_RULES")
Text(rules, "AddButton", "ADD")
Text(rules, "EditButton", "EDIT")
Text(rules, "DeleteButton", "DELETE")
local falling = Template("LiteMountFallingPanel", "STRING_ENVIRONMENTAL_DAMAGE_FALLING")
Text(falling, "DeleteButton", "DELETE")
Text(falling, "AddButton", "ADD")
local groups = Template("LiteMountGroupsPanel")
Text(groups, "AddGroupButton", "ADD")
Text(groups, "DeleteButton", "DELETE")
Text(groups, "RenameButton", "PET_RENAME")
local advanced = Template("LiteMountAdvancedPanel")
Text(Template("LiteMountMacroPanel"), "DeleteButton", "DELETE")
local add = rawget(_G, "LiteMountFallingAdd")
Text(add, "AddButton", "ADD")
Text(add, "CancelButton", "CANCEL")
local edit = rawget(_G, "LiteMountRuleEdit")
Text(edit, "CancelButton", "CANCEL")
Text(edit, "OkayButton", "OKAY")

-- ── The binding dropdowns (UI/Rules.lua, UI/Advanced.lua) ─────────────────────────────────────
S.bind = {}
local function BindingText(n) return format('%s %s', KEY_BINDING, n) end
local function BindingGenerator(owner, rootDescription)
    local function IsSelected(i) return owner.selected == i end
    local function SetSelected(i) owner.selected = i end
    for i = 1, 4 do rootDescription:CreateRadio(BindingText(i), IsSelected, SetSelected, i) end
end
local function Dropdown(f, key)
    local dd = CreateFrame("Frame", nil, f)
    dd.Text = dd:CreateFontString()
    dd.selected = 1
    local radios = {}
    local root = {}
    function root:CreateRadio(text, isSelected, setSelected, v)
        radios[#radios + 1] = text
        if isSelected(v) then dd.Text:SetText(text) end
        return {}
    end
    function dd:SetupMenu(gen)
        self.menuGenerator = gen
        wipe(radios)
        gen(self, root)
    end
    f.BindingDropDown = dd
    S.bind[key] = { dd = dd, radios = radios }
    dd:SetupMenu(BindingGenerator)
end
Dropdown(rules, "rules")
Dropdown(advanced, "advanced")
S.bind.advanced.dd.selected = 2
S.bind.advanced.dd:SetupMenu(BindingGenerator)
S.bindingGenerator = BindingGenerator
S.globalPages = { rules = rules, falling = falling }

-- ── Conditions named by a game global (Conditions.lua) ────────────────────────────────────────
S.places = { [249] = "Wobbly Keep" }                                 -- a made-up instance and map name
local C = LM.Conditions
local function Place(v)
    local n = S.places[tonumber(v)]
    if n then return string.format("%s (%s)", n, v) end
end
C.list.instance = { name = INSTANCE, toDisplay = function(v) return Place(v) or v end }
C.list.map = { name = BRAWL_TOOLTIP_MAP, toDisplay = Place }
C.list.level = { name = LEVEL, textentry = true }
C.list.falling = { name = STRING_ENVIRONMENTAL_DAMAGE_FALLING }
