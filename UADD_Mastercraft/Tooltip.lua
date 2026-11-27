-- UADD - Mastercraft: our words on the tooltip lines Mastercraft adds (its own tooltips and the lines it
-- adds to item tooltips), each line whole, the same way as on screen (Words.lua).
--   * Post-hooks on AddLine, AddDoubleLine and SetText of the game's tooltips. A line changes only when
--     we have Ukrainian for it and the call came from Mastercraft's own code (debugstack, looked at
--     only then), so a line of the game or another addon that reads the same stays as it is.
--   * That line gets UADD's Cyrillic font at its size; the tooltip's own font object comes back when
--     the tooltip is cleared (U.FontBack: never a pinned file, docs/LESSONS2.md lesson 18).
--   * Off or the hold key: new lines stay English (a tooltip already shown changes when shown again).

local _, ns = ...
local U = UADD
local W = ns.Words
local P = ns.Split
local T = {}
ns.Tooltip = T

local CYR = "[\208-\210]"
-- LibDBIconTooltip: the minimap button's tooltip (LibDBIcon makes it when it loads, before us).
local TIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "LibDBIconTooltip" }
local changed = {}            -- tooltip -> { [fontString] = its font before ours (U.SaveFont) }
local said = setmetatable({}, { __mode = "k" })   -- line -> the Ukrainian we put on it
local hookedTip = {}
local count = 0

local function FromMastercraft()
    local ok, st = pcall(debugstack, 2, 12, 0)
    if not ok or type(st) ~= "string" then return false end
    return st:find("AddOns[/\\]Mastercraft[/\\]") ~= nil
end

local function Line(tip, side, i)
    local name = tip.GetName and tip:GetName()
    return name and _G[name .. "Text" .. side .. i] or nil
end

local function Put(tip, fs, uk)
    if not fs or not U.Plain(uk) then return end
    if not uk:find(CYR) then fs:SetText(uk) return end
    -- A game line: UADD's Cyrillic font OBJECT, never a file by hand (it pins the line, lesson 18). Saved before
    -- ours goes on, read back (lesson 2); no Cyrillic font or no take: the line stays English (no boxes).
    -- A line that keeps a file set by hand over any object gets ours by hand (U.CyrOnOwn, lesson 44).
    changed[tip] = changed[tip] or {}
    local was = changed[tip][fs] or U.SaveFont(fs)
    if not U.IsCyrFont((fs:GetFont())) and not U.CyrOnLocked(fs) and not U.CyrOnOwn(fs, was) then
        if not changed[tip][fs] then pcall(U.FontBack, fs, was) end
        return
    end
    changed[tip][fs] = was
    fs:SetText(uk)
    said[fs] = uk
    count = count + 1
    return true
end

-- One side of a row that must stay whole English: while it still shows the Ukrainian we put, its English goes
-- back first, then its own font (lesson 45).
local function Back(tip, fs, uk, en)
    if not fs then return end
    local ok, t = pcall(fs.GetText, fs)
    if not ok or t ~= uk then return end
    pcall(fs.SetText, fs, en or "")
    local list = changed[tip]
    if list and list[fs] then U.CyrUnfix(fs, list) end
    if not (list and list[fs]) then said[fs] = nil end
end

-- Could s be one of Mastercraft's texts? Every line of every game tooltip passes here, so this cheap test
-- comes first (docs/LESSONS2.md lesson 12): no slot is filled, nothing is cached. It follows the shapes
-- W.Translate knows (Words.lua, steps 1-10); false means Translate(s) would surely give nothing.
-- No pattern with two lazy runs here (Split.lua: by plain find, docs/LESSONS2.md lesson 22).
local DOT = " \194\183 "
local function Maybe(s, d)
    if type(s) ~= "string" or s == "" or d > 6 or not s:find("%a") then return false end
    local ix = W.Index()
    if ix:Exact(s) or ix:Match(s, 0) then return true end
    if s:find("\n", 1, true) then
        for line in s:gmatch("[^\n]+") do if Maybe(line, d + 1) then return true end end
        return false
    end
    local _, body = P.Trim(s)
    if body ~= s then return Maybe(body, d + 1) end
    local inner = s:match("^|c%x%x%x%x%x%x%x%x(.*)|r$")
    if inner and Maybe(inner, d + 1) then return true end
    local rest = s:match("^|T.-|t%s*(.+)$")
    if rest and Maybe(rest, d + 1) then return true end
    local head = s:match("^(.-%S) %d+%%$")
    if head and Maybe(head, d + 1) then return true end
    if s:find(DOT, 1, true) then
        for part in (s .. DOT):gmatch("(.-)" .. DOT) do if Maybe(part, d + 1) then return true end end
    end
    local text = s:match("^(.-%S) |c%x%x%x%x%x%x%x%x%d+|r$")
    if text and Maybe(text, d + 1) then return true end
    if ns.Rows.Could(s) then return true end
    local words = P.Quoted(s)
    return words ~= nil and Maybe(words, d + 1)
end
T.Maybe = function(s) return Maybe(s, 0) end

-- A game name through one UADD.UALL route (lesson 20; ClassicUA first, lesson 25: no [ ( | or edge spaces
-- asked): the Ukrainian, or nil and whether the source said "not now".
local function Ask(en, route)
    if en == "" or en:find("[|%[%(\n]") or en:find("^%s") or en:find("%s$") then return nil, false end
    local A = U.UALL
    local look = type(A) == "table" and A[route]
    if type(look) ~= "function" then return nil, false end
    local ok, ua, wait = pcall(look, en)
    if ok and type(ua) == "string" and ua ~= en and ua:find(CYR) then return ua end
    return nil, ok and wait and true or false
end

-- Its pickpocket source row: the label is a spell, a game name (lesson 9: the Spell route only); the right side
-- is "<NPC> <percent>", the NPC through the Npc route. nil for any other label; both sides; or false and whether
-- a source said "not now". Never one side alone (lesson 6), never kept: a wait is asked again on the next fill.
-- One table look first: every line of every tooltip passes here.
local SPELL_ROW = { ["Pick Pocket"] = true }
local function SpellRow(label, text)
    if not SPELL_ROW[label] then return nil end
    if type(text) ~= "string" or text == "" then return nil end    -- the label alone: the words, as any line
    if #text > 120 then return false, false end
    local l, wait = Ask(label, "Spell")
    if not l then return false, wait end
    local who, pct = text:match("^(.-%S)( [%d%.]+%%)$")    -- one lazy run, anchored at both ends
    if not who then who, pct = text, "" end
    local r
    r, wait = Ask(who, "Npc")
    if not r then return false, wait end
    return l, r .. pct
end

-- The line just added: each side alone; nothing unless both checks pass. Cheapest first: could it be
-- Mastercraft's at all, then our words, then the stack (only for a line we have Ukrainian for).
local function Redo(tip, left, right)
    if not ns.WordsWanted() then return end
    left, right = U.Plain(left), U.Plain(right)     -- nil for a secret text: left as it is
    local missed = left and U.MissedOn() and left:find("%a%a%a")
    -- its pickpocket source row (a spell for a label): both sides, or the whole row English (Words.lua)
    local sl, sr = SpellRow(left, right)
    if sl ~= nil then
        if sl and FromMastercraft() then
            -- both sides take our font, or neither: a side that did not (or a throw) gives the left its English
            local i = tip:NumLines()
            local lf, rf = Line(tip, "Left", i), Line(tip, "Right", i)
            local ok, both = pcall(function() return Put(tip, lf, sl) and Put(tip, rf, sr) end)
            if not (ok and both) then
                Back(tip, lf, sl, left)
                Back(tip, rf, sr, right)
                if not ok then error(both, 0) end     -- counted by U.SafeCall, as before
            end
        elseif not sl and not sr and missed and FromMastercraft() then
            U.Missed("mastercraft", left)       -- not on a "wait": it may be ours on the next fill
        end
        return
    end
    local maybeL, maybeR = left and Maybe(left, 0), right and Maybe(right, 0)
    if not missed and not maybeL and not maybeR then return end
    local l = maybeL and W.Translate(left) or nil
    local r = maybeR and W.Translate(right) or nil
    if not l and not r then
        -- the stack walk only while /uadd missed is on
        if missed and FromMastercraft() then U.Missed("mastercraft", left) end
        return
    end
    if not FromMastercraft() then return end
    local i = tip:NumLines()
    if l then Put(tip, Line(tip, "Left", i), l) end
    if r then Put(tip, Line(tip, "Right", i), r) end
end

-- Its font object back (U.CyrUnfix: never a pinned file, lesson 18). The font follows the text: FontBack keeps
-- ours on a shown line that still shows Cyrillic, and then the record stays until ours is off. how:
-- "clear": the tooltip was cleared, so no line of it is drawn (the client hides them): a line that still holds
-- our words is emptied first, and its object goes back whether the line is hidden yet or not.
-- "add": a line added to the tooltip (filled again): a kept line that shows no Cyrillic now gets its own back.
-- "off": every line; one that still shows our Ukrainian keeps ours until it is cleared or shows English.
local function Settle(tip, how)
    local list = changed[tip]
    if not list then return end
    for fs in pairs(list) do
        local ok, t = pcall(fs.GetText, fs)
        t = ok and U.Plain(t) or nil
        if how == "clear" and t ~= nil and t == said[fs] then pcall(fs.SetText, fs, "") t = "" end
        if how ~= "add" or not (t and t:find(CYR)) then U.CyrUnfix(fs, list) end
        if not list[fs] then said[fs] = nil end
    end
    if next(list) == nil then changed[tip] = nil end
end

-- A kept line (above) first, also with our words off: one table look for the game's other lines.
local function Add(self, a, b)
    if changed[self] then U.SafeCall(Settle, self, "add") end
    U.SafeCall(Redo, self, a, b)
end

local function HookTip(tip)
    if type(tip) ~= "table" or hookedTip[tip] or not tip.AddLine then return end
    hookedTip[tip] = true
    hooksecurefunc(tip, "AddLine", function(self, text) Add(self, text) end)
    hooksecurefunc(tip, "AddDoubleLine", function(self, a, b) Add(self, a, b) end)
    hooksecurefunc(tip, "SetText", function(self, text) Add(self, text) end)
    if tip.HookScript then tip:HookScript("OnTooltipCleared", function(self) U.SafeCall(Settle, self, "clear") end) end
end

function T.Install()
    for _, name in ipairs(TIPS) do HookTip(rawget(_G, name)) end
end

function T.Restore()
    for tip in pairs(changed) do Settle(tip, "off") end
end

function T.Count() return count end
