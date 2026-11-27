-- UADD box guard: what our texts really draw (docs/LESSONS4.md lesson 46).
-- GetFont names the Latin file whether or not the font draws Cyrillic, so no read-back of a font proves letters. A
-- text's WIDTH does: a letter a font lacks is drawn as a box of one fixed width (measured in the client with
-- UADD/Probe.lua: one word, 53.3 as boxes, 39.5 as letters). So each text our font went on (U.BoxWatch) is measured
-- against the same words in a file that has the letters and in one that has not:
--   * on a state change of its button (ButtonFont.lua, one frame later), and in the next 1 s tick once it is watched,
--     its text, font or shown state changed (hooks on it), or a frame above it showed (OnShow): at most LOOK texts
--     looked at and MEASURE measured a second, none in combat, none whose text and width stayed. A shown text is
--     looked at again every SWEEP s; a hidden one not until one of those: no work while its window is closed.
--   * boxes: our font again; still boxes: the Cyrillic file by hand (it draws Latin too, so it may stay); still boxes:
--     the English back, and no Ukrainian on that text again this session. Each is noted (kinds "box", "boxfail") with
--     a sample, like the guard's other repairs (Guard.lua).
--   * never a false alarm: a text with a font of its own counts as boxes only when its width is the boxes' width of its
--     own file and the letters' width is at least 12% away. A file nobody can judge, a scaled or several-line text, or
--     fewer than 3 Cyrillic letters: no verdict, left alone.

local U = UADD
local CYR = "[\208\209\210][\128-\191]"
local FRIZ = "Fonts\\FRIZQT__.TTF"            -- a file of the client's without Cyrillic
local LOOK, MEASURE, KEEP, MAX_TELL, SWEEP = 400, 40, 300, 5, 10   -- SWEEP: a pass of the shown ones every 10 s
local weak = { __mode = "k" }
local watched = setmetatable({}, weak)        -- FontString -> true, or function(fs): its module puts its English back
local bad = setmetatable({}, weak)            -- FontString -> true: boxes after both repairs
local passed = setmetatable({}, weak)         -- FontString -> { t, w }: drawn right
local awake = setmetatable({}, weak)          -- FontString -> true: to be looked at in the next tick
local live = setmetatable({}, weak)           -- FontString -> true: shown when last looked at (swept again, slowly)
local asleep = setmetatable({}, weak)         -- frame -> { FontString = true }: hidden texts it wakes when it shows
local hooked = setmetatable({}, weak)         -- a text or frame -> true: hooked (false: one we may not hook)
local widths, kept, cyrFile = {}, 0, {}
local probe, repairs, told, fixing, sweep, at, beat = nil, 0, 0, false, {}, 1, 0

local function Same(a, b)
    return type(a) == "string" and type(b) == "string" and (a:gsub("/", "\\"):lower()) == (b:gsub("/", "\\"):lower())
end

-- The width of `text` in one file, or nil when the client cannot open that file. Kept (KEEP at most).
local function Width(path, size, flags, text)
    local key = ("%s|%.2f|%s|%s"):format(path, size, flags, text)
    local w = widths[key]
    if w ~= nil then return w or nil end
    if not probe then
        local holder = CreateFrame("Frame")
        holder:Hide()
        probe = holder:CreateFontString(nil, "BACKGROUND")
    end
    probe:SetFont(path, size, flags)
    if Same((probe:GetFont()), path) then
        probe:SetText(text)
        w = probe:GetUnboundedStringWidth()
        probe:SetText("")
    end
    if type(w) ~= "number" or w <= 0 then w = false end
    if kept >= KEEP then widths, kept = {}, 0 end
    widths[key], kept = w, kept + 1
    return w or nil
end

-- Has a file Cyrillic letters? Without them a narrow and a wide one are the same box. nil: cannot be told.
local function HasCyr(path)
    if U.IsCyrFont(path) then return true end
    local k = path:lower()
    if cyrFile[k] == nil then
        local n, w = Width(path, 20, "", "іііііі"), Width(path, 20, "", "шшшшшш")
        local ln, lw = Width(path, 20, "", "iiiiii"), Width(path, 20, "", "WWWWWW")
        local v = "?"
        if n and w and ln and lw and lw > ln * 1.2 then v = math.abs(w - n) > 0.05 * w end
        cyrFile[k] = v
    end
    local v = cyrFile[k]
    if v == "?" then return nil end
    return v
end

-- true: `fs` draws its Cyrillic text `t` (width `w`) as boxes; false: it does not, or it cannot be told.
local function Boxes(fs, t, w)
    if #t > 200 or t:find("[\13\n]") or t:find("|n", 1, true) then return false end
    local _, n = t:gsub(CYR, "")
    if n < 3 or type(w) ~= "number" or w <= 0 then return false end
    if fs.GetTextScale then
        local s = fs:GetTextScale()
        if type(s) == "number" and math.abs(s - 1) > 0.01 then return false end
    end
    local path, size, flags = fs:GetFont()
    size = tonumber(size)
    if type(path) ~= "string" or not size or size <= 0 then return false end
    local has, cyr = HasCyr(path), U.CyrFontPath()
    if has == nil or not cyr then return false end
    local good = Width(has and path or cyr, size, flags or "", t)
    local box = Width(has and FRIZ or path, size, flags or "", t)
    if not good or not box then return false end
    local gap = math.abs(box - good)
    return gap >= 0.12 * good and math.abs(w - box) <= 0.25 * gap
end

-- The text and its width as drawn now, only when it can be looked at (visible, and it shows Cyrillic). false: hidden.
local function Drawn(fs)
    if not fs.IsVisible or type(fs.GetUnboundedStringWidth) ~= "function" then return nil end
    if not fs:IsVisible() then return false end
    local t = U.Plain(fs:GetText())
    if not t or not t:find(CYR) then return nil end
    return t, fs:GetUnboundedStringWidth()
end

-- Who and what, for the record: the nearest frame name and the start of the text, cut between letters.
function U.BoxSample(fs)
    local ok, s = pcall(function()
        local p, name = fs, nil
        for _ = 1, 12 do
            if type(p) ~= "table" or name then break end
            name = U.Plain(p.GetName and p:GetName())
            p = p.GetParent and p:GetParent()
        end
        local t = U.Plain(fs:GetText()) or ""
        t = t:sub(1, 60):gsub("[\192-\255][\128-\191]*$", "")
        return tostring(name or "?") .. ": " .. t
    end)
    return ok and s or "?"
end

local function Repair(fs)
    local sample = U.BoxSample(fs)
    repairs = repairs + 1
    local function Good()
        local t, w = Drawn(fs)
        return not t or not Boxes(fs, t, w)
    end
    pcall(U.CyrOnLocked, fs)
    if not Good() and not U.Locked(fs) then
        local path, _, size, flags = U.CyrFontPath(), fs:GetFont()
        if path then pcall(U.SetFontSelf, fs, path, tonumber(size) or 12, flags or "") end
    end
    if Good() then return U.GuardNote("box", sample) end
    U.BoxGiveUp(fs, sample)
end

-- Our font cannot hold on this text (a repair failed; or ButtonFont.lua: its button's states cannot all be our
-- copies, the cap): its English back (its module's callback; none: every module draws again), and no Ukrainian on it
-- again this session (lesson 45: English, then its module puts the old font back).
function U.BoxGiveUp(fs, sample)
    if type(fs) ~= "table" or bad[fs] then return end
    sample = sample or U.BoxSample(fs)
    bad[fs], live[fs], awake[fs] = true, nil, nil
    if type(watched[fs]) == "function" then pcall(watched[fs], fs) end
    if Drawn(fs) and told < MAX_TELL and U.TellAgain then
        told = told + 1
        pcall(U.TellAgain)
    end
    U.GuardNote("boxfail", sample)
end

-- ── When to look: a text that changed or showed (hooks), never a closed window's each second ──────────
local function Wake(fs)
    if not fixing and watched[fs] ~= nil and not bad[fs] then awake[fs] = true end
end

local function Shown(frame)
    local list = asleep[frame]
    asleep[frame] = nil
    if list then for fs in pairs(list) do Wake(fs) end end
end

-- Hidden: each frame above it wakes it when it shows (not a protected one, nor one that cannot be hooked).
local function Sleep(fs)
    pcall(function()
        local p = fs:GetParent()
        for _ = 1, 20 do
            if type(p) ~= "table" then return end
            if hooked[p] == nil then
                local ok, no = pcall(function() return p:IsForbidden() or p:IsProtected() end)
                hooked[p] = ok and not no and pcall(p.HookScript, p, "OnShow", Shown) or false
            end
            if hooked[p] then
                asleep[p] = asleep[p] or setmetatable({}, weak)
                asleep[p][fs] = true
            end
            p = p:GetParent()
        end
    end)
end

-- Its text, font or shown state changes: looked at in the next tick (a FontString has no OnShow of its own).
local CHANGES = { "SetText", "SetFormattedText", "SetFont", "SetFontObject", "Show", "SetShown", "SetParent" }
local function Hook(fs)
    if hooked[fs] ~= nil then return end
    hooked[fs] = false
    local ok, no = pcall(function()
        local p = fs:GetParent()
        return fs:IsForbidden() or (type(p) == "table" and (p:IsForbidden() or p:IsProtected()))
    end)
    if not ok or no then return end
    for _, name in ipairs(CHANGES) do
        if type(fs[name]) == "function" then pcall(hooksecurefunc, fs, name, Wake) end
    end
    hooked[fs] = true
end

local function Check(fs)
    awake[fs] = nil
    if bad[fs] then live[fs] = nil return false end
    local t, w = Drawn(fs)
    if t == false then
        live[fs] = nil
        Sleep(fs)
        return false
    end
    live[fs] = true
    if not t then return false end
    local p = passed[fs]
    if p and p.t == t and p.w == w then return true end
    if Boxes(fs, t, w) then
        passed[fs] = nil
        Repair(fs)
    else
        passed[fs] = { t = t, w = w }
    end
    return true
end

-- A text our font is on: looked at from now on. `english`, when given: function(fs), its module puts the English back.
-- Not a menu row (U.Locked), nor a tooltip line (Guard.lua).
function U.BoxWatch(fs, english)
    if type(fs) ~= "table" or U.Locked(fs) then return end
    if watched[fs] ~= nil and not english then return end
    local ok, tip = pcall(function()
        local p = fs.GetParent and fs:GetParent()
        return type(p) == "table" and type(p.AddDoubleLine) == "function"
    end)
    if not ok or tip then return end
    watched[fs] = english or true
    Hook(fs)
    Wake(fs)
end

-- Our font cannot draw this text in this session (Font.lua asks): it stays English.
function U.BoxBad(fs) return bad[fs] == true end

local function Fighting() return InCombatLockdown and InCombatLockdown() end

-- One text now (ButtonFont.lua, after a state change of its button).
function U.BoxCheck(fs)
    if fixing or watched[fs] == nil or Fighting() then return end
    fixing = true
    pcall(Check, fs)
    fixing = false
end

-- The awake texts first (listed before any is looked at: a look may change the tables), then a slow sweep of the
-- shown ones (a font object changed under them calls nothing on the text). Hidden ones cost nothing.
local function Tick()
    local list, n, m = {}, 0, 0
    for fs in pairs(awake) do
        if n >= LOOK then break end
        n = n + 1
        list[n] = fs
    end
    for i = 1, n do
        if m >= MEASURE then break end
        if Check(list[i]) then m = m + 1 end
    end
    beat = beat + 1
    if at > #sweep and beat >= SWEEP and next(live) then
        sweep, at, beat = {}, 1, 0
        for fs in pairs(live) do sweep[#sweep + 1] = fs end
    end
    while n < LOOK and m < MEASURE and at <= #sweep do
        local fs = sweep[at]
        sweep[at], at, n = nil, at + 1, n + 1
        if live[fs] and Check(fs) then m = m + 1 end
    end
end

-- Once a second (Guard.lua's ticker).
function U.BoxTick()
    if fixing or Fighting() then return end
    fixing = true
    if not pcall(Tick) then sweep, at = {}, 1 end
    fixing = false
end

-- For the checks: repairs tried so far; is this text watched?
function U.BoxRepairs() return repairs end
function U.BoxWatched(fs) return watched[fs] ~= nil end
