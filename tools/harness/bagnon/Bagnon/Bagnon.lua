-- Not Bagnon: a stand-in shaped like it, for tools/harness/flow_bagnon.py. Before this file runs, the
-- flow runs the installed BagBrother's LibStub, AceLocale-3.0 and core/localization/en.lua under the
-- name "Bagnon", so every word here is read from Bagnon's own AceLocale table, as Bagnon does:
--   * read once at load: the window classes' title formats, three bag rules' names, the key binding
--     names (as BagBrother's frames, rules.lua and slashCommands.lua do);
--   * read each time a window updates: its title (the format, with the owner's name) and a few labels.
local ADDON = ...
local L = LibStub("AceLocale-3.0"):GetLocale(ADDON)
local OWNER = "Quix"

local Addon = { Frames = { Registry = {} }, Rules = { Registry = {} } }
_G[ADDON] = Addon
BagnonStandIn = { owner = OWNER, texts = {} }
local S = BagnonStandIn

Addon.Inventory = { Title = L.TitleBags }
Addon.Bank = { Title = L.TitleBank }
Addon.Vault = { Title = L.TitleVault }
local CLASS = { inventory = "Inventory", bank = "Bank", vault = "Vault" }

for id, key in pairs({ normal = "NormalBags", trade = "TradeBags", ammo = "AmmoBags" }) do
    Addon.Rules.Registry[id] = { id = id, title = L[key] }
end

local UP = ADDON:upper()
_G["BINDING_HEADER_" .. UP] = ADDON
_G["BINDING_NAME_" .. UP .. "_TOGGLE"] = L.OpenBags
_G["BINDING_NAME_" .. UP .. "_BANK_TOGGLE"] = L.OpenBank
_G["BINDING_NAME_" .. UP .. "_VAULT_TOGGLE"] = L.OpenVault
_G["BINDING_NAME_" .. UP .. "_GUILD_TOGGLE"] = L.OpenGuild

-- A window's labels: read from L at each update. Drag stays English (make_bgn_text.py: STAY).
S.LABELS = { "BrowseItems", "Characters", "OfflineViewing", "Drag" }

local function Text(parent, size)
    local fs = parent:CreateFontString(nil, "ARTWORK")
    fs:SetFont("Fonts\\FRIZQT__.TTF", size or 12, "")
    return fs
end

local Frames = Addon.Frames

function Frames:Get(id)
    for _, f in ipairs(self.Registry) do if f.id == id then return f end end
end

function Frames:New(id)
    local f = CreateFrame("Frame", nil, UIParent)
    f.id = id
    f.Title = CreateFrame("Button", nil, f)
    f.Title.title = Addon[CLASS[id]].Title
    f.Title.text = Text(f.Title, 14)
    f.Title.Update = function(self) self.text:SetFormattedText(self.title, OWNER) end
    S.texts["win:" .. id .. ":title"] = f.Title.text
    f.labels = {}
    for _, key in ipairs(S.LABELS) do
        f.labels[key] = Text(f)
        S.texts["win:" .. id .. ":" .. key] = f.labels[key]
    end
    f.Update = function(self)
        self.Title:Update()
        for key, fs in pairs(self.labels) do fs:SetText(L[key]) end
    end
    table.insert(self.Registry, f)
    f:Update()
    return f
end

function Frames:Update()
    for _, f in ipairs(self.Registry) do f:Update() end
end

function Frames:Show(id)
    local f = self:Get(id) or self:New(id)
    f:Show()
    return f
end
