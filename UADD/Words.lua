-- UADD: one module's texts (English) to our Ukrainian, or nil (the text stays English). Shared by the
-- modules that find whole texts on screen by a hash of the English (UADD_WhatsTraining; UADD_Mastercraft
-- keeps its own copy of the same engine, Words.lua there).
--
-- local W = UADD.NewWords(data): data = { exact = {..}, templates = {..} } (UADD/Hash.lua, made by a
-- tools/make_*_text.py build). W.Translate(s) tries, in this order:
--   1. the whole text;
--   2. a text of several lines: each line alone; when a line with English words has no Ukrainian, the
--      whole text stays English (a name glued on with a line break must not leave a half text, lesson 7);
--   3. outer spaces taken off, put back after;
--   4. one outer colour (|c........ ... |r) taken off, put back after;
--   5. an icon at the start (|T...|t) kept, the rest translated;
--   6. a template. Each slot is filled by what it holds (rec.sort, tools/*_rules.py):
--        v  a value (a number, a time, money, a link): kept when it has no English word, else our text
--        f  a free name: kept as it is; one name only, so not a wide gap, a line break, " - " or a word
--           in small letters (that is a glued text or a phrase: the line stays English)
--        n  a game name (item, zone, NPC): UALL Forever's Ukrainian, or the whole line stays English
--        t  our text: translated again (empty stays empty)
--        b  blank (an English plural ending): dropped
--      Any slot that holds English we have no Ukrainian for keeps the whole line English (no half lines).
--   7. {one|few|many} in our Ukrainian picks its form by the last number before it (U.Plural).
-- Answers are remembered by input; a name UALL Forever cannot give yet ("wait") is not remembered.

local U = UADD

-- An English word: a run of Latin letters, but not a short unit right after a number ("5m", "10 sec")
-- nor "x" before one ("x3"). Colour codes, icons and links do not count.
local function HasLatin(v)
    if type(v) ~= "string" or not v:find("%a") then return false end
    v = v:gsub("|H.-|h.-|h", " "):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", " ")
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
U.HasLatin = HasLatin

-- Ukrainian capitals (the game's own capitals lack і ї є ґ). Latin letters too, when the text has no
-- colour codes or icons (they must keep their case).
function U.UpperUk(s)
    if type(s) ~= "string" then return s end
    if not s:find("|", 1, true) then s = s:upper() end
    s = s:gsub("\208([\176-\191])", function(c) return "\208" .. string.char(c:byte() - 32) end)
    s = s:gsub("\209([\128-\143])", function(c) return "\208" .. string.char(c:byte() + 32) end)
    s = s:gsub("\209\148", "\208\132"):gsub("\209\150", "\208\134"):gsub("\209\151", "\208\135")
    return (s:gsub("\210\145", "\210\144"))
end

function U.NewWords(data)
    local W = { HasLatin = HasLatin, Upper = U.UpperUk }
    local ix = U.TextIndex(data or {})
    local cache, size, LIMIT = {}, 0, 6000
    local waited = false
    local depth, DEPTH = 0, 6
    local Translate

    function W.Count()
        local e, t = ix:Count()
        return (e or 0) + (t or 0)
    end
    function W.Index() return ix end

    -- A game name in a slot: UALL Forever's Ukrainian, with its colour put back; false when there is none.
    local function Name(v)
        if v == "" or not HasLatin(v) or v:find("|H", 1, true) then return v end
        local c, inner = v:match("^(|c%x%x%x%x%x%x%x%x)(.-)|r$")
        local en = inner or v
        for _, look in ipairs({ U.Text, U.Zone, U.Npc, U.Item }) do
            local ua, wait = nil, nil
            if look then ua, wait = look(en) end
            if ua then return c and (c .. ua .. "|r") or ua end
            if wait then waited = true end
        end
        return false
    end

    local function Slot(k, v, rec)
        local sort = rec.sort and rec.sort[k] or "v"
        if sort == "f" then
            if v:find("   ", 1, true) or v:find("\n", 1, true) or v:find(" - ", 1, true)
                or v:find("%f[%a]%l%a") then return false end
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

    local function Raw(s)
        local uk = ix:Exact(s)
        if uk then return U.Plural(uk, true) end
        if s:find("\n", 1, true) then return Lines(s) end
        local a, body, b = s:match("^(%s*)(.-)(%s*)$")
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
        if icon then
            local t = Translate(rest)
            return t and (icon .. t) or nil
        end
        local after = 0
        while true do
            local id, caps, rank = ix:Match(s, after)
            if not id then return nil end
            local filled = ix:Fill(id, caps, Slot)
            if filled then return U.Plural(filled, true) end
            if not rank or rank <= after then return nil end
            after = rank
        end
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

    function W.Forget() wipe(cache) size = 0 end
    return W
end
