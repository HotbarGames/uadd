-- UADD - GearQuest Forever: its Orders rows, glued in code (lesson 31): an item name, then its grey skill template.
--
--   * The item is a game name: ClassicUA or UALL Forever name it (UADD.UALL.Item), we write none.
--   * Known: the row is ours, on UADD's Cyrillic face through the core helpers (lessons 18, 32; the row's own font
--     has no Cyrillic). Unknown: the row is its English, the skill template too (lesson 27), on its own font.
--   * A header ("asked by <name>", from its L, the name as typed: lesson 13) is drawn on GameFontNormal, which has no
--     Cyrillic: ours gets UADD's face while it shows Cyrillic, its own font back when it does not (lesson 32).
--   * A name ClassicUA has not settled yet ("wait") is never kept: English now, the page painted again later.
--   * On, held and off: GearQuest paints the page again and the hook after its paint follows (Glued.lua's Sync);
--     rows it did not paint get their English and their font back while they still show ours (lesson 23).
-- Uses Glued.lua's helpers (loaded before). Any error leaves the row as GearQuest painted it, or its English.

local _, ns = ...
local U = UADD
local G = ns.Glued

local R = {}
ns.Rows = R

local KEY = "gq"
local CYR = "[\208-\211]"
local SKILL = "L.3e6e7a4d"          -- its grey skill template (a value slot)
local SEP, CLOSE = "  |cffb0b0b0", "|r"   -- how a row glues the skill on
local GetText, SetRaw, Shown, Split, InForce = G.GetText, G.SetRaw, G.Shown, G.Split, G.InForce
local made = 0

local saved = setmetatable({}, { __mode = "k" })   -- row text -> its own font, while ours is on it
local rows = setmetatable({}, { __mode = "k" })    -- row text -> { its English, ours } shown now
local pending, tries, queued = false, 0, false

local function Item(name)
    if name == "" or #name > 120 or name:find("|", 1, true) or name:find("\n", 1, true) then return nil end
    if name:find(CYR) then return name end
    local A = U.UALL
    if type(A) ~= "table" or type(A.Item) ~= "function" then return nil end
    local ok, ua, wait = pcall(A.Item, name)
    if ok and type(ua) == "string" and ua ~= "" and ua:find(CYR) and not ua:find("|", 1, true) then return ua end
    return nil, ok and wait == true
end

-- One row as it is painted now (ours in force): ours or nil, its whole English, and "wait" (ask again later).
local function Row(text)
    local s = text:find(SEP, 1, true)
    if not s then
        local ua, wait = Item(text)
        return ua, text, wait
    end
    local head, tail = Split(ns.AL[SKILL], "%d")
    if not head then return nil, nil end
    local item, mid = text:sub(1, s - 1), text:sub(s + #SEP)
    if #mid < #CLOSE or mid:sub(-#CLOSE) ~= CLOSE then return nil, nil end
    mid = mid:sub(1, -#CLOSE - 1)
    if #mid <= #head + #tail or mid:sub(1, #head) ~= head or mid:sub(#mid - #tail + 1) ~= tail then
        return nil, nil                  -- not our skill template: its own line, left as it is
    end
    local num = mid:sub(#head + 1, #mid - #tail)
    if not num:match("^%d+$") then return nil, nil end
    local en
    local tpl = ns.Loc.Back()[ns.AL[SKILL]]
    if type(tpl) == "string" then
        local ok, skill = pcall(string.format, tpl, tonumber(num))
        if ok then en = item .. SEP .. skill .. CLOSE end
    end
    local ua, wait = Item(item)
    if ua and en then return ua .. SEP .. mid .. CLOSE, en, wait end
    return nil, en, wait
end
R.Row = Row

local function FontBack(fs)
    local was = saved[fs]
    if not was then return end
    saved[fs] = nil
    local ok, face = pcall(fs.GetFont, fs)
    if ok and U.IsCyrFont(face) then pcall(U.FontBack, fs, was) end
end

-- UADD's Cyrillic face on a row (through its own font object, lesson 18), read back; false: its own face kept.
local function CyrOn(fs)
    local ok, face = pcall(fs.GetFont, fs)
    if not ok then return false end
    if U.IsCyrFont(face) then return true end
    local okS, was = pcall(U.SaveFont, fs)              -- ours is not on it now: its own font (lesson 32 again)
    if not okS or type(was) ~= "table" then return false end
    saved[fs] = was
    local okC, yes = pcall(U.CyrOnLocked, fs)
    if okC and yes then return true end
    FontBack(fs)
    return false
end

local function PaintRow(fs)
    rows[fs] = nil
    local text = GetText(fs)
    if not text or text == "" then return FontBack(fs) end
    local uk, en, wait = Row(text)
    if wait then pending = true end
    if uk and CyrOn(fs) and SetRaw(fs, uk) then
        rows[fs] = { en, uk }
        made = made + 1
        return
    end
    if en and en ~= text then SetRaw(fs, en) end        -- the whole row its English
    FontBack(fs)
end

local function Page(orders)
    local page = type(orders) == "table" and rawget(orders, "page")
    local list = type(page) == "table" and rawget(page, "rows")
    return page, type(list) == "table" and list or nil
end

local function Orders()
    local g = ns.Loc.Addon()
    local orders = g and rawget(g, "Orders")
    return type(orders) == "table" and orders or nil
end

-- A name ClassicUA had not settled yet: the page painted again a few seconds later (one timer at a time, at most
-- 10 in a row while names keep waiting).
local function Retry()
    if queued or tries >= 10 or type(C_Timer) ~= "table" or type(C_Timer.After) ~= "function" then return end
    tries, queued = tries + 1, true
    local ok = pcall(C_Timer.After, 3, G.Guard(function()
        queued = false
        local orders = Orders()
        local page = Page(orders)
        if InForce() and Shown(page) and type(orders.Paint) == "function" then orders:Paint() end
    end))
    if not ok then queued = false end
end

local function AfterPaint(orders)
    local _, list = Page(orders)
    if not list then return end
    pending = false
    for i = 1, math.min(#list, 400) do
        local row = list[i]
        local fs = type(row) == "table" and rawget(row, "text")
        if type(fs) ~= "table" or not Shown(row) then
            -- hidden or odd: left alone
        elseif rawget(row, "itemId") ~= nil then
            if InForce() then PaintRow(fs) else rows[fs] = nil; FontBack(fs) end
        else                                   -- a header: its own words (ours from its L) on a face with no Cyrillic
            local t = GetText(fs)
            if not (InForce() and t and t:find(CYR) and CyrOn(fs)) then FontBack(fs) end
        end
    end
    if not pending then tries = 0 elseif InForce() then Retry() end
end

-- Its language button and list (GearQuestLanguageButton, GearQuestLanguageMenu) show our entry's name on
-- GameFontNormal and GameFontHighlight, which have no Cyrillic on Forever (lesson 32). A label that shows Cyrillic
-- gets UADD's face, on, held or off (a guard against boxes, lesson 39); one that does not gets its own face back.
local function LangFonts()
    local labels = {}
    local btn = rawget(_G, "GearQuestLanguageButton")
    if type(btn) == "table" and type(btn.GetFontString) == "function" then
        local ok, fs = pcall(btn.GetFontString, btn)
        if ok and type(fs) == "table" then labels[1] = fs end
    end
    local menu = rawget(_G, "GearQuestLanguageMenu")
    local list = type(menu) == "table" and rawget(menu, "rows")
    if type(list) == "table" then
        for i = 1, math.min(#list, 40) do
            local label = type(list[i]) == "table" and rawget(list[i], "label")
            if type(label) == "table" then labels[#labels + 1] = label end
        end
    end
    for _, fs in ipairs(labels) do
        local t = GetText(fs)
        if not (t and t:find(CYR) and CyrOn(fs)) then FontBack(fs) end
    end
end

local langHooked = false
local function LangHook()
    LangFonts()
    local btn = rawget(_G, "GearQuestLanguageButton")
    if langHooked or type(btn) ~= "table" or type(btn.SetText) ~= "function" then return end
    langHooked = true
    hooksecurefunc(btn, "SetText", G.Guard(function() LangFonts() end))   -- a language picked: its name again
end

function R.Install()
    local g = ns.Loc.Addon()
    local log = g and rawget(g, "Log")
    if type(log) == "table" and type(rawget(log, "CreateLanguageDropdown")) == "function" then
        hooksecurefunc(log, "CreateLanguageDropdown", G.Guard(LangHook))
    end
    pcall(LangHook)
    local orders = Orders()
    if not orders or type(rawget(orders, "Paint")) ~= "function" then return end
    hooksecurefunc(orders, "Paint", G.Guard(AfterPaint))
end

function R.Sync(on)
    local orders = Orders()
    local page = Page(orders)
    if Shown(page) and type(orders.Paint) == "function" then
        local ok, err = pcall(orders.Paint, orders)        -- GearQuest paints it again; our hook follows
        if not ok then pcall(U.Fault, KEY, tostring(err)) end
    end
    if on then pcall(LangFonts) return end
    -- Off and held: no row of ours stays (its paint failed, or the page is hidden).
    for fs, rec in pairs(rows) do
        if GetText(fs) == rec[2] then SetRaw(fs, rec[1]) end
        rows[fs] = nil
    end
    for fs in pairs(saved) do FontBack(fs) end
    pcall(LangFonts)                                      -- our entry's name keeps a face that draws it
end

function R.Count() return made end
