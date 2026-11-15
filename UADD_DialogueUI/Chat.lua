-- DialogueUI's chat lines ("Auto Select", "Quest Unblocked Alert", ...) in Ukrainian.
-- DialogueUI prints them as  logo .. "|cffffd100" .. header .. "  |cffffffff" .. message .. "|r".
-- DEFAULT_CHAT_FRAME's AddMessage is wrapped on that one frame; the wrapper changes only lines that
-- start with DialogueUI's logo, and only the header and message parts that are an L value (a quest or
-- option name stays as it is). "/uadd dialogueui off" puts AddMessage back exactly as it was; when
-- another addon wrapped it after us, ours stays in its chain but passes every line through.

local _, ns = ...
local C = {}
ns.Chat = C

local LOGO = "|TInterface\\AddOns\\DialogueUI\\Art\\Icons\\Logo:0:0|t|cffffd100"
local frame, had, before, wrapper = nil, nil, nil, nil
local active = false

local function Line(text)
    if not active or not UADD.Plain(text) or text:sub(1, #LOGO) ~= LOGO then return text end
    local header, msg = text:sub(#LOGO + 1):match("^(.-)  |cffffffff(.*)|r$")
    if not header then return text end
    local W = ns.Words
    return LOGO .. (W.Text(header) or header) .. "  |cffffffff" .. (W.Text(msg) or msg) .. "|r"
end

function C.Start()
    active = true
    if wrapper then return end
    frame = rawget(_G, "DEFAULT_CHAT_FRAME")
    if type(frame) ~= "table" or type(frame.AddMessage) ~= "function" then frame = nil return end
    had, before = rawget(frame, "AddMessage"), frame.AddMessage
    local call = before
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
        wrapper, frame, had, before = nil, nil, nil, nil
    end
end

-- For the checks: true while the wrapper changes lines.
function C.Active() return active and wrapper ~= nil end
C.Line = Line
