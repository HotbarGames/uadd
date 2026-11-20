-- The chaos test's Lua ops (tools/harness/chaos.py), run after chaos.lua. Loops stay in Lua: 10k calls from
-- Python would take the whole time budget. Each op returns plain values Python reads.
local H = HARNESS
local C = CHAOS
local OTHER = "ChaosOther"          -- code of an addon UADD does not translate

-- fs:SetText(v) from the addon's chunk, best of 3 in ms. Returns ok, err, ms.
function C.Feed(addon, fs, v)
    local best, ok, err = 1e9, true, nil
    for _ = 1, 3 do
        local t0 = os.clock()
        local o, e = C.As(addon, function() fs:SetText(v) end)
        local dt = (os.clock() - t0) * 1000
        if dt < best then best = dt end
        if not o then ok, err = false, tostring(e) end
    end
    return ok, err, best
end

-- A chat line from `src`'s code; returns ok, err, the line the chat got (nil: none).
function C.Chat(src, v)
    local n = #H.chat
    local ok, err = C.As(src, function() DEFAULT_CHAT_FRAME:AddMessage(v, 1, 1, 1) end)
    return ok, err and tostring(err), #H.chat > n and H.chat[#H.chat] or nil
end

-- Another addon fills and clears the game tooltip n times. Returns Translate and debugstack calls.
function C.Tip(n, a, b)
    C.Reset() C.counting = true
    local ok, err = C.As(OTHER, function()
        for i = 1, n do
            GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
            GameTooltip:AddLine(a) GameTooltip:AddDoubleLine(b, a) GameTooltip:AddLine(b .. " " .. i)
            GameTooltip:Show() GameTooltip:ClearLines() GameTooltip:Hide()
        end
    end)
    C.counting = false
    return ok, err and tostring(err), C.n.tr, C.n.ds
end

-- Another addon makes n font strings and sets English on them (and an AceGUI widget when there is one).
function C.Foreign(n, a)
    C.Reset() C.counting = true
    local ok, err = C.As(OTHER, function()
        local f = CreateFrame("Frame", nil, UIParent)
        for i = 1, n do
            local fs = f:CreateFontString(nil, "OVERLAY")
            fs:SetText(i % 2 == 0 and a or (a .. " " .. i))
        end
        local G = LibStub and LibStub("AceGUI-3.0", true)
        if G then
            for _ = 1, 20 do
                local w = G:Create("Label")
                if w then w:SetText(a) G:Release(w) end
            end
        end
    end)
    H.pump(3)
    C.counting = false
    return ok, err and tostring(err), C.n.tr, C.n.ds
end

-- A forbidden frame (reading it raises, as in the client) gets a font string from another addon's code.
function C.Forbidden(a)
    local ok, err = C.As(OTHER, function()
        local f = CreateFrame("Frame", "ChaosForbidden", UIParent)
        local fs = f:CreateFontString(nil, "OVERLAY")
        fs:SetText(a)
        local boom = function() error("chaos: forbidden frame read", 2) end
        f.IsForbidden = function() return true end
        for _, m in ipairs({ "GetRegions", "GetChildren", "GetNumRegions", "GetNumChildren", "GetName",
                "GetParent", "IsShown", "IsVisible", "GetText" }) do f[m] = boom end
        f:CreateFontString(nil, "OVERLAY"):SetText(a)
        local g = CreateFrame("Frame", nil, f)
        g:CreateFontString(nil, "OVERLAY"):SetText(a)
    end)
    H.pump(10)
    return ok, err and tostring(err)
end

-- Frame visits by UADD's code over `secs` simulated seconds of idle frames (10 a second).
function C.Idle(secs)
    C.Reset() C.counting = true
    H.pump(secs * 10, function() return false end, 0.1)
    C.counting = false
    return C.n.visits, C.n.ds, C.n.tr
end

-- 10k calls of the same text and of unseen texts on fs, from the addon's code; ms per call, the KB a second
-- round of 10k other unseen texts leaves (a bounded cache: about 0), the biggest cache after.
local function Unseen(i)
    local w = { "blue", "ferret", "lantern", "seventh", "harbor", "spindle", "copper", "candle", "drift" }
    return w[i % 9 + 1] .. " " .. w[(i * 7) % 9 + 1] .. " " .. i
end
function C.Many(addon, fs, en, n)
    local t0 = os.clock()
    local ok1 = C.As(addon, function() for _ = 1, n do fs:SetText(en) end end)
    local same = (os.clock() - t0) * 1000 / n
    t0 = os.clock()
    local ok2 = C.As(addon, function() for i = 1, n do fs:SetText(Unseen(i)) end end)
    local new = (os.clock() - t0) * 1000 / n
    local function round(k)
        if type(H.textLog) == "table" then wipe(H.textLog) end     -- the harness's own log of every SetText
        C.As(addon, function() for i = 1, n do fs:SetText(Unseen(i + k * n)) end end)
        for _, t in ipairs(C.trs) do pcall(function() for i = 1, n do t(Unseen(i + k * n)) end end) end
        return C.Mem()
    end
    -- A bounded cache (6000, wiped when full) goes up and down over 3 rounds of 10k; one without end
    -- keeps rising: the highest of rounds 4-6 against the highest of rounds 1-3.
    local a, b = 0, 0
    for k = 1, 3 do a = math.max(a, round(k)) end
    for k = 4, 6 do b = math.max(b, round(k)) end
    local grown = b - a
    C.As(addon, function() fs:SetText(en) end)
    return ok1 and ok2, same, new, grown, C.MaxCache()
end

-- Every Translate C.WrapTranslate found, and the biggest Words cache.
function C.MaxCache()
    local most = 0
    for _, f in ipairs(C.sizes) do
        local ok, s = pcall(f)
        if ok and type(s) == "number" and s > most then most = s end
    end
    return most
end

-- The module's own functions made to throw (names matching `pat` in its namespace, UADD's Words objects'
-- Translate): returns how many. C.Unbreak() puts them back.
local broken = {}
function C.Break(folder, pat, every, skip)
    local n, seen = 0, {}
    local function walk(t, depth)
        if type(t) ~= "table" or seen[t] or depth > 3 then return end
        seen[t] = true
        for k, v in pairs(t) do
            if type(v) == "function" and type(k) == "string" and k:find(pat) and not (skip and k:find(skip)) then
                n = n + 1
                if n % every == 0 then
                    broken[#broken + 1] = { t, k, v }
                    local i = 0
                    rawset(t, k, function() i = i + 1 error("chaos boom " .. k .. " #" .. i .. " " .. tostring({})) end)
                end
            elseif type(v) == "table" and v ~= _G and v ~= H and v ~= UADD then
                walk(v, depth + 1)
            end
        end
    end
    walk(H.ns[folder], 0)
    return #broken
end
function C.Unbreak()
    for i = #broken, 1, -1 do local b = broken[i] rawset(b[1], b[2], b[3]) broken[i] = nil end
end

-- A frame made after login by the addon's code with the English of fs, shown at once. Returns the font
-- string (C.Late: its text).
function C.NewFs(addon, en)
    local fs
    C.As(addon, function()
        local f = CreateFrame("Frame", nil, UIParent)
        fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetText(en)
        f:Show()
    end)
    H.pump(10)
    return fs
end
function C.Late(addon, en)
    local fs = C.NewFs(addon, en)
    return fs and fs:GetText()
end

-- The addon's windows closed: every frame its code made, hidden.
function C.HideOwn(addon)
    for f, a in pairs(C.frames) do
        if a == addon and f.Hide then pcall(f.Hide, f) end
    end
    local map = rawget(_G, "WorldMapFrame")
    if type(map) == "table" and map.Hide then pcall(map.Hide, map) end
    H.pump(5)
end

-- UADD's own error lines in chat since line n.
function C.Errlines(n)
    local k = 0
    for i = n + 1, #H.chat do if tostring(H.chat[i]):find("помилка", 1, true) then k = k + 1 end end
    return k
end
