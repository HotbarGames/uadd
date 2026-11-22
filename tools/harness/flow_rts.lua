-- Lua helpers for flow_rts.py, on the Road to Sixty stand-in (tools/harness/rts). Reached from Python as HARNESS.rts.
-- Run before the game starts: it gives the harness what the stand-in's hooks need (StartDuel, a filter list, a
-- tooltip that keeps its lines, StaticPopup_Show, the game's ERR_/LOOT_/FACTION_/DUEL_ globals).
local H = HARNESS
local M = {}
H.rts = M

function StartDuel() end
RTSFilters = {}
local add = ChatFrame_AddMessageEventFilter
ChatFrame_AddMessageEventFilter = function(ev, f)
    RTSFilters[ev] = RTSFilters[ev] or {}
    table.insert(RTSFilters[ev], f)
    return add(ev, f)
end
for _, name in ipairs(CHAT_FRAMES) do
    if _G[name] then _G[name]:RegisterEvent("TIME_PLAYED_MSG") end
end
M.GLOBALS = { ERR_CHAT_PLAYER_NOT_FOUND_S = "No player named '%s' is currently playing.", LOOT_ITEM_SELF = "You receive loot: %s.",
    FACTION_STANDING_INCREASED = "Reputation with %s increased by %d.", DUEL_COUNTDOWN = "Duel starting: %d" }
for k, v in pairs(M.GLOBALS) do if rawget(_G, k) == nil then _G[k] = v end end

-- As in the game, only a tooltip has AddLine (the harness gives it to every widget, and U.Walk leaves a frame
-- with AddLine to U.TipLines, so no window of the stand-in would be walked), as flow_dci.lua does.
local create = CreateFrame
CreateFrame = function(kind, name, ...)
    local f = create(kind, name, ...)
    if kind ~= "GameTooltip" then rawset(f, "AddLine", false) end
    return f
end

-- As newer clients do: the addon's Settings category gets a number for its ID (so a look-up by its name finds
-- nothing), and its canvas sits in the Settings window's Container, where UADD finds it by its name field.
if type(SettingsPanel) == "table" and not rawget(SettingsPanel, "Container") then
    SettingsPanel.Container = CreateFrame("Frame", nil, SettingsPanel)
end
local register, ids = Settings.RegisterCanvasLayoutCategory, 0
Settings.RegisterCanvasLayoutCategory = function(frame, name, ...)
    local c, l = register(frame, name, ...)
    if type(name) == "string" and name:find("Sixty", 1, true) and type(c) == "table" then
        ids = ids + 1
        c.ID = 9000 + ids
        if frame and frame.SetParent then frame:SetParent(SettingsPanel.Container) end
    end
    return c, l
end

-- Word wrap kept, as the game's FontString has it (CanWordWrap): Road to Sixty's name rows are one line.
local Wd = H.Widget
function Wd:SetWordWrap(on) self.__wrap = on and true or false end
function Wd:CanWordWrap() return self.__wrap ~= false end

-- GameTooltip and StaticPopup1..4 as the game has them (font strings by name), so U.TipLines and U.Popups work.
local function Tipify(tip, name)
    local n = 0
    for i = 1, 8 do
        _G[name .. "TextLeft" .. i] = tip:CreateFontString(name .. "TextLeft" .. i, nil, "GameTooltipText")
        _G[name .. "TextRight" .. i] = tip:CreateFontString(name .. "TextRight" .. i, nil, "GameTooltipText")
    end
    local function Clear(self)
        for i = 1, 8 do _G[name .. "TextLeft" .. i]:SetText(nil) _G[name .. "TextRight" .. i]:SetText(nil) end
        n = 0
        local f = self:GetScript("OnTooltipCleared") if f then f(self) end
    end
    tip.SetOwner = function(self, o) self.__owner = o Clear(self) end
    tip.ClearLines = Clear
    tip.NumLines = function() return n end
    tip.SetText = function(self, t) Clear(self) n = 1 _G[name .. "TextLeft1"]:SetText(t) end
    tip.AddLine = function(self, t) if n < 8 then n = n + 1 _G[name .. "TextLeft" .. n]:SetText(t) end end
    tip.AddDoubleLine = function(self, a, b) if n < 8 then n = n + 1 _G[name .. "TextLeft" .. n]:SetText(a)
        _G[name .. "TextRight" .. n]:SetText(b) end end
end
Tipify(GameTooltip, "GameTooltip")
function M.tipLines() local out = {} for i = 1, GameTooltip:NumLines() do out[i] = _G["GameTooltipTextLeft" .. i]:GetText() end return out end

local pops, shown = {}, nil
for i = 1, 4 do
    local d = CreateFrame("Frame", "StaticPopup" .. i, UIParent)
    d:Hide()
    d.text = d:CreateFontString("StaticPopup" .. i .. "Text", nil, "GameFontHighlight")
    _G["StaticPopup" .. i .. "Text"] = d.text
    for b = 1, 4 do
        local btn = CreateFrame("Button", "StaticPopup" .. i .. "Button" .. b, d)
        d["button" .. b] = btn
    end
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
    shown = d
    return d
end
function StaticPopup_Hide(which) for _, p in ipairs(pops) do if p.which == which then p:Hide() p.which = nil end end end
function M.popup() local d = shown if not d then return nil end
    return { which = d.which, text = d.text:GetText(), b1 = d.button1:GetText(), b2 = d.button2:GetText() } end

function M.wait(seconds) for _ = 1, math.ceil(seconds / 0.05 - 1e-6) do H.step(0.05) end end
function M.stand() return RTSStandIn end
function M.key(down)
    H.keys.SHIFT = down
    H.fire("MODIFIER_STATE_CHANGED", "LSHIFT", down and 1 or 0)
    M.wait(0.4)
end
function M.click(i) local t = RTSStandIn.tabs[i] t:GetScript("OnClick")(t) return t.fs:GetFontObject() == GameFontHighlight end
function M.tabFont(i) return RTSStandIn.tabs[i].fs:GetFontObject() == GameFontHighlight end
function M.enabledButton(on) RTSStandIn.button:SetEnabled(on) return RTSStandIn.button:IsEnabled() end
function M.say(msg) local n = #H.chat RTSStandIn.Say(msg) return H.chat[n + 1] end
function M.names() local out = {} for _, n in ipairs({ "RoadToSixtyJourneyFrame", "RoadToSixtyMinimapButton", "RoadToSixtyCompareWindow",
    "RoadToSixtyWhatsNew" }) do out[n] = rawget(_G, n) and true or false end return out end
function M.globals() local out = {} for k in pairs(M.GLOBALS) do out[#out + 1] = k .. "=" .. tostring(_G[k]) end table.sort(out) return table.concat(out, "|") end
function M.db()
    local d = RoadToSixtyDB.runs[1]
    return table.concat({ d.name, d.level, d.zone, RoadToSixtyDB.note }, "|")
end
function M.hookNow() local s, n = RTSStandIn.sent, RTSStandIn.SentNow() return s ~= nil and s.SetItemRef == n.SetItemRef and
    s.StartDuel == n.StartDuel and s.filter == n.filter and n.filters == RTSStandIn.filter and n.muted and s.muted end
function M.combat(on) H.combat = on end
