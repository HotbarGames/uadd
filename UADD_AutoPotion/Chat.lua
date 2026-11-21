-- Auto Potion's own chat lines in Ukrainian. It prints through print, which goes to
-- DEFAULT_CHAT_FRAME:AddMessage. The core chat hook (U.ChatHook, UADD/Lines.lua) wraps it once for all modules:
--   * a line with its name in front (PREFIXES: its purple name, or its red error name): only the part
--     after the name changes, when Words.lua knows it; the name stays;
--   * a line it prints alone (the reset and wrong-option answers of /ap): changed only when the whole
--     line is one of those (Words.Bare), so nobody else's chat line is touched. Words.MaybeBare (a length
--     and a short hash) comes first, so other lines never reach Bare (lesson 12).
-- The lines of its debug log stay English (the lines that say debug is on or off are ours). What players say
-- is never touched. "/uadd autopotion off" stops the hook; the core puts AddMessage back when no module needs it.

local _, ns = ...
local C = {}
ns.Chat = C

local PREFIXES = { "|cffb48ef9AutoPotion:|r ", "|cffff0000AutoPotion Error:|r " }
local active = false

local function Line(text)
    if not active or type(text) ~= "string" or not UADD.Plain(text) or not ns.WordsWanted() then return text end
    for _, p in ipairs(PREFIXES) do
        if text:sub(1, #p) == p then
            local msg = text:sub(#p + 1)
            local uk = ns.Words.Text(msg)
            if not uk then UADD.Missed("autopotion", msg) end
            return uk and p .. uk or text
        end
    end
    if not ns.Words.MaybeBare(text) then return text end
    return ns.Words.Bare(text) or text
end

local hook = UADD.ChatHook({ marks = PREFIXES, line = Line,
    maybe = function(text) return ns.Words.MaybeBare(text) end })

function C.Start() active = true hook.Start() end
function C.Stop() active = false hook.Stop() end

-- For the checks.
function C.Active() return active and hook.Active() end
C.Line = Line
