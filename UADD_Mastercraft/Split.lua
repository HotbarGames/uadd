-- UADD - Mastercraft: splits of a text by plain find, for Words.lua and Tooltip.lua. A Lua pattern with
-- two lazy runs ("^(.-)x(.-)y$") takes the square of the line, and a line with a name UALL Forever makes
-- wait is never remembered, so it runs again each time (docs/LESSONS2.md lesson 22).

local _, ns = ...
local P = {}
ns.Split = P

-- Each "<open> ... <close>" (close n times: a link is |H...|h...|h, an icon |T...|t) made one space. An
-- open with no close after it, and all after it, stays as it is.
function P.Strip(v, open, close, n)
    if not v:find(open, 1, true) then return v end
    local out, from = {}, 1
    while true do
        local a = v:find(open, from, true)
        if not a then break end
        local e = a + #open - 1
        for _ = 1, n do
            e = v:find(close, e + 1, true)
            if not e then break end
            e = e + #close - 1
        end
        if not e then break end
        out[#out + 1] = v:sub(from, a - 1)
        out[#out + 1] = " "
        from = e + 1
    end
    out[#out + 1] = v:sub(from)
    return table.concat(out)
end

-- Outer spaces: (before, body, after), by one walk from each end (a pattern "^(%s*)(.-)(%s*)$" takes the
-- square of a long run of spaces inside the text).
function P.Trim(s)
    local a = s:match("^%s*")
    local e = #s
    while e > #a and s:sub(e, e):find("%s") do e = e - 1 end
    return a, s:sub(#a + 1, e), s:sub(e + 1)
end

-- Our words, ": ", then the player's own text in quotes: (words, quoted) or nil. Split at the first quote
-- (the pattern '^([^"]-%a[^"]-): (".*")$' took 400 ms on a 10 KB text).
function P.Quoted(s)
    local q = s:find('"', 1, true)
    local words = q and q > 3 and #s > q and s:sub(-1) == '"' and s:sub(q - 2, q - 1) == ": "
        and s:sub(1, q - 3)
    if words and words:find("%a") then return words, s:sub(q) end
end

-- A step, then its zones in grey ("<step>  |cff......-  <zones>|r"): (step, grey colour, zones) or nil.
function P.Zones(s)
    local p, q, grey = s:find("  (|c%x%x%x%x%x%x%x%x)%-  ")
    if p and p > 1 and s:sub(-2) == "|r" and s:sub(p - 1, p - 1):find("%S") then
        return s:sub(1, p - 1), grey, s:sub(q + 1, -3)
    end
end

-- A name, a gap, then its count in colour ("<recipe>   |cff......x51|r": a guide step's row title; two
-- spaces on a closed row): (name, gap and count) or nil. The count is found at the end, the gap by one walk
-- back over its spaces. The name is asked as one name: two recipes ("A + B") or a list of herbs keep the row
-- English on purpose (no route names them as one, and a part alone would make a half line).
function P.Count(s)
    if s:sub(-2) ~= "|r" then return end               -- most lines: out at once (lesson 12)
    local c = s:match("()|c%x%x%x%x%x%x%x%xx%d+|r$")
    if not c then return end
    local e = c - 1
    while e > 0 and s:byte(e) == 32 do e = e - 1 end
    if e > 0 and e < c - 1 then return s:sub(1, e), s:sub(e + 1) end
end

-- A coloured label, then what it says ("|cff......<label>:|r  <what>"): (colour, label, what) or nil.
function P.Label(s)
    if not s:find("^|c%x%x%x%x%x%x%x%x") then return end
    local e = s:find(":|r  ", 11, true)
    local label, what = e and s:sub(11, e - 1), e and s:sub(e + 5)
    if label and what ~= "" and label:find("%a") and not label:find("|", 1, true) then
        return s:sub(1, 10), label, what
    end
end
