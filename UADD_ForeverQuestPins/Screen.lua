-- UADD_ForeverQuestPins: the frames Forever Quest Pins builds once, switched both ways (lesson 15).
-- Its settings page (built on its first show), its first-run setup window and its breadcrumb dialog read L only
-- when they are made or redrawn, so a text drawn before our words came in, or while the hold key was down,
-- stays as it was drawn. Apply walks only these frames (U.Regions / U.Children) and swaps each FontString that
-- is our word or its English. A text that is neither (a quest title, another addon's) is never touched.
-- Its settings checkboxes keep their label and tooltip in an OnEnter closure: a tooltip hook swaps the lines
-- of GameTooltip while one of its own checkboxes owns it.
local _, ns = ...
local U = UADD
local Lc = ns.Locale
local S = {}
ns.Screen = S

local KEY = "foreverquestpins"
local NAME = "Forever Quest Pins"                -- its settings category and its canvas' .name
local ROOTS = { "ForeverQuestPinsSetup", "ForeverQuestPinsBreadcrumb" }
local DEPTH = 5

local canvas = nil
local seen, ours = 0, 0
local tipped = {}                                -- frames whose OnEnter we already follow

-- A text in the words wanted, or nil. Its Config.lua glues the player's level range (" (50-61)") onto the
-- auto-accept label: the head is swapped and the range kept, so off and the hold key bring it back too.
local function Turn(t, want)
    local new
    if want then new = Lc.Uk(t) else new = Lc.En(t) end
    if new then return new end
    local head, tail = t:match("^(.-)( %(%d+%-%d+%))$")
    if head and head ~= "" then
        if want then new = Lc.Uk(head) else new = Lc.En(head) end
        if new then return new .. tail end
    end
    return nil
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
-- module is off, even after U.Safe turned it off for errors (lesson 19): then it only puts the English back,
-- and an error there is swallowed, never counted or shown.
local SafeTip = U.Safe(KEY, OnTip)
local function TipHook(self)
    local ok, want = pcall(ns.WordsWanted)
    if ok and want then return SafeTip(self) end
    pcall(OnTip, self)
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
    if tips and not tipped[f] and type(f.GetScript) == "function" and type(f.HookScript) == "function"
        and f:GetScript("OnEnter") then
        tipped[f] = true
        f:HookScript("OnEnter", TipHook)
    end
    for _, c in ipairs(U.Children(f)) do Walk(c, depth - 1, want, tips) end
end

-- Its settings page: an unnamed frame, found through the settings window by its category name.
local function IsCanvas(f)
    return type(f) == "table" and rawget(f, "name") == NAME and type(f.GetObjectType) == "function"
end

local function Run(want)
    seen, ours = 0, 0
    if canvas and canvas.built then Walk(canvas, DEPTH, want, true) end
    for _, name in ipairs(ROOTS) do
        local f = rawget(_G, name)
        if type(f) == "table" then Walk(f, DEPTH, want, false) end
    end
    U.SafeCall(ns.Breadcrumb.Switch, want)
    -- The breadcrumb dialog sizes itself to its texts: let it lay out again.
    local p = ns.Breadcrumb.Panel() or rawget(_G, "ForeverQuestPinsBreadcrumb")
    if type(p) == "table" and p.IsShown and p:IsShown() and p.GetScript then
        local layout = p:GetScript("OnShow")
        if layout then U.SafeCall(layout, p) end
    end
end

function S.Apply() Run(ns.WordsWanted()) end
function S.Restore() Run(false) end           -- off: End runs before db.enabled is false
function S.Count() return seen, ours end

local function Found(f)
    if canvas or not IsCanvas(f) then return end
    canvas = f
    if type(f.HookScript) == "function" then
        f:HookScript("OnShow", U.Safe(KEY, S.Apply))  -- after its own OnShow builds and syncs it
    end
    S.Apply()
end

local function FromCategory(cat)
    local P = rawget(_G, "SettingsPanel")
    if type(cat) ~= "table" or type(P) ~= "table" then return end
    local ok, name = pcall(cat.GetName, cat)
    if not ok or name ~= NAME then return end
    if type(P.GetLayout) == "function" then
        local okL, layout = pcall(P.GetLayout, P, cat)
        if okL and type(layout) == "table" and type(layout.GetFrame) == "function" then
            local okF, f = pcall(layout.GetFrame, layout)
            if okF then Found(f) end
        end
    end
end

local function Look()
    if canvas then return end
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

-- Hook the settings window (Blizzard's, made at load): when its page is picked, find our canvas.
local hooked, waiting = false, nil
function S.HookPanel()
    if hooked then return end
    local P = rawget(_G, "SettingsPanel")
    if type(P) ~= "table" or type(P.HookScript) ~= "function" then return end
    if InCombatLockdown and InCombatLockdown() then
        if not waiting then
            waiting = CreateFrame("Frame")
            waiting:RegisterEvent("PLAYER_REGEN_ENABLED")
            waiting:SetScript("OnEvent", U.Safe(KEY, function(self)
                self:UnregisterAllEvents()
                S.HookPanel()
            end))
        end
        return
    end
    hooked = true
    P:HookScript("OnShow", U.Safe(KEY, Look))
    if type(P.SelectCategory) == "function" then
        hooksecurefunc(P, "SelectCategory", U.Safe(KEY, function(_, cat)
            FromCategory(cat)
            if canvas and canvas.IsShown and canvas:IsShown() then S.Apply() end
        end))
    end
end
