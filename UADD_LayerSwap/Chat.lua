-- LayerSwap's own chat lines in Ukrainian. Its messages to the player go through print with its
-- name in front ("|cff7fd4ffLayerSwap|r: " .. msg); print goes to DEFAULT_CHAT_FRAME:AddMessage.
-- That AddMessage is wrapped on that one frame (as UADD_ForeverXPBar/Chat.lua); the wrapper changes
-- only lines that start with that prefix, and only the part after it, when Words.lua knows it. The
-- prefix (the addon's name) stays. What players say, the lines LayerSwap sends or reads in the layer
-- channel, whispers and its addon messages are never touched: those are not its own printed lines.
-- "/uadd layerswap off" puts AddMessage back exactly as it was; when another addon wrapped it after
-- us, ours stays in its chain but passes every line through.

local _, ns = ...
local C = {}
ns.Chat = C

local PREFIX = "|cff7fd4ffLayerSwap|r: "
local frame, had, wrapper = nil, nil, nil
local active = false

local function Line(text)
    if not active or not UADD.Plain(text) or text:sub(1, #PREFIX) ~= PREFIX then return text end
    if not ns.WordsWanted() then return text end
    local msg = text:sub(#PREFIX + 1)
    local uk = ns.Words.Text(msg)
    if not uk then UADD.Missed("layerswap", msg) end
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
