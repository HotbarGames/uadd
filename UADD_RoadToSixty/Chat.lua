-- UADD - Road to Sixty: its prints, its tooltip lines and its three popups, each through a core helper.
--   * Prints: the shared print handler (U.PrintHook, UADD/Print.lua; off in an instance, lesson 35). A print of one
--     text that starts with Road to Sixty's coloured prefix: the prefix stays, the rest is ours when it is a whole
--     text of ours; else the line is left as it is. Its level-up chat line (its own prefix and the link it sends)
--     is never touched: only prints with the addon's print prefix are read, and a link payload is never written.
--   * Tooltips: U.TipLines on GameTooltip. A line of the game is tried only when its whole text is a key of ours
--     (Words.Maybe, a hash: lesson 12), and only when Road to Sixty's files wrote it (the stack).
--   * Popups: U.Popups for its three dialogs (the text and both buttons); the dialog's fields go back to its
--     English off and on the hold key, only where ours still shows.
-- Any error leaves the English as it was.

local _, ns = ...
local U = UADD
local sub = string.sub

local C = {}
ns.Chat = C

local KEY = "rts"
local PREFIX = "|cff33ff99RoadToSixty|r: "
local FROM = "AddOns[/\\]RoadToSixty[/\\]"
local POPUPS = { ROADTOSIXTY_RESET = true, ROADTOSIXTY_DELETE_CHARACTER = true, ROADTOSIXTY_REMOVE_FRIEND = true }

local W = ns.Words

-- ── Prints ───────────────────────────────────────────────────────────────────────────────────

-- Its prints start with its name in colour, written two ways: in one word (most files) and with spaces (the
-- level-up summary). The prefix stays as it is; the rest must be one whole text of ours. A link in the rest is
-- kept byte for byte: a link whose text has no Ukrainian keeps the whole line English (no half lines).
local SPACED = "|cff33ff99Road to Sixty|r: "
local PREFIXES = { PREFIX, SPACED }
local function Line(text)
    local s = U.Plain(text)                      -- first, before any string op (lesson 35)
    if not s or not ns.WordsWanted() then return nil end
    for i = 1, #PREFIXES do
        local p = PREFIXES[i]
        if #s > #p and sub(s, 1, #p) == p then
            local uk = W.Translate(sub(s, #p + 1))
            return uk and (p .. uk) or nil
        end
    end
    return nil
end
local prints = U.PrintHook({ line = Line })

-- ── Tooltips ─────────────────────────────────────────────────────────────────────────────────

local tips = U.TipLines({ tips = { "GameTooltip" }, from = FROM, words = W, wanted = function() return ns.WordsWanted() end, missed = KEY })

-- ── Popups ───────────────────────────────────────────────────────────────────────────────────

local back, nback = {}, 0                       -- ours -> the English it came from (so a shown popup flips back)
local function PopText(en)
    local s = U.Plain(en)
    if not s then return nil end
    local uk = W.Field(s) or W.Translate(s)
    if uk then
        if nback >= 50 then back, nback = {}, 0 end
        if back[uk] == nil then nback = nback + 1 end
        back[uk] = s
    end
    return uk
end
local function PopEnglish(uk)
    local s = U.Plain(uk)
    return s and back[s] or nil
end

local saved = setmetatable({}, { __mode = "k" })
local function Fix(fs)
    if type(fs) ~= "table" then return end
    local ok, path = pcall(fs.GetFont, fs)
    if ok and U.IsCyrFont(path) then return end
    if not saved[fs] then
        local okS, was = pcall(U.SaveFont, fs)
        if okS and type(was) == "table" then saved[fs] = was end
    end
    pcall(U.CyrOnLocked, fs)
end
local function Back(fs)
    local was = type(fs) == "table" and saved[fs]
    if not was then return end
    saved[fs] = nil
    pcall(U.FontBack, fs, was)
end

local popupsOk = type(U.Popups) == "table" and type(U.Popups.Register) == "function"
if popupsOk then
    U.Popups.Register(KEY, {
        names = POPUPS, text = PopText, english = PopEnglish, wanted = function() return ns.WordsWanted() end,
        fix = Fix, back = Back,
    })
end

-- ── On, off, the hold key ────────────────────────────────────────────────────────────────────

function C.Install()
    if not ns.On() then return end
    U.SafeCall(prints.Start)
    U.SafeCall(tips.Install)
    if popupsOk then U.SafeCall(U.Popups.Sync, KEY) end
end
function C.Sync()
    if popupsOk then U.SafeCall(U.Popups.Sync, KEY) end
end
function C.Remove()
    U.SafeCall(prints.Stop)
    U.SafeCall(tips.Restore)
    if popupsOk then U.SafeCall(U.Popups.Off, KEY) end
    back, nback = {}, 0
end

function C.Prints() return prints.Count() end
function C.Tips() return tips.Count() end
function C.Popups() return popupsOk and type(U.Popups.Count) == "function" and U.Popups.Count(KEY) or 0 end
C.Line, C.PopText, C.PopEnglish = Line, PopText, PopEnglish     -- for the checks
