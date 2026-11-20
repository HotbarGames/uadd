-- UADD - Mastercraft: one text of Mastercraft's (English) to our Ukrainian, or nil (it stays English).
--
-- data/*.lua (made by tools/make_mc_text.py) hold hashes of Mastercraft's English and our Ukrainian:
-- whole texts (exact) and templates with slots. W.Translate(s) tries, in this order:
--   1. the whole text;
--   2. a text of several lines: each line alone; when a line with English words has no Ukrainian, the
--      whole text stays English (a name glued on with a line break must not leave a half text, lesson 7);
--   3. outer spaces taken off, put back after;
--   4. one outer colour (|c........ ... |r) taken off, put back after;
--   5. an icon at the start (|T...|t) kept, the rest translated (or else on to the templates);
--   6. a template. Each slot is filled by what it holds (rec.sort, tools/mc_rules.py):
--        v  a value (a number, a time, money, a link): kept when it has no English word, else our text
--        f  a free name (a player, a version): kept as it is; one name only, so not a wide gap, a line
--           break, " - " or a word in small letters (that is a glued text or a phrase: the line stays English)
--        n  a game name (item, zone, NPC), or a list of them with counts: UALL Forever's Ukrainian for
--           every name, or the whole line stays English
--        t  our text: translated again (empty stays empty)
--        b  blank (an English plural ending): dropped
--      Any slot that holds English we have no Ukrainian for keeps the whole line English (no half lines).
--   7. a text with a percent after it ("<word> 75%"): the text translated, the percent kept;
--   8. parts joined with " · ", a grey "  ·  " or "  -  ": each part alone; a part with English we have
--      no Ukrainian for keeps the whole text English;
--   9. a text with a coloured number or a skill ("286 / 300") after it: the text translated; a step with
--      its zones in grey after it: both; a coloured label and what it says ("Now:  <step>"): both;
--  10. our words, ": ", then the player's own text in quotes: our words translated, the quotes never;
--  11. {one|few|many} in our Ukrainian picks its form by the last number before it (U.Plural);
--  12. a line that is only one game name, maybe after a guild tag: UALL Forever's (a list there may be
--      players' names, lesson 13).
-- Answers are remembered by input; a name UALL Forever cannot give yet ("wait") is not remembered, and
-- W.Try says so (the screen tries that line again later).

local _, ns = ...
local U = UADD
local W = {}
ns.Words = W

local ix = U.TextIndex(ns.MC or {})
local cache, size, LIMIT = {}, 0, 6000
local waited = false
local depth, DEPTH = 0, 6
local DOT = " \194\183 "                           -- Mastercraft's " · " join (U+00B7), as bytes
local Translate

function W.Count()
    local e, t = ix:Count()
    return (e or 0) + (t or 0)
end
function W.Index() return ix end

-- Splits by plain find, never a pattern with two lazy runs (Split.lua, docs/LESSONS2.md lesson 22).
local P = ns.Split
local Strip, Trim = P.Strip, P.Trim

-- An English word: a run of Latin letters, but not a short unit right after a number ("5m", "10 sec")
-- nor "x" before one ("x3"). Colour codes, icons and links do not count.
local function HasLatin(v)
    if type(v) ~= "string" or not v:find("%a") then return false end
    v = Strip(v, "|H", "|h", 2):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    v = Strip(v, "|T", "|t", 1)
    local from = 1
    while true do
        local a, b = v:find("%a+", from)
        if not a then return false end
        local before, after = v:sub(1, a - 1), v:sub(b + 1, b + 1)
        local unit = b - a < 3 and before:find("%d%s?$") ~= nil
        local times = b == a and v:sub(a, a):lower() == "x" and after:find("%d") ~= nil
        if not unit and not times then return true end
        from = b + 1
    end
end
W.HasLatin = HasLatin

-- A game name in a slot: UALL Forever's Ukrainian, with its colour put back; false when there is none.
-- A list ("2 <item>, <item>", "<zone> or <zone>") is asked name by name: all of them, or false. One name
-- may have a count before it ("2 ", "2-3 ", "2x ") or after it (" x10"), or a value after " - " (a price).
local ROUTES = { "Text", "Zone", "Npc", "Item" }
local BARE = { "Zone", "Npc", "Item" }   -- a line that is only a name: never the UI-word route
local LISTS = { { ", ", ", " }, { " / ", " / " }, { " or ", " або " } }

local function One(en, routes)
    local A = U.UALL   -- UALL Forever's routes live here, never on UADD's root (docs/LESSONS2.md lesson 20)
    for _, route in ipairs(routes) do
        local look = type(A) == "table" and A[route]
        local ua, wait = nil, nil
        if type(look) == "function" then ua, wait = look(en) end
        if type(ua) == "string" and ua ~= "" then return ua end
        if wait then waited = true end
    end
end

local function Counted(v, routes)
    local ua = One(v, routes)
    if ua then return ua end
    local n, rest = v:match("^(%d+%-?%d*x? )(.*%S)$")
    if n then
        ua = One(rest, routes)
        return ua and (n .. ua)
    end
    local head, tail = v:match("^(.-%S)( x%d+)$")
    if not head then
        head, tail = v:match("^(.-%S)( %- .+)$")
        if tail and HasLatin(tail) then head = nil end
    end
    if head then
        ua = One(head, routes)
        return ua and (ua .. tail)
    end
end

local function List(v, routes, i)
    local sep = LISTS[i]
    if not sep then return Counted(v, routes) end
    if not v:find(sep[1], 1, true) then return List(v, routes, i + 1) end
    local whole = One(v, routes)
    if whole then return whole end
    local out = {}
    for part in (v .. sep[1]):gmatch("(.-)" .. sep[1]) do
        local t = part ~= "" and List(part, routes, i + 1)
        if not t then return nil end
        out[#out + 1] = t
    end
    return table.concat(out, sep[2])
end

-- one: a single name (with its count), never a list.
local function Name(v, routes, one)
    if v == "" or not HasLatin(v) or v:find("|H", 1, true) then return v end
    local c, inner = v:match("^(|c%x%x%x%x%x%x%x%x)(.-)|r$")
    local ua = List(inner or v, routes or ROUTES, one and #LISTS + 1 or 1)
    if not ua then return false end
    return c and (c .. ua .. "|r") or ua
end
W.Name = Name

local function Slot(k, v, rec)
    local sort = rec.sort and rec.sort[k] or "v"
    -- A free slot holds one name: a wide gap, a line break or " - " in it means a text glued on (lesson 7);
    -- a word in small letters ("the", "and") means a phrase, not a name: a longer template fits, or none.
    if sort == "f" then
        local bare = v:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")   -- a name in its class colour
        if bare:find("   ", 1, true) or bare:find("\n", 1, true) or bare:find(" - ", 1, true)
            or bare:find("%f[%a]%l%a") then return false end
        return v
    end
    if sort == "b" then return "" end
    if sort == "n" then return Name(v) end
    if sort == "t" then
        if v == "" then return v end
        local t = Translate(v)
        if t then return t end
        return not HasLatin(v) and v or false
    end
    if not HasLatin(v) then return v end
    return Translate(v) or false
end

local function Lines(s)
    local out, any = {}, false
    for line in (s .. "\n"):gmatch("(.-)\n") do
        local t = line ~= "" and Translate(line) or nil
        if t then any = true elseif HasLatin(line) then return nil end
        out[#out + 1] = t or line
    end
    return any and table.concat(out, "\n") or nil
end

local function Joined(s, sep, back)
    local out, any = {}, false
    for part in (s .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do
        local t = part ~= "" and Translate(part) or nil
        if t then any = true elseif HasLatin(part) then return nil end
        out[#out + 1] = t or part
    end
    return any and table.concat(out, back) or nil
end

local function Raw(s)
    local uk = ix:Exact(s)
    if uk then return U.Plural(uk, true) end
    if s:find("\n", 1, true) then return Lines(s) end
    local a, body, b = Trim(s)
    if a ~= "" or b ~= "" then
        if body == "" then return nil end
        local t = Translate(body)
        return t and (a .. t .. b) or nil
    end
    local c, inner = s:match("^(|c%x%x%x%x%x%x%x%x)(.*)|r$")
    if c and not inner:find("|c", 1, true) and not inner:find("|r", 1, true) then
        local t = inner ~= "" and Translate(inner)
        return t and (c .. t .. "|r") or nil
    end
    local icon, rest = s:match("^(|T.-|t%s*)(.+)$")
    if icon then                        -- (else a template may hold the icon in a slot: a disenchant row)
        local t = Translate(rest)
        if t then return icon .. t end
    end
    local after = 0
    while true do
        local id, caps, rank = ix:Match(s, after)
        if not id then break end
        local filled = ix:Fill(id, caps, Slot)
        if filled then return U.Plural(filled, true) end
        if not rank or rank <= after then break end
        after = rank
    end
    -- 7. a text and a percent after it ("%s %d%%", a disenchant chance: too short to ship as a template)
    local head, pct = s:match("^(.-%S)( %d+%%)$")
    if head then
        local t = Translate(head)
        if t then return t .. pct end
    end
    -- 8. parts joined with " · " (the Crafters profile line), a grey "  ·  " (Home's next steps) or "  -  "
    -- (the cooking card): each part alone, all of them or none. The dot is matched by its bytes; our line
    -- joins the parts with "—" instead, which the Cyrillic fonts surely draw.
    if s:find(DOT, 1, true) then return Joined(s, DOT, " — ") end
    local dot = s:match("  |c%x%x%x%x%x%x%x%x\194\183|r  ")
    if dot then return Joined(s, dot, (dot:gsub("\194\183", "\226\128\148"))) end
    if s:find("  -  ", 1, true) then return Joined(s, "  -  ", "  -  ") end
    -- 9. a text and a number after it: coloured ("Tailoring |cffffffff300|r") or a skill ("<rank>  286 / 300")
    local text, num = s:match("^(.-%S)( |c%x%x%x%x%x%x%x%x%d+|r)$")
    if not text then text, num = s:match("^(.-%S)(  %d+ / %d+)$") end
    if text then
        local t = Translate(text)
        if t then return t .. num end
    end
    -- 9b. a step and its zones in grey after it ("<step>  |cff......-  <zone>, <zone>|r"): both or none
    local step, grey, zones = P.Zones(s)
    if step then
        local t, z = Translate(step), Name(zones)
        if t and z then return t .. "  " .. grey .. "-  " .. z .. "|r" end
    end
    -- 9c. a coloured label, then what it says ("|cff......Now:|r  <what>", the guide's line): both or none
    local lc, label, what = P.Label(s)
    if lc then
        local a, b = Translate(label), Translate(what)
        if a and b then return lc .. a .. ":|r  " .. b end
    end
    -- 10. our words, then the player's own text in quotes (a note for buyers): the quotes kept as they are
    local words, quoted = P.Quoted(s)
    if words then
        local t = Translate(words)
        if t then return t .. ": " .. quoted end
    end
    -- 12. a line that is only a game name (a fish, the zone under the character), maybe after the player's
    -- guild in <> (kept as it is): UALL Forever's name, never its UI-word route. One name only, never a list
    -- ("Thrall, Jaina" may be players named as NPCs; lists of names live in template slots). One word alone
    -- only as a zone: a one-word name may be a player's (docs/LESSONS2.md lesson 13).
    local tag, gap, rest = s:match("^(<[^>]*>)(%s+)(.+)$")
    local bare = rest or s
    local ua = Name(bare, bare:find(" ", 1, true) and BARE or { "Zone" }, true)
    if ua and ua ~= bare then return tag and (tag .. gap .. ua) or ua end
    return nil
end

Translate = function(s)
    if type(s) ~= "string" or s == "" or not s:find("%a") then return nil end
    local hit = cache[s]
    if hit ~= nil then return hit or nil end
    if depth >= DEPTH then return nil end
    local top = depth == 0
    if top then waited = false end
    depth = depth + 1
    local ok, uk = pcall(Raw, s)
    depth = depth - 1
    if not ok then uk = nil end
    if uk == s then uk = nil end
    if not waited then
        if size >= LIMIT then wipe(cache) size = 0 end
        cache[s] = uk or false
        size = size + 1
    end
    return uk
end
W.Translate = Translate

-- Translate, and whether a game name in it had to wait for UALL Forever ("not now": in combat, the
-- hold key...). The screen tries such a line again a little later.
function W.Try(s)
    waited = false
    local uk = Translate(s)
    return uk, waited
end

-- Ukrainian capitals where Mastercraft writes a heading in capitals (its own capitals lack і ї є ґ).
-- Latin letters too, when the text has no colour codes or icons (they must keep their case).
function W.Upper(s)
    if type(s) ~= "string" then return s end
    if not s:find("|", 1, true) then s = s:upper() end
    s = s:gsub("\208([\176-\191])", function(c) return "\208" .. string.char(c:byte() - 32) end)
    s = s:gsub("\209([\128-\143])", function(c) return "\208" .. string.char(c:byte() + 32) end)
    s = s:gsub("\209\148", "\208\132"):gsub("\209\150", "\208\134"):gsub("\209\151", "\208\135")
    return (s:gsub("\210\145", "\210\144"))
end

function W.Forget() wipe(cache) size = 0 end
