-- Weekday names in WhatTheWhisper's date lines (the day line in a conversation and its export, the short day
-- in the conversation list).
--   * It copied the game's weekday names (the WEEKDAY_* globals) at load, so they never pass through its
--     locale table. Its two date functions (Format.DayLabel, Format.ListStamp) are looked up on each call,
--     so each is wrapped: when what it gave is one of the game's weekday names (or the first three letters
--     of one, for the list), ours comes back instead (data "Day.<n>", Sunday = 1).
--   * Only while ours is in its table (enUS in force, on, the hold key not held), and only while the
--     game's name is still English (an addon that put another language there wins). The game's globals
--     are never written. Any error gives its own text back.

local _, ns = ...
local U = UADD
local D = {}
ns.Days = D

local WEEKDAYS = { "WEEKDAY_SUNDAY", "WEEKDAY_MONDAY", "WEEKDAY_TUESDAY", "WEEKDAY_WEDNESDAY",
    "WEEKDAY_THURSDAY", "WEEKDAY_FRIDAY", "WEEKDAY_SATURDAY" }
-- The usual short Ukrainian names, Sunday first; used only where the full one ("Day.<n>") is ours too.
local SHORT = { "Нд", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб" }
local wraps = {}                    -- field name -> { orig = its function, fn = ours }

local function Format()
    local a = ns.Swap.Addon()
    local F = a and a.Format
    return type(F) == "table" and F or nil
end

local function First3(s)
    local a = ns.Swap.Addon()
    local T = a and a.Text
    if type(T) == "table" and type(T.Sub) == "function" then
        local ok, v = pcall(T.Sub, s, 1, 3)
        if ok and type(v) == "string" then return v end
    end
    return s:sub(1, 3)
end

-- Ours for one weekday text of it, or nil.
local function Map(out, short)
    local s = U.Plain(out)
    if not s or s == "" or s:find("[\128-\255]") then return nil end
    for i, name in ipairs(WEEKDAYS) do
        local g = rawget(_G, name)
        local ua = ns.AL["Day." .. i]
        if ua and type(g) == "string" and g ~= "" and not g:find("[\128-\255]") then
            if short and s == First3(g) then return SHORT[i] end
            if not short and s == g then return ua end
        end
    end
    return nil
end
D.Map = Map

local function Wrap(F, name, short)
    local orig = F[name]
    if type(orig) ~= "function" or wraps[name] then return end
    local function fn(...)
        local out = orig(...)
        if ns.Swap.On() and not ns.Swap.Saving() then  -- its saved file gets its own names (Swap.lua)
            local ok, ua = U.SafeCall(Map, out, short)
            if ok and ua then return ua end
        end
        return out
    end
    wraps[name] = { orig = orig, fn = fn }
    F[name] = fn
end

-- Once, when the module starts.
function D.Install()
    local F = Format()
    if not F then return end
    Wrap(F, "DayLabel", false)
    Wrap(F, "ListStamp", true)
end

-- Off: its own functions back, unless someone wrapped them after us (then ours only gives its text).
function D.Remove()
    local F = Format()
    for name, w in pairs(wraps) do
        if F and F[name] == w.fn then
            F[name] = w.orig
            wraps[name] = nil
        end
    end
end

function D.Count()
    local n = 0
    for _ in pairs(wraps) do n = n + 1 end
    return n
end
