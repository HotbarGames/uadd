-- ── An addon's SetFont that reads our file back (docs/LESSONS5.md lesson 48) ──────────────────────
-- An addon that sets a size by SetFont(fs:GetFont()) while ours is on passes our Cyrillic file, and SetFont pins it
-- (OneForAll's tab bar takes its names 13 to 10 so). A U.SaveFont record (Font.lua) whose file goes back by path
-- anyway, set by hand before us (`own`) or by U.CyrOnOwn (`byhand`), takes the new size and flags, so U.FontBack
-- gives back its own file at its latest size, as the addon would have set it without us. Never any other record: a
-- line that follows its font object (a game tooltip line) gets its object back and keeps the file the addon pinned
-- (English in our font, never boxes), never a Latin file by path (lessons 18, 45). Never UADD's own call: the core's
-- (U.SetFontSelf) and a module's (the stack) leave the record as it was.

local U = UADD

local KEEP = 4                                        -- the newest records of one FontString (Lines.lua: one a fill)
local FAULTS = 5                                      -- errors in the hook; then it does nothing (records stay)
local records = setmetatable({}, { __mode = "k" })   -- FontString -> its newest U.SaveFont records, oldest first
local watched = setmetatable({}, { __mode = "k" })   -- FontString -> true once its SetFont is hooked
local oursOn = setmetatable({}, { __mode = "k" })    -- FontString -> true while the font the core put on is on
local uaddAt = setmetatable({}, { __mode = "k" })    -- FontString -> "size|flags" UADD's own call last set
local selfSet, faults = 0, 0                          -- selfSet: up while the core sets a font itself

local function SamePath(a, b)
    if a == b then return type(a) == "string" end
    return type(a) == "string" and type(b) == "string" and (a:gsub("/", "\\"):lower()) == (b:gsub("/", "\\"):lower())
end

-- U.SaveFont's record of fs: an addon's SetFont of our file later may give it its new size.
function U.FontRemember(fs, was)
    local list = records[fs]
    if not list then
        list = {}
        records[fs] = list
    end
    for i = 1, #list do if list[i] == was then return end end
    list[#list + 1] = was
    if #list > KEEP then table.remove(list, 1) end
    uaddAt[fs] = nil
end

-- The core's own SetFont on a FontString (never taken for the addon's).
function U.SetFontSelf(fs, path, size, flags)
    selfSet = selfSet + 1
    local ok, err = pcall(fs.SetFont, fs, path, size, flags)
    selfSet = selfSet - 1
    if not ok then error(err, 0) end
end

-- Did UADD's own code make this call? The first addon file on the stack past this one decides (as Guard.lua's).
-- Unknown (no stack, no addon file on it): the addon's; the record keeps its own file either way.
local function ByUADD()
    local ok, st = pcall(debugstack, 2, 14, 0)
    if not ok or type(st) ~= "string" then return false end
    for line in st:gmatch("[^\n]+") do
        if not line:find("AddOns[/\\]UADD[/\\]FontReadBack%.lua") then
            local folder = line:match("AddOns[/\\]([^/\\]+)[/\\]")
            if folder then return folder:find("^UADD") ~= nil end
        end
    end
    return false
end

-- Only a record whose file goes back by path anyway (Font.lua Back).
local function ByPath(was) return (was.own or was.byhand) and not U.IsCyrFont(was.path) end

-- After their SetFont: cheapest tests first (lesson 12); the stack only when a record would change, once per size.
local function OnTheirFont(fs, path)
    if selfSet > 0 then return end
    local list = records[fs]
    if not list or not oursOn[fs] then return end
    local cyr = U.CyrFontPath()
    if not SamePath(path, cyr) then oursOn[fs] = nil return end   -- a file of theirs: ours is off now
    local p, size, flags = fs:GetFont()                          -- read back: what their call put on
    if not SamePath(p, cyr) or type(size) ~= "number" then return end
    flags = type(flags) == "string" and flags or ""
    local take
    for i = 1, #list do
        local was = list[i]
        if ByPath(was) and (was.size ~= size or (was.flags or "") ~= flags) then
            take = take or {}
            take[#take + 1] = was
        end
    end
    if not take then return end
    local key = size .. "|" .. flags
    if uaddAt[fs] == key then return end
    if ByUADD() then uaddAt[fs] = key return end
    uaddAt[fs] = nil
    for _, was in ipairs(take) do was.size, was.flags = size, flags end
end

-- Our font took on fs (U.CyrOnLocked, U.CyrOnOwn): its SetFont is watched from now on. Never a menu region (reading
-- SetFont on one throws, lesson 38) nor a forbidden one.
function U.FontWatch(fs)
    if U.Locked(fs) or (fs.IsForbidden and fs:IsForbidden()) then return end
    oursOn[fs] = true
    if watched[fs] then return end
    watched[fs] = true
    pcall(hooksecurefunc, fs, "SetFont", function(self, path)
        if faults >= FAULTS then return end
        local ok, err = pcall(OnTheirFont, self, path)
        if not ok then
            faults = faults + 1                         -- each error once in the chat (U.ReportError), then quiet
            if U.ReportError then pcall(U.ReportError, tostring(err)) end
        end
    end)
end

-- U.FontBack put its own font back: once ours is off (on(fs) false), their SetFont is theirs again.
function U.FontUnwatch(fs, on)
    if oursOn[fs] and not on(fs) then oursOn[fs] = nil end
end
