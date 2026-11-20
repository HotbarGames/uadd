-- The game's own words in Bagnon, from UALL Forever (docs/LESSONS.md, lesson 9: game words are its, never ours).
--
-- Bagnon takes a few words from the game (its global strings). Each is read from the game when it is needed,
-- never stored here, and its Ukrainian is asked of UALL Forever (UADD.UALL.Text) at that moment:
--   * the window names in the frame list of the settings and in the offline menu (Inventory, Bank, ...);
--   * in Bagnon_Config's locale table: the Help page's name and the Money check's label;
--   * on the frame settings page, read each time it shows: the "Display" header and the "Never" choice;
--   * tooltips of Bagnon's buttons: a line that is that word alone (search, money), or the word after only
--     icons and Ukrainian (the right-click "Options" line). A line with other English stays English (the
--     title bar's "drag ... search" line: its first half stays English, make_bgn_text.py STAY).
-- A word UALL Forever lacks stays English, and so does each line built from it. "Not now": asked again a
-- little later. Off and the hold key: the English goes back wherever a word went in.
-- Stays English: "Always" in the same choice (UALL Forever's has a full stop), the filter menu's second
-- level ("Search", "Macro": the module does not reach that menu level).

local _, ns = ...
local U = UADD
local G = {}
ns.Game = G

local NAME, CONFIG = "Bagnon", "Bagnon_Config"
local REG = { inventory = "INVENTORY_TOOLTIP", bank = "BANK", guild = "GUILD_BANK", vault = "VOID_STORAGE" }
local CONF = { Help = "HELP_LABEL", Money = "MONEY" }       -- Bagnon_Config's locale key -> the game's word
local TIP = { "SEARCH", "MONEY", "OPTIONS" }
local CYR = "[\208-\210]"
local put = {}                -- id -> { English, Ukrainian } that went in, to put back by value
local wrapped = {}
local later, tries = false, 0

local function Addon() local a = rawget(_G, NAME) return type(a) == "table" and a or nil end
local function En(global) local s = rawget(_G, global) return type(s) == "string" and s ~= "" and s or nil end

-- UALL Forever's word for the game's `en`, or nil (and true for "not now").
local function Uk(en)
    local A = U.UALL
    if not en or type(A) ~= "table" or type(A.Text) ~= "function" then return nil end
    local uk, wait = A.Text(en)
    if wait then later = true end
    return type(uk) == "string" and uk:find(CYR) and uk or nil
end

-- t[k] shows the game's `en` (id: where, for putting back): UALL Forever's word in, or the English back.
local function Field(id, t, k, en, on)
    local cur, rec = rawget(t, k), put[id]
    if not on then
        if rec and cur == rec[2] then rawset(t, k, rec[1]) end
        return
    end
    if rec and cur == rec[2] then return end
    local uk = en and cur == en and Uk(en)
    if uk then
        put[id] = { en, uk }
        rawset(t, k, uk)
    end
end

local function App() local A = LibStub and LibStub("AceLocale-3.0", true) return A and A.apps and A.apps[CONFIG] end

-- Bagnon_Config just wrote its key `k` (Locale.lua's wrapper, before its pages read it).
function G.Config(t, k)
    if CONF[k] and ns.WordsWanted() then Field("config:" .. k, t, k, En(CONF[k]), true) end
end

-- The Help page's title (read once, at load): the name at its start.
local function HelpTitle(on)
    local A = Addon()
    local p, rec = A and rawget(A, "Help"), put["config:Help"]
    if type(p) ~= "table" or type(p.title) ~= "string" or not rec then return end
    local from, to = on and rec[1] or rec[2], on and rec[2] or rec[1]
    if p.title:sub(1, #from + 2) == from .. "  " then p.title = to .. p.title:sub(#from + 1) end
end

local function Registry(on)
    local A = Addon()
    local reg = A and type(A.Frames) == "table" and A.Frames.Registry
    for _, f in ipairs(type(reg) == "table" and reg or {}) do
        local g = type(f) == "table" and REG[f.id]
        if g then Field("reg:" .. f.id, f, "name", En(g), on) end
    end
end

-- The frame settings page: its header and choice read the game's words each time it shows.
local function Copy(t) local c = {} for k, v in pairs(t) do c[k] = v end return c end

local function WrapPage(p)
    if wrapped[p] or type(p) ~= "table" or type(p.Add) ~= "function" or type(p.AddChoice) ~= "function" then return end
    wrapped[p] = true
    local add, choice = p.Add, p.AddChoice
    p.Add = function(self, class, text, ...)
        if ns.WordsWanted() then
            if class == "DropChoice" then U.SafeCall(Registry, true) end      -- the frame list: names now
            if class == "Header" and text ~= nil and text == En("DISPLAY") then text = Uk(text) or text end
        end
        return add(self, class, text, ...)
    end
    p.AddChoice = function(self, data)
        local never = En("NEVER")
        local uk = type(data) == "table" and never and ns.WordsWanted() and Uk(never)
        if uk then
            data = Copy(data)
            for i, e in ipairs(data) do
                if type(e) == "table" and e.text == never then data[i] = Copy(e) data[i].text = uk end
            end
        end
        return choice(self, data)
    end
end

-- Our words in (on) or the game's English back (off), everywhere they went in.
function G.Set(on)
    on = on and true or false
    later = false
    local t = App()
    if type(t) == "table" then
        for k, g in pairs(CONF) do Field("config:" .. k, t, k, En(g), on) end
    end
    HelpTitle(on)
    Registry(on)
    local A = Addon()
    local p = A and rawget(A, "FrameOptions")
    U.SafeCall(WrapPage, p)
    if type(p) == "table" and p.IsVisible and p:IsVisible() and type(p.UpdateChildren) == "function" then
        U.SafeCall(p.UpdateChildren, p, true)
    end
    if on and later and tries < 5 and C_Timer and C_Timer.After then
        tries = tries + 1
        C_Timer.After(2, function() if ns.WordsWanted() then U.SafeCall(G.Set, true) end end)
    end
end

-- A tooltip of a Bagnon button is shown (Fonts.lua, after it found the owner is Bagnon's): a line that ends
-- in one of the game's words, with only icons and Ukrainian before it, gets UALL Forever's word.
local function Strip(s)
    return (s:gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

function G.Tip(tip, name)
    if not ns.WordsWanted() or not name then return false end
    local any = false
    for i = 1, tip:NumLines() do
        local fs = _G[name .. "TextLeft" .. i]
        local s = fs and fs:IsShown() and fs:GetText()
        if type(s) == "string" then
            for _, g in ipairs(TIP) do
                local en = En(g)
                if en and #s >= #en and s:sub(-#en) == en then
                    local head = s:sub(1, #s - #en)
                    local uk = (head == "" or head:sub(-1) == " ") and not Strip(head):find("%a") and Uk(en)
                    if uk then fs:SetText(head .. uk) any = true end
                    break
                end
            end
        end
    end
    return any
end
