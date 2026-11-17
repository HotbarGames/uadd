-- Lua helpers for flow_fxpb.py, on the ForeverXP Bar stand-in (tools/harness/foreverxpbar).
-- Reached from Python as HARNESS.fxpb. Run before the game starts: it lets the stand-in's own font
-- file load, gives GameTooltip's lines text and a font (the harness only counts lines), and holds the
-- seed: a few test translations for texts data/words.lua does not translate (flow_fxpb.py hashes them).
local H = HARNESS
local M = {}
H.fxpb = M
H.fontFiles["interface\\addons\\foreverxpbar\\fonts\\bignoodletoo.ttf"] = true

local function S() return rawget(_G, "ForeverXPbarStandIn") end
local function NS() return H.ns.UADD_ForeverXPBar end

-- Test translations only, keyed by the stand-in's English. flow_fxpb.py puts our real wording in
-- for each text data/words.lua translates; the checks then expect that.
M.SEED = {
    ["Lock Bar"] = "Закріпити панель",
    ["Options"] = "Налаштування",
    ["Leveling info"] = "Про рівні",
    ["Kills to level"] = "Вбивств до рівня",
    ["Flight travel"] = "Політ",
    ["ForeverXP Bar - Record"] = "ForeverXP Bar - рекорд",
    ["Time this level: %s"] = "Час на цьому рівні: %s",
    ["%s XP/Hour"] = "%s досвіду/год",
    ["Leveling in: %s (%s)"] = "Новий рівень через: %s (%s)",
    ["-- XP/Hour"] = "-- досвіду/год",
    ["Left-click: settings"] = "Ліва кнопка: налаштування",
    ["Right-click: lock/unlock bar"] = "Права кнопка: закріпити панель",
    ["ForeverXP Bar - Level %s"] = "ForeverXP Bar - рівень %s",
    ["position and size reset."] = "положення й розмір скинуто.",
    ["+%d level%s since you started"] = "+%d рів.%s від початку",   -- slot 2: the English "s", blanked
    ["Race created: %s | Code: %s. Share the code with friends."] =
        "Перегони створено: %s | Код: %s. Поділіться кодом із друзями.",
    ["I understand"] = "Зрозуміло",
    ["Optional challenges, races, leaderboards, level-up cards and Played records."] = "Виклики й перегони.",
    ["ForeverXP Bar: the minimap icon setting changed.\n\nReload the UI now to apply and save it?"] =
        "ForeverXP Bar: кнопку на мінікарті змінено.\n\nПерезавантажити інтерфейс зараз?",
    ["Reload UI"] = "Перезавантажити",
    ["Later"] = "Пізніше",
    ["Race goal received: reach level %s%s."] = "Мета перегонів: рівень %s%s.",              -- two templates
    ["Race goal received: reach level %s by %s."] = "Мета перегонів: рівень %s до %s.",     -- for one text
}

-- The client: SetFontObject also gives a FontString its font object's justify (here: CENTER).
local W = H.Widget
local setObject = W.SetFontObject
W.SetJustifyH = function(self, j) rawset(self, "__jh", j) end
W.GetJustifyH = function(self) return rawget(self, "__jh") or "CENTER" end
W.SetFontObject = function(self, o) setObject(self, o) rawset(self, "__jh", nil) end

-- StaticPopup1 as the game has it: a text and two buttons that StaticPopup_Show fills from
-- StaticPopupDialogs (the harness's own StaticPopup_Show does nothing). Its text is 12 high per
-- 40 bytes, and the dialog 60 + that.
local pop = StaticPopup1
pop.text = pop:CreateFontString("StaticPopup1Text", "ARTWORK", "GameFontHighlight")
pop.text.GetHeight = function(self) local t = self:GetText() or "" return 12 * math.ceil(#t / 40) end
for i = 1, 2 do
    local b = CreateFrame("Button", "StaticPopup1Button" .. i, pop)
    b:GetFontString():SetFontObject(GameFontNormal)
    pop["button" .. i] = b
end
function StaticPopup_Show(which)
    local info = StaticPopupDialogs[which]
    if not info then return end
    pop.which = which
    pop.text:SetText(info.text)
    pop.button1:SetText(info.button1)
    pop.button2:SetText(info.button2)
    pop:SetHeight(60 + pop.text:GetHeight())
    pop:Show()
    return pop
end
function StaticPopup_Hide(which) if pop.which == which then pop:Hide() end end

-- GameTooltip's lines get their text (AddLine and friends only count lines in the harness).
local tip = GameTooltip
for i = 1, 8 do
    _G["GameTooltipTextLeft" .. i]:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    _G["GameTooltipTextRight" .. i]:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
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
tip.AddDoubleLine = function(self, l, r) Add(self, l, r) end

-- The word tables built again with the seed's hashed texts (`src`: a Lua chunk from flow_fxpb.py that
-- returns { exact = .., templates = .. }) over data/words.lua, then a look.
function M.seed(src)
    local ns = NS()
    ns.Words.Build(assert(loadstring(src))())
    ns.Screen.Scan()
    return ns.Words.Count()
end

function M.text(name) return S().texts[name]:GetText() end
function M.font(name) return S().texts[name]:GetFont() end
function M.shown(name) return S().texts[name]:IsVisible() end
function M.stale(name) return NS().Texts.Stale(S().texts[name]) end
function M.hooked(name) return NS().Texts.Hooked(S().texts[name]) end
function M.uk(en) return NS().Words.Text(en) end
function M.memo() return NS().Words.MemoSize() end
function M.hookCalls() return NS().Texts.HookCalls() end
function M.fontCount() return NS().Fonts.Count() end
function M.extras() return #NS().Screen.Extras() end
function M.tipLine(i, side) return _G["GameTooltipText" .. (side or "Left") .. i]:GetText() end
function M.tipFont(i) return (_G["GameTooltipTextLeft" .. i]:GetFont()) end
function M.tipCount() return NS().Tooltip.Count() end

-- n bar updates; returns the milliseconds they took.
function M.ticks(n, from)
    local t0 = debugprofilestop()
    for i = from or 1, (from or 1) + n - 1 do S().Tick(i) end
    return debugprofilestop() - t0
end
function M.tick(i) S().Tick(i) end
function M.under(done, rest) S().Under(done, rest) end
function M.camp(t) S().Camp(t) end

-- What the bar should show after tick i, in English (its own) and with the seed (ours).
function M.want(i, mode)
    local function Short(v) return v >= 1000 and ("%.1fK"):format(v / 1000) or tostring(v) end
    local rate = (i % 50 == 0) and "-- XP/Hour" or ("%s XP/Hour"):format(Short(20000 + i * 13))
    local left = ("Leveling in: %s (%s)"):format(("%dh %02dm"):format(i % 5, i % 60), rate)
    if mode == "uk" then   -- the time in Ukrainian too (Time.lua): "4 год 03 хв"
        local r = (i % 50 == 0) and M.SEED["-- XP/Hour"] or M.SEED["%s XP/Hour"]:format(Short(20000 + i * 13))
        left = M.SEED["Leveling in: %s (%s)"]:format(("%d год %02d хв"):format(i % 5, i % 60), r)
        rate = r
    end
    return rate, left
end

function M.hover() S().Hover() end
function M.leave() S().Leave() end
function M.hoverRep(short) S().HoverRep(short) end
-- The same tooltip text, owned by a frame that is not ForeverXP Bar's.
function M.hoverOther()
    GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
    GameTooltip:SetText("Left-click: settings")
    GameTooltip:Show()
end

function M.print(msg) S().printMsg(msg) end
function M.lastChat() return H.chat[#H.chat] end
function M.send() return S().Send() end
function M.readBack() return S().ReadBack() end
function M.sent(i) local s = S().sent[i] return s and s[1], s and s[2] end
function M.chatPutBack() return rawget(DEFAULT_CHAT_FRAME, "AddMessage") == nil end

function M.options(show) if show then S().OpenOptions() else S().CloseOptions() end end
function M.tab(show) S().Tab(show) end
function M.record(show) S().Record(show) end
function M.page(show) S().Page(show) end

function M.perf()
    for _, p in pairs(UADD.originalPerf or {}) do
        if p.name == "ForeverXP Bar" then return p.down, p.up end
    end
end

function M.combat(on)
    H.combat = on
    if not on then H.fire("PLAYER_REGEN_ENABLED") end
end
function M.key(down)
    H.keys.SHIFT = down
    H.fire("MODIFIER_STATE_CHANGED", "LSHIFT", down and 1 or 0)
end
function M.wait(seconds) for _ = 1, math.ceil(seconds / 0.05 - 1e-6) do H.step(0.05) end end
function M.uadd(msg) return H.call("/uadd " .. msg, SlashCmdList.UADD, msg) end
function M.standIn() return S() ~= nil end

function M.show(what, on) S().Show(what, on) end
function M.isExtra(name)
    local fs = S().texts[name]
    local f = fs and fs:GetParent()
    for _, e in ipairs(NS().Screen.Extras()) do
        if e == f or (f and e == f:GetParent()) then return true end
    end
    return false
end
function M.setText(name, t) S().texts[name]:SetText(t) end
function M.justify(name) return S().texts[name]:GetJustifyH() end
function M.askReload() S().AskReload() end
function M.popup(part)
    if part == "text" then return StaticPopup1.text:GetText(), (StaticPopup1.text:GetFont()) end
    if part == "height" then return StaticPopup1:GetHeight(), 60 + StaticPopup1.text:GetHeight() end
    local fs = StaticPopup1[part]:GetFontString()
    return fs:GetText(), (fs:GetFont())
end
function M.popupHide() StaticPopup_Hide("FOREVERXPBAR_RELOAD_UI") end
-- The same FontString key for two texts in a row (its hint), as a bar text that changes.
local keys = {}
function M.ukAt(key, en) keys[key] = keys[key] or {} return NS().Words.Text(en, keys[key]) end
function M.quick(en, key) return NS().Words.Quick(en, key and keys[key]) end
