-- The World Map's hover label, where OpenMap writes its own parts into it.
--   * OpenMap takes over the label's OnUpdate (its Map/Extras.lua) and, with its zone levels on,
--     writes the zone's name with its level range in colour ("<zone> |cffRRGGBB(1-10)|r") and,
--     under it, the zone's fishing skill ("|cffRRGGBBFishing 25|r"). These lines are OpenMap's,
--     so they are ours to translate, each one whole: «<зона> (1-10)», «Риболовля 25».
--   * A plain name (no part of OpenMap's) is the game's: UALL Forever translates it (its
--     MapHooks.lua), and we leave it alone.
--   * The zone's word is UALL Forever's own (UADD.UALL.Zone, asked at run time: the same word its
--     plain labels show), else a name other modules saved (Parts.lua P.Dungeon). A zone with
--     neither leaves the whole line English.
--   * Both texts are set every frame the cursor is on the map, so a SetText hook (hooksecurefunc,
--     once) puts our line in each time; with the hold key or "/uadd openmap off" the next frame shows
--     OpenMap's English, and Sync puts it back at once. Nothing is changed in combat.
-- This is the one World Map text we touch: Screen.lua leaves the rest of the map alone.

local _, ns = ...
local U = UADD
local B = {}
ns.Label = B

local G = U.Glossary and U.Glossary.Text or function() return nil end
local P = ns.Parts
local CYR = "[\208\209]"
local C = "|c%x%x%x%x%x%x%x%x"
local NAME = "^(.-) (" .. C .. "%(%d+%-?%d*%)|r)$"   -- the zone, then OpenMap's level range
local FISH = "^(" .. C .. ")Fishing (%d+)|r$"          -- OpenMap's fishing line

local hooked = {}     -- FontString -> true once its SetText is hooked
local shown = {}      -- FontString -> { en = OpenMap's text, uk = ours } while it shows ours
local guard = false   -- up while we set a text ourselves
local installed = false

local function Zone(en)
    local uk = U.UALL and U.UALL.Zone and U.UALL.Zone(en)
    if type(uk) == "string" and uk:find(CYR) then return uk end
    return P.Dungeon(en)
end

-- One of OpenMap's label lines in Ukrainian, whole, or nil (not OpenMap's, or no word for a part).
function B.Text(t)
    if type(t) ~= "string" or t == "" or t:find(CYR) then return nil end
    local name, range = t:match(NAME)
    if name and name ~= "" then
        local uk = Zone(name)
        return uk and (uk .. " " .. range) or nil
    end
    local code, n = t:match(FISH)
    local word = code and G("prof.fishing")
    return word and (code .. word .. " " .. n .. "|r") or nil
end

local function Put(fs, text)
    guard = true
    local ok, err = pcall(fs.SetText, fs, text)
    guard = false
    if not ok then error(err, 0) end
end

local function OnText(fs)
    if guard then return end
    shown[fs] = nil
    if not ns.WordsWanted() or (InCombatLockdown and InCombatLockdown()) then return end
    local en = U.Plain(fs:GetText())   -- nil for a secret text: left as it is
    local uk = en and B.Text(en)
    if not uk then return end
    Put(fs, uk)
    shown[fs] = { en = en, uk = uk }
    U.SafeCall(ns.Fonts.Fix, fs)   -- the label's font may have no Ukrainian letters
end

-- The label of the World Map's area label provider (the one OpenMap takes over), hooked once.
function B.Install()
    if installed then return end
    local map = rawget(_G, "WorldMapFrame")
    if type(map) ~= "table" then return end
    if not hooked[map] and map.HookScript then
        hooked[map] = true
        map:HookScript("OnShow", function() U.SafeCall(B.Install) end)   -- providers added later
    end
    for provider in pairs(type(map.dataProviders) == "table" and map.dataProviders or {}) do
        local label = type(provider) == "table" and provider.Label
        if type(label) == "table" and label.Name and label.Description then
            installed = true
            for _, fs in ipairs({ label.Name, label.Description }) do
                if not hooked[fs] then
                    hooked[fs] = true
                    hooksecurefunc(fs, "SetText", function(self) U.SafeCall(OnText, self) end)
                end
                U.SafeCall(OnText, fs)
            end
            return
        end
    end
end

-- As it should be now (hold key, "on", "off"): OpenMap's English back on the texts showing ours.
function B.Sync()
    if ns.WordsWanted() then return end
    for fs, t in pairs(shown) do
        if U.Plain(fs:GetText()) == t.uk then Put(fs, t.en) end
        shown[fs] = nil
    end
end

-- For the checks: how many label texts show our words now.
function B.Count()
    local n = 0
    for fs, t in pairs(shown) do if U.Plain(fs:GetText()) == t.uk then n = n + 1 end end
    return n
end
