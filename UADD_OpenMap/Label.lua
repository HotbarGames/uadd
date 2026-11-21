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
--   * ClassicUA hooks the same Name text on Forever and writes its word over OpenMap's line ("<зона>|cff..(1-10)|r")
--     on every SetText, also while the hold key is held (it does not know our key). With the key held, ours puts
--     OpenMap's English back over it (Over, English); otherwise its whole Ukrainian line stays. Off: left alone.
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
local last = {}       -- FontString -> OpenMap's last zone line with levels set on it (English), else nil
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

-- true when t is another addon's Ukrainian over OpenMap's zone line en: Cyrillic, then en's own colour-code tail
-- as it was. ClassicUA's world-map hook (its frame_hooks.lua, hook_forever_zone_text) writes "<зона>|cff..(30-45)|r"
-- over it on every SetText, and it does not know the hold key.
local function Over(t, en)
    local tail = en and en:match("^.-(|c.*)$")
    if not tail or #t <= #tail or t:sub(-#tail) ~= tail then return false end
    return t:sub(1, #t - #tail):find(CYR) ~= nil
end

local through = false   -- up while we set OpenMap's English through the other hooks
-- The hold key: OpenMap's English back on fs. Once through the other addons' hooks (unguarded), so that when
-- theirs writes its Ukrainian over it again, ours (OnText) puts the English back inside their call, where their
-- own flag keeps them out; inside that, or when a text still shows theirs after, set straight (Put).
local function English(fs, en)
    if through then return Put(fs, en) end
    through = true
    local ok, err = pcall(fs.SetText, fs, en)
    through = false
    if not ok then error(err, 0) end
    if U.Plain(fs:GetText()) ~= en then Put(fs, en) end
end

local function OnText(fs, text)
    if guard then return end
    shown[fs] = nil
    local set = U.Plain(text)
    if set and not set:find(CYR) then last[fs] = set:match(NAME) and set or nil end   -- OpenMap's own text
    if not ns.On() or (InCombatLockdown and InCombatLockdown()) then return end
    local now = U.Plain(fs:GetText())   -- nil for a secret text: left as it is
    if not now then return end
    if U.originalShown then
        if last[fs] and now ~= last[fs] and Over(now, last[fs]) then English(fs, last[fs]) end
        return
    end
    local uk = B.Text(now)
    if not uk then return end
    Put(fs, uk)
    shown[fs] = { en = now, uk = uk }
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
                    hooksecurefunc(fs, "SetText", function(self, text) U.SafeCall(OnText, self, text) end)
                end
                U.SafeCall(OnText, fs, fs:GetText())
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
    -- the hold key: OpenMap's English also where another addon's Ukrainian is over it (ClassicUA). Off: left
    -- as it is, as without UADD.
    if not ns.On() or not U.originalShown then return end
    local todo = {}
    for fs, en in pairs(last) do todo[fs] = en end
    for fs, en in pairs(todo) do
        local now = U.Plain(fs:GetText())
        if now and now ~= en and Over(now, en) then U.SafeCall(English, fs, en) end
    end
end

-- For the checks: how many label texts show our words now.
function B.Count()
    local n = 0
    for fs, t in pairs(shown) do if U.Plain(fs:GetText()) == t.uk then n = n + 1 end end
    return n
end
