-- Lua helpers for flow_pawn_names.py: Pawn's stat list, shaped like Pawn's where UADD_Pawn/Game.lua touches
-- it (our code, no Pawn text). Run after flow_pawn.lua and before the game starts, so the module hooks it.
--   * PawnUIFrame_StatsList_Item1..N: one line per row of PawnStats (a header row: its name alone; an
--     ignored stat: the name and PawnLocal.Unusable; any other stat: the name).
--   * PawnUIFrame_StatNameLabel: format(PawnLocal.StatNameText, the chosen row's name).
--   * HARNESS.pawn.names: a stand-in for UALL Forever's answers (UADD.UALL.Text), set after login.
local H = HARNESS
local M = H.pawn
local ui = PawnUIFrame
local N = #PawnStats
PawnUIStatsListHeight = N
PawnUICurrentStatIndex = 0
M.ignored = {}
M.en = { Unusable = PawnLocal.Unusable, StatNameText = PawnLocal.StatNameText }   -- Pawn's, before UADD runs

for i = 1, N do
    local b = CreateFrame("Button", "PawnUIFrame_StatsList_Item" .. i, ui)
    local fs = b:CreateFontString()
    fs:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    b:SetFontString(fs)
end
local label = ui:CreateFontString("PawnUIFrame_StatNameLabel")
label:SetFont("Fonts\\FRIZQT__.TTF", 12, "")

function PawnUIFrame_StatsList_UpdateStatItem(i, index)
    local row, line = PawnStats[index], _G["PawnUIFrame_StatsList_Item" .. i]
    if not row[2] then
        line:SetText(row[1])
    elseif M.ignored[row[2]] then
        line:SetText("  " .. row[1] .. " " .. PawnLocal.Unusable)
    else
        line:SetText("  " .. row[1])
    end
end

function PawnUIFrame_StatsList_Update()
    for i = 1, N do PawnUIFrame_StatsList_UpdateStatItem(i, i) end
end

function PawnUIFrame_StatsList_SelectStat(index)
    local row = PawnStats[index]
    if not (row and row[2]) then index = 0 end
    PawnUICurrentStatIndex = index
    if index > 0 then
        label:SetText(row[5] or format(PawnLocal.StatNameText, row[1]))
    end
end

function PawnUI_ValuesTab_Refresh()
    PawnUIFrame_StatsList_Update()
    PawnUIFrame_StatsList_SelectStat(PawnUICurrentStatIndex)
end
ui:HookScript("OnShow", PawnUI_ValuesTab_Refresh)

-- The stand-in for UALL Forever: names[en] = Ukrainian; "later" = "not now" until M.later is false.
M.names, M.later, M.asked = {}, {}, {}
function M.stub()
    UADD.UALL.Text = function(en)
        M.asked[en] = (M.asked[en] or 0) + 1
        if M.later[en] then return nil, true end
        return M.names[en]
    end
end
function M.row(key)
    for i, row in ipairs(PawnStats) do if row[2] == key then return i, row end end
end
function M.header(en)
    for i, row in ipairs(PawnStats) do if row[2] == nil and row[1] == en then return i end end
end
function M.line(i) return _G["PawnUIFrame_StatsList_Item" .. i]:GetText() end
function M.label() return label:GetText() end
function M.rowName(i) return PawnStats[i][1] end
function M.select(i) PawnUIFrame_StatsList_SelectStat(i) end
function M.refresh() PawnUI_ValuesTab_Refresh() end
function M.close() ui:Hide() end
function M.english(path) return M.en[path] end
function M.ignore(key, yes) M.ignored[key] = yes or nil end
