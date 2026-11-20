-- UADD - Pawn: the game's own names in Pawn's stat list, taken from UALL Forever at run time (lesson 9).
--   * Pawn's stat rows (PawnStats, PawnStatsUnfiltered) name each stat, and the two header rows, with the
--     game's own string (row[1]). When Pawn's window shows, each such name goes to UADD.UALL.Text; where UALL
--     Forever has it, the row holds its Ukrainian. We write no name. A name it lacks stays English.
--   * Lines Pawn builds around a name take our words only around a Ukrainian name: "1 <name> is worth:" (the
--     template StatNameText, slot n) and "<name> (unusable)". With an English name both stay whole English.
--   * "Not now" from UALL Forever (combat, a window on screen): asked again a little later, never cached.
--   * Off, and while the hold key is held: the English goes back, only where a row still holds our name.

local _, ns = ...
local U = UADD
local G = {}
ns.Game = G

local CYR = "[\208-\210]"                -- the first byte of a Cyrillic letter in UTF-8
local set = {}                           -- { row, en, uk } for each name we put in
local wait, retrying = false, false

local function Rows()
    local out, seen = {}, {}
    for _, name in ipairs({ "PawnStats", "PawnStatsUnfiltered" }) do
        local rows = rawget(_G, name)
        for _, row in ipairs(type(rows) == "table" and rows or {}) do
            if type(row) == "table" and not seen[row] then
                seen[row] = true
                out[#out + 1] = row
            end
        end
    end
    return out
end

-- On: UALL Forever's Ukrainian into each row it has a name for; true when a row changed. Off: the English back.
function G.Names(on)
    if not on then
        for _, s in ipairs(set) do if s.row[1] == s.uk then s.row[1] = s.en end end
        wipe(set)
        wait = false
        return false
    end
    local L = U.UALL
    if not (L and L.Text) then return false end
    local done, changed = {}, false
    for _, s in ipairs(set) do done[s.row] = true end
    wait = false
    for _, row in ipairs(Rows()) do
        local en = row[1]
        if not done[row] and type(en) == "string" and en ~= "" and not en:find(CYR) then
            local uk, later = L.Text(en)
            if later then
                wait = true
            elseif type(uk) == "string" and uk:find(CYR) then
                set[#set + 1] = { row = row, en = en, uk = uk }
                row[1] = uk
                changed = true
            end
        end
    end
    return changed
end

function G.Count() return #set end
function G.Waiting() return wait end

local function Shown()
    local ui = rawget(_G, "PawnUIFrame")
    return ui and ui.IsShown and ui:IsShown()
end

-- Names in, then Pawn draws its lists again; once more a little later while UALL Forever says "not now".
local function Fill()
    if not ns.WordsWanted() then return end
    if G.Names(true) and Shown() then U.SafeCall(ns.Swap.Refresh) end
    if wait and not retrying and C_Timer and C_Timer.After then
        retrying = true
        C_Timer.After(2, function()
            retrying = false
            if Shown() then U.SafeCall(Fill) end
        end)
    end
end
G.Fill = Fill

local function English(line) return type(line) == "string" and not line:find(CYR) end

-- "1 <name> is worth:" with a Ukrainian name: our template around it (Pawn's own is English).
local function OnSelect()
    if not ns.WordsWanted() then return end
    local idx, rows = tonumber(rawget(_G, "PawnUICurrentStatIndex")) or 0, rawget(_G, "PawnStats")
    local row = idx > 0 and type(rows) == "table" and rows[idx]
    local fs, fmt, en = rawget(_G, "PawnUIFrame_StatNameLabel"), ns.AL.StatNameText, ns.Swap.English("StatNameText")
    local P = rawget(_G, "PawnLocal")
    en = en or (type(P) == "table" and P.StatNameText)
    if type(row) ~= "table" or row[5] ~= nil or type(row[1]) ~= "string" or English(row[1]) then return end
    if not (fs and fs.GetText and type(fmt) == "string" and type(en) == "string") then return end
    if fs:GetText() == format(en, row[1]) then pcall(function() fs:SetText(format(fmt, row[1])) end) end
end

-- "<name> (unusable)" with an English name: Pawn's English word, so the line is whole English.
local function OnItem(i, index)
    if not ns.WordsWanted() then return end
    local rows, P = rawget(_G, "PawnStats"), rawget(_G, "PawnLocal")
    local row, line = type(rows) == "table" and rows[index], rawget(_G, "PawnUIFrame_StatsList_Item" .. tostring(i))
    local en = ns.Swap.English("Unusable")
    if type(row) ~= "table" or not English(row[1]) or not (line and line.GetText) then return end
    if type(en) ~= "string" or type(P) ~= "table" or type(P.Unusable) ~= "string" or P.Unusable == en then return end
    if line:GetText() == "  " .. row[1] .. " " .. P.Unusable then
        pcall(function() line:SetText("  " .. row[1] .. " " .. en) end)
    end
end

local hooked = false
function G.Install()
    if hooked then return end
    hooked = true
    local hooks = { PawnUIFrame_StatsList_SelectStat = OnSelect, PawnUIFrame_StatsList_UpdateStatItem = OnItem }
    for name, fn in pairs(hooks) do
        if type(rawget(_G, name)) == "function" then
            hooksecurefunc(name, function(...) U.SafeCall(fn, ...) end)
        end
    end
    local ui = rawget(_G, "PawnUIFrame")
    if ui and ui.HookScript then ui:HookScript("OnShow", function() U.SafeCall(Fill) end) end
end
