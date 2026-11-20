-- UADD.WidgetMethods(kind): the method table that all widgets of one kind share ("Frame", "Button", ...),
-- for a hook on a method (CreateFontString) that covers every widget of that kind. nil when there is none.
--
-- It never makes an EditBox: a new one is shown with autoFocus on and takes the keyboard for good (Enter
-- no longer opens chat; docs/LESSONS2.md lesson 16). An EditBox's table comes from one the game already
-- has (the chat edit box). Other kinds are made once, hidden at once, and kept.

local U = UADD

local cache = {}
local EXISTING = { EditBox = { "ChatFrame1EditBox", "ChatFrame2EditBox", "ChatFrame3EditBox" } }

local function Methods(f)
    local mt = type(f) == "table" and getmetatable(f)
    local t = type(mt) == "table" and mt.__index
    return type(t) == "table" and t or nil
end

function U.WidgetMethods(kind)
    if type(kind) ~= "string" then return nil end
    if cache[kind] then return cache[kind] end
    local t
    if EXISTING[kind] then
        for _, name in ipairs(EXISTING[kind]) do
            local f = rawget(_G, name)
            if type(f) == "table" and f.IsObjectType and f:IsObjectType(kind) then
                t = Methods(f)
                if t then break end
            end
        end
    else
        local ok, f = pcall(CreateFrame, kind)
        if ok and f then
            f:Hide()
            t = Methods(f)
        end
    end
    cache[kind] = t
    return t
end
