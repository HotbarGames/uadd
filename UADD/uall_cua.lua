-- UADD core: game names from ClassicUA first; UALL Forever (uall.lua) fills in what ClassicUA lacks.
--
-- ClassicUA keeps its glossary private. On Forever the one name path we can reach is the SetText hook it
-- puts on the zone texts (MinimapZoneText, ZoneTextString, SubZoneTextString) when the player enters the
-- world: it looks the English up in its glossary (zones, NPCs, items, spells, quest titles and more) and
-- writes the Ukrainian back in the same call. As uall.lua does for UALL Forever, we call that hook chain
-- with our own hidden font string as self and keep what ClassicUA writes. A game widget is never written
-- to, so nothing on screen flickers. UALL Forever hooks the same widgets, so an answer counts only when
-- debugstack names ClassicUA. We never copy its data, never write into its tables or options.
-- See docs/research-classicua-names.md.
--
-- Text with "[", "(", "|", a line break or spaces at its edges is not asked: ClassicUA reads such text in
-- other ways and could answer for half of it. Any error or unknown state means "ClassicUA is not active":
-- the routes then work as uall.lua alone does (UALL Forever, or the English as it was).
--
-- Loaded after Collector.lua, so it wraps the routes of uall.lua, QuestVariants.lua and Routes.lua.

local U = UADD.UALL
if type(U) ~= "table" then return end

local NAME = "ClassicUA"
local WIDGETS = { "MinimapZoneText", "ZoneTextString", "SubZoneTextString" }   -- best first
local CANARY = { "Elwynn Forest", "Durotar" }
local MAX_LEN = 120          -- longer text is no single name
local MAX_CACHE = 4000       -- entries before the cache starts again (it never grows without end)
local TRIES, TRY_GAP = 3, 3  -- tries to find ClassicUA's hook, seconds between them

local ready = false          -- PLAYER_ENTERING_WORLD seen and 1 s passed: ClassicUA's hooks are on
local broken = false         -- its test names failed TRIES times once ready: not asked again this session
local chosen                 -- the zone text whose hook chain gave ClassicUA's answer to a test name
local cache, cacheN = {}, 0  -- English -> Ukrainian, or false for a real miss

-- ── Is ClassicUA active ───────────────────────────────────────────────────────────────────────

local function Loaded()
    if C_AddOns and C_AddOns.IsAddOnLoaded then
        local loading, done = C_AddOns.IsAddOnLoaded(NAME)
        return loading and done ~= false
    end
    return IsAddOnLoaded and IsAddOnLoaded(NAME) and true or false
end

-- ClassicUA's own test for a zone text: options.can_translate("translate_zone"). With dev_mode on it
-- writes every miss into its log as a missing zone, so we do not ask then either.
local function OptionsOn()
    if not Loaded() then return false end
    local o = _G.ClassicUA_Options
    if type(o) ~= "table" then return false end
    if o.translate_zone == false or o.disable_all_translation or o.dev_mode then return false end
    return true
end

local function Active()
    if broken then return false end
    local ok, on = pcall(OptionsOn)
    return ok and on == true
end

-- ── The probe ─────────────────────────────────────────────────────────────────────────────────

local probing, probeInput, captured
local mine                   -- our own hidden font string; false: it could not be made

local function FromClassicUA()
    local ok, stack = pcall(debugstack)
    return ok and type(stack) == "string" and stack:find("[/\\]ClassicUA[/\\]") ~= nil
end

-- Runs inside ClassicUA's (or UALL Forever's) hook: must never raise.
local function Catch(text)
    if type(text) ~= "string" or text == probeInput then return end
    if not text:find("[\208\209\210]") or text:find("{", 1, true) then return end
    if FromClassicUA() then captured = text end
end

local function OnSetText(self, text)
    if probing ~= self or captured then return end
    pcall(Catch, text)
end

local function Mine()
    if mine == nil then
        mine = false
        local ok, fs = pcall(function()
            local f = CreateFrame("Frame")
            f:Hide()
            local s = f:CreateFontString(nil, "ARTWORK", "GameFontNormal")
            hooksecurefunc(s, "SetText", OnSetText)
            return s
        end)
        if ok and type(fs) == "table" then mine = fs end
    end
    return mine or nil
end

local function Free(fs)
    if type(fs) ~= "table" or type(fs.SetText) ~= "function" then return false end
    if fs.IsForbidden then
        local ok, forbidden = pcall(fs.IsForbidden, fs)
        if not ok or forbidden then return false end
    end
    return true
end

-- Calls fs's SetText hook chain on our hidden string with en; returns ClassicUA's Ukrainian or nil.
local function Ask(fs, en)
    if probing then return nil end
    local s = Mine()
    if not s then return nil end
    local ok, chain = pcall(function() return fs.SetText end)
    if not ok or type(chain) ~= "function" then return nil end
    probing, probeInput, captured = s, en, nil
    pcall(chain, s, en)
    local ua = captured
    probing, probeInput, captured = nil, nil, nil
    return ua
end

-- The zone text to ask through, found with the test names. ClassicUA may put its hooks on a little later
-- than we expect, so a try that gets no answer is made again, TRY_GAP seconds later, TRIES times in all;
-- only then is it broken for the session. Few tries: a ClassicUA hook that throws reaches the game's error
-- handler each time. Between tries nothing is asked (nil: the route falls through to UALL Forever).
local tries, nextTry = 0, 0
local function Route()
    if chosen then return chosen end
    if broken then return nil end
    local now = GetTime and GetTime() or 0
    if now < nextTry then return nil end
    for _, en in ipairs(CANARY) do
        for _, name in ipairs(WIDGETS) do
            local fs = _G[name]
            if Free(fs) and Ask(fs, en) then chosen = fs return fs end
        end
    end
    tries = tries + 1
    if tries >= TRIES then broken = true else nextTry = now + TRY_GAP end
    return nil
end

-- ── Lookup ────────────────────────────────────────────────────────────────────────────────────

local function Fit(en)
    if type(en) ~= "string" then return nil end
    local n = #en
    if n == 0 or n > MAX_LEN then return nil end
    if en:find("[%[%(|%c]") or en:find("^%s") or en:find("%s$") then return nil end   -- %c: a line break, a tab
    return en
end

-- ClassicUA's glossary keeps some names in small letters (an item, as used mid-sentence). A name whose
-- English starts with a capital gets a capital first letter too, as UALL Forever writes it.
local function Cap(en, ua)
    if not en:find("^%u") then return ua end
    local b1, b2 = ua:byte(1, 2)
    if not b2 or b1 < 0xD0 or b1 > 0xD2 then return ua end
    local cp, up = (b1 - 0xC0) * 64 + (b2 - 0x80)
    if cp >= 0x430 and cp <= 0x44F then up = cp - 0x20          -- а-я
    elseif cp >= 0x450 and cp <= 0x45F then up = cp - 0x50      -- є, і, ї and the rest of that row
    elseif cp == 0x491 then up = 0x490 end                      -- ґ
    if not up then return ua end
    return string.char(0xC0 + math.floor(up / 64), 0x80 + up % 64) .. ua:sub(3)
end

-- ClassicUA's word: ua; nil, true = not now (ask again later); nil = it has none, or en is not asked.
local function Cua(en)
    local okFit, fit = pcall(Fit, en)
    en = okFit and fit or nil
    if not en then return nil end
    local hit = cache[en]
    if hit ~= nil then return hit or nil end
    if not ready or (InCombatLockdown and InCombatLockdown()) then return nil, true end
    if probing then return nil end   -- asked from inside a probe: no answer now, no "miss" kept, no try spent
    local fs = Route()
    if not fs then return nil end
    local ua = Ask(fs, en)
    ua = ua and Cap(en, ua)
    if cacheN >= MAX_CACHE then wipe(cache) cacheN = 0 end
    cache[en] = ua or false
    cacheN = cacheN + 1
    return ua
end

-- UALL Forever's setting for this kind of name is off: it would say "not now" for good.
local function GateOff(kind)
    local ok, off = pcall(function()
        local spec = U.probe.KINDS[kind]
        return spec ~= nil and U.probe.Settings()[spec.gate] == false
    end)
    return not ok or off == true
end

local function UallfOn()
    local ok, on = pcall(U.UallfAvailable)
    return ok and on == true
end

-- ClassicUA first; on a miss UALL Forever when it can answer; with ClassicUA not active, as before.
local function Pick(kind, en, uallf, ...)
    if not Active() then return uallf(...) end
    local ok, ua, wait = pcall(Cua, en)
    if not ok then broken = true return uallf(...) end
    if ua then return ua end
    if wait then return nil, true end
    if UallfOn() and not GateOff(kind) then return uallf(...) end
    return nil
end

local function Wrap(kind, old)
    if type(old) ~= "function" then return old end
    return function(en)
        local ok, ua, wait = pcall(Pick, kind, en, old, en)
        if ok then return ua, wait end
        return nil
    end
end

U.Zone, U.Npc, U.Item = Wrap("zone", U.Zone), Wrap("npc", U.Npc), Wrap("item", U.Item)
U.Text, U.Class, U.Spell = Wrap("quest", U.Text), Wrap("quest", U.Class), Wrap("spell", U.Spell)

local quest = U.Quest
if type(quest) == "function" then
    local function Title(questId, englishTitle)
        if type(englishTitle) == "string" and englishTitle ~= "" then return englishTitle end
        if type(questId) == "number" and C_QuestLog and C_QuestLog.GetTitleForQuestID then
            local t = C_QuestLog.GetTitleForQuestID(questId)
            if type(t) == "string" and t ~= "" then return t end
        end
    end
    function U.Quest(questId, englishTitle)
        local ok, ua, wait = pcall(function()
            local okT, en = pcall(Title, questId, englishTitle)
            return Pick("quest", okT and en or nil, quest, questId, englishTitle)
        end)
        if ok then return ua, wait end
        return nil
    end
end

-- A kind is off only when UALL Forever's setting for it is off and ClassicUA is not active.
local routeOff = U.RouteOff
if type(routeOff) == "function" then
    function U.RouteOff(kind)
        if Active() then return false end
        return routeOff(kind)
    end
end

-- ── Public ────────────────────────────────────────────────────────────────────────────────────

-- The name sources UADD asks, in ask order: { "ClassicUA", "UALLF" }, one of them, or {}.
function U.Providers()
    local out = {}
    if Active() then out[#out + 1] = NAME end
    if UallfOn() then out[#out + 1] = "UALLF" end
    return out
end

function U.HasProvider(name)
    for _, p in ipairs(U.Providers()) do
        if p == name then return true end
    end
    return false
end

function U.IsAvailable() return Active() or UallfOn() end

-- Part of the saved-cache signatures: "" without ClassicUA, so caches saved before it stay valid.
function U.ProviderSig()
    if not Active() then return "" end
    local ok, v = pcall(function() return UADD.Meta(NAME, "Version") end)
    return NAME .. "=" .. tostring(ok and v or nil)
end

-- ── When to ask ───────────────────────────────────────────────────────────────────────────────

pcall(function()
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", function()
        if ready then return end
        C_Timer.After(1, function() ready = true end)
    end)
end)

-- For /uadd test and the harness: the probe without the cache, and the state. Ask gives
-- (Ukrainian or nil, why there is none: "not ready yet", "in combat", or nil).
local function TestAsk(en)
    if not ready then return nil, "not ready yet" end
    if InCombatLockdown and InCombatLockdown() then return nil, "in combat" end
    local fs = not probing and Active() and Route()
    if fs then return Ask(fs, en) end
    return nil, (not broken and tries > 0) and "not ready yet" or nil
end

U.cua = { Active = Active, Ask = TestAsk,
          State = function() return ready, broken, chosen ~= nil end, Fit = Fit, Cap = Cap,
          CacheSize = function() return cacheN end }
