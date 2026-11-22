-- Lua helpers for flow_bs.py, on the BugSack stand-in (tools/harness/bugsack). Reached from Python as HARNESS.bs.
-- Run before the game starts: StaticPopup1..4 that format their text as the game does, GameTooltip lines that get
-- their text, and the font objects and game word its window uses. No English of BugSack here: the stand-in gets it
-- from BugSackStandInFeed (M.feed, built in flow_bs.py from the installed addon).
local H = HARNESS
local M = {}
H.bs = M

local MOD, POPUP = "UADD_BugSack", "BugSackSendBugs"
local CYR = "[\208-\211][\128-\191]"
local function NS() return H.ns[MOD] end
local function S() return BugSackStandIn end

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

-- ── What its window needs from the game ──────────────────────────────────────────────────────
OPTIONS = rawget(_G, "OPTIONS") or "Options"
for name, size in pairs({ GameFontNormalLeft = 12, GameFontHighlightLeft = 12, GameFontDisable = 12 }) do
    if not rawget(_G, name) then CreateFont(name):SetFont("Fonts\\FRIZQT__.TTF", size, "") end
end

-- ── The game's popups (as flow_wql.lua) ──────────────────────────────────────────────────────
local pops = {}
for i = 1, 4 do
    local d = _G["StaticPopup" .. i]
    if not rawget(d, "button1") then
        d.text = d:CreateFontString("StaticPopup" .. i .. "Text", "ARTWORK", "GameFontHighlight")
        for b = 1, 4 do
            local btn = CreateFrame("Button", "StaticPopup" .. i .. "Button" .. b, d)
            btn:GetFontString():SetFontObject(GameFontNormal)
            d["button" .. b] = btn
        end
    end
    d:Hide()
    pops[i] = d
end
function StaticPopup_Show(which, a1, a2, data)
    local info = StaticPopupDialogs[which]
    if not info then return end
    local d = pops[1]
    for _, p in ipairs(pops) do if p.which == which or not p:IsShown() then d = p break end end
    d.which = which
    d.text:SetText(string.format(info.text, a1 or "", a2 or ""))
    for b = 1, 4 do d["button" .. b]:SetText(info["button" .. b]) end
    d:Show()
    if info.OnShow then info.OnShow(d, data) end
    return d
end
function StaticPopup_Hide(which) for _, p in ipairs(pops) do if p.which == which then p:Hide() end end end

-- ── GameTooltip's lines get their text (as flow_auc.lua) ─────────────────────────────────────
local tip = GameTooltip
for i = 1, 8 do
    _G["GameTooltipTextLeft" .. i]:SetFontObject(i == 1 and GameTooltipHeaderText or GameTooltipText)
    _G["GameTooltipTextRight" .. i]:SetFontObject(GameTooltipText)
end
local function Clear(self)
    for i = 1, 8 do _G["GameTooltipTextLeft" .. i]:SetText(nil) _G["GameTooltipTextRight" .. i]:SetText(nil) end
    self.__lines = 0
end
tip.ClearLines = Clear
tip.SetOwner = function(self, owner) self.__owner = owner Clear(self) end
tip.AddLine = function(self, l)
    self.__lines = (self.__lines or 0) + 1
    _G["GameTooltipTextLeft" .. self.__lines]:SetText(l)
end

-- ── Reading back ─────────────────────────────────────────────────────────────────────────────
-- The mouse over f and away: the tooltip's lines while it was over.
local function Hover(f)
    local out = {}
    f:GetScript("OnEnter")(f)
    for i = 1, math.min(tip:NumLines() or 0, 8) do out[i] = _G["GameTooltipTextLeft" .. i]:GetText() end
    local leave = f:GetScript("OnLeave")
    if leave then leave(f) end
    return out
end

function M.open() H.call("BugSack:OpenSack", BugSack.OpenSack, BugSack) end
function M.popup()
    StaticPopup_Hide(POPUP)
    local d = S().Send()
    if not d then return nil end
    local t, b1, b2 = d.text:GetText(), d.button1:GetText(), d.button2:GetText()
    return t, b1, b2
end
function M.session(kind, word, name)
    local s = S()
    s.Session({ kind = kind, word = word, name = name })
    local t = s.W.session:GetText()
    s.Session({ kind = "today" })
    return t
end

-- Everything a player can read: S the session label and its tooltip, W the window's labels, WT the wipe button's
-- tooltip, X the text area, O and T each option and its tooltip, R the menu labels, F the filter box, P the popup.
function M.snap()
    local s = S()
    local W = s.W
    local out = {}
    s.Session({ kind = "today" })
    s.Bugs(0)
    out["S:sess"] = W.session:GetText()
    for j, t in ipairs(Hover(W.session)) do out["S:tip" .. j] = t end
    out["W:filter"] = W.filterLabel:GetText()
    for k, b in pairs(W.buttons) do out["W:" .. k] = b:GetText() end
    for i, t in ipairs(W.tabs) do out["W:tab" .. i] = t.Text:GetText() end
    for j, t in ipairs(Hover(W.buttons.wipe)) do out["WT:" .. j] = t end
    out["X:text"] = W.text:GetText()
    for i, c in ipairs(W.checks) do
        out["O:" .. i] = c.Text:GetText()
        for j, t in ipairs(Hover(c)) do out["T:" .. i .. ":" .. j] = t end
    end
    for i, r in ipairs(W.rows) do out["R:" .. i] = r:GetText() end
    out["F:filter"] = W.filter:GetText()
    out["P:text"], out["P:b1"], out["P:b2"] = M.popup()
    StaticPopup_Hide(POPUP)
    return out
end

-- A text shows Cyrillic exactly when our font is on it: each label, the text area, the popup; and H.cyrBoxes.
function M.fonts()
    local s = S()
    local W = s.W
    local bad = {}
    local function one(where, fs)
        local t = fs:GetText() or ""
        local c, ours = t:find(CYR) ~= nil, UADD.IsCyrFont((fs:GetFont())) and true or false
        if c ~= ours then bad[#bad + 1] = where .. ": " .. t .. " (" .. tostring((fs:GetFont())) .. ")" end
    end
    one("session", W.session:GetFontString())
    one("filter", W.filterLabel)
    for k, b in pairs(W.buttons) do one(k, b:GetFontString()) end
    for i, t in ipairs(W.tabs) do one("tab" .. i, t.Text) end
    for i, c in ipairs(W.checks) do one("O:" .. i, c.Text) end
    for i, r in ipairs(W.rows) do one("R:" .. i, r) end
    one("text", W.text)
    local d = s.Send()
    if d then one("P:text", d.text) one("P:b1", d.button1:GetFontString()) one("P:b2", d.button2:GetFontString()) end
    local boxes = H.cyrBoxes(200)
    if type(boxes) == "string" then boxes = { boxes } end
    for _, l in pairs(type(boxes) == "table" and boxes or {}) do bad[#bad + 1] = "box " .. tostring(l) end
    StaticPopup_Hide(POPUP)
    return bad
end

function M.press() S().Press() end
function M.fontSize(name) S().FontSize(_G[name]) end
function M.bugs(n) S().Bugs(n) return S().W.text:GetText(), S().ERR end
function M.typed()                  -- the player types the filter label's own text in the filter box
    local W = S().W
    W.filter:SetText(W.filterLabel:GetText())
    return W.filter:GetText()
end

function M.shown() return NS().Shown() end
function M.saved()
    local n = 0
    for _ in pairs(NS().saved) do n = n + 1 end
    return n
end
function M.feed(code) assert((loadstring or load)(code))() end
function M.wait(seconds) for _ = 1, math.ceil(seconds / 0.05 - 1e-6) do H.step(0.05) end end
function M.uadd(msg) return H.call("/uadd " .. msg, SlashCmdList.UADD, msg) end
function M.key(down)
    H.keys.SHIFT = down
    H.fire("MODIFIER_STATE_CHANGED", "LSHIFT", down and 1 or 0)
    M.wait(0.4)                         -- UADD/Original.lua switches once the key is held a while
end
