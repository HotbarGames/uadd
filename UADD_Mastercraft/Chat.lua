-- UADD - Mastercraft: our words on Mastercraft's chat lines. Mastercraft writes them to the main chat
-- window with its name in front (in its blue, then two spaces). Only such a line changes: its name
-- stays, the rest is translated as one whole line (Words.lua), or stays English.
-- The core chat hook (U.ChatHook, UADD/Lines.lua) wraps the chat window's AddMessage once for all modules;
-- "off" stops the hook, and the core puts the game's own back when no module needs it.

local _, ns = ...
local W = ns.Words
local C = {}
ns.Chat = C

local PREFIX = "|cff4da6ffMastercraft|r  "
local N = #PREFIX

local function Line(msg)
    if not UADD.Plain(msg) or not ns.WordsWanted() or msg:sub(1, N) ~= PREFIX then return nil end  -- lesson 35
    local uk = W.Translate(msg:sub(N + 1))
    return uk and PREFIX .. uk or nil
end

local hook = UADD.ChatHook({ marks = { PREFIX }, line = Line })

C.Install, C.Restore, C.Count, C.Active = hook.Start, hook.Stop, hook.Count, hook.Active
