-- Step 14 of flow_ofa.py (after flow_ofa.lua, whose helpers it uses): OneForAll's kept hidden pages (lesson 48).
-- It builds each page and each dungeon, pet or recipe view once and keeps it hidden; one walk over all of them
-- passed the walker's 4000 frames, so a page made later stayed English. Also its dressed labels ("Diet:", a text
-- in one colour) and its tab bar laid out again for our longer tab names.
local H = HARNESS
local M = H.ofa
local R, h = M.R, M.h
local Cyr, CyrFont, Res, Key, Uadd = h.Cyr, h.CyrFont, h.Res, h.Key, h.Uadd

local EN, UK = "Wobble pages", "Хиткі сторінки"
local EN2, UK2 = "Plonk pages", "Сторінки плонку"

R.pages = function()
    local out = {}
    M.inject()
    local ns = H.ns.UADD_OneForAll
    local W = ns.Screen.W
    ns.OFA[Key(EN)], ns.OFA[Key(EN2)] = UK, UK2
    ns.Words.Forget()
    -- 50 kept pages of 90 frames each, all hidden (4550 frames); the first and third with a text of ours
    local kept = {}
    for i = 1, 50 do
        local p = CreateFrame("Frame", nil, OneForAllFrame)
        p:Hide()
        for _ = 1, 90 do CreateFrame("Frame", nil, p) end
        kept[i] = p
    end
    local first = kept[1]:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    first:SetText(EN)
    local third = kept[3]:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    third:SetText(EN)
    -- the page opened now: made after all of them, shown
    local page = CreateFrame("Frame", nil, OneForAllFrame)
    local function Label(text) local fs = page:CreateFontString(nil, "OVERLAY", "GameFontNormal") fs:SetText(text) return fs end
    local label, colon = Label(EN), Label(EN .. ":")
    local grey, odd = Label("|cff9d9d9d" .. EN .. "|r"), Label("|cff9d9d9d" .. EN .. " gizmo|r")
    -- lesson 13: a profile named like a word of ours, in a colour or with a colon after it
    local oldDB = rawget(_G, "OneForAllDB")
    OneForAllDB = { profiles = { [EN2] = {} } }
    local prof, profColon = Label("|cff00ff00" .. EN2 .. "|r"), Label(EN2 .. ":")
    -- a tab of its bar (_label, _place) and its LayoutTabs as OneForAll's: each label down 13..10 by SetFont of the
    -- font it reads back. Run from a chunk in its folder: the core tells the addon's own call from UADD's by the stack
    local F = OneForAll
    local oldUI, laid, read = rawget(F, "UI"), 0, {}
    local tab = CreateFrame("Button", nil, OneForAllFrame)
    local name = tab:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    do local p, _, fl = name:GetFont() name:SetFont(p, 13, fl) end      -- as its own: the label set to 13 by hand
    tab._label, tab._place = name, function() end
    F.UI = { LayoutTabs = assert(loadstring([[
        local tab, count = ...
        return function()
            count(tab._label:GetFont())
            for _, size in ipairs({ 13, 12, 11, 10 }) do
                local font, _, flags = tab._label:GetFont()
                if font then tab._label:SetFont(font, size, flags) tab._place(0, 0) end
            end
        end]], "@AddOns/OneForAll/UI/MainFrame.lua"))(tab, function(p, s) laid, read = laid + 1, { p, s } end) }
    -- its English in its own file again, at the size its layout set last (10), never in ours (lesson 48): as its
    -- layout reads it back when it starts, and after
    local function Own(fs)
        local p, s = fs:GetFont()
        return p ~= nil and not UADD.IsCyrFont(p) and s == 10 and read[1] == p and read[2] == 10
    end
    local function FontOf(fs) local p, s = fs:GetFont() return tostring(p) .. " " .. tostring(s) .. ", read "
        .. tostring(read[1]) .. " " .. tostring(read[2]) end
    name:SetText(EN)
    M.wait(0.3)
    ns.Screen.Sync() M.wait(0.2)
    Res(out, "a page made after 4500 kept hidden frames: ours, in a Cyrillic font", label:GetText() == UK and CyrFont(label),
        tostring(label:GetText()))
    Res(out, "a label with a colon after it: ours with the colon", colon:GetText() == UK .. ":", tostring(colon:GetText()))
    Res(out, "a text in one colour: ours, the colour kept", grey:GetText() == "|cff9d9d9d" .. UK .. "|r",
        tostring(grey:GetText()))
    Res(out, "a coloured text with English left: whole English", odd:GetText() == "|cff9d9d9d" .. EN .. " gizmo|r",
        tostring(odd:GetText()))
    Res(out, "a profile name in a colour or with a colon: as typed",
        prof:GetText() == "|cff00ff00" .. EN2 .. "|r" and profColon:GetText() == EN2 .. ":",
        tostring(prof:GetText()) .. " | " .. tostring(profColon:GetText()))
    Res(out, "a tab name of ours: the tab bar laid out again, our Cyrillic font kept over its SetFont",
        name:GetText() == UK and laid >= 1 and CyrFont(name), tostring(laid) .. " " .. tostring(name:GetFont()))
    -- a kept page shown later: only its own frames walked, never a whole walk
    local walks, laters = {}, 0
    local walk, later = W.Walk, W.Later
    W.Walk = function(f) walks[#walks + 1] = f return walk(f) end
    W.Later = function() laters = laters + 1 return later() end
    kept[1]:Show()
    M.wait(0.2)
    kept[1]:Hide() kept[1]:Show()
    M.wait(0.2)
    W.Walk, W.Later = walk, later
    Res(out, "a kept page shown later: ours", first:GetText() == UK and CyrFont(first), tostring(first:GetText()))
    Res(out, "a kept page shown, hidden and shown again: walks only itself, no whole walk",
        #walks == 2 and walks[1] == kept[1] and walks[2] == kept[1] and laters == 0, #walks .. " walks, " .. laters .. " whole")
    -- its own SetScript("OnShow") after our hook drops it (lesson 2): the next walk hooks again
    kept[3]:SetScript("OnShow", function() end)
    ns.Screen.Sync() M.wait(0.2)
    kept[3]:Show()
    M.wait(0.2)
    Res(out, "a kept page whose OnShow it set again after our hook: ours when shown", third:GetText() == UK,
        tostring(third:GetText()))
    -- the hold key and its release: the English, then ours, each time the bar laid out again. Its LayoutTabs read
    -- ours back and set it by SetFont: the English still gets its own file back, at its latest size (UADD/FontReadBack.lua)
    local before = laid
    M.key(true)
    Res(out, "hold: the tab's English in its own file at its latest size, the bar laid out again",
        name:GetText() == EN and laid > before and Own(name), tostring(laid) .. " " .. FontOf(name))
    before = laid
    M.key(false)
    Res(out, "release: ours in a Cyrillic font, the bar laid out again", name:GetText() == UK and CyrFont(name)
        and laid > before, tostring(laid) .. " " .. tostring(name:GetText()))
    before = laid
    Uadd("off")
    Res(out, "off: English back on the pages", label:GetText() == EN and first:GetText() == EN
        and colon:GetText() == EN .. ":" and name:GetText() == EN, tostring(label:GetText()))
    Res(out, "off: the tab bar laid out again for the English", laid > before, laid)
    Res(out, "off: the tab's English in its own file at its latest size", Own(name), FontOf(name))
    Uadd("on")
    ns.Screen.Sync() M.wait(0.2)
    Res(out, "on again: ours", label:GetText() == UK and Cyr(first:GetText()) and CyrFont(name), tostring(label:GetText()))
    F.UI, OneForAllDB = oldUI, oldDB
    for _, p in ipairs(kept) do p:Hide() end
    page:Hide() tab:Hide()
    return out
end
