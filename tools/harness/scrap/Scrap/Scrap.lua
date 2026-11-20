-- Stand-in for Scrap (tools/harness/flow_scrap.py). Every word comes from Scrap's own AceLocale table (its
-- localization/en.lua, run from the installed addon before this file); none is written here. Like Scrap 12,
-- it copies four words into the key binding names at load; the chat lines, the merchant button's tooltip
-- and the confirm pop-up read the table each time; the tutorial reads it when registered.
-- Two small libraries stand in for the ones the module reaches: Sushi-3.2 (its pop-ups) and
-- CustomTutorials-2.1 (its frames).

local L = LibStub("AceLocale-3.0"):GetLocale("Scrap")
local S = { tag = {}, junk = {} }
ScrapStandIn = S
S.FONT = "Fonts\\FRIZQT__.TTF"

function S.Text(parent)
    local fs = parent:CreateFontString(nil, "ARTWORK")
    fs:SetFont(S.FONT, 12, "")
    return fs
end

function S.Button(parent)
    local b = CreateFrame("Button", nil, parent)
    b:GetFontString():SetFont(S.FONT, 12, "")
    return b
end

-- ── Sushi-3.2: its pop-ups (Active, New, called as a function) ─────────────────────────────────

local Sushi = LibStub:NewLibrary("Sushi-3.2", 1)
local Popup = { Active = {} }
Sushi.Popup = setmetatable(Popup, { __call = function(self, info) return self:New(info) end })
function Popup:New(info)
    local f = CreateFrame("Frame", nil, UIParent)
    f.Text = S.Text(f)
    f.Text:SetText(info.text)
    f.Yes, f.No = S.Button(f), S.Button(f)
    f.Yes:SetText(info.button1)
    f.No:SetText(info.button2)
    self.Active[#self.Active + 1] = f
    return f
end
function Popup:Release(f)
    for i, p in ipairs(self.Active) do
        if p == f then table.remove(self.Active, i) f:Hide() return end
    end
end

-- ── CustomTutorials-2.1: one frame per owner, a step's text set when it shows ──────────────────

local CT = LibStub:NewLibrary("CustomTutorials-2.1", 1)
CT.frames = {}
function CT.RegisterTutorials(self, data)
    if not CT.frames[self] then
        local f = CreateFrame("Frame", nil, UIParent)
        f.text = S.Text(f)
        f:Hide()
        CT.frames[self] = f
    end
    CT.frames[self].data = data
end
function CT.TriggerTutorial(self, i)
    local f = CT.frames[self]
    f.i = i
    f.text:SetText(f.data[i].text)
    f:Show()
end

-- ── The addon ────────────────────────────────────────────────────────────────────────────────

Scrap = { sets = {}, charsets = {} }
function Scrap:NewModule(name, obj)
    obj = obj or {}
    self[name] = obj
    return obj
end

BINDING_NAME_SCRAP_TOGGLE = L.ToggleMousehover
BINDING_NAME_SCRAP_DESTROY_ONE = L.DestroyCheapest
BINDING_NAME_SCRAP_DESTROY_ALL = L.DestroyJunk
BINDING_NAME_SCRAP_SELL = L.SellJunk

function Scrap:Print(text)
    S.last = text
    DEFAULT_CHAT_FRAME:AddMessage(text)
end
local Money = rawget(_G, "GetMoneyString") or function(v) return v .. "|TInterface\\MoneyFrame\\UI-GoldIcon:0|t" end
function Scrap:PrintMoney(pattern, value) self:Print(pattern:format(Money(value, true))) end

-- The lines Scrap prints (S.last: the last one). Money lines: ours; lines with an item link: English.
function S.Sold(v) Scrap:PrintMoney(L.SoldJunk, v) return S.last end
function S.Repair(v, guild) Scrap:PrintMoney(guild and L.GuildRepaired or L.Repaired, v) return S.last end
function S.Toggle(link, junk) Scrap:Print(format(junk and L.Removed or L.Added, link)) return S.last end
function S.Forget(link) Scrap:Print(format(L.Forgotten, link)) return S.last end
function S.Destroy(link, n) Scrap:Print(L.Destroyed:format(link, n)) return S.last end
-- A line its code builds from one key with its values (the half-line check).
function S.Line(key, ...) Scrap:Print(L[key]:format(...)) return S.last end

function S.Confirm() return Sushi.Popup { text = L.ConfirmDelete, button1 = OKAY, button2 = CANCEL } end

-- The merchant button: its tooltip reads the table each time it shows.
local Merchant = Scrap:NewModule("Merchant", CreateFrame("Button", nil, UIParent))
function Merchant:UpdateTip(tip)
    if S.cursor then
        tip:SetText(S.junk[S.cursor] and L.Remove or L.Add, 1, 1, 1)
    else
        tip:SetText(S.merchant and L.SellJunk or L.DestroyJunk)
    end
    tip:Show()
end
Merchant:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    self:UpdateTip(GameTooltip)
end)

-- The tutorial: Register reads the table; step 1 shows at load.
local Tutorials = Scrap:NewModule("Tutorials", {})
Tutorials.RegisterTutorials, Tutorials.TriggerTutorial = CT.RegisterTutorials, CT.TriggerTutorial
function Tutorials:Register()
    self:RegisterTutorials({ savedvariable = Scrap.sets, key = "tutorial", title = "Scrap",
        { text = L.Tutorial_Welcome }, { text = L.Tutorial_Button }, { text = L.Tutorial_Drag },
        { text = L.Tutorial_Visualizer }, { text = L.Tutorial_Bye } })
end
Tutorials:Register()
Tutorials:TriggerTutorial(1)
