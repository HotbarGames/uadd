-- UADD - OneForAll: its chat lines and its tooltip lines, each through a core helper.
--   * Chat: OneForAll writes to the chat window itself (FLT.Msg: DEFAULT_CHAT_FRAME:AddMessage, never print()), so
--     the shared chat hook (U.ChatLines with its prefix, UADD/Lines.lua; off in an instance, lesson 35). A line that
--     starts with OneForAll's coloured prefix: the prefix stays, the rest is ours when it is a whole text of ours;
--     else the line is left as it is. Only lines with its prefix are read; a link in the rest is kept byte for byte
--     (a link whose text has no Ukrainian keeps the whole line English). Its addon messages are never touched.
--   * Tooltips: U.TipLines on GameTooltip. A line is tried only when its whole text is a key of ours (Words.Maybe, a
--     hash: lesson 12), and only when OneForAll's files wrote it (the stack).
-- It has no StaticPopupDialogs: its own confirm box is a frame of its own, walked by Screen.lua.
-- Any error leaves the English as it was.

local _, ns = ...
local U = UADD
local sub = string.sub

local C = {}
ns.Chat = C

local KEY = "oneforall"
-- FLT.Print: "|cff66ccff" .. (FLT.DISPLAY_NAME or "OneForAll") .. ":|r " .. msg.
local PREFIX = "|cff66ccffOneForAll:|r "
local FROM = "AddOns[/\\]OneForAll[/\\]"

local W = ns.Words

local function Prefix()
    local F = rawget(_G, "OneForAll")
    local name = type(F) == "table" and rawget(F, "DISPLAY_NAME")
    if type(name) == "string" and name ~= "" and #name < 40 then return "|cff66ccff" .. name .. ":|r " end
    return PREFIX
end

local function Line(text)
    local s = U.Plain(text)                      -- first, before any string op (lesson 35)
    if not s or not ns.WordsWanted() then return nil end
    local p = Prefix()
    if #s > #p and sub(s, 1, #p) == p then
        local uk = W.Translate(sub(s, #p + 1))
        return uk and (p .. uk) or nil
    end
    return nil
end
local chat                                        -- made at the first Install: OneForAll has set its name by then
local function Chat()
    if not chat then
        chat = U.ChatLines({ prefix = Prefix(), words = W, wanted = function() return ns.WordsWanted() end })
    end
    return chat
end

local tips = U.TipLines({ tips = { "GameTooltip" }, from = FROM, words = W,
    wanted = function() return ns.WordsWanted() end, missed = KEY })

function C.Install()
    if not ns.On() then return end
    U.SafeCall(Chat().Install)
    U.SafeCall(tips.Install)
end
function C.Sync() end
function C.Remove()
    if chat then U.SafeCall(chat.Restore) end
    U.SafeCall(tips.Restore)
end

function C.Prints() return chat and chat.Count() or 0 end
function C.Tips() return tips.Count() end
C.Line = Line                                     -- for the checks
