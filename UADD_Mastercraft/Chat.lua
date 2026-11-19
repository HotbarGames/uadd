-- UADD - Mastercraft: our words on Mastercraft's chat lines. Mastercraft writes them to the main chat
-- window with its name in front (in its blue, then two spaces). Only such a line changes: its name
-- stays, the rest is translated as one whole line (Words.lua), or stays English.
-- The chat window's AddMessage is wrapped once; "off" puts the game's own back when nobody wrapped it
-- after us (otherwise the wrapper stays and lets every line through as it is).

local _, ns = ...
local W = ns.Words
local C = {}
ns.Chat = C

local PREFIX = "|cff4da6ffMastercraft|r  "
local N = #PREFIX
local frame, orig, count = nil, nil, 0

local function Wrapped(self, msg, ...)
    if self == frame and type(msg) == "string" and ns.WordsWanted() and msg:sub(1, N) == PREFIX then
        local ok, uk = pcall(W.Translate, msg:sub(N + 1))
        if ok and uk then
            msg = PREFIX .. uk
            count = count + 1
        end
    end
    return orig(self, msg, ...)
end
C.Wrapped = Wrapped

function C.Install()
    if orig then return end
    local f = DEFAULT_CHAT_FRAME
    if type(f) ~= "table" or type(f.AddMessage) ~= "function" then return end
    frame, orig = f, f.AddMessage
    f.AddMessage = Wrapped
end

function C.Restore()
    if orig and frame and rawget(frame, "AddMessage") == Wrapped then
        frame.AddMessage = orig
        frame, orig = nil, nil
    end
end

function C.Count() return count end
