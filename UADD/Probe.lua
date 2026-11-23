-- Font probe: once per session the real client tells us how its fonts behave, so the offline harness can
-- be checked against it (tools/test_client_facts.py, tools/harness/client_facts.py). The harness once
-- modelled SetFontObject wrong: it dropped a file set by hand, the client keeps it (lesson 44), and boxes
-- reached the item tooltips.
-- Safe by design: only FontStrings of our own hidden frame and our own font object (UADD_ProbeFont); never
-- a game frame, never an EditBox, never a setter on a shared font object (GameTooltipText is only read and
-- put on our own FontStrings). Runs a little after login, never in combat. Each fact is read under pcall:
-- an error leaves that fact nil and says nothing. Saved: UADD_DB.health.probe = { facts..., build, at }.

local U = UADD
local LATIN = "Fonts\\ARIALN.TTF"          -- a Latin file other than the tooltip's own
local FRIZ = "Fonts\\FRIZQT__.TTF"          -- the file GetFont reports for GameTooltipText
local MISSING = "Fonts\\UADD_NO_SUCH.TTF"   -- a file the client does not have
local SAMPLE = "Привіт"
local done, holder, own = false, nil, nil

local function Norm(p) return type(p) == "string" and (p:gsub("/", "\\"):lower()) or nil end
local function IsLatin(p) return Norm(p) == Norm(LATIN) end

-- What a call gave back, as text: "none" (nothing at all) or tostring of the first value.
local function Ret(...)
    if select("#", ...) == 0 then return "none" end
    return tostring((...))
end

-- A fresh FontString on our own hidden frame.
local function Fresh()
    if not holder then holder = CreateFrame("Frame") holder:Hide() end
    return holder:CreateFontString(nil, "BACKGROUND")
end

-- The one place a file is set by hand on a FontString; gives back what SetFont returned (Ret).
local function Pin(fs, path) return Ret(fs:SetFont(path, 12, "")) end

-- A FontString on GameTooltipText with LATIN set by hand, then `after(fs)`: is LATIN still its file?
local function Kept(after)
    local fs = Fresh()
    fs:SetFontObject(GameTooltipText)
    Pin(fs, LATIN)
    after(fs)
    return IsLatin((fs:GetFont()))
end

-- Width of SAMPLE on GameTooltipText, or with `path` set by hand; one decimal.
local function Width(path, obj)
    local fs = Fresh()
    fs:SetFontObject(obj or GameTooltipText)
    if path then Pin(fs, path) end
    fs:SetText(SAMPLE)
    local w = fs:GetStringWidth()
    fs:SetText("")
    return type(w) == "number" and math.floor(w * 10 + 0.5) / 10 or nil
end

local FACTS = {
    -- true: the client keeps a hand-set file over SetFontObject (lesson 44).
    keepsFileOverObject = function() return Kept(function(fs) fs:SetFontObject(GameTooltipText) end) end,
    otherThenBackKeepsFile = function()
        return Kept(function(fs) fs:SetFontObject(GameTooltipHeaderText) fs:SetFontObject(GameTooltipText) end)
    end,
    nilKeepsFile = function() return Kept(function(fs) fs:SetFontObject(nil) end) end,
    nilClearsObject = function()
        local fs = Fresh()
        fs:SetFontObject(GameTooltipText)
        fs:SetFontObject(nil)
        return fs:GetFontObject() == nil
    end,
    -- What GetFont reports for the font family (we believe FRIZQT__.TTF, a Latin file).
    objectPath = function() return Norm((GameTooltipText:GetFont())) end,
    objectReportsLatin = function()
        local p = GameTooltipText:GetFont()
        return type(p) == "string" and not U.IsCyrFont(p)
    end,
    fsPath = function()
        local fs = Fresh()
        fs:SetFontObject(GameTooltipText)
        return Norm((fs:GetFont()))
    end,
    fsReportsLatin = function()
        local fs = Fresh()
        fs:SetFontObject(GameTooltipText)
        local p = fs:GetFont()
        return type(p) == "string" and not U.IsCyrFont(p)
    end,
    -- What SetFont gives back (lesson 2: a font object gives nothing; a FontString?).
    setFontReturnsFS = function() return Pin(Fresh(), LATIN) end,
    setFontReturnsMissing = function() return Pin(Fresh(), MISSING) end,
    setFontReturnsObject = function()
        own = own or CreateFont("UADD_ProbeFont")
        return Ret(own:SetFont(LATIN, 12, ""))
    end,
    -- Widths of a short Ukrainian word: does width tell boxes (Latin file) from letters?
    widthObject = function() return Width(nil) end,
    widthFriz = function() return Width(FRIZ) end,
    widthCyr = function() local p = U.CyrFontPath() return p and Width(p) or nil end,
    -- GameFontNormal: like widthFriz (boxes) or like widthCyr (letters)? Lesson 32 says boxes.
    widthNormal = function() return Width(nil, GameFontNormal) end,
    -- An addon's CreateFontFamily (ForeverDungeonJournal's fonts) has a Cyrillic member here.
    hasFontFamily = function() return type(CreateFontFamily) == "function" end,
}

local SCALAR = { boolean = true, number = true, string = true }

local function Measure()
    local out = {}
    for name, fn in pairs(FACTS) do
        local ok, v = pcall(fn)
        if ok and SCALAR[type(v)] then out[name] = v end
    end
    local okB, build = pcall(function() return (select(4, GetBuildInfo())) end)
    out.build = okB and build or nil
    out.at = time()
    local db = U.DB()
    if type(db.health) ~= "table" then db.health = {} end
    db.health.probe = out
end

local ev = CreateFrame("Frame")

local function Run()
    if done then return end
    if InCombatLockdown and InCombatLockdown() then
        ev:RegisterEvent("PLAYER_REGEN_ENABLED")      -- wait for the fight to end
        return
    end
    done = true
    pcall(Measure)
end

ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_ENABLED" then pcall(self.UnregisterEvent, self, event) end
    pcall(C_Timer.After, event == "PLAYER_LOGIN" and 5 or 1, function() pcall(Run) end)
end)
