-- Not LiteMount: the rest of the stand-in (LiteMount.lua), the three more copies of L's words it makes at load,
-- built the way the installed LiteMount (GPL-2.0) builds them: the Mounts filter menu, the General options page and
-- a compiled rule set's errors; and its lines glued to a game global.
local _, LM = ...
local S = LiteMountStandIn
local L = LM.L or setmetatable({}, { __index = function(_, k) return k end })

-- ── The Mounts filter menu (UI/MountsFilter.lua) ──────────────────────────────────────────────
S.filter, S.filterSub, S.filterThrow = {}, {}, 0
local function GroupList() local t = {} for g in pairs(S.groups) do t[#t + 1] = g end table.sort(t) return t end
local DROPDOWNS = {
    { text = L.LM_HIDDEN }, { text = L.LM_ZONEMATCH },
    { text = L.LM_PRIORITY, menulist = function() return { "1", "2" } end },
    { text = L.LM_GROUP, menulist = GroupList },
}
local FRoot = {}
function FRoot:SetTag() end
function FRoot:CreateCheckbox(text) S.filter[#S.filter + 1] = text return {} end
function FRoot:CreateButton(text)
    S.filter[#S.filter + 1] = text
    local sub = {}
    function sub:CreateCheckbox(t) S.filterSub[#S.filterSub + 1] = t return {} end
    return sub
end
local function DropdownGenerate(owner, rootDescription)
    rootDescription:SetTag("MENU_LITEMOUNT_FILTER")
    for i, info in ipairs(DROPDOWNS) do                      -- S.filterThrow > 0: it throws after its first item
        if i == 2 and S.filterThrow > 0 then S.filterThrow = S.filterThrow - 1 error("stand-in: a filter fails") end
        if info.menulist then
            local subMenu = rootDescription:CreateButton(info.text)
            for _, v in ipairs(info.menulist()) do subMenu:CreateCheckbox(v, function() end, function() end) end
        else
            rootDescription:CreateCheckbox(info.text, function() return false end, function() end)
        end
    end
end
local filter = CreateFrame("Frame", "LiteMountFilter", UIParent)
filter.FilterDropdown = CreateFrame("Frame", nil, filter)
function filter.FilterDropdown:SetupMenu(gen) self.menuGenerator = gen end
filter.FilterDropdown:SetupMenu(DropdownGenerate)
function S.filterOpen()                                              -- the menu opens: built from its generator
    wipe(S.filter)
    wipe(S.filterSub)
    filter.FilterDropdown.menuGenerator(filter.FilterDropdown, FRoot)
    return S.filter, S.filterSub
end
function S.filterIsTheirs() return filter.FilterDropdown.menuGenerator == DropdownGenerate end

-- ── The General options page (UI/General.lua): names built once by the Settings registrar ─────
S.GENERAL = { "LM_COPY_TARGETS_MOUNT", "LM_ADD_MOUNTS_AT_PRIORITY_0", "LM_INSTANT_ONLY_MOVING", "LM_RESTORE_FORMS",
    "LM_ADD_TO_TOOLTIP", "LM_SUMMON_STYLE", "LM_RANDOM_PERSISTENCE", "LM_ANNOUNCE_MOUNTS", "LM_COLOR_BY_PRIORITY",
    "LM_ANNOUNCE_FLIGHT_STYLE" }
if not rawget(_G, "EMOTE171_CMD1") then EMOTE171_CMD1 = "/idle" end
local general = CreateFrame("Frame", "LiteMountGeneralPanel", UIParent)
general:Hide()
-- The game's globals LiteMount glues to L's words (English, as on Forever).
for g, en in pairs({ DEFAULT = "Default", NONE = "None", CHAT = "Chat", MOUNT = "Mount", OPTIONS_MENU = "Options",
    KEY_BUTTON1 = "Left Mouse Button", BUG_CATEGORY5 = "User Interface", TOTAL = "Total", COLLECTED = "Collected" }) do
    if not rawget(_G, g) then _G[g] = en end
end
local function Initializer(name)
    local setting = { name = name }
    function setting:GetName() return self.name end
    return { data = { setting = setting, name = setting:GetName() } }
end
local function AnnounceVia()                -- its "Announce via" options, built from L each time it is drawn
    local c = Settings.CreateControlTextContainer()
    c:Add(0, NONE)
    c:Add(1, CHAT)
    c:Add(2, L.LM_ON_SCREEN_DISPLAY)
    c:Add(3, CHAT .. ' + ' .. L.LM_ON_SCREEN_DISPLAY)
    return c:GetData()
end
function S.general()                                                 -- its Register
    general.layout = { initializers = {} }
    function general.layout:GetInitializers() return self.initializers end
    function general.layout:AddInitializer(i) self.initializers[#self.initializers + 1] = i end
    for _, k in ipairs(S.GENERAL) do
        local i = Initializer(L[k])
        if k == "LM_ANNOUNCE_MOUNTS" then i.data.options = AnnounceVia end
        general.layout:AddInitializer(i)
    end
    general.layout:AddInitializer(Initializer(string.format(L.LM_MOUNTSPECIAL_TIMER, EMOTE171_CMD1)))
end
S.general()
function S.generalNames()
    local out = {}
    for _, i in ipairs(general.layout:GetInitializers()) do out[#out + 1] = i.data.name end
    return out
end
function LM.Print(...) S.printed = format(...) end                 -- Print.lua (its chat frame left out)
local function Drawn()                                               -- the Announce dropdown's options, as drawn
    for _, i in ipairs(general.layout:GetInitializers()) do
        if type(i.data.options) == "function" then return i.data.options() end
    end
end
-- Its lines glued to a game global, built as it builds them: global -> the line, and the word also shown alone.
local GLUED = {
    DEFAULT = function()                     -- UI/General.lua, two dropdowns' options (GetSettings)
        return string.format("%s (%s)", L.LM_SUMMON_STYLE_PRIORITY, DEFAULT) .. " | "
            .. string.format("%s (%s)", L.LM_EVERY_TIME, DEFAULT)
    end,
    MOUNT = function() return "|cffff00ff" .. L.LM_LEFT_CLICK .. ": " .. MOUNT .. "|r" end,          -- MountTooltip
    OPTIONS_MENU = function() return "|cffff00ff" .. L.LM_RIGHT_CLICK .. ": " .. OPTIONS_MENU .. "|r" end,
    KEY_BUTTON1 = function() return KEY_BUTTON1 .. ': ' .. L.LM_TOGGLE end,                        -- MountsFilter
    ["TOTAL+COLLECTED"] = function()         -- UI/Mounts.lua, the counts
        return string.format('%s: %s %s: %s %s: %s', TOTAL, "|cffffffff5|r", COLLECTED, "|cffffffff3|r", L.LM_USABLE,
            "|cffffffff2|r")
    end,
    CHAT = function() local o = Drawn() return o[4].label, o[3].label end,
    BUG_CATEGORY5 = function()               -- SlashCommand.lua: uidebug, then debug
        LM.Print(BUG_CATEGORY5 .. ' ' .. L.LM_DEBUGGING_ENABLED)
        local glued = S.printed
        LM.Print(L.LM_DEBUGGING_ENABLED)
        return glued, S.printed
    end,
}
function S.glued(g) return GLUED[g]() end

-- ── Rule errors (Options.lua, RuleSet.lua): formatted when compiled, printed later ──────────────
LM.Options = { cachedRuleSets = {} }
function LM.Options:GetCompiledRuleSet(n)
    local key = "user" .. n
    if not self.cachedRuleSets[key] then
        self.cachedRuleSets[key] = { errors = { { line = "zorp", err = format(L.LM_ERR_BAD_ACTION, "zorp") } } }
    end
    return self.cachedRuleSets[key]
end
function S.ruleError()                                               -- RuleSet:PrintErrors at its next Run
    local info = LM.Options:GetCompiledRuleSet(1).errors[1]
    return format(L.LM_ERR_BAD_RULE, info.line, info.err)
end
