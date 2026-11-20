-- Game names on Auto Potion's pages, from UALL Forever (docs/LESSONS.md, lesson 9: game names are its, never ours).
--   * The Heal and Mana pages group their spell boxes under a header per class: the game's own class name
--     (LOCALIZED_CLASS_NAMES_MALE). The header gets UALL Forever's word for it (UADD.UALL.Class).
--   * A check box's label that is not one of Auto Potion's own texts is a spell or item name from the game
--     (a class spell, a mana spell, a potion): UALL Forever's spell name
--     (UADD.UALL.Spell), else its item name (UADD.UALL.Item).
--   * A name it lacks stays English, whole. "Not now": asked again the next time the page shows. Each
--     answer is kept, so a page shown again costs no lookup and makes no garbage (the miss path).
--   * Texts.lua keeps the English and puts it back on the hold key and "/uadd autopotion off".

local _, ns = ...
local U = UADD
local G = {}
ns.Game = G

local CYR = "[\208-\210]"
local classes   -- English class name -> true, built once from the game's table
local said = {}  -- route -> { English -> its Ukrainian, or false }: UALL Forever's answer, asked once (no garbage after)
local wait = { Class = {}, Spell = {}, Item = {} }  -- route -> { English -> when to ask again after "not now" or an error }
local AGAIN = 1  -- seconds

local function Now() return type(GetTime) == "function" and GetTime() or 0 end

-- "Not now" or an error gives nil and is asked again a second later (not on every show: a miss makes no
-- garbage); an error never leaves a text half done.
local function Uk(route, en)
    local memo = said[route]
    if memo and memo[en] ~= nil then return memo[en] or nil end
    local w = wait[route]
    if not w then return nil end
    if w[en] and Now() < w[en] then return nil end
    local A = U.UALL
    local fn = type(A) == "table" and A[route]
    if type(fn) ~= "function" then return nil end
    local ok, uk, later = pcall(fn, en)
    if not ok or later then w[en] = Now() + AGAIN return nil end
    w[en] = nil
    uk = type(uk) == "string" and uk:find(CYR) and uk or false
    memo = memo or {}
    said[route], memo[en] = memo, uk
    return uk or nil
end

local function Class(en)
    if not classes then
        local t = rawget(_G, "LOCALIZED_CLASS_NAMES_MALE")
        if type(t) ~= "table" then return false end
        classes = {}
        for _, v in pairs(t) do if type(v) == "string" then classes[v] = true end end
    end
    return classes[en] == true
end

-- UALL Forever's Ukrainian for the game name FontString fs shows (English en), or nil.
function G.Text(fs, en)
    if type(en) ~= "string" or en == "" or en:find(CYR) then return nil end
    local p = fs.GetParent and fs:GetParent()
    if p and p.GetObjectType and p:GetObjectType() == "CheckButton" then
        return Uk("Spell", en) or Uk("Item", en)
    end
    if Class(en) then return Uk("Class", en) end
    return nil
end
