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
local T = {}
ns.Tooltip = T

local CYR = "[\208-\210]"
-- LibDBIconTooltip: the minimap button's tooltip (LibDBIcon makes it when it loads, before us).
local TIPS = { "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "LibDBIconTooltip" }
local changed = {}            -- tooltip -> { [fontString] = its font before ours (U.SaveFont) }
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
    -- No Cyrillic font: the line stays English (no boxes).
    local path = U.CyrFontPath()
    local _, s, f = fs:GetFont()
    if not path or not s then return end
    fs:SetText(uk)
    changed[tip] = changed[tip] or {}
    if not changed[tip][fs] then changed[tip][fs] = U.SaveFont(fs) end
    fs:SetFont(path, s, f or "")
    count = count + 1
end

-- Could s be one of Mastercraft's texts? Every line of every game tooltip passes here, so this cheap test
-- comes first (docs/LESSONS2.md lesson 12): no slot is filled, nothing is cached. It follows the shapes
-- W.Translate knows (Words.lua, steps 1-10); false means Translate(s) would surely give nothing.
local DOT = " \194\183 "
local function Maybe(s, d)
    if type(s) ~= "string" or s == "" or d > 6 or not s:find("%a") then return false end
    local ix = W.Index()
    if ix:Exact(s) or ix:Match(s, 0) then return true end
    if s:find("\n", 1, true) then
        for line in s:gmatch("[^\n]+") do if Maybe(line, d + 1) then return true end end
        return false
    end
    local body = s:match("^%s*(.-)%s*$")
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
    local words = s:match('^([^"]-%a[^"]-): ".*"$')
    return words ~= nil and Maybe(words, d + 1)
end
T.Maybe = function(s) return Maybe(s, 0) end

-- The line just added: each side alone; nothing unless both checks pass. Cheapest first: could it be
-- Mastercraft's at all, then our words, then the stack (only for a line we have Ukrainian for).
local function Redo(tip, left, right)
    if not ns.WordsWanted() then return end
    left, right = U.Plain(left), U.Plain(right)     -- nil for a secret text: left as it is
    local missed = left and U.MissedOn() and left:find("%a%a%a")
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

local function Cleared(tip)
    local list = changed[tip]
    if not list then return end
    changed[tip] = nil
    for fs, was in pairs(list) do pcall(U.FontBack, fs, was) end   -- its font object, not a pinned file
end

local function HookTip(tip)
    if type(tip) ~= "table" or hookedTip[tip] or not tip.AddLine then return end
    hookedTip[tip] = true
    hooksecurefunc(tip, "AddLine", function(self, text) U.SafeCall(Redo, self, text) end)
    hooksecurefunc(tip, "AddDoubleLine", function(self, a, b) U.SafeCall(Redo, self, a, b) end)
    hooksecurefunc(tip, "SetText", function(self, text) U.SafeCall(Redo, self, text) end)
    if tip.HookScript then tip:HookScript("OnTooltipCleared", function(self) U.SafeCall(Cleared, self) end) end
end

function T.Install()
    for _, name in ipairs(TIPS) do HookTip(rawget(_G, name)) end
end

function T.Restore()
    for tip in pairs(changed) do Cleared(tip) end
end

function T.Count() return count end
