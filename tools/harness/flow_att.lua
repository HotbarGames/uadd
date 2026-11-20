-- Lua helpers for flow_att.py, on the Attune stand-in (tools/harness/attune). Reached from Python as
-- HARNESS.att. Run before the game starts. It gives the harness what Attune's libraries need
-- (GameTooltipTemplate and OptionsListButtonTemplate parts, StaticPopup1..4 that StaticPopup_Show
-- fills, tooltip lines with real text), records what is sent to other players, and sets two traps:
--   * every hooksecurefunc wrapper is remembered;
--   * a field written by UADD code on a frame UADD did not make is a violation, and a function field
--     of such a frame that is no longer its first value (and no hooksecurefunc wrapper) is one too.
-- The expected Ukrainian is read from the module's ui tables (ns.UA, ns.UA_CATEGORY, the hashed tables, ns.UA_STEP_TYPE,
-- ns.UA_NOTES), never from Words.lua.
local H = HARNESS
local M = { violations = {}, first = {}, owner = setmetatable({}, { __mode = "k" }), sent = {},
    uallCalls = {}, uallReady = false, hookFrom = {} }
H.att = M
local wrappers = setmetatable({}, { __mode = "k" })

-- ── Traps ──────────────────────────────────────────────────────────────────────────────────────
local hsf = hooksecurefunc
function hooksecurefunc(a, b, c)
    local t, name = a, b
    if type(a) == "string" then t, name = _G, a end
    local src = debug.getinfo(2, "S").source or ""
    local who = src:match("^@AddOns/([^/]+)/") or "harness"
    M.hookFrom[who] = (M.hookFrom[who] or 0) + 1
    hsf(a, b, c)
    local w = rawget(t, name)
    if type(w) == "function" then wrappers[w] = true end
end

local function Maker()
    for level = 3, 40 do
        local info = debug.getinfo(level, "S")
        if not info then break end
        local addon = (info.source or ""):match("^@AddOns/([^/]+)/")
        if addon then return addon end
    end
    return "harness"
end
local newWidget = H.newWidget
function H.newWidget(...)
    local w = newWidget(...)
    M.owner[w] = Maker()
    return w
end

local mt = getmetatable(UIParent)
local function Label(w) return tostring(rawget(w, "__name") or rawget(w, "__type")) end
mt.__newindex = function(w, k, v)
    rawset(w, k, v)
    if type(k) ~= "string" or k:sub(1, 2) == "__" then return end
    local owner = M.owner[w] or "harness"
    local src = debug.getinfo(2, "S").source or ""
    if src:find("^@AddOns/UADD") and not owner:find("^UADD") then
        M.violations[#M.violations + 1] = Label(w) .. "." .. k .. " (" .. src .. ")"
    end
    if type(v) == "function" then
        M.first[w] = M.first[w] or {}
        if M.first[w][k] == nil then M.first[w][k] = v end
    end
end
for _, w in ipairs(H.widgets()) do
    for k, v in pairs(w) do
        if type(k) == "string" and type(v) == "function" then
            M.first[w] = M.first[w] or {}
            M.first[w][k] = v
        end
    end
end
-- Function fields of frames UADD did not make that are not their first value nor a wrapper.
function M.replaced()
    local out = {}
    for w, keys in pairs(M.first) do
        if not (M.owner[w] or "harness"):find("^UADD") then
            for k, v in pairs(keys) do
                local now = rawget(w, k)
                if now ~= v and not wrappers[now] then out[#out + 1] = Label(w) .. "." .. k end
            end
        end
    end
    table.sort(out)
    return table.concat(out, ", ")
end
function M.violated() return table.concat(M.violations, ", ") end

-- ── Tooltips with real lines ───────────────────────────────────────────────────────────────────
local function Lines(tip)
    local name = tip:GetName()
    for i = 1, 8 do
        for _, side in ipairs({ "Left", "Right" }) do
            local fs = rawget(_G, name .. "Text" .. side .. i) or tip:CreateFontString(name .. "Text" .. side .. i)
            fs:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
        end
    end
    local function Clear(self)
        for i = 1, 8 do _G[name .. "TextLeft" .. i]:SetText(nil) _G[name .. "TextRight" .. i]:SetText(nil) end
        self.__lines, self.__item = 0, nil
        local f = self:GetScript("OnTooltipCleared")
        if f then f(self) end
    end
    local function Add(self, l, r)
        self.__lines = (self.__lines or 0) + 1
        _G[name .. "TextLeft" .. self.__lines]:SetText(l)
        _G[name .. "TextRight" .. self.__lines]:SetText(r)
    end
    tip.ClearLines = Clear
    tip.SetOwner = function(self, owner) self.__owner = owner Clear(self) end
    tip.SetText = function(self, t) Clear(self) Add(self, t) end
    tip.AddLine = function(self, t) Add(self, t) end
    tip.AddDoubleLine = function(self, l, r) Add(self, l, r) end
    tip.SetHyperlink = function(self, link) Clear(self) self.__item = link Add(self, "Core Fragment") end
    tip.GetItem = function(self) if self.__item then return "Core Fragment", self.__item end end
end
Lines(GameTooltip)

local applyTemplate = H.applyTemplate
function H.applyTemplate(w, template)
    applyTemplate(w, template)
    if template == "GameTooltipTemplate" and w:GetName() then Lines(w) end
    if template == "OptionsListButtonTemplate" then
        w.toggle = CreateFrame("Button", nil, w)
        w.text = w:CreateFontString((w:GetName() or "") .. "Text", "OVERLAY", "GameFontNormalSmall")
        w:SetFontString(w.text)
    end
end

-- ── StaticPopup1..4, filled by StaticPopup_Show as the game does ───────────────────────────────
local pops = {}
M.pops = pops
for i = 1, 4 do
    local d = _G["StaticPopup" .. i]
    d.text = d:CreateFontString("StaticPopup" .. i .. "Text", "ARTWORK", "GameFontHighlight")
    d.text.GetHeight = function(self) local t = self:GetText() or "" return 12 * math.ceil(#t / 40) end
    for b = 1, 3 do
        local btn = CreateFrame("Button", "StaticPopup" .. i .. "Button" .. b, d)
        btn:GetFontString():SetFontObject(GameFontNormal)
        d["button" .. b] = btn
    end
    d.editBox = CreateFrame("EditBox", "StaticPopup" .. i .. "EditBox", d)
    d.editBox:SetAutoFocus(false)         -- the game's popup sets the focus itself
    d:Hide()
    pops[i] = d
end
function StaticPopup_Show(which, a1, a2, data)
    local info = StaticPopupDialogs[which]
    if not info then return end
    local d = pops[1]
    for _, p in ipairs(pops) do if p.which == which or not p:IsShown() then d = p break end end
    d.which, d.data = which, data
    d.text:SetText(info.text)
    for b = 1, 3 do d["button" .. b]:SetText(info["button" .. b]) d["button" .. b]:SetShown(info["button" .. b] ~= nil) end
    d.editBox:SetText("")
    d.editBox:SetShown(info.hasEditBox and true or false)
    d:Show()
    if info.OnShow then info.OnShow(d, data) end
    d:SetHeight(60 + d.text:GetHeight())
    return d
end
function StaticPopup_Hide(which) for _, p in ipairs(pops) do if p.which == which then p:Hide() end end end
function M.popupOf(which) for i, p in ipairs(pops) do if p.which == which and p:IsShown() then return i end end end
function M.popupHeight(i) return pops[i]:GetHeight() end
function M.accept(i) local p = pops[i] StaticPopupDialogs[p.which].OnAccept(p, p.data) p:Hide() end

-- ── What goes to other players ─────────────────────────────────────────────────────────────────
local scm = SendChatMessage
function SendChatMessage(msg, kind, ...) M.sent[#M.sent + 1] = "chat|" .. tostring(kind) .. "|" .. tostring(msg) return scm(msg, kind, ...) end
local sam = C_ChatInfo.SendAddonMessage
C_ChatInfo.SendAddonMessage = function(p, msg, kind, target)
    M.sent[#M.sent + 1] = "addon|" .. tostring(p) .. "|" .. tostring(kind) .. "|" .. tostring(target) .. "|" .. tostring(msg)
    return sam(p, msg, kind, target)
end
function M.sentAll() return table.concat(M.sent, "\n") end

-- ── UALL Forever, as UADD.UALL answers (a stand-in) ────────────────────────────────────────────
M.uall = {
    Quest = { ["Attunement to the Core"] = "Налаштування на Ядро", ["Warlord's Command"] = "Наказ воєводи" },
    Item = { ["Core Fragment"] = "Уламок Ядра" },
    Npc = { ["Highlord Omokk"] = "Верховний Лорд Омокк", ["Rexxar"] = "Рексар",
        ["Lothos Riftwaker"] = "Лотос Розривач", ["Warlord Goretooth"] = "Воєвода Ікластий" },
    Zone = { ["Blackrock Mountain"] = "Гора Чорної Скелі", ["Blackrock Depths"] = "Глибини Чорної Скелі",
        ["Badlands"] = "Безплідні Землі", ["Lower Blackrock Spire"] = "Нижній Шпиль Чорної Скелі",
        ["Desolace"] = "Пустоплин", ["Orgrimmar"] = "Оргриммар" },
    Text = { ["Molten Core"] = "Огняне Ядро", ["Onyxia's Lair"] = "Лігво Онікії", ["Ragefire Chasm"] = "Вогнелюта Безодня" },
}
function M.stubUall()
    local A = UADD.UALL
    A.IsAvailable = function() return M.uallReady end
    A.RouteOff = function() return false end
    A.RoutesOff = function() return "" end
    A.RULES = "harness"
    for _, kind in ipairs({ "Quest", "Item", "Npc", "Zone", "Text" }) do
        A[kind] = function(a, b)
            M.uallCalls[#M.uallCalls + 1] = H.combat and "combat" or "out"
            return M.uall[kind][kind == "Quest" and b or a]
        end
    end
end
function M.uallReadyNow(on) M.uallReady = on end
function M.uallIn(state) local n = 0 for _, s in ipairs(M.uallCalls) do if s == state then n = n + 1 end end return n end
function M.uk(kind, en) return M.uall[kind][en] end
