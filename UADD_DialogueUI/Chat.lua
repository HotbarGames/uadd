-- DialogueUI's chat lines ("Auto Select", "Quest Unblocked Alert", ...) in Ukrainian.
-- DialogueUI prints them as  logo .. "|cffffd100" .. header .. "  |cffffffff" .. message .. "|r".
-- The core chat hook (U.ChatHook, UADD/Lines.lua) wraps DEFAULT_CHAT_FRAME's AddMessage once for all modules;
-- only lines that start with DialogueUI's logo reach Line, and only the header and message parts that are an
-- L value change (a quest or option name stays as it is). "/uadd dialogueui off" stops the hook; the core
-- puts AddMessage back when no module needs it.

local _, ns = ...
local C = {}
ns.Chat = C

local LOGO = "|TInterface\\AddOns\\DialogueUI\\Art\\Icons\\Logo:0:0|t|cffffd100"
local active = false

local function Line(text)
    if not active or not UADD.Plain(text) or text:sub(1, #LOGO) ~= LOGO then return text end
    local header, msg = text:sub(#LOGO + 1):match("^(.-)  |cffffffff(.*)|r$")
    if not header then return text end
    local W = ns.Words
    return LOGO .. (W.Text(header) or header) .. "  |cffffffff" .. (W.Text(msg) or msg) .. "|r"
end

local hook = UADD.ChatHook({ marks = { LOGO }, line = Line })

function C.Start() active = true hook.Start() end
function C.Stop() active = false hook.Stop() end

-- For the checks: true while the hook changes lines.
function C.Active() return active and hook.Active() end
C.Line = Line
