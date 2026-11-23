-- Lua helpers and steps for flow_ofa.py, on the OneForAll stand-in (tools/harness/ofa) with the real UADD_OneForAll.
-- Run before the game starts (it gives the harness a tooltip that keeps its lines, as flow_rts.lua does); the steps
-- look the module up when they run. HARNESS.ofa: inject() puts made-up Ukrainian for the stand-in's made-up English
-- into ns.OFA by "Code."..UADD.Hash(en), as the real data is keyed; R[n]() runs step n and returns a list of
-- {name, ok, detail}. No English of OneForAll here: the stand-in's texts are read from OneForAllStandIn.T.
local H = HARNESS
local M, R = {}, {}
H.ofa, M.R = M, R

-- As in the game, only a tooltip has AddLine (U.Walk leaves a frame with AddLine to U.TipLines).
local create = CreateFrame
CreateFrame = function(kind, name, ...)
    local f = create(kind, name, ...)
    if kind ~= "GameTooltip" then rawset(f, "AddLine", false) end
    return f
end

-- GameTooltip as the game has it (font strings by name), so U.TipLines works.
do
    local tip, name, n = GameTooltip, "GameTooltip", 0
    for i = 1, 8 do
        _G[name .. "TextLeft" .. i] = tip:CreateFontString(name .. "TextLeft" .. i, nil, "GameTooltipText")
        _G[name .. "TextRight" .. i] = tip:CreateFontString(name .. "TextRight" .. i, nil, "GameTooltipText")
    end
    local function Clear(self)
        for i = 1, 8 do _G[name .. "TextLeft" .. i]:SetText(nil) _G[name .. "TextRight" .. i]:SetText(nil) end
        n = 0
        local f = self:GetScript("OnTooltipCleared") if f then f(self) end
    end
    tip.SetOwner = function(self, o) self.__owner = o Clear(self) end
    tip.ClearLines = Clear
    tip.NumLines = function() return n end
    tip.AddLine = function(_, t) if n < 8 then n = n + 1 _G[name .. "TextLeft" .. n]:SetText(t) end end
end
local function Tip1() return GameTooltipTextLeft1:GetText() end

function M.wait(seconds) for _ = 1, math.ceil(seconds / 0.05 - 1e-6) do H.step(0.05) end end
function M.key(down)
    H.keys.SHIFT = down
    H.fire("MODIFIER_STATE_CHANGED", "LSHIFT", down and 1 or 0)
    M.wait(0.4)
end
function M.say(msg) local n = #H.chat OneForAllStandIn.Say(msg) return H.chat[n + 1] end
function M.add(line) local n = #H.chat DEFAULT_CHAT_FRAME:AddMessage(line) return H.chat[n + 1] end

local UK = { title = "Хитка дошка гаджетів", tab = "Вкладка плонку", button = "Плонкнути гаджет",
    late = "Хиткий пізній гаджет", pin = "Шпилька гаджета", say = "Гаджет плонкнуто",
    tip = "Клацніть, щоб плонкнути гаджет", profile = "Зорп" }
local PRE = "|cff66ccffOneForAll:|r "
local S, U, ns, T

local function Plain(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function Cyr(s) return Plain(s):find("[\208\209]") ~= nil end
local function CyrFont(fs) local p = fs and fs:GetFont() return p and U.IsCyrFont(p) and true or false end
local function Res(out, name, ok, d) out[#out + 1] = { name, ok, d ~= nil and tostring(d) or "" } return out end
local function Key(en) return "Code." .. U.Hash(en) end
local function Uadd(cmd) SlashCmdList.UADD("oneforall " .. cmd) M.wait(0.3) end
local function Texts() return { S.title:GetText(), S.tab.fs:GetText(), S.button:GetText() } end
local function Is(list, want) for i, k in ipairs({ "title", "tab", "button" }) do if list[i] ~= want[k] then return false end end return true end
local function Show(list) return table.concat(list, " | ") end

function M.inject()
    S, U, ns = OneForAllStandIn, UADD, H.ns.UADD_OneForAll
    T = S.T
    for k, uk in pairs(UK) do ns.OFA[Key(T[k])] = uk end
    ns.Words.Forget()
    ns.Screen.W.Forget()          -- the walker keeps each text's last answer (none before the made-up data)
    S.Redraw()
    M.wait(0.1)
end

function M.real(en)               -- a real text of the addon's (read by Python at run time) put on the title
    if en == nil then S.Redraw() return false, false end
    local want = ns.OFA[Key(en)]
    if type(want) ~= "string" or (ns.SORT[Key(en)] or "") ~= "" then return false, false end
    S.title:SetText(en)
    return S.title:GetText(), want
end

R[1] = function()
    M.inject()
    local t, out = Texts(), {}
    Res(out, "the walk: title, tab and button are ours", Is(t, UK), Show(t))
    Res(out, "each in a Cyrillic font", CyrFont(S.title) and CyrFont(S.tab.fs) and CyrFont(S.button), "")
    return out
end

R[2] = function()
    M.key(true)
    local held = Texts()
    M.key(false)
    local out = {}
    Res(out, "hold key: English while held", Is(held, T), Show(held))
    Res(out, "hold key: ours again on release", Is(Texts(), UK), Show(Texts()))
    return out
end

R[3] = function()
    local out = {}
    Uadd("off")
    local off, font = Texts(), CyrFont(S.title)
    S.Redraw() M.wait(0.1)
    local again, line = Texts(), M.say(T.say)
    Uadd("on")
    Res(out, "off: English back", Is(off, T), Show(off))
    Res(out, "off: the addon's font back", not font, "")
    Res(out, "off: a redraw and a chat line stay English", Is(again, T) and line == PRE .. T.say, Show(again) .. " | " .. tostring(line))
    Res(out, "on: ours again", Is(Texts(), UK), Show(Texts()))
    return out
end

R[4] = function()
    local fs = S.Late()
    M.wait(0.2)
    return Res({}, "a window made later (its name prefix) is ours", fs:GetText() == UK.late, fs:GetText())
end

R[5] = function()
    local out = {}
    local mine = M.say(T.say)
    local other = M.add("|cff66ccffWobblyPlonk:|r " .. T.say)    -- same colour, another name
    local unknown = M.say("Wibble plonk")
    local bare = M.add(T.say)
    Res(out, "a chat line with its prefix: the prefix kept, the rest ours", mine == PRE .. UK.say, mine)
    Res(out, "a line with another prefix is left alone", other == "|cff66ccffWobblyPlonk:|r " .. T.say, other)
    Res(out, "its prefix with an unknown text is left alone", unknown == PRE .. "Wibble plonk", unknown)
    Res(out, "the same text without its prefix is left alone", bare == T.say, bare)
    return out
end

R[6] = function()
    local out = {}
    S.Tip()
    Res(out, "a tooltip line from its files is ours", Tip1() == UK.tip, Tip1())
    GameTooltip:SetOwner(UIParent) GameTooltip:AddLine(T.tip) GameTooltip:Show()
    Res(out, "the same line from other code stays English", Tip1() == T.tip, Tip1())
    GameTooltip:Hide()
    return out
end

R[7] = function()
    local out = {}
    S.Redraw() M.wait(0.1)
    Res(out, "lesson 13: a profile named like a word of ours stays as typed", S.profile:GetText() == T.profile, S.profile:GetText())
    Res(out, "that word is ours where it is not a profile name", ns.Words.Translate(T.profile) == UK.profile, "")
    return out
end

R[8] = function()
    local fs, news = S.Pin(), S.News()
    M.wait(0.2)
    S.Redraw() M.wait(0.1)
    local out = Res({}, "a map pin inside its window is left alone (game names)", fs:GetText() == T.pin, fs:GetText())
    return Res(out, "its news window stays English, also a word that is ours elsewhere (lesson 43)",
        news:GetText() == T.button, news:GetText())
end

-- Step 11 (lesson 44): its Gear Planner and setup end page, made up. A button label and a nav label whose font it
-- set by hand (SetFont, its own size) and that keeps that file over any font object (as the client may); the
-- search box's hint; the end page's body: lines of ours, a gap and the author's signature in colour.
local G = { btn = "Sprocket picks", nav = "Wobble plan", hint = "Seek all gizmos...", typed = "Sprocket picks",
    body = "Plonk the gizmos.\n\nWobble with care!\n|cffd9a63a- Zorpi|r" }
local GUK = { btn = "Вибір зубчиків", nav = "План хитання", hint = "Шукати всі гаджети...",
    l1 = "Плонкніть гаджети.", l2 = "Хитайте обережно!" }

R.gear = function()
    local out = {}
    M.inject()
    ns.OFA[Key(G.btn)], ns.OFA[Key(G.nav)], ns.OFA[Key(G.hint)] = GUK.btn, GUK.nav, GUK.hint
    ns.OFA[Key("Plonk the gizmos.")], ns.OFA[Key("Wobble with care!")] = GUK.l1, GUK.l2
    ns.Words.Forget()
    local f = CreateFrame("Frame", "OneForAllGearPlannerTest", OneForAllFrame)
    local function Hand(size, text)
        local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetFont("Fonts\\FRIZQT__.TTF", size, "")
        fs.SetFontObject = function() end                  -- the hand-set file stays over any font object
        fs:SetText(text)
        return fs
    end
    local btn, nav = Hand(11, G.btn), Hand(12, G.nav)
    local body = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    body:SetText(G.body)
    local eb = CreateFrame("EditBox", nil, f)
    eb:SetAutoFocus(false)
    local hint = eb:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    hint:SetText(G.hint)
    eb:SetText(G.typed)
    M.wait(0.3)
    ns.Screen.Sync() M.wait(0.1)
    local wantBody = GUK.l1 .. "\n\n" .. GUK.l2 .. "\n|cffd9a63a- Zorpi|r"
    Res(out, "a button label set by hand at size 11: ours, in a Cyrillic font", btn:GetText() == GUK.btn and CyrFont(btn),
        tostring(btn:GetText()) .. " " .. tostring(btn:GetFont()))
    Res(out, "a nav label set by hand at size 12: ours, in a Cyrillic font", nav:GetText() == GUK.nav and CyrFont(nav),
        tostring(nav:GetText()) .. " " .. tostring(nav:GetFont()))
    local _, size = btn:GetFont()
    Res(out, "the hand-set label keeps its own size", math.abs((size or 0) - 11) < 0.5, size)
    Res(out, "the search box's hint: ours", hint:GetText() == GUK.hint and CyrFont(hint), hint:GetText())
    Res(out, "the typed text stays as typed, also a word of ours", eb:GetText() == G.typed, eb:GetText())
    Res(out, "the end page's body with the signature: whole Ukrainian, the signature kept", body:GetText() == wantBody,
        body:GetText())
    Res(out, "a level line is ours (data)", Cyr(ns.Words.Translate("Level 44") or ""), ns.Words.Translate("Level 44"))
    Uadd("off")
    local p, s = btn:GetFont()
    Res(out, "off: English back on every label", btn:GetText() == G.btn and nav:GetText() == G.nav
        and hint:GetText() == G.hint and body:GetText() == G.body, Show({ btn:GetText(), nav:GetText(), hint:GetText() }))
    Res(out, "off: the hand-set font back (file and size)", p == "Fonts\\FRIZQT__.TTF" and math.abs((s or 0) - 11) < 0.5,
        tostring(p) .. " " .. tostring(s))
    Uadd("on")
    ns.Screen.Sync() M.wait(0.1)
    Res(out, "on again: ours", btn:GetText() == GUK.btn and hint:GetText() == GUK.hint, btn:GetText())
    return out
end

-- Step 12: texts the addon builds in code (pieces joined with a dot, money in a paragraph, a zone and its
-- coordinates): whole Ukrainian or whole English, the dot drawn as "  -  ", off gives the English back.
R.joined = function()
    local out = {}
    M.inject()
    local route = UADD.UALL.Zone
    UADD.UALL.Zone = function(n) if n == "Sprocket Vale" then return "Долина зубчиків" end return nil end
    ns.Words.Forget()
    local function Tr(s) return ns.Words.Translate(s) end
    local function Dot(s) return s and s:find("·", 1, true) ~= nil end
    local lv = Tr("Level 14  ·  Done")
    Res(out, "a level and a state joined by a dot: ours, the dot as a dash", Cyr(lv or "") and not Dot(lv)
        and (lv or ""):find("  -  ", 1, true) ~= nil, lv)
    local cl = Tr("Level 18  ·  Paladin  ·  0 / 12")
    Res(out, "a class from the glossary and a count between dots", Cyr(cl or "") and not Dot(cl) and cl:find("0 / 12", 1, true) ~= nil, cl)
    local cls = Tr("Tailoring  ·  Cloth  ·  Requires level 39  ·  Mage, Priest, Warlock")
    Res(out, "a profession, a class list and a level need", Cyr(cls or "") and not Dot(cls) and not Plain(cls):find("%a%a%a%a%a%a%a"), cls)
    local st = Tr("Neutral  ·  18 rewards")
    Res(out, "a standing word of ours and a count", Cyr(st or "") and not Dot(st), st)
    local zc = Tr("Sprocket Vale  |cff9d94806.5, 70.1|r")
    Res(out, "a zone UALL knows and its coordinates", zc == "Долина зубчиків  |cff9d94806.5, 70.1|r", zc)
    Res(out, "a zone UALL does not know: the whole line stays English", Tr("Wobbly Gizmo  |cff9d94806.5, 70.1|r") == nil
        and Tr("Level 18  ·  Wobbly  ·  0 / 12") == nil and Tr("Level 18  ·  Paladin, Gizmo") == nil,
        tostring(Tr("Level 18  ·  Wobbly  ·  0 / 12")))
    local gold = "12|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t 30|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"
    local para = Tr("No cheap upgrade up to " .. gold .. " for this in your level range.\nClick \"Cheap Upgrade Scan\" in the "
        .. "auction house for fresh prices, or raise the highest price.")
    Res(out, "the paragraph with money in it: whole Ukrainian, the money kept", Cyr(para or "") and para:find(gold, 1, true) ~= nil
        and not Plain(para):find("auction house", 1, true), para)
    local f = CreateFrame("Frame", "OneForAllJoinedTest", OneForAllFrame)
    local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetText("Level 14  ·  Done")
    M.wait(0.3)
    ns.Screen.Sync() M.wait(0.1)
    Res(out, "on the screen: ours", fs:GetText() == lv and CyrFont(fs), fs:GetText())
    Uadd("off")
    Res(out, "off: the English back", fs:GetText() == "Level 14  ·  Done", fs:GetText())
    Uadd("on")
    ns.Screen.Sync() M.wait(0.1)
    Res(out, "on again: ours", fs:GetText() == lv, fs:GetText())
    UADD.UALL.Zone = route
    return out
end

-- Step 10, in a game whose OneForAll is set to another language: the module is off and says so.
R.lang = function()
    local out = {}
    M.inject()
    local t, line = Texts(), M.say(T.say)
    local st = tostring(ns.Status())
    Res(out, "its language deDE: the windows stay English", Is(t, T), Show(t))
    Res(out, "its language deDE: a chat line stays English", line == PRE .. T.say, line)
    Res(out, "its language deDE: the status says why", st:find("не англійська", 1, true) ~= nil, st)
    return out
end
