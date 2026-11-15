-- UADD core: hold a key to see the original English for a moment, as in UALL Forever (UALLF).
--
-- The key is UALLF's own "show original" key when UALLF is loaded (UALLFSettingsDB.originalKey,
-- a global we only read: "SHIFT", "CTRL", "ALT" or "NONE" for no key), and Shift otherwise.
-- UALLF's reverse mode (English unless the key is held) is not copied here.
--
-- A module calls UADD.OnOriginal(fn[, name]). fn(true) runs once the key has been held for HOLD seconds,
-- fn(false) as soon as it comes up, and only after a true. A quick tap does nothing: Shift is also
-- pressed for capital letters, shift-clicks (loot, quest links, which must keep the Ukrainian
-- names) and Shift keybinds, and every switch redraws Questie's tracker. Nothing switches while
-- a text box has the keyboard (typing in chat).
--
-- We listen to MODIFIER_STATE_CHANGED. The game does not send it when the key comes up outside
-- the game window (Alt-Tab), so while the original is shown, and only then, a ticker checks the
-- key every POLL seconds. Entering and leaving combat checks it too.
--
-- In a fight the key does nothing (Shift is a common keybind there, and a switch redraws texts):
-- a fight that starts with the original shown gives the Ukrainian back once, and when it ends a key
-- still held shows the original at once. /uadd combat off (UADD_DB.keyInCombat = true) turns this off.

local U = UADD
local listeners = {}
U.originalShown = false     -- true after the listeners were told true, until they are told false
U.originalPoll = nil        -- the ticker while the original is shown
U.originalPerf = {}         -- per listener: { name, down = ms, up = ms } of the last switch (/uadd perf)

local HOLD, POLL = 0.25, 0.2
local DOWN = { SHIFT = "IsShiftKeyDown", CTRL = "IsControlKeyDown", ALT = "IsAltKeyDown" }

local function Loaded(name)
    local fn = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    if type(fn) ~= "function" then return false end
    local ok, yes = pcall(fn, name)
    return ok and yes and true or false
end

-- "SHIFT", "CTRL", "ALT", or nil when the player chose no key in UALLF.
function U.OriginalKey()
    local s = _G.UALLFSettingsDB
    if Loaded("UALLF") and type(s) == "table" and s.originalKey ~= nil then
        local key = s.originalKey
        if key == "NONE" then return nil end
        return DOWN[key] and key or "SHIFT"
    end
    return "SHIFT"
end

-- true while the key is held (at once, without the HOLD delay).
function U.ShowOriginal()
    local key = U.OriginalKey()
    local down = key and _G[DOWN[key]]
    return type(down) == "function" and down() and true or false
end

-- The module's folder name without "UADD_" (for /uadd perf), read from the call stack. "?" when unknown.
local function Caller()
    local ok, stack = pcall(debugstack, 3)
    return ok and type(stack) == "string" and stack:match("UADD_(%w+)") or "?"
end

-- name (optional) labels fn in /uadd perf; without it the module's folder name is used.
function U.OnOriginal(fn, name)
    if type(fn) ~= "function" then return end
    listeners[#listeners + 1] = fn
    U.originalPerf[#listeners] = { name = type(name) == "string" and name or Caller() }
end

-- true while a text box (chat, a search field) has the keyboard.
local function Typing()
    local ok, focus = pcall(GetCurrentKeyBoardFocus)
    return ok and focus ~= nil
end

local function Tell(show)
    U.originalShown = show
    if show and not U.originalPoll then
        U.originalPoll = C_Timer.NewTicker(POLL, function() U.CheckOriginal() end)
    elseif not show and U.originalPoll then
        U.originalPoll:Cancel()
        U.originalPoll = nil
    end
    local clock = type(debugprofilestop) == "function" and debugprofilestop
    for i, fn in ipairs(listeners) do
        local t0 = clock and clock()
        U.SafeCall(fn, show)
        local perf = U.originalPerf[i]
        if t0 and perf then perf[show and "down" or "up"] = clock() - t0 end
    end
end

local keyDown = false       -- the key went down and no HOLD check has given up on it yet
local press = 0             -- counts presses and releases: a HOLD check for an older press does nothing
local fighting = false      -- between PLAYER_REGEN_DISABLED and PLAYER_REGEN_ENABLED

-- true unless the player turned it off (/uadd combat off saves UADD_DB.keyInCombat = true).
function U.IgnoreKeyInCombat()
    return not (type(UADD_DB) == "table" and UADD_DB.keyInCombat == true)
end

-- true while the key must be ignored: in combat, unless the player turned that off.
local function Blocked()
    if not U.IgnoreKeyInCombat() then return false end
    if fighting then return true end
    local ok, yes = pcall(InCombatLockdown)
    return ok and yes and true or false
end

-- Looks at the key: lets go at once, or starts the HOLD wait when it just went down.
function U.CheckOriginal()
    local down = U.ShowOriginal()
    if not down then
        if keyDown then keyDown, press = false, press + 1 end
        if U.originalShown then Tell(false) end
        return
    end
    if keyDown or U.originalShown or Blocked() then return end
    keyDown, press = true, press + 1
    local mine = press
    C_Timer.After(HOLD, function()
        if mine ~= press or U.originalShown then return end
        if U.ShowOriginal() and not Typing() and not Blocked() then
            Tell(true)
        else
            keyDown = false     -- not now: a later key change looks again
        end
    end)
end

-- A fight that starts while the original is shown gives the Ukrainian back, once. When it ends, the
-- key counts as it is at that moment: still held, the original shows at once (it was held long enough).
local function Combat(starts)
    fighting = starts
    if not U.IgnoreKeyInCombat() then return U.CheckOriginal() end
    if starts then
        if U.originalShown then
            keyDown, press = false, press + 1
            Tell(false)
        end
    elseif not U.originalShown and U.ShowOriginal() and not Typing() then
        keyDown, press = true, press + 1
        Tell(true)
    else
        U.CheckOriginal()
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("MODIFIER_STATE_CHANGED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then Combat(true)
    elseif event == "PLAYER_REGEN_ENABLED" then Combat(false)
    else U.CheckOriginal() end
end)
