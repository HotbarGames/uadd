-- A button's label and the button's own font objects (docs/LESSONS4.md lesson 46).
-- A button has a font object per state: normal, highlight (under the mouse), disabled. On a state change the client
-- puts the state's object on the label by itself: no Lua SetFontObject runs, so no hook sees it, and it may come after
-- our OnEnter hook. The game's objects are font families, and on a label they draw their Latin member: our Ukrainian
-- there is boxes (seen on BugSack's tabs, 2026-11-26). GetFont cannot tell it: it names the Latin file either way.
-- So while our text is on a label, each of its button's objects without Cyrillic is replaced by our own copy of it
-- (UADD_CyrFontBn: a plain font object with the Cyrillic file, the same size, flags, colour and shadow), and the
-- client's own switch puts Cyrillic on. The button's own objects go back with the label's font (U.FontBack).
--   * Only the button's own setters are used; a game font object is only read. One copy per object, at most CAP.
--   * Not CopyFontObject: a copied family keeps its members, and SetFont changes only the main one (measured).
--   * An object the addon sets later is its own from then on: ours goes over that one, and that one goes back.
--   * A protected or forbidden button, or no copy left: false, and the caller leaves the text English.
-- One frame after each thing that may change a button's state, the label is looked at again.

local U = UADD
local STATES = { "Normal", "Highlight", "Disabled" }
local CALLS = { "SetNormalFontObject", "SetHighlightFontObject", "SetDisabledFontObject", "Enable", "Disable",
    "SetEnabled", "LockHighlight", "UnlockHighlight" }
local SCRIPTS = { "OnEnter", "OnLeave", "OnMouseDown", "OnMouseUp", "OnShow", "OnEnable", "OnDisable" }
local CAP = 64
local weak = { __mode = "k" }
local copies, base, made = {}, {}, 0       -- an object -> { o = our copy, size, flags }; our copy -> that object
local rec = setmetatable({}, weak)         -- Button -> { Normal = our copy on it, ... } while our text is on its label
local hooked = setmetatable({}, weak)
local queued, waiting, putting = {}, false, false

-- The Button whose own label `fs` is (its GetFontString), or nil. Never a menu row (U.Locked) or a forbidden frame.
function U.LabelButton(fs)
    if type(fs) ~= "table" or U.Locked(fs) then return nil end
    local ok, b = pcall(function()
        local p = fs.GetParent and fs:GetParent()
        if type(p) ~= "table" or (p.IsForbidden and p:IsForbidden()) or not p.GetObjectType then return nil end
        local kind = p:GetObjectType()
        if kind ~= "Button" and kind ~= "CheckButton" then return nil end
        if type(p.GetNormalFontObject) ~= "function" or p:GetFontString() ~= fs then return nil end
        return p
    end)
    return ok and b or nil
end

-- The object our copy stands for; any other object as it is (a label's own font is never saved as our copy).
function U.FontBase(o) return o ~= nil and base[o] or o end

local function IsCyr(o) return U.IsCyrFont((o:GetFont())) end

-- Our copy of one font object, or nil (no Cyrillic file, no CreateFont, CAP reached, or the file did not take).
local function Copy(o)
    local path = U.CyrFontPath()
    if not path or type(CreateFont) ~= "function" or type(o) ~= "table" or not o.GetFont then return nil end
    local _, size, flags = o:GetFont()
    size, flags = tonumber(size) or 12, flags or ""
    if size <= 0 then size = 12 end
    local c = copies[o]
    if c and c.size == size and c.flags == flags then return c.o end
    local mine = c and c.o
    if not mine then
        if made >= CAP then return nil end
        made = made + 1
        mine = CreateFont("UADD_CyrFontB" .. made)
    end
    mine:SetFont(path, size, flags)
    if not IsCyr(mine) then return nil end                 -- read back (lesson 2)
    for _, m in ipairs(U.FontLooks) do
        if o[m[1]] and mine[m[2]] then
            local looks = { o[m[1]](o) }
            if looks[1] ~= nil then pcall(mine[m[2]], mine, unpack(looks)) end
        end
    end
    copies[o], base[mine] = { o = mine, size = size, flags = flags }, o
    return mine
end

-- A button we may change: not protected (a secure button of the game's or an addon's), not forbidden.
local function Free(btn)
    local ok, no = pcall(function()
        return (btn.IsForbidden and btn:IsForbidden()) or (btn.IsProtected and btn:IsProtected())
    end)
    return ok and not no
end

local function Get(btn, s)                  -- the object (a name, as the setters take one, is looked up)
    local o = btn["Get" .. s .. "FontObject"](btn)
    if type(o) == "string" then o = _G[o] end
    return o
end
local function Set(btn, s, o) return btn["Set" .. s .. "FontObject"](btn, o) end

local Hooks

local function Put(btn, look)
    local r, want = rec[btn], nil
    for _, s in ipairs(STATES) do
        local o = Get(btn, s)
        if type(o) == "table" and not base[o] and o.GetFont and not IsCyr(o) then
            if look and not r then return false end
            local c = Copy(o)
            if not c then return false end
            want = want or {}
            want[s] = c
        end
    end
    if look and not r then return true end
    local free = Free(btn)
    if want then
        if not free then return false end
        local was, ok = {}, true
        for s, c in pairs(want) do
            was[s] = Get(btn, s)
            ok = pcall(Set, btn, s, c) and Get(btn, s) == c
            if not ok then break end
        end
        if not ok then                                      -- whole or nothing: the button's own objects again
            for s, o in pairs(was) do pcall(Set, btn, s, o) end
            return false
        end
    end
    r = r or {}
    for s, c in pairs(want or {}) do r[s] = c end
    rec[btn] = r
    if free then Hooks(btn) end
    return true
end

-- Every state of the button draws Cyrillic from now on: true. false: it cannot, nothing was changed.
-- `look`: a button we did not change is only looked at.
function U.ButtonCyr(btn, look)
    local was = putting
    putting = true
    local ok, yes = pcall(Put, btn, look)
    putting = was
    return ok and yes == true
end

-- The button's own objects back, each only while it is still our copy (one the addon set since is its own).
function U.ButtonBack(btn)
    local r = rec[btn]
    if not r then return end
    rec[btn] = nil
    local was = putting
    putting = true
    for s, c in pairs(r) do
        pcall(function() if Get(btn, s) == c then Set(btn, s, base[c]) end end)
    end
    putting = was
end

-- A font object on a label. Only looks the addon gave the label itself are kept over it: a colour set again on a
-- label would stay over the colours of all its later states (the gold text under the mouse, 2026-11-26).
function U.LabelOn(fs, o)
    local from, keep = fs.GetFontObject and fs:GetFontObject() or nil, {}
    for i, m in ipairs(U.FontLooks) do
        if fs[m[1]] and fs[m[2]] then
            local a, b = { fs[m[1]](fs) }, type(from) == "table" and from[m[1]] and { from[m[1]](from) } or {}
            for k, v in pairs(a) do
                local w = b[k]
                local same = v == w or (type(v) == "number" and type(w) == "number" and math.abs(v - w) < 0.01)
                if not same then keep[i] = a end
            end
        end
    end
    fs:SetFontObject(o)
    for i, a in pairs(keep) do fs[U.FontLooks[i][2]](fs, unpack(a)) end
end

-- Our font on the label of `btn`, as its state has it: true when the label draws Cyrillic now and in every state.
-- false: a label that keeps a font set by hand (its states are ours, the caller puts the file on by hand), or nil:
-- the button cannot be changed, the text stays English.
function U.LabelCyr(btn, fs)
    if not U.ButtonCyr(btn) then return nil end
    local o = fs:GetFontObject()
    local c = type(o) == "table" and not base[o] and copies[o]
    if c then U.LabelOn(fs, c.o) end
    return U.IsCyrFont((fs:GetFont()))
end

-- ── A look again after a state change ─────────────────────────────────────────────────────────────

local function Again(btn)
    if not rec[btn] then return end
    -- Our copies on its states first, whatever the label shows now: a state object the addon set while the label
    -- was empty or English is ours before our text goes on (no later look is needed for it).
    local states = U.ButtonCyr(btn)
    local fs = btn:GetFontString()
    if not fs then return end
    local t = U.Plain(fs:GetText())
    if not t or not t:find("[\208\209\210][\128-\191]") then return end
    if not states then return U.BoxGiveUp and U.BoxGiveUp(fs) end   -- a state stays Latin: English, never boxes
    if not U.IsCyrFont((fs:GetFont())) then U.CyrOnLocked(fs) end
    if U.BoxCheck then U.BoxCheck(fs) end
end

local function Run()
    waiting = false
    local list = queued
    queued = {}
    for btn in pairs(list) do pcall(Again, btn) end
end

local function Later(btn)
    if not rec[btn] then return end                         -- nothing of ours on it: leave at once
    queued[btn] = true
    if waiting or not (C_Timer and C_Timer.After) then return end
    waiting = true
    C_Timer.After(0, Run)
end

local function OnCall(btn)
    if putting or not rec[btn] then return end
    pcall(Again, btn)                                       -- the client may draw the label before the next frame
    Later(btn)
end

Hooks = function(btn)
    if hooked[btn] then return end
    hooked[btn] = true
    for _, m in ipairs(CALLS) do
        if type(btn[m]) == "function" then pcall(hooksecurefunc, btn, m, OnCall) end
    end
    if btn.HookScript then
        for _, s in ipairs(SCRIPTS) do pcall(btn.HookScript, btn, s, Later) end
    end
end

-- For the checks: our copies made so far; what is ours on one button.
function U.ButtonFonts(btn)
    if btn == nil then return made end
    return rec[btn]
end
