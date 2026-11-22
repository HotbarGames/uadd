-- Harness stand-in for DeleteCheapestItem Reloaded: not the addon. Same frame names, templates and SetText
-- calls; every English text comes at run time from DCIStandInFeed (tools/harness/dci_feed.py).
-- S.Open(st)            show DCIFrame and draw it for st (as S.Update)
-- S.Update(st)          UpdateDCIFrame: contents made on the first call, then rows and the two top texts
--                       st = {mode="bags"|"loot"|"quest"|"accept", items={{name,link,quality,count,vendor,auction,id}},
--                             free, freeAfter, receive, recv={name,link,vendor,auction}, qty, red, full, bind,
--                             merchant, both, compare}
-- S.OpenIgnored(list)   (Ignored.lua) DCI_IgnoredItemsFrame, made on first open, rows from list = {{id=, name=}}
-- S.Tip()               the info button's GameTooltip lines
-- S.RowTip(i, which)    row i: "icon" (GameTooltip + DCI_SecondTooltip) or "delete" (DCI_SecondTooltip)
-- S.Broker(tip)         the Broker launcher's tooltip lines into tip (GameTooltip by default)
-- S.Chat(kind, arg)     a chat line: "ignore" (arg: a name), "reset", "delete" (arg: the item text)
-- S.Slash(msg)          the slash handler's own lines: "debug", "debug on", "debug off", anything else: the help
-- S.Delete(text, link)  the popup DCI_RELOADED_DELETE_ITEM through StaticPopup_Show
-- Config.lua adds S.BuildConfig, S.OpenConfig, S.ConfigTexts, S.SetProfiles, S.ProfilePopup, S.ProfileStatus.
-- S.F is the feed, S.T[role] one English text (roles below), S.Rows the 100 row tables.
local addonName = ... or "DeleteCheapestItem"
local F = DCIStandInFeed or { fn = {}, page = {}, choices = {}, title = "", version = "0", slash = {}, aux = {} }
local S = {}
DCIStandIn = S
S.F = F
local L = setmetatable({}, { __index = function(_, k) return k end })  -- private, keyed by the English
local ROLES = {
  SaveIgnoredItem = { "chatIgnore" }, ResetIgnoredItem = { "chatReset" }, ConfirmAndDeleteBagItem = { "chatDelete" },
  RefreshIgnoredItems = { "remove", "itemId", "noIgnored" }, ShowIgnoredItems = { "ignTitle", "ignReset" },
  CreateDCIFrame = { "tipSettings", "tipMaxQ", "tipConfirmQ", "tipConfirm", "tipAuction", "tipFrom", "tipVendorP",
    "tipAuctionP", "tipBestP", "tipCompare", "tips", "tip1", "tip2", "tip3", "tip4" },
  UpdateDCIFrame = { "vendor", "auction", "ignoreTip", "sell", "sellTip", "deleteTip", "none", "infoHint", "looting",
    "caution", "red", "cheapest", "questRewards", "willSlot", "willSlots", "items", "total", "choose", "haveSlot",
    "haveSlots", "questSpace" },
  CreateProfileControls = { "profiles", "profHelp", "copyFrom", "deleteUnused", "noCopy", "noDelete", "enter1",
    "created", "create", "enter2" },
  ConfirmProfileAction = { "popCopy", "popReset", "popDelete", "popShared" },
  InitializeBroker = { "brokerLeft", "brokerRight", "brokerCtrl" },
}
local T = {}
for fn, names in pairs(ROLES) do
  for i, role in ipairs(names) do T[role] = (F.fn[fn] or {})[i] or "" end
end
S.T, S.ROLES = T, ROLES
local function W(role) return L[T[role]] end
local function G(name, alt) local v = rawget(_G, name) if v == nil then return alt end return v end
local isForever = true
local GOLD = "|cffffd200"
local QCOL = { "9d9d9d", "ffffff", "1eff00", "0070dd", "a335ee", "ff8000" }

local function Money(c)
  c = math.floor(tonumber(c) or 0)
  local f = G("GetMoneyString")
  if f then return f(c) end
  return string.format("%d|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t %d|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t %d|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t",
    math.floor(c / 10000), math.floor(c / 100) % 100, c % 100)
end
S.Money = Money

local function Say(msg, colour)
  DEFAULT_CHAT_FRAME:AddMessage("|cff7f7fff" .. "[" .. F.title .. "] " .. (colour or "|cffffffff") .. msg .. "|r")
end

local function CreateWindowFrame(name)
  local f = CreateFrame("Frame", name, UIParent, isForever and "DefaultPanelFlatTemplate" or "BasicFrameTemplateWithInset")
  f.CloseButton = f.CloseButton or CreateFrame("Button", nil, f, "UIPanelCloseButtonDefaultAnchors")
  f.titleParent = f.TitleContainer or f
  return f
end

local DCIFrame = CreateWindowFrame("DCIFrame")
DCIFrame:SetSize(290, 240)
DCIFrame:Hide()
S.Rows = {}
S.state = { mode = "bags", items = {}, free = 0 }

local function CreateDCIFrame()
  local second = CreateFrame("GameTooltip", "DCI_SecondTooltip", DCIFrame, "GameTooltipTemplate")
  local title = DCIFrame.titleParent:CreateFontString("DCI_TitleText", "OVERLAY", "GameFontNormal")
  title:SetText(F.title)
  CreateFrame("Frame", "DCI_DragFrame", DCIFrame)
  local info = CreateFrame("Button", "DCI_TitleInfoButton", DCIFrame, "UIPanelInfoButton")
  info:SetSize(23, 23)
  info:SetScript("OnEnter", function() S.Tip() end)
  info:SetScript("OnLeave", function() GameTooltip:Hide() end)
  DCIFrame:CreateFontString("DCI_TopSection_Text1", "OVERLAY", "GameFontHighlightSmall")
  DCIFrame:CreateFontString("DCI_TopSection_Text2", "OVERLAY", "GameFontDisableSmall")
  local inset = CreateFrame("ScrollFrame", "DCI_BottomSection_Inset", DCIFrame, "InsetFrameTemplate3")
  local scroll = CreateFrame("ScrollFrame", "DCI_ScrollParent", inset, "UIPanelScrollFrameTemplate")
  local child = CreateFrame("Frame", "DCI_ScrollChild", scroll)
  scroll:SetScrollChild(child)
  for n = 1, 100 do
    local r = { frame = CreateFrame("Frame", "DCI_Item" .. n, child) }
    r.frame:SetSize(258, 44)
    r.icon = CreateFrame("Button", "DCI_ItemIcon" .. n, r.frame)
    r.icon:SetSize(38, 38)
    r.count = r.icon:CreateFontString("DCI_ItemIconCountText" .. n, "OVERLAY", "NumberFontNormal")
    for _, k in ipairs({ "TopLeft", "TopRight", "BottomLeft", "BottomRight" }) do
      r[k] = r.frame:CreateFontString("DCI_ItemInfo_Text" .. k .. n, "OVERLAY", "GameFontNormal")
    end
    r.TopRight:SetText(" ")
    r.delete = CreateFrame("Button", "DCI_DeleteButton" .. n, r.frame, "UIPanelButtonTemplate")
    r.delete:SetText(G("DELETE", ""))
    r.delete:SetSize(60, 32)
    r.icon:SetScript("OnEnter", function() S.RowTip(n, "icon") end)
    r.delete:SetScript("OnEnter", function() S.RowTip(n, "delete") end)
    r.frame:Hide()
    S.Rows[n] = r
  end
  local ign = CreateFrame("Button", "DCI_IgnoreButton", DCIFrame, "UIPanelSquareButton")
  ign:SetSize(44, 44)
  S.second = second
end

local function DrawRow(r, item, st)
  r.item = item
  r.frame:Show()
  r.count:SetText((item.count or 1) > 1 and tostring(item.count) or "")
  if st.both then
    r.TopLeft:SetText(W("vendor"))
    r.TopRight:SetText(Money(item.vendor))
    r.BottomLeft:SetText(W("auction"))
    r.BottomRight:SetText(item.auction and Money(item.auction) or "- ")
  else
    r.TopLeft:SetText("|c" .. "ff" .. (QCOL[(item.quality or 1) + 1] or "ffffff") .. (item.name or "") .. "|r")
    r.TopRight:SetText(" ")
    r.BottomLeft:SetText((st.compare or 1) == 1 and W("vendor") or W("auction"))
    r.BottomRight:SetText(Money((st.compare or 1) == 1 and item.vendor or (item.auction or item.vendor)))
  end
  r.delete:SetText(st.merchant and W("sell") or G("DELETE", ""))
  r.tip = st.merchant and W("sellTip") or W("deleteTip")
end

local function Fits(fs)
  -- the real addon reads GetSize(); a one-point font string's size is its text's width, which the stubs
  -- give only through GetStringWidth, so take the larger
  local w = math.max(fs:GetSize() or 0, fs:GetStringWidth() or 0)
  return w + (isForever and 24 or 0) <= (DCIFrame:GetWidth() or 290)
end

local function TopTexts(st)
  local t1, t2 = DCI_TopSection_Text1, DCI_TopSection_Text2
  local text1, text2
  if #(st.items or {}) == 0 and st.mode == "bags" then
    text1, text2 = "|cffdddddd" .. W("none") .. "|r", "|cff666666" .. W("infoHint") .. "|r"
  elseif st.mode == "loot" or st.mode == "quest" then
    local verb = st.mode == "loot" and W("looting") or W("questRewards")
    if st.mode == "loot" then
      text2 = st.red and string.format(W("caution"), "|cffaa0000" .. W("red") .. "|r") or W("cheapest")
    else
      local n = st.freeAfter or 0
      text2 = string.format(n == 1 and W("willSlot") or W("willSlots"), (n <= 0 and "|cffff0000" or GOLD) .. n .. "|r")
    end
    local recv = st.recv or {}
    if (st.receive or 1) > 1 then
      verb = string.format(verb, string.format(W("items"), GOLD .. st.receive .. "|r"))
      text1 = verb .. " (" .. string.format(W("total"), Money(recv.vendor)) .. ")"
      if st.full then text2 = W("choose") end
    else
      local value
      if st.bind then
        value, text2 = G("ITEM_BIND_QUEST", ""), W("choose")
      elseif (st.compare or 1) == 1 then
        value = W("vendor") .. ": " .. Money(recv.vendor)
      else
        value = W("auction") .. ": " .. Money(recv.auction or recv.vendor)
      end
      local name, link, qty = recv.name or "", recv.link or recv.name or "", st.qty or ""
      local limit = #name
      for _ = 1, 25 do
        local short = link
        if limit < #name then short = link:gsub(name:gsub("%p", "%%%0"), (string.sub(name, 1, limit) .. "..."):gsub("%%", "%%%%")) end
        text1 = string.format(verb, qty .. short) .. "  (" .. value .. ")"
        t1:SetText(text1)
        if Fits(t1) then break end
        limit, text1 = limit - 1, nil
      end
      text1 = text1 or (string.format(verb, qty .. string.sub(name, 1, 15)) .. "...  (" .. value .. ")")
    end
  else
    local n = st.free or 0
    if n == 1 then
      text1 = string.format(W("haveSlot"), GOLD .. n .. "|r")
    else
      text1 = string.format(W("haveSlots"), (n == 0 and "|cffff0000" or GOLD) .. n .. "|r")
    end
    text2 = st.mode == "accept" and W("questSpace") or W("cheapest")
  end
  t1:SetText(text1)
  t2:SetText(text2 or "")
end

function S.Update(st)
  if st then S.state = st end
  st = S.state
  if not S.second then CreateDCIFrame() end
  for n, r in ipairs(S.Rows) do
    local item = (st.items or {})[n]
    if item then DrawRow(r, item, st) else r.frame:Hide() end
  end
  TopTexts(st)
end

function S.Open(st)
  DCIFrame:Show()
  S.Update(st)
end

function S.Tip()
  local db = S.db or {}
  GameTooltip:SetOwner(DCIFrame, "ANCHOR_NONE")
  GameTooltip:AddDoubleLine(W("tipSettings"), "v" .. F.version)
  GameTooltip:AddLine(" ")
  local q = S.QualityChoices and S.QualityChoices() or {}
  GameTooltip:AddDoubleLine(W("tipMaxQ"), q[(db.MaxQuality or 1) + 1] or "")
  if db.ConfirmMinQuality then
    GameTooltip:AddDoubleLine(W("tipConfirmQ"), q[db.ConfirmMinQuality + 1] or "")
  else
    GameTooltip:AddDoubleLine(W("tipConfirm"), G("NEVER", ""))
  end
  local using = db.UseAuctionPrices and db.AuctionSource
  GameTooltip:AddDoubleLine(W("tipAuction") .. (using and (" " .. W("tipFrom")) or ""), using or G("NO", ""))
  if using then
    local opts = { W("tipVendorP"), W("tipAuctionP"), W("tipBestP") }
    GameTooltip:AddDoubleLine(W("tipCompare"), opts[db.CompareByPrice or 1])
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine(W("tips"))
  for i = 1, 4 do GameTooltip:AddLine("* " .. W("tip" .. i)) end
  GameTooltip:Show()
end

function S.RowTip(i, which)
  local r = S.Rows[i]
  if not r or not r.item then return end
  if which == "icon" then
    GameTooltip:SetOwner(r.icon, "ANCHOR_RIGHT")
    if GameTooltip.SetItemByID then GameTooltip:SetItemByID(r.item.id or 0) end
    GameTooltip:Show()
    S.second:SetOwner(DCIFrame, "ANCHOR_NONE")
    S.second:SetText(W("ignoreTip"), 1, 1, 1, 0.75)
  else
    S.second:SetOwner(DCIFrame, "ANCHOR_NONE")
    S.second:SetText(r.tip or "", 1, 0, 0, 1)
  end
  S.second:Show()
end

S.Window = CreateWindowFrame  -- for Ignored.lua

function S.Broker(tip)
  tip = tip or GameTooltip
  tip:AddLine(F.title)
  tip:AddLine(W("brokerLeft"), 1, 1, 1)
  tip:AddLine(W("brokerRight"), 1, 1, 1)
  tip:AddLine(W("brokerCtrl"), 1, 1, 1)
end

function S.Chat(kind, arg)
  if kind == "ignore" then Say(W("chatIgnore") .. tostring(arg))
  elseif kind == "reset" then Say(W("chatReset"))
  else Say(W("chatDelete") .. tostring(arg or "")) end
end

function S.Slash(msg)
  local cmd = (msg or ""):lower():match("^%s*(.-)%s*$")
  local d, h = F.slash[1] or { "", "", "" }, F.slash[2] or { "" }
  if cmd:find("^debug") then
    if cmd == "debug" then S.debug = not S.debug else S.debug = cmd:find("on$") ~= nil end
    Say(d[1] .. (S.debug and d[2] or d[3]))
  else
    Say(h[1])
  end
end

function S.Delete(text, link)
  StaticPopupDialogs["DCI_RELOADED_DELETE_ITEM"] = {
    text = G("DELETE_ITEM", "") .. "\n\n%s\n\n", button1 = G("YES", ""), button2 = G("NO", ""),
    OnAccept = function(_, data) if data then data() end end,
    timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3, showAlert = true,
  }
  return StaticPopup_Show("DCI_RELOADED_DELETE_ITEM", text, link, function() end)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(_, _, name)
  if name ~= addonName then return end
  SLASH_DCI1 = "/dci"
  SlashCmdList["DCI"] = S.Slash
  if S.BuildConfig then S.BuildConfig() end
end)
