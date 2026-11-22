-- Lua helpers for flow_dci.py, on the DeleteCheapestItem Reloaded stand-in (tools/harness/deletecheapestitem).
-- Reached from Python as HARNESS.dci. Run before the game starts: it gives the harness what the addon's frames need
-- (tooltip lines on every GameTooltip, StaticPopup1..4 that format their text, the game's globals it reads). No
-- English of the addon here: the stand-in gets it at run time (M.feed).
local H = HARNESS
local M = {}
H.dci = M

local CYR = "[\208-\210]"
local ZORP = "\208\151\208\190\209\128\208\191"            -- a made-up Ukrainian game name
M.ITEM, M.OTHER = "Zorp Shard", "Quix Gizmo"              -- one UALL Forever "knows", one it does not

local function NS() return H.ns.UADD_DeleteCheapestItem end
local function S() return DCIStandIn end

-- ── What the harness lacks ───────────────────────────────────────────────────────────────────
-- The game's words the addon reads (Blizzard's globals, not the addon's), where the harness has none.
for k, v in pairs({ YES = "Yes", NO = "No", NEVER = "Never", DELETE = "Delete", ITEM_BIND_QUEST = "Quest Item",
    DELETE_ITEM = "Delete %s?" }) do
    if rawget(_G, k) == nil then _G[k] = v end
end

-- Every tooltip has its lines and fills them (GameTooltip now, DCI_SecondTooltip when the addon makes it).
local function Tipify(tip, name)
    for i = 1, 8 do
        for _, side in ipairs({ "Left", "Right" }) do
            local n = name .. "Text" .. side .. i
            if not rawget(_G, n) then tip:CreateFontString(n) end
            _G[n]:SetFontObject(i == 1 and side == "Left" and GameTooltipHeaderText or GameTooltipText)
        end
    end
    local function Clear(self)
        for i = 1, 8 do _G[name .. "TextLeft" .. i]:SetText(nil) _G[name .. "TextRight" .. i]:SetText(nil) end
        self.__lines = 0
        local f = self:GetScript("OnTooltipCleared")
        if f then f(self) end
    end
    local function Add(self, l, r)
        self.__lines = math.min((self.__lines or 0) + 1, 8)
        _G[name .. "TextLeft" .. self.__lines]:SetText(l)
        _G[name .. "TextRight" .. self.__lines]:SetText(r)
    end
    tip.ClearLines = Clear
    tip.SetOwner = function(self, owner) self.__owner = owner Clear(self) end
    tip.GetOwner = function(self) return self.__owner end
    tip.NumLines = function(self) return self.__lines or 0 end
    tip.SetText = function(self, t) Clear(self) Add(self, t) end
    tip.AddLine = function(self, t) Add(self, t) end
    tip.AddDoubleLine = function(self, l, r) Add(self, l, r) end
end
Tipify(GameTooltip, "GameTooltip")
local create = CreateFrame
CreateFrame = function(kind, name, ...)
    local f = create(kind, name, ...)
    if kind == "GameTooltip" and type(name) == "string" then Tipify(f, name)
    elseif kind ~= "GameTooltip" then rawset(f, "AddLine", false) end   -- as in the game: only a tooltip has it
    return f
end

-- StaticPopup1..4: a text and buttons; StaticPopup_Show formats the text with its two arguments, as the game does.
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
function StaticPopup_Show(which, a1, a2)
    local info = StaticPopupDialogs[which]
    if not info then return end
    local d = pops[1]
    for _, p in ipairs(pops) do if p.which == which or not p:IsShown() then d = p break end end
    d.which = which
    d.text:SetText(string.format(info.text, a1 or "", a2 or ""))
    for b = 1, 4 do d["button" .. b]:SetText(info["button" .. b]) end
    d:Show()
    return d
end
function StaticPopup_Hide(which) for _, p in ipairs(pops) do if p.which == which then p:Hide() end end end

-- Hooks put in place, counted (lesson 37: off must re-install none on its own redraw).
local hook = hooksecurefunc
M.hooks = 0
hooksecurefunc = function(...) M.hooks = M.hooks + 1 return hook(...) end

-- The minimap button the tooltip of the Broker launcher belongs to (LibDBIcon names it after the addon).
local mini = CreateFrame("Button", "LibDBIcon10_DeleteCheapestItem", Minimap or UIParent)

-- ── Helpers ──────────────────────────────────────────────────────────────────────────────────
function M.feed(code) assert((loadstring or load)(code))() end
function M.wait(seconds) for _ = 1, math.ceil(seconds / 0.05 - 1e-6) do H.step(0.05) end end
function M.uadd(msg) return H.call("/uadd " .. msg, SlashCmdList.UADD, msg) end
function M.key(down)
    H.keys.SHIFT = down
    H.fire("MODIFIER_STATE_CHANGED", "LSHIFT", down and 1 or 0)
    M.wait(0.4)
end
function M.stand() return S() end
function M.on() return NS().On() and true or false end
function M.last() return H.chat[#H.chat] end

-- UALL Forever's item route knows M.ITEM (patched on UADD.UALL, never on the root: lesson 20).
function M.uall()
    local A = UADD.UALL
    local item = A.Item
    A.Item = function(n, ...) if n == M.ITEM then return ZORP end return item and item(n, ...) end
end
function M.link(name, id) return "|cff1eff00|Hitem:" .. (id or 4711) .. "::::::::60:::::|h[" .. name .. "]|h|r" end

local function Item(name, id) return { name = name, link = M.link(name, id), quality = 2, count = 3, vendor = 12345,
    auction = 20000, id = id } end
M.STATE = { mode = "bags", items = { Item(M.ITEM, 4711), Item(M.OTHER, 4712) }, free = 3 }
M.IGNORED = { { id = 4712, name = M.OTHER }, { id = 4713 } }

local function T(fs) return fs and fs:GetText() or nil end
local function Lines(out, tip, name, tag)
    for i = 1, tip:NumLines() do
        out[tag .. i .. "L"] = T(_G[name .. "TextLeft" .. i])
        out[tag .. i .. "R"] = T(_G[name .. "TextRight" .. i])
    end
end

-- Every text the module may change, each drawn again now. T top and title, R rows, I the ignored list, C the
-- settings page, D its dropdowns, P the profile picker, G the info tooltip, B the minimap tooltip, X the second
-- tooltip, H chat lines, Q the profile popup. The windows get one frame for their walk (U.OnNewFrame, OnShow).
function M.snap(st)
    local s, out = S(), {}
    s.Open(st or M.STATE)
    s.OpenIgnored(M.IGNORED)
    s.OpenConfig()
    M.wait(0.1)
    out["T:title"], out["T:1"], out["T:2"] = T(DCI_TitleText), T(DCI_TopSection_Text1), T(DCI_TopSection_Text2)
    for i = 1, 2 do
        local r = s.Rows[i]
        for _, k in ipairs({ "TopLeft", "TopRight", "BottomLeft", "BottomRight" }) do out["R" .. i .. ":" .. k] = T(r[k]) end
        out["R" .. i .. ":delete"], out["R" .. i .. ":count"] = r.delete:GetText(), T(r.count)
    end
    local f = DCI_IgnoredItemsFrame
    out["I:title"], out["I:empty"], out["I:reset"] = T(f.title), T(f.empty), f.reset:GetText()
    for i, row in ipairs(f.rows) do out["I:label" .. i], out["I:remove" .. i] = T(row.label), row.remove:GetText() end
    for k, v in pairs(s.ConfigTexts()) do out["C:" .. k] = v end
    for name, d in pairs(_G) do
        if type(name) == "string" and name:find("^DCI_Config_Dropdown_") and type(d) == "table" and rawget(d, "Text") then
            out["D:" .. name] = T(d.Text)
        end
    end
    out["P:select"] = T(rawget(s.pSelect, "Text"))
    s.Tip()
    Lines(out, GameTooltip, "GameTooltip", "G:")
    GameTooltip:SetOwner(mini)
    s.Broker(GameTooltip)
    Lines(out, GameTooltip, "GameTooltip", "B:")
    GameTooltip:Hide()
    s.RowTip(1, "delete")
    out["X:delete"] = T(DCI_SecondTooltipTextLeft1)
    s.RowTip(1, "icon")
    out["X:icon"] = T(DCI_SecondTooltipTextLeft1)
    GameTooltip:Hide()
    s.Chat("ignore", M.link(M.ITEM)) out["H:ignore"] = M.last()
    s.Chat("reset") out["H:reset"] = M.last()
    s.Chat("delete", M.link(M.ITEM)) out["H:delete"] = M.last()
    for _, a in ipairs({ "copy", "reset", "delete" }) do
        local d = s.ProfilePopup(a, "Alpha", "Beta")
        out["Q:" .. a] = d and T(d.text)
        if a == "copy" and d then out["Q:yes"], out["Q:no"] = d.button1:GetText(), d.button2:GetText() end
        StaticPopup_Hide("DCI_PROFILE_ACTION")
    end
    return out
end

-- The fixed-width buttons' font sizes (lesson 5): rows' delete buttons, the ignored list's two, the page's.
function M.sizes()
    local s, out = S(), {}
    local function Size(k, b) if b then local _, n = b:GetFontString():GetFont() out[k] = n end end
    Size("delete", s.Rows[1].delete)
    Size("reset", DCI_IgnoredItemsFrame and DCI_IgnoredItemsFrame.reset)
    Size("remove", DCI_IgnoredItemsFrame and DCI_IgnoredItemsFrame.rows[1] and DCI_IgnoredItemsFrame.rows[1].remove)
    Size("create", rawget(_G, "DCI_ProfileCreate"))
    for name, b in pairs(_G) do
        if type(name) == "string" and name:find("^DCI_Config_Button_") then Size(name, b) end
    end
    return out
end

-- A text shows Cyrillic exactly when our font is on it, over its windows' texts: (bad texts, n with ours).
function M.fonts()
    local list, bad, n = {}, {}, 0
    for _, w in ipairs(H.widgets()) do
        if w.__type == "FontString" and w ~= M.boomFs and w:IsVisible() then
            local p, mine = w, false
            while p and not mine do mine = type(p.__name) == "string" and p.__name:find("^DCI_") p = p.__parent end
            if mine then list[#list + 1] = w end
        end
    end
    for _, fs in ipairs(list) do
        local t = fs:GetText() or ""
        local cyr, ours = t:find(CYR) ~= nil, UADD.IsCyrFont((fs:GetFont())) and true or false
        if ours then n = n + 1 end
        if cyr and not ours then bad[#bad + 1] = t end
    end
    return bad, n
end

-- Work the tooltip hook does on GameTooltip lines whose owner is not the addon's: Translate calls, cache growth.
function M.cheap()
    local W, n = NS().Words, 0
    local t = W.Translate
    local size = W.CacheSize()
    W.Translate = function(...) n = n + 1 return t(...) end
    GameTooltip:SetOwner(UIParent)
    GameTooltip:AddLine("Quix Zorp gizmo")
    S().Broker(GameTooltip)
    GameTooltip:Show()
    local out = {}
    Lines(out, GameTooltip, "GameTooltip", "")
    GameTooltip:Hide()
    W.Translate = t
    return n, W.CacheSize() - size, out
end

-- n errors in its window's hooks: a text under DCIFrame whose translation throws n times (inside OnSet).
local BOOM = "Harness boom text"
function M.fault(n)
    if not M.boomFs then
        local W = NS().Words
        local tr = W.Translate
        W.Translate = function(t, ...)
            if t == BOOM and (M.boom or 0) > 0 then M.boom = M.boom - 1 error("harness: a broken text") end
            return tr(t, ...)
        end
        M.boomFs = DCIFrame:CreateFontString("DCI_HarnessBoom")
    end
    M.boom = n
end
function M.poke() if M.boomFs then M.boomFs:SetText(BOOM) M.boomFs:SetText(nil) end end
function M.reopen()
    DCIFrame:Hide()
    S().Open(M.STATE)
    M.wait(0.1)
end

-- Every chat line "/uadd msg" printed, joined.
function M.said(msg)
    local from, out = #H.chat, {}
    M.uadd(msg)
    for i = from + 1, #H.chat do out[#out + 1] = tostring(H.chat[i]) end
    return table.concat(out, "\n")
end
-- One chat line of the addon: kind and its argument (an item name or link).
function M.chat(kind, arg) S().Chat(kind, arg) return M.last() end
-- The loot window's top line for a received item, in a frame of the given width (the addon cuts the name to fit).
function M.loot(name, width, link)
    DCIFrame:SetWidth(width or 290)
    S().Open({ mode = "loot", items = { Item(M.ITEM, 4711) }, receive = 1, bind = true,
        recv = { name = name, link = link and M.link(name) or name, vendor = 100 } })
    M.wait(0.1)
    local t = T(DCI_TopSection_Text1)
    DCIFrame:SetWidth(290)
    return t
end
-- The window drawn again while it is shown (no OnShow): the rows' button for a merchant, as the addon does on
-- MERCHANT_SHOW. (its text, the second tooltip's line for it)
function M.redraw(merchant)
    local st = {}
    for k, v in pairs(M.STATE) do st[k] = v end
    st.merchant = merchant
    S().Update(st)
    M.wait(0.1)
    S().RowTip(1, "delete")
    return S().Rows[1].delete:GetText(), T(DCI_SecondTooltipTextLeft1)
end
-- The game's globals the module reads: their values now, joined.
function M.globals() return table.concat({ tostring(DELETE), tostring(YES), tostring(NO), tostring(ITEM_BIND_QUEST) }, "|") end
function M.setGlobal(k, v) _G[k] = v end
function M.translate(t) return (NS().Words.Translate(t)) end
function M.cyrBoxes() return H.cyrBoxes(20) end
