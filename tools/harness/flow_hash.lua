-- Helpers for flow_hash.py: UADD/Hash.lua (texts by hash) as the game loads it.
-- The test data is a file tools/hashtext.py wrote; it is run as an addon file would be.

local H = HARNESS
local M = {}
H.hash = M

-- Runs a data file the way the client runs an addon's file; returns the index over ns[name].
function M.load(text, name)
    local ns = {}
    assert(loadstring(text, "@hash_data.lua"))("UADD_HashTest", ns)
    return UADD.TextIndex(ns[name])
end

-- Slot translations for the "template inside a template" checks: a %s value that is one of our
-- texts goes into Ukrainian too; `refuse` makes every slot of kind s say no.
local function Inner(index, refuse)
    return function(k, v, tpl)
        if tpl.kinds[k] ~= "s" then return nil end
        if refuse then return false end
        return index:Text(v)
    end
end

-- The Ukrainian only (Text also gives the template's id).
function M.text(index, s, inner, refuse)
    return (index:Text(s, inner and Inner(index, refuse) or nil))
end

-- id, the captures joined by "|", rank.
function M.match(index, s, after)
    local id, caps, rank = index:Match(s, after)
    if not id then return nil end
    return id, table.concat(caps, "|"), rank
end

-- Every call on a secret string: nil, and no Lua error.
function M.secret(index, s)
    H.secret[s] = true
    H.Secret(true)
    local ok, a, b, c, d = pcall(function()
        return UADD.Hash(s), index:Exact(s), index:Match(s), index:Text(s)
    end)
    H.Secret(false)
    return ok, a == nil and b == nil and c == nil and d == nil, tostring(a or b or c or d)
end

-- `rounds` times over `texts` with index:Text: milliseconds, hits, and the KB of garbage the misses made.
function M.speed(index, texts, rounds)
    local hits, t0 = 0, debugprofilestop()
    for _ = 1, rounds do
        for i = 1, #texts do
            if index:Text(texts[i]) then hits = hits + 1 end
        end
    end
    local ms = debugprofilestop() - t0
    local misses = {}
    for i = 1, #texts do
        if not index:Text(texts[i]) then misses[#misses + 1] = texts[i] end
    end
    collectgarbage("collect")
    collectgarbage("stop")
    local kb = collectgarbage("count")
    for _ = 1, rounds do
        for i = 1, #misses do index:Text(misses[i]) end
    end
    kb = collectgarbage("count") - kb
    collectgarbage("restart")
    return ms, hits, kb, #misses
end
