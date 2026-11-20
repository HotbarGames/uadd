-- UADD_ForeverQuestPins: its two chat lines that are not L words.
-- Its other chat lines are L words (Locale.lua writes them). Two are built in code around a value or a name:
--   * the What's New header at login: its own English around its version (a value), built whole;
--   * the abandoned-quest line: L's words around a quest title (a game name, lesson 9): Ukrainian only when
--     the title is (Breadcrumb.lua B.Title), else the whole line stays English.
-- Its chat prefix ("Forever Quest Pins:") stays English, as its name. One U.ChatLines on the prefix "|cff":
-- the colour and its name are tested first, so the game's lines never reach a look-up (lesson 12).
local _, ns = ...
local U = UADD
local Lc = ns.Locale

local TAG = "Forever Quest Pins:|r "
local HEAD = "What is new in %s:"
local GONE = "Abandoned %s."

local headShape, goneShape

local function Head(rest)
    local tpl = Lc.Template(HEAD)
    if not tpl then return nil end
    headShape = headShape or Lc.Shape(HEAD)
    local v = rest:match(headShape)
    if not v or not v:match("^[%w%.%-]+$") then return nil end
    return Lc.Put(tpl, v)
end

local function Gone(rest)
    goneShape = goneShape or Lc.Shape(GONE)
    local t = rest:match(goneShape)
    if not t then return nil end
    local tpl = Lc.Template(GONE)
    local uk = tpl and ns.Breadcrumb.Title(t)
    if uk then return Lc.Put(tpl, uk) end
    local en = ns.Breadcrumb.Plain(t)        -- not ours: whole English, its untitled quest too (lesson 27)
    return en ~= t and Lc.Put(GONE, en) or nil
end

local Words = {}
-- msg after "|cff": six colour digits, its name, then its text.
function Words.Translate(msg)
    if #msg > 400 or msg:sub(7, 6 + #TAG) ~= TAG then return nil end
    local colour, rest = msg:sub(1, 6), msg:sub(7 + #TAG)
    local uk
    if colour == "ffd100" then uk = Head(rest) elseif colour == "33ff99" then uk = Gone(rest) end
    return uk and (colour .. TAG .. uk) or nil
end
ns.ChatWords = Words

ns.Chat = U.ChatLines({ prefix = "|cff", words = Words, wanted = function() return ns.WordsWanted() end })
