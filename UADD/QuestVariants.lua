-- Quest titles that UALL Forever spells a little differently from QuestieDB.
--
-- When the exact title is not in UALLF, ask UALLF again with a few spelling variants
-- (docs/research-quest-variants.md has the numbers):
--   * runs of spaces as one space        "One Shot.  One Kill."      -> "One Shot. One Kill."
--   * small words in lower case          "Your Place In The World"   -> "Your Place in the World"
--   * a plural "s'" without the "'"      "Smokywood Pastures' Thank" -> "Smokywood Pastures Thank"
--   * the leading word and its mark      "WANTED: Arnak Grimtotem"   -> "Wanted - Arnak Grimtotem"
-- The Ukrainian always comes from UALLF; we never write a translation ourselves.
-- A variant is not used when the item or NPC route also knows it (it may not be a quest title).
-- Answers that differ only in letter case, marks, quote style or spaces are the same translation:
-- we take the one whose English is closest to ours. Answers that differ in words: no answer.
local U = UADD.UALL
local exact = U.Quest
local uallfRoutes = { U.Item, U.Npc }   -- UALLF's own, taken before uall_cua.lua puts ClassicUA first

U.RULES = 3   -- version of these lookup rules; part of the saved-cache signature (Names.lua)

local SMALL = {}
for w in ("a an and as at but by for from in into of on or the to with"):gmatch("%a+") do SMALL[w] = true end
local MARKS = { ":", " -", "!" }

function U.QuestVariants(en)
    local out, seen = {}, { [en] = true }
    local function add(v)
        if not seen[v] then seen[v] = true; out[#out + 1] = v end
    end
    add((en:gsub("  +", " ")))
    local first = true
    add((en:gsub("%S+", function(w)
        if first then first = false return nil end
        if SMALL[w:lower()] then return w:lower() end
    end)))
    add((en:gsub("s' ", "s ")))
    local word, rest = en:match("^(%a+): +(.+)$")
    if not word then word, rest = en:match("^(%a+)! +(.+)$") end
    if not word then word, rest = en:match("^(%a+) %- +(.+)$") end
    if word then
        word = word:sub(1, 1):upper() .. word:sub(2):lower()
        for _, mark in ipairs(MARKS) do
            add(word .. mark .. " " .. rest)
            add(word .. mark .. "  " .. rest)
        end
    end
    return out
end

-- Ukrainian without letter case, marks, quote style, dash type or extra spaces.
local WIDE = { "\194\171", "\194\187", "\226\128\147", "\226\128\148", "\226\128\152", "\226\128\153",
    "\226\128\156", "\226\128\157", "\226\128\158", "\226\128\166", "\202\188" }   -- « » – — ‘ ’ “ ” „ … ʼ
function U.SameMeaning(s)
    s = s:gsub("\208([\144-\159])", function(b) return "\208" .. string.char(b:byte() + 32) end)
    s = s:gsub("\208([\160-\175])", function(b) return "\209" .. string.char(b:byte() - 32) end)
    s = s:gsub("\208([\128-\143])", function(b) return "\209" .. string.char(b:byte() + 16) end)
    s = s:gsub("\210\144", "\210\145"):lower()
    for _, w in ipairs(WIDE) do s = s:gsub(w, " ") end
    return (s:gsub("%p", " "):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
end

-- How far a variant's English is from ours: 1 letter case only, 2 marks too, 3 spaces only, 4 more.
local function Distance(en, v)
    local function marks(s) return (s:lower():gsub("[:!%-]", " "):gsub("%s+", " ")) end
    if v:lower() == en:lower() then return 1 end
    if marks(v) == marks(en) and v:gsub("%s+", " ") ~= en:gsub("%s+", " ") then return 2 end
    if v:gsub("%s+", " ") == en:gsub("%s+", " ") then return 3 end
    return 4
end

-- "Not now" for every route alike: UALLF off or not loaded, combat, before login, its key held.
-- UALLFSettingsDB is UALLF's saved settings, a global; we only read it.
local function NotNow()
    if not U.UallfAvailable() or (InCombatLockdown and InCombatLockdown()) then return true end
    if IsLoggedIn and not IsLoggedIn() then return true end
    local s = type(_G.UALLFSettingsDB) == "table" and _G.UALLFSettingsDB or {}
    if s.reverseOriginal then return false end
    local key = s.originalKey or "SHIFT"
    return (key == "SHIFT" and IsShiftKeyDown and IsShiftKeyDown())
        or (key == "CTRL" and IsControlKeyDown and IsControlKeyDown())
        or (key == "ALT" and IsAltKeyDown and IsAltKeyDown()) or false
end

-- Does the item or NPC route know this text (or can we not rule it out)? Second value: not now.
-- A route that is switched off in UALLF, or does not answer (its window busy, its test names
-- not translated), cannot clear the variant, so we do not use it. We do not wait for that route:
-- it may stay off for good, and the quest just keeps its English title.
local function Elsewhere(text)
    for _, fn in ipairs(uallfRoutes) do
        local ua, wait = fn(text)
        if ua then return true end
        if wait then
            if NotNow() then return false, true end
            return true
        end
    end
    return false
end

local function ByVariants(questId, englishTitle)
    local en = type(englishTitle) == "string" and englishTitle ~= "" and englishTitle or nil
    if not en and type(questId) == "number" and C_QuestLog and C_QuestLog.GetTitleForQuestID then
        en = UADD.Plain(C_QuestLog.GetTitleForQuestID(questId))
    end
    if type(en) ~= "string" or en == "" then return nil end
    local best, bestDistance, meaning
    for _, v in ipairs(U.QuestVariants(en)) do
        local hit, wait = exact(nil, v)
        if wait then return nil, true end
        if hit then
            local other, later = Elsewhere(v)
            if later then return nil, true end
            if not other then
                local m = U.SameMeaning(hit)
                if meaning and meaning ~= m then return nil end
                meaning = m
                local d = Distance(en, v)
                if not best or d < bestDistance then best, bestDistance = hit, d end
            end
        end
    end
    return best
end

-- Same as before for titles UALLF knows; variants only when the exact title misses.
function U.Quest(questId, englishTitle)
    local ua, wait = exact(questId, englishTitle)
    if ua or wait then return ua, wait end
    local ok, out, later = pcall(ByVariants, questId, englishTitle)
    return ok and out or nil, ok and later or nil
end
