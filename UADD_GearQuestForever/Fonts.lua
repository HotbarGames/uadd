-- UADD - GearQuest Forever: a Cyrillic face where GearQuest pins its own.
--
-- GearQuest sets most of its texts' fonts by file (GQ:CalmFont, GQ:FitCalmFont, GQ:SetLocaleFont): it reads the
-- face a text has and sets that file again, which drops the Cyrillic member of the game's font family, so our
-- words would draw as boxes. Its table of faces per language is private and has no Ukrainian.
--   * Each of those three calls is wrapped: after it, while ours is in force, the text's font is saved
--     (U.SaveFont, only while ours is not on it: lesson 32) and UADD's Cyrillic face goes on through our own font
--     object (U.CyrOnLocked, at the size and flags GearQuest just gave it, read back: lesson 2).
--   * Held and off: each such text gets its saved font back (U.FontBack: its object, and the file GearQuest
--     pinned, as GearQuest set it; lesson 18), only while ours is still on it (lesson 23). On again: ours again.
--   * GQ:LocaleFontFace (asked by its own font helpers and a few windows) gives our face while ours is in force.
-- This file sets no font itself: only the core helpers do. Any error leaves GearQuest's own face.

local _, ns = ...
local U = UADD

local F = {}
ns.Fonts = F

local saved = setmetatable({}, { __mode = "k" })   -- text -> its font before ours (U.SaveFont)
local known = setmetatable({}, { __mode = "k" })   -- texts GearQuest pinned while ours was in force
local count, nknown = 0, 0

local function Cyr()
    local ok, path = pcall(U.CyrFontPath)
    return ok and type(path) == "string" and path or nil
end

local function Face(w)
    if type(w) ~= "table" or type(w.GetFont) ~= "function" then return nil end
    local ok, face, size = pcall(w.GetFont, w)
    if not ok then return nil end
    return face, size
end

-- Its saved font back, while ours is on it (never over a face GearQuest changed since).
local function Back(w)
    local was = saved[w]
    if not was then return end
    local face = Face(w)
    if face and U.IsCyrFont(face) then pcall(U.FontBack, w, was) end
    if not U.IsCyrFont((Face(w))) then saved[w] = nil end
end

-- Ours on one text GearQuest has just set a face on; read back, or its own font again.
local function Put(w)
    local face, size = Face(w)
    if type(face) ~= "string" or type(size) ~= "number" then return end
    if not known[w] then known[w], nknown = true, nknown + 1 end   -- also while off: "on" later needs it
    if not ns.Loc.InForce() then return end
    if U.IsCyrFont(face) then return end                  -- ours (or a Cyrillic face) is on: keep what we saved
    local okS, was = pcall(U.SaveFont, w)                 -- ours is not on it now: its own font (lesson 32)
    if not okS or type(was) ~= "table" or not Cyr() then return end
    saved[w] = was
    local okC, yes = pcall(U.CyrOnLocked, w)
    if okC and yes and U.IsCyrFont((Face(w))) then
        count = count + 1
        return
    end
    Back(w)
    saved[w] = nil
end
F.Put = Put

local wrapped = false
local function Wrap(g, name)
    local own = rawget(g, name)
    if type(own) ~= "function" then return end
    g[name] = function(self, widget, ...)
        local out = own(self, widget, ...)
        pcall(Put, widget)
        return out
    end
end

function F.Install()
    if wrapped then return end
    local g = ns.Loc.Addon()
    if not g then return end
    wrapped = true
    Wrap(g, "CalmFont")
    Wrap(g, "FitCalmFont")
    Wrap(g, "SetLocaleFont")
    local face = rawget(g, "LocaleFontFace")
    if type(face) == "function" then
        g.LocaleFontFace = function(self, f, ...)
            local out = face(self, f, ...)
            if ns.Loc.InForce() and out == f then
                local cyr = Cyr()
                if cyr then return cyr end
            end
            return out
        end
    end
end

-- Off or held (on = false): the saved font back where ours still is. On: ours again on those texts.
function F.Sync(on)
    for w in pairs(known) do
        if on then pcall(Put, w) else pcall(Back, w) end
    end
end

function F.Count() return count end
function F.Known() return nknown end              -- texts it ever set a face on while ours was in force
