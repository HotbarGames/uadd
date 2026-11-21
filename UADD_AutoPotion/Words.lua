-- Auto Potion's English texts -> our Ukrainian. No English is kept: data/words.lua (ns.AP and ns.AP_BARE,
-- made by tools/make_ap_text.py) holds hashes of it, and UADD.TextIndex (UADD/Hash.lua) finds them.
--   * Exact: a whole text the addon shows -> its Ukrainian.
--   * Template: a text with a %s slot. The slot may hold a value (a number, a version), one of the
--     addon's own texts (translated too), or, when the slot is marked free (data: free), a name as it
--     is: the author, a key name, a macro name, the word the player typed. Any other English there means
--     the template does not fit and the whole text stays English: never a half-translated line.
--   * A text in one colour (|cff..text|r) is translated inside the colour.
--   * ns.AP_BARE: lines the addon prints to chat with nothing in front (W.Bare). Kept apart, so a chat
--     line from someone else is never changed just because it reads the same as one of its labels.
-- The five macro names are not in the data: they stay English everywhere.
-- Never translated: texts with Ukrainian letters (already ours).

local _, ns = ...
local W = {}
ns.Words = W
if type(UADD) == "table" then UADD.AutoPotionWords = W end   -- for the checks (tools/harness)

local U = UADD
local CYR = "[\208-\210]"
local MAX_LEN, MAX_DEPTH = 600, 3
local idx, bareIdx = U.TextIndex({}), U.TextIndex({})
local memo, memoSize, MEMO_MAX = {}, 0, 500

local Text
local gate = { lens = {}, pre = {}, suf = {}, any = false }   -- W.MaybeBare: lengths and edge hashes only

local function Gate(data)
    local g = { lens = {}, pre = {}, suf = {}, any = false }
    for key in pairs(type(data.exact) == "table" and data.exact or {}) do
        local len, h = tostring(key):match("^(%d+):(%x+)$")
        len = tonumber(len)
        if len then g.lens[len] = g.lens[len] or {} g.lens[len][h] = true end
    end
    for _, d in ipairs(type(data.templates) == "table" and data.templates or {}) do
        local L, H = type(d.len) == "table" and d.len or {}, type(d.hash) == "table" and d.hash or {}
        local a, z = tonumber(L[1]) or 0, tonumber(L[#L]) or 0
        if a > 0 and H[1] then g.pre[a] = g.pre[a] or {} g.pre[a][H[1]] = true
        elseif z > 0 and H[#H] then g.suf[z] = g.suf[z] or {} g.suf[z][H[#H]] = true
        else g.any = true end                              -- starts and ends with a slot: always tried
    end
    return g
end

function W.Build()
    idx = U.TextIndex(ns.AP or {})
    bareIdx = U.TextIndex(ns.AP_BARE or {})
    gate = Gate(ns.AP_BARE or {})
    wipe(memo)
    memoSize = 0
end

-- Could t be one of the lines it prints alone? Every chat line of the game passes here (lesson 12): a length
-- compare, then a hash of the line (only at a length of ours) or of a few edge bytes; no look-up, no cache.
function W.MaybeBare(t)
    if not U.Plain(t) then return false end                -- a secret line: no string op on it (lesson 35)
    local n = #t
    if n == 0 or n > MAX_LEN then return false end
    if gate.any or (gate.lens[n] and gate.lens[n][U.Hash(t)]) then return true end
    for L, hs in pairs(gate.pre) do if n >= L and hs[U.Hash(t:sub(1, L))] then return true end end
    for L, hs in pairs(gate.suf) do if n >= L and hs[U.Hash(t:sub(n - L + 1))] then return true end end
    return false
end

-- A value the addon puts in a %s as it is: no letters at all ("4.0.9", "12", "--"), colour codes
-- and icons not counted.
local function IsValue(c)
    c = c:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
    return not c:find("%a")
end

local function Has(list, k)
    if list then
        for _, v in ipairs(list) do if v == k then return true end end
    end
    return false
end

-- What goes into slot k (holding c) of template d, for Index:Fill: a new value, nil to keep c, or
-- false when the template does not fit. One function per depth, made once.
local fillers = {}
local function Filler(depth)
    local f = fillers[depth]
    if f then return f end
    f = function(k, c, d)
        if d.kinds[k] ~= "s" or IsValue(c) then return nil end
        if depth < MAX_DEPTH then
            local uk = Text(c, depth + 1)
            if uk then return uk end
        end
        -- A free slot holds one name: a line break or a wide gap in it means more text glued on.
        if Has(d.free, k) and not (c:find("\n", 1, true) or c:find("   ", 1, true) or c:find(" - ", 1, true)) then return nil end
        return false
    end
    fillers[depth] = f
    return f
end

-- t filled in from the best template of `index` that fits, in Ukrainian, or nil.
local function Search(index, t, depth)
    local fn, after = Filler(depth), 0
    while true do
        local id, caps, rank = index:Match(t, after)
        if not id then return nil end
        local uk = index:Fill(id, caps, fn)
        if uk then return uk end
        after = rank
    end
end

local function One(index, t, depth)
    local uk = index:Exact(t)
    if uk then return uk end
    if #t > MAX_LEN then return nil end
    uk = Search(index, t, depth)
    if uk then return uk end
    local code, inner = t:match("^(|c%x%x%x%x%x%x%x%x)(.-)|r$")
    if code and inner ~= "" and not inner:find("|r", 1, true) then
        uk = One(index, inner, depth)
        if uk then return code .. uk .. "|r" end
    end
    return nil
end

Text = function(t, depth)
    if type(t) ~= "string" or t == "" or not U.Plain(t) or not t:find("%a") or t:find(CYR) then return nil end
    return One(idx, t, depth or 1)
end

-- One text in Ukrainian, or nil (a text we have no Ukrainian for). Every answer is kept.
function W.Text(t)
    if type(t) ~= "string" or not U.Plain(t) then return nil end
    local m = memo[t]
    if m ~= nil then return m or nil end
    local uk = Text(t, 1)
    if memoSize >= MEMO_MAX then wipe(memo) memoSize = 0 end
    memo[t], memoSize = uk or false, memoSize + 1
    return uk
end

-- A chat line the addon prints alone (no name in front), in Ukrainian, or nil.
function W.Bare(t)
    if type(t) ~= "string" or not U.Plain(t) or t:find(CYR) or #t > MAX_LEN then return nil end
    return bareIdx:Exact(t) or Search(bareIdx, t, 1)
end

-- For the status line, U.Missed and the checks.
function W.Count()
    local e, t = idx:Count()
    local be, bt = bareIdx:Count()
    return e + t + be + bt
end
function W.Index() return idx, bareIdx end
