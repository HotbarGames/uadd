-- Helpers for flow_dj_home.py: Edit Mode on the home page (FDJ's Systems/HomeEdit.lua) and the glued quest
-- titles (Systems/Tier05Chain.lua). Every English text comes from the journal at run time.
-- Reached as HARNESS.djhome.
local H = HARNESS
local D = {}
H.djhome = D

local function F() return ForeverDungeonJournal_NS end
local function ns() return H.ns.UADD_DungeonJournal end
local function Frame() return ForeverDungeonJournalFrame end
local CYR = "[\208-\210]"
local function Half(t) return t:find("%a") and t:find(CYR) and true or false end

function D.en(key) return F().Locales.enUS[key] end
function D.edit(on) F().SetHomeEditMode(on) end

-- Edit Mode's bar: its button of this kind, clicked, and the words on all four.
local function Tool(kind)
    for _, c in ipairs({ Frame().homePanel:GetChildren() }) do if rawget(c, "fdjKey") == kind then return c end end
end
function D.tool(kind) H.dj.click(Tool(kind)) end
function D.bar()
    local r = {}
    for i, k in ipairs({ "hide", "reorder", "view", "reset" }) do r[i] = Tool(k).text:GetText() end
    return table.concat(r, "|")
end
function D.barEnglish()
    return table.concat({ D.en("HIDE_DUNGEONS"), D.en("REORDER_DUNGEONS"), D.en("VIEW_MODE"), D.en("RESET_UI") }, "|")
end
function D.tip(kind)
    local b = Tool(kind)
    local r, set, add = {}, rawget(GameTooltip, "SetText"), rawget(GameTooltip, "AddLine")
    local function line(_, t) r[#r + 1] = t end
    GameTooltip.SetText, GameTooltip.AddLine = line, line
    H.call("OnEnter", b.__scripts.OnEnter, b)
    GameTooltip.SetText, GameTooltip.AddLine = set, add
    GameTooltip:Hide()
    return table.concat(r, "|")
end

-- The words of a window of the journal's own (its frame's name), in order; "" while it is not shown.
function D.window(name)
    local f = rawget(_G, name)
    if not (f and f:IsShown()) then return "" end
    return table.concat(H.dj.visible(f), "|")
end
function D.hide(name) local f = rawget(_G, name) if f then f:Hide() end end
function D.menuEnglish() return table.concat({ D.en("VIEW_DEFAULT"), D.en("VIEW_SMALL"), D.en("VIEW_LIST") }, "|") end

-- A controller connected: the journal asks in a window of its own.
function D.controller(on)
    if on then
        D.was, F().ControllerConnected = F().ControllerConnected, function() return true end
    else
        F().ControllerConnected = D.was
    end
end
function D.popup() local d = StaticPopupDialogs.FDJ_RESET_HOME_UI return d.button1 .. "|" .. d.button2 end
function D.globals() return YES .. "|" .. NO .. "|" .. OKAY end

-- The note of Edit Mode: its text and its small OK.
function D.note()
    F().ShowEditModeNote()
    H.step(0.05)
    return D.noteText()
end
function D.noteText()
    for _, c in ipairs({ Frame().homePanel:GetChildren() }) do
        if rawget(c, "arrow") and rawget(c, "ok") then return c.text:GetText() .. "|" .. c.ok:GetText() end
    end
end

-- The game's OKAY on a made-up button of the journal's: wide and narrow, then a text the journal sets itself.
function D.okay(width, own)
    local b = CreateFrame("Button", nil, Frame(), "UIPanelButtonTemplate")
    b:SetSize(width, 20)
    b:SetText(OKAY)
    ns().Buttons.Look(b)
    local first = b:GetText()
    if own then b:SetText(own) end
    ns().Buttons.Back()
    local last = b:GetText()
    b:Hide()
    return first, last
end

-- The glued titles: the journal's own function gives a half line on some (that is why Whole.lua is there).
local IDS = { 8962, 8963, 8964, 8965, 8966, 8967, 8968, 8969, 8985, 8986, 8987, 8988, 8989, 8990, 8991, 8992 }
function D.titles()
    local whole, uk, en = true, 0, 0
    local bad = ""
    for _, id in ipairs(IDS) do
        local t = F().LocalizeQuestField(id, "name", "Wobbly Gizmo")
        if Half(t) then whole, bad = false, t end
        if t:find(CYR) then uk = uk + 1 else en = en + 1 end
    end
    return whole, uk, en, bad
end
-- A made-up title and item name, each known or not, through the journal's real function.
function D.title(id, title, en, uk)
    local maps = ns().Names.maps
    local q = maps.Quest[id]
    maps.Quest[id] = title
    if en then maps.Item[en] = uk end
    local C = C_Item.GetItemNameByID
    C_Item.GetItemNameByID = function() return en or "Wobbly Gizmo" end
    local content = F().ContentLocales.ukUA
    F().ContentLocales.ukUA = setmetatable({ quests = setmetatable({ [id] = title and { name = title } or false },
        { __index = content.quests }) }, { __index = content })
    local out = F().LocalizeQuestField(id, "name", "Wobbly Quest")
    F().ContentLocales.ukUA = content
    C_Item.GetItemNameByID = C
    maps.Quest[id] = q
    if en then maps.Item[en] = nil end
    return out
end

function D.place(label) return F().L("REORDER_PLACE_TIP", label) end
-- A dungeon with a Ukrainian name: its key and that name.
function D.dungeon()
    for _, k in ipairs(F().HomeOrder()) do
        local uk = ns().Names.Dungeon(k)
        if uk and not uk:find("%a") then return k, uk end
    end
end
-- The functions Whole.lua wraps, to compare by identity; and where a wrap of ours is on.
function D.own() return F().L, F().LocalizeQuestField end
function D.sameOwn(a, b) return F().L == a and F().LocalizeQuestField == b end
