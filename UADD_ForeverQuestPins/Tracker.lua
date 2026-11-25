-- UADD_ForeverQuestPins: the line its quest tracker shows when no quest matches its filter (since 1.1.8).
-- Forever Quest Pins draws it from L at each tracker update, so it is ours while our words are in L. Between two
-- updates it stays as drawn: off and the hold key switch this one line here, only while it is our word or its
-- English. Its block is looked up by its own id in Forever Quest Pins' own module frame; the tracker is never
-- walked, hooked, marked dirty or given a font (its font object has Cyrillic; UALL Forever translates the rest).
local _, ns = ...
local U = UADD
local Lc = ns.Locale
local Tr = {}
ns.Tracker = Tr

local FRAME, TEMPLATE, ID = "FQPQuestObjectiveTracker", "ObjectiveTrackerBlockTemplate", "fqp-filter-empty"

local function Line()
    local f = rawget(_G, FRAME)
    local used = type(f) == "table" and f.usedBlocks
    local of = type(used) == "table" and used[TEMPLATE]
    local block = type(of) == "table" and of[ID]
    local fs = type(block) == "table" and block.HeaderText
    return type(fs) == "table" and fs.GetText and fs.SetText and fs or nil
end

function Tr.Switch(want)
    local fs = Line()
    local t = fs and U.Plain(fs:GetText())
    if type(t) ~= "string" or t == "" then return end
    local new
    if want then new = Lc.Uk(t) else new = Lc.En(t) end
    if new and new ~= t then fs:SetText(new) end
end
