-- Harness: the Lua additions of the WoW client (string/table helpers, bit, time). Loaded after wow_core.lua.
local H = HARNESS
local clock = H.clock

-- ── Lua extras of the WoW client ──────────────────────────────────────────────────────────────

function wipe(t) for k in pairs(t) do t[k] = nil end return t end
table.wipe = wipe
tinsert, tremove, sort, tContains = table.insert, table.remove, table.sort, nil
function tContains(t, v) for _, x in pairs(t) do if x == v then return true end end return false end
function tInvert(t) local r = {} for k, v in pairs(t) do r[v] = k end return r end
function CopyTable(t, shallow)
    local r = {}
    for k, v in pairs(t) do r[k] = (type(v) == "table" and not shallow) and CopyTable(v) or v end
    return r
end
function tIndexOf(t, v) for i, x in ipairs(t) do if x == v then return i end end end
strlen, strsub, strfind, strmatch, strgmatch = string.len, string.sub, string.find, string.match, string.gmatch
strlower, strupper, strrep, strbyte, strchar, strrev = string.lower, string.upper, string.rep, string.byte,
    string.char, string.reverse
format, gsub, gmatch = string.format, string.gsub, string.gmatch
floor, ceil, abs, max, min, sqrt, mod = math.floor, math.ceil, math.abs, math.max, math.min, math.sqrt, math.fmod
random, fastrandom = math.random, math.random
getn = table.getn
function strtrim(s, chars)
    chars = chars and ("[" .. chars:gsub("[%]%^%-]", "%%%0") .. "]") or "%s"
    return (s:gsub("^" .. chars .. "+", ""):gsub(chars .. "+$", ""))
end
function strsplit(sep, s, limit)
    local out, start, n = {}, 1, 0
    sep = "[" .. sep:gsub("[%]%^%-]", "%%%0") .. "]"
    while true do
        if limit and n >= limit - 1 then out[#out + 1] = s:sub(start) break end
        local a, b = s:find(sep, start)
        if not a then out[#out + 1] = s:sub(start) break end
        out[#out + 1] = s:sub(start, a - 1)
        n = n + 1
        start = b + 1
    end
    return unpack(out)
end
function strsplittable(sep, s, limit) return { strsplit(sep, s, limit) } end
function strjoin(sep, ...) return table.concat({ ... }, sep) end
function strconcat(...) return table.concat({ ... }) end
function tostringall(...)
    local t, n = { ... }, select("#", ...)
    for i = 1, n do t[i] = tostring(t[i]) end
    return unpack(t, 1, n)
end
function strlenutf8(s) local _, n = s:gsub("[^\128-\191]", "") return n end
function strcmputf8i(a, b) a, b = a:lower(), b:lower() return a == b and 0 or (a < b and -1 or 1) end
string.split, string.trim, string.join = strsplit, strtrim, strjoin
function nop() end
function securecall(fn, ...) if type(fn) == "string" then fn = _G[fn] end return fn(...) end
securecallfunction = securecall
function secureexecuterange(t, fn, ...) for k, v in pairs(t) do fn(k, v, ...) end end
function issecure() return false end
function issecurevariable() return true, nil end
function forceinsecure() end
function scrub(...) return ... end
function debugstack() return debug.traceback("", 2) end
function debuglocals() return "" end
function GetTime() return H.time end
function GetTimePreciseSec() return H.time end
function GetServerTime() return os.time() end
function debugprofilestop() return clock() * 1000 end   -- real milliseconds: budgets are honest
function debugprofilestart() end
time, date, difftime = os.time, os.date, os.difftime
function Ambiguate(name) return name end

-- bit: 32-bit operations on plain numbers (the client ships the bit library).
local function u32(x) x = x % 4294967296 return x end
local function bitop(a, b, f)
    a, b = u32(a), u32(b)
    local r, p = 0, 1
    for _ = 1, 32 do
        local x, y = a % 2, b % 2
        if f(x, y) then r = r + p end
        a, b, p = (a - x) / 2, (b - y) / 2, p * 2
    end
    return r
end
bit = {
    band = function(a, b, ...) local r = bitop(a, b, function(x, y) return x == 1 and y == 1 end)
        if ... then return bit.band(r, ...) end return r end,
    bor = function(a, b, ...) local r = bitop(a, b or 0, function(x, y) return x == 1 or y == 1 end)
        if ... then return bit.bor(r, ...) end return r end,
    bxor = function(a, b) return bitop(a, b, function(x, y) return x ~= y end) end,
    bnot = function(a) return 4294967295 - u32(a) end,
    lshift = function(a, n) return u32(u32(a) * 2 ^ n) end,
    rshift = function(a, n) return math.floor(u32(a) / 2 ^ n) end,
    arshift = function(a, n)
        a = u32(a)
        local r = math.floor(a / 2 ^ n)
        if a >= 2147483648 then r = r + u32(4294967296 - 2 ^ (32 - n)) end
        return r
    end,
    tobit = function(a) a = u32(a) if a >= 2147483648 then a = a - 4294967296 end return a end,
}
bit.mod = math.fmod


-- The client xpcall passes extra arguments to the function (Lua 5.1 xpcall does not).
local rawxpcall = xpcall
function xpcall(f, handler, ...)
    local n, args = select("#", ...), { ... }
    if n == 0 then return rawxpcall(f, handler) end
    return rawxpcall(function() return f(unpack(args, 1, n)) end, handler)
end
