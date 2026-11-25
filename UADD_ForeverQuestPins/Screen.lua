-- UADD_ForeverQuestPins: the frames Forever Quest Pins builds once, switched both ways (lesson 15).
-- Its settings (a main page and, since 1.1, five pages under it, each built on its first show), its first-run
-- setup window and its breadcrumb dialog read L only when they are made or redrawn, so a text drawn before our
-- words came in, or while the hold key was down, stays as it was drawn. Apply walks only these frames
-- (U.Regions / U.Children) and swaps each FontString that is our word or its English. A text that is neither (a
-- quest title, another addon's) is never touched.
-- Its pages under the main one are found through the main category's subcategory links, never by their names
-- (common words: "Interface", "Navigation"). Their names in the settings tree are set from L at its load, before
-- our words came in: they are renamed both ways too, only while they hold our word or its English.
-- Its settings checkboxes keep their label and tooltip in an OnEnter closure: a tooltip hook swaps the lines
-- of GameTooltip while one of its own checkboxes owns it.
local _, ns = ...
local U = UADD
local Lc = ns.Locale
local S = {}
ns.Screen = S

local Guard = Lc.Guard                           -- not U.Safe: works again after an off for errors (lesson 19)
local NAME = "Forever Quest Pins"                -- its settings category and its canvas' .name
local ROOTS = { "ForeverQuestPinsSetup", "ForeverQuestPinsBreadcrumb", "ForeverQuestPinsMapFilterList" }
local DEPTH = 5

local canvas = nil
local pages, subs, known = {}, {}, {}           -- its pages under the main one; their categories; both, as a set
local seen, ours = 0, 0
local tipped = {}                                -- frames whose OnEnter we already follow
local shown = {}                                 -- pages whose OnShow we already follow

-- The bits its Config.lua glues onto a label: the player's level range (" (50-61)") onto the auto-accept label,
-- and since 1.1.4 " (BETA)" onto the quest tracker page's heading and checkbox.
local TAILS = { " %(%d+%-%d+%)", " %(BETA%)" }
local JOINS = 8                                  -- at most this many sentence ends tried in one text

local function One(t, want)
    if want then return Lc.Uk(t) end
    return Lc.En(t)
end

-- A text in the words wanted, or nil. A label with a glued bit: the head is swapped and the bit kept. Two of its
-- sentences joined by a space (1.1.4 to 1.1.6: the quest tracker page's help line): each is swapped, only when both
-- are ours or their English, never one alone. So off and the hold key bring these back too (lesson 6).
local function Turn(t, want)
    local new = One(t, want)
    if new then return new end
    for _, tail in ipairs(TAILS) do
        local head, bit = t:match("^(.-)(" .. tail .. ")$")
        if head and head ~= "" then
            new = One(head, want)
            if new then return new .. bit end
        end
    end
    local from = 1
    for _ = 1, JOINS do
        local i = t:find("[%.!?] ", from)
        if not i then break end
        local a, b = One(t:sub(1, i), want), One(t:sub(i + 2), want)
        if a and b then return a .. " " .. b end
        from = i + 2
    end
    return nil
end

-- The font follows the text (lesson 32): its lines use GameFontNormal and GameFontHighlight, which have no
-- Cyrillic on Forever. A line that shows Cyrillic (ours, or L's word it drew itself) gets UADD's font; once it is
-- English again it gets its own font back (U.CyrFix / U.CyrUnfix).
local kept = setmetatable({}, { __mode = "k" })
function S.Font(fs)
    local t = U.Plain(fs:GetText())
    if type(t) ~= "string" then return end
    if t:find("[\208\209][\128-\191]") then
        if kept[fs] and not U.IsCyrFont((fs:GetFont())) then kept[fs] = nil end   -- a font set since ours: its own now
        U.CyrFix(fs, kept)
    elseif kept[fs] then U.CyrUnfix(fs, kept) end
end

local function Swap(fs, want)
    if type(fs) ~= "table" or type(fs.GetText) ~= "function" then return end
    local t = U.Plain(fs:GetText())
    if type(t) ~= "string" or t == "" then return end
    seen = seen + 1
    local new = Turn(t, want)
    if new and new ~= t then
        fs:SetText(new)
        if want then ours = ours + 1 end
    elseif want and Turn(t, false) then
        ours = ours + 1
    end
    U.SafeCall(S.Font, fs)
end

-- The tooltip of one of its settings checkboxes, in the words now wanted.
local function OnTip(self)
    if not (GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(self)) then return end
    local want = ns.WordsWanted()
    local n = GameTooltip:NumLines() or 0
    local changed = false
    for i = 1, math.min(n, 12) do
        local fs = rawget(_G, "GameTooltipTextLeft" .. i)
        local t = fs and U.Plain(fs:GetText())
        if type(t) == "string" and t ~= "" then
            local new = Turn(t, want)
            if new and new ~= t then fs:SetText(new) changed = true end
        end
    end
    if changed then GameTooltip:Show() end
end

-- The checkboxes' OnEnter closures hold the words they were built with, so the hook must also run once the
-- module is off, for errors too (lesson 19): then it only puts the English back, and an error there is
-- swallowed, never counted or shown.
local SafeTip = Guard(OnTip)
local function TipHook(self)
    local ok, want = pcall(ns.WordsWanted)
    if ok and want then return SafeTip(self) end
    pcall(OnTip, self)
end

-- A frame whose OnEnter tooltip holds its words: its settings checkboxes (Walk), the World Map filter button
-- (Menu.lua).
function S.TipOn(f)
    if tipped[f] or type(f) ~= "table" or type(f.HookScript) ~= "function" then return end
    tipped[f] = true
    f:HookScript("OnEnter", TipHook)
end

local function Walk(f, depth, want, tips)
    if type(f) ~= "table" or depth < 0 then return end
    for _, r in ipairs(U.Regions(f)) do
        if r.GetObjectType and r:GetObjectType() == "FontString" then Swap(r, want) end
    end
    if type(f.GetFontString) == "function" then Swap(f:GetFontString(), want) end
    if type(f.disabledReason) == "string" then
        local new = Turn(f.disabledReason, want)
        if new then f.disabledReason = new end
    end
    if tips and not tipped[f] and type(f.GetScript) == "function" and f:GetScript("OnEnter") then S.TipOn(f) end
    for _, c in ipairs(U.Children(f)) do Walk(c, depth - 1, want, tips) end
end

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

-- Its settings page: an unnamed frame, found through the settings window by its category name.
local function IsCanvas(f)
    return type(f) == "table" and rawget(f, "name") == NAME and type(f.GetObjectType) == "function"
end

local Look

local function Run(want)
    seen, ours = 0, 0
    U.SafeCall(Look)
    if canvas and canvas.built then Walk(canvas, DEPTH, want, true) end
    for _, p in ipairs(pages) do
        if p.built then Walk(p, DEPTH, want, true) end
    end
    for _, cat in ipairs(subs) do U.SafeCall(Rename, cat, want) end
    for _, name in ipairs(ROOTS) do
        local f = rawget(_G, name)
        if type(f) == "table" then Walk(f, DEPTH, want, false) end
    end
    U.SafeCall(ns.Breadcrumb.Switch, want)
    U.SafeCall(ns.Tracker.Switch, want)
    -- The breadcrumb dialog sizes itself to its texts: let it lay out again.
    local p = ns.Breadcrumb.Panel() or rawget(_G, "ForeverQuestPinsBreadcrumb")
    if type(p) == "table" and p.IsShown and p:IsShown() and p.GetScript then
        local layout = p:GetScript("OnShow")
        if layout then U.SafeCall(layout, p) end
    end
end

function S.Apply() Run(ns.WordsWanted()) end
-- One of its frames alone, in the words wanted (the filter list after a click, Menu.lua).
function S.ApplyTo(f) if type(f) == "table" then Walk(f, DEPTH, ns.WordsWanted(), false) end end
function S.Restore() Run(false) end           -- off: End runs before db.enabled is false
function S.Count() return seen, ours end

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

function Look()
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
