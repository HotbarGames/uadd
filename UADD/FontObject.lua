-- Font objects we may put on a text (docs/LESSONS4.md lesson 47).
-- SetFontObject makes a text, or a font object, inherit from the object given, and the client follows that chain
-- in its own code: a chain that comes back on itself never ends, a stack overflow that kills the game (no pcall
-- catches it). An edit box's GetFontObject gave a nameless font record of the client's own (BugSack's text area,
-- 2026-11-26), and that record put back on the box inherited from itself. So an object goes on a text only when the
-- client knows it by name (the global of its name is this object, as ours are), it is not the text, and its chain
-- ends within DEEP steps, never on a repeat, the text or the text's own nameless record. One set at a time per text:
-- a hook that sets the same text again inside it gets false. Any doubt: false, nothing set.
-- Every put-back of a saved object goes through here (U.FontBack, ButtonFont.lua, the modules' Fonts.lua):
-- tools/test_shared_state.py ("put object") fails a module that calls SetFontObject with a saved one itself.

local U = UADD

local DEEP = 10
local setting = setmetatable({}, { __mode = "k" })

local function Named(o)
    local ok, yes = pcall(function()
        local n = o:GetName()
        return type(n) == "string" and n ~= "" and rawget(_G, n) == o
    end)
    return ok and yes == true
end

local function Up(o)
    local ok, up = pcall(function() return o.GetFontObject and o:GetFontObject() or nil end)
    if not ok then return false end
    if type(up) == "string" then up = rawget(_G, up) end
    return up
end

-- true: `o` may go on `fs` (fs nil: a button's state object, ButtonFont.lua).
function U.FontObjectOK(fs, o)
    if type(o) ~= "table" or o == fs or type(o.GetFont) ~= "function" or not Named(o) then return false end
    local cur = fs ~= nil and Up(fs) or nil
    if cur ~= nil and (cur == false or Named(cur)) then cur = nil end   -- a named object it follows is no record
    local seen, p = { [o] = true }, o
    for _ = 1, DEEP do
        local up = Up(p)
        if up == nil then return true end
        if type(up) ~= "table" or seen[up] or up == fs or up == cur then return false end
        seen[up], p = true, up
    end
    return false
end

-- The object fs follows, as one that may go back on it: the first in its chain that U.FontObjectOK takes. Second
-- result true: it follows an object, but none in its chain may go back (the font then stays as it is).
function U.SafeFontObject(fs)
    local o = Up(fs)
    if o == nil then return nil, false end
    local seen = {}
    for _ = 1, DEEP do
        if type(o) ~= "table" or seen[o] or o == fs then break end
        if U.FontObjectOK(fs, o) then return o, false end
        seen[o] = true
        o = Up(o)
        if o == nil then break end
    end
    return nil, true
end

-- SetFontObject only with an object U.FontObjectOK takes, never inside another set of the same text: true when set.
function U.SetFontObject(fs, o)
    if type(fs) ~= "table" or setting[fs] or not U.FontObjectOK(fs, o) then return false end
    setting[fs] = true
    local ok, err = pcall(fs.SetFontObject, fs, o)
    setting[fs] = nil
    if not ok then error(err, 0) end
    return true
end
