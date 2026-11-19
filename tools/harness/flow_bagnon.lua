-- Lua helpers for flow_bagnon.py, on the Bagnon stand-ins (tools/harness/bagnon). Reached from Python
-- as HARNESS.bgn. Run before the game starts. The game's few words Bagnon_Config's locale file reads
-- are given here when the harness lacks them.
local H = HARNESS
local M = {}
H.bgn = M

NEW_CAPS = NEW_CAPS or "NEW"
HELP_LABEL = HELP_LABEL or "Help"
MONEY = MONEY or "Money"
BATTLENET_FONT_COLOR = BATTLENET_FONT_COLOR or CreateColor(0.51, 0.77, 1)

local function S() return rawget(_G, "BagnonStandIn") end
local function NS() return H.ns.UADD_Bagnon end
local function Ace() return LibStub and LibStub("AceLocale-3.0", true) end
local function App(name) local a = Ace() return a and a.apps[name] end
local NAME = "Bagnon"

-- A stale line: the English it was made from is not Bagnon's any more (src hash changed), set right
-- after the module's data loaded and before it starts.
M.stale = {}
M.tamper = {}
local watch = CreateFrame("Frame")
watch:RegisterEvent("ADDON_LOADED")
watch:SetScript("OnEvent", function(_, _, name)
    if name ~= "UADD_Bagnon" then return end
    local src = NS() and NS().BGN and NS().BGN.src
    for id in pairs(M.tamper) do
        if src and src[id] then src[id] = "1:00000000" M.stale[id] = true end
    end
end)
function M.markStale(id) M.stale[id] = true end
function M.src(id) local B = NS() and NS().BGN return B and B.src[id] end

-- Everything Bagnon shows or keeps, by name: both locale tables, the FAQ, the words read at load,
-- and the stand-in's texts on screen.
local TITLES = { Inventory = "TitleBags", Bank = "TitleBank", Vault = "TitleVault" }
local RULES = { normal = "NormalBags", trade = "TradeBags", ammo = "AmmoBags" }
local BINDS = { TOGGLE = "OpenBags", BANK_TOGGLE = "OpenBank", VAULT_TOGGLE = "OpenVault", GUILD_TOGGLE = "OpenGuild" }

function M.snap()
    local out = {}
    for _, which in ipairs({ "core", "config" }) do
        local t = App(which == "core" and NAME or "Bagnon_Config") or {}
        for k, v in pairs(t) do if type(v) == "string" then out[which .. ":" .. k] = v end end
        if type(rawget(t, "FAQ")) == "table" then
            for i, v in ipairs(rawget(t, "FAQ")) do out["faq:" .. i] = v end
        end
    end
    local A = rawget(_G, NAME)
    for c in pairs(TITLES) do if A[c] then out["class:" .. c] = A[c].Title end end
    for id in pairs(RULES) do out["rule:" .. id] = A.Rules.Registry[id].title end
    for id in pairs(BINDS) do out["bind:" .. id] = rawget(_G, "BINDING_NAME_BAGNON_" .. id) end
    for _, id in ipairs(S().PAGES or {}) do
        local p = A[id]
        if p then out["panel:" .. id .. ":title"], out["panel:" .. id .. ":subtitle"] = p.title, p.subtitle end
    end
    for name, fs in pairs(S().texts) do out[name] = fs:GetText() end
    return out
end

-- Our Ukrainian for a name of M.snap, straight from the module's data (ns.BGN); nil: Bagnon's English.
local function D(which, k)
    if k == nil or M.stale[which .. ":" .. k] then return nil end
    local B = NS().BGN
    return B[which] and B[which][k]
end
local function Cap(s) return (s:gsub("^.", string.upper)) end
local function Title(id) local uk = D("config", id) return uk and (uk .. "  " .. S().ICON) end
local function Sub(id) local uk = D("config", id .. "Description") return uk and uk:format(NAME) end

function M.want(name)
    local kind, a, b = name:match("^(%a+):([^:]+):?(.*)$")
    if kind == "core" or kind == "config" then return D(kind, a) end
    if kind == "faq" then return D("faq", tonumber(a)) end
    if kind == "class" then return D("core", TITLES[a]) end
    if kind == "rule" then return D("core", RULES[a]) end
    if kind == "bind" then return D("core", BINDS[a]) end
    if kind == "panel" then
        if a == "GeneralOptions" and b == "title" then return nil end
        return (b == "title" and Title or Sub)(a)
    end
    if kind == "win" then
        if b == "title" then local uk = D("core", TITLES[Cap(a)]) return uk and uk:format(S().owner) end
        return D("core", b)
    end
    if kind == "page" then
        if b == "head" then return a ~= "GeneralOptions" and Title(a) or nil end
        if b == "sub" then return Sub(a) end
        local i = b:match("^faq(%d)$")
        if i then local uk = D("faq", tonumber(i)) return uk and (uk:gsub("ADDON", NAME)) end
        return D("config", b)
    end
end

-- What Bagnon shows for locale key `key` formatted with the values it passes (the halves check).
function M.shows(which, key, ...)
    local t = App(which == "core" and NAME or "Bagnon_Config")
    local s = t and rawget(t, key)
    if type(s) ~= "string" then return nil end
    local ok, out = pcall(string.format, s, ...)
    return ok and out or nil
end

-- The stand-in and the player.
function M.open(id) rawget(_G, NAME).Frames:Show(id) end
function M.pages(on)
    for _, id in ipairs(S().PAGES) do
        local p = rawget(_G, NAME)[id]
        p:Hide()
        if on then p:Show() end
    end
end
function M.loaded(name) return IsAddOnLoaded(name) and true or false end
function M.standIn() return S() ~= nil end
function M.on() return NS().On() end
function M.count() return NS().Locale.Count() end
function M.fontCount() return NS().Fonts.Count() end
function M.wrapOk() return NS().Locale.WrapOk() end
function M.late() return NS().Locale.LateConfig() end

-- Fonts read back: (Cyrillic texts in our font, Cyrillic texts not in it, other texts in it).
function M.fonts()
    local good, bad, wrong = 0, 0, 0
    for _, fs in pairs(S().texts) do
        local t, cyr = fs:GetText(), UADD.IsCyrFont((fs:GetFont()))
        if t and t:find("[\208-\210]") then
            if cyr then good = good + 1 else bad = bad + 1 end
        elseif cyr then
            wrong = wrong + 1
        end
    end
    return good, bad, wrong
end

function M.key(down)
    H.keys.SHIFT = down
    H.fire("MODIFIER_STATE_CHANGED", "LSHIFT", down and 1 or 0)
    M.wait(0.4)                         -- UADD/Original.lua switches once the key is held a while
end
function M.wait(seconds) for _ = 1, math.ceil(seconds / 0.05 - 1e-6) do H.step(0.05) end end
function M.uadd(msg) return H.call("/uadd " .. msg, SlashCmdList.UADD, msg) end

-- Speed of the miss paths: what a hooked FontString runs on each English text (its font stays; the
-- harness's own SetText and hook wrapper make garbage of their own, so the hook body is timed), a text
-- we have no Ukrainian for, and a frame that is not Bagnon's: little time, no garbage, n times each.
function M.speed(n)
    local fs, Lc, F = S().texts["win:inventory:Drag"], NS().Locale, NS().Fonts
    local miss, other = "Glimmering Quixberry", CreateFrame("Frame")
    fs:SetText(miss) F.Decide(fs) Lc.Ukrainian(miss) F.Ours(other)
    collectgarbage("collect")
    collectgarbage("stop")
    local kb0 = collectgarbage("count")
    local t0 = debugprofilestop()
    for _ = 1, n do F.Decide(fs) end
    for _ = 1, n do Lc.Ukrainian(miss) end
    for _ = 1, n do F.Ours(other) end
    local ms = debugprofilestop() - t0
    local kb = collectgarbage("count") - kb0
    collectgarbage("restart")
    return ms, kb
end
