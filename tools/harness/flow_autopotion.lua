-- Lua helpers for flow_autopotion.py, on the Auto Potion stand-in (tools/harness/autopotion).
-- Reached from Python as HARNESS.ap. Run before the game starts: check boxes keep their click area
-- (Get/SetHitRectInsets), the game's binding list is the stand-in's (GetNumBindings, GetBinding),
-- GameTooltip's lines get text and a font and it knows its owner (the harness only counts lines).
local H = HARNESS
local M = {}
H.ap = M

local function S() return rawget(_G, "AutoPotionStandIn") end
local function NS() return H.ns.UADD_AutoPotion end

local W = H.Widget
W.SetHitRectInsets = function(self, l, r, t, b) rawset(self, "__hit", { l or 0, r or 0, t or 0, b or 0 }) end
W.GetHitRectInsets = function(self) return unpack(rawget(self, "__hit") or { 0, 0, 0, 0 }) end

function GetNumBindings() return S() and #S().bindings or 0 end
function GetBinding(i)
    local b = S() and S().bindings[i]
    if b then return b[1], b[2] end
end

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
tip.GetOwner = function(self) return self.__owner end
tip.SetText = function(self, t) Clear(self) Add(self, t) end
tip.AddLine = function(self, t) Add(self, t) end

-- The stand-in's texts.
function M.names()
    local out = {}
    for name in pairs(S().texts) do out[#out + 1] = name end
    table.sort(out)
    return out
end
function M.hash(name) return S().spec[name].hash end
function M.text(name) return S().texts[name]:GetText() end
function M.font(name) return S().texts[name]:GetFont() end
function M.shown(name) return S().texts[name]:IsVisible() end
function M.width(name) return S().texts[name]:GetStringWidth() end
function M.hooked(name) return NS().Texts.Hooked(S().texts[name]) end
function M.linkText() return S().link:GetText() end
function M.resetWidth() return S().reset:GetWidth() end
function M.hit(name) local _, r = S().boxes[name]:GetHitRectInsets() return r end
-- The stand-in's texts measured wider in our font (7 per byte, not 6), as a real font differs: a box
-- fitted from a width read in the wrong font (e.g. after "/uadd autopotion off" put the font back
-- first) then no longer matches its label.
function M.fontWidths()
    local base = W.GetStringWidth
    for _, fs in pairs(S().texts) do
        rawset(fs, "GetStringWidth", function(self)
            local w, p = base(self), self:GetFont()
            return (p and UADD.IsCyrFont(p)) and w * 7 / 6 or w
        end)
    end
end
function M.pageCount() local n = 0 for _ in pairs(S().pages) do n = n + 1 end return n end
function M.uaddAtBuild() return S().uaddAtBuild end
function M.standIn() return S() ~= nil end

-- Our Ukrainian for a text, straight from data/words.lua (ns.AP, ns.AP_BARE): an exact text, or a
-- template filled with the stand-in's slot values; inside the colour it had. nil: not in the data.
local function FromData(data, hash, args)
    if not data then return nil end
    local uk = data.exact[hash]
    if uk then return uk end
    for _, t in ipairs(data.templates) do
        if t.id == hash then
            local out = {}
            for _, p in ipairs(t.uk) do out[#out + 1] = type(p) == "number" and tostring(args[p]) or p end
            return table.concat(out)
        end
    end
end
function M.want(name)
    local sp = S().spec[name]
    if not sp or not sp.hash then return nil end
    local uk = FromData(NS().AP, sp.hash, sp.args)
    return uk and (sp.pre or "") .. uk .. (sp.post or "")
end
function M.wantHash(hash, ...) return FromData(NS().AP, hash, { ... }) end
function M.wantBare(hash, ...) return FromData(NS().AP_BARE, hash, { ... }) end
function M.dataCount()
    local n = 0
    for _, d in ipairs({ NS().AP, NS().AP_BARE }) do
        if d then for _ in pairs(d.exact) do n = n + 1 end n = n + #d.templates end
    end
    return n
end
function M.tipHash(name) return S().spec[name].tip end

-- The pages and the stand-in's doings.
function M.settings(on) InterfaceOptionsFrame:SetShown(on) end
function M.page(name, on) S().Show(name, on) end
function M.hover(name) S().Hover(name) end
function M.leave(name) S().Leave(name) end
function M.tipLine(i) return _G["GameTooltipTextLeft" .. i]:GetText() end
function M.tipFont(i) return (_G["GameTooltipTextLeft" .. i]:GetFont()) end
function M.setInstalled() S().SetInstalled() end
function M.purple(hash, ...) S().Purple(hash, ...) end
function M.error(macro) S().Error(macro) end
function M.resetDone() S().ResetDone() end
function M.badOption(word) S().BadOption(word) end
function M.prefix(red) return red and S().RED or S().PURPLE end
function M.chatLine(msg) DEFAULT_CHAT_FRAME:AddMessage(msg) end
function M.lastChat() return H.chat[#H.chat] end

-- The key bindings: i = 1..5 (S.MACROS order).
function M.binding(i) return rawget(_G, "BINDING_NAME_MACRO " .. S().MACROS[i]) end
function M.bindingOwn(i) return rawget(_G, "BINDING_NAME_" .. S().bindEn[i]) end
function M.bindingEn(i) return S().bindEn[i] end
function M.category() return rawget(_G, S().categoryEn) end
function M.setCategory(v) _G[S().categoryEn] = v end
function M.bindingCount() return NS().Bindings.Count() end

-- The module.
function M.uk(en) return UADD.AutoPotionWords.Text(en) end
function M.bare(en) return UADD.AutoPotionWords.Bare(en) end
function M.count() return UADD.AutoPotionWords.Count() end
function M.on() return NS().On() end
function M.textCount() return NS().Texts.Count() end
function M.fontCount() return NS().Fonts.Count() end
function M.chatActive() return NS().Chat.Active() end
function M.isCyr(p) return UADD.IsCyrFont(p) end

function M.key(down)
    H.keys.SHIFT = down
    H.fire("MODIFIER_STATE_CHANGED", "LSHIFT", down and 1 or 0)
    M.wait(0.4)                         -- UADD/Original.lua switches once the key is held a while
end
function M.wait(seconds) for _ = 1, math.ceil(seconds / 0.05 - 1e-6) do H.step(0.05) end end
function M.uadd(msg) return H.call("/uadd " .. msg, SlashCmdList.UADD, msg) end

-- Speed of the miss paths: a text we have no Ukrainian for (a spell name on a shown check box, a
-- chat line of someone else) costs little and makes no garbage, n times each.
function M.speed(n)
    local Wd, C, T = UADD.AutoPotionWords, NS().Chat, NS().Texts
    local fs = S().texts.spell
    local miss, line = "Glimmering Quixberry", "[Guild] Quix: anyone up for Zorp Blatter?"
    Wd.Text(miss) C.Line(line) T.Apply(fs, false)
    collectgarbage("collect")
    collectgarbage("stop")
    local kb0 = collectgarbage("count")
    local t0 = debugprofilestop()
    for _ = 1, n do Wd.Text(miss) end
    for _ = 1, n do C.Line(line) end
    for _ = 1, n do T.Apply(fs, false) end
    local ms = debugprofilestop() - t0
    local kb = collectgarbage("count") - kb0
    collectgarbage("restart")
    return ms, kb
end
