-- UADD core: hold a key to see the original English for a moment, as in UALL Forever (UALLF).
--
-- The key is UALLF's own "show original" key when UALLF is loaded (UALLFSettingsDB.originalKey,
-- a global we only read: "SHIFT", "CTRL", "ALT" or "NONE" for no key); without UALLF, ClassicUA's
-- tooltip key when ClassicUA is loaded (U.ClassicUAKey); Shift otherwise, or for a value we do not know.
-- UALLF's reverse mode (UALLFSettingsDB.reverseOriginal) is followed the same way: then the
-- English shows unless the key is held, and holding the key shows the Ukrainian. Without UALLF
-- there is no reverse mode.
--
-- A module calls UADD.OnOriginal(fn[, name]). fn(true) means "show the English", fn(false) "show the
-- Ukrainian"; each is told only when it changes. Normally fn(true) runs once the key has been held for
-- HOLD seconds, fn(false) as soon as it comes up; in reverse mode the other way round, and fn(true)
-- runs once when the game world is loaded, or at the next key change after the setting is turned on.
-- A quick tap does nothing: Shift is also pressed for capital letters, shift-clicks (loot, quest
-- links, which must keep the Ukrainian names) and Shift keybinds, and every switch redraws texts.
-- Nothing switches while a text box has the keyboard (typing in chat).
--
-- We listen to MODIFIER_STATE_CHANGED. The game does not send it when the key comes up outside
-- the game window (Alt-Tab), so while the key counts as held, and only then, a ticker checks the
-- key every POLL seconds. Entering and leaving combat checks it too.
--
-- In a fight the key does nothing (Shift is a common keybind there, and a switch redraws texts):
-- a fight that starts with the key counted as held lets it go once (normal mode: Ukrainian; reverse
-- mode: English), but in lockdown nothing is redrawn, so the windows change when the fight ends; then a
-- key still held counts at once. /uadd combat off
-- (UADD_DB.keyInCombat = true) turns this off.
--
-- In combat lockdown no listener runs, unless /uadd combat off (docs/LESSONS3.md): they redraw addon
-- windows, some with secure buttons, and write globals. The last state asked for then waits and runs
-- once at PLAYER_REGEN_ENABLED; a state that ends where it started runs nothing. U.originalShown
-- always says what the listeners were last told (what the windows show).

local U = UADD
local listeners = {}
U.originalShown = false     -- true after the listeners were told true, until they are told false
U.originalPoll = nil        -- the ticker while the key counts as held
U.originalPerf = {}         -- per listener: { name, down = ms, up = ms } of the last switch (/uadd perf)

local HOLD, POLL = 0.25, 0.2
local DOWN = { SHIFT = "IsShiftKeyDown", CTRL = "IsControlKeyDown", ALT = "IsAltKeyDown" }

local function Loaded(name)
    local fn = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
    if type(fn) ~= "function" then return false end
    local ok, yes = pcall(fn, name)
    return ok and yes and true or false
end

local function Field(t, k)            -- t[k], or nil when t is not a table or reading it throws
    if type(t) ~= "table" then return nil end
    local ok, v = pcall(function() return t[k] end)
    return ok and v or nil
end

-- ClassicUA's tooltip key (ClassicUA_Options.tooltip_original_key, a global we only read): "ALT", "CTRL",
-- "SHIFT", or nil when ClassicUA is not loaded or the value is not one of those (then today's Shift).
-- ClassicUA has no "no key" choice and no reverse mode; its quest windows have their own language button.
function U.ClassicUAKey()
    if not Loaded("ClassicUA") then return nil end
    local key = Field(_G.ClassicUA_Options, "tooltip_original_key")
    return type(key) == "string" and DOWN[key] and key or nil
end

-- "SHIFT", "CTRL", "ALT", or nil when the player chose no key in UALLF. UALLF loaded: its key.
-- Only ClassicUA loaded: its tooltip key. Neither, or a value we do not know: Shift.
function U.OriginalKey()
    if Loaded("UALLF") then
        local key = Field(_G.UALLFSettingsDB, "originalKey")
        if key == "NONE" then return nil end
        return type(key) == "string" and DOWN[key] and key or "SHIFT"
    end
    return U.ClassicUAKey() or "SHIFT"
end

-- true when UALLF is loaded and the player turned on its reverse mode (English unless the key is held).
function U.OriginalReverse()
    return Loaded("UALLF") and Field(_G.UALLFSettingsDB, "reverseOriginal") == true
end

-- ── Which key: the chat notice ────────────────────────────────────────────────────────────────
-- Printed once, at the first login (U.KeyNotice from Core.lua), and again only when the set of
-- Ukrainian addons that own a key (UALLF, ClassicUA) changes: UADD_DB.keyNotice keeps the last set.
-- /uadd shows the same lines. Neither addon: no notice. Both are named side by side, neither as better.

local NAMES = { SHIFT = "Shift", CTRL = "Ctrl", ALT = "Alt" }
local WINDOWS = "вікна аддонів покажуть англійський оригінал"

-- "UALLF", "ClassicUA", "UALLF+ClassicUA", or "" for neither.
function U.KeySources()
    local uall, cua = Loaded("UALLF"), Loaded("ClassicUA")
    return (uall and cua and "UALLF+ClassicUA") or (uall and "UALLF") or (cua and "ClassicUA") or ""
end

-- UALLF's part: "Затисніть Shift — вікна аддонів ...", for UALLF's key and reverse mode.
local function UallLine(key)
    if not key then return "Клавішу оригіналу для вікон аддонів вимкнено в налаштуваннях UALL Forever." end
    if U.OriginalReverse() then
        return "Затисніть " .. NAMES[key] .. " — вікна аддонів стануть українськими (обернений режим UALL Forever)."
    end
    return "Затисніть " .. NAMES[key] .. " — " .. WINDOWS .. " (клавіша з налаштувань UALL Forever)."
end

-- The notice: one or two chat lines (without the "UADD" mark), or {} when neither addon is loaded.
function U.KeyNoticeLines()
    local set, key, cua = U.KeySources(), U.OriginalKey(), U.ClassicUAKey()
    if set == "UALLF" or (set == "UALLF+ClassicUA" and not cua) then
        return { UallLine(key) }
    elseif set == "ClassicUA" then
        if not cua then return { "Затисніть " .. NAMES[key] .. " — " .. WINDOWS .. "." } end
        return { "Затисніть " .. NAMES[cua] .. " — англійський оригінал покажуть вікна аддонів і підказки ClassicUA"
                     .. " (клавіша з /ua).",
                 "У вікнах завдань ClassicUA має свою кнопку мови." }
    elseif set == "UALLF+ClassicUA" then
        if key == cua and not U.OriginalReverse() then
            return { "Затисніть " .. NAMES[key] .. " — англійський оригінал покажуть вікна аддонів (клавіша UALL Forever)"
                         .. " і підказки ClassicUA (клавіша з /ua)." }
        end
        local out = { UallLine(key) .. " Підказки ClassicUA — клавіша " .. NAMES[cua] .. "." }
        if key ~= cua then
            out[2] = "Одна клавіша для всього: виберіть ту саму в налаштуваннях UALL Forever і в /ua (ClassicUA)."
        end
        return out
    end
    return {}
end

-- At login: the notice when the set of addons differs from the one saved at the last notice.
function U.KeyNotice()
    if type(UADD_DB) ~= "table" then return end
    local set = U.KeySources()
    if UADD_DB.keyNotice == set then return end
    for _, line in ipairs(U.KeyNoticeLines()) do U.Print(line) end
    UADD_DB.keyNotice = set
end

-- true while the key is held (at once, without the HOLD delay).
function U.KeyHeld()
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

-- true while the game's combat lockdown is on (protected frames, secure buttons). false on any error.
local function Locked()
    local ok, yes = pcall(InCombatLockdown)
    return ok and yes and true or false
end

local function Run(show)
    U.originalShown = show
    local clock = type(debugprofilestop) == "function" and debugprofilestop
    for i, fn in ipairs(listeners) do
        local t0 = clock and clock()
        U.SafeCall(fn, show)
        local perf = U.originalPerf[i]
        if t0 and perf then perf[show and "down" or "up"] = clock() - t0 end
    end
end

-- The listeners told again what the windows show: English, then ours (BoxGuard.lua: a text our font cannot draw
-- stays English then). Nothing while the English shows, or in combat lockdown.
function U.TellAgain()
    if U.originalShown or Locked() then return end
    Run(true)
    Run(false)
end

-- In combat lockdown no listener runs (they redraw addon windows, some with secure buttons, and write
-- globals): the state asked for waits in `waiting` and runs once when the fight ends (Flush), with the
-- last state asked. A state that ends where the listeners were last told runs nothing.
local waiting = nil         -- true / false: asked for in combat, not told yet; nil: nothing waits

local function Tell(show)
    if Locked() and U.IgnoreKeyInCombat() then   -- /uadd combat off: the player wants the key in a fight
        if show ~= U.originalShown then waiting = show else waiting = nil end
        return
    end
    waiting = nil
    if show ~= U.originalShown then Run(show) end
end

local function Flush()
    if waiting ~= nil then Tell(waiting) end
end
U.OriginalWaiting = function() return waiting end   -- for the checks

local keyDown = false       -- the key went down and no HOLD check has given up on it yet
local engaged = false       -- the key was held for HOLD and has not come up since
local press = 0             -- counts presses and releases: a HOLD check for an older press does nothing
local fighting = false      -- between PLAYER_REGEN_DISABLED and PLAYER_REGEN_ENABLED

-- Sets whether the key counts as held, and tells the listeners when what they show changes: the
-- English while it is held, or in reverse mode while it is not. Engage(engaged) only looks again
-- at the reverse setting.
local function Engage(on)
    engaged = on
    if on and not U.originalPoll then
        U.originalPoll = C_Timer.NewTicker(POLL, function() U.CheckOriginal() end)
    elseif not on and U.originalPoll then
        U.originalPoll:Cancel()
        U.originalPoll = nil
    end
    Tell(engaged ~= U.OriginalReverse())    -- tells only a change; in combat it waits (Tell)
end

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
    local down = U.KeyHeld()
    if not down then
        if keyDown then keyDown, press = false, press + 1 end
        Engage(false)       -- also follows a reverse setting changed since
        return
    end
    if keyDown or engaged or Blocked() then return end
    keyDown, press = true, press + 1
    local mine = press
    C_Timer.After(HOLD, function()
        if mine ~= press or engaged then return end
        if U.KeyHeld() and not Typing() and not Blocked() then
            Engage(true)
        else
            keyDown = false     -- not now: a later key change looks again
        end
    end)
end

-- A fight that starts while the key counts as held lets it go, once. When it ends, the key counts
-- as it is at that moment: still held, it counts at once (it was held long enough).
local function Combat(starts)
    fighting = starts
    if not U.IgnoreKeyInCombat() then return U.CheckOriginal() end
    if starts then
        if engaged then
            keyDown, press = false, press + 1
            Engage(false)
        end
    elseif not engaged and U.KeyHeld() and not Typing() then
        keyDown, press = true, press + 1
        Engage(true)
    else
        U.CheckOriginal()
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("MODIFIER_STATE_CHANGED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then Combat(true)
    elseif event == "PLAYER_REGEN_ENABLED" then
        U.SafeCall(Combat, false)
        Flush()                     -- what waited in combat, once, with the last state
    elseif event == "PLAYER_ENTERING_WORLD" then Engage(engaged)   -- reverse mode: English from the start
    else U.CheckOriginal() end
end)
