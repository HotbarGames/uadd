-- Our tables as (English, Ukrainian) pairs, for Words.lua. The repo keeps none of Attune's English: each
-- English text is read from Attune's own AttuneLang (rawget, never written) by the keys of our tables.
--   * ui/locale.lua: ns.UA by locale key; ns.UA_CATEGORY by a category's key (its value, and the value in
--     sentence case as the options list shows it); ns.UA_GLUED by the key of a word Attune glues to a
--     number or a name ({ shape, uk }: {} in the shape is AttuneLang[key]); ns.UA_STEP_TYPE by a step TYPE
--     value (only what is shown changes, step.TYPE stays as it is). ui/notes.lua: ns.UA_NOTES, by N2_<id>.
--   * data/hashed.lua (made by tools/make_att_text.py), by "<bytes>:<hash>" (UADD.Hash): ns.UA_KEYHASH and
--     ns.UA_GLUEHASH are locale keys that are English sentences, found by hashing AttuneLang's keys.
--     (ns.UA_TEXTHASH, English Attune writes in its code, is looked up by the shown text: Words.lua.)
-- A key missing in AttuneLang gives no pair: its text stays English.

local _, ns = ...

-- Keys that stay English: the guild line goes to other players, the request line is saved in the Survey Log.
local NEVER = { AttuneCompleteGuild = true, ReceivedRequestFrom = true }

-- Calls add(english, ukrainian) for every pair, in a fixed order where it matters: the same English
-- under two locale keys takes the first key's Ukrainian.
function ns.Pairs(add)
    local lang = rawget(_G, "AttuneLang")
    lang = type(lang) == "table" and lang or {}
    local function L(key)
        local v = type(key) == "string" and rawget(lang, key)
        return type(v) == "string" and v or nil
    end
    -- Locale keys kept by hash: AttuneLang's keys of those lengths, each hashed once.
    local want, byHash = {}, {}
    for _, t in ipairs({ ns.UA_KEYHASH or {}, ns.UA_GLUEHASH or {} }) do
        for h in pairs(t) do
            local n = tonumber(tostring(h):match("^(%d+):"))
            if n then want[n] = true end
        end
    end
    for key in pairs(lang) do
        if type(key) == "string" and want[#key] then byHash[#key .. ":" .. UADD.Hash(key)] = key end
    end
    local rows = {}
    for key, uk in pairs(ns.UA or {}) do if not NEVER[key] then rows[#rows + 1] = { key, uk } end end
    for h, uk in pairs(ns.UA_KEYHASH or {}) do if byHash[h] then rows[#rows + 1] = { byHash[h], uk } end end
    table.sort(rows, function(a, b) return a[1] < b[1] end)
    for _, r in ipairs(rows) do add(L(r[1]), r[2]) end
    -- Lines glued from a locale word and a number or name: the shape with the word's text at {}.
    for _, t in ipairs({ ns.UA_GLUED or {}, ns.UA_GLUEHASH or {} }) do
        for key, v in pairs(t) do
            local text = L(byHash[key] or key)
            if text and type(v) == "table" and type(v[1]) == "string" then
                add((v[1]:gsub("{}", function() return text end)), v[2])
            end
        end
    end
    -- Categories: the tree shows the value as it is, the options list it in sentence case.
    for key, uk in pairs(ns.UA_CATEGORY or {}) do
        local v = L(key)
        if v then
            add(v, uk)
            add((v:lower():gsub("^%l", string.upper)), uk)
        end
    end
    -- Step type labels: Attune shows AttuneLang[step.TYPE].
    for value, uk in pairs(ns.UA_STEP_TYPE or {}) do add(L(value) or value, uk) end
    -- NPC notes: the English is Attune's own N2_<id> text.
    for key, uk in pairs(ns.UA_NOTES or {}) do add(L(key), uk) end
end
