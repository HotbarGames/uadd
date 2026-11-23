-- Lua helpers for flow_gq.py, on the GearQuest Forever stand-in (tools/harness/gearquest). Reached from Python as
-- HARNESS.gq. Run before the game starts: the font objects its windows use. No English of GearQuest here: the
-- stand-in gets it from GearQuestStandInFeed and GearQuestStandInLocale (M.feed, built in flow_gq.py from the
-- installed addon). Item names are made up (M.stub, through UADD.UALL.Item, lesson 20).
local H = HARNESS
local M = {}
H.gq = M

local MOD = "UADD_GearQuestForever"
local CYR = "[\208-\211][\128-\191]"
local function S() return GearQuestStandIn end

-- The proof that a step has teeth: with M.cut set, one module file runs without one fix (in memory only).
local CUTS = {}
M.cut, M.wasCut = nil, false
function M.addCut(name, file, old, new) CUTS[name] = { file, old, new } end
local runFile = H.runFile
function H.runFile(addon, path, code)
    local c = M.cut and CUTS[M.cut]
    if addon == MOD and c and path == c[1] then
        local a, b = code:find(c[2], 1, true)
        if a then code, M.wasCut = code:sub(1, a - 1) .. c[3] .. code:sub(b + 1), true end
    end
    return runFile(addon, path, code)
end

for name, size in pairs({ GameFontNormal = 12, GameFontHighlight = 12, GameFontHighlightSmall = 10, QuestFont = 13,
                          GameFontNormalLarge = 16 }) do
    if not rawget(_G, name) then CreateFont(name):SetFont("Fonts\\FRIZQT__.TTF", size, "") end
end

-- Made-up items: one known, one ClassicUA has not settled yet (waits `slow` times), one unknown.
M.items = { names = {}, slow = 0, asked = 0 }
function M.stub(known, ua, slowName, slowUa, waits)
    local N = M.items
    N.names[known], N.slowName, N.slowUa, N.slow = ua, slowName, slowUa, waits
    UADD.UALL.Item = function(en)
        N.asked = N.asked + 1
        if en == N.slowName then
            if N.slow > 0 then N.slow = N.slow - 1 return nil, true end
            return N.slowUa
        end
        return N.names[en]
    end
end

function M.open() return S().Open() end
function M.late() S().Late() end
function M.guide(i) S().Guide(i) end
function M.orders(list) S().Orders(list) end
function M.hide(what)
    local f = what == "guide" and GearQuestGuideBubble or GearQuestOrdersPage
    if f then f:Hide() end
end
function M.nohunts(slot, preview)
    S().NoHunts(slot, preview)
    local c = H.chat
    return c[#c]
end
-- Its bubble fits the page shown now (as its Refresh sizes it).
function M.bubbleOk()
    local b = GearQuestGuideBubble
    local h = b.body:GetStringHeight() or 0
    if h < 20 then h = 84 end
    return b:GetHeight() == h + 40
end
-- Words it built once at load: its coloured source tag and a spec name.
function M.tag() return GearQuest:GetSourceTag("vendor") end
function M.spec() return GearQuest.Spec.CLASS_SPECS.WARRIOR[1].label end
function M.choices()
    local out = {}
    for i, o in ipairs(S().Choices()) do out[i] = o.value end
    return table.concat(out, ",")
end
function M.lang()
    local b = GearQuestLanguageButton
    return b and b:GetText() or ""
end

-- Its language button and list rows (for the font check only: the list has our entry only with the module).
local function LangTexts(out)
    local b = GearQuestLanguageButton
    if b then out["W:lang"] = b:GetFontString() end
    local menu = GearQuestLanguageMenu
    for i, row in ipairs(menu and menu.rows or {}) do out["W:langrow" .. i] = row.label end
    return out
end

-- Every text of its windows: W its main window (labels, option labels, tabs), L the late window, G the guide's
-- page, R the Orders rows shown (headers too: "asked by <name>", the name as the player typed it).
local function Texts(lang)
    local s, out = S(), {}
    if lang then LangTexts(out) end
    local W = s.W
    if W then
        for i, fs in ipairs(W.labels) do out["W:lbl" .. i] = fs end
        for i, fs in ipairs(W.opts) do out["W:opt" .. i] = fs end
        for i, b in ipairs(W.tabs) do out["W:tab" .. i] = b:GetFontString() end
    end
    for i, fs in ipairs(s.late or {}) do out["L:" .. i] = fs end
    local b = GearQuestGuideBubble
    if b and b:IsShown() then out["G:now"] = b.body end
    local page = GearQuestOrdersPage
    if page and page:IsShown() then
        for i, row in ipairs(page.rows) do if row:IsShown() then out["R:" .. i] = row.text end end
    end
    return out
end

function M.snap()
    local out = {}
    for k, fs in pairs(Texts()) do out[k] = fs:GetText() end
    out["T:tag"], out["T:spec"] = M.tag(), M.spec()
    return out
end

-- A text shows Cyrillic only on a Cyrillic face, and English only on its own (option labels aside: GearQuest asks
-- LocaleFontFace for them); and H.cyrBoxes over the whole screen.
function M.fonts()
    local bad = {}
    for k, fs in pairs(Texts(true)) do
        local t = fs:GetText() or ""
        local c, ours = t:find(CYR) ~= nil, UADD.IsCyrFont((fs:GetFont())) and true or false
        if c and not ours then bad[#bad + 1] = k .. " box: " .. t .. " (" .. tostring((fs:GetFont())) .. ")"
        elseif ours and not c and t ~= "" and not k:find("^W:opt") then
            bad[#bad + 1] = k .. " English on ours: " .. t
        end
    end
    local boxes = H.cyrBoxes(200)
    for _, l in pairs(type(boxes) == "table" and boxes or {}) do bad[#bad + 1] = "box " .. tostring(l) end
    return bad
end

function M.feed(code) assert((loadstring or load)(code))() end
function M.wait(seconds) for _ = 1, math.ceil(seconds / 0.05 - 1e-6) do H.step(0.05) end end
function M.uadd(msg) return H.call("/uadd " .. msg, SlashCmdList.UADD, msg) end
function M.key(down)
    H.keys.SHIFT = down
    H.fire("MODIFIER_STATE_CHANGED", "LSHIFT", down and 1 or 0)
    M.wait(0.4)                         -- UADD/Original.lua switches once the key is held a while
end
