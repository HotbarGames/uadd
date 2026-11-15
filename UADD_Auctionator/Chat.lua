-- Auctionator's own chat lines in Ukrainian. It prints every message the same way
-- (Source/Utilities/Message.lua):
--     print(LIGHTBLUE_FONT_COLOR:WrapTextInColorCode("Auctionator: ") .. message)
-- print() hands its words to the game's print handler (getprinthandler / setprinthandler). We put a
-- handler in front of the one that was there: a print of one text that starts with that coloured
-- prefix gets the part after it in Ukrainian, when Words.lua knows it; every other print (other
-- addons, several values, what players say never comes here) goes to the old handler untouched.
-- No chat frame is changed. The prefix (the addon's name) stays. Lines Auctionator glues together:
--   * "/atr help": "<command words>: <text>": only the text after the first ": " changes;
--   * a failed full scan: two sentences joined by " ": each sentence on its own;
--   * "/atr version": "|cff..Version: |r346, <date>, |cff..WoW: |r<build>": each coloured piece.
-- Item links, prices, command words and option names stay as they are. What players say is never
-- touched. "/uadd auctionator off" puts the old handler back exactly as it was; when another addon set
-- its own handler after us, ours stays in its chain but passes every line through.
-- A client without setprinthandler: chat lines stay English (nothing else is wrapped instead).

local _, ns = ...
local C = {}
ns.Chat = C

local PREFIX = "^(|c%x%x%x%x%x%x%x%xAuctionator: |r)(.*)$"
local had, wrapper = nil, nil
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

function C.Start()
    active = true
    if wrapper then return end
    local get, set = rawget(_G, "getprinthandler"), rawget(_G, "setprinthandler")
    if type(get) ~= "function" or type(set) ~= "function" then return end
    had = get()
    if type(had) ~= "function" then had = nil return end
    local old = had
    wrapper = function(...)
        local text = ...
        if select("#", ...) ~= 1 or type(text) ~= "string" then return old(...) end
        local ok, t = pcall(Line, text)
        return old(ok and t or text)
    end
    set(wrapper)
end

function C.Stop()
    active = false
    if not wrapper then return end
    if getprinthandler() == wrapper then   -- nobody set a handler after us: put the old one back
        setprinthandler(had)
        wrapper, had = nil, nil
    end
end

-- For the checks: true while the wrapper changes lines.
function C.Active() return active and wrapper ~= nil end
C.Line = Line
