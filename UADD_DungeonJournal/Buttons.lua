-- The game's YES, NO and OKAY on the journal's own buttons (its question for a controller, its notes): it
-- writes the global once, when it makes the button, so ClassicUA or UALL Forever alone may leave it English
-- (docs/LESSONS3.md, lesson 1 again). Screen.lua's look gives each shown button here.
--   * Our word only while the button shows the global's English and our language is on (L.Active); English
--     again while held, with another language and off. The globals are never written, and one already
--     Cyrillic is left as it is. A text the journal has set since is never touched.
--   * A button too narrow for our word (its small OK, 40 wide) keeps its English (lesson 5).
--   * The same for texts the journal sets only when it opens a small window (LABELS: Edit Mode's menus, its
--     question, its note): a window left open flips both ways too (lesson 15), whole texts of ours only.
--   * English goes back before the font does (lesson 45), under a plain pcall (lesson 19): this also runs
--     after the module went off for errors.

local _, ns = ...
local U = UADD
local B = {}
ns.Buttons = B

local WORDS = { YES = "ui.yes", NO = "ui.no", OKAY = "ui.ok" }     -- game global -> glossary word
B.ROOM = { OKAY = 70 }     -- a button narrower than this keeps the English

local mine = {}            -- button or label -> { English, ours }

local function Turn(b, uk)
    local rec = mine[b]
    local now = U.Plain(b:GetText())
    if now ~= rec[1] and now ~= rec[2] then
        mine[b] = nil      -- the journal's own new text
    elseif now ~= (uk and rec[2] or rec[1]) then
        b:SetText(uk and rec[2] or rec[1])
    end
end

-- Short words only in their own menu (window name -> the journal's keys); ANY: whole sentences.
local LABELS = {
    ForeverDungeonJournalOrderMenu = { "RESET_ORDER" },
    ForeverDungeonJournalViewMenu = { "VIEW_DEFAULT", "VIEW_SMALL", "VIEW_LIST" },
}
local ANY = { "RESET_UI_CONFIRM", "EDIT_MODE_NEW" }

local function Find(keys, fs, text)
    local fdj = rawget(_G, "ForeverDungeonJournal_NS")
    for _, k in ipairs(keys or {}) do
        local en, uk = fdj.Locales.enUS[k], ns.uiStrings[k]
        if type(en) == "string" and type(uk) == "string" and (text == en or text == uk) then
            mine[fs] = { en, uk }
            return true
        end
    end
end

local function Label(f)
    local fs = rawget(f, "text")
    if type(fs) ~= "table" or not (fs.GetText and fs.SetText) then return end
    if not mine[fs] then
        local text = U.Plain(fs:GetText())
        if type(text) ~= "string" or text == "" then return end
        local up = f.GetParent and f:GetParent()
        local menu = LABELS[up and up.GetName and up:GetName() or ""]
        if not (Find(menu, fs, text) or Find(ANY, fs, text)) then return end
    end
    Turn(fs, ns.Lang.Active())
end

-- One shown frame (Screen.lua's Walk).
function B.Look(b)
    Label(b)
    if not (b.GetObjectType and b:GetObjectType() == "Button" and b.GetText) then return end
    local active = ns.Lang.Active()
    if mine[b] then return Turn(b, active) end
    if not active then return end
    local text = U.Plain(b:GetText())
    if type(text) ~= "string" or text == "" then return end
    for name, id in pairs(WORDS) do
        if text == rawget(_G, name) then
            local uk = not text:find("[\208-\210]") and U.Glossary.Text(id)
            if type(uk) == "string" and uk ~= "" and (b:GetWidth() or 0) >= (B.ROOM[name] or 0) then
                mine[b] = { text, uk }
                Turn(b, true)
            end
            return
        end
    end
end

local function Guard(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if ok then return end
        err = tostring(err)
        pcall(U.ReportError, err)
        pcall(U.Fault, "dj", err)
    end
end

-- Every text we changed, shown or not: the English back.
B.Back = Guard(function()
    for b in pairs(mine) do Turn(b, false) end
end)

-- The hold key and each change of language: the words of now.
B.Sync = Guard(function()
    local active = ns.Lang.Active()
    for b in pairs(mine) do Turn(b, active) end
end)

local restore = ns.Fonts.Restore
function ns.Fonts.Restore()
    B.Back()
    restore()
end

local forget = ns.Lang.Forget
function ns.Lang.Forget(...)
    forget(...)
    B.Sync()
end

-- For the checks: how many of these texts are ours now.
function B.Count()
    local n = 0
    for b, rec in pairs(mine) do if b:GetText() == rec[2] then n = n + 1 end end
    return n
end
