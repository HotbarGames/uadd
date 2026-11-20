-- UADD: a module that fails falls back to English, never to a broken game.
--
-- U.Safe(key, fn) -> a function that runs fn(...) under pcall, for hooks and handlers of module `key`.
--   It does nothing once that module is off for this session. An error is reported (UADD.SafeCall's
--   way: once per place) and counted.
-- U.SafeCall errors are counted too: the module is the UADD_<X> folder named in the error's place.
-- A module is turned off for this session (U.TurnOff) when:
--   * it failed 5 times this session, or
--   * it failed while it was being set up: before the game settled after login (its Install ran
--     then), or during "/uadd <key> on". All hooks or none: a half-made setup stays off.
-- Turned off means the module's own "/uadd <key> off" runs (its chat lines silenced), one frame
-- later, so what the failed setup did is undone by the module's own off path and its texts are
-- English again; hooks that cannot be removed stay inert (they check the module's on flag, and
-- U.Safe ones check ours). One Ukrainian chat line says so. It is noted in UADD_DB.health and shown
-- in /uadd. At logout the module's own setting is put back, so the next session tries again.

local U = UADD
local LIMIT = 5                -- errors a session before a module is turned off
local SETTLE = 3               -- seconds after login while a failure counts as a failed setup
local folderKey = {}           -- "UADD_Attune" -> "attune"
local count, off, wasOn = {}, {}, {}
local settled = false

local function Health()
    local db = U.DB()
    if type(db.health) ~= "table" then db.health = {} end
    return db.health
end

-- The module key behind an error text ("...AddOns/UADD_Attune/Words.lua:12: ..."), or nil.
local function KeyOf(err)
    local folder = type(err) == "string" and err:match("AddOns[/\\](UADD_[%w_]+)[/\\]")
    return folder and folderKey[folder] or nil
end

-- Which folder registered a module: read once, from the stack of RegisterModule's caller.
local register = U.RegisterModule
function U.RegisterModule(key, spec)
    register(key, spec)
    if type(key) ~= "string" then return end
    local ok, st = pcall(debugstack, 2, 4, 0)
    local folder = ok and type(st) == "string" and st:match("AddOns[/\\](UADD_[%w_]+)[/\\]")
    if folder then folderKey[folder] = key:lower() end
end

local function Off(key, why)
    local spec = U.modules[key]
    if not spec or type(spec.Command) ~= "function" then return end
    local db = type(UADD_DB) == "table" and type(UADD_DB.modules) == "table" and UADD_DB.modules[key]
    wasOn[key] = type(db) == "table" and db.enabled ~= false
    U.quiet = true
    pcall(spec.Command, "off")
    U.quiet = false
    local h = Health()
    h.off = type(h.off) == "table" and h.off or {}
    h.off[key] = { why = why, when = type(date) == "function" and date("%Y-%m-%d %H:%M") or "", err = U.lastError and
        tostring(U.lastError):sub(1, 200) or "" }
    U.Print(("|cffff6060модуль %s вимкнено до кінця сесії|r (%s): його написи знову англійською. "
        .. "Повідомте автору UADD, будь ласка."):format(spec.title or key, why))
end

-- Turns module `key` off for this session, once. `why`: a short Ukrainian reason.
function U.TurnOff(key, why)
    if type(key) ~= "string" or off[key] then return end
    off[key] = true
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function() pcall(Off, key, why) end)   -- after the failed setup has run
    else
        pcall(Off, key, why)
    end
end

function U.IsTurnedOff(key) return off[key] == true end

-- One error of module `key` (nil: not a module's). Never throws.
function U.Fault(key, err)
    if not key or off[key] then return end
    count[key] = (count[key] or 0) + 1
    local h = Health()
    h.errors = type(h.errors) == "table" and h.errors or {}
    h.errors[key] = (tonumber(h.errors[key]) or 0) + 1
    if not settled or U.installing == key then
        U.TurnOff(key, "помилка під час запуску")
    elseif count[key] >= LIMIT then
        U.TurnOff(key, LIMIT .. " помилок")
    end
end

-- Core's SafeCall sends every error here.
function U.OnFault(err)
    U.Fault(KeyOf(err) or U.installing, err)
end

local function Done(key, ok, ...)
    if not ok then
        local err = tostring((...))
        U.ReportError(err)                -- once per place, like every SafeCall error
        U.Fault(key, err)
        return
    end
    return ...
end

function U.Safe(key, fn)
    key = type(key) == "string" and key:lower() or key
    return function(...)
        if off[key] or type(fn) ~= "function" then return end
        return Done(key, pcall(fn, ...))
    end
end

-- Lines for /uadd: modules off this session and what the guard (UADD/Guard.lua) put right.
function U.HealthLines()
    local out = {}
    for key in pairs(off) do
        local spec = U.modules[key]
        out[#out + 1] = ("  |cffff6060%s|r: вимкнено до кінця сесії через помилки"):format(spec and spec.title or key)
    end
    for _, line in ipairs(U.GuardLines and U.GuardLines() or {}) do out[#out + 1] = line end
    return out
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        if C_Timer and C_Timer.After then C_Timer.After(SETTLE, function() settled = true end) else settled = true end
        return
    end
    -- Off for this session only: the player's own choice comes back for the next one.
    for key in pairs(off) do
        local db = type(UADD_DB) == "table" and type(UADD_DB.modules) == "table" and UADD_DB.modules[key]
        if wasOn[key] and type(db) == "table" then db.enabled = true end
    end
end)
