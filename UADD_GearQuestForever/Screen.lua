-- UADD - GearQuest Forever: texts already drawn, switched on the hold key, off and on.
--
-- GearQuest asks its locale table when it builds a window and keeps the text, so a switch of ours shows only in
-- windows built after it. This pass goes over its windows (its frames named GearQuest...) and swaps each text that
-- is whole: our text -> its English key (held, off), its English key -> ours (on again).
--   * Only pairs its own lookups handed out (Locale.lua learns them), and its templates: a line made from one
--     of them ("... %s ...") is matched whole and made again from the other side's template with the same values,
--     so the line is all ours or all English, never a mix.
--   * A text is put back only while it still shows what we set (lesson 23); text boxes (the player's own text)
--     are never touched; no walk in combat (Module.lua waits, lesson 36). At most MAX frames a pass.
--   * Fonts go with the text (Fonts.lua).
-- Any error leaves the text as it was.

local _, ns = ...
local U = UADD

local S = {}
ns.Screen = S

local PREFIX = "GearQuest"
local DEPTH, MAX, LONG = 12, 4000, 400
local set = setmetatable({}, { __mode = "k" })   -- FontString -> the text we set on it
local roots, rootsAt, rootsSig = {}, -1e9, nil
local changed = 0

-- What a window made since the last scan leaves behind: a text learned from its lookups, a text it set a face on.
local function Sig()
    local okL, n = pcall(ns.Loc.Count)
    local okF, k = pcall(ns.Fonts.Known)
    return (okL and tonumber(n) or 0) .. ":" .. (okF and tonumber(k) or 0)
end

-- Its frames by name (a scan of the globals at most once in 30 s: the hold key may be pressed often), and again
-- at once when a window was made since (lesson 2: a late window is switched too).
local function Roots()
    local now = type(GetTime) == "function" and GetTime() or 0
    local sig = Sig()
    if now - rootsAt < 30 and #roots > 0 and sig == rootsSig then return roots end
    rootsAt, roots, rootsSig = now, {}, sig
    for name, f in pairs(_G) do
        if type(name) == "string" and name:sub(1, #PREFIX) == PREFIX and type(f) == "table"
            and type(f.GetObjectType) == "function" and type(f.GetParent) == "function" then
            local ok, p = pcall(f.GetParent, f)
            local pn = ok and p and type(p.GetName) == "function" and select(2, pcall(p.GetName, p)) or nil
            if type(pn) ~= "string" or pn:sub(1, #PREFIX) ~= PREFIX then roots[#roots + 1] = f end
        end
    end
    return roots
end

-- A template's text as a Lua pattern: magic letters escaped, each slot a capture ("%%" is one "%"; a number slot
-- takes only digits, so "%d%s" splits where the digits end).
local pats = {}
local CAP = { d = "(%-?%d+)", i = "(%-?%d+)", f = "(%-?[%d%.]+)", s = "(.-)" }
local function Esc(s) return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")) end
local function Pattern(t)
    local p = pats[t]
    if p ~= nil then return p or nil end
    local out, i, n, bad = {}, 1, 0, false
    while i <= #t do
        local s = t:find("%", i, true)
        if not s then out[#out + 1] = Esc(t:sub(i)); break end
        out[#out + 1] = Esc(t:sub(i, s - 1))
        if t:sub(s + 1, s + 1) == "%" then
            out[#out + 1], i = "%%", s + 2
        else
            local a, e, kind = t:find("^%%[-+#0]*%d*%.?%d*([sdif])", s)
            if not a then bad = true; break end
            out[#out + 1] = CAP[kind]
            n, i = n + 1, e + 1
        end
    end
    if bad then n = 0 end
    p = (n > 0 and n <= 3) and ("^" .. table.concat(out) .. "$") or false
    pats[t] = p
    return p or nil
end

local function Fill(t, vals)
    local ok, out = pcall(string.format, t, unpack(vals))
    return ok and out or nil
end

-- What each slot of a template holds (the data's S: v value, f free, t our text), by its English key.
local sorts = {}
local function Sorts(en)
    local s = sorts[en]
    if s == nil then
        local ok, h = pcall(U.Hash, en)
        s = ok and ns.SORT and ns.SORT["L." .. tostring(h)] or false
        sorts[en] = s
    end
    return s or nil
end

-- One slot's value for the other side, or nil (the whole line then stays as it is: no half line).
--   v: a value (a number, a version, a link, a colour): no Latin word in it once codes are out.
--   f: a name kept as it is, never a glued text (lesson 7).
--   t: one of its texts: its other side, or nil.
local function Slot(sort, v, toEnglish)
    if sort == "v" then
        local bare = v:gsub("|H.-|h.-|h", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
        if bare:find("[A-Za-z][A-Za-z]") and not bare:find("^%x+$") then return nil end   -- hex: a colour
        return v
    elseif sort == "f" then
        if v:find("\n", 1, true) or v:find("   ", 1, true) or v:find(" - ", 1, true) then return nil end
        return v
    elseif sort == "t" then
        if toEnglish then return ns.Loc.Back()[v] end
        return ns.Loc.Ours(v)
    end
    return v
end

-- The values for the other side of template en, or nil.
local function Values(en, vals, toEnglish)
    local s = Sorts(en)
    if not s then return vals end
    local out = {}
    for i, v in ipairs(vals) do
        local o = Slot(s:sub(i, i), v, toEnglish)
        if o == nil then return nil end
        out[i] = o
    end
    return out
end

-- The other side of one whole text: toEnglish true gives its English, false ours. nil: not a text of ours.
local function Other(text, toEnglish)
    local back = ns.Loc.Back()
    if toEnglish then
        local en = back[text]
        if en then return en end
    else
        local ours = ns.Loc.Ours(text)
        if ours then return ours end
    end
    if #text > LONG then return nil end
    for en, ours in pairs(ns.Loc.Templates()) do
        local from, to = toEnglish and ours or en, toEnglish and en or ours
        local p = Pattern(from)
        if p then
            local vals = { text:match(p) }
            local other = #vals > 0 and Values(en, vals, toEnglish)
            if other then
                local out = Fill(to, other)
                -- Made again from the same side, it must give the same text: the values went in whole.
                if out and Fill(from, vals) == text then return out end
            end
        end
    end
    return nil
end
S.Other = Other

local function Text(fs, toEnglish)
    local ok, text = pcall(fs.GetText, fs)
    if not ok or type(text) ~= "string" or text == "" then return end
    local mine = set[fs]
    if mine and mine ~= text then set[fs] = nil end         -- it drew something else since: not ours to undo
    local out = Other(text, toEnglish)
    if not out or out == text then return end
    if pcall(fs.SetText, fs, out) then
        set[fs] = out
        changed = changed + 1
    end
end

local function Kind(f)
    local ok, k = pcall(f.GetObjectType, f)
    return ok and k or nil
end

local function Walk(f, toEnglish, depth, seen)
    if seen.n >= MAX or depth > DEPTH or seen[f] then return end
    seen[f], seen.n = true, seen.n + 1
    local k = Kind(f)
    if k == "EditBox" or k == "GameTooltip" then return end
    if k == "FontString" then return Text(f, toEnglish) end
    for _, r in ipairs(U.Regions(f)) do
        if Kind(r) == "FontString" then Text(r, toEnglish) end
    end
    for _, c in ipairs(U.Children(f)) do Walk(c, toEnglish, depth + 1, seen) end
end

-- Ours (on) or its English (off, held) on every text of its windows that is whole; fonts with them.
function S.Sync(on)
    local seen = { n = 0 }
    for _, f in ipairs(Roots()) do Walk(f, not on, 1, seen) end
    pcall(ns.Fonts.Sync, on)
end

function S.Count() return changed end
