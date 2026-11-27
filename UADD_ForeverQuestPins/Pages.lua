-- UADD_ForeverQuestPins: its settings pages, found for Screen.lua (which walks them, both ways).
-- Its pages under the main one are found through the main category's subcategory links, never by their names
-- (common words: "Interface", "Navigation"). Their names in the settings tree are set from L at its load, before
-- our words came in: they are renamed both ways too, only while they hold our word or its English.
local _, ns = ...
local U = UADD
local Lc = ns.Locale
local S = ns.Screen
local Pg = {}
ns.Pages = Pg

local Guard = Lc.Guard                           -- not U.Safe: works again after an off for errors (lesson 19)
local NAME = "Forever Quest Pins"                -- its settings category and its canvas' .name
local Turn = S.Turn

local canvas = nil
local pages, subs, known = {}, {}, {}           -- its pages under the main one; their categories; both, as a set
local shown = {}                                 -- pages whose OnShow we already follow
Pg.pages, Pg.subs = pages, subs
function Pg.Canvas() return canvas end

-- A page's name in the settings tree, in the words wanted (only while it is our word or its English).
local function Rename(cat, want)
    if type(cat) ~= "table" then return end
    local ok, name = false, nil
    if type(cat.GetName) == "function" then ok, name = pcall(cat.GetName, cat) end
    if not ok then name = rawget(cat, "name") end
    if type(name) ~= "string" or name == "" then return end
    local new = Turn(name, want)
    if not new or new == name then return end
    if type(cat.SetName) == "function" then cat:SetName(new) else cat.name = new end
end
Pg.Rename = Rename

-- Its settings page: an unnamed frame, found through the settings window by its category name.
local function IsCanvas(f)
    return type(f) == "table" and rawget(f, "name") == NAME and type(f.GetObjectType) == "function"
end

-- Each page is walked again after its own OnShow builds and syncs it.
local function Hook(f)
    if type(f) ~= "table" or shown[f] or type(f.HookScript) ~= "function" then return end
    shown[f] = true
    f:HookScript("OnShow", Guard(S.Apply))
end

local function Frame(cat)
    local P = rawget(_G, "SettingsPanel")
    if type(P) ~= "table" or type(P.GetLayout) ~= "function" then return nil end
    local okL, layout = pcall(P.GetLayout, P, cat)
    if not okL or type(layout) ~= "table" or type(layout.GetFrame) ~= "function" then return nil end
    local okF, f = pcall(layout.GetFrame, layout)
    return okF and type(f) == "table" and f or nil
end

local function Found(f)
    if canvas or not IsCanvas(f) then return end
    canvas = f
    Hook(f)
end

local function IsMain(cat)
    if type(cat) ~= "table" or type(cat.GetName) ~= "function" then return false end
    local ok, name = pcall(cat.GetName, cat)
    return ok and name == NAME
end

local function Parent(cat)
    if type(cat.GetParentCategory) == "function" then
        local ok, p = pcall(cat.GetParentCategory, cat)
        if ok then return p end
    end
    return rawget(cat, "parentCategory")
end

-- Its pages under the main category, through the category's own links.
local function Subs(main)
    local list
    if type(main.GetSubcategories) == "function" then
        local ok, l = pcall(main.GetSubcategories, main)
        if ok then list = l end
    end
    if type(list) ~= "table" then list = rawget(main, "subcategories") end
    if type(list) ~= "table" then return end
    for _, cat in ipairs(list) do
        if type(cat) == "table" and not known[cat] then
            local f = Frame(cat)
            if f then
                known[cat] = true
                subs[#subs + 1] = cat
                pages[#pages + 1] = f
                Hook(f)
            end
        end
    end
end

-- true when cat is its main category or one of the pages under it.
local function FromCategory(cat)
    if type(cat) ~= "table" then return false end
    local main = cat
    if not IsMain(cat) then
        local ok, p = pcall(Parent, cat)
        if not (ok and IsMain(p)) then return false end
        main = p
    end
    if not canvas then Found(Frame(main)) end
    Subs(main)
    return true
end

function Pg.Look()
    local ok, cat = false, nil
    if Settings and type(Settings.GetCategory) == "function" then ok, cat = pcall(Settings.GetCategory, NAME) end
    if ok and cat then FromCategory(cat) end
    if canvas then return end
    local P = rawget(_G, "SettingsPanel")
    local box = type(P) == "table" and P.Container
    for _, holder in ipairs({ box, type(box) == "table" and box.SettingsCanvas or nil }) do
        if type(holder) == "table" then
            for _, c in ipairs(U.Children(holder)) do
                if IsCanvas(c) then return Found(c) end
            end
        end
    end
end

-- Hook the settings window (Blizzard's, made at load): when it opens or one of its pages is picked, find ours.
-- It stays S.HookPanel, as Module.lua calls it.
local hooked, waiting = false, nil
function S.HookPanel()
    if hooked then return end
    local P = rawget(_G, "SettingsPanel")
    if type(P) ~= "table" or type(P.HookScript) ~= "function" then return end
    if InCombatLockdown and InCombatLockdown() then
        if not waiting then
            waiting = CreateFrame("Frame")
            waiting:RegisterEvent("PLAYER_REGEN_ENABLED")
            waiting:SetScript("OnEvent", Guard(function(self)
                self:UnregisterAllEvents()
                S.HookPanel()
            end))
        end
        return
    end
    hooked = true
    P:HookScript("OnShow", Guard(S.Apply))
    if type(P.SelectCategory) == "function" then
        hooksecurefunc(P, "SelectCategory", Guard(function(_, cat)
            if FromCategory(cat) then S.Apply() end
        end))
    end
end
