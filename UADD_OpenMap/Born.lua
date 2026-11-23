-- Texts OpenMap sets while it builds a named window (Screen.lua's NAMED), before any look of ours: they would
-- show in a font without Cyrillic until the next look (boxes). So each new FontString of a named window (or of
-- a frame under one) has its SetText hooked at birth (Words.lua: our words, and the font follows the text).
-- Every CreateFontString of the game passes here (core U.OnNewFontString, under U.SafeCall, lesson 35): the
-- module off and a frame met before leave at a table look-up; the game's busy frames by their name only
-- (U.GameMade); others by at most 4 names up their parents, once per frame. No walk: only the frame's own regions.

local _, ns = ...
local U = UADD
local B = {}
ns.Born = B

local NAMED_SET = {}
for _, name in ipairs(ns.Screen.NAMED) do NAMED_SET[name] = true end
local isOurs = setmetatable({}, { __mode = "k" })   -- frame -> true under a named window, false not

local function UnderNamed(f)
    local p = f
    for _ = 1, 4 do
        local name = U.Plain(p:GetName())
        if name and NAMED_SET[name] and rawget(_G, name) == p then return true end
        p = p:GetParent()
        if type(p) ~= "table" then return false end
    end
    return false
end

local function OnNewText(f)
    if not ns.On() or type(f) ~= "table" then return end
    local ours = isOurs[f]
    if ours == nil then
        ours = false
        if not U.GameMade(f) then
            local ok, v = pcall(UnderNamed, f)
            ours = ok and v == true
        end
        isOurs[f] = ours
    end
    if not ours then return end
    if f:GetObjectType() == "Button" then ns.Words.HookButton(f) end
    for _, g in ipairs(U.Regions(f)) do
        if g:GetObjectType() == "FontString" then ns.Words.Hook(g) end
    end
end
B.OnNewText = OnNewText   -- for the checks

local hooked = false
function B.Install()
    if not hooked then hooked = U.OnNewFontString(OnNewText) end
end
