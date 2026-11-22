-- UADD - LootTriage: our Ukrainian for one of its texts, found by the hash of its English (data/).
--
-- A text is one string literal of its code, a format template (Slots.lua: its slots found by shape), or
-- literals it glues with ".." (each piece looked up alone, below). The answer is a whole Ukrainian line, or
-- nil: the line stays as it came. A quest title glued in comes from UALL Forever or ClassicUA
-- (UADD.UALL.Quest, lesson 20); a title the addon made itself for an unknown quest keeps the line English
-- (lesson 27). No English of LootTriage is stored here: its texts are known by hash only.

local _, ns = ...
local U = UADD
local W = {}
ns.Words = W
local P = ns.Slots
local Key, Exact, Codes, Link, Base, Shapes = P.Key, P.Exact, P.Codes, P.Link, P.Base, P.Shapes
W.Exact = Exact

local find, sub, byte, match, concat = string.find, string.sub, string.byte, string.match, table.concat
local CYR = "[\208-\210]"
local PREFIX = "LootTriage: "             -- the addon's name: its tooltip lines start so
local MAXLEN = 1200

-- ── Glued pieces ──────────────────────────────────────────────────────────────────────────────

local function Glued(s)
    local codes = Codes(s)
    local first = codes[1]
    -- a link, then one of our pieces
    if first and first[3] and first[1] == 1 and first[2] < #s then
        local rest = Exact(sub(s, first[2] + 1))           -- ours first: no route asked for a line not ours
        local l = rest and Link(sub(s, 1, first[2]))
        if l then return l .. rest end
    end
    -- a keep click, then one of our pieces
    local t1, t2 = find(s, "^[^%s|]*%+[^%s|]*")
    if t1 and t2 < #s then
        local click, rest = Exact(sub(s, 1, t2)), Exact(sub(s, t2 + 1))
        if click and rest then return click .. rest end
    end
    -- two spaces, then a link alone, or a quest's title and maybe one of our pieces in brackets
    if sub(s, 1, 2) == "  " and #s > 2 then
        local rest = sub(s, 3)
        local rc = Codes(rest)
        if rc[1] and rc[1][3] and rc[1][1] == 1 and rc[1][2] == #rest then
            local l = Link(rest)
            return l and "  " .. l or nil
        end
        if #rc > 0 then return nil end
        local title, suffix = rest, ""
        local p = find(rest, " (", 1, true)
        if p and sub(rest, -1) == ")" then
            suffix = Exact(sub(rest, p))
            if not suffix then return nil end
            title = sub(rest, 1, p - 1)
        end
        local R = U.UALL
        if type(R) ~= "table" or type(R.Quest) ~= "function" or title == "" then return nil end
        P.asked = true
        local uk = R.Quest(nil, title)
        if type(uk) ~= "string" or not find(uk, CYR) then return nil end
        return "  " .. uk .. suffix
    end
    return nil
end

-- One line (no "\n\n" in it): itself, its colour wrap, its shape, its glued pieces.
local function Line(s)
    local uk = Exact(s)
    if uk then return uk end
    local hex, inner = match(s, "^|c(%x%x%x%x%x%x%x%x)(.*)|r$")
    if hex and not find(inner, "|r", 1, true) then
        local i = Line(inner)
        return i and "|c" .. hex .. i .. "|r" or nil
    end
    return Shapes(s) or Glued(s)
end
W.Line = Line

-- Blocks glued with a blank line (a row's tip and its red notes): each block alone, or a few as one literal.
local function Blocks(s)
    if not find(s, "\n\n", 1, true) then return Line(s) end
    local parts, i = {}, 1
    while true do
        local p = find(s, "\n\n", i, true)
        parts[#parts + 1] = sub(s, i, p and p - 1 or #s)
        if not p then break end
        i = p + 2
        if #parts > 8 then return nil end
    end
    local out, a = {}, 1
    while a <= #parts do
        local hit, to
        for b = #parts, a, -1 do
            local x = concat(parts, "\n\n", a, b)
            hit = (b > a) and Exact(x) or (b == a and (x == "" and "" or Line(x))) or nil
            if hit then to = b break end
        end
        if not hit then return nil end
        out[#out + 1] = hit
        a = to + 1
    end
    return concat(out, "\n\n")
end

-- ── Public ────────────────────────────────────────────────────────────────────────────────────

local cache, size = {}, 0

function W.Translate(s)
    s = U.Plain(s)
    if not s or s == "" or #s > MAXLEN or find(s, CYR) then return nil end
    local hit = cache[s]
    if hit ~= nil then return hit or nil end
    P.asked = false
    local uk = Blocks(s)
    if uk == s then uk = nil end
    if not P.asked then                                     -- a route's answer can come later: not kept
        if size >= 400 then cache, size = {}, 0 end
        cache[s], size = uk or false, size + 1
    end
    return uk
end
function W.CacheSize() return size end
function W.Forget()
    cache, size = {}, 0
    if P.Forget then P.Forget() end
end

-- For the game's tooltip: could this line be one of ours? No lookup into the cache, at most one hash.
-- Per tooltip: n = its line count at the last left text, run = that line was ours (or a "  " line right after
-- ours: quest lines follow it). A right text (AddDoubleLine) comes with the same count and changes nothing.
-- Cleared with the tooltip (W.Install), or when its count goes down.
local runs = setmetatable({}, { __mode = "k" })
local function Count(tip)
    local ok, n = pcall(tip.NumLines, tip)
    return ok and type(n) == "number" and n or nil
end
function W.Maybe(s)
    if type(s) ~= "string" then return false end
    local tip = GameTooltip
    if type(tip) ~= "table" then tip = W end
    local st = runs[tip]
    if not st then st = { run = false } runs[tip] = st end
    local n = tip ~= W and Count(tip) or nil
    local right = n ~= nil and n == st.n
    if not right then
        if n and st.n and n < st.n then st.run = false end
        st.n = n
    end
    local yes, run
    if sub(s, 1, #PREFIX) == PREFIX then yes, run = true, true
    elseif byte(s, 1) == 32 and byte(s, 2) == 32 then yes, run = st.run, st.run
    else
        run = false
        local t1, t2 = find(s, "^[^%s|]*%+[^%s|]*")
        yes = (t1 ~= nil and t2 < 40 and Exact(sub(s, 1, t2)) ~= nil)
            or (ns.Screen and ns.Screen.OwnsTip and ns.Screen.OwnsTip()) or false
    end
    if not right then st.run = run end
    return yes
end

-- The tooltip's state goes with its lines.
function W.Install()
    local tip = GameTooltip
    if W.hooked or type(tip) ~= "table" or not tip.HookScript then return end
    W.hooked = true
    pcall(tip.HookScript, tip, "OnTooltipCleared", function(self) runs[self] = nil end)
end

-- For chat lines with no prefix (its help lines): two spaces and a hash we know.
function W.ChatMaybe(s)
    if type(s) ~= "string" or byte(s, 1) ~= 32 or byte(s, 2) ~= 32 or #s > 300 then return false end
    if Exact(s) then return true end
    local codes = Codes(s)
    local k = (function()
        local slots, parts, at = Base(s, codes, {}), {}, 1
        for _, sl in ipairs(slots) do
            parts[#parts + 1] = (sub(s, at, sl.a - 1):gsub("%%", "%%%%"))
            parts[#parts + 1] = sl.d and "%d" or "%s"
            at = sl.b + 1
        end
        parts[#parts + 1] = (sub(s, at):gsub("%%", "%%%%"))
        return Key(concat(parts))
    end)()
    return ns.LT[k] ~= nil
end
