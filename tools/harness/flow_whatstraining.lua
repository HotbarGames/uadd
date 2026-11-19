-- Lua helpers for flow_whatstraining.py, on the What's Training? stand-in (tools/harness/whatstraining).
-- Reached from Python as HARNESS.wt. Run before the game starts.
local H = HARNESS
local M = {}
H.wt = M

-- In the game every frame of a kind shares one method table (getmetatable(f).__index), and Screen.lua
-- hooks CreateFontString there. The harness looks methods up through a function instead, so the
-- module is shown the table the function reads (H.Widget). Only UADD_WhatsTraining sees this.
local realMeta = getmetatable
local SHARED = { __index = H.Widget }
getmetatable = function(x)
    if type(x) == "table" and rawget(x, "__type") ~= nil and rawget(x, 0) == x then
        local info = debug.getinfo(2, "S")
        if info and info.source and info.source:find("AddOns/UADD_WhatsTraining/", 1, true) then return SHARED end
    end
    return realMeta(x)
end

-- UIPanelDialogTemplate: the client makes the template's title region itself, never through the Lua
-- CreateFontString method that Screen.lua hooks; so here it is made straight, as the method would.
local applyTemplate = H.applyTemplate
function H.applyTemplate(w, template)
    applyTemplate(w, template)
    if template == "UIPanelDialogTemplate" then
        local t = H.newWidget("FontString", (w:GetName() or "") .. "TitleText", w)
        t.__text, t.__color, t.__font = nil, { 1, 0.82, 0, 1 }, { "Fonts\\FRIZQT__.TTF", 12, "" }
        w.Title = t
    end
end

WhatsTrainingStandInFeed = { load = {}, later = {} }
function M.feedTitle(text) WhatsTrainingStandInFeed.title = text end
function M.feed(where, name, text, how, size)
    local t = WhatsTrainingStandInFeed[where]
    t[#t + 1] = { name = name, text = text, how = how ~= "" and how or nil, size = size }
end
function M.broker(text) WhatsTrainingStandInFeed.broker = text end

local function S() return rawget(_G, "WhatsTrainingStandIn") end
local function NS() return H.ns.UADD_WhatsTraining end
M.S = S
function M.loaded() return S() ~= nil and NS() ~= nil end
function M.on() return NS().On() end
function M.uk(t) return NS().Words.Translate(t) end
function M.count() return NS().Words.Count() end
function M.fontCount() return NS().Screen.Count() end
function M.hooked() return NS().Screen.Hooked() end

-- A made-up name the halves check puts in a game-name slot: UALL Forever's Ukrainian for it.
function M.names(en, uk)
    for _, k in ipairs({ "Text", "Zone", "Npc", "Item" }) do
        local old = UADD[k]
        UADD[k] = function(s, ...)
            if s == en then return uk end
            if old then return old(s, ...) end
        end
    end
end

-- Our Ukrainian for a whole text, straight from the module's data.
function M.want(key)
    local uk = NS().WT.exact[key]
    return uk and UADD.Plural(uk, true)
end

-- A template filled by hand from its record (data: uk list, numbers are slots), every slot a value.
function M.fill(id, a, b, c)
    local vals = { a, b, c }
    for _, rec in ipairs(NS().WT.templates) do
        if rec.id == id then
            local out = {}
            for _, p in ipairs(rec.uk) do out[#out + 1] = type(p) == "number" and vals[p] or p end
            return UADD.Plural(table.concat(out), true)
        end
    end
end

function M.snap()
    local out = {}
    for name, fs in pairs(S().texts) do out[name] = fs:GetText() or "" end
    for name, fs in pairs(S().other) do out["other:" .. name] = fs:GetText() or "" end
    out["broker:text"] = S().broker.text
    return out
end

-- Fonts read back: Cyrillic text in our font, English text in the stand-in's own.
function M.fonts()
    local good, bad, wrong = 0, 0, 0
    for _, list in ipairs({ S().texts, S().other }) do
        for _, fs in pairs(list) do
            local p = fs:GetFont()
            local cyr = (fs:GetText() or ""):find("[\208-\210]") ~= nil
            if cyr and UADD.IsCyrFont(p) then good = good + 1
            elseif cyr then bad = bad + 1
            elseif p ~= S().PATH then wrong = wrong + 1 end
        end
    end
    return good, bad, wrong
end

-- Any Cyrillic left on the stand-in's texts or its tooltip?
function M.anyCyr()
    local n = 0
    for _, list in ipairs({ S().texts, S().other }) do
        for _, fs in pairs(list) do if (fs:GetText() or ""):find("[\208-\210]") then n = n + 1 end end
    end
    return n
end

function M.later()
    S().Later()
    M.wait(0.2)
end
-- The main window opened late (after login): its title text and whether it has our font.
local function Title()
    local t = S().floating.Title
    return t:GetText() or "", UADD.IsCyrFont((t:GetFont())) and true or false
end
function M.open() S().Open() return Title() end
function M.title() return Title() end
-- Hidden and shown again, then the English title set again (as the addon would): what shows.
function M.reshow(text)
    local f = S().floating
    f:Hide()
    f:Show()
    f.Title:SetText(text)
    return Title()
end
function M.set(name, text) S().Set(name, text) end
function M.label(text) S().Label(text) end

-- A tooltip line from the stand-in's code on the game tooltip, and the same line from here.
function M.tip(left, right)
    GameTooltipTextLeft1:SetText("") GameTooltipTextRight1:SetText("")
    S().Tip(left, right)
    return GameTooltipTextLeft1:GetText(), GameTooltipTextRight1:GetText(),
        UADD.IsCyrFont((GameTooltipTextLeft1:GetFont())) and true or false
end
function M.tipOther(left)
    GameTooltipTextLeft1:SetText("")
    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    GameTooltip:AddLine(left)
    return GameTooltipTextLeft1:GetText() or ""
end

-- A line on its own tooltip (the client writes the English, we may write over it).
function M.ownTip(left, right)
    S().OwnTip(left, right)
    local l, r = WhatsTrainingTrainerTooltipTextLeft1, WhatsTrainingTrainerTooltipTextRight1
    return l:GetText(), r:GetText(), UADD.IsCyrFont((l:GetFont())) and true or false
end

-- No Cyrillic font (a client without one): UADD finds none, every text is done again.
local savedPath, savedFont
function M.nofont(on)
    if on then
        savedPath, savedFont = UADD.CyrFontPath, UADD.fontPath
        UADD.CyrFontPath = function() return nil end
        UADD.fontPath = nil
    else
        UADD.CyrFontPath, UADD.fontPath = savedPath, savedFont
    end
    NS().Screen.Sync()
end

-- The miss paths (an unknown text, a chat line of another addon, a shown font string we have no
-- Ukrainian for), n times each: (ms, KB of garbage).
function M.speed(n, name)
    local W, Sc = NS().Words, NS().Screen
    local fs = S().texts[name]
    local miss, line = "Glimmering Quixberry", "[Guild] Quix: anyone up for Zorp Blatter?"
    W.Translate(miss) W.Translate(line) Sc.Apply(fs)
    collectgarbage("collect")
    collectgarbage("stop")
    local kb0 = collectgarbage("count")
    local t0 = debugprofilestop()
    for _ = 1, n do W.Translate(miss) end
    for _ = 1, n do W.Translate(line) end
    for _ = 1, n do Sc.Apply(fs) end
    local ms = debugprofilestop() - t0
    local kb = collectgarbage("count") - kb0
    collectgarbage("restart")
    return ms, kb
end

-- A chat line from the stand-in (its print), or one from other code; the line shown.
function M.print(text) S().Print(text) return H.chat[#H.chat] end
function M.say(text) DEFAULT_CHAT_FRAME:AddMessage(text) return H.chat[#H.chat] end
function M.lastChat(n)
    local out = {}
    for i = math.max(1, #H.chat - n + 1), #H.chat do out[#out + 1] = H.chat[i] end
    return table.concat(out, " | ")
end

function M.key(down)
    H.keys.SHIFT = down
    H.fire("MODIFIER_STATE_CHANGED", "LSHIFT", down and 1 or 0)
    M.wait(0.4)                         -- UADD/Original.lua switches once the key is held a while
end
function M.wait(seconds) for _ = 1, math.ceil(seconds / 0.05 - 1e-6) do H.step(0.05) end end
function M.uadd(msg) return H.call("/uadd " .. msg, SlashCmdList.UADD, msg) end
