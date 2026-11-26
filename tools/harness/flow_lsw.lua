-- Lua helpers for flow_lsw.py, on the LayerSwap stand-in (tools/harness/layerswap).
-- Reached from Python as HARNESS.lsw. Run before the game starts: GameTooltip's lines get text and a font
-- (the harness only counts lines). A button's state font objects are the shared stand-in's (wow_button.lua:
-- the getters return the object, and its state puts it on the label natively, as in the client).
local H = HARNESS
local M = {}
H.lsw = M

local function S() return rawget(_G, "LayerSwapStandIn") end
local function NS() return H.ns.UADD_LayerSwap end

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
tip.AddDoubleLine = function(self, l, r) Add(self, l, r) end

-- The stand-in's English (its labels live only there).
function M.en(key) return S().EN[key] end
function M.prefix() return S().PREFIX end

function M.text(name) return S().texts[name] and S().texts[name]:GetText() end
function M.font(name) return S().texts[name]:GetFont() end
function M.objectSize(name)
    local o = S().texts[name]:GetFontObject()
    if type(o) == "table" and o.GetFont then return (select(2, o:GetFont())) end
end
function M.hooked(name) return NS().Texts.Hooked(S().texts[name]) end
function M.stale(name) return NS().Texts.Stale(S().texts[name]) end
function M.uk(en) return NS().Words.Text(en) end

-- UALL Forever's zone names (UADD.UALL.Zone, UADD/uall.lua) as a stand-in that knows one name:
-- en -> ua. With `wait` it answers "not now", as in combat. No en: the real one back.
function M.zoneStub(en, ua, wait)
    local A = UADD.UALL
    A.__zone = A.__zone or A.Zone
    if en == nil then A.Zone = A.__zone return end
    A.Zone = function(name)
        if wait then return nil, true end
        if name == en then return ua end
    end
end
function M.fontCount() return NS().Fonts.Count() end
function M.textCount() return NS().Texts.Count() end
function M.wordCount() return NS().Words.Count() end

function M.panel(show) S().Panel(show) end
function M.refresh() S().Refresh() end
function M.grouped(on) S().state.grouped = on end
function M.enabled(on) S().swapButton:SetEnabled(on) end
function M.letter(l) S().state.letter = l end
function M.menu(show, minutes) S().Menu(show, minutes) end
function M.settings(show) S().Settings(show) end
function M.hover() S().Hover() end
function M.leave() S().Leave() end
function M.tipLine(i) return _G["GameTooltipTextLeft" .. i]:GetText() end
function M.tipFont(i) return (_G["GameTooltipTextLeft" .. i]:GetFont()) end

function M.say(msg) S().say(msg) end
function M.chatLine(msg) DEFAULT_CHAT_FRAME:AddMessage(msg) end
function M.lastChat() return H.chat[#H.chat] end
function M.chatPutBack() return rawget(DEFAULT_CHAT_FRAME, "AddMessage") == nil end

function M.key(down)
    H.keys.SHIFT = down
    H.fire("MODIFIER_STATE_CHANGED", "LSHIFT", down and 1 or 0)
end
function M.combat(on)
    H.combat = on
    if not on then H.fire("PLAYER_REGEN_ENABLED") end
end
function M.wait(seconds) for _ = 1, math.ceil(seconds / 0.05 - 1e-6) do H.step(0.05) end end
function M.uadd(msg) return H.call("/uadd " .. msg, SlashCmdList.UADD, msg) end
function M.standIn() return S() ~= nil end
