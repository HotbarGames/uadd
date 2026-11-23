-- The symptom check for boxes (docs/LESSONS2.md lesson 18, LESSONS3.md lesson 32, LESSONS4.md lesson 44).
-- Whatever the cause (a pinned Latin file, a font object without Cyrillic, a hand-set file kept over
-- SetFontObject), a box on screen is a FontString that shows Cyrillic in a font that has none. So:
--   * a SUSPECT is marked at SetText, SetFont and SetFontObject time: a FontString with Cyrillic text whose
--     font is not UADD.IsCyrFont. Not one: a line with no hand-set file (__hand) whose font object is a
--     font FAMILY (the game's GameTooltipText and friends have a Cyrillic member while GetFont shows only
--     FRIZQT__.TTF; wow_fontfam.lua; an addon's CreateFontFamily with a Cyrillic member), nor a FontString
--     whose font nobody named (no object, no SetFont), nor an addon's own font file with Cyrillic (boxes.py
--     file_cyr), nor a text that is not UADD's (Theirs below: by the code that set it).
--   * UADD_BOXTRACE=1 names each hit's whole call chain.
--   * at each HARNESS.step a suspect that is still one, shown and placed is a HIT: kept in H.boxHits and
--     sent to H.boxReport (boxes.py, one check per run.py segment) with its name or parent chain, its font
--     file and a 40-byte sample. UALL Forever's text counts too ("UALLF <name>").
--   * H.boxQuiet (a client loaded with a cut, a mutant) keeps the hits in H.boxHits only.
-- Loaded at the end of wow_fontfam.lua.
local H = HARNESS
local W = H.Widget
local FAMILY = { GameTooltipText = true, GameTooltipHeaderText = true, GameTooltipTextSmall = true,
    GameFontHighlightSmall = true }
local suspects = setmetatable({}, { __mode = "k" })
local said = setmetatable({}, { __mode = "k" })       -- fs -> the "font|text" last reported
H.boxHits = {}
do  -- UADD_BOXTRACE=1: each hit names the whole call chain that made it a suspect (to look at one flow)
    local py = rawget(_G, "python")
    local ok, v = pcall(function() return py.eval("__import__('os').environ.get('UADD_BOXTRACE', '')") end)
    H.boxTrace = ok and v ~= nil and v ~= "" or nil
end

-- The client's CreateFontFamily (client_facts.py "hasFontFamily"): GetFont shows the first (Latin) member's
-- file, as on GameTooltipText; a family with a Cyrillic member (ForeverDungeonJournal's ForeverDJ_*) draws
-- Cyrillic, so it counts as one of FAMILY. Without it such an addon falls back to CreateFont and a Latin file.
local function CyrFile(p)
    p = type(p) == "string" and p:lower():gsub("/", "\\") or ""
    return p:find("_cyr%.ttf$") ~= nil or p:find("\\arialn%.ttf$") ~= nil
end
if rawget(_G, "CreateFontFamily") == nil and type(rawget(_G, "CreateFont")) == "function" then
    function CreateFontFamily(name, members)
        local f = CreateFont(name)
        local first, cyr = nil, false
        for _, m in ipairs(type(members) == "table" and members or {}) do
            if type(m) == "table" then
                first = first or m
                cyr = cyr or CyrFile(m.file)
            end
        end
        if first then f:SetFont(first.file, first.height, first.flags) end
        rawset(f, "__cyrMember", cyr or nil)
        rawset(f, "GetFontObjectForAlphabet", function(self) return self end)
        return f
    end
end

-- A file an addon ships in its own folder ("Interface\AddOns\<addon>\...ttf"): boxes.py reads the installed
-- file's own letters (WhatTheWhisper's Manrope and Inter have Cyrillic). Unknown: no Cyrillic (strict).
local fileCyr = {}
local function AddonFileCyr(p)
    if type(p) ~= "string" or not p:lower():find("^interface[\\/]addons[\\/]") then return false end
    if fileCyr[p] == nil then
        local py = rawget(_G, "python")
        local ok, v = pcall(function() return py.eval("__import__('boxes').file_cyr")(p) end)
        fileCyr[p] = ok and v == true
    end
    return fileCyr[p]
end

-- Whose text, by source: UADD's when the nearest addon file on the stack at SetText is UADD's. When it is the
-- addon's own code, the text is ours only with a letter only Ukrainian has (і ї є ґ: an L word of ours the
-- addon draws itself); else it is the addon's own (gq's «Русский», ForeverDungeonJournal's own Russian) and
-- not ours to check. Gap: an L word of ours with none of those letters, drawn by the addon, is skipped.
local UA_ONLY = { "\209[\148\150\151]", "\208[\132\134\135]", "\210[\144\145]" }
local theirs = setmetatable({}, { __mode = "k" })     -- fs -> true while its text is not UADD's
local function Theirs(t)
    for level = 4, 40 do
        local info = debug.getinfo(level, "S")
        if not info then break end
        local s = info.source or ""
        if s:find("^@AddOns/UADD") then return nil end
        if s:find("^@AddOns/") then break end
    end
    for _, pat in ipairs(UA_ONLY) do if t:find(pat) then return nil end end
    return true
end

-- A family, or a copy of one whose file nobody changed since (CopyFontObject keeps the family).
local function Family(o)
    for _ = 1, 6 do
        if type(o) ~= "table" then return false end
        if FAMILY[rawget(o, "__name") or ""] or rawget(o, "__cyrMember") then return true end
        local up, f = rawget(o, "__fontObject"), rawget(o, "__font")
        local uf = type(up) == "table" and rawget(up, "__font")
        if not (f and uf and f[1] == uf[1]) then return false end
        o = up
    end
    return false
end

local function Suspect(fs)
    local t, f = rawget(fs, "__text"), rawget(fs, "__font")
    if type(t) ~= "string" or not t:find("[\208\209][\128-\191]") or type(f) ~= "table" then return false end
    local isCyr = rawget(_G, "UADD") and UADD.IsCyrFont
    if not isCyr or isCyr(f[1]) or AddonFileCyr(f[1]) or theirs[fs] then return false end
    local hand, o = rawget(fs, "__hand"), rawget(fs, "__fontObject")
    if not hand and (o == nil or Family(o)) then return false end
    return true
end

local function Mark(self, method)
    local fs = self
    if rawget(fs, "__type") ~= "FontString" then fs = rawget(self, "__fs") end
    if type(fs) ~= "table" or rawget(fs, "__type") ~= "FontString" then return end
    if method == "SetText" then
        local t = rawget(fs, "__text")
        theirs[fs] = type(t) == "string" and t:find("[\208\209][\128-\191]") and Theirs(t) or nil
    end
    if not Suspect(fs) then suspects[fs] = nil return end
    local at = true                       -- the addon file and line that made it a suspect, for the report
    for level = 3, 14 do
        local info = debug.getinfo(level, "Sl")
        if not info then break end
        if (info.source or ""):find("^@AddOns/") then
            at = info.source:sub(9) .. ":" .. tostring(info.currentline)
            break
        end
    end
    if H.boxTrace then
        local chain = {}
        for level = 3, 30 do
            local info = debug.getinfo(level, "Sl")
            if not info then break end
            local s = (info.source or ""):gsub("^@", ""):gsub("^.*/", "")
            if s ~= "boxes.lua" and s ~= "wow_fontfam.lua" and s ~= "wow_widgets.lua" then
                chain[#chain + 1] = s .. ":" .. tostring(info.currentline)
            end
        end
        at = table.concat(chain, " < ")
    end
    suspects[fs] = at
end

for _, m in ipairs({ "SetText", "SetFont", "SetFontObject" }) do
    local was = W[m]
    W[m] = function(self, ...)
        local r = { was(self, ...) }
        pcall(Mark, self, m)
        return unpack(r)
    end
end

-- As H.cyrBoxes (wow_widgets2.lua): a top frame nothing ever placed or showed draws nothing.
local function Placed(w)
    local top = w
    while top.__parent and top.__parent ~= UIParent do top = top.__parent end
    return top == UIParent or #top.__points > 0 or top.__showed
end

local function Name(fs)
    local p, name = fs, nil
    while p and not name do name = rawget(p, "__name") p = rawget(p, "__parent") end
    local uall = H.ns and H.ns.UALLF and H.ns.UALLF.replacements
    if type(uall) == "table" and uall[fs] then name = "UALLF " .. tostring(name) end
    return tostring(name or "?")
end

local function Look()
    for fs in pairs(suspects) do
        if not Suspect(fs) then
            suspects[fs] = nil
        elseif fs:IsVisible() and (fs.__alpha or 1) > 0 and Placed(fs) then
            local path, t = fs.__font[1], fs.__text
            local key = tostring(path) .. "|" .. t
            if said[fs] ~= key then
                said[fs] = key
                local o, on = rawget(fs, "__fontObject"), nil
                for _ = 1, 6 do
                    if type(o) ~= "table" or on then break end
                    on = rawget(o, "__name") o = rawget(o, "__fontObject")
                end
                local how = (rawget(fs, "__hand") and "hand," or "") .. tostring(on or "-")
                if type(suspects[fs]) == "string" then how = how .. "," .. suspects[fs] end
                local hit = { name = Name(fs), path = tostring(path) .. "<" .. how .. ">", sample = t:sub(1, 40) }
                if #H.boxHits < 50 then H.boxHits[#H.boxHits + 1] = hit end
                local rep = H.boxReport
                if not H.boxQuiet and (type(rep) == "function" or type(rep) == "userdata") then
                    rep(hit.name, hit.path, hit.sample)
                end
            end
        end
    end
end

H.boxSuspect, H.boxLook, H.boxSuspects = Suspect, Look, suspects     -- for proofs and tests

local step = H.step
function H.step(...)
    local r = { step(...) }
    local ok, err = pcall(Look)
    if not ok and not H.boxQuiet and H.boxReport then H.boxReport("boxes.lua", "error", tostring(err)) end
    return unpack(r)
end
