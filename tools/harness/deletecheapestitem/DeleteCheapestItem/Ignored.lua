-- Harness stand-in for DeleteCheapestItem Reloaded: its ignored-items window (not the addon).
-- S.OpenIgnored(list)   DCI_IgnoredItemsFrame, made on first open; rows (unnamed) from list = {{id=, name=}}
local S = DCIStandIn
local L = setmetatable({}, { __index = function(_, k) return k end })  -- private, keyed by the English
local function W(role) return L[S.T[role]] end

function S.OpenIgnored(list)
  local f = DCI_IgnoredItemsFrame
  if not f then
    f = S.Window("DCI_IgnoredItemsFrame")
    f:SetSize(310, 286)
    f:SetFrameStrata("DIALOG")
    f.title = f.titleParent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetText(W("ignTitle"))
    f.empty = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.inset = CreateFrame("Frame", nil, f, "InsetFrameTemplate3")
    f.scroll = CreateFrame("ScrollFrame", "DCI_IgnoredItemsScroll", f, "UIPanelScrollFrameTemplate")
    f.content = CreateFrame("Frame", nil, f.scroll)
    f.scroll:SetScrollChild(f.content)
    f.reset = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.reset:SetSize(200, 24)
    f.reset:SetText(W("ignReset"))
    f.rows = {}
  end
  S.ignored = list or S.ignored or {}
  for i, info in ipairs(S.ignored) do
    local row = f.rows[i]
    if not row then
      row = CreateFrame("Frame", nil, f.content)
      row:SetSize(274, 38)
      row.icon = row:CreateTexture(nil, "ARTWORK")
      row.background = row:CreateTexture(nil, "BACKGROUND")
      row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      row.label:SetSize(136, 30)
      row.remove = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
      row.remove:SetSize(76, 32)
      f.rows[i] = row
    end
    row.label:SetText(info.name or string.format(W("itemId"), tostring(info.id)))
    row.remove:SetText(W("remove"))
    row:Show()
  end
  for i = #S.ignored + 1, #f.rows do f.rows[i]:Hide() end
  f.empty:SetText(#S.ignored == 0 and W("noIgnored") or "")
  f:Show()
  return f
end
