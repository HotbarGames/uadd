-- Game functions Wowhead Quick Link calls that the harness lacks, and its /wql window, built here as its XML
-- builds it (sizes, anchors, font objects). Run before its own Lua files (tools/harness/flow_wql.py runs those from
-- the installed addon). The window's texts are not here: flow_wql.py reads them from the installed addon's XML and
-- hands them in as HARNESS.wqlLabels before the game starts (the addon has no licence).

local function fill(t, k, v) if rawget(t, k) == nil then t[k] = v end end

fill(_G, "GetBindingAction", function() return "" end)
fill(_G, "SaveBindings", function() end)
fill(_G, "GetCurrentBindingSet", function() return 1 end)
-- A faction row's id is GetFactionInfo's 14th value (the harness stub gives nothing).
function GetFactionInfo(index) if index then return nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, 77 end end

for _, tip in ipairs({ GameTooltip, ItemRefTooltip }) do
    fill(tip, "GetItem", function() return nil end)
    fill(tip, "GetSpell", function() return nil end)
    fill(tip, "GetUnit", function() return nil end)
end

if not rawget(_G, "ChatFontNormal") then CreateFont("ChatFontNormal"):SetFont("Fonts\\ARIALN.TTF", 14, "") end

-- ── The /wql window (WowheadQuickLinkConfig.xml) ─────────────────────────────────────────────

local L = HARNESS.wqlLabels or {}
local f = CreateFrame("Frame", "WowheadQuickLinkConfig_Frame", UIParent)
f:SetSize(330, 150)
f:SetPoint("CENTER")
f:Hide()

local header = f:CreateTexture(nil, "ARTWORK")
header:SetSize(420, 64)
header:SetPoint("TOP", 0, 12)

local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", f, "TOP", 0, -2)
title:SetText(L.title)

local urlHead = f:CreateFontString("WowheadQuickLinkConfig_FinalUrlHeader", "OVERLAY", "GameFontNormal")
urlHead:SetPoint("CENTER", f, "CENTER", 0, -30)
urlHead:SetText(L.header)

local url = f:CreateFontString("WowheadQuickLinkConfig_FinalUrlText", "OVERLAY", "ChatFontNormal")
url:SetPoint("BOTTOM", urlHead, "BOTTOM", 0, -15)
url:SetText("www.example.com")

-- An edit box of the template: two border textures, its own font string (what the player types; the real box draws
-- its text there), and the label above it, anchored at its top left, upwards.
local function Box(name, point, x, label)
    local b = CreateFrame("EditBox", name, f)       -- autoFocus on, as in its XML: it takes the keyboard on /wql
    b:SetSize(120, 32)
    b:SetPoint(point, f, point, x, 10)
    for _, side in ipairs({ "LEFT", "RIGHT" }) do
        local t = b:CreateTexture(nil, "BACKGROUND")
        t:SetSize(75, 32)
        t:SetPoint(side, b, side, side == "LEFT" and -10 or 10, 0)
    end
    local typed = b:CreateFontString(nil, "ARTWORK", "ChatFontNormal")
    hooksecurefunc(b, "SetText", function(self, v) typed:SetText(v) end)
    b.typed = typed
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 10)
    fs:SetText(label)
    return b, fs
end
local bp, prefix = Box("WowheadQuickLinkConfig_EditBoxPrefix", "LEFT", 30, L.prefix)
local bs, suffix = Box("WowheadQuickLinkConfig_EditBoxSuffix", "RIGHT", -30, L.suffix)
-- Its texts, for tools/harness/flow_wql.lua to read back.
f.standIn = { title = title, header = urlHead, url = url, prefix = prefix, suffix = suffix, typedP = bp.typed,
    typedS = bs.typed }

local close = CreateFrame("Button", nil, f)
close:SetSize(32, 32)
close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -5, -5)
close:SetScript("OnClick", function() f:Hide() end)
