-- Lua helpers for flow_button.py, part 3: step 14, an addon's SetFont of our file read back (docs/LESSONS5.md
-- lesson 48, UADD/FontReadBack.lua). Run after flow_button.lua, before the game starts. M.readBack() returns a list
-- of what went wrong (empty: passed). Every text is made up.
-- An addon that sets a size by SetFont(fs:GetFont()) while ours is on passes our Cyrillic file, and SetFont pins it.
-- A label whose file goes back by path (set by hand): back (off, held) gives its own file at its latest size and
-- flags. A game tooltip line (it follows its font family): its object back, never a Latin file by path (lesson 18).
-- UADD's own call is not the addon's; the stack is read once per size; an unknown stack counts as the addon's;
-- a hook that keeps failing goes quiet.
local H = HARNESS
local M = H.btn
local Bad, FRIZ = M.h.Bad, M.h.FRIZ

local runners = {}
local function As(addon, fn, ...)                           -- fn called from a chunk in that addon's folder
    local r = runners[addon]
    if not r then
        -- no tail call: its frame stays on the stack, where the core looks for the caller
        r = assert(loadstring("local f = ... local r = { f(select(2, ...)) } return unpack(r)",
            "@AddOns/" .. addon .. "/Layout.lua"))
        runners[addon] = r
    end
    return r(fn, ...)
end
local function Resize(fs, size, flags)                      -- the addon's code: its font read back, a new size
    local p, _, f = fs:GetFont()
    fs:SetFont(p, size, flags or f)
end
local function Font(fs) local p, s, fl = fs:GetFont() return tostring(p) .. " " .. tostring(s) .. " " .. tostring(fl) end
local function Is(fs, size, flags) local p, s, fl = fs:GetFont() return p == FRIZ and s == size and fl == flags end

-- A label of the addon's with its file set by hand (as OneForAll's tab label), ours on.
local function Hand(f, size, kept)
    local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetFont(FRIZ, size, "")
    fs:SetText(M.EN)
    local took = UADD.CyrFix(fs, kept)
    fs:SetText(M.UK)
    return fs, took
end
local function Back(fs, kept) fs:SetText(M.EN) UADD.CyrUnfix(fs, kept) end

function M.readBack()
    local U, bad = UADD, {}
    local f = CreateFrame("Frame", "FlowReadBack", UIParent)
    f:Show()
    -- hand-set at its object's size (12): ours by hand (`byhand`); then again at 10 (`own`)
    local kept = {}
    local fs, took = Hand(f, 12, kept)
    Bad(bad, took, "on: our font did not take")
    As("UADD_FlowModule", As, "FlowLayout", Resize, fs, 13)   -- a module calls the addon's layout (OneForAll's)
    As("FlowLayout", Resize, fs, 10, "OUTLINE")
    Bad(bad, U.IsCyrFont((fs:GetFont())), "on: its SetFont did not keep our file: " .. Font(fs))
    Back(fs, kept)
    Bad(bad, Is(fs, 10, "OUTLINE"), "back: not its own file at its latest size: " .. Font(fs))
    Bad(bad, U.CyrFix(fs, kept), "on again: our font did not take")
    fs:SetText(M.UK)
    As("FlowLayout", Resize, fs, 11)
    Back(fs, kept)
    Bad(bad, Is(fs, 11, "OUTLINE"), "back again: not its own file at its latest size: " .. Font(fs))
    -- a game tooltip line: a scaling addon's SetFont of our file pins it; back: its object, our file kept (no box)
    local line, tk = GameTooltipTextLeft2, {}
    local obj = line:GetFontObject()
    GameTooltip:Show()
    -- first a plain round, no scaler: UADD gives its object back (the scaler's SetFont below takes the pin from
    -- UADD, so wow_fontfam sees no back of ours there; tipfont.segment needs each put of ours seen going back)
    line:SetText(M.EN)
    Bad(bad, U.CyrFix(line, tk), "tooltip line, plain: our font did not take")
    Back(line, tk)
    Bad(bad, line:GetFontObject() == obj and not U.IsCyrFont((line:GetFont())),
        "tooltip line, plain: not its own object back: " .. Font(line))
    tk = {}
    line:SetText(M.EN)
    Bad(bad, U.CyrFix(line, tk), "tooltip line: our font did not take")
    line:SetText(M.UK)
    As("FlowScale", Resize, line, 14)
    Back(line, tk)
    Bad(bad, line:GetFontObject() == obj and U.IsCyrFont((line:GetFont())),
        "tooltip line: a Latin file by path, or not its object: " .. Font(line))
    line:SetText(M.UK)                                      -- another addon's Ukrainian on it later
    Bad(bad, H.drawsCyr(line) and not H.boxSuspect(line), "tooltip line: boxes on a later Ukrainian")
    line:SetText("")
    GameTooltip:Hide()
    -- UADD's own code (a module) sets our file the same way, three times: the record stays, the stack read once
    local k2 = {}
    local mod = Hand(f, 14, k2)
    local stacks, stack = 0, debugstack
    debugstack = function(...) stacks = stacks + 1 return stack(...) end
    for _ = 1, 3 do As("UADD_FlowModule", Resize, mod, 13) end
    debugstack = stack
    Back(mod, k2)
    Bad(bad, Is(mod, 14, ""), "UADD's own SetFont taken for the addon's: " .. Font(mod))
    Bad(bad, stacks == 1, "the stack read " .. stacks .. " times for one size, not once")
    -- no stack (debugstack fails): the addon's call, the record takes its size
    local k3 = {}
    local odd = Hand(f, 14, k3)
    debugstack = function() error("flow: no stack") end
    local ok = pcall(As, "FlowLayout", Resize, odd, 12)
    debugstack = stack
    Back(odd, k3)
    Bad(bad, ok and Is(odd, 12, ""), "no stack: not the addon's size: " .. Font(odd))
    -- the hook fails each time (its GetFont throws): reported 5 times, then quiet
    local k4 = {}
    local sick = Hand(f, 14, k4)
    local said, report = 0, U.ReportError
    U.ReportError = function() said = said + 1 end
    rawset(sick, "GetFont", function() error("flow: GetFont broke") end)
    for i = 1, 10 do pcall(sick.SetFont, sick, U.CyrFontPath(), 10 + i % 2, "") end
    rawset(sick, "GetFont", nil)
    U.ReportError = report
    Back(sick, k4)
    Bad(bad, said == 5, "a failing hook: " .. said .. " errors reported, not 5")
    f:Hide()
    return bad
end
