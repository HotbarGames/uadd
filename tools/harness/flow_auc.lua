-- Lua helpers for flow_auc.py, on the Auctionator stand-in (tools/harness/auctionator).
-- Reached from Python as HARNESS.auc. Run before the game starts: it lets the stand-in's own font
-- file load, gives StaticPopup1 and GameTooltip's lines real text (the harness only counts lines),
-- and puts in a small Menu API (Menu.GetManager) whose open menu has FontStrings.
-- The expected Ukrainian is read from the module's data (ns.UA, ns.UA_MADE, ns.UA_TEXT), never from
-- Words.lua, so a wrong answer there shows up here.
local H = HARNESS
local M = {}
H.auc = M
H.fontFiles["interface\\addons\\auctionator\\fonts\\standin.ttf"] = true

local function S() return rawget(_G, "AuctionatorStandIn") end
local function NS() return H.ns.UADD_Auctionator end

-- StaticPopup1 as the game has it: a text and three buttons that StaticPopup_Show fills from
-- StaticPopupDialogs (the harness's own StaticPopup_Show does nothing). Its text is 12 high per
-- 40 bytes, and the dialog 60 + that.
local pop = StaticPopup1
pop.text = pop:CreateFontString("StaticPopup1Text", "ARTWORK", "GameFontHighlight")
pop.text.GetHeight = function(self) local t = self:GetText() or "" return 12 * math.ceil(#t / 40) end
for i = 1, 3 do
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
    pop.button3:SetText(info.button3)
    pop:SetHeight(60 + pop.text:GetHeight())
    pop:Show()
    return pop
end
function StaticPopup_Hide(which) if pop.which == which then pop:Hide() end end

-- GameTooltip's lines get their text (AddLine and friends only count lines in the harness).
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
    if self.__secret then                       -- like the client in combat: the lines are secret
        if l then H.secret[l] = true end
        if r then H.secret[r] = true end
    end
    _G["GameTooltipTextLeft" .. self.__lines]:SetText(l)
    _G["GameTooltipTextRight" .. self.__lines]:SetText(r)
end
tip.ClearLines = Clear
tip.SetOwner = function(self, owner) self.__owner = owner Clear(self) end
tip.SetText = function(self, t) Clear(self) Add(self, t) end
tip.AddLine = function(self, t) Add(self, t) end
tip.AddDoubleLine = function(self, l, r) Add(self, l, r) end

-- The game's menu manager (Menu.GetManager): an open menu is a frame of FontStrings, reused by every
-- menu (the game pools them), shown after its rows are filled.
local menu = CreateFrame("Frame", "HarnessAucMenu", UIParent)
menu:Hide()
menu.rows = {}
local manager = {}
function manager:OpenContextMenu(owner, texts)
    menu:Hide()
    for i, t in ipairs(texts) do
        menu.rows[i] = menu.rows[i] or menu:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        menu.rows[i]:SetText(t)
        menu.rows[i]:Show()
    end
    for i = #texts + 1, #menu.rows do menu.rows[i]:Hide() end
    menu.owner = owner
    menu:Show()
end
manager.OpenMenu = manager.OpenContextMenu
function manager:GetOpenMenu() return menu:IsShown() and menu or nil end
Menu = { GetManager = function() return manager end }
function M.menuHide() menu:Hide() end

-- ── Reading what is shown ───────────────────────────────────────────────────────────────────────
-- A FontString by kind: text (stand-in key), header (key), cell (list, row, column), dialog
-- (n, "text" / "acceptButton" / "cancelButton"), popup ("text" / "button1" / "button2"),
-- tip (line, "Left" / "Right"), menu (row), group (bag group n: its title).
local function Find(kind, a, b, c)
    local s = S()
    if kind == "text" then return s.texts[a] end
    if kind == "header" then return s.headers[a] and s.headers[a]:GetFontString() end
    if kind == "cell" then
        local r = s.lists[a].rows[b]
        return r and (r.cells[c].text or r.cells[c].Text)
    end
    if kind == "group" then return s.groups[a] and s.groups[a].GroupTitle:GetFontString() end
    if kind == "dialog" then
        local d = rawget(_G, "AuctionatorDialog" .. a)
        if not d then return nil end
        return b == "text" and d.text or d[b]:GetFontString()
    end
    if kind == "popup" then return a == "text" and pop.text or pop[a]:GetFontString() end
    if kind == "tip" then return _G["GameTooltipText" .. (b or "Left") .. a] end
    if kind == "menu" then return menu.rows[a] end
end
function M.text(...) local fs = Find(...) return fs and fs:GetText() end
function M.font(...) local fs = Find(...) if fs then return fs:GetFont() end end
function M.shown(...) local fs = Find(...) return fs ~= nil and fs:IsVisible() end
function M.hooked(...) return NS().Texts.Hooked(Find(...)) end
function M.rowsMade(list) return #S().lists[list].rows end

-- ── What we expect ─────────────────────────────────────────────────────────────────────────────
-- One key's Ukrainian as ui/locale.lua has it (a written \n is a break).
function M.ua(key)
    local uk = NS().UA[key]
    if type(uk) ~= "string" then return nil end
    return (uk:gsub("\\n", "\n"))
end
local function G(k) return rawget(_G, "AUCTIONATOR_L_" .. k) end
-- The English of a ns.UA_MADE entry, made here on its own (not by Words.lua).
local function MadeEN(m)
    if m.join then return G(m.join[1]) and G(m.join[2]) and G(m.join[1]) .. " " .. G(m.join[2]) end
    local v = G(m.key)
    return v and (string.gsub(v, m.from, m.to))
end
-- The Ukrainian of an exact English text: the first key (sorted by name) whose AUCTIONATOR_L_ global
-- has that English and that has a Ukrainian of its own, else a ns.UA_MADE text, else ui/text.lua's
-- entry for its hash.
function M.ukOf(en)
    local ns, keys = NS(), {}
    for k in pairs(ns.UA) do if G(k) == en then keys[#keys + 1] = k end end
    table.sort(keys)
    for _, k in ipairs(keys) do
        local uk = M.ua(k)
        if uk and uk ~= "" and uk ~= en then return uk end
    end
    for _, m in ipairs(ns.UA_MADE or {}) do
        if MadeEN(m) == en then return m.uk end
    end
    return ns.UA_TEXT and ns.UA_TEXT.exact[#en .. ":" .. UADD.Hash(en)]
end
-- The stand-in's English by key, for flow_auc.py to hold against the installed Auctionator.
function M.standInEN() return S().EN end
-- Every AUCTIONATOR_L_* global still the stand-in's English.
function M.globalsSame()
    for k, v in pairs(S().EN) do
        if rawget(_G, "AUCTIONATOR_L_" .. k) ~= v then return false end
    end
    return true
end
function M.money(c) return S().Money(c) end
function M.link() return S().LINK end
function M.uk(en) return NS().Words.Text(en) end
-- A key's English, and a column header's short form (ui/locale.lua ns.UA_HEAD).
function M.en(key) return G(key) end
function M.head(key) local v = (NS().UA_HEAD or {})[key] return type(v) == "string" and v or nil end

-- ── Doing things ───────────────────────────────────────────────────────────────────────────────
function M.ah(open) H.fire(open and "AUCTION_HOUSE_SHOW" or "AUCTION_HOUSE_CLOSED") end

local ITEMS = { "Linen Cloth", "Wool Cloth", "Silk Cloth", "Mageweave Cloth", "Copper Ore", "Tin Ore",
    "Peacebloom", "Silverleaf" }
function M.item(i) return ITEMS[(i - 1) % #ITEMS + 1] end
-- n rows in the shopping results; even rows are owned ("Yes").
function M.results(n)
    local data = {}
    for i = 1, n do data[i] = { name = M.item(i), isOwned = (i % 2 == 0) and AUCTIONATOR_L_UNDERCUT_YES or "" } end
    S().ShowResults("shop", data)
end
-- The item history: Tuesday 25 February 2025, and today.
function M.history()
    local tue = time({ year = 2025, month = 2, day = 25, hour = 12 })
    local U = Auctionator.Utilities
    S().ShowResults("history", { { date = U.PrettyDate(tue), price = S().Money(12345) },
        { date = U.PrettyDate(time()), price = S().Money(678) } })
end
function M.header(key, name) S().Header(S().lists.shop.HeaderContainer, key, name) end
function M.total(onSale, pending) S().Total(onSale, pending) end
function M.posted(q, unit) S().Posted(q, unit) end
-- Auctionator's own dialogs (Dialogs.lua of the stand-in): the name of the one that showed.
function M.dialog()
    Auctionator.Dialogs.ShowConfirm(AUCTIONATOR_L_CONFIRM_UNHIDE_ALL, ACCEPT, CANCEL)
    return S().DialogOf("confirm"):GetName()
end
function M.cancelWithBid(copper) S().CancelWithBid(copper) return S().DialogOf("money"):GetName() end
function M.dialogHide(n) _G["AuctionatorDialog" .. n]:Hide() end
function M.dialogHooks() return NS().Screen.DialogHooks() end
-- The commodity purchase dialogs (key: the dialog's name in the buy panel, also its text's key).
function M.buy(key, quantity, unit, increased) S().Buy(key, quantity, unit, increased) end
function M.buyHide(key) S().BuyHide(key) end
function M.buyShow(key) S().BuyShow(key) end
function M.postedBid(bid, buyout) S().PostedBid(bid, buyout) end
-- A buy panel made late; its rows filled while it is not one of the module's windows.
function M.latePanel() S().LatePanel() end
function M.lateShow() AuctionatorBuyItemFrame:Show() end
function M.lateResults(n)
    local data = {}
    for i = 1, n do data[i] = { name = M.item(i), isOwned = (i % 2 == 0) and AUCTIONATOR_L_UNDERCUT_YES or "" } end
    S().ShowResults("late", data)
end
-- A chat line that is not Auctionator's.
function M.printOther(...) print(...) end
function M.confirmPost() S().ConfirmPost() end
function M.popupHide() StaticPopup_Hide("AUCTIONATOR_SELLING_CONFIRM_POST") end
function M.tooltip(days) S().Tooltip(days) end
function M.tooltipHide() GameTooltip:Hide() end
-- Tooltip lines the client marks secret (combat). Off: every string plain again.
function M.secretTips(on) GameTooltip.__secret = on or nil H.Secret(on) end
function M.lastError() return UADD.lastError end
function M.clearError() UADD.lastError = nil end
function M.columnMenu() S().ColumnMenu() end
function M.help() return H.call("/atr help", SlashCmdList.AUCTIONATOR, "help") end
function M.readBack() return S().ReadBack() end
function M.chat(n) return H.chat[#H.chat - (n or 1) + 1] end

-- A burst of redraws: `passes` times new data for `rows` rows. Returns the milliseconds it took,
-- the SetText hook calls and the cell SetText calls in it.
function M.burst(rows, passes)
    local s, ns = S(), NS()
    local data = {}
    local calls0, set0 = ns.Texts.HookCalls(), s.setTexts
    local t0 = debugprofilestop()
    for p = 1, passes do
        for i = 1, rows do
            data[i] = { name = M.item(i + p), isOwned = ((i + p) % 3 == 0) and AUCTIONATOR_L_UNDERCUT_YES or "" }
        end
        s.ShowResults("shop", data)
    end
    local ms = debugprofilestop() - t0
    return ms, ns.Texts.HookCalls() - calls0, s.setTexts - set0
end

-- ── The module's own counters ──────────────────────────────────────────────────────────────────
function M.memo() return NS().Words.MemoSize() end
function M.hookCalls() return NS().Texts.HookCalls() end
function M.rows() return NS().Rows.Count() end
function M.textCount() return NS().Texts.Count() end
function M.fontCount() return NS().Fonts.Count() end
function M.tipCount() return NS().Tooltip.Count() end
function M.populateSame() return AuctionatorCellMixin.Populate == S().origPopulate end
function M.chatActive() return NS().Chat.Active() end
-- The game's own print handler back, and no field written on the chat frame.
function M.chatPutBack()
    return getprinthandler() == H.GamePrint and rawget(DEFAULT_CHAT_FRAME, "AddMessage") == nil
end
-- Milliseconds per Words.Text call on n texts never seen before (each one a memo miss):
-- "uk": the money dialog's text (two pieces joined by a blank line, both found); "en": two
-- English pieces joined by a blank line that we have no words for; "line": one such line.
function M.missCost(n, kind)
    local W, s = NS().Words, S()
    local t0 = debugprofilestop()
    for i = 1, n do
        local t
        if kind == "uk" then t = AUCTIONATOR_L_BID_EXISTING_ON_OWNED_AUCTION .. "\n\n" .. s.Money(i * 10101)
        elseif kind == "en" then t = "Note number " .. i .. " from a friend\n\nRead it later, number " .. i
        else t = "Note number " .. i .. " from a friend, read it later" end
        W.Text(t)
    end
    return (debugprofilestop() - t0) / n
end
function M.standIn() return S() ~= nil end

function M.combat(on)
    H.combat = on
    H.fire(on and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED")
end
function M.key(down)
    H.keys.SHIFT = down
    H.fire("MODIFIER_STATE_CHANGED", "LSHIFT", down and 1 or 0)
end
function M.wait(seconds) for _ = 1, math.ceil(seconds / 0.05 - 1e-6) do H.step(0.05) end end
function M.uadd(msg) return H.call("/uadd " .. msg, SlashCmdList.UADD, msg) end
