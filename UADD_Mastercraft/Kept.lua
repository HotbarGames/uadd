-- UADD - Mastercraft: the font Mastercraft keeps for its own strings, while ours is on (docs/LESSONS5.md lesson 48).
--
-- Mastercraft's fitters set a size by SetFont with the font GetFont gives: while ours is on, that is our Cyrillic
-- file. Its SetFont wrappers keep the file they are given (ns.Text's mcPath; ns.RawText's in a local of its own)
-- and use it again later (a player's name in another alphabet and back, a language switch), so its English would
-- come out in our file. And a RawText string has no mcSize: its new size lived nowhere. So each SetFont of its own
-- while ours is on is kept here (the size and flags it asked for, and its file when that is not ours), mcPath
-- never stays ours, and off and held give back its own file at its latest size through its own SetFont, which
-- puts its kept file right too (Screen.lua Font).

local _, ns = ...
local U = UADD
local K = {}
ns.Kept = K

local asked = setmetatable({}, { __mode = "k" })    -- fs -> { size, flags, path } its own SetFont asked, ours on

local function Latin(path) return type(path) == "string" and not U.IsCyrFont(path) and path or nil end

-- Its own file: the one its wrapper keeps, the last one it asked for, the one it had before ours.
local function OwnPath(fs, was)
    local a = asked[fs]
    return Latin(rawget(fs, "mcPath")) or (a and a.path) or Latin(was.mcPath) or Latin(was[1]) or STANDARD_TEXT_FONT
end

local function Mend(fs, was)
    if U.IsCyrFont(rawget(fs, "mcPath")) then rawset(fs, "mcPath", OwnPath(fs, was)) end
end

-- Ours goes on for the first time since its own font: what it keeps now.
function K.Saved(fs, was)
    was.mcPath = rawget(fs, "mcPath")
    asked[fs] = nil
end

-- Its own SetFont ran while ours is on (was: the record from before ours).
function K.Asked(fs, was, path, size, flags)
    local a = asked[fs]
    if not a then a = {} asked[fs] = a end
    if type(size) == "number" then a.size, a.flags = size, type(flags) == "string" and flags or "" end
    if Latin(path) then a.path = path end
    Mend(fs, was)
end

-- Its latest size and flags: mcSize (ns.Text), else the last it asked for, else the one from before ours.
function K.Size(fs, was)
    local mc = rawget(fs, "mcSize")
    if mc then return mc, rawget(fs, "mcFlags") or was[3] or "" end
    local a = asked[fs]
    if a and a.size then return a.size, a.flags end
    return was[2], was[3]
end

-- Ours goes off: its own file, size and flags; mcPath its own again.
function K.Back(fs, was)
    local path = OwnPath(fs, was)
    local size, flags = K.Size(fs, was)
    asked[fs] = nil
    Mend(fs, was)
    return path, size, flags or ""
end

-- Ours went off another way (its own font is on already): only its kept file, never ours.
function K.Drop(fs, was)
    Mend(fs, was)
    asked[fs] = nil
end

-- Its font back through its own SetFont (its wrapper keeps that file, never ours); read back, else the game's
-- setter. hush(true) keeps our own hook on its SetFont quiet; hush(old) after.
function K.Give(fs, path, size, flags, hush)
    local set = rawget(fs, "SetFont")
    if type(set) == "function" then
        local was = hush(true)
        pcall(set, fs, path, size, flags)
        hush(was)
    end
    local now, s = fs:GetFont()
    if U.IsCyrFont(now) or type(s) ~= "number" or math.abs(s - size) >= 0.5 then
        fs.mcSetFont(fs, rawget(fs, "mcScript") or path, size, flags)
    end
end
