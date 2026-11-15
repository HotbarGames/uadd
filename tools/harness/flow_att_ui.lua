-- More Lua helpers for flow_att.py (run after flow_att.lua, before the game starts): deep snapshots
-- of Attune's tables, reading what a window shows, doing what a player does, and the module's
-- own counters. Reached from Python as HARNESS.att.
local H = HARNESS
local M = H.att
local pops = M.pops

-- ── Deep snapshots (sorted keys, raw) ──────────────────────────────────────────────────────────
local function Ser(v, out, seen)
    local t = type(v)
    if t == "string" then out[#out + 1] = string.format("%q", v) return end
    if t ~= "table" then out[#out + 1] = t == "function" and "<fn>" or tostring(v) return end
    if seen[v] then out[#out + 1] = "<loop>" return end
    seen[v] = true
    local keys = {}
    for k in next, v do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        if type(a) ~= type(b) then return type(a) < type(b) end
        if type(a) == "string" or type(a) == "number" then return a < b end
        return tostring(a) < tostring(b)
    end)
    out[#out + 1] = "{"
    for _, k in ipairs(keys) do Ser(k, out, seen) out[#out + 1] = "=" Ser(rawget(v, k), out, seen) out[#out + 1] = "," end
    out[#out + 1] = "}"
    seen[v] = nil
end
function M.snap(name) local out = {} Ser(rawget(_G, name), out, {}) return table.concat(out) end

-- ── Reading what is shown ──────────────────────────────────────────────────────────────────────
local function SI() return rawget(_G, "AttuneStandIn") end
local function NS() return H.ns.UADD_Attune end
local TIPS = { tip = "GameTooltip", giver = "AttuneGiverTip", ldb = "LibDBIconTooltip", acd = "AceConfigDialogTooltip" }
local function TreeButton(value)
    for i = 1, 60 do
        local b = rawget(_G, "AceGUI30TreeButton" .. i)
        if b and b:IsShown() and rawget(b, "value") == value then return b end
    end
end
-- A FontString by kind: title, status, survey, node (step id), type (step id), tree (value), next
-- (row), nextTitle, results (head1/head2/row), reward (title/line), detail (title/sub/giver/body),
-- sync, menu (guild/char), tip/giver/ldb/acd (line, side), popup (n, text/button1/button2/editBox).
local function Find(kind, a, b)
    local s = SI()
    if kind == "title" then return s.frame.titletext end
    if kind == "status" then return s.frame.statustext end
    if kind == "survey" then return s.survey.frame:GetFontString() end
    if kind == "node" then return rawget(_G, "Attune_Title_" .. a) end
    if kind == "type" then return rawget(_G, "Attune_Type_" .. a) end
    if kind == "tree" then local btn = TreeButton(a) return btn and btn.text end
    if kind == "next" then local r = Attune_NextFrame.rows[a] return r and r.text end
    if kind == "nextTitle" then return s.nextTitle end
    if kind == "results" then return Attune_ResultsFrame[a] end
    if kind == "reward" then return AttuneQuestRewardFrame[a] end
    if kind == "detail" then return s.detail[a] end
    if kind == "sync" then return s.sync.text end
    if kind == "menu" then return a == "guild" and s.menuGuild or s.menuChar end
    if TIPS[kind] then return rawget(_G, TIPS[kind] .. "Text" .. (b or "Left") .. a) end
    if kind == "popup" then
        local p = pops[a]
        if b == "text" then return p.text end
        if b == "editBox" then return p.editBox end
        return p[b]:GetFontString()
    end
end
function M.text(...) local fs = Find(...) return fs and fs:GetText() end
function M.font(...) local fs = Find(...) if fs then return fs:GetFont() end end
function M.size(...) local fs = Find(...) return fs:GetWidth(), fs:GetHeight() end
function M.nodeSize(sid) local n = _G["Attune_Node_" .. sid] return n:GetWidth(), n:GetHeight() end
function M.hooked(...) return NS().Texts.Hooked(Find(...)) end

-- Every shown FontString text under a frame (shown in it: its parents may be hidden) (edit boxes skipped), in a stable order.
function M.shownTexts(f)
    local out = {}
    local function Walk(x, depth)
        if depth > 30 or not x:IsShown() or x:IsObjectType("EditBox") then return end
        for _, g in ipairs({ x:GetRegions() }) do
            if g:GetObjectType() == "FontString" and g:IsShown() and g:GetText() and g:GetText() ~= "" then
                out[#out + 1] = g:GetText()
            end
        end
        for _, c in ipairs({ x:GetChildren() }) do Walk(c, depth + 1) end
    end
    if type(f) == "string" then f = rawget(_G, f) end
    if f then Walk(f, 0) end
    table.sort(out)
    return table.concat(out, "\001")
end
local function Settings() return LibStub("AceConfigDialog-3.0").BlizOptions["Attune"]["Attune"] end
function M.settingsTexts() return M.shownTexts(Settings().frame) end
function M.tipTexts(kind)
    local out = {}
    for i = 1, 8 do local t = _G[TIPS[kind] .. "TextLeft" .. i]:GetText() if t then out[#out + 1] = t end end
    return table.concat(out, "\001")
end

-- ── What we expect ─────────────────────────────────────────────────────────────────────────────
-- A table kept by hash (data/hashed.lua): its entry for the text `s`.
local function Hashed(t, s) return t and t[#s .. ":" .. UADD.Hash(s)] end
function M.ua(key)
    local v = NS().UA[key] or Hashed(NS().UA_KEYHASH, key)
    return type(v) == "string" and (v:gsub("\\n", "\n")) or nil
end
-- A shown label: a category's value (or its sentence case), else English from Attune's code (by hash).
function M.uaText(en)
    for key, uk in pairs(NS().UA_CATEGORY) do
        local v = rawget(AttuneLang, key)
        if v == en or (v and (v:lower():gsub("^%l", string.upper)) == en) then return uk end
    end
    return Hashed(NS().UA_TEXTHASH, en)
end
function M.stepType(t) return NS().UA_STEP_TYPE[t] end
function M.note(key) local v = NS().UA_NOTES[key] return type(v) == "string" and (v:gsub("\\n", "\n")) or nil end
function M.lang(key) return rawget(AttuneLang, key) end
function M.typeOf(aid, sid)
    for _, s in ipairs(Attune_Data.steps) do if s.ID_ATTUNE == aid and s.ID == sid then return s.TYPE end end
end

-- ── Doing things ───────────────────────────────────────────────────────────────────────────────
function M.open()
    Attune_Frame()
    SI().tree.treeframe:SetHeight(500)       -- the game lays the tree out; the harness has no layout
    SI().tree:RefreshTree()
end
function M.expand(value)
    local b = TreeButton(value)
    if b and b.toggle:IsShown() ~= false then b.toggle:GetScript("OnClick")(b.toggle) end
    return b ~= nil
end
function M.click(value) local b = TreeButton(value) if b then b:GetScript("OnClick")(b, "LeftButton") end return b ~= nil end
function M.select(id) Attune_Select(id) end
function M.hover(sid) local n = _G["Attune_Node_" .. sid] n:GetScript("OnEnter")(n) end
function M.leave(sid) local n = _G["Attune_Node_" .. sid] n:GetScript("OnLeave")(n) end
function M.hoverRow(i) local r = Attune_NextFrame.rows[i] r:GetScript("OnEnter")(r) end
function M.surveyEnter() SI().survey:Fire("OnEnter") end
function M.ldbHover()
    local b = _G["LibDBIcon10_Attune_Broker"]
    b:GetScript("OnEnter")(b)
end
function M.ldbLeave() local b = _G["LibDBIcon10_Attune_Broker"] b:GetScript("OnLeave")(b) end
function M.settings(tab)
    local w = Settings()
    InterfaceOptionsFrame:Show()            -- the game's options window: the page is visible in it
    w.frame:Hide()
    w.frame:Show()
    if tab then rawget(w, "children")[1]:SelectTab(tab) end
end
function M.settingsEnter()
    local function Find1(w)
        if rawget(w, "type") == "CheckBox" then return w end
        for _, c in ipairs(rawget(w, "children") or {}) do local x = Find1(c) if x then return x end end
    end
    Find1(Settings()):Fire("OnEnter")
end
function M.settingsHide() Settings().frame:Hide() InterfaceOptionsFrame:Hide() end
function M.si(k) return SI()[k] end
function M.call(name, ...) return _G[name](...) end
function M.siCall(name, ...) return SI()[name](...) end
function M.lastViewed() return AttuneLastViewed end
function M.chat(n) return H.chat[#H.chat - (n or 1) + 1] end
function M.slash(msg) return H.call("/attune " .. msg, SlashCmdList.ACECONSOLE_ATTUNE, msg) end
function M.bags(n) for _ = 1, n do H.fire("BAG_UPDATE", 0) end end
function M.refreshes() return SI().refreshes or 0 end
function M.selects() return SI().selects end

-- ── The module's own counters and switches ─────────────────────────────────────────────────────
function M.memo() return NS().Words.MemoSize() end
function M.hookCalls() return NS().Texts.HookCalls() end
function M.textCount() return NS().Texts.Count() end
function M.fontCount() return NS().Fonts.Count() end
function M.tipCount() return NS().Tooltip.Count() end
function M.popCount() return NS().Popup.Count() end
function M.installed() return NS().Screen.Installed() end
function M.chatActive() return NS().Chat.Active() end
function M.chatPutBack() return getprinthandler() == H.GamePrint and rawget(DEFAULT_CHAT_FRAME, "AddMessage") == nil end
function M.hooksBy(addon) return M.hookFrom[addon] or 0 end
function M.combat(on) H.combat = on H.fire(on and "PLAYER_REGEN_DISABLED" or "PLAYER_REGEN_ENABLED") end
function M.key(down) H.keys.SHIFT = down H.fire("MODIFIER_STATE_CHANGED", "LSHIFT", down and 1 or 0) end
function M.wait(seconds) for _ = 1, math.ceil(seconds / 0.05 - 1e-6) do H.step(0.05) end end
function M.uadd(msg) return H.call("/uadd " .. msg, SlashCmdList.UADD, msg) end
function M.ms(fn, n) local t0 = debugprofilestop() for _ = 1, n do fn() end return (debugprofilestop() - t0) / n end
function M.selectCost(n) return M.ms(function() Attune_Select("20") end, n) end
function M.bagCost(n) return M.ms(function() H.fire("BAG_UPDATE", 0) end, n) end
