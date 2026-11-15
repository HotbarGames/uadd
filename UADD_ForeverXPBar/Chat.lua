-- ForeverXP Bar's own chat lines in Ukrainian. Its printMsg writes
--     DEFAULT_CHAT_FRAME:AddMessage("|cff8ee6deForeverXP Bar|r " .. msg)
-- DEFAULT_CHAT_FRAME's AddMessage is wrapped on that one frame (as UADD_DialogueUI/Chat.lua); the
-- wrapper changes only lines that start with that prefix, and only the part after it, when Words.lua
-- knows it. The prefix (the addon's name) stays. What players say, its race and level-up lines sent
-- through chat ("[FXPB] ...") and its addon messages are never touched: those are not printMsg lines.
-- "/uadd fxpb off" puts AddMessage back exactly as it was; when another addon wrapped it after us,
-- ours stays in its chain but passes every line through.

local _, ns = ...
local C = {}
ns.Chat = C

local PREFIX = "|cff8ee6deForeverXP Bar|r "
local frame, had, wrapper = nil, nil, nil
local active = false

local function Line(text)
    if not active or not UADD.Plain(text) or text:sub(1, #PREFIX) ~= PREFIX then return text end
    if not ns.WordsWanted() then return text end
    local msg = text:sub(#PREFIX + 1)
    local uk = ns.Words.Text(msg)
    return uk and PREFIX .. uk or text
end

function C.Start()
    active = true
    if wrapper then return end
    frame = rawget(_G, "DEFAULT_CHAT_FRAME")
    if type(frame) ~= "table" or type(frame.AddMessage) ~= "function" then frame = nil return end
    had = rawget(frame, "AddMessage")
    local call = frame.AddMessage
    wrapper = function(self, text, ...)
        local ok, t = pcall(Line, text)
        return call(self, ok and t or text, ...)
    end
    frame.AddMessage = wrapper   -- taints this one field; accepted: chat addons all do it, no secure code needs it
end

function C.Stop()
    active = false
    if not wrapper or not frame then return end
    if rawget(frame, "AddMessage") == wrapper then   -- nobody wrapped it after us: put it back
        frame.AddMessage = had
        wrapper, frame, had = nil, nil, nil
    end
end

-- For the checks: true while the wrapper changes lines.
function C.Active() return active and wrapper ~= nil end
C.Line = Line
