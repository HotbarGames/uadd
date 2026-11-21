-- Attune's own chat lines in Ukrainian. It prints its messages one way:
--     print("|cffff00ff[Attune]|r " .. AttuneLang[...]:gsub("##NAME##", name))
-- print() hands its words to the game's print handler. Line is a handler on the core's one print
-- handler (U.PrintHook, UADD/Print.lua; off in an instance, lesson 35): a print of one text that starts
-- with that coloured prefix gets the part after it in Ukrainian, when Words.lua knows it; every other
-- print (other addons, several values) goes to the old handler untouched. No chat frame is changed. The prefix
-- (the addon's name) stays; player names, numbers and versions stay.
-- Not here: the "Attune loaded" line at login (written straight into the chat frame) and "Addon
-- disabled" (AceConsole's own Print): both stay English. What goes to other players (the guild
-- "attunement complete" line, addon messages) is sent by Attune itself and never comes here.
-- "/uadd attune off" puts the old handler back exactly as it was; when another addon set its own
-- handler after us, ours stays in its chain but passes every line through.
-- A client without setprinthandler: chat lines stay English (nothing else is wrapped instead).

local _, ns = ...
local C = {}
ns.Chat = C

local PREFIX = "^(|c%x%x%x%x%x%x%x%x%[Attune%]|r )(.*)$"
local active = false

-- Sentences ("One. Two.") each in Ukrainian where we know them; nil when none changed.
local function Sentences(msg)
    if not msg:find(". ", 1, true) then return nil end
    local out, any, pos = {}, false, 1
    while pos <= #msg do
        local s, e = msg:find("%. ", pos)
        local part = s and msg:sub(pos, s) or msg:sub(pos)
        local uk = ns.Words.Text(part)
        out[#out + 1] = uk or part
        any = any or uk ~= nil
        if not s then break end
        out[#out + 1] = " "
        pos = e + 1
    end
    return any and table.concat(out) or nil
end

-- The coloured pieces ("|cff..Version: |r") in Ukrainian; nil when none changed.
local function Pieces(msg)
    local any = false
    local out = msg:gsub("(|c%x%x%x%x%x%x%x%x)(.-)(|r)", function(code, inner, close)
        local uk = ns.Words.Text(inner)
        if not uk then return nil end
        any = true
        return code .. uk .. close
    end)
    return any and out or nil
end

local function Message(msg)
    local uk = ns.Words.Text(msg)
    if uk then return uk end
    local head, tail = msg:match("^(.-): (.+)$")
    if head and not head:find("|", 1, true) then
        uk = ns.Words.Text(tail)
        if uk then return head .. ": " .. uk end
    end
    return Sentences(msg) or Pieces(msg)
end

local function Line(text)
    if not active or not UADD.Plain(text) or not ns.WordsWanted() then return text end
    local prefix, msg = text:match(PREFIX)
    if not prefix then return text end
    local uk = Message(msg)
    return uk and prefix .. uk or text
end

local hook = UADD.PrintHook({ line = Line })

function C.Start()
    active = true
    hook.Start()
end

function C.Stop()
    active = false
    hook.Stop()
end

-- For the checks: true while the core handler changes lines.
function C.Active() return active and hook.Active() end
C.Line = Line
