-- Harness stand-in for BugSack: not the addon. Same globals, frame kinds and SetText calls as its sack window, its
-- options and its send popup; every English text comes at run time from BugSackStandInFeed (tools/harness/flow_bs.py).
-- S.Session(st)   the session label for st = {kind = "today"|"num"|"options"|"local"|"date"|"sent", word, name}
-- S.Line(st)      the text it would set for st (its English)
-- S.Bugs(n)       the text area: an error text (n > 0) or its "no bugs" line
-- S.FontSize(o)   the player's font size choice: the text area's font object
-- S.Send()        its send popup through StaticPopup_Show
-- S.Press()       each button off and on, the mouse over it and away
-- S.W             the window's parts (made on the first BugSack:OpenSack)
local addonName = "BugSack"
local F = BugSackStandInFeed or { L = {}, role = {}, win = {}, tips = { session = {}, wipe = {} }, opts = {}, rows = {} }
local A = {}
_G.BugSack = A
local L = {}
for k, v in pairs(F.L) do L[k] = v end
A.L = L
local R = F.role
BugGrabber = BugGrabber or { GetSessionId = function() return 7 end }

-- Read once at load, as its sack file does.
local sourceFormat, localFormat = L[R.sent] or "%s %s", L[R.loc] or "%s"
local sessionFormat = "%s - |cffff4411%s|r - |cff44ff44%d|r"

StaticPopupDialogs = StaticPopupDialogs or {}
StaticPopupDialogs.BugSackSendBugs = { text = L[R.pop] or "%d", button1 = L[R.send], button2 = CLOSE,
    hasEditBox = true, timeout = 0 }

local S = { st = { kind = "today" }, bugs = 0 }
BugSackStandIn = S
S.ERR = "Interface/AddOns/Gizmo/Gizmo.lua:12: attempt to index a nil value"
local W

function S.Line(st)
    local k = st.kind
    if k == "options" then return addonName .. " " .. OPTIONS end
    if k == "today" then return ("%s (%d)"):format(L[R.today], BugGrabber:GetSessionId()) end
    if k == "num" then return ("%d"):format(5) end
    local src
    if k == "sent" then src = sourceFormat:format(st.name or "Zorp", st.word or F.word)
    else src = localFormat:format(st.word or F.word) end
    local d = k == "date" and "2026/11/22 13:14:15" or "13:14:15 PM"
    return sessionFormat:format(d, src, 3)
end

-- A button whose label changes font object with its state, as the game's buttons do.
local function States(b, normal, highlight, disabled)
    local fs = b:GetFontString()
    b.__nfo, b.__hfo, b.__dfo = normal, highlight, disabled
    b.SetNormalFontObject = function(self, o) self.__nfo = o if not self.__off then fs:SetFontObject(o) end end
    b.SetHighlightFontObject = function(self, o) self.__hfo = o end
    b.SetDisabledFontObject = function(self, o) self.__dfo = o if self.__off then fs:SetFontObject(o) end end
    local en, dis = b.Enable, b.Disable
    b.Enable = function(self) en(self) self.__off = false fs:SetFontObject(self.__nfo) end
    b.Disable = function(self) dis(self) self.__off = true fs:SetFontObject(self.__dfo) end
    -- Native in the game: it goes through no Lua Enable, Disable or SetFontObject (hooks never see it).
    local raw = fs.SetFontObject
    b.SetEnabled = function(self, on)
        if on then en(self) else dis(self) end
        self.__off = not on
        raw(fs, on and self.__nfo or self.__dfo)
    end
    fs:SetFontObject(normal)
end

local function Tip(owner, lines)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    for i, t in ipairs(lines) do
        if i == 1 then GameTooltip:AddLine(t) else GameTooltip:AddLine(t, 1, 1, 1, 1) end
    end
    GameTooltip:Show()
end
local function Leave() GameTooltip:Hide() end

local function Build()
    local w = CreateFrame("Frame", "BugSackFrame", UIParent)
    w:SetPoint("CENTER")
    W = { frame = w, buttons = {}, tabs = {}, checks = {}, rows = {} }
    S.W = W
    local tc = CreateFrame("Frame", nil, w)
    tc:SetPoint("TOP")
    w.TitleContainer = tc

    local s = CreateFrame("Button", nil, tc)
    s:SetPoint("LEFT")
    States(s, GameFontNormalLeft, GameFontHighlightLeft, GameFontDisable)
    s:SetScript("OnEnter", function(self)
        local lines = { addonName }
        for _, k in ipairs(F.tips.session) do lines[#lines + 1] = L[k] end
        Tip(self, lines)
    end)
    s:SetScript("OnLeave", Leave)
    W.session = s

    local lab = tc:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    lab:SetPoint("RIGHT")
    lab:SetText(L[F.win.filter] .. ":")
    W.filterLabel = lab
    local box = CreateFrame("EditBox", nil, tc)
    box:SetAutoFocus(false)
    box:SetFontObject(GameFontHighlightSmall)
    box:ClearFocus()
    W.filter = box

    for i, name in ipairs({ "next", "prev", "send", "wipe" }) do
        local b = CreateFrame("Button", "BugSack" .. name:sub(1, 1):upper() .. name:sub(2) .. "Button", w)
        b:SetPoint("BOTTOM")
        States(b, GameFontNormal, GameFontHighlight, GameFontDisable)
        b:SetText(L[F.win.buttons[i]])
        b:SetScript("OnEnter", function(self) self:GetFontString():SetFontObject(self.__hfo) end)
        b:SetScript("OnLeave", function(self) self:GetFontString():SetFontObject(self.__off and self.__dfo or self.__nfo) end)
        W.buttons[name] = b
    end
    W.buttons.wipe:HookScript("OnEnter", function(self)
        local lines = {}
        for _, k in ipairs(F.tips.wipe) do lines[#lines + 1] = L[k] end
        Tip(self, lines)
    end)
    W.buttons.wipe:HookScript("OnLeave", Leave)

    for i, name in ipairs({ "All", "Session", "Last" }) do
        local t = CreateFrame("Button", "BugSackTab" .. name, w)
        t:SetPoint("BOTTOMLEFT")
        t.Text = t:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
        t.Text:SetText(L[F.win.tabs[i]])
        W.tabs[i] = t
    end

    local sf = CreateFrame("ScrollFrame", "BugSackScroll", w)
    sf:SetPoint("CENTER")
    local ta = CreateFrame("EditBox", "BugSackScrollText", sf)
    ta:SetAutoFocus(false)
    ta:SetFontObject(GameFontHighlightSmall)
    ta:ClearFocus()
    W.text = ta

    local o = CreateFrame("Frame", nil, w)
    o:SetPoint("RIGHT")
    for i, p in ipairs(F.opts) do
        local label, tip = L[p[1]], L[p[2]]          -- kept in the closure, as its options do
        local c = CreateFrame("CheckButton", nil, o)
        c:SetPoint("TOPLEFT")
        c.Text = c:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        c.Text:SetText(label)
        c:SetScript("OnEnter", function(self) Tip(self, { label, tip }) end)
        c:SetScript("OnLeave", Leave)
        W.checks[i] = c
    end
    for i, k in ipairs(F.rows) do
        local fs = o:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        fs:SetText(L[k])
        W.rows[i] = fs
    end
end

local function Update()
    W.session:SetText(S.Line(S.st))
    W.text:SetText(S.bugs > 0 and S.ERR or L[R.nobugs])
end

function A:OpenSack()
    if W and W.frame:IsShown() then return end
    if not W then Build() end
    Update()
    W.frame:Show()
end
function A:OpenConfig()
    S.st = { kind = "options" }
    if W and W.frame:IsShown() then Update() return end
    A:OpenSack()
end

function S.Session(st) S.st = st W.session:SetText(S.Line(st)) end
function S.Bugs(n) S.bugs = n W.text:SetText(n > 0 and S.ERR or L[R.nobugs]) end
function S.FontSize(o) W.text:SetFontObject(o) end
function S.Send() return StaticPopup_Show("BugSackSendBugs", BugGrabber:GetSessionId()) end
function S.Press()
    for _, b in pairs(W.buttons) do
        b:Disable()
        b:Enable()
        b:GetScript("OnEnter")(b)
        b:GetScript("OnLeave")(b)
        b:SetEnabled(false) -- last, with no hover after it, as the sack's Options tab does
        b:SetEnabled(true)
    end
end
