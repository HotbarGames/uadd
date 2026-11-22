-- Lua helpers for flow_lt.py, on the LootTriage stand-in (tools/harness/loottriage). Reached from Python as
-- HARNESS.lt. Run before the game starts: it gives the harness what LootTriage's frames need (GameTooltip's
-- lines, the Settings panel's categories, layouts and scroll box, its Defaults button). No English of LootTriage
-- here: the stand-in gets it at run time (M.feed).
local H = HARNESS
local M = {}
H.lt = M

local CYR = "[\208-\210]"
local ZORP = "\208\151\208\190\209\128\208\191"            -- a made-up Ukrainian game name
M.ITEM, M.QUEST = "Zorp Shard", "The Zorp Hunt"           -- made-up names UALL Forever "knows"

local function NS() return H.ns.UADD_LootTriage end
local function S() return LootTriageStandIn end

-- ── What the harness lacks ───────────────────────────────────────────────────────────────────
local tip = GameTooltip
for i = 1, 8 do
    _G["GameTooltipTextLeft" .. i]:SetFontObject(i == 1 and GameTooltipHeaderText or GameTooltipText)
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
tip.NumLines = function(self) return self.__lines or 0 end
tip.SetText = function(self, t) Clear(self) Add(self, t) end
tip.AddLine = function(self, t) Add(self, t) end
tip.AddDoubleLine = function(self, l, r) Add(self, l, r) end

GAMEMENU_NEW_BUTTON = GAMEMENU_NEW_BUTTON or "New"
if not UIParent:GetHeight() then UIParent:SetHeight(768) end

local box = { __onRow = {} }
M.box = box
ScrollUtil = ScrollUtil or {}
ScrollUtil.AddInitializedFrameCallback = function(b, cb, owner) table.insert(b.__onRow, { cb, owner }) end
CreateSettingsButtonInitializer = CreateSettingsButtonInitializer or function(name, text, click, tooltip)
    local i = { data = { name = name, buttonText = text, buttonClick = click, tooltip = tooltip } }
    i.GetData = function(self) return self.data end
    return i
end
local cats, layouts = {}, {}
local reg = Settings.RegisterVerticalLayoutCategory
Settings.RegisterVerticalLayoutCategory = function(name, ...)
    local c, l = reg(name, ...)
    l = l or {}
    l.__init = {}
    l.AddInitializer = function(self, i) table.insert(self.__init, i) end
    l.GetInitializers = function(self) return self.__init end
    cats[#cats + 1], layouts[c] = c, l
    return c, l
end
local getLayout = SettingsPanel.GetLayout
SettingsPanel.GetAllCategories = function() return cats end
SettingsPanel.GetLayout = function(self, c) return layouts[c] or (getLayout and getLayout(self, c)) end
SettingsPanel.GetSettingsList = function() return { ScrollBox = box } end
local defaults = CreateFrame("Button", nil, UIParent)
defaults:Hide()
SettingsPanel.Container = SettingsPanel.Container or {}
SettingsPanel.Container.SettingsList = { Header = { DefaultsButton = defaults } }

-- A forbidden child of UIParent that looks like its window (any call on one throws in the game).
local forbidden = CreateFrame("Frame", nil, UIParent)
forbidden.Refresh, forbidden.pages, forbidden.news, forbidden.version = function() end, {}, {}, {}
forbidden.IsForbidden = function() return true end
M.forbidden = forbidden

-- ── Helpers ──────────────────────────────────────────────────────────────────────────────────
function M.feed(code) assert((loadstring or load)(code))() end
function M.wait(seconds) for _ = 1, math.ceil(seconds / 0.05 - 1e-6) do H.step(0.05) end end
function M.uadd(msg) return H.call("/uadd " .. msg, SlashCmdList.UADD, msg) end
function M.lt(msg) return H.call("/lt " .. msg, SlashCmdList.LOOTTRIAGE, msg) end
function M.last() return H.chat[#H.chat] end
function M.key(down)
    H.keys.SHIFT = down
    H.fire("MODIFIER_STATE_CHANGED", "LSHIFT", down and 1 or 0)
    M.wait(0.4)
end
function M.click(b) b:GetScript("OnClick")(b, "LeftButton") end
function M.stand() return S() end

-- UALL Forever's routes know the made-up names (patched on UADD.UALL, never on the root: lesson 20).
function M.uall()
    local A = UADD.UALL
    local item, quest = A.Item, A.Quest
    A.Item = function(n, ...) if n == M.ITEM then return ZORP end return item and item(n, ...) end
    A.Quest = function(id, n, ...) if n == M.QUEST then return ZORP .. "!" end return quest and quest(id, n, ...) end
end
function M.link(name) return "|cff1eff00|Hitem:4711::::::::60:::::|h[" .. name .. "]|h|r" end
function M.qlink(name) return "|cffffff00|Hquest:4711:60|h[" .. name .. "]|h|r" end

-- Lines on GameTooltip from the stand-in's file, its Delete button the owner.
function M.tip(...) return S().Tip(S().delete, { ... }) end
function M.tr(t) return M.tip({ t })[1] end
function M.chat(line) S().Say(line) return M.last() end
function M.help()
    local from = #H.chat
    M.lt("help")
    local out = {}
    for i = from + 1, #H.chat do out[#out + 1] = H.chat[i] end
    return out
end

-- The game draws its row in the Settings panel: the row's two texts from the initializer, then the callbacks.
function M.drawRow()
    local f = M.row
    if not f then
        f = CreateFrame("Frame", nil, UIParent)
        f.Text = f:CreateFontString()
        f.Button = CreateFrame("Button", nil, f)
        M.row = f
    end
    local d = S().init.data
    f.Text:SetText(d.name)
    f.Button:SetText(d.buttonText)
    for _, e in ipairs(box.__onRow) do e[1](e[2], f, S().init) end
    return f
end

-- Every text the module may change: W window labels, D the dropdown's text, C its choices, N the news button,
-- V the version, P the panel data, R the drawn row, X the What's New dialog.
function M.snap()
    local s, out = S(), {}
    M.lt("")
    for i, l in ipairs(s.win.labels) do out["W:" .. i] = l.fs:GetText() end
    out["D"] = s.win.drop.text:GetText()
    for i, c in ipairs(s.win.drop.row.choices()) do out["C:" .. i] = tostring(c[1]) .. "=" .. tostring(c[2]) end
    out["N"], out["V"] = s.win.news:GetText(), s.win.version:GetText()
    for _, k in ipairs({ "name", "buttonText", "tooltip" }) do out["P:" .. k] = s.init.data[k] end
    local r = M.drawRow()
    out["R:text"], out["R:button"] = r.Text:GetText(), r.Button:GetFontString():GetText()
    M.click(s.win.news)
    out["X"] = s.dialog.text:GetText()
    return out
end

-- A text shows Cyrillic exactly when our font is on it: (bad texts, n with ours).
function M.fonts()
    local s, list, bad, n = S(), {}, {}, 0
    for _, l in ipairs(s.win.labels) do list[#list + 1] = l.fs end
    list[#list + 1] = s.win.drop.text
    if s.dialog then list[#list + 1] = s.dialog.text end
    if M.row then list[#list + 1] = M.row.Text list[#list + 1] = M.row.Button:GetFontString() end
    for _, fs in ipairs(list) do
        local t = fs:GetText() or ""
        local cyr, ours = t:find(CYR) ~= nil, UADD.IsCyrFont((fs:GetFont())) and true or false
        if ours then n = n + 1 end
        if cyr ~= ours then bad[#bad + 1] = t end
    end
    return bad, n
end

-- Work the tooltip hook does on lines that are not LootTriage's: calls of Translate and UADD.Hash, and how
-- much the Words cache grew. (a line from other code, the stand-in's file with another owner, cache growth)
function M.cheap()
    local W, n = NS().Words, 0
    local t, h = W.Translate, UADD.Hash
    local function count(f) return function(...) n = n + 1 return f(...) end end
    local size = W.CacheSize()
    W.Translate, UADD.Hash = count(t), count(h)
    tip:SetOwner(UIParent)
    tip:AddLine("Quix Zorp gizmo")
    tip:AddLine("  Quix Zorp gizmo")
    tip:Show()
    local other = n
    n = 0
    S().Tip(UIParent, { "Quix Zorp gizmo", "  Quix wobbly" })
    local stand = n
    W.Translate, UADD.Hash = t, h
    return other, stand, W.CacheSize() - size
end

-- n errors in its window's hooks: a text on its page whose GetText throws n times.
function M.fault(n)
    if not M.boomFs then
        local fs = S().win.pages[1]:CreateFontString()
        fs.GetText = function()
            if (M.boom or 0) > 0 then M.boom = M.boom - 1 error("harness: a broken text") end
            return nil
        end
        M.boomFs = fs
    end
    M.boom = n
end
-- The game's menu its dropdown opens (Stand.lua; opened first when `open`): each shown entry as
-- "text<TAB>1 if in our Cyrillic font<TAB>1 if its font object is the game's (GameFontHighlight)".
function M.menu(open)
    if open then S().OpenDrop() end
    local out = {}
    for _, fs in ipairs(S().menu.rows) do
        if fs:IsShown() and S().menu:IsShown() then
            out[#out + 1] = tostring(fs:GetText()) .. "\t" .. (UADD.IsCyrFont((fs:GetFont())) and "1" or "0") .. "\t"
                .. (fs:GetFontObject() == GameFontHighlight and "1" or "0")
        end
    end
    return out
end
function M.closeMenu() S().CloseDrop() end
function M.menuCount() return NS().Menu.Count() end

-- A tooltip whose owner is forbidden (any call on one throws, as in the game): (lines, errors reported, faults).
function M.forbiddenTip(line)
    local f, reported, faults = M.forbidden, 0, 0
    local gp, rep, fault = f.GetParent, UADD.ReportError, UADD.Fault
    f.GetParent = function() error("harness: a call on a forbidden frame") end
    UADD.ReportError = function(...) reported = reported + 1 return rep(...) end
    UADD.Fault = function(...) faults = faults + 1 return fault(...) end
    local ok, out = pcall(S().Tip, f, { line })
    f.GetParent, UADD.ReportError, UADD.Fault = gp, rep, fault
    return ok and out or { "error: " .. tostring(out) }, reported, faults
end

function M.on() return NS().On() and true or false end
function M.choicesBack() return S().win.drop.row.choices == S().choices end
-- Every chat line "/uadd msg" printed, joined.
function M.said(msg)
    local from, out = #H.chat, {}
    M.uadd(msg)
    for i = from + 1, #H.chat do out[#out + 1] = tostring(H.chat[i]) end
    return table.concat(out, "\n")
end
