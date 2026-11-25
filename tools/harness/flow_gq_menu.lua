-- Lua helpers for flow_gq_menu.py (after flow_gq.lua, before the game starts): the game's shared dropdown list, as
-- its UIDropDownMenu draws it (rows reused, all hidden and redrawn at each open, a row keeps the font it had), and
-- what GearQuest's right-click menu, copy box and notices show. The list's font is taken as one without Cyrillic.
local H = HARNESS
local M = H.gq
local CYR = "[\208-\211][\128-\191]"
local ROW = "GameFontHighlightSmallLeft"
if not rawget(_G, ROW) then CreateFont(ROW):SetFont("Fonts\\FRIZQT__.TTF", 10, "") end

local function List()
    local list = rawget(_G, "DropDownList1")
    if not list then
        list = CreateFrame("Button", "DropDownList1", UIParent)
        list:SetPoint("CENTER")
        list:Hide()
        list.numButtons = 0
    end
    return list
end
function UIDropDownMenu_CreateInfo() return {} end
function UIDropDownMenu_Initialize(frame, fn)
    frame.initialize = fn
    List():Hide()
end
function UIDropDownMenu_AddButton(info)
    local list = List()
    list.numButtons = list.numButtons + 1
    local name = "DropDownList1Button" .. list.numButtons
    local b = rawget(_G, name)
    if not b then
        b = CreateFrame("Button", name, list)
        b:SetPoint("TOP")
        _G[name .. "NormalText"] = b:CreateFontString(name .. "NormalText", "ARTWORK", ROW)
        _G[name .. "NormalText"]:SetPoint("LEFT")
    end
    _G[name .. "NormalText"]:SetText(info.text)
    b.func = info.func
    b:Show()
end
function ToggleDropDownMenu(_, _, frame)
    local list = List()
    list:Hide()
    list.numButtons = 0
    for i = 1, 8 do
        local b = rawget(_G, "DropDownList1Button" .. i)
        if b then b:Hide() end
    end
    frame:initialize(1)
    list:Show()
end

function M.hunt(name)
    GearQuest.Log:ShowHuntRowMenu({ id = 1, name = name })
    M.wait(0.1)
end
-- Another addon's menu, with these rows.
function M.otherMenu(a, b)
    local f = rawget(_G, "ZorpMenu") or CreateFrame("Frame", "ZorpMenu", UIParent)
    UIDropDownMenu_Initialize(f, function()
        for _, t in ipairs({ a, b }) do UIDropDownMenu_AddButton({ text = t }) end
    end, "MENU")
    ToggleDropDownMenu(1, nil, f, "cursor", 0, 0)
end
function M.hideMenu() List():Hide() end
function M.copy(name) GearQuest.Log:CopyHuntName({ id = 1, name = name }) end
function M.edit()
    local e = GearQuest.Log.copyNameBox.edit
    return e:GetText()
end
function M.notice(key) GearQuest.Orders:ShowNotice(GearQuest.L[key]) end
function M.noticeFits()
    local n = GearQuest.Orders.notice
    return math.abs(n:GetWidth() - math.max(240, math.min(520, n.text:GetStringWidth() + 56))) < 0.01
end

local function Parts()
    local out = {}
    for i = 1, List().numButtons do out["M:" .. i] = rawget(_G, "DropDownList1Button" .. i .. "NormalText") end
    local box, n = GearQuest.Log.copyNameBox, GearQuest.Orders.notice
    if box then out["C:title"] = box.title end
    if n then out["N:text"] = n.text end
    return out
end
function M.parts()
    local out = {}
    for k, fs in pairs(Parts()) do out[k] = fs:GetText() end
    return out
end
-- Cyrillic only on our face, English only on its own; no box on screen.
function M.partFonts()
    local bad = {}
    for k, fs in pairs(Parts()) do
        local t = fs:GetText() or ""
        local c, ours = t:find(CYR) ~= nil, UADD.IsCyrFont((fs:GetFont())) and true or false
        if c ~= ours and t ~= "" then bad[#bad + 1] = k .. ": " .. t .. " (" .. tostring((fs:GetFont())) .. ")" end
    end
    local boxes = H.cyrBoxes(200)
    for _, l in pairs(type(boxes) == "table" and boxes or {}) do bad[#bad + 1] = "box " .. tostring(l) end
    return bad
end
