-- UADD core: shared helpers, the list of modules and the /uadd command.
-- A module (for example UADD_Questie) is its own addon. It calls UADD.RegisterModule once,
-- keeps its settings in UADD.DB(key) and answers "/uadd <key> ...".

local ADDON = ...

UADD = UADD or {}
local U = UADD

local function Meta(addon, field)
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    if type(get) ~= "function" then return nil end
    local ok, value = pcall(get, addon, field)
    return ok and value or nil
end
U.Meta = Meta
U.version = Meta(ADDON, "Version") or "?"

-- ── Chat output ───────────────────────────────────────────────────────────────────────────────

function U.Print(msg)
    local frame = DEFAULT_CHAT_FRAME
    local text = "|cff4fc3f7UADD|r " .. tostring(msg)
    if frame and frame.AddMessage then frame:AddMessage(text) else print(text) end
end

-- ── SafeCall: pcall that reports each different error once ────────────────────────────────────

local reported = {}

local function Finish(ok, ...)
    if not ok then
        local err = tostring((...))
        U.lastError = err
        if not reported[err] then
            reported[err] = true
            U.Print("|cffff6060помилка:|r " .. err)
        end
    end
    return ok, ...
end

-- Returns ok, results... like pcall. Never throws.
function U.SafeCall(fn, ...)
    if type(fn) ~= "function" then return false, "not a function" end
    return Finish(pcall(fn, ...))
end

-- ── Plain: a text we may read, or nil ─────────────────────────────────────────────────────────
-- The client can hand our code "secret" strings (tooltip lines in combat, for example): any
-- index, match or compare on one throws. Plain(v) is v when it is a string we may read, else nil.
-- Use it on every text read back from the game (GetText and the like) before touching it.

local isSecret = rawget(_G, "issecretvalue")
local function IsEmpty(s) return s == "" end

function U.Plain(v)
    if type(v) ~= "string" then return nil end
    if type(isSecret) == "function" then
        local ok, secret = pcall(isSecret, v)
        if ok and not secret then return v end
        return nil
    end
    if not pcall(IsEmpty, v) then return nil end
    return v
end

-- ── Saved settings ────────────────────────────────────────────────────────────────────────────

-- UADD_DB = { modules = { [key] = { ...module settings... } } }
function U.DB(key)
    if type(UADD_DB) ~= "table" then UADD_DB = {} end
    if type(UADD_DB.modules) ~= "table" then UADD_DB.modules = {} end
    if key == nil then return UADD_DB end
    local db = UADD_DB.modules[key]
    if type(db) ~= "table" then
        db = {}
        UADD_DB.modules[key] = db
    end
    return db
end

-- A Ukrainian name another module already saved (UADD_DB.modules.<key>.cache), or nil. Read only.
-- kind: "zones" (dungeons, wings, zones) or "Npc" (bosses), both keyed by the English name.
-- The Dungeon Journal's copy first (it has every dungeon and boss), then Questie's (zones only).
function U.CachedName(kind, en)
    if type(en) ~= "string" or type(UADD_DB) ~= "table" or type(UADD_DB.modules) ~= "table" then return nil end
    for _, key in ipairs({ "dj", "questie" }) do
        local m = UADD_DB.modules[key]
        local c = type(m) == "table" and type(m.cache) == "table" and m.cache[kind]
        local uk = type(c) == "table" and c[en]
        if type(uk) == "string" and uk ~= "" then return uk end
    end
    return nil
end

-- ── Modules ───────────────────────────────────────────────────────────────────────────────────

-- spec = { title = "Questie", Status = function() return "text" end,
--          Command = function(args) end, help = { "line", ... } }
U.modules, U.order = {}, {}

function U.RegisterModule(key, spec)
    if type(key) ~= "string" or type(spec) ~= "table" then return end
    key = key:lower()
    if not U.modules[key] then U.order[#U.order + 1] = key end
    U.modules[key] = spec
end

local function StatusOf(spec)
    if type(spec.Status) ~= "function" then return "" end
    local ok, text = U.SafeCall(spec.Status)
    return ok and tostring(text or "") or "стан невідомий"
end

local function ListModules()
    U.Print("версія " .. U.version .. ". Модулі:")
    if #U.order == 0 then
        U.Print("  жодного. Увімкніть, наприклад, UADD - Questie у списку аддонів.")
        return
    end
    for _, key in ipairs(U.order) do
        local spec = U.modules[key]
        U.Print(("  |cffffd200%s|r (%s): %s"):format(key, spec.title or key, StatusOf(spec)))
    end
    U.Print("Більше: /uadd <модуль>, наприклад /uadd " .. U.order[1])
    U.Print("  /uadd perf — скільки мс забрав останній показ оригіналу (клавіша вниз / вгору)")
    U.Print("  /uadd combat on|off — чи діє клавіша оригіналу в бою (типово ні)")
end

-- /uadd combat on: the show-original key does nothing in a fight (the default); off: it works there too.
local function CombatKey(arg)
    arg = (arg or ""):lower()
    if arg == "on" then U.DB().keyInCombat = nil elseif arg == "off" then U.DB().keyInCombat = true end
    if U.IgnoreKeyInCombat() then
        U.Print("У бою клавіша оригіналу не діє. Увімкнути її в бою: /uadd combat off")
    else
        U.Print("У бою клавіша оригіналу діє. Вимкнути її в бою: /uadd combat on")
    end
end

local function Ms(v) return v and ("%.2f"):format(v) or "—" end

-- /uadd perf: the time each module took on the last key down and up (UADD.originalPerf).
local function Perf()
    local perf = U.originalPerf or {}
    U.Print("Показ оригіналу, мс (клавіша вниз / вгору), останній раз:")
    local down, up, any = 0, 0, false
    for _, p in ipairs(perf) do
        U.Print(("  |cffffd200%s|r: %s / %s"):format(p.name, Ms(p.down), Ms(p.up)))
        down, up, any = down + (p.down or 0), up + (p.up or 0), any or p.down ~= nil
    end
    if any then U.Print(("  разом: %s / %s"):format(Ms(down), Ms(up)))
    else U.Print("  ще не було: затисніть клавішу оригіналу й спробуйте знову.") end
    U.Print("  UALL Forever: свій час не показує, його список написів закритий для інших аддонів.")
end

SLASH_UADD1 = "/uadd"
SlashCmdList.UADD = function(msg)
    msg = type(msg) == "string" and msg or ""
    local first, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
    first = (first or ""):lower()
    local spec = U.modules[first]
    if first == "perf" and not spec then
        Perf()
    elseif first == "combat" and not spec then
        CombatKey(rest)
    elseif spec and type(spec.Command) == "function" then
        U.SafeCall(spec.Command, rest or "")
    else
        ListModules()
    end
end

-- ── Events ────────────────────────────────────────────────────────────────────────────────────

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == ADDON then
        U.DB()
        U.DB().version = U.version
    end
    -- LibSharedMedia may arrive with any later addon (Questie embeds it), so try each time.
    if U.RegisterFont then U.SafeCall(U.RegisterFont) end
end)
