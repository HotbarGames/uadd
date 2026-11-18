-- Lua helpers for flow_missed.py (UADD/Missed.lua): reached from Python as HARNESS.missed.
-- Runs after flow_lsw.lua (the LayerSwap stand-in's helpers: HARNESS.lsw).
local H = HARNESS
local M = {}
H.missed = M

local U = UADD
local function S() return rawget(_G, "LayerSwapStandIn") end

local function Mod(key)
    local m = type(UADD_DB) == "table" and UADD_DB.missed
    return type(m) == "table" and type(m.mods) == "table" and m.mods[key] or nil
end

-- Entries of a module: how many, and the count of the one whose text is `t` (or nil).
function M.count(key)
    local m, n = Mod(key), 0
    if m and m.texts then for _ in pairs(m.texts) do n = n + 1 end end
    return n
end
function M.times(key, t)
    local m = Mod(key)
    for _, e in pairs(m and m.texts or {}) do if e.t == t then return e.n end end
    return nil
end
function M.has(key, t) return M.times(key, t) ~= nil or M.isName(key, t) end
function M.isName(key, t)
    local m = Mod(key)
    for _, e in pairs(m and m.names or {}) do if e.t == t then return true end end
    return false
end
function M.names(key)
    local m, n = Mod(key), 0
    for _ in pairs(m and m.names or {}) do n = n + 1 end
    return n
end
function M.namesDropped(key) local m = Mod(key) return m and m.namesDropped or 0 end
function M.stored() return type(UADD_DB) == "table" and UADD_DB.missed ~= nil end
function M.dropped(key) local m = Mod(key) return m and m.dropped or 0 end
function M.version(key) local m = Mod(key) return m and m.v end
function M.entryVersion(key, t)
    local m = Mod(key)
    for _, e in pairs(m and m.texts or {}) do if e.t == t then return e.v end end
end
function M.total()
    local n = 0
    for key in pairs(type(UADD_DB.missed) == "table" and UADD_DB.missed.mods or {}) do n = n + M.count(key) end
    return n
end

-- The stand-in's panel heading (hooked by UADD_LayerSwap) set to `t`, `times` times.
function M.setHeading(t, times)
    for _ = 1, times or 1 do S().texts.heading:SetText(t) end
end
function M.inCombat(on) H.combat = on end

-- A made-up module for the core checks; keep: "Kept on purpose" stays quiet.
function M.register(key)
    U.MissedModule(key, { addon = "LayerSwap", keep = function(t) return t == "Kept on purpose" end })
end
function M.note(key, t, fs) U.Missed(key, t, fs) end

-- Off: a module start must not walk the stored entries. Plants one, registers a module whose test counts
-- its calls; returns a function that gives the count.
function M.plant(key)
    local db = U.DB()
    db.missed = type(db.missed) == "table" and db.missed or {}
    db.missed.mods = type(db.missed.mods) == "table" and db.missed.mods or {}
    db.missed.mods[key] = { texts = { x1 = { t = "Old wobbly gizmo", n = 1, d = "2026-01-01" } } }
    local calls = 0
    U.MissedModule(key, { addon = "LayerSwap", test = function() calls = calls + 1 return false end })
    return function() return calls end
end

-- A made-up module with a template index: "<slot> wobbles at <slot>" (both slots any text).
function M.indexed(key)
    local idx = U.TextIndex({ exact = {}, templates = { { id = "wob", len = { 0, 12, 0 },
        hash = { U.Hash(""), U.Hash(" wobbles at "), U.Hash("") }, kinds = { "s", "s" }, uk = { 1, " - ", 2 } } } })
    U.MissedModule(key, { addon = "LayerSwap", index = function() return idx end })
end

-- `n` made-up names ("Gizmo Ab"), each a whole text.
function M.floodNames(key, n)
    for i = 1, n do
        local s, j = "", i
        repeat s = s .. string.char(97 + j % 26) j = math.floor(j / 26) until j == 0
        U.Missed(key, "Gizmo " .. s:sub(1, 1):upper() .. s:sub(2))
    end
end

-- A name UALL Forever knows (a stand-in answer for one made-up zone) is not noted.
function M.noteUall(key, t)
    local L = U.UALL
    local old = L.Zone
    L.Zone = function(c) return c == t and "Ґізмо" or nil end
    U.Missed(key, t)
    L.Zone = old
end

-- `n` texts with letters only (digits would make them one entry), `modules` modules of `n` each.
local function Word(i)
    local s = ""
    repeat s = s .. string.char(97 + i % 26) i = math.floor(i / 26) until i == 0
    return "Gizmo word " .. s
end
function M.flood(prefix, modules, n)
    for k = 1, modules do
        for i = 1, n do U.Missed(prefix .. k, Word(i)) end
    end
end

-- Puts an entry for `t` in the module's store as an earlier session would have, then the module
-- starts again (U.MissedModule): a text it translates now goes, the others stay.
function M.restart(t, other)
    local m = UADD_DB.missed.mods.layerswap
    m.texts["x1"] = { t = t, n = 1, d = "2026-01-01", v = "old" }
    m.texts["x2"] = { t = other, n = 1, d = "2026-01-01", v = "old" }
    local ns = H.ns.UADD_LayerSwap
    U.MissedModule("layerswap", { addon = "LayerSwap", test = function(x) return ns.Words.Text(x) end })
end

-- Speed: `n` notes of a text already seen (on one FontString, and without one), in ms; and the KB of
-- garbage they made.
function M.speed(n)
    local fs = S().texts.layer
    U.Missed("speedcheck", "A noted speed text", fs)
    collectgarbage("collect")
    collectgarbage("stop")
    local kb0 = collectgarbage("count")
    local t0 = debugprofilestop()
    for _ = 1, n do U.Missed("speedcheck", "A noted speed text", fs) end
    for _ = 1, n do U.Missed("speedcheck", "A noted speed text") end
    local ms = debugprofilestop() - t0
    local kb = collectgarbage("count") - kb0
    collectgarbage("restart")
    return ms, kb
end
