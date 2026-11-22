-- Harness stand-in for DeleteCheapestItem Reloaded: its settings canvas and Profiles section (not the addon).
-- Built at ADDON_LOADED from the feed's page list (one entry per settings call of the real addon, in order).
-- S.BuildConfig()          DCI_ConfigCanvas / DCI_ConfigPanel with every section, checkbox, dropdown and button
-- S.OpenConfig()           shows the canvas
-- S.ConfigTexts()          {key = text} of every text it drew (frame name, or frame name .. ".label")
-- S.SetProfiles(names, cur) the player's profile names in DCI_ProfileSelect/Copy/Delete, cur as the active one
-- S.ProfilePopup(action, a, b) DCI_PROFILE_ACTION: "copy" (a dest, b source), "reset" (a), "delete" (a)
-- S.ProfileStatus(i)       the profile status line: profile message i, or the created text when i is nil
local S = DCIStandIn
local F = S.F
local L = setmetatable({}, { __index = function(_, k) return k end })  -- private, keyed by the English
local function W(role) return L[S.T[role]] end
local function G(name, alt) local v = rawget(_G, name) if v == nil then return alt end return v end
local drawn = {}
S.db = { MaxQuality = 1, CompareByPrice = 1 }

local function Put(key, fs, text)
  fs:SetText(text)
  drawn[#drawn + 1] = { key = key, fs = fs }
end

local function Choices(name)
  local out = {}
  for i, c in ipairs(F.choices[name] or {}) do
    if c.t then out[i] = L[c.t] else out[i] = c.c .. tostring(G(c.g, c.g)) end
  end
  return out
end
function S.QualityChoices() for k in pairs(F.choices) do if k:find("^quality") then return Choices(k) end end return {} end

local function Section(parent, x, y, h, text)
  local f = CreateFrame("Frame", "DCI_Config_Section_" .. string.sub(string.gsub(text, " ", ""), 1, 10), parent, "TooltipBorderBackdropTemplate")
  f:SetSize(620, h)
  f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  Put(f:GetName() .. ".label", label, text)
  return f
end

local function Checkbox(parent, x, y, var, text)
  local f = CreateFrame("CheckButton", "DCI_Config_Checkbox_" .. var, parent, "UICheckButtonTemplate")
  f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  Put(f:GetName() .. ".label", label, text)
  f.label = label
  return f
end

local function SetDefault(dd, choices, i)
  local choice = choices[i] or choices[1] or ""
  dd:SetDefaultText(choice)
  if dd.Text then dd.Text:SetText(choice) end
  S.Update(false)
end

local function Dropdown(parent, x, y, var, text, choices, width)
  local f = CreateFrame("DropdownButton", "DCI_Config_Dropdown_" .. var, parent, "WowStyle1DropdownTemplate")
  f:SetWidth(width or 250)
  f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  local label = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  Put(f:GetName() .. ".label", label, text)
  f:SetupMenu(function(_, root)
    for i = 1, #choices do root:CreateButton(choices[i], function() S.db[var] = i SetDefault(f, choices, i) end) end
  end)
  SetDefault(f, choices, S.db[var] or 1)
  f.choices = choices
  return f
end

local function Button(parent, x, y, text)
  local f = CreateFrame("Button", "DCI_Config_Button_" .. string.sub(string.gsub(text, "[^A-Za-z]", ""), 1, 10), parent, "UIPanelButtonTemplate")
  Put(f:GetName(), f, text)
  f:SetSize(150, 32)
  f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
  return f
end

local P = {}
local function Parent(a, panel)
  local name = type(a) == "table" and a.name or "?"
  if not P[name] then P[name] = CreateFrame("Frame", "DCI_Config_AuctionFrame", panel) end  -- the one frame made inline
  return P[name]
end

local function Profiles(panel)
  local box = CreateFrame("Frame", "DCI_ProfileControls", panel)
  box:SetSize(600, 310)
  Put("DCI_ProfileControls.heading", box:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"), W("profiles"))
  local help = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  help:SetSize(580, 45)
  Put("DCI_ProfileControls.help", help, W("profHelp"))
  local function DD(name, label)
    local d = CreateFrame("DropdownButton", name, box, "WowStyle1DropdownTemplate")
    d:SetWidth(280)
    if label then Put(name .. ".label", d:CreateFontString(nil, "OVERLAY", "GameFontHighlight"), label) end
    d:SetupMenu(function(_, root) for _, n in ipairs(S.profiles or {}) do root:CreateButton(n, function() end) end end)
    return d
  end
  S.pSelect = DD("DCI_ProfileSelect")
  S.pSelect:SetDefaultText("")
  S.pCopy = DD("DCI_ProfileCopy", W("copyFrom"))
  S.pDelete = DD("DCI_ProfileDelete", W("deleteUnused"))
  local function Help(name, text)
    local fs = box:CreateFontString(name, "OVERLAY", "GameFontDisableSmall")
    fs:SetSize(280, 32)
    Put(name, fs, text)
    return fs
  end
  S.copyHelp, S.deleteHelp = Help("DCI_ProfileCopyHelp", W("noCopy")), Help("DCI_ProfileDeleteHelp", W("noDelete"))
  local edit = CreateFrame("EditBox", "DCI_ProfileName", box, "InputBoxTemplate")
  edit:SetSize(270, 28)
  edit:SetMaxLetters(50)
  if edit.SetAutoFocus then edit:SetAutoFocus(false) end
  if edit.ClearFocus then edit:ClearFocus() end
  S.status = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  S.status:SetSize(580, 40)
  Put("DCI_ProfileControls.status", S.status, W("enter1"))
  local create = CreateFrame("Button", "DCI_ProfileCreate", box, "UIPanelButtonTemplate")
  create:SetSize(150, 32)
  Put("DCI_ProfileCreate", create, W("create"))
  create:SetScript("OnClick", function() S.ProfileStatus() end)
  box:SetScript("OnShow", function() S.RefreshProfiles() end)
  S.RefreshProfiles()
end

function S.RefreshProfiles()
  local others = math.max(0, #(S.profiles or {}) - 1)
  S.pSelect:SetDefaultText(S.current or "")
  if others > 0 then S.copyHelp:Hide() S.deleteHelp:Hide() else S.copyHelp:Show() S.deleteHelp:Show() end
  S.status:SetText(W("enter2"))
end

function S.SetProfiles(names, current)
  S.profiles, S.current = names or {}, current or (names or {})[1]
  if S.pSelect then S.RefreshProfiles() end
end

function S.ProfileStatus(i)
  S.status:SetText(i and L[(F.fn.ProfileMessages or {})[i] or ""] or W("created"))
end

function S.ProfilePopup(action, a, b)
  local text
  if action == "copy" then text = string.format(W("popCopy"), a, b)
  elseif action == "reset" then text = string.format(W("popReset"), a)
  else text = string.format(W("popDelete"), a) end
  text = text .. "\n\n" .. W("popShared")
  StaticPopupDialogs.DCI_PROFILE_ACTION = { text = "%s", button1 = G("YES", ""), button2 = G("NO", ""),
    OnAccept = function() end, timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3 }
  return StaticPopup_Show("DCI_PROFILE_ACTION", text)
end

function S.BuildConfig()
  if S.panel then return end
  local canvas = CreateFrame("Frame", "DCI_ConfigCanvas", UIParent)
  canvas.name = F.title
  if Settings and Settings.RegisterCanvasLayoutCategory then
    local cat = Settings.RegisterCanvasLayoutCategory(canvas, F.title)
    if Settings.RegisterAddOnCategory then Settings.RegisterAddOnCategory(cat) end
  end
  local scroll = CreateFrame("ScrollFrame", "DCI_ConfigScrollFrame", canvas, "UIPanelScrollFrameTemplate")
  local panel = CreateFrame("Frame", "DCI_ConfigPanel", scroll)
  panel:SetSize(635, 1027)
  scroll:SetScrollChild(panel)
  Put("DCI_ConfigPanel.title", panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"), F.title)
  Put("DCI_ConfigPanel.version", panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge"), F.version)
  S.canvas, S.panel = canvas, panel
  P = {}
  if F.page[1] then P[F.page[1].a[1].name or "?"] = panel end  -- the first call's parent is the panel itself
  for _, e in ipairs(F.page) do
    local a = e.a
    local parent = Parent(a[1], panel)
    local f
    if e.kind == "Button" then f = Button(parent, a[2], a[3], L[a[4]])
    elseif e.kind == "Section" then f = Section(parent, a[2], a[3], a[4], L[a[5]])
    elseif e.kind == "Checkbox" then f = Checkbox(parent, a[2], a[3], a[4], L[a[5]])
    else f = Dropdown(parent, a[2], a[3], a[4], L[a[5]], Choices(type(a[7]) == "table" and a[7].name or ""), type(a[8]) == "number" and a[8] or nil) end
    if e["local"] ~= "" then P[e["local"]] = f end
    if e.aux then
      local note = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
      Put(f:GetName() .. ".note", note, "|cffbb0000(" .. L[F.aux[1] or ""] .. ")")
    end
  end
  local edit = CreateFrame("EditBox", "DCI_Config_LowSlotsThreshold", panel, "InputBoxTemplate")
  if edit.SetAutoFocus then edit:SetAutoFocus(false) end
  if edit.ClearFocus then edit:ClearFocus() end
  edit:SetText("2")
  Profiles(panel)
end

function S.OpenConfig()
  S.BuildConfig()
  S.canvas:Show()
  S.panel:Show()
end

function S.ConfigTexts()
  local out = {}
  for _, d in ipairs(drawn) do out[d.key] = d.fs:GetText() end
  return out
end
