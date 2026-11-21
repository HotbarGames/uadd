-- LayerSwap's own chat lines in Ukrainian. Its messages to the player go through print with its
-- name in front ("|cff7fd4ffLayerSwap|r: " .. msg); print goes to DEFAULT_CHAT_FRAME:AddMessage.
-- The core chat hook (U.ChatHook, UADD/Lines.lua) wraps that AddMessage once for all modules; only lines that
-- start with that prefix reach Line, and only the part after it changes, when Words.lua knows it. The prefix
-- (the addon's name) stays. What players say, whispers, the addon's channel talk and its addon messages
-- are never touched: those are not its own printed lines.
-- "/uadd layerswap off" stops the hook; the core puts AddMessage back when no module needs it.

local _, ns = ...
local C = {}
ns.Chat = C

local PREFIX = "|cff7fd4ffLayerSwap|r: "
local active = false

local function Line(text)
    if not active or not UADD.Plain(text) or text:sub(1, #PREFIX) ~= PREFIX then return text end
    if not ns.WordsWanted() then return text end
    local msg = text:sub(#PREFIX + 1)
    local uk = ns.Words.Text(msg)
    if not uk then UADD.Missed("layerswap", msg) end
    return uk and PREFIX .. uk or text
end

local hook = UADD.ChatHook({ marks = { PREFIX }, line = Line })

function C.Start() active = true hook.Start() end
function C.Stop() active = false hook.Stop() end

-- For the checks: true while the hook changes lines.
function C.Active() return active and hook.Active() end
C.Line = Line
