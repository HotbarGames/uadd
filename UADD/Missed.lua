-- Missed texts: a text a module showed in English because it has no Ukrainian for it yet.
-- A tool for the owner and testers, OFF by default: "/uadd missed on" starts it. While on, each such
-- text is noted once in UADD_DB.missed (your own SavedVariables, never sent anywhere). After logout,
-- tools/missed.py lists them, so a test run shows what still needs words.
--   * Off: U.Missed returns at its first line (one boolean), and module start reads nothing. Turning it
--     off keeps what was noted; "/uadd missed clear" wipes it.
--   * A module calls U.Missed(key, text, fs) only where its lookup found nothing (its miss path), never in
--     combat. A text we translate costs nothing here.
--   * Quiet on purpose: values ("1,234", "12.3k", "4h 03m"), texts with no Latin word, texts with Ukrainian
--     letters, very long texts (prose), the target addon's own name, and what the module's `keep` says.
--     A module's STAY list (English on purpose) lives in tools/, so tools/missed.py drops those.
--   * Names are never noted inside a text: an item or player link becomes <link>, quoted text (a name
--     the player typed) becomes "<name>", and where the module has a template index (spec.index), a slot
--     that holds a name or a value becomes %s, so only the addon's own words around it are kept.
--   * A whole text that looks like a name (1 to 5 capitalised words) is dropped when UALL Forever knows it
--     (a zone, an NPC, an item: its job), else it goes to its own bucket (names, with its own cap), so
--     names never push real misses out.
--   * Numbers do not make new entries: "Level 5" and "Level 6" are one entry (digits count as one).
--   * At most MAX_MOD texts per module and MAX_ALL in all, MAX_NAMES names per module; past that only a
--     count of dropped ones. Bounded: under 1.5 MB of SavedVariables at the very most.
--   * An addon update does not clear a module's entries: each keeps the addon version it was seen with,
--     and an entry the module translates now is removed when the module starts (U.MissedModule).
--   * "/uadd missed": counts per module; "/uadd missed on|off|clear [module]".

local U = UADD

local MAX_MOD, MAX_ALL, MAX_NAMES, MAX_LEN, SESS_MAX = 1000, 3000, 500, 300, 4000
local NAME_LEN, SLOT_LEN = 60, 40

local on = false                 -- the one check on the miss path
local mods = {}                  -- key -> { addon = "Folder", version = "1.2", keep = fn, test = fn, index = fn }
local sess, sessSize = {}, 0     -- key -> { [text] = entry or false }: looked at this session
local last = setmetatable({}, { __mode = "k" })   -- FontString -> the last text noted for it
local total                      -- texts in all modules (counted once, then kept up to date)

-- UADD_DB.missed = { on = true|nil, mods = { [key] = { v = version, dropped = n, namesDropped = n,
--   texts = { ["len:hash"] = { t = text, n = times, d = "YYYY-MM-DD", v = version } }, names = { same } } } }
local function Saved()
    local db = rawget(_G, "UADD_DB")
    local m = type(db) == "table" and db.missed
    return type(m) == "table" and m or nil
end

local function Store()
    local db = U.DB()
    local m = db.missed
    if type(m) ~= "table" then m = {} db.missed = m end
    if type(m.mods) ~= "table" then m.mods = {} end
    return m
end

local function Mod(m, key)
    local e = m.mods[key]
    if type(e) ~= "table" then e = {} m.mods[key] = e end
    if type(e.texts) ~= "table" then e.texts = {} end
    if type(e.names) ~= "table" then e.names = {} end
    return e
end

local function Count(t) local n = 0 for _ in pairs(type(t) == "table" and t or {}) do n = n + 1 end return n end
local sizes = setmetatable({}, { __mode = "k" })   -- list -> its entries (counted once, then kept)
local function Size(list) local n = sizes[list] or Count(list) sizes[list] = n return n end

local function Total(m)
    if not total then
        total = 0
        for _, e in pairs(m.mods) do if type(e) == "table" then total = total + Count(e.texts) end end
    end
    return total
end

local function Strip(t)
    return (t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|H.-|h(.-)|h", "%1"))
end

-- Names out: an item or player link becomes <link>, a quoted text (a name the player typed) "<name>".
local function Mask(t)
    return (t:gsub("|H.-|h.-|h", "<link>"):gsub('"[^"\n]*"', '"<name>"'))
end

-- A value shown as it is: no letters but a unit of 1 to 3 right after a digit ("1,234", "4h 03m").
local function IsValue(c)
    local from = 1
    while true do
        local a, b = c:find("[A-Za-z]+", from)
        if not a then return true end
        if b - a > 2 or a == 1 or not c:find("^%d", a - 1) then return false end
        from = b + 1
    end
end

-- 1 to 5 words, each capitalised (or a small joining word after the first): a name, a place, an item.
local SMALL = { of = 1, the = 1, de = 1, ["and"] = 1, a = 1, an = 1, ["in"] = 1, on = 1, to = 1, ["for"] = 1,
    with = 1, from = 1, at = 1 }
local function NameLike(c, most)
    c = c:match("^%s*(.-)%s*$")
    if c == "" or #c > (most or NAME_LEN) or c:find("[^%w%s'%-]") or c:find("%s%s") then return false end
    local n = 0
    for w in c:gmatch("%S+") do
        n = n + 1
        if n > 5 or not (w:find("^%u") or (n > 1 and SMALL[w])) then return false end
    end
    return true
end

-- A name UALL Forever translates (a zone, an NPC, an item, a quest): its job, not a miss of ours.
local function UallName(c)
    local L = U.UALL
    c = c:match("^%s*(.-)%s*$")
    return type(L) == "table" and type(L.Zone) == "function" and (L.Zone(c) or L.Text(c)) and true or false
end

-- The text with each slot that holds a name or a value as %s, when the module's index matches a
-- template (its words around the slot are the addon's own); nil when none matches.
local function Shape(idx, s)
    if type(idx) ~= "table" or not idx.Match then return nil end
    local ok, id, caps = pcall(idx.Match, idx, s)
    local d = ok and id and idx:Template(id)
    if type(d) ~= "table" or type(d.len) ~= "table" or type(caps) ~= "table" then return nil end
    local out, lit, pos = {}, {}, 1
    for i = 1, #caps do
        local L, c = tonumber(d.len[i]) or 0, caps[i]
        out[#out + 1] = s:sub(pos, pos + L - 1)
        lit[#lit + 1] = out[#out]
        pos = pos + L
        if s:sub(pos, pos + #c - 1) ~= c then return nil end
        local plain = Strip(c)
        out[#out + 1] = (#plain <= SLOT_LEN and (NameLike(plain, SLOT_LEN) or IsValue(plain))) and "%s" or c
        pos = pos + #c
    end
    out[#out + 1] = s:sub(pos)
    lit[#lit + 1] = out[#out]
    if not table.concat(lit, " "):find("%a.-%a.-%a") then return nil end   -- the addon's words: 3 letters at least
    return table.concat(out)
end

-- Worth noting: an English text a person reads, not a value, a name the module keeps, or prose.
local function Worth(spec, t)
    if #t > MAX_LEN or t:find("[\208-\210][\128-\191]") then return false end
    local c = Strip(t)
    local words = c:gsub("<link>", ""):gsub('"<name>"', ""):gsub("%%s", "")
    if not words:find("[A-Za-z][A-Za-z]") or IsValue(words) then return false end
    if spec and spec.title and c:match("^%s*(.-)%s*$") == spec.title then return false end
    if spec and spec.keep and spec.keep(t, c) then return false end
    return true
end

local function Key(t)
    local s = t:gsub("%d+", "#")
    return #s .. ":" .. (U.Hash(s) or "?")
end

local function Today() return type(date) == "function" and date("%Y-%m-%d") or "?" end

-- The entry for `t` in module `key` (made when there is room), or false.
local function Entry(key, spec, t)
    local m = Store()
    local mod = Mod(m, key)
    if spec then mod.v = spec.version end
    local name = NameLike(Strip(t))
    if name and UallName(Strip(t)) then return false end
    local list, hk = name and mod.names or mod.texts, Key(t)
    local e = list[hk]
    if e then return e end
    local size = Size(list)
    if name and size >= MAX_NAMES then
        mod.namesDropped = (mod.namesDropped or 0) + 1
        return false
    elseif not name and (size >= MAX_MOD or Total(m) >= MAX_ALL) then
        mod.dropped = (mod.dropped or 0) + 1
        return false
    end
    e = { t = t, n = 0, d = Today(), v = spec and spec.version or nil }
    list[hk], sizes[list] = e, size + 1
    if not name then total = total + 1 end    -- counted by Total() just above
    return e
end

-- Notes `text` for module `key` (fs: the FontString it showed on, so a text set again each tick counts once).
function U.Missed(key, text, fs)
    if not on then return end
    text = U.Plain(text)
    if not text or text == "" then return end
    if fs and last[fs] == text then return end
    local seen = sess[key]
    if not seen then seen = {} sess[key] = seen end
    local e = seen[text]
    if e == nil then
        local spec = mods[key]
        local t = text
        if spec and spec.index then
            local a, b = spec.index()
            t = Shape(a, text) or Shape(b, text) or text
        end
        t = Mask(t)
        e = Worth(spec, t) and Entry(key, spec, t) or false
        if sessSize >= SESS_MAX then wipe(sess) sessSize = 0 seen = {} sess[key] = seen end
        seen[text], sessSize = e, sessSize + 1
    end
    if fs then last[fs] = text end
    if e then e.n = e.n + 1 end
end

-- Drops the entries a started module translates now (only while on).
local function Prune(key, spec)
    local m = Saved()
    local mod = m and type(m.mods) == "table" and m.mods[key]
    if type(mod) ~= "table" then return end
    mod.v = spec.version
    if type(spec.test) ~= "function" then return end
    for _, list in ipairs({ mod.texts, mod.names }) do
        for hk, e in pairs(type(list) == "table" and list or {}) do
            local ok, uk = pcall(spec.test, type(e) == "table" and e.t or "")
            if type(e) ~= "table" or (ok and uk) then list[hk], total = nil, nil wipe(sizes) end
        end
    end
end

-- A module that notes its misses. spec: addon (its target addon's folder), keep(text, plain) -> true for
-- a text it keeps English on purpose, test(text) -> true when it translates the text now, index() -> its
-- UADD.TextIndex objects (one or two; to put %s for the names in a slot). Off: only kept for later, nothing read.
function U.MissedModule(key, spec)
    if type(key) ~= "string" or type(spec) ~= "table" then return end
    spec.version = spec.addon and U.Meta(spec.addon, "Version") or nil
    spec.title = spec.addon and U.Meta(spec.addon, "Title") or spec.addon
    if type(spec.title) == "string" then spec.title = Strip(spec.title):match("^%s*(.-)%s*$") end
    mods[key] = spec
    sess[key] = nil
    local m = Saved()
    on = m ~= nil and m.on == true
    if on then Prune(key, spec) end
end

-- /uadd missed [on|off|clear [module]]
function U.MissedCommand(arg)
    local word, which = (arg or ""):lower():match("^(%S*)%s*(%S*)")
    local m = Saved()
    if word == "off" and m then m.on = nil
    elseif word == "on" then
        m = Store()
        m.on = true
        for key, spec in pairs(mods) do Prune(key, spec) end
    elseif word == "clear" and m and type(m.mods) == "table" then
        if which ~= "" then m.mods[which] = nil else wipe(m.mods) end
    end
    on = m ~= nil and m.on == true
    wipe(sess) sessSize, total = 0, nil
    wipe(sizes)
    wipe(last)
    local names, all = {}, 0
    for key, e in pairs(m and type(m.mods) == "table" and m.mods or {}) do
        local n = type(e) == "table" and Count(e.texts) + Count(e.names) or 0
        if n > 0 then
            local over = (tonumber(e.dropped) or 0) + (tonumber(e.namesDropped) or 0)
            names[#names + 1] = ("%s %d"):format(key, n) .. (over > 0 and (" (+%d понад ліміт)"):format(over) or "")
            all = all + n
        end
    end
    table.sort(names)
    U.Print(("Пропущені написи (англійською, бо ще без перекладу): %s."):format(all > 0 and table.concat(names, ", ") or "жодного"))
    U.Print(on and "Запис увімкнено. Вимкнути: /uadd missed off; стерти: /uadd missed clear [модуль]"
        or "Запис вимкнено (так типово; записане лишається). Увімкнути: /uadd missed on")
    U.Print("  Список: після виходу з гри запустіть tools/missed.py")
end

-- For the checks.
function U.MissedSessionSize() return sessSize end
function U.MissedOn() return on end
