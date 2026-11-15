-- Attune's texts that get their words before they are inside one of Attune's windows, so they are
-- measured in Ukrainian, not in English.
--   * AceGUI widgets. Attune makes every widget with its own Attune_AceCreate: for the time of that one
--     AceGUI:Create call it puts its own SetWidth and SetHeight on AceGUI.WidgetBase, then puts the old
--     ones back. Attune then sets a label's text and measures it before AddChild, while the widget
--     still sits on UIParent, so Screen.Inside cannot see it yet. We post-hook (hooksecurefunc) the
--     AceGUI base SetWidth, SetHeight and SetLayout, which every widget calls while it is made; while
--     Attune's swap is on, the widget is noted. The AceGUI:Create post-hook then claims it when the
--     call came from Attune's own code (the stack, libraries skipped): its FontStrings are hooked
--     at once and count as Attune's (Owned) until AceGUI releases the widget.
--   * Attune's own plain frames that are measured on their first draw: the icon view's section header
--     (a post-hook on Attune_IconViewHeader, the header is the last child it made) and the "Will not
--     do" check box (a post-hook on Attune_WillNotDoLabel, which Attune calls just before it sets and
--     measures that text).
--   * Not covered: the small "OR" ring between steps (made and measured inside one function with no
--     call in between); it is sized from "OR" on its first draw only and is right on the next one.
-- Nothing is written on a widget, a frame or an AceGUI table: all we keep is in our own weak tables.
local _, ns = ...
local C = {}
ns.Claim = C

local owner = setmetatable({}, { __mode = "k" })     -- FontString -> its widget, or true (a plain frame)
local claimed = setmetatable({}, { __mode = "k" })   -- widget -> its FontStrings, while Attune holds it
local plain = setmetatable({}, { __mode = "k" })     -- plain frames already looked at
local base, normalWidth, candidate = nil, nil, nil
local claims = 0                                     -- for the checks
local installed = false

-- While Attune's swap is on, the widget being made is the one that just set its size or layout.
local function Note(self)
    if base and rawget(base, "SetWidth") ~= normalWidth then candidate = self end
end

-- The code that made the widget is Attune's own (not a library, not another addon).
local function FromAttune()
    local stack = type(debugstack) == "function" and debugstack(2) or ""
    for addon, rest in stack:gmatch("AddOns[/\\]([^/\\]+)[/\\]([^:\"%]\n]+)") do
        if not addon:find("^UADD") and not rest:lower():find("^libs[/\\]") then return addon == "Attune" end
    end
    return false
end

-- Every FontString of one frame and its children (a few levels deep), hooked and marked as ours.
local function Gather(f, mark, list, depth)
    if depth > 3 or type(f) ~= "table" then return end
    if (f.IsProtected and f:IsProtected()) or (f.IsObjectType and f:IsObjectType("EditBox")) then return end
    if f.GetRegions then
        for _, g in ipairs({ f:GetRegions() }) do
            if g.GetObjectType and g:GetObjectType() == "FontString" then
                ns.Texts.Hook(g)
                owner[g] = mark
                if list then list[#list + 1] = g end
            end
        end
    end
    if f.GetChildren then
        for _, c in ipairs({ f:GetChildren() }) do Gather(c, mark, list, depth + 1) end
    end
end

-- From the AceGUI:Create post-hook: true when the widget just made is Attune's (and now claimed).
function C.OnCreate(widgetType)
    local w = candidate
    candidate = nil
    if type(w) ~= "table" or not base or rawget(base, "SetWidth") == normalWidth then return false end
    if rawget(w, "type") ~= widgetType or not ns.On() or not FromAttune() then return false end
    local list = {}
    Gather(rawget(w, "frame"), w, list, 0)
    claimed[w] = list
    claims = claims + 1
    return true
end

-- AceGUI gives a widget back to its pool: its FontStrings are no longer Attune's.
function C.Release(w)
    local list = type(w) == "table" and claimed[w]
    if not list then return end
    claimed[w] = nil
    for _, fs in ipairs(list) do
        if owner[fs] == w then owner[fs] = nil end
        if ns.Texts.Known(fs) then ns.Texts.Forget(fs) end
    end
end

-- A FontString Attune holds now, though it may not be inside its windows yet.
function C.Owned(fs)
    local o = owner[fs]
    return o == true or (o ~= nil and claimed[o] ~= nil)
end

-- Ours to change: claimed, or inside one of Attune's windows.
function C.Ours(fs) return C.Owned(fs) or ns.Screen.Inside(fs) end

local function Plain(f)
    if type(f) ~= "table" or plain[f] then return end
    plain[f] = true
    Gather(f, true, nil, 0)
end

function C.Install(gui)
    if installed or type(gui) ~= "table" then return end
    installed = true
    base = rawget(gui, "WidgetBase")
    local box = rawget(gui, "WidgetContainerBase")
    if type(base) == "table" and type(base.SetWidth) == "function" then
        hooksecurefunc(base, "SetWidth", Note)
        if type(base.SetHeight) == "function" then hooksecurefunc(base, "SetHeight", Note) end
        normalWidth = rawget(base, "SetWidth")
    else
        base = nil
    end
    if type(box) == "table" and type(rawget(box, "SetLayout")) == "function" then
        hooksecurefunc(box, "SetLayout", Note)
    end
    if type(rawget(_G, "Attune_IconViewHeader")) == "function" then
        hooksecurefunc("Attune_IconViewHeader", function(view)
            local content = type(view) == "table" and rawget(view, "content")
            if type(content) ~= "table" or not content.GetChildren or not ns.On() then return end
            local n = select("#", content:GetChildren())
            if n > 0 then UADD.SafeCall(Plain, (select(n, content:GetChildren()))) end
        end)
    end
    if type(rawget(_G, "Attune_WillNotDoLabel")) == "function" then
        hooksecurefunc("Attune_WillNotDoLabel", function()
            if ns.On() then UADD.SafeCall(Plain, rawget(_G, "AttuneSkipCheck")) end
        end)
    end
end

-- For the checks: how many widgets were claimed so far.
function C.Claims() return claims end
