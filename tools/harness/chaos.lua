-- The chaos test's Lua side (tools/harness/chaos.py). Run before c.start(), so its spies sit under every hook.
--   * CHAOS.orig[fs]: the last text code that is not UADD's gave a font string (the English as it was);
--     CHAOS.ours[fs]: the UADD addon whose code set its text last (nil: the addon's or the game's text is up).
--   * CHAOS.n: counters (Translate calls, debugstack calls, UADD's frame visits, UADD's hooksecurefunc calls),
--     each only while CHAOS.counting is on (the ops below turn it on around the work they measure).
--   * CHAOS.As(addon, fn, ...): fn called from a chunk named "@AddOns/<addon>/Chaos.lua", so U.CalledFrom and
--     the spy take it for that addon's code. Returns pcall's results: an error that reaches the caller is false.
local H = HARNESS
local W = H.Widget
CHAOS = { orig = {}, ours = {}, made = {}, by = {}, counting = false, hookFail = nil, trs = {}, sizes = {},
    hooks = 0, n = { tr = 0, ds = 0, visits = 0, sets = 0, probe = 0 } }
local C = CHAOS

local function Who(lo)
    for l = lo, 18 do
        local i = debug.getinfo(l, "S")
        if not i then return nil end
        local a = (i.source or ""):match("^@AddOns/([^/]+)/")
        if a then return a, i.source end
    end
    return nil
end
C.Who = Who

local function Ours(a) return a ~= nil and a:find("^UADD") ~= nil end

local set = W.SetText
W.SetText = function(self, t, ...)
    local a, src = Who(3)
    if Ours(a) then
        C.ours[self] = a
        if src == "@AddOns/UADD/uall.lua" then C.n.probe = C.n.probe + 1 end
    else
        C.ours[self] = nil
        C.orig[self] = t
        C.by[self] = a
    end
    if C.counting then C.n.sets = C.n.sets + 1 end
    return set(self, t, ...)
end

-- Frames each addon's code made (C.HideOwn hides them: its windows closed).
C.frames = setmetatable({}, { __mode = "k" })
local cf = CreateFrame
CreateFrame = function(...)
    local f = cf(...)
    local a = Who(3)
    if a and not Ours(a) and type(f) == "table" then C.frames[f] = a end
    return f
end

local make = W.CreateFontString
W.CreateFontString = function(self, ...)
    local fs = make(self, ...)
    local a = Who(3)
    if Ours(a) then C.made[fs] = a end
    return fs
end

-- Where a counted call came from (file:line of UADD's caller), for the failure's detail.
C.at = {}
local function At(kind)
    for l = 3, 8 do
        local i = debug.getinfo(l, "Sl")
        if i and (i.source or ""):find("^@AddOns/UADD") then
            local k = kind .. " " .. i.source:sub(9) .. ":" .. tostring(i.currentline)
            C.at[k] = (C.at[k] or 0) + 1
            return
        end
    end
end

-- Frame visits: the reads a ticker or a scan makes. Counted only for UADD's callers.
for _, m in ipairs({ "GetRegions", "GetChildren", "GetText", "IsShown", "IsVisible", "GetNumRegions",
        "GetNumChildren", "GetFontString", "GetName" }) do
    local f = W[m]
    if type(f) == "function" then
        W[m] = function(self, ...)
            if C.counting and Ours(Who(3)) then C.n.visits = C.n.visits + 1 At("visit") end
            return f(self, ...)
        end
    end
end

local ds = debugstack
debugstack = function(...)
    if C.counting then C.n.ds = C.n.ds + 1 At("debugstack") end
    return ds(...)
end

-- hooksecurefunc from UADD's code: counted; with C.hookFail = k the k-th one raises (an Install that fails
-- part-way, as when a game frame is missing or forbidden).
local hsf = hooksecurefunc
hooksecurefunc = function(...)
    if Ours(Who(3)) then
        C.hooks = C.hooks + 1
        if C.hookFail and C.hooks == C.hookFail then error("chaos: hooksecurefunc refused", 2) end
    end
    return hsf(...)
end

-- Wraps every Translate function in UADD's tables and the modules' namespaces (each Words object): counted.
function C.WrapTranslate()
    local seen = {}
    local function walk(t, depth)
        if type(t) ~= "table" or seen[t] or depth > 4 then return end
        seen[t] = true
        for k, v in pairs(t) do
            if k == "Translate" and type(v) == "function" and not C[v] then
                local fn = function(...)
                    if C.counting then C.n.tr = C.n.tr + 1 At("Translate") end
                    return v(...)
                end
                C[fn] = true
                C.trs[#C.trs + 1] = fn
                rawset(t, k, fn)
            elseif k == "CacheSize" and type(v) == "function" and not C[v] then
                C[v] = true
                C.sizes[#C.sizes + 1] = v
            elseif type(v) == "table" and v ~= _G and v ~= H then
                walk(v, depth + 1)
            end
        end
    end
    walk(UADD, 0)
    for name, ns in pairs(H.ns) do if tostring(name):find("^UADD") then walk(ns, 0) end end
end

-- The sizes of every Words cache (W.CacheSize) reachable from the namespaces, added up.
function C.CacheSize()
    local seen, n = {}, 0
    local function walk(t, depth)
        if type(t) ~= "table" or seen[t] or depth > 4 then return end
        seen[t] = true
        for k, v in pairs(t) do
            if k == "CacheSize" and type(v) == "function" then
                local ok, s = pcall(v)
                if ok and type(s) == "number" then n = n + s end
            elseif type(v) == "table" and v ~= _G and v ~= H then
                walk(v, depth + 1)
            end
        end
    end
    walk(UADD, 0)
    for name, ns in pairs(H.ns) do if tostring(name):find("^UADD") then walk(ns, 0) end end
    return n
end

local runners = {}
function C.As(addon, fn, ...)
    local r = runners[addon]
    if not r then
        r = assert(loadstring("local f = ... local r = { pcall(f, select(2, ...)) } return unpack(r, 1, 3)",
            "@AddOns/" .. addon .. "/Chaos.lua"))
        runners[addon] = r
    end
    return r(fn, ...)
end

-- The font strings UADD changed whose English we saw, at most `max`: { fs }, in a fixed order (by name).
function C.Touched(max)
    local out = {}
    for fs, a in pairs(C.ours) do
        local o = C.orig[fs]
        if type(o) == "string" and not C.made[fs] and o:find("%a%a%a") and not o:find("[\208-\210]")
            and fs:GetText() ~= o then out[#out + 1] = fs end
    end
    table.sort(out, function(x, y) return tostring(x:GetName() or C.orig[x]) < tostring(y:GetName() or C.orig[y]) end)
    while #out > (max or 12) do out[#out] = nil end
    return out
end

-- Font strings the addon itself last set to English (for modules that swap its words before it sets them).
function C.Seen(addon, max)
    local out = {}
    for fs, a in pairs(C.by) do
        local o = C.orig[fs]
        if a == addon and type(o) == "string" and o:find("%a%a%a") and not o:find("[\208-\210]") then
            out[#out + 1] = fs
        end
    end
    table.sort(out, function(x, y) return tostring(C.orig[x]) < tostring(C.orig[y]) end)
    while #out > (max or 4) do out[#out] = nil end
    return out
end

function C.Text(fs) return fs:GetText() end
function C.Orig(fs) return C.orig[fs] end
function C.IsOurs(fs) return C.ours[fs] ~= nil end
function C.Reset() for k in pairs(C.n) do C.n[k] = 0 end C.at = {} end
-- The places counted since C.Reset, most first: "kind file:line xN; ...".
function C.Where()
    local list = {}
    for k, n in pairs(C.at) do list[#list + 1] = { k, n } end
    table.sort(list, function(a, b) return a[2] > b[2] end)
    local out = {}
    for i = 1, math.min(3, #list) do out[i] = list[i][1] .. " x" .. list[i][2] end
    return table.concat(out, "; ")
end

-- The addon's own SetText on fs with v (a string, or nil / a number / a table), from the addon's chunk.
function C.Set(addon, fs, v)
    return C.As(addon, function() fs:SetText(v) end)
end

-- UALL Forever's kind of hook on fs: after each SetText it writes its own text once (its busy flag set).
function C.Rewriter(fs)
    local busy = false
    C.rewrite = true                    -- C.rewrite = false: the hooks stay (as in the game) but do nothing
    return C.As("UALLF", function()
        hooksecurefunc(fs, "SetText", function(self, t)
            if busy or not C.rewrite or type(t) ~= "string" or t:find("[\208-\210]") then return end
            busy = true
            self:SetText("Переклад УАЛЛ")
            busy = false
        end)
    end)
end

-- Lua memory in KB after a full collect.
function C.Mem() collectgarbage("collect") collectgarbage("collect") return collectgarbage("count") end
