-- ForeverXP Bar's own chat lines in Ukrainian. Its printMsg writes
--     DEFAULT_CHAT_FRAME:AddMessage("|cff8ee6deForeverXP Bar|r " .. msg)
-- The core chat hook (U.ChatHook, UADD/Lines.lua) wraps that AddMessage once for all modules; only lines that
-- start with that prefix reach Line, and only the part after it changes, when Words.lua knows it. The prefix
-- (the addon's name) stays. What players say, its race and level-up lines sent through chat ("[FXPB] ...")
-- and its addon messages are never touched: those are not printMsg lines.
-- "/uadd fxpb off" stops the hook; the core puts AddMessage back when no module needs it.

local _, ns = ...
local C = {}
ns.Chat = C

local PREFIX = "|cff8ee6deForeverXP Bar|r "
local active = false

local function Line(text)
    if not active or not UADD.Plain(text) or text:sub(1, #PREFIX) ~= PREFIX then return text end
    if not ns.WordsWanted() then return text end
    local msg = text:sub(#PREFIX + 1)
    local uk = ns.Words.Text(msg)
    if not uk then UADD.Missed("fxpb", msg) end
    return uk and PREFIX .. uk or text
end

local hook = UADD.ChatHook({ marks = { PREFIX }, line = Line })

function C.Start() active = true hook.Start() end
function C.Stop() active = false hook.Stop() end

-- For the checks: true while the hook changes lines.
function C.Active() return active and hook.Active() end
C.Line = Line
