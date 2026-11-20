-- Not Auto Potion. A stand-in for tools/harness/flow_autopotion.py, shaped like Auto Potion's settings
-- pages (FrameXML/*OptionsFrame.lua), its chat lines and its Bindings.lua.
-- It holds none of Auto Potion's English (all rights reserved): the flow reads the real texts from the
-- installed addon (tools/make_ap_text.py texts) and hands them in as AP_STANDIN_EN, by hash, before the
-- game starts. A hash with no text gets a made-up one. Spell names, the author and the link are made up.
local addonName = ...
local EN = rawget(_G, "AP_STANDIN_EN") or {}
local function L(h) return EN[h] or ("Zq text " .. h) end

local S = { texts = {}, spec = {}, boxes = {}, pages = {}, bindings = {}, bindEn = {} }
AutoPotionStandIn = S
S.PURPLE = "|cffb48ef9AutoPotion:|r "
S.RED = "|cffff0000AutoPotion Error:|r "
S.MACROS = { "AutoPotion", "AutoBandage", "AutoFood", "AutoDrink", "AutoManaPotion" }
-- By hash, in S.MACROS order: the five binding names, then their category (Bindings.xml).
local BINDINGS = { "16:49b12489", "17:c766f9d2", "14:cf0dea18", "15:54c58728", "20:802c6b66" }
local CATEGORY = "11:3bb4f737"

-- One text: name -> FontString, and what the flow expects of it (hash, slot values, colour around).
local function Spec(name, fs, hash, args, pre, post)
    S.texts[name] = fs
    S.spec[name] = { hash = hash, args = args or {}, pre = pre, post = post }
end

local function Label(name, parent, font, hash, args, pre, post)
    local fs = parent:CreateFontString(nil, "ARTWORK", font)
    local en = hash and L(hash) or name
    if args and #args > 0 then en = en:format(unpack(args)) end
    fs:SetText((pre or "") .. en .. (post or ""))
    Spec(name, fs, hash, args, pre, post)
    return fs
end

-- A check box (InterfaceOptionsCheckButtonTemplate: its label is .Text); with an icon, its click area
-- reaches past the icon and the label, as Auto Potion sets it; with a tooltip on OnEnter.
local function CheckBox(name, parent, hash, text, icon, tipHash)
    local b = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    if not b.Text then
        b.Text = b:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        b:SetFontString(b.Text)
    end
    b.Text:SetText(hash and L(hash) or text)
    Spec(name, b.Text, hash)
    if icon then
        b.icon = b:CreateTexture()
        b:SetHitRectInsets(0, -(6 * 2 + 28 + b.Text:GetStringWidth()), 0, 0)
    end
    if tipHash then
        b:HookScript("OnEnter", function()
            GameTooltip:SetOwner(b, "ANCHOR_TOPRIGHT")
            GameTooltip:SetText(L(tipHash), nil, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        b:HookScript("OnLeave", function() GameTooltip:Hide() end)
        S.spec[name].tip = tipHash
    end
    S.boxes[name] = b
    return b
end

-- A settings page: a canvas under InterfaceOptionsFramePanelContainer, a scroll frame, its content.
local function Page(suffix)
    local panel = CreateFrame("Frame", addonName .. suffix, InterfaceOptionsFramePanelContainer)
    panel:Hide()
    local scroll = CreateFrame("ScrollFrame", addonName .. suffix .. "ScrollFrame", panel, "UIPanelScrollFrameTemplate")
    local content = CreateFrame("Frame", nil, scroll)
    S.pages[suffix == "" and "Info" or suffix] = panel
    return content
end

local function Build()
    S.uaddAtBuild = rawget(_G, "UADD") ~= nil
    -- Info page: title, version, author, copy hint, a green "installed" mark, a link (an edit box).
    local info = Page("")
    Label("title", info, "GameFontNormalHuge", "20:55251b28")
    S.texts.title:SetFont("Fonts\\FRIZQT__.TTF", 18, "OUTLINE")      -- an outlined one: kept as it is
    Label("version", info, "GameFontHighlight", "10:4d1075a3", { "0.9.7" })
    Label("author", info, "GameFontHighlight", "17:14e192a4", { "Quixwright" })
    Label("copy", info, "GameFontNormalSmall", "26:65c53d41", { L("6:ac9c15c8") })
    Label("installed", info, "GameFontNormal", "9:57fa4ae5", nil, "|cff00ff00", "|r")
    Label("how", info, "GameFontNormal", "12:7c705686")
    Label("madeup", info, "GameFontNormal", nil)                     -- made-up English: stays whole
    S.texts.madeup:SetText("Zorp settings wobble")
    local link = CreateFrame("EditBox", nil, info)
    link:SetAutoFocus(false)
    link:SetText("https://example.invalid/quix")
    S.link = link
    -- Heal page: a header, a check box with a tooltip, check boxes with icons, the priority footer.
    local heal = Page("Heal")
    Label("behaviour", heal, "GameFontNormalHuge", "15:abb9c630")
    CheckBox("stopcast", heal, "33:20fb2d31", nil, false, "19:8529a663")
    CheckBox("serum", heal, "16:779bf91e", nil, true)
    CheckBox("soulburn", heal, "20:e2bf1f5a", nil, true)
    CheckBox("spell", heal, nil, "Glimmering Quixberry", true)       -- a made-up spell name: not ours
    local footer = CreateFrame("Frame", nil, heal)
    Label("current", footer, "GameFontNormal", "16:657f430a")
    local reset = CreateFrame("Button", nil, footer, "UIPanelButtonTemplate")
    reset:SetText(L("16:1ead0710"))
    local fs = reset:GetFontString()
    reset:SetWidth(math.max(120, fs:GetStringWidth() + 20))
    Spec("reset", fs, "16:1ead0710")
    S.reset = reset
    -- Food page: a header and a check box with a tooltip (a page opened later in the flow).
    local food = Page("Food")
    Label("foodTitle", food, "GameFontNormalHuge", "13:6a67032f")
    CheckBox("buffFood", food, "17:dc897e74", nil, false, "134:750b46f4")
    -- The other pages: their headers.
    Label("manaTitle", Page("ManaPotion"), "GameFontNormalHuge", "13:f9f7a43b")
    Label("drinkTitle", Page("Drink"), "GameFontNormalHuge", "14:dc6fab1f")
    Label("bandageTitle", Page("Bandage"), "GameFontNormalHuge", "16:ad8d3349")
end

-- Bindings.lua: the binding names, set while it loads.
for i, macro in ipairs(S.MACROS) do
    local en = L(BINDINGS[i])
    _G["BINDING_NAME_MACRO " .. macro] = en
    S.bindEn[i] = en
    S.bindings[i] = { en, L(CATEGORY) }     -- Bindings.xml: command, category
end
S.categoryEn = L(CATEGORY)

-- Another addon's frame with a tooltip of the same English: never ours.
local function Other()
    local o = CreateFrame("Button", "APStandInOther", UIParent)
    o:SetScript("OnEnter", function()
        GameTooltip:SetOwner(o, "ANCHOR_TOPRIGHT")
        GameTooltip:SetText(L("19:8529a663"))
        GameTooltip:Show()
    end)
    o:SetScript("OnLeave", function() GameTooltip:Hide() end)
    S.other = o
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == addonName then
        Build()
        Other()
    elseif event == "PLAYER_LOGIN" then
        -- The class spell rows of the Heal page come at login.
        CheckBox("loginSpell", S.pages.Heal, nil, "Quixotic Mending", true)
    end
end)

-- What the flow drives.
function S.Show(page, on) S.pages[page]:SetShown(on) end
function S.Hover(name) local b = name and S.boxes[name] or S.other b:GetScript("OnEnter")(b) end
function S.Leave(name) local b = name and S.boxes[name] or S.other b:GetScript("OnLeave")(b) end
function S.SetInstalled() S.texts.installed:SetText("|cff00ff00" .. L("9:57fa4ae5") .. "|r") end
-- Its chat lines: after its purple name, after its red error name (a macro name in the slot), and the
-- two answers of /ap it prints alone.
function S.Purple(hash, ...) print(S.PURPLE .. L(hash):format(...)) end
function S.Error(macro)
    local a, b = L("79:aa814ae1"):match("^(.-)%%s(.*)$")
    print(S.RED .. (a or "") .. tostring(macro) .. (b or ""))
end
function S.ResetDone() print(L("17:bf4baa09")) end
function S.BadOption(word) print((L("18:9531cf37"):gsub("%%s$", "")) .. word) end
function S.Plain(hash) print(L(hash)) end
