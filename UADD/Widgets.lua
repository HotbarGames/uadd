-- UADD.WidgetMethods(kind): the method table that all widgets of one kind share ("Frame", "Button", ...),
-- for a hook on a method (CreateFontString) that covers every widget of that kind. nil when there is none.
--
-- It never makes an EditBox: a new one is shown with autoFocus on and takes the keyboard for good (Enter
-- no longer opens chat; docs/LESSONS2.md lesson 16). An EditBox's table comes from one the game already
-- has (the chat edit box). Other kinds are made once, hidden at once, and kept.

local U = UADD

local cache = {}
local EXISTING = { EditBox = { "ChatFrame1EditBox", "ChatFrame2EditBox", "ChatFrame3EditBox" } }

local function Methods(f)
    local mt = type(f) == "table" and getmetatable(f)
    local t = type(mt) == "table" and mt.__index
    return type(t) == "table" and t or nil
end

function U.WidgetMethods(kind)
    if type(kind) ~= "string" then return nil end
    if cache[kind] then return cache[kind] end
    local t
    if EXISTING[kind] then
        for _, name in ipairs(EXISTING[kind]) do
            local f = rawget(_G, name)
            if type(f) == "table" and f.IsObjectType and f:IsObjectType(kind) then
                t = Methods(f)
                if t then break end
            end
        end
    else
        local ok, f = pcall(CreateFrame, kind)
        if ok and f then
            f:Hide()
            t = Methods(f)
        end
    end
    cache[kind] = t
    return t
end

-- U.OnNewFrame(fn) and U.OnNewFontString(fn): fn(kind, name, parent) after each CreateFrame of the game, and
-- fn(frame) after each CreateFontString of a frame kind. Every frame the game makes passes here (a BG makes
-- hundreds: nameplates, raid frames), so there is one hook for all modules, each fn runs under U.SafeCall
-- (an error is counted for its module and goes no further, lesson 35), and each fn must leave at once, with a
-- type or table look-up, for a frame that is not its addon's. Odd arguments (nil, a number, a name with no
-- frame, a table that is no frame) reach fn as they came.
local onFrame, onFont, fontHooked = {}, {}, {}
local FONT_KINDS = { "Frame", "Button", "CheckButton", "StatusBar", "ScrollFrame", "Slider", "EditBox" }

local function RunFrame(kind, name, parent)
    for i = 1, #onFrame do U.SafeCall(onFrame[i], kind, name, parent) end
end
local function RunFont(self)
    for i = 1, #onFont do U.SafeCall(onFont[i], self) end
end
U.NewFrameRun, U.NewFontRun = RunFrame, RunFont                   -- for the checks

function U.OnNewFrame(fn)
    if type(fn) ~= "function" then return false end
    onFrame[#onFrame + 1] = fn
    if #onFrame == 1 and type(hooksecurefunc) == "function" then
        local ok = pcall(hooksecurefunc, "CreateFrame", RunFrame)
        if not ok then onFrame[1] = nil return false end
    end
    return true
end

-- A frame of the game's busy families (nameplates, raid, party and arena frames: a BG makes them by the
-- hundred), told by its own name only: no parent walk. A module's CreateFontString hook leaves at once then.
local GAME = { "NamePlate", "CompactRaid", "CompactParty", "CompactArena", "CompactUnitFrame" }
function U.GameMade(f)
    local get = type(f) == "table" and f.GetName
    if type(get) ~= "function" then return false end
    local ok, name = pcall(get, f)
    if not ok or not U.Plain(name) then return false end
    for i = 1, #GAME do
        local g = GAME[i]
        if name:sub(1, #g) == g then return true end
    end
    return false
end

-- Wait while the player is in combat (nothing of ours is worth a hitch then): true when fn was put off.
function U.AfterCombat(fn)
    if type(InCombatLockdown) ~= "function" or not InCombatLockdown() then return false end
    if C_Timer and C_Timer.After then C_Timer.After(1, fn) end
    return true
end

function U.OnNewFontString(fn)
    if type(fn) ~= "function" then return false end
    onFont[#onFont + 1] = fn
    for _, kind in ipairs(FONT_KINDS) do
        local t = U.WidgetMethods(kind)      -- never a new EditBox: it would take the keyboard
        if t and not fontHooked[t] and type(t.CreateFontString) == "function" then
            if pcall(hooksecurefunc, t, "CreateFontString", RunFont) then fontHooked[t] = true end
        end
    end
    return true
end
