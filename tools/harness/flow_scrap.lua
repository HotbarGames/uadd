-- Lua helpers for flow_scrap.py, on the Scrap stand-in (tools/harness/scrap). Reached from Python as
-- HARNESS.scrap. Run before the game starts. No English here: Scrap's words are in its own locale table
-- (run from the installed addon), and the few its settings code writes come from the flow (M.code).
local H = HARNESS
local M = {}
H.scrap = M

local CYR = "[\208-\210]"
local TEST = "\208\162\208\181\209\129\209\130"          -- a Cyrillic test word
local LINK = "|cff9d9d9d|Hitem:1::::::::::|h[Quix Blade]|h|r"
local GROUPS = { "Main", "Filters", "Help", "Credits" }
local BINDS = { "BINDING_NAME_SCRAP_TOGGLE", "BINDING_NAME_SCRAP_DESTROY_ONE", "BINDING_NAME_SCRAP_DESTROY_ALL",
    "BINDING_NAME_SCRAP_SELL" }
local function NS() return H.ns.UADD_Scrap end
local function S() return rawget(_G, "ScrapStandIn") end
local function L() return LibStub("AceLocale-3.0").apps["Scrap"] end
local function CT() return LibStub("CustomTutorials-2.1") end
local function Sushi() return LibStub("Sushi-3.2") end

function M.code(page, tutorial, community, join, item)
    ScrapStandInCode = { page = page, tutorial = tutorial, community = community, join = join }
    ScrapStandInItem = item
end

-- Test Ukrainian for the rows that stay English (chat lines with an item link), so taking STAY out shows.
M.data, M.used = {}, {}
function M.put(row, uk) M.data[row] = uk end
local watch = CreateFrame("Frame")
watch:RegisterEvent("ADDON_LOADED")
watch:SetScript("OnEvent", function(_, _, name)
    if name ~= "UADD_Scrap" then return end
    for row, uk in pairs(M.data) do
        if NS().AL[row] == nil then NS().AL[row] = uk M.used[#M.used + 1] = row end
    end
end)

-- GameTooltip's lines get their text.
local tip = GameTooltip
for i = 1, 8 do
    _G["GameTooltipTextLeft" .. i]:SetFontObject(i == 1 and GameTooltipHeaderText or GameTooltipText)  -- wow_fontfam.lua
    _G["GameTooltipTextRight" .. i]:SetFontObject(GameTooltipText)
end
local function Clear(self)
    for i = 1, 8 do _G["GameTooltipTextLeft" .. i]:SetText(nil) _G["GameTooltipTextRight" .. i]:SetText(nil) end
    self.__lines = 0
    local f = self:GetScript("OnTooltipCleared")
    if f then f(self) end
end
local function Add(self, l, r)
    self.__lines = (self.__lines or 0) + 1
    _G["GameTooltipTextLeft" .. self.__lines]:SetText(l)
    _G["GameTooltipTextRight" .. self.__lines]:SetText(r)
end
tip.ClearLines = Clear
tip.SetOwner = function(self, owner) self.__owner = owner Clear(self) end
tip.SetText = function(self, t) Clear(self) Add(self, t) end
tip.AddLine = function(self, t) Add(self, t) end
tip.GetItem = function() return nil end

-- ── Reading the game ──────────────────────────────────────────────────────────────────────────

-- The merchant button's tooltip: cursor (an item held), junk (it is junk), at a merchant.
local function MerchantTip(cursor, junk, merchant)
    local s = S()
    s.cursor, s.junk, s.merchant = cursor and 1 or nil, { junk }, merchant
    Scrap.Merchant:GetScript("OnEnter")(Scrap.Merchant)
    local t = GameTooltipTextLeft1:GetText()
    GameTooltip:Hide()
    s.cursor, s.merchant = nil, nil
    return t
end

-- Every word Scrap shows that UADD_Scrap may change, as a flat map. Keys: L locale rows, S rows and chat
-- lines that stay English, B binding names, R/G/N page rows (ours, the game's, names), V the junk list,
-- M the merchant tooltip, U the tutorial, P the pop-up, H money lines.
function M.snap()
    local out, s = {}, S()
    for k, v in pairs(L()) do
        if type(v) == "string" then out[(M.stay[k] and "S:" or "L:") .. k] = v end
    end
    for i, v in ipairs(rawget(L(), "FAQ") or {}) do out["L:FAQ." .. i] = v end
    for _, b in ipairs(BINDS) do out["B:" .. b] = rawget(_G, b) end
    local O = Scrap.Options
    for _, id in ipairs(O and GROUPS or {}) do
        local g = rawget(O, id)
        g:Show()
        out[(g.tagTitle or "R") .. ":" .. id .. ".name"] = g.category:GetName()
        for i, row in ipairs(g.rows) do
            out[row.tag .. ":" .. id .. "." .. i] = row:GetText()
            if row.tip then out[row.tag .. ":" .. id .. "." .. i .. ":tip"] = row.tip end
        end
        g:Hide()
    end
    local V = Scrap.Visualizer
    if V then
        out["V:tab1"], out["V:tab2"] = V.Tab1:GetText(), V.Tab2:GetText()
        out["V:forget"], out["V:toggle"] = V.ForgetButton:GetText(), V.ToggleButton:GetText()
        out["V:forget.w"], out["V:toggle.w"] = V.ForgetButton:GetWidth(), V.ToggleButton:GetWidth()
        for i, b in ipairs(V.items) do out["N:item." .. i] = b.Text:GetText() end
    end
    out["M:sell"], out["M:destroy"] = MerchantTip(false, false, true), MerchantTip(false, false, false)
    out["M:add"], out["M:remove"] = MerchantTip(true, false), MerchantTip(true, true)
    local f = CT().frames[Scrap.Tutorials]
    for i, step in ipairs(f.data) do out["U:" .. i] = step.text end
    Scrap.Tutorials:TriggerTutorial(2)
    out["U:shown"] = f.text:GetText()
    local p = s.Confirm()
    out["P:confirm"], out["G:popup.yes"], out["G:popup.no"] = p.Text:GetText(), p.Yes:GetText(), p.No:GetText()
    Sushi().Popup:Release(p)
    out["H:sold"], out["H:repair"], out["H:guild"] = s.Sold(12345), s.Repair(678), s.Repair(910, true)
    out["S:line.added"], out["S:line.removed"] = s.Toggle(LINK, false), s.Toggle(LINK, true)
    out["S:line.forgot"], out["S:line.destroyed"] = s.Forget(LINK), s.Destroy(LINK, 3)
    return out
end
M.stay = { Added = true, Removed = true, Forgotten = true, Destroyed = true }

-- A FontString shows Cyrillic exactly when our font is on it. (bad, n with ours, n on pages, n on the list)
function M.fonts()
    local bad, n, seen = {}, 0, {}
    local function walk(f)
        if type(f) ~= "table" or seen[f] or not f.GetObjectType then return 0 end
        seen[f] = true
        local c = 0
        if f:GetObjectType() == "FontString" then
            local t = f:GetText()
            if f:IsVisible() and t and t ~= "" then
                local cyr, ours = t:find(CYR) ~= nil, UADD.IsCyrFont((f:GetFont())) and true or false
                if ours then c = 1 end
                if cyr ~= ours then bad[#bad + 1] = t end
            end
            return c
        end
        for _, g in ipairs({ f:GetRegions() }) do c = c + walk(g) end
        for _, k in ipairs({ f:GetChildren() }) do c = c + walk(k) end
        return c
    end
    local pages, list = 0, 0
    for _, id in ipairs(GROUPS) do
        local g = rawget(Scrap.Options, id)
        g:Show()
        pages = pages + walk(g)
        g:Hide()
    end
    Scrap.Visualizer:Show()
    list = walk(Scrap.Visualizer)
    Scrap.Visualizer:Hide()
    Scrap.Tutorials:TriggerTutorial(3)
    n = pages + list + walk(CT().frames[Scrap.Tutorials])
    local p = S().Confirm()
    n = n + walk(p)
    Sushi().Popup:Release(p)
    S().cursor = 1
    Scrap.Merchant:GetScript("OnEnter")(Scrap.Merchant)
    n = n + walk(GameTooltip)
    GameTooltip:Hide()
    S().cursor = nil
    return bad, n, pages, list
end

-- Work the game-wide hooks do: (on a foreign tooltip and chat line, on the merchant button's tooltip).
function M.cheap()
    local ns, n = NS(), 0
    local W, A = ns.Swap, UADD.AceFont
    local t, e, p, set = W.Translate, W.English, UADD.Plain, A.Set
    local nl = rawget(GameTooltip, "NumLines")
    local function count(f) return function(...) n = n + 1 return f(...) end end
    W.Translate, W.English, UADD.Plain, A.Set = count(t), count(e), count(p), count(set)
    GameTooltip.NumLines = count(nl or GameTooltip.NumLines)
    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    GameTooltip:SetText(TEST .. " " .. TEST)
    GameTooltip:Show()
    GameTooltip:Hide()
    DEFAULT_CHAT_FRAME:AddMessage(TEST .. ", Quix")
    local foreign = n
    n = 0
    MerchantTip(false, false, true)
    local ours = n
    W.Translate, W.English, UADD.Plain, A.Set = t, e, p, set
    rawset(GameTooltip, "NumLines", nl)
    return foreign, ours
end

-- The line Scrap builds from one locale row with these values (the half-line check).
function M.line(row, ...) return S().Line(row:sub(3), ...) end

function M.want(row) return NS().AL[row] end
function M.count() return NS().Swap.Count() + NS().Screen.Count() end
function M.fontCount() return NS().Fonts.Count() end
function M.key(down)
    H.keys.SHIFT = down
    H.fire("MODIFIER_STATE_CHANGED", "LSHIFT", down and 1 or 0)
    M.wait(0.4)                         -- UADD/Original.lua switches once the key is held a while
end
function M.wait(seconds) for _ = 1, math.ceil(seconds / 0.05 - 1e-6) do H.step(0.05) end end
function M.uadd(msg) return H.call("/uadd " .. msg, SlashCmdList.UADD, msg) end
