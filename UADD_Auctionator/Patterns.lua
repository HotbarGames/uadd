-- A template (a text with %s / %d / %%) -> a Lua pattern for its English and the pieces of its
-- Ukrainian. Words.lua fills the pieces with what the pattern captures (Fill there).

local _, ns = ...

local SPEC = "%%[%-%+ #0]*%d*%.?%d*[sdif]"

-- The template's pieces: { "lit", text } / { "pct" } / { "spec", "%s" }.
local function Tokens(t)
    local out, pos = {}, 1
    while true do
        local s1, e1 = t:find("%%%%", pos)
        local s2, e2 = t:find(SPEC, pos)
        local s, e, kind = s1, e1, "pct"
        if s2 and (not s1 or s2 < s1) then s, e, kind = s2, e2, "spec" end
        if not s then out[#out + 1] = { "lit", t:sub(pos) } break end
        if s > pos then out[#out + 1] = { "lit", t:sub(pos, s - 1) } end
        out[#out + 1] = { kind, t:sub(s, e) }
        pos = e + 1
    end
    return out
end

local function Codes(t)
    local c = {}
    for _, code in ipairs({ "|c", "|r", "|T", "|t", "|H", "|h", "|n" }) do
        local _, n = t:gsub(code:gsub("|", "%%|"), "")
        c[#c + 1] = n
    end
    return table.concat(c, ",")
end

local function SpecList(toks)
    local s = {}
    for _, tk in ipairs(toks) do if tk[1] == "spec" then s[#s + 1] = tk[2]:sub(-1) end end
    return table.concat(s)
end

-- A pattern for `en` and the Ukrainian pieces, or nil when the two do not fit together.
local function Build(en, uk)
    local et, ut = Tokens(en), Tokens(uk)
    if SpecList(et) ~= SpecList(ut) or Codes(en) ~= Codes(uk) then return nil end
    local parts, lit, kinds = { "^" }, 0, {}
    for _, tk in ipairs(et) do
        if tk[1] == "lit" then
            parts[#parts + 1] = tk[2]:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
            lit = lit + #tk[2]
        elseif tk[1] == "pct" then
            parts[#parts + 1] = "%%"
        else
            local c = tk[2]:sub(-1)
            kinds[#kinds + 1] = c
            if c == "d" or c == "i" then parts[#parts + 1] = "(%-?[%d,]+)"
            elseif c == "f" then parts[#parts + 1] = "(%-?[%d%.,]+)"
            else parts[#parts + 1] = "(.-)" end
        end
    end
    if lit < 3 then return nil end            -- "%s%s" or "%s/%s" alone would match anything
    parts[#parts + 1] = "$"
    return { pat = table.concat(parts), uk = ut, kinds = kinds, lit = lit, en = en,
        first = et[1][1] == "lit" and et[1][2] or "", last = et[#et][1] == "lit" and et[#et][2] or "",
        slots = {}, rivals = {} }
end

local function IsTemplate(en) return en:find(SPEC) ~= nil or en:find("%%%%") ~= nil end

-- A value, not words: after taking out icons (|T..|t), links (|H..|h[..]|h) and colour codes, any
-- letters are at most two next to a digit ("12g", "x20", " x5", "1.2K").
local function IsValue(c)
    c = c:gsub("|T.-|t", ""):gsub("|H.-|h.-|h", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    for i, run, j in c:gmatch("()(%a+)()") do
        if #run > 2 or not (c:sub(i - 1, i - 1):find("%d") or c:sub(j, j):find("%d")) then return false end
    end
    return true
end

-- An item link's name has spaces ("[Linen Cloth]"), and a slot must not end inside it: the
-- templates are matched with each link |H..|h..|h made one mark (\1, a byte, \1), and the marks
-- are put back in what they captured. Returns the marked text and the links (nil: none).
local function Mask(t)
    if not t:find("|H", 1, true) then return t, nil end
    local links = {}
    local m = t:gsub("|H.-|h.-|h", function(l)
        if #links >= 120 then return nil end
        links[#links + 1] = l
        return "\1" .. string.char(0x80 + #links) .. "\1"
    end)
    return m, links
end

-- Template f's captures in marked text m (links put back), or nil.
local function Caps(f, m, links)
    local caps = { m:match(f.pat) }
    if caps[1] == nil then return nil end
    if links then
        for i, c in ipairs(caps) do
            caps[i] = c:gsub("\1(.)\1", function(b) return links[b:byte() - 0x80] end)
        end
    end
    return caps
end

ns.Patterns = { Build = Build, IsTemplate = IsTemplate, IsValue = IsValue, Mask = Mask, Caps = Caps }
