-- The chaos test's BG flood (docs/LESSONS3.md, lesson 35), run after chaos.lua and chaos_ops.lua.
-- A battleground floods the main chat window and makes frames by the hundred. These ops send that load
-- through every hook UADD has on the game-wide paths, from code of an addon UADD does not translate.
local H = HARNESS
local C = CHAOS
local OTHER = "ChaosOther"

-- Wraps every Bare function (a whole chat line the addon prints alone) in the modules' namespaces: counted.
function C.WrapBare()
    local seen = {}
    local function walk(t, depth)
        if type(t) ~= "table" or seen[t] or depth > 4 then return end
        seen[t] = true
        for k, v in pairs(t) do
            if k == "Bare" and type(v) == "function" and not C[v] then
                local fn = function(...)
                    if C.counting then C.n.bare = (C.n.bare or 0) + 1 end
                    return v(...)
                end
                C[fn] = true
                rawset(t, k, fn)
            elseif type(v) == "table" and v ~= _G and v ~= H then
                walk(v, depth + 1)
            end
        end
    end
    walk(UADD, 0)
    for name, ns in pairs(H.ns) do if tostring(name):find("^UADD") then walk(ns, 0) end end
end

-- Line i of the flood: what a BG prints (system lines, players' links, items, colours, odd bytes, long lines,
-- Cyrillic, values that are no string). Every 7th string line is secret, as the client makes some in combat.
local KINDS = {
    function(i) return "Zorp" .. i .. " has joined the battle." end,
    function(i) return "|Hplayer:Zorp-Realm:" .. i .. "|h[Zorp]|h: inc mid " .. i end,
    function(i) return "|cff1eff00|Hitem:" .. i .. "::::::::60:::::|h[Wobbly Gizmo]|h|r" end,
    function(i) return "|cff7fd4ffZorp|r: " .. i end,                -- a coloured name with ": ", as many prefixes
    function(i) return "\0\1\255[(.*+-?^$%" .. i end,
    function(i) return string.rep("Blatter ", 640) .. i end,          -- about 5 KB
    function(i) return "Привіт, " .. i end,
    function(i) return "%s %d %% " .. i end,
    function() return "" end,
    function() return nil end,
    function(i) return i end,
    function() return true end,
    function(i) return i + 0.5 end,
}

-- The string ops a secret string must not reach (the client throws on any; plain Lua can make the method calls
-- and these library calls throw, not `..`, `#` or `==`).
local OPS = { "sub", "find", "match", "gmatch", "gsub", "byte", "lower", "upper", "len", "format", "rep" }

local function Secrets(on, saved)
    H.Secret(on)
    for _, k in ipairs(OPS) do
        if on then
            local f = string[k]
            saved[k] = f
            string[k] = function(s, ...)
                if type(s) == "string" and H.secret[s] then error("attempt to use a secret string value", 2) end
                return f(s, ...)
            end
        elseif saved[k] then
            string[k] = saved[k]
        end
    end
end

-- n chat lines from another addon's code. Returns: calls that threw, lines lost or doubled, string lines that
-- changed, secret lines sent, Translate calls, Bare calls, debugstack calls, ms (os.clock), the first problem.
function C.Flood(n)
    local lines, secret = {}, {}
    for i = 1, n do
        local v = KINDS[(i - 1) % #KINDS + 1](i)
        if type(v) == "string" and i % 7 == 0 then v = "S" .. i .. ": " .. v secret[v] = true end
        lines[i] = v
    end
    local saved, threw, lost, changed, first = {}, 0, 0, 0, nil
    for s in pairs(secret) do H.secret[s] = true end
    Secrets(true, saved)
    C.Reset() C.counting = true
    local frame = DEFAULT_CHAT_FRAME
    local t0 = os.clock()
    local ok, err = C.As(OTHER, function()
        for i = 1, n do
            local v, before = lines[i], #H.chat
            local o, e = pcall(frame.AddMessage, frame, v, 1, 0.5, 0, i)
            local got = H.chat[before + 1]
            if not o then
                threw = threw + 1
                first = first or ("line " .. i .. ": " .. tostring(e))
            elseif #H.chat ~= before + 1 then
                lost = lost + 1
                first = first or ("line " .. i .. ": " .. (#H.chat - before) .. " lines arrived")
            elseif type(v) == "string" and got ~= v then
                changed = changed + 1
                first = first or ("line " .. i .. " changed")
            elseif type(v) ~= "string" and got ~= tostring(v) then
                changed = changed + 1
                first = first or ("line " .. i .. " became another value")
            end
        end
    end)
    local ms = (os.clock() - t0) * 1000
    C.counting = false
    Secrets(false, saved)
    if not ok then threw, first = threw + 1, first or tostring(err) end
    local nsec = 0
    for _ in pairs(secret) do nsec = nsec + 1 end
    return threw, lost, changed, nsec, C.n.tr, C.n.bare or 0, C.n.ds, ms, first
end

-- The core frame hook (U.NewFrameRun: every module's U.OnNewFrame fn, Attune's too) fed n rounds of odd
-- CreateFrame arguments from another addon. Returns: calls that threw, UADD error reports made, ms.
function C.OddFrames(n)
    local U = UADD
    local run = U and U.NewFrameRun
    if type(run) ~= "function" then return -1, 0, 0 end
    local plain = CreateFrame("Frame", "ChaosPlainFrame")
    local odd = {
        { nil, nil, nil }, { 5, 6, 7 }, { "Frame", "ChaosNoSuchFrame", "ChaosNoSuchParent" },
        { "Frame", nil, {} }, { "Frame", nil, { GetParent = 5 } },
        { "Frame", nil, { GetParent = function() error("chaos: GetParent throws") end } },
        { "Button", "ChaosPlainFrame", plain }, { {}, {}, "ChaosPlainFrame" }, { "Frame", true, false },
    }
    local reports0 = U.ReportedCount and U.ReportedCount() or 0
    local threw = 0
    local t0 = os.clock()
    C.As(OTHER, function()
        for _ = 1, n do
            for j = 1, #odd do
                local a = odd[j]
                if not pcall(run, a[1], a[2], a[3]) then threw = threw + 1 end
            end
        end
    end)
    local ms = (os.clock() - t0) * 1000
    return threw, (U.ReportedCount and U.ReportedCount() or 0) - reports0, ms
end

-- The mutants of C.Instance and C.PrintInstance: C.cutFrom in UADD/Lines.lua or UADD/Print.lua becomes C.cutTo
-- as the file loads (C.wasCut).
local runFile = H.runFile
function H.runFile(addon, path, code)
    if C.cutFrom and addon == "UADD" and (path == "Lines.lua" or path == "Print.lua") then
        local a, b = code:find(C.cutFrom, 1, true)
        if a then code, C.wasCut = code:sub(1, a - 1) .. C.cutTo .. code:sub(b + 1), true end
    end
    return runFile(addon, path, code)
end

-- One line from another addon, secret when asked: true when it arrived once and byte for byte.
local function Once(frame, v, secret)
    local before, saved = #H.chat, {}
    if secret then H.secret[v] = true Secrets(true, saved) end
    local ok = C.As(OTHER, function() frame:AddMessage(v, 1, 1, 1) end)
    if secret then Secrets(false, saved) end
    return ok and #H.chat == before + 1 and H.chat[before + 1] == v
end

-- A BG and back (lesson 35): the wrap's field taints the game's chat path, where every line is secret. Returns
-- wrapped before, our field gone inside, lines pass inside, wrapped again outside, a later wrapper kept inside
-- and lines through it once, wrapped again after it is gone (false where the module wraps no chat).
function C.Instance()
    local U, frame = UADD, DEFAULT_CHAT_FRAME
    local ours = U and U.ChatWrapped
    local was = rawget(_G, "IsInInstance")
    local function Go(inside, event)
        IsInInstance = function() return inside, inside and "pvp" or "none" end
        H.fire(event, false, false)
    end
    local wrapped = ours ~= nil and rawget(frame, "AddMessage") == ours
    Go(true, "PLAYER_ENTERING_WORLD")
    local gone = rawget(frame, "AddMessage") ~= ours or not wrapped
    local pass = Once(frame, "Zorp wins.", false) and Once(frame, "S1: Zorp wins.", true)
    Go(false, "ZONE_CHANGED_NEW_AREA")
    local back = rawget(frame, "AddMessage") == ours
    local kept, through, again = false, false, false
    if back then                                         -- another addon wraps after us, then we go in
        local n, prev = 0, frame.AddMessage
        local theirs = function(self, msg, ...) n = n + 1 return prev(self, msg, ...) end
        frame.AddMessage = theirs
        Go(true, "PLAYER_ENTERING_WORLD")
        kept = rawget(frame, "AddMessage") == theirs
        through = Once(frame, "S2: Zorp wins.", true) and n == 1
        frame.AddMessage = prev                          -- they come off
        Go(false, "PLAYER_ENTERING_WORLD")
        again = rawget(frame, "AddMessage") == ours
    end
    IsInInstance = was
    return wrapped, gone, pass, back, kept, through, again
end

-- One print() from another addon (values packed, n of them), secret when asked: true when one chat line came,
-- the values as the game's handler joins them.
local function Printed(vals, n, secret)
    local before, saved, want = #H.chat, {}, {}
    for i = 1, n do want[i] = tostring(vals[i]) end
    if secret then H.secret[vals[1]] = true Secrets(true, saved) end
    local ok = C.As(OTHER, function() print((table.unpack or unpack)(vals, 1, n)) end)
    if secret then Secrets(false, saved) end
    return ok and #H.chat == before + 1 and H.chat[before + 1] == table.concat(want, " ", 1, n)
end

-- The core print handler (UADD/Print.lua) in a BG and back (lesson 35). Returns: ours set before, odd prints pass
-- once outside, ours gone inside, prints pass inside, ours back outside, a later addon's handler kept inside and
-- prints through it once, ours back after it is gone (false where no module translates prints).
function C.PrintInstance()
    local U = UADD
    local ours = U and U.PrintWrapped
    local was = rawget(_G, "IsInInstance")
    local function Go(inside, event)
        IsInInstance = function() return inside, inside and "pvp" or "none" end
        H.fire(event, false, false)
    end
    local wrapped = ours ~= nil and getprinthandler() == ours
    local odd = Printed({ "S9: Zorp wins." }, 1, true)  -- a secret one, several values, no string, empty, Cyrillic
    for _, p in ipairs({ { { "Zorp", 5 }, 2 }, { { nil }, 1 }, { { 7 }, 1 }, { { true, nil, "x" }, 3 },
                         { { "" }, 1 }, { { "Привіт" }, 1 }, { { "\0\1\255[(.*%" }, 1 } }) do
        odd = odd and Printed(p[1], p[2], false)
    end
    Go(true, "PLAYER_ENTERING_WORLD")
    local gone = getprinthandler() ~= ours or not wrapped
    local pass = Printed({ "Zorp wins." }, 1, false) and Printed({ "S1: Zorp wins." }, 1, true)
    Go(false, "ZONE_CHANGED_NEW_AREA")
    local back = getprinthandler() == ours
    local kept, through, again = false, false, false
    if back then                                         -- another addon sets its handler after us, then we go in
        local n, prev = 0, getprinthandler()
        local theirs = function(...) n = n + 1 return prev(...) end
        setprinthandler(theirs)
        Go(true, "PLAYER_ENTERING_WORLD")
        kept = getprinthandler() == theirs
        through = Printed({ "S2: Zorp wins." }, 1, true) and n == 1
        setprinthandler(prev)                            -- they come off
        Go(false, "PLAYER_ENTERING_WORLD")
        again = getprinthandler() == ours
    end
    IsInInstance = was
    return wrapped, odd, gone, pass, back, kept, through, again
end
