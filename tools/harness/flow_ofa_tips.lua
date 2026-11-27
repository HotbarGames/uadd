-- Step 13 of flow_ofa.py (after flow_ofa.lua, whose helpers it uses): the lines OneForAll fills or glues for its
-- tooltips, its History and its dungeon tracker.
local H = HARNESS
local M = H.ofa
local R, h = M.R, M.h
local Tip1, Plain, Cyr, CyrFont, Res, Key, Uadd = h.Tip1, h.Plain, h.Cyr, h.CyrFont, h.Res, h.Key, h.Uadd

-- Step 13: tooltip lines that OneForAll fills or glues before they are drawn (a head and names, numbers in a text,
-- its "OFA" mark with an arrow and a grey part, two words with a slash, a History row): each through a real
-- tooltip, whole Ukrainian or whole English; the same line from other code, and off, stay English.
R.tips = function()
    local out = {}
    M.inject()
    local S, ns = OneForAllStandIn, H.ns.UADD_OneForAll
    local T = S.T
    local A, oldTip, dungeons = UADD.UALL, T.tip, rawget(OneForAll, "DUNGEONS")
    local zone, npc, item, spell = A.Zone, A.Npc, A.Item, A.Spell
    local Names = { ["Sprocket Vale"] = "Долина зубчиків", ["Gizmo Plonker"] = "Плонкач гаджетів",
        ["Old Wobbler"] = "Старий хитун", ["Sprocket Hat"] = "Капелюх зубчика", ["Plonk Shield"] = "Щит плонку",
        ["Pattern: Sprocket Hat"] = "Викрійка: Капелюх зубчика" }
    A.Zone = function(n) return n == "Sprocket Vale" and Names[n] or nil end
    A.Npc = function(n) return (n == "Gizmo Plonker" or n == "Old Wobbler") and Names[n] or nil end
    A.Item = function(n) return (n == "Sprocket Hat" or n == "Pattern: Sprocket Hat") and Names[n] or nil end
    A.Spell = function(n) return n == "Plonk Shield" and Names[n] or nil end
    OneForAll.DUNGEONS = { { name = "Sprocket Vale" } }
    ns.Words.Forget()
    local function Mine(line) T.tip = line S.Tip() local t = Tip1() GameTooltip:Hide() return t end
    local function Other(line)
        GameTooltip:SetOwner(UIParent) GameTooltip:AddLine(line) GameTooltip:Show()
        local t = Tip1()
        GameTooltip:Hide()
        return t
    end
    local function Whole(s)                                -- Ukrainian, and no English word left
        local p = Plain(s):gsub("|T[^|]*|t", ""):gsub("OFA", "")
        return Cyr(s) and not p:find("%a%a")
    end
    local OFA, UP = "|cffc8961eOFA|r ", "|TInterface\\Plonk\\icon_arrow_up:16:16:0:0|t "
    local ours = {
        "Killed after 12:34", "Left-click: target and mark with a skull", "Loot rolls",
        "Click: who rolled what on the loot of this run", "Quests in your log: 1 of 4", "On your wishlist: Sprocket Hat",
        OFA .. UP .. "Upgrade: 4.0%", OFA .. UP .. "Downgrade: 4.0% (overall 2.0%)",
        OFA .. UP .. "Upgrade: 4.0%  |cffb0b0b0(replaces Sprocket Hat)|r",
        "Coordinates: 12.3, 45.6", "Last scan here: 26 |4Min:Min; ago", "Ready again in about 26 |4Min:Min;.",
        "Sort by Level", "Object: Sprocket Hat", "Territory: Neutral", "Flight time: about 2:05", "Flight time: 12:40",
        OFA .. "About the same value as your worn item", OFA .. "|TInterface\\Plonk\\star:14:14|t Wishlist",
    }
    for _, line in ipairs(ours) do
        local t = Mine(line)
        Res(out, "whole Ukrainian: " .. Plain(line):gsub("|T.-|t ", ""), Whole(t), t)
    end
    local function Want(name, line, want) local t = Mine(line) Res(out, name, t == want, t) end
    local head, target = ns.OFA[Key("Drops from:")], ns.OFA[Key("Target:")]
    Want("drops: a boss and a dungeon the sources know", "Drops from: Gizmo Plonker (Sprocket Vale)",
        head .. " Плонкач гаджетів (Долина зубчиків)")
    Want("drops: two and a count", "Drops from: Gizmo Plonker (Sprocket Vale), Old Wobbler (Sprocket Vale) +3",
        head .. " Плонкач гаджетів (Долина зубчиків), Старий хитун (Долина зубчиків) +3")
    Want("target: an NPC the sources know", "Target: Old Wobbler", target .. " Старий хитун")
    Want("target: a player's name kept", "Target: |cff0070ddZorp|r", target .. " |cff0070ddZorp|r")
    Want("target: you", "Target: |cffff4040>> You <<|r", target .. " |cffff4040>> " .. ns.OFA[Key("You")] .. " <<|r")
    -- 6.2.17 missed lines: a spell (the Spell route, not Item), an item mid-line, a vendor or its quartermaster word,
    -- a class from the glossary, a recipe item whole, players' names kept (a class after a twink's name ours).
    local function F(en, ...) return string.format(ns.OFA[Key(en)], ...) end
    local hunter = UADD.Glossary.Text("class.hunter")
    Want("click: a spell through the Spell route", "Click: cast Plonk Shield", F("Click: cast %s", "Щит плонку"))
    Want("click: an item on a hand", "Click: use Sprocket Hat on your main hand",
        F("Click: use %s on your main hand", "Капелюх зубчика"))
    Want("sold by: a vendor the sources know", "Sold by Old Wobbler", F("Sold by %s", "Старий хитун"))
    Want("sold by: its quartermaster word", "Sold by profession quartermaster",
        F("Sold by %s", ns.OFA[Key("profession quartermaster")]))
    Want("level: a class from the glossary", "Level 40 Hunter", F("Level %s %s", "40", hunter))
    Want("a recipe item, whole", "Pattern: Sprocket Hat", "Викрійка: Капелюх зубчика")
    Want("guild: players' names kept", "Guild: Zorp, Pozick Hunt, Smörgi +2",
        ns.OFA[Key("Guild:")] .. " Zorp, Pozick Hunt, Smörgi +2")
    Want("twinks: names kept, a class ours", "Twinks: Zorp (Hunter), Blip",
        ns.OFA[Key("Twinks:")] .. " Zorp (" .. hunter .. "), Blip")
    for _, line in ipairs({ "Click: cast Wobbly Gizmo", "Click: cast ", "Click: cast Sprocket Hat",
        "Click: use Wobbly Gizmo on your off hand", "Click: use  on your main hand", "Sold by Wobbly Gizmo",
        "Sold by wobbly vendors", "Level 40 Wobbly", "Level 40 Hunter wobbly", "Level wobbly Hunter",
        "Pattern: Wobbly Gizmo", "Pattern: ", "Guild: Zorp, wobbly gizmo", "Guild: Zorp   Wobbly gizmo", "Guild: ",
        "Twinks: Zorp (Wobbly)", "Twinks: Zorp (Hunter) wobbly", "Guild: Zorp, Blip +x", "Flight time: about wobbly",
        "Flight time: 2:05 wobbly" }) do
        Want("an unknown piece, whole English: " .. Plain(line), line, line)
    end
    for _, line in ipairs({ "Drops from: Gizmo Plonker (Wobbly Den)", "Drops from: Wobbly Gizmo (Sprocket Vale)",
        "Drops from: Gizmo Plonker (Sprocket Vale), Wobbly Gizmo (Sprocket Vale)", "Drops from: Gizmo Plonker",
        "Drops from: ", "Last scan here: 26 |4Wob:Wobs; ago", "Last scan here: 2 wobble ago", "Coordinates: 1.2, wobble",
        "Drops from: Gizmo Plonker (Sprocket Vale) wobble", "Target: Wobbly Gizmo", "Target: ",
        "Target: |cff0070ddWobbly Gizmo|r", "Target: |cffff4040>> Wobbly <<|r", OFA .. "Wobbly gizmo",
        OFA .. UP .. "Upgrade: 4.0%  |cffb0b0b0(wobbly gizmo)|r", OFA .. UP .. "Upgrade: 4.0% (wobbly gizmo)",
        OFA .. UP .. "Upgrade: 4.0%  |cffb0b0b0(replaces Wobbly Gizmo)|r", OFA .. "|TInterface\\Plonk" }) do
        Want("an unknown piece, whole English: " .. Plain(line), line, line)
    end
    local line = "Drops from: Gizmo Plonker (Sprocket Vale)"
    Res(out, "the same lines from other code stay English", Other(line) == line and Other(ours[1]) == ours[1]
        and Other(ours[7]) == ours[7], Other(line))
    local real, calls = ns.Words.Translate, 0
    ns.Words.Translate = function(s) calls = calls + 1 return real(s) end
    local size = ns.Words.CacheSize()
    for i = 1, 50 do Other("Wobbly plonk: " .. i) Other("OFA " .. i) Other("Level " .. i .. " Beast") end
    ns.Words.Translate = real
    Res(out, "other code's lines: no look-up, the cache as it was", calls == 0 and ns.Words.CacheSize() == size,
        calls .. " calls, " .. ns.Words.CacheSize() - size)
    local Tr = ns.Words.Translate
    local sl = Tr("Rare / Optional")
    Res(out, "two words of ours and a slash", Whole(sl) and sl:find(" / ", 1, true) ~= nil, sl)
    Res(out, "a slash with an unknown word: English", Tr("Rare / Wobbly") == nil and Tr("Wobbly / Optional") == nil, "")
    local row = Tr("23.11. 14:05  |cffffffff12:34|r  |cff59ff73Completed|r")
    Res(out, "a History row: the date and clock kept, the state ours", Whole(row)
        and row:find("23.11. 14:05  |cffffffff12:34|r  |cff59ff73", 1, true) == 1, row)
    local f = CreateFrame("Frame", "OneForAllRunTracker", UIParent)
    local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetText("Rare / Optional")
    M.wait(0.3)
    ns.Screen.Sync() M.wait(0.1)
    Res(out, "its dungeon tracker window (made on first use): ours", sl and fs:GetText() == sl and CyrFont(fs), fs:GetText())
    Uadd("off")
    Res(out, "off: English", Mine(line) == line and Mine(ours[1]) == ours[1] and fs:GetText() == "Rare / Optional",
        Mine(line))
    Uadd("on")
    Res(out, "on again: ours", Whole(Mine(line)), Mine(line))
    A.Npc = function() error("plonk") end
    ns.Words.Forget()
    Res(out, "a names source that fails: whole English", Mine(line) == line, Mine(line))
    A.Zone, A.Npc, A.Item, A.Spell, T.tip, OneForAll.DUNGEONS = zone, npc, item, spell, oldTip, dungeons
    ns.Words.Forget()
    return out
end
