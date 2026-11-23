-- UADD - OneForAll: pieces of a line that OneForAll joins in code with a dot ("Level 18  ·  Paladin  ·  0 / 12")
-- or a wide gap: each piece is ours (a text, a class from the glossary, a zone from UALL Forever or ClassicUA, a
-- value); one piece left English keeps the whole line English. The dot is drawn as our "  -  " (lesson 6).
-- Words.lua calls W.Joined after its own steps; it gives W.Atom and W.Value for the pieces.

local _, ns = ...
local U = UADD
local find, sub = string.find, string.sub
local W = ns.Words
local P = W.P
local Atom, Value = W.Atom, W.Value
local CYR = "[\208-\210]"
local MAXPIECES = 8

local function Class(p)
    local G = U.Glossary
    if not (G and G.Text) or #p > 80 or find(p, "[^%a, ]") then return nil end
    local out, n = {}, 0
    for name in string.gmatch(p, "[^,]+") do
        name = name:gsub("^%s+", ""):gsub("%s+$", "")
        local ok, uk = pcall(G.Text, "class." .. string.lower(name):gsub(" ", "_"))
        n = n + 1
        if n > 12 or not ok or type(uk) ~= "string" then return nil end
        out[n] = uk
    end
    return n > 0 and table.concat(out, ", ") or nil
end

local function Zone(p)
    if #p > 60 or find(p, "[|%[%(\n%d]") or not find(p, "^%u") then return nil end
    P.asked = true                                -- a game name: a miss now may be an answer later, never kept
    local route = UADD.UALL and UADD.UALL.Zone
    if type(route) ~= "function" then return nil end
    local ok, uk = pcall(route, p)
    if ok and type(uk) == "string" and uk ~= p and find(uk, CYR) then return uk end
    return nil
end

local function Coords(p) return find(p, "^%(?%d+%.?%d*, %d+%.?%d*%)?$") and p or nil end

local Joined

local function Piece(p)
    local lead = p:match("^|c%x%x%x%x%x%x%x%x") or ""
    local core = sub(p, #lead + 1)
    local tail = core:match("|r$") or ""
    core = sub(core, 1, #core - #tail)
    core = core:gsub("^%s+", ""):gsub("%s+$", "")
    if core == "" or not find(core, "%w") then return nil end
    local uk = Atom(core) or Class(core) or Coords(core) or Value(core) or Zone(core)
    if not uk then
        local z, c = core:match("^(%u[^%d|%(]-)%s+([%(%d][%d%.,%) ]*)$")
        local zk = z and Zone(z)
        if zk and Coords(c) then uk = zk .. " " .. c end
    end
    if not uk and find(core, "  ", 1, true) then uk = Joined(core) end
    return uk and (lead .. uk .. tail) or nil
end

function Joined(s)
    if #s > 300 then return nil end
    local dot = find(s, "·", 1, true)
    if not dot and not find(s, "  ", 1, true) then return nil end
    local out, n, pos = {}, 0, 1
    while pos <= #s + 1 do
        -- the next separator: a dot between wide gaps, maybe in its own colour, or a wide gap
        local a, b, code = find(s, "%s%s(|?c?%x*)·%s%s", pos)
        if a and code ~= "" and not find(code, "^|c%x%x%x%x%x%x%x%x$") then a = nil end
        local sep = "  -  "
        if a then
            sep = "  " .. code .. "-  "
        else
            a, b = find(s, "  +", pos)
            sep = a and sub(s, a, b) or ""
        end
        local piece = sub(s, pos, (a or #s + 1) - 1)
        n = n + 1
        if n > MAXPIECES then return nil end
        local uk = Piece(piece)
        if not uk then return nil end
        out[n] = uk
        if not a then break end
        out[n + 1] = sep
        n = n + 1
        pos = b + 1
    end
    return table.concat(out)
end

W.Joined = Joined
