-- UADD.WalkFrames: the small frame questions UADD.Walk (Walk.lua) asks while it walks a module's windows. Each one
-- runs under a pcall: a frame that throws on a question is taken as forbidden or nameless, never as an error.

local U = UADD
local sub = string.sub
local F = {}
U.WalkFrames = F

F.CYR = "[\208-\210]"

function F.Forbidden(f)
    if type(f) ~= "table" then return true end
    local ok, yes = pcall(function() return f.IsForbidden and f:IsForbidden() end)
    return not ok or yes and true or false
end

function F.Protected(f)
    local ok, yes = pcall(function() return f.IsProtected and f:IsProtected() end)
    return not ok or yes and true or false
end

function F.Name(f)
    local ok, n = pcall(function() return f.GetName and f:GetName() end)
    return ok and U.Plain(n) or nil
end

function F.Kind(f)
    local ok, k = pcall(function() return f.GetObjectType and f:GetObjectType() end)
    return ok and k or nil
end

-- A Button's label (it draws into it without the label's SetText).
function F.Label(b)
    local ok, fs = pcall(function() return b.GetFontString and b:GetFontString() end)
    if ok and type(fs) == "table" and not F.Forbidden(fs) then return fs end
end

-- spec.skip: a set of frame names, or a function(frame, name).
function F.Skip(spec, f, name)
    local s = spec.skip
    if type(s) == "function" then
        local ok, yes = pcall(s, f, name)
        return not ok or yes and true or false
    end
    return type(s) == "table" and name and s[name] and true or false
end

-- spec.roots: a list of global frame names (or frames), or a function giving a list of frames.
function F.Roots(spec)
    local r = spec.roots
    if type(r) == "function" then
        local ok, list = pcall(r)
        return ok and type(list) == "table" and list or {}
    end
    local list = {}
    for _, name in ipairs(type(r) == "table" and r or {}) do
        local f = type(name) == "string" and rawget(_G, name) or name
        if type(f) == "table" then list[#list + 1] = f end
    end
    return list
end

-- A text box's hint FontStrings (a "Search..." the addon draws in it, lesson 44): each one already `hooked`, or
-- with a text that is not what the box holds. The typed text is the box's own, never one of these.
function F.Hints(box, hooked)
    local out = {}
    local okT, typed = pcall(box.GetText, box)
    for _, r in ipairs(U.Regions(box)) do
        if not F.Forbidden(r) and F.Kind(r) == "FontString" then
            local ok, t = pcall(r.GetText, r)
            t = ok and U.Plain(t) or nil
            if hooked[r] or (t and t ~= "" and not (okT and t == U.Plain(typed))) then out[#out + 1] = r end
        end
    end
    return out
end

-- spec.prefix: a frame name prefix, or a list of them.
function F.Starts(spec, name)
    local p = spec.prefix
    if type(p) == "string" then return sub(name, 1, #p) == p end
    for _, one in ipairs(type(p) == "table" and p or {}) do
        if sub(name, 1, #one) == one then return true end
    end
    return false
end
