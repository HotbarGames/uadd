-- H2: the real UADD_RoadToSixty on the stand-in (tools/harness/rts). Run once after the game starts; it gives
-- HARNESS.rtsmod: inject() puts made-up Ukrainian for the stand-in's made-up English into ns.RTS and ns.SORT by
-- "Code."..UADD.Hash(en), as the real data is keyed; R[n]() runs step n and returns a list of {name, ok, detail}
-- (ok nil: SKIP). No English of Road to Sixty here: the stand-in's texts are read from RTSStandIn.T.
local H = HARNESS
local R = {}
H.rtsmod = R
local S, M, U = RTSStandIn, H.rts, UADD
local ns = H.ns.UADD_RoadToSixty
local W = ns.Words
local T = S.T
local UK = { title = "Хитка мапа шляху", tabA = "Зорп", tabB = "Квікс", tabC = "Флім", button = "Гаджет",
    news = "Свіже", newsHead = "Виправлені гаджети", compare = "Порівняти Флім", optHead = "Хиткі налаштування",
    optCheck = "Показати гаджет", optButton = "Скинути гаджети", mini = "Зорп-шлях",
    tipLine = "Клацніть для мапи гаджетів", say = "Гаджет збережено", reset = "Скинути всі дані гаджетів?",
    del = "Видалити гаджет %s?\n\nЙого хиткі дані теж зникнуть.", rem = "Видалити друга %s?\n\nГаджет лишиться.", yes = "Так", no = "Ні", info = "Ранг %d - %s - %s",
    glued = "Ви увійшли до %s" }
local SORT = { del = "f", rem = "f", info = "vnu", glued = "n" }

local function Key(en) return "Code." .. U.Hash(en) end
local function Put(en, uk, sort) ns.RTS[Key(en)] = uk ns.SORT[Key(en)] = sort end
local function Plain(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
local function Cyr(s) return Plain(s):find("[\208\209]") ~= nil end
local function Latin(s) return Plain(s):find("%a") ~= nil end
local function Whole(s) return not (Cyr(s) and Latin(s)) end
local function CyrFont(fs) local p = fs and fs.GetFont and fs:GetFont() return p and U.IsCyrFont(p) and true or false end
local function Res(out, name, ok, d) out[#out + 1] = { name, ok, d ~= nil and tostring(d) or "" } return out end
local function Off(on) SlashCmdList.UADD(on and "rts on" or "rts off") M.wait(0.3) end
local function Title() return S.title:GetText() end

function R.inject()
    for k, uk in pairs(UK) do Put(T[k], uk, SORT[k]) end
    Put("%s's " .. T.title, "Хитка мапа шляху: %s", "f")
    Put("%d zone", "%d {зона|зони|зон}", "v")
    Put("%d zones", "%d {зона|зони|зон}", "v")
    Put("Seen %s", "Бачено %s", "v")
    W.Forget()
    R.g0 = M.globals()
end

function R.real(en)               -- a real text of the addon's (read by Python at run time) put on the title
    if en == nil then S.Redraw() return false, false end
    local want = ns.RTS[Key(en)]
    if type(want) ~= "string" or (ns.SORT[Key(en)] or "") ~= "" then return false, false end
    S.title:SetText(en)
    return S.title:GetText(), want
end

local function Texts(f, out, seen)
    if not f or seen[f] then return out end
    seen[f] = true
    local function One(r)
        if r and not seen[r] and r.GetText and r.GetObjectType and r:GetObjectType() == "FontString" then
            seen[r] = true
            local t = r:GetText()
            if t and t ~= "" then out[#out + 1] = { r, t } end
        end
    end
    if f.GetFontString then One(f:GetFontString()) end
    if f.GetRegions then for _, r in ipairs({ f:GetRegions() }) do One(r) end end
    if f.GetChildren then for _, k in ipairs({ f:GetChildren() }) do Texts(k, out, seen) end end
    return out
end
local function All()
    local out, seen = {}, {}
    for _, f in ipairs({ RoadToSixtyJourneyFrame, RoadToSixtyCompareWindow, RoadToSixtyWhatsNew, S.panel or false }) do
        if f then Texts(f, out, seen) end
    end
    return out
end

R[1] = function()
    R.inject()
    S.OpenMap() S.OpenCompare() S.OpenNews() S.OpenOptions()
    if SettingsPanel and SettingsPanel.Show then SettingsPanel:Show() end
    M.wait(0.2) S.Redraw() M.wait(0.1)
    local mixed, left, nofont, ua = {}, {}, {}, 0
    local ours = {}
    for k in pairs(UK) do if not T[k]:find("%", 1, true) then ours[T[k]] = true end end
    for _, p in ipairs(All()) do
        local t = p[2]
        if not Whole(t) then mixed[#mixed + 1] = t end
        if ours[t] then left[#left + 1] = t end
        if Cyr(t) then ua = ua + 1 if not CyrFont(p[1]) then nofont[#nofont + 1] = t end end
    end
    local out = {}
    Res(out, "4 frames + canvas (some made later): no mixed line", #mixed == 0, table.concat(mixed, " / "))
    Res(out, "4 frames + canvas: none of our texts left English", #left == 0 and ua >= 8, ua .. " Ukrainian; left: " .. table.concat(left, " / "))
    Res(out, "4 frames + canvas: each Ukrainian text in a Cyrillic font", #nofont == 0, table.concat(nofont, " / "))
    Res(out, "the title is ours", Title() == UK.title, Title())
    return out
end

R[2] = function()
    local last = S.Tick(100)
    local shown = S.infoText and S.infoText:GetText()
    local out = {}
    Res(out, "info line with n and u slots stays whole English", shown == last and not Cyr(shown), shown)
    Res(out, "Words cache at most 400 after 100 updates", W.CacheSize() <= 400, W.CacheSize())
    Res(out, "a u-slot line gives no translation", W.Translate(string.format(T.info, 3, "Zorpvale", "5m")) == nil, "")
    return out
end

R[3] = function()
    M.key(true)
    local held, tab = Title(), S.tabs[1].fs:GetText()
    M.key(false)
    local out = {}
    Res(out, "hold key: English while held", held == T.title and tab == T.tabA, held .. " | " .. tostring(tab))
    Res(out, "hold key: ours again on release", Title() == UK.title, Title())
    return out
end

R[4] = function()
    local out = {}
    Off(false)
    local t1, tab, f = Title(), S.tabs[1].fs:GetText(), CyrFont(S.title)
    S.Redraw() M.wait(0.1)
    local t2 = Title()
    local mixed = 0
    for _, p in ipairs(All()) do if Cyr(p[2]) then mixed = mixed + 1 end end
    Off(true)
    Res(out, "/uadd rts off: English back", t1 == T.title and tab == T.tabA and mixed == 0, t1 .. " | " .. mixed .. " Cyrillic left")
    Res(out, "/uadd rts off: the addon's font back", not f, "")
    Res(out, "redraw while off stays English", t2 == T.title, t2)
    Res(out, "/uadd rts on: ours again", Title() == UK.title, Title())
    return out
end

R[5] = function()
    local out = {}
    M.click(2)
    local fs = S.tabs[2].fs
    Res(out, "tab click (SetFontObject) keeps our text", fs:GetText() == UK.tabB, fs:GetText())
    Res(out, "tab click keeps a Cyrillic font", CyrFont(fs), "")
    S.button:SetEnabled(false) S.button:SetEnabled(true)
    Res(out, "SetEnabled keeps the button ours", S.button:GetText() == UK.button, S.button:GetText())
    return out
end

R[6] = function()
    local g = W.Translate(S.Glued("Zorpvale"))
    return Res({}, "glued zone (n slot, a zone nobody named) stays English", g == nil, g)
end

R[7] = function()
    local out = {}
    S.Title("Quix")
    Res(out, "a character's name in the title: whole Ukrainian, the name kept", Title() == "Хитка мапа шляху: Quix", Title())
    -- A name glued before a text of ours that starts with an apostrophe ("<name>'s ..."): the name kept, the rest ours.
    Put("'s gizmo log", " — журнал гаджета") W.Forget()
    local g = W.Translate("Quix's gizmo log")
    Res(out, "a name glued before our \"'s\" text: the name kept, the rest ours", g == "Quix — журнал гаджета", tostring(g))
    -- Lesson 13: a character named exactly like a one-word text of ours keeps its name. Shaped as the addon's
    -- name labels: a map marker's label (a frame with .entry and .label), a compare row's coloured name under the
    -- stats chart (one line, its top left on the pane's bottom left; the row is a plain table, the text sits on the
    -- pane) and a compare window row's first cell (one line, its top left on the window's top left).
    Put("Zorp", "Зорп") W.Forget()
    local mk = CreateFrame("Frame", nil, RoadToSixtyJourneyFrame)
    mk.entry = { name = "Zorp" }
    mk.label = mk:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    mk.label:SetPoint("TOP", mk, "BOTTOM", 0, -1)
    mk.label:SetText("Zorp")
    local pane = CreateFrame("Frame", nil, RoadToSixtyJourneyFrame)
    local row = { name = pane:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall") }
    row.name:SetJustifyH("LEFT") row.name:SetWordWrap(false)
    row.name:SetPoint("TOPLEFT", pane, "BOTTOMLEFT", 28, -40)
    row.name:SetText("|cffaabbccZorp|r")
    local more = pane:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")   -- wraps: a text of the addon's
    more:SetPoint("TOPLEFT", pane, "BOTTOMLEFT", 28, -60)
    more:SetText("Zorp")
    local sub = pane:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")  -- one line, on a sibling
    sub:SetWordWrap(false) sub:SetPoint("TOPLEFT", more, "BOTTOMLEFT", 0, -3)
    sub:SetText("Zorp")
    local win = RoadToSixtyCompareWindow
    local cell = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cell:SetJustifyH("LEFT") cell:SetWordWrap(false)
    cell:SetPoint("TOPLEFT", win, "TOPLEFT", 20, -60)
    cell:SetText("|cffaabbccZorp|r")
    local cell2 = win:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cell2:SetWordWrap(false) cell2:SetPoint("TOPRIGHT", win, "TOPLEFT", 200, -60)
    cell2:SetText("Zorp")
    win:Hide() win:Show() S.Redraw() M.wait(0.1)
    ns.Screen.Later() M.wait(0.1)
    local a, b, c = mk.label:GetText(), row.name:GetText(), cell:GetText()
    Res(out, "C1: a character named like a one-word text of ours keeps the name (marker, compare row, window cell)",
        a == "Zorp" and not Cyr(b) and not Cyr(c), tostring(a) .. " | " .. tostring(b) .. " | " .. tostring(c))
    local d, e, f = more:GetText(), sub:GetText(), cell2:GetText()
    Res(out, "C1: the same word elsewhere in those windows is ours (the skip is by place, not wider)",
        d == "Зорп" and e == "Зорп" and f == "Зорп", tostring(d) .. " | " .. tostring(e) .. " | " .. tostring(f))
    return out
end

R[8] = function()
    local got, want, ok = {}, { "1 зона", "3 зони", "5 зон", "11 зон", "21 зона" }, true
    for i, n in ipairs({ 1, 3, 5, 11, 21 }) do
        local t = W.Translate(S.Count(n))
        got[i] = tostring(t)
        if t ~= nil and t ~= want[i] then ok = false end
    end
    local out = Res({}, "plurals 1,3,5,11,21: each English or the right Ukrainian form", ok, table.concat(got, " / "))
    local all = got[1] ~= "nil" and got[2] ~= "nil" and got[3] ~= "nil" and got[4] ~= "nil" and got[5] ~= "nil"
    return Res(out, "plurals reach Ukrainian (each of 1,3,5,11,21)", all, table.concat(got, " / "))
end

R[9] = function()
    local t = W.Translate("Seen " .. S.When(3, 11))
    return Res({}, "a date in a v slot: whole English or whole Ukrainian", t == nil or not Latin(t), tostring(t))
end

R[10] = function()
    local out = {}
    local mine = M.say(T.say)
    -- another addon's prefix of the same length and colour, so only the prefix compare tells them apart
    local n = #H.chat print("|cff33ff99WobblyPlonk|r: " .. T.say)
    local other = H.chat[n + 1]
    local unknown = M.say("Wibble plonk")
    local pre = "|cff33ff99RoadToSixty|r: "          -- the addon's own prefix stays; the rest is whole ours
    local rest = tostring(mine):sub(1, #pre) == pre and tostring(mine):sub(#pre + 1) or nil
    Res(out, "a print with the addon's prefix is ours", rest == UK.say, mine)
    Res(out, "a print with another prefix is left alone", other == "|cff33ff99WobblyPlonk|r: " .. T.say, other)
    Res(out, "our prefix with an unknown text is left alone", not Cyr(unknown), unknown)
    -- the level-up summary's prefix has spaces; a link with English text in the rest keeps the line English, intact
    local sp, link = "|cff33ff99Road to Sixty|r: ", "|Haddon:RoadToSixty:level:12|h|cff71d5ff[Zorp]|r|h"
    n = #H.chat print(sp .. T.say)
    local spaced = H.chat[n + 1]
    n = #H.chat print(sp .. T.say .. " " .. link)
    local linked = H.chat[n + 1]
    Res(out, "a print with the spaced prefix is ours", spaced == sp .. UK.say, spaced)
    Res(out, "a spaced print with an English link stays as it is", linked == sp .. T.say .. " " .. link, linked)
    S.Tip()
    local tip = M.tipLines()
    Res(out, "the addon's tooltip lines are ours", tip[1] == UK.mini and tip[2] == UK.tipLine, tostring(tip[1]) .. " | " .. tostring(tip[2]))
    GameTooltip:SetOwner(UIParent) GameTooltip:AddLine(T.mini) GameTooltip:Show()
    Res(out, "a tooltip line from other code stays English", M.tipLines()[1] == T.mini, M.tipLines()[1])
    GameTooltip:Hide()
    local bad = {}
    for _, key in pairs(S.Popups()) do
        StaticPopup_Show(key, "Quix")
        local p = M.popup()
        -- the character's name is kept as it is inside our whole text; every other word is ours
        local rest = p and (tostring(p.text):gsub("Quix", "")) or ""
        if not (p and Cyr(p.text) and Whole(rest) and p.b1 == UK.yes and p.b2 == UK.no) then
            bad[#bad + 1] = key .. "=" .. tostring(p and p.text) .. "/" .. tostring(p and p.b1) .. "/" .. tostring(p and p.b2)
        end
        StaticPopup_Hide(key)
    end
    Res(out, "3 popups: text and buttons ours (core U.Popups)", #bad == 0, table.concat(bad, " ; "))
    return out
end

R[11] = function()
    local out = {}
    S.Redraw()
    local db = M.db()
    Res(out, "saved data has no Ukrainian", not Cyr(db) and not Cyr(RoadToSixtyDB.note), db)
    Res(out, "ERR_/LOOT_/FACTION_/DUEL_ globals not written", M.globals() == R.g0, "")
    return out
end

R[12] = function()
    local out = {}
    Off(false) Off(true)
    Res(out, "the 4 game-wide hooks are the addon's own after off and on", M.hookNow(), "")
    local bad, msg = 0, "No player named 'Quix' is currently playing."
    for _, f in ipairs(RTSFilters.CHAT_MSG_SYSTEM or {}) do
        local drop, m = f(ChatFrame1, "CHAT_MSG_SYSTEM", msg)
        if drop or (m ~= nil and m ~= msg) then bad = bad + 1 end
    end
    Res(out, "every system chat filter passes a game message as it is", bad == 0, bad)
    return out
end
-- Step 13 is in flow_rts_mod2.lua (the file budget); it uses these helpers.
R._ = { Res = Res, Title = Title }
