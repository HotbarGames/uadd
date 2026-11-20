-- The chaos test's Lua ops for an addon update and for UADD's core (tools/harness/chaos_more.py), run after
-- chaos_ops.lua.
local H = HARNESS
local C = CHAOS

-- The addon's locale tables: AceLocale's for the addon, and a global "<addon>Locale" / PawnLocal one.
local function Locales(addon)
    local out = {}
    local A = LibStub and LibStub("AceLocale-3.0", true)
    if A and type(A.apps) == "table" and type(A.apps[addon]) == "table" then out[#out + 1] = A.apps[addon] end
    for _, name in ipairs({ addon .. "Locale", addon .. "_Locale", "PawnLocal" }) do
        local t = rawget(_G, name)
        if type(t) == "table" and (name ~= "PawnLocal" or addon == "Pawn") then out[#out + 1] = t end
    end
    -- Its private namespace's or its global object's L / Locale (ns.L = ..., OpenMap.L).
    for _, owner in ipairs({ H.ns and H.ns[addon], rawget(_G, addon) }) do
        for _, k in ipairs({ "L", "Locale", "locale" }) do
            local t = type(owner) == "table" and rawget(owner, k)
            if type(t) == "table" then
                local dup = false
                for _, o in ipairs(out) do if o == t then dup = true end end
                if not dup then out[#out + 1] = t end
            end
        end
    end
    return out
end

-- An addon update: in its locale tables every `every`-th string (in key order, from `start`) is changed,
-- renamed or removed in turn. Returns how many.
function C.Mutate(addon, every, start)
    local n, i = 0, 0
    local function walk(t, depth)
        local keys = {}
        for k in pairs(t) do if type(k) == "string" then keys[#keys + 1] = k end end
        table.sort(keys)
        for _, k in ipairs(keys) do
            local v = rawget(t, k)
            if type(v) == "table" and depth < 2 then
                walk(v, depth + 1)
            elseif type(v) == "string" and v:find("%a%a%a") then
                i = i + 1
                if (i + start) % every == 0 then
                    n = n + 1
                    local how = n % 3
                    if how == 0 then rawset(t, k, v .. " Extra")
                    elseif how == 1 then rawset(t, k, nil) rawset(t, k .. "_v2", v)
                    else rawset(t, k, nil) end
                end
            end
        end
    end
    for _, t in ipairs(Locales(addon)) do walk(t, 0) end
    return n
end

-- U.SafeCall over n errors whose text changes (a number) and n from as many places: returns the places
-- reported, UADD's error lines in chat, and the KB the reports left.
function C.SafeFlood(n)
    local U = UADD
    local chat, m0 = #H.chat, C.Mem()
    for i = 1, n do
        U.SafeCall(function() error("chaos flood " .. i .. " " .. tostring({})) end)
        U.SafeCall(function() error("Chaos" .. i .. ".lua:" .. i .. ": chaos place " .. i, 0) end)
    end
    local k = 0
    for i = chat + 1, #H.chat do if tostring(H.chat[i]):find("помилка", 1, true) then k = k + 1 end end
    return U.ReportedCount and U.ReportedCount() or -1, k, C.Mem() - m0
end

-- Another addon's spy on the game's zone text (as many addons hook it): every (self, text) it sees.
-- Returns a function giving: calls with the game's string as self, calls with another self, the game's
-- string's text now.
function C.ZoneSpy()
    local fs = rawget(_G, "ZoneTextString")
    if type(fs) ~= "table" then
        local f = CreateFrame("Frame", "ChaosZoneFrame", UIParent)
        fs = f:CreateFontString("ZoneTextString", "OVERLAY", "GameFontNormal")
        _G.ZoneTextString = fs
    end
    local mine, other = 0, 0
    C.As("ChaosOther", function()
        hooksecurefunc(fs, "SetText", function(self) if self == fs then mine = mine + 1 else other = other + 1 end end)
    end)
    fs:SetText("Chaos Zone")
    mine = 0
    return function() return mine, other, fs:GetText() end
end

-- UALL Forever's kind of hook on the zone text: it writes its Ukrainian into the same call.
function C.FakeUallf()
    local fs = _G.ZoneTextString
    local busy = false
    C.As("UALLF", function()
        hooksecurefunc(fs, "SetText", function(self, t)
            if busy or type(t) ~= "string" or t:find("[\208-\210]") then return end
            busy = true
            self:SetText("Ельвиннський ліс")
            busy = false
        end)
    end)
end

-- Every UADD module's busy-style flags: true ones after a throw stay stuck (reads only the upvalues of
-- functions in the module's namespace whose name says "busy", "probing", "inside" or "guard").
function C.Stuck(folder)
    local out, seen = {}, {}
    local function walk(t, depth)
        if type(t) ~= "table" or seen[t] or depth > 3 then return end
        seen[t] = true
        for k, v in pairs(t) do
            if type(v) == "function" then
                for i = 1, 60 do
                    local name, val = debug.getupvalue(v, i)
                    if not name then break end
                    if val == true and (name:find("busy") or name:find("probing") or name:find("inside")
                            or name:find("guard")) then
                        out[#out + 1] = tostring(k) .. ":" .. name
                    end
                end
            elseif type(v) == "table" and v ~= _G and v ~= H and v ~= UADD then
                walk(v, depth + 1)
            end
        end
    end
    walk(H.ns[folder], 0)
    table.sort(out)
    return table.concat(out, ", ")
end

-- The addon's own code fills the game tooltip with its words n times and clears it (the tooltip font check,
-- tipfont.py, then sees each line UADD changed get its font object back). Returns ok, err.
function C.OwnTip(addon, n, ...)
    local lines = { ... }
    local ok, err = C.As(addon, function()
        for _ = 1, n do
            GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
            for _, s in ipairs(lines) do GameTooltip:AddLine(s) end
            GameTooltip:Show() GameTooltip:ClearLines() GameTooltip:Hide()
        end
    end)
    H.pump(2)
    return ok, err and tostring(err)
end
