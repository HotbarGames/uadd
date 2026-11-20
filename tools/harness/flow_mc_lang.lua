-- Lua helpers for flow_mc_lang.py: «Українська» in Mastercraft's language menu, on the menu stand-in
-- (tools/harness/mastercraft/Lang.lua). Reached from Python as HARNESS.mcl. Run before the game starts,
-- after flow_mastercraft.lua (its shared-metatable patch lets Screen.lua find the font strings).
local H = HARNESS
local M = {}
H.mcl = M

local CYR = "[\208-\210]"
local function S() return rawget(_G, "MastercraftLangStandIn") end
local function NS() return H.ns.UADD_Mastercraft end
local function Wait(n) for _ = 1, n do H.step(0.05) end end

local texts = {}
function M.text(t) texts[#texts + 1] = t end

-- Mastercraft's window, first opened: codes "en,de" (its rows), shape "" or one of Lang.lua's.
function M.build(codes, shape)
    local list = {}
    for c in codes:gmatch("[^,]+") do list[#list + 1] = c end
    S().Build({ texts = texts, codes = list, shape = shape ~= "" and shape or nil })
    Wait(4)                                     -- Find.lua looks at new frames on the next frame
end

function M.on() return NS().On() == true end
function M.choice() return tostring(NS().db.choice) end
function M.lang() return tostring(MastercraftDB.settings.lang) end
function M.lastWrite() local w = S().writes return tostring(w[#w]) end
function M.writes() return table.concat(S().writes, ",") end
function M.code() return S().lang.code:GetText() or "" end
function M.height() return S().lang.menu:GetHeight() end
function M.extra() return #S().Extra() end
function M.entry() return NS().Lang.Entry() ~= nil end
function M.shown(i) return S().texts[i]:GetText() or "" end
function M.count() return #S().texts end

-- Cyrillic anywhere on Mastercraft's own strings or its button (our menu row aside).
function M.cyr()
    local n = 0
    for _, fs in ipairs(S().texts) do if (fs:GetText() or ""):find(CYR) then n = n + 1 end end
    if M.code():find(CYR) then n = n + 1 end
    return n
end

-- The menu opened: (our tick shown, its English row's tick shown, the tick of row `code` shown).
function M.ticks(code)
    local menu = S().lang.menu
    if not menu:IsShown() then S().Click(S().lang) end
    local e = NS().Lang.Entry()
    local ours = e and e.tick and e.tick:IsShown() or false
    local en = S().Row("en").tick:IsShown()
    local other = code and S().Row(code) and S().Row(code).tick:IsShown() or false
    S().Click(S().lang)                         -- closed again
    return ours and true or false, en and true or false, other and true or false
end

-- A row picked as the player does it: the button, then the row (PreClick, OnClick, PostClick).
function M.pick(code)
    if not S().lang.menu:IsShown() then S().Click(S().lang) end
    local w
    if code == "uk" then w = NS().Lang.Entry() else w = S().Row(code) end
    if w then S().Click(w) else S().Click(S().lang) end   -- no such row: the menu closed again
    Wait(2)
end

-- Mastercraft's strings that still have UADD's Cyrillic font.
function M.cyrFont()
    local n = 0
    for _, fs in ipairs(S().texts) do if UADD.IsCyrFont((fs:GetFont())) then n = n + 1 end end
    return n
end

function M.setLanguage(code) S().SetLanguage(code) Wait(2) end
function M.saveOnly(code) S().SaveOnly(code) end
function M.uadd(msg) return H.call("/uadd " .. msg, SlashCmdList.UADD, msg) end
