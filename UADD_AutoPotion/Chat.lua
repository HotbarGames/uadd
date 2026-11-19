-- Auto Potion's own chat lines in Ukrainian. It prints through print, which goes to
-- DEFAULT_CHAT_FRAME:AddMessage. That AddMessage is wrapped on that one frame (as UADD_LayerSwap/Chat.lua):
--   * a line with its name in front (PREFIXES: its purple name, or its red error name): only the part
--     after the name changes, when Words.lua knows it; the name stays;
--   * a line it prints alone (the reset and wrong-option answers of /ap): changed only when the whole
--     line is one of those (Words.Bare), so nobody else's chat line is touched.
-- The lines of its debug log stay English (the lines that say debug is on or off are ours). What players say is never touched. "/uadd autopotion off" puts
-- AddMessage back as it was; when another addon wrapped it after us, ours stays in its chain but passes
-- every line through.

local _, ns = ...
local C = {}
ns.Chat = C

local PREFIXES = { "|cffb48ef9AutoPotion:|r ", "|cffff0000AutoPotion Error:|r " }
local frame, had, wrapper = nil, nil, nil
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
    return ns.Words.Bare(text) or text
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
    if rawget(frame, "AddMessage") == wrapper then
        frame.AddMessage = had
        wrapper, frame, had = nil, nil, nil
    end
end

-- For the checks.
function C.Active() return active and wrapper ~= nil end
C.Line = Line
