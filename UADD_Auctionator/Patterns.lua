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

ns.Patterns = { Build = Build, IsTemplate = IsTemplate }
