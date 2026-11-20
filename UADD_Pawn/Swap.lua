-- UADD - Pawn: our Ukrainian into Pawn's words, and Pawn's English back (docs/LESSONS2.md lesson 15).
--
-- data/*.lua (made by tools/make_pawn_text.py) hold our Ukrainian by PawnLocal path ("Key", "UI.Key",
-- "Stats.Key"; ns.AL), what each % slot holds (ns.SORT), and data/names.lua the names of Pawn's UI globals
-- (ns.Names). No English is stored here: it is read from Pawn at run time and kept in memory.
--   * PawnLocal: each path we have gets ours (its English kept). Never written: STAY (Pawn parses or
--     compares with them) and DISPLAY (Pawn saves them in the player's data, lesson 14): those three show
--     ours only on screen, through the frame scan and the header hook below.
--   * What Pawn copied from PawnLocal while loading (UIStrings.lua): the UI globals, the tab label and
--     header lists, the stat rows of PawnStats ([1] name, [3] help, [5] a note). Each is changed only while
--     it still holds the English we saw, and put back only while it still holds ours.
--   * Its frames (made from XML while loading, before us): every FontString whose whole text is one of
--     Pawn's texts gets ours; on off, ours gets the English back. A fixed line in Pawn's code (the About
--     tab's thanks) is found by its hash ("Code.<hash>"). Scale names (the player's, or Pawn's) are never
--     touched: the selector's scale lines and every EditBox are skipped.
--   * A template is used only when its slots are the same, in the same order; never one with an `n` slot
--     (a game name: the line would be half English, CLAUDE.md "No half translations").

local _, ns = ...
local U = UADD
local W = {}
ns.Swap = W

local STAY = { DecimalSeparator = true, ThousandsSeparator = true, EngineeringName = true, TooltipParsing = true,
    Specs = true }
local DISPLAY = { NoScale = true, ["UI.AskMrRobotProvider"] = true, ["UI.StarterProvider"] = true }
local ROOTS = { "PawnUIFrame", "PawnInterfaceOptionsFrame", "PawnUIStringDialogSingleLine",
    "PawnUIStringDialogMultiLine" }
-- Labels Pawn fills once from a UI global with format (the player's name; Pawn's version).
local LABELS = {
    { "PawnUIFrame_ShowScaleCheck_Label", "PawnUIFrame_ShowScaleCheck_Label_Text",
        function() return UnitName and UnitName("player") or "" end },
    { "PawnUIFrame_AboutVersionLabel", "PawnUIFrame_AboutVersionLabel_Text",
        function() return U.Meta and U.Meta("Pawn", "Version") or "" end },
}
W.STAY, W.DISPLAY, W.ROOTS = STAY, DISPLAY, ROOTS

local saved, ours, shown = {}, {}, {}  -- path -> Pawn's English; path -> ours in PawnLocal; DISPLAY path -> ours
local whole, back = {}, {}             -- English -> ours, ours -> English (whole texts, no slots)
local gset, lset, sset = {}, {}, {}    -- what we wrote into globals, lists and stat rows (to put back)
local frames = 0

-- The % conversions of a text, in order ("sd"); "%%" is none, nor "50% more" (tools/key_text.py SLOT).
local function Specs(s)
    local out = {}
    for c in (s:gsub("%%%%", "")):gmatch("%%[-+#0]*%d*%.?%d*([sdifx])") do out[#out + 1] = c end
    return table.concat(out)
end
W.Specs = Specs

-- The PawnLocal table and field of `path`, or nil (STAY, a code line, an unknown part).
local function Where(path)
    local L = rawget(_G, "PawnLocal")
    if type(L) ~= "table" or type(path) ~= "string" then return nil end
    local part, leaf = path:match("^(%a+)%.([%w_]+)$")
    if part then
        if part ~= "UI" and part ~= "Stats" then return nil end
        local t = rawget(L, part)
        if type(t) ~= "table" then return nil end
        return t, leaf
    end
    if path:find("^[%w_]+$") and not STAY[path] then return L, path end
    return nil
end
W.Where = Where

-- May `path` take our Ukrainian over Pawn's English `en`? Then that Ukrainian, else nil.
local function Usable(path, en)
    local uk = ns.AL[path]
    if STAY[path] or type(uk) ~= "string" or uk == "" or type(en) ~= "string" or uk == en then return nil end
    local sort = ns.SORT[path]
    if type(sort) == "string" and sort:find("n") then return nil end
    local c = Specs(en)
    if c ~= Specs(uk) then return nil end
    if type(sort) == "string" and #sort ~= #c then return nil end
    return uk
end
W.Usable = Usable

-- ── Globals, lists, stat rows ─────────────────────────────────────────────────────────────────

local function Globals(on)
    local G = ns.Names and ns.Names.G or {}
    for name, path in pairs(G) do
        local cur = rawget(_G, name)
        if on then
            local uk = ours[path]
            if uk and cur == saved[path] then gset[name] = { en = cur, uk = uk }; _G[name] = uk end
        elseif gset[name] and cur == gset[name].uk then
            _G[name] = gset[name].en
        end
    end
    if not on then wipe(gset) end
end

local function Lists(on)
    if not on then
        for _, s in ipairs(lset) do if s.t[s.i] == s.uk then s.t[s.i] = s.en end end
        wipe(lset)
        return
    end
    for list, paths in pairs(ns.Names and ns.Names.L or {}) do
        local t = rawget(_G, list)
        for i, path in ipairs(type(t) == "table" and paths or {}) do
            local uk = ours[path]
            if uk and t[i] == saved[path] then
                lset[#lset + 1] = { t = t, i = i, en = t[i], uk = uk }
                t[i] = uk
            end
        end
    end
end

local function Stats(on)
    if not on then
        for _, s in ipairs(sset) do if s.row[s.i] == s.uk then s.row[s.i] = s.en end end
        wipe(sset)
        return
    end
    local m = {}
    for _, path in ipairs(ns.Names and ns.Names.ST or {}) do
        if ours[path] then m[saved[path]] = ours[path] end
    end
    local seen = {}
    for _, name in ipairs({ "PawnStats", "PawnStatsUnfiltered" }) do
        local rows = rawget(_G, name)
        for _, row in ipairs(type(rows) == "table" and rows or {}) do
            if type(row) == "table" and not seen[row] then
                seen[row] = true
                for _, i in ipairs({ 1, 3, 5 }) do
                    local v = row[i]
                    if type(v) == "string" and m[v] then
                        sset[#sset + 1] = { row = row, i = i, en = v, uk = m[v] }
                        row[i] = m[v]
                    end
                end
            end
        end
    end
end

-- ── PawnLocal ─────────────────────────────────────────────────────────────────────────────────

function W.SwapIn()
    if not ns.WordsWanted() or rawget(_G, "PawnLocal") == nil then return end
    wipe(ours); wipe(shown); wipe(whole); wipe(back)
    for path in pairs(ns.AL) do
        local t, leaf = Where(path)
        if t then
            local en = saved[path]
            if en == nil then en = rawget(t, leaf) end
            local uk = Usable(path, en)
            if uk then
                saved[path] = en
                if DISPLAY[path] then shown[path] = uk else rawset(t, leaf, uk); ours[path] = uk end
                if Specs(en) == "" then whole[en], back[uk] = uk, en end
            end
        end
    end
    Globals(true)
    Lists(true)
    Stats(true)
end

function W.SwapOut()
    Stats(false)
    Lists(false)
    Globals(false)
    for path, uk in pairs(ours) do
        local t, leaf = Where(path)
        if t and rawget(t, leaf) == uk then rawset(t, leaf, saved[path]) end
    end
    wipe(ours); wipe(shown)
end

function W.Count() return (function() local n = 0; for _ in pairs(ours) do n = n + 1 end; return n end)() end
function W.Frames() return frames end
function W.English(path) return saved[path] end
function W.Shown(path) return shown[path] end
function W.Translate(t) return whole[t] end  -- ours for one of Pawn's whole texts (U.MissedModule)

-- ── Frames ────────────────────────────────────────────────────────────────────────────────────

-- The scale's own name, unless Pawn shows its "no scale" text there.
local function NoScaleShown()
    local L = rawget(_G, "PawnLocal")
    local cur = rawget(_G, "PawnUICurrentScale")
    return L and shown.NoScale and (cur == nil or cur == L.NoScale)
end

-- One FontString: ours for Pawn's English (on), Pawn's English for ours (off).
-- The scale name label holds the player's scale name: never ours, both ways (LESSONS 13).
local function One(fs, on)
    if fs == rawget(_G, "PawnUIFrame_ScaleNameLabel") and not NoScaleShown() then return end
    local t = U.Plain(fs:GetText())
    if not t or t == "" then return end
    if on then
        local uk = whole[t]
        if not uk and U.Hash then
            local c = ns.AL["Code." .. (U.Hash(t) or "")]
            if type(c) == "string" and c ~= "" and c ~= t and Specs(c) == Specs(t) then uk, back[c] = c, t end
        end
        if uk then fs:SetText(uk); frames = frames + 1 end
    elseif back[t] then
        fs:SetText(back[t])
    end
end
W.One = One

local function Walk(f, on, seen)
    if type(f) ~= "table" or seen[f] or not f.GetObjectType then return end
    seen[f] = true
    local kind = f:GetObjectType()
    if kind == "EditBox" then return end                      -- what the player types: never ours
    if kind == "FontString" then return One(f, on) end
    if f.ScaleName ~= nil then return end                     -- a scale line: the scale's own name
    if f.GetFontString and f:GetFontString() then One(f:GetFontString(), on) end
    for _, g in ipairs({ f:GetRegions() }) do
        if g.GetObjectType and g:GetObjectType() == "FontString" then One(g, on) end
    end
    for _, c in ipairs({ f:GetChildren() }) do Walk(c, on, seen) end
end

function W.Scan(on)
    local seen = {}
    if on then frames = 0 end
    for _, name in ipairs(ROOTS) do
        local f = rawget(_G, name)
        if f then U.SafeCall(Walk, f, on, seen) end
    end
    for i = 1, 10 do
        local tab = rawget(_G, "PawnUIFrameTab" .. i)
        if tab and PanelTemplates_TabResize then pcall(PanelTemplates_TabResize, tab, 0) end
    end
end

-- The labels Pawn formats once, then what it shows now (its own refresh code reads PawnLocal again).
function W.Refresh()
    for _, l in ipairs(LABELS) do
        local fs, g = rawget(_G, l[1]), rawget(_G, l[2])
        if fs and fs.SetText and type(g) == "string" then pcall(function() fs:SetText(format(g, l[3]())) end) end
    end
    local ui = rawget(_G, "PawnUIFrame")
    if not (ui and ui.IsShown and ui:IsShown()) then return end
    for _, fn in ipairs({ "PawnUIFrame_ScaleSelector_Refresh", "PawnUI_ScalesTab_Refresh", "PawnUI_ValuesTab_Refresh",
        "PawnUI_CompareTab_Refresh", "PawnUIUpdateHeader" }) do
        U.SafeCall(rawget(_G, fn))
    end
end

-- ── Hooks (once; they act only while our words are wanted) ────────────────────────────────────

local function OnHeader()
    if not ns.WordsWanted() or not NoScaleShown() then return end
    local list, tab, hdr = rawget(_G, "PawnUIHeaders"), rawget(_G, "PawnUICurrentTabNumber"), rawget(_G, "PawnUIHeader")
    local fmt = type(list) == "table" and list[tab]
    if hdr and type(fmt) == "string" and back[fmt] == nil and fmt:find("[\208-\210]") then
        hdr:SetText(format(fmt, shown.NoScale))
    end
end

local function OnLines()
    if not ns.WordsWanted() then return end
    for i = 1, tonumber(rawget(_G, "PawnUITotalScaleLines")) or 0 do
        local line = rawget(_G, "PawnUIScaleLine" .. i)
        if line and line.ScaleName == nil and line.GetFontString and line:GetFontString() then
            One(line:GetFontString(), true)
        end
    end
end

local function OnScales()
    local fs = rawget(_G, "PawnUIFrame_ScaleNameLabel")
    if ns.WordsWanted() and fs and NoScaleShown() then One(fs, true) end
end

local function OnLoaded()
    if not ns.WordsWanted() then return end
    local fs = rawget(_G, "PawnUIFrame_MrRobotLabel")
    if fs then One(fs, true) end
end

local hooked = false
function W.Install()
    if hooked then return end
    hooked = true
    local hooks = { PawnUIUpdateHeader = OnHeader, PawnUIFrame_ScaleSelector_Refresh = OnLines,
        PawnUI_ScalesTab_Refresh = OnScales, PawnUI_EnsureLoaded = OnLoaded }
    for name, fn in pairs(hooks) do
        if type(rawget(_G, name)) == "function" then
            hooksecurefunc(name, function() U.SafeCall(fn) end)
        end
    end
    local ui = rawget(_G, "PawnUIFrame")
    if ui and ui.HookScript then
        ui:HookScript("OnShow", function() if ns.WordsWanted() then U.SafeCall(W.Scan, true) end end)
    end
end
