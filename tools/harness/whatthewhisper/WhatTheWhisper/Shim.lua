-- Not WhatTheWhisper. What its own Namespace, Locale, enUS, ruRU, Format, Sounds and Export files need before
-- they run (flow_wtw.py runs those files from the installed addon after this one, read only), and the game's
-- weekday globals the harness lacks. No text of the addon here.
local _, ns = ...
_G.WhatTheWhisper = ns

-- The game's weekday names (its globals; Format.lua copies them at load). Only set where the harness has none.
local DAYS = { "SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY" }
local NAMES = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" }
for i, d in ipairs(DAYS) do
    if _G["WEEKDAY_" .. d] == nil then _G["WEEKDAY_" .. d] = NAMES[i] end
end

-- Its settings: only what the files read (the language picker's choice and the date style).
ns.db = { profile = { appearance = { locale = "auto" }, general = {}, sounds = {} } }
function ns.Setting(path)
    local node = ns.db and ns.db.profile
    for key in string.gmatch(path, "[^%.]+") do
        if type(node) ~= "table" then return nil end
        node = node[key]
    end
    return node
end

ns.softErrors = {}
function ns.SoftError(where, msg) ns.softErrors[#ns.softErrors + 1] = tostring(where) .. ": " .. tostring(msg) end

function ns.Guard(name, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then ns.SoftError(name, err) end
    return ok
end

ns.Compat = {
    CanDrawScript = function() return true end,
    RegisterOptionsPanel = function(panel, name) ns.registeredPanel = { panel, name } end,
    ShortName = function(id) return (tostring(id):match("^[^%-]+")) end,
}

-- A message's fields (time, direction, text) and its text reader, for the export file (flow_wtw.lua exportFile).
ns.MSG_TS, ns.MSG_DIR, ns.MSG_TEXT = 1, 2, 3
ns.ConversationManager = { MessageText = function(m) return m and m[3] or "" end }

-- UTF-8 aware, by characters (its Text.Sub cuts the weekday to 3 letters).
local CHAR = "[%z\1-\127\194-\244][\128-\191]*"
ns.Text = {
    Sub = function(s, i, j)
        local out, n = {}, 0
        for ch in tostring(s):gmatch(CHAR) do
            n = n + 1
            if n >= i and (not j or n <= j) then out[#out + 1] = ch end
        end
        return table.concat(out)
    end,
    Strip = function(s) return (tostring(s):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end,
}
