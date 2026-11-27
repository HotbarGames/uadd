-- UADD_ForeverQuestPins: the breadcrumb dialog's sentence, built whole.
-- Forever Quest Pins writes one line into the dialog's body: its words around two quest titles (gold) and the
-- second quest's zone (grey). The titles and the zone are game names: we write none (lesson 9). The line is
-- Ukrainian only when every name in it is: already Ukrainian on screen (the game or ClassicUA gave it), or
-- known to UADD.UALL.Quest / UADD.UALL.Zone (ClassicUA first, then UALL Forever). Otherwise the whole line stays
-- English, as Forever Quest Pins drew it. Its key is never written into L (Locale.lua, Lc.NAMES).
-- The body is a FontString of its own dialog: a post-hook on its SetText puts our line in; off and the hold
-- key put the English back while the line is still ours (lessons 15, 23).
local _, ns = ...
local U = UADD
local Lc = ns.Locale
local B = {}
ns.Breadcrumb = B

local KEY = "foreverquestpins"
local EN = "You accepted %s without completing its breadcrumb quest %s."
-- Since 1.1.9 its body is that sentence, a line break and this one (L words both). Like EN it is never in L
-- (Lc.NAMES): the body is ours only as a whole, so an English sentence never gets our second line (lesson 15).
local HINT = "Abandon it from the quest log to set a waypoint to the breadcrumb."
local QUEST = "Quest "                   -- its L["Quest "] .. id when it has no title
local GOLD, DIM, END = "|cffffd100", "|cff9d9d9d", "|r"
local CYR = "[\208-\211]"

local panel, body, busy, last, made = nil, nil, false, nil, 0   -- last: { English, ours } of the body
local shape

-- A quest title in Ukrainian, or nil.
function B.Title(t)
    if type(t) ~= "string" or t == "" or #t > 200 then return nil end
    if t:find(CYR) then return t end
    if t:sub(1, #QUEST) == QUEST and t:sub(#QUEST + 1):match("^%d+$") then
        local word = Lc.Word(QUEST)
        return word and (word .. t:sub(#QUEST + 1)) or nil
    end
    local A = U.UALL
    if type(A) ~= "table" or type(A.Quest) ~= "function" then return nil end
    local ok, ua = pcall(U.UALL.Quest, nil, t)
    return ok and type(ua) == "string" and ua ~= "" and ua or nil
end

local function Zone(z)
    if type(z) ~= "string" or z == "" or #z > 120 then return nil end
    if z:find(CYR) then return z end
    local A = U.UALL
    if type(A) ~= "table" or type(A.Zone) ~= "function" then return nil end
    local ok, ua = pcall(U.UALL.Zone, z)
    return ok and type(ua) == "string" and ua ~= "" and ua or nil
end

-- Forever Quest Pins names a quest with no title by L["Quest "] (our word) and its id. In a line that stays
-- English, that word would make a half line: here its English goes back ("Quest 5"). Only for a text known to be
-- the addon's English around names (lesson 27).
function B.Plain(t)
    local word = Lc.Word(QUEST)
    if type(t) ~= "string" or type(word) ~= "string" or word == QUEST then return t end
    local out, i = {}, 1
    while true do
        local a, b = t:find(word, i, true)
        if not a then break end
        out[#out + 1] = t:sub(i, a - 1) .. (t:find("^%d", b + 1) and QUEST or word)
        i = b + 1
    end
    out[#out + 1] = t:sub(i)
    return table.concat(out)
end

local function Gold(s) return s:match("^|cffffd100(.-)|r$") end

-- Our line for the English body, or nil (the whole line stays English).
function B.Make(text)
    local tpl = Lc.Template(EN)
    if not tpl or type(text) ~= "string" or #text > 600 then return nil end
    local nl, tail = text:find("\n", 1, true), nil
    if nl then                                 -- only its own second line after it, else whole English
        if text:sub(nl + 1) ~= HINT then return nil end
        tail = Lc.Template(HINT)
        if not tail then return nil end
        text = text:sub(1, nl - 1)
    end
    shape = shape or Lc.Shape(EN)
    local a, b = text:match(shape)
    if not a then return nil end
    local t1 = Gold(a)
    local u1 = t1 and B.Title(t1)
    if not u1 then return nil end
    local s2
    local t2, z = b:match("^|cffffd100(.-)|r |cff9d9d9d%((.-)%)|r$")
    if t2 then
        local u2, uz = B.Title(t2), Zone(z)
        if not (u2 and uz) then return nil end
        s2 = GOLD .. u2 .. END .. " " .. DIM .. "(" .. uz .. ")" .. END
    else
        t2 = Gold(b)
        local u2 = t2 and B.Title(t2)
        if not u2 then return nil end
        s2 = GOLD .. u2 .. END
    end
    local out = Lc.Put(tpl, GOLD .. u1 .. END, s2)
    return tail and (out .. "\n" .. tail) or out
end

local function Set(text)
    busy = true
    local ok, err = pcall(body.SetText, body, text)
    busy = false
    if not ok then U.Fault(KEY, err) end
    if ns.Screen then U.SafeCall(ns.Screen.Font, body) end     -- the font follows the text (Screen.lua)
    return ok and body:GetText() == text
end

local function OnBody(_, text)
    if busy then return end
    last = nil
    if not ns.WordsWanted() or not U.Plain(text) or #text > 600 then return end   -- a secret: no op on it
    shape = shape or Lc.Shape(EN)
    local en = text:match(shape) and B.Plain(text) or text   -- the line with no word of ours in it
    local uk = B.Make(text)
    if uk and Set(uk) then
        last = { en, uk }            -- off and the hold key give back whole English
        made = made + 1
    elseif en ~= text then
        Set(en)                      -- not ours: whole English, its untitled quest too (lesson 27)
    end
end

-- Find the dialog once it is made; hook its body.
function B.Catch()
    if body then return end
    local p = rawget(_G, "ForeverQuestPinsBreadcrumb")
    local fs = type(p) == "table" and p.body
    if type(fs) ~= "table" or type(fs.SetText) ~= "function" or type(fs.GetText) ~= "function" then return end
    panel, body = p, fs
    hooksecurefunc(fs, "SetText", Lc.Guard(OnBody))      -- gives English back too: not U.Safe (lesson 19)
    OnBody(fs, fs:GetText())
    -- Its buttons show L's words from the moment it is made: our font on them now, not at the next walk (lesson 46:
    -- a button's label draws boxes in the game's font objects).
    if ns.Screen and ns.Screen.Apply then U.SafeCall(ns.Screen.Apply) end
end

-- Its dialog is made on the first notice: hook the two ways one comes (a quest taken, /fqp breadcrumbtest).
local hooked = false
function B.Hook()
    if hooked then return end
    local fqp = Lc.Target()
    local br = fqp and fqp.Breadcrumbs
    if type(br) ~= "table" then return end
    hooked = true
    local function Later()
        U.SafeCall(B.Catch)
        if body or not (C_Timer and C_Timer.After) then return end
        -- A quest taken: it makes the dialog on its next frame. Ours runs right after that, then once more later.
        C_Timer.After(0, Lc.Guard(function()
            B.Catch()
            if not body then C_Timer.After(1, Lc.Guard(B.Catch)) end
        end))
    end
    for _, name in ipairs({ "OnQuestAccepted", "ShowPreview" }) do
        if type(br[name]) == "function" then hooksecurefunc(br, name, Lc.Guard(Later)) end
    end
    B.Catch()
end

-- On/off and the hold key: the body both ways, while it is still the text we know.
function B.Switch(want)
    if not body then return end
    local now = body:GetText()
    if want then
        if last and now == last[2] then return end
        OnBody(body, now)
    elseif last and now == last[2] then
        Set(last[1])
        last = nil
    end
end

function B.Panel() return panel end
function B.Count() return made end
