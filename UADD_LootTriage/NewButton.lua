-- UADD - LootTriage: the word on the two buttons that open its What's New.
--
-- The What's New dialog itself is never touched: it stays the addon's English, on, held and off (lesson 43).
--
-- The two buttons that open it (its window's, and the one on the game's Settings panel) show the game's
-- GAMEMENU_NEW_BUTTON, which ClassicUA alone leaves English. On these two buttons only, our word shows while
-- that global is English (LiteMount's globals, LESSONS3); the global itself is never written, and one that is
-- already Cyrillic is left as it is. The hold key and off give its text back. Our font stays on through the
-- window button's hover, which sets the label's font object again (lesson 32), and that button is sized to its
-- word as the addon sizes it (lesson 5).

local _, ns = ...
local U = UADD
local N = {}
ns.NewButton = N

local find = string.find
local watched = {}
local CYR = "[\208-\210]"
local busy = false         -- our own font change: the label's font hooks stay out
local NEW_UK = "Що нового"
local labels = {}          -- a button's label -> { button, fit = size the button to it, en = the English we swapped }

local function Wanted() return ns.WordsWanted() end

-- The global's text while it is English, else nil.
local function GlobalEnglish()
    local g = rawget(_G, "GAMEMENU_NEW_BUTTON")
    if type(g) ~= "string" or g == "" or find(g, CYR) then return nil end
    return g
end

local Label
local function Relabel(lab) if not busy then pcall(Label, lab) end end   -- the addon set its font again (its hover)

local function FontOn(lab) busy = true local ok, yes = pcall(ns.Screen.Font, lab) busy = false return ok and yes end
local function FontOff(lab) busy = true pcall(ns.Screen.Unfont, lab) busy = false end

local function Size(l, lab)
    if l.fit and l.button.SetWidth then l.button:SetWidth(18 + 5 + (lab:GetStringWidth() or 0)) end
end

-- One label: ours (our font read back) or its English, as wanted now; only while it shows one of the two.
Label = function(lab)
    local l = labels[lab]
    if not l or (lab.IsForbidden and lab:IsForbidden()) then return end
    local t, en = lab:GetText(), GlobalEnglish()
    if Wanted() and en and (t == en or t == NEW_UK) then
        if t == en then l.en = en lab:SetText(NEW_UK) end
        FontOn(lab)
        local ok, path = pcall(lab.GetFont, lab)
        if not (ok and U.IsCyrFont(path)) then          -- no Cyrillic in its font: its English
            lab:SetText(l.en or en)
            FontOff(lab)
        end
        Size(l, lab)
    elseif t == NEW_UK then
        lab:SetText(l.en or en or rawget(_G, "GAMEMENU_NEW_BUTTON"))   -- the English first, then its font
        FontOff(lab)
        Size(l, lab)
    end
end

local function AddLabel(button, lab, fit)
    if type(lab) ~= "table" or labels[lab] or not lab.GetText or not lab.SetText then return end
    labels[lab] = { button = button, fit = fit }
    if not U.Locked(lab) then                                   -- its hover sets the label's font again
        hooksecurefunc(lab, "SetFontObject", Relabel)
        hooksecurefunc(lab, "SetFont", Relabel)
    end
    Label(lab)
end

-- Its window's button has its own label (`label`), sized to it.
function N.Watch(button)
    if type(button) ~= "table" or watched[button] then return end
    watched[button] = true
    if type(button.label) == "table" then AddLabel(button, button.label, true) end
end

-- The panel's own button for it sits on the panel's Defaults button.
function N.Install()
    local list = SettingsPanel and SettingsPanel.Container and SettingsPanel.Container.SettingsList
    local d = list and list.Header and list.Header.DefaultsButton
    if not d then return end
    for _, c in ipairs(U.Children(d)) do
        local ok, yes = pcall(function()
            return not (c.IsForbidden and c:IsForbidden()) and c.GetText and c:GetText() == GAMEMENU_NEW_BUTTON
        end)
        if ok and yes then
            watched[c] = true
            local ok2, lab = pcall(c.GetFontString, c)      -- its template's label (a fixed width)
            if ok2 then AddLabel(c, lab, false) end
        end
    end
end

function N.Sync()
    for lab in pairs(labels) do pcall(Label, lab) end
end
