-- UADD - LootTriage: its own settings window, its one row in the game's Settings panel, and whose tooltip a
-- line is on (for Words.Maybe).
--
-- The window has no name. It is found as a child of UIParent by its fields (Refresh, pages, news, version)
-- when /lt runs, when the panel's button is clicked, and at the start. Each of its redraws (window.Refresh)
-- is followed by a walk of its texts: each English text we know gets ours, with our font read back (lesson 2);
-- a text the font cannot draw keeps its English. Its dropdowns and menus read row.choices() each time they
-- draw: that function is wrapped while we are on, and gives the names in Ukrainian only while our words are
-- wanted (the values stay the same); off gives the addon's own function back.
--   * Off and the hold key: each text goes back to its English only while it still shows ours (lesson 23).
--   * Its hooks run under ns.Guard, not U.Safe: they put the English back after an off for errors too
--     (lesson 19).
--   * The version line and the button that names the game's "New" are not touched.
--   * A forbidden child of UIParent is skipped (any call on one throws), each child under pcall.
-- The panel row: its initializer's name and tooltip are swapped both ways (lesson 15): the game reads them when
-- it draws the row and its tooltip (the row has no search tags). The row the game draws gets ours on its name and
-- button, with our font read back; on the hold key and off, the English goes back while ours shows, before the
-- font goes back. The gamepad fallback rows (its whole list in the panel) stay English.

local _, ns = ...
local U = UADD
local A = UADD.AceFont
local S = {}
ns.Screen = S

local W = ns.Words
local CYR = "[\208-\210]"
local APP = "LootTriage"
local MAXFRAMES = 4000                        -- frames one walk visits at most (its pages hold a few hundred)
local win, delete, searched, capped
local tipOwner, tipAns                        -- the last tooltip owner asked, and its answer
local rec, fonted, rows = {}, {}, {}
local panel = { init = nil, en = nil, click = nil, hooked = false, frames = {} }
local count = 0

local function Wanted() return ns.WordsWanted() end
local function Fighting() local ok, yes = pcall(InCombatLockdown) return ok and yes == true end
local function Forbidden(f) return type(f) ~= "table" or (f.IsForbidden and f:IsForbidden()) end

-- Our font on a text, read back; true when it can draw Cyrillic now.
local function Font(fs)
    if A and A.Set then pcall(A.Set, fs, APP) end
    local ok, path = pcall(fs.GetFont, fs)
    if ok and U.IsCyrFont(path) then fonted[fs] = true return true end
    return false
end
local function Unfont(fs) if fonted[fs] then fonted[fs] = nil if A and A.Back then pcall(A.Back, fs) end end end

S.Font, S.Unfont = Font, Unfont

-- ── Its window ────────────────────────────────────────────────────────────────────────────────

local function Text(fs)
    local t = fs:GetText()
    local r = rec[fs]
    if Wanted() then
        if r and t == r.uk then Font(fs) return end
        rec[fs] = nil
        if type(t) ~= "string" or t == "" then return end
        if t:find(CYR) then if not Font(fs) then Unfont(fs) end return end           -- a name from our choices (below)
        local uk = W.Translate(t)
        if not uk then return end
        fs:SetText(uk)
        if Font(fs) then rec[fs] = { en = t, uk = uk } count = count + 1 return end
        fs:SetText(t)
        Unfont(fs)
    else
        if r and t == r.uk then fs:SetText(r.en) end
        rec[fs] = nil
        Unfont(fs)
    end
end

-- Its choices with our names while wanted (a copy; the values are the same).
local function WrapRow(row)
    if rows[row] or type(row.choices) ~= "function" then return end
    local orig = row.choices
    local mine
    mine = function(...)
        local list = orig(...)
        if type(list) ~= "table" or not Wanted() or Fighting() then return list end
        if not ns.Menu.CanFont() then return list end            -- else boxes in its dropdown and menu
        local ok, out = pcall(function()
            local copy = {}
            for i, c in ipairs(list) do
                local e = {}
                for k, v in pairs(c) do e[k] = v end
                local uk = type(c[2]) == "string" and W.Translate(c[2])
                if uk then e[2] = uk end
                copy[i] = e
            end
            return copy
        end)
        return ok and out or list
    end
    rows[row] = { orig = orig, mine = mine }
    row.choices = mine
end

local function Walk(f, depth, seen)
    if depth > 10 or Forbidden(f) then return end
    if seen.n >= MAXFRAMES then
        if not capped then
            capped = true
            if U.debug then U.Print("LootTriage: обхід вікна зупинився на " .. MAXFRAMES .. " рамках") end
        end
        return
    end
    seen.n = seen.n + 1
    if f.IsProtected and f:IsProtected() then return end
    if f.GetObjectType and f:GetObjectType() == "EditBox" then return end
    if f == (win.news) then return end
    if type(f.row) == "table" and ns.On() then WrapRow(f.row) end   -- never again on the walk after an off
    for _, r in ipairs(U.Regions(f)) do
        if r ~= win.version and r.GetObjectType and r:GetObjectType() == "FontString" then Text(r) end
    end
    for _, c in ipairs(U.Children(f)) do Walk(c, depth + 1, seen) end
end

local function WalkAll() if win then Walk(win, 0, { n = 0 }) end end

local function IsWindow(c)
    return not Forbidden(c) and type(c.Refresh) == "function" and type(c.pages) == "table" and c.news ~= nil
        and c.version ~= nil
end

local function Find()
    if win then return win end
    for _, c in ipairs(U.Children(UIParent)) do
        local ok, yes = pcall(IsWindow, c)
        if ok and yes then
            win, tipOwner = c, nil
            hooksecurefunc(c, "Refresh", ns.Guard(WalkAll))
            if ns.News and ns.News.Watch then U.SafeCall(ns.News.Watch, c.news) end
            break
        end
    end
    return win
end

-- Once per show of the loot window while its delete button is not found (it may be made late).
local function FindDelete()
    if delete or searched or not LootFrame then return end
    searched = true
    for _, c in ipairs(U.Children(LootFrame)) do
        local ok, t = pcall(function() return not Forbidden(c) and c.GetNormalTexture and c:GetNormalTexture() end)
        if ok and t and t.GetAtlas and t:GetAtlas() == "128-RedButton-Delete" then delete, tipOwner = c, nil break end
    end
end

-- Is GameTooltip's owner its delete button, or a part of its window? (a few parent steps, no lookups; the
-- answer is kept for the same owner until the window or the button is found)
function S.OwnsTip()
    local tip = GameTooltip
    local o = tip and tip.GetOwner and tip:GetOwner()
    if not o then return false end
    if not delete then FindDelete() end
    if not delete and not win then return false end
    if o == tipOwner then return tipAns end
    local first, yes = o, false
    for _ = 1, 12 do
        if Forbidden(o) then break end                -- any call on one throws (as in Walk and Find)
        if o == delete or (win and o == win) then yes = true break end
        o = o.GetParent and o:GetParent()
        if not o then break end
    end
    tipOwner, tipAns = first, yes
    return yes
end

-- ── The panel row ─────────────────────────────────────────────────────────────────────────────

local function Init()
    if panel.init then return panel.init end
    local cat
    local sp = SettingsPanel
    if not sp or not sp.GetLayout or not sp.GetAllCategories then return nil end
    for _, c in ipairs(sp:GetAllCategories() or {}) do
        if c.GetName and c:GetName() == APP then cat = c break end
    end
    local layout = cat and sp:GetLayout(cat)
    local list = layout and layout.GetInitializers and layout:GetInitializers()
    for _, i in ipairs(list or {}) do
        local d = i.data or (i.GetData and i:GetData())
        if type(d) == "table" and type(d.buttonClick) == "function" and type(d.buttonText) == "string" then
            panel.init, panel.data = i, d
            panel.en = { name = d.name, buttonText = d.buttonText, tooltip = d.tooltip }
            break
        end
    end
    return panel.init
end

-- The drawn row's name and button text: ours (font read back) or the English, as wanted now.
local function RowFrame(frame, on)
    local en, list = panel.en, panel.frames[frame]
    if not en or not list then return end
    local b = frame.Button
    local fs2 = b and b.GetFontString and b:GetFontString()
    for _, p in ipairs({ { frame.Text, en.name }, { fs2, en.buttonText } }) do
        local fs, e = p[1], p[2]
        local uk = fs and type(e) == "string" and W.Exact(e)
        if uk then
            local t = fs:GetText()
            if on then
                if t == e then fs:SetText(uk) t = uk end
                if t == uk and Font(fs) then list[fs] = true
                elseif t == uk then fs:SetText(e) list[fs] = nil end
            else
                if t == uk then fs:SetText(e) end         -- the English first, then its font (no boxes)
                list[fs] = nil
                Unfont(fs)
            end
        end
    end
end

local function OnRow(frame, el)
    if el ~= panel.init then
        for fs in pairs(panel.frames[frame] or {}) do Unfont(fs) end
        panel.frames[frame] = nil
        return
    end
    panel.frames[frame] = panel.frames[frame] or {}
    RowFrame(frame, Wanted())
end

local function Rows(on)
    for frame in pairs(panel.frames) do pcall(RowFrame, frame, on) end
end

local function Panel(on)
    if not Init() then return end
    local d, en = panel.data, panel.en
    if not panel.hooked then
        panel.hooked = true
        panel.click = d.buttonClick
        d.buttonClick = function(...)
            panel.click(...)
            ns.Guard(function() if Find() then WalkAll() end end)()
        end
        local sl = SettingsPanel.GetSettingsList and SettingsPanel:GetSettingsList()
        if sl and sl.ScrollBox and ScrollUtil and ScrollUtil.AddInitializedFrameCallback then
            ScrollUtil.AddInitializedFrameCallback(sl.ScrollBox, function(_, frame, el)
                U.SafeCall(OnRow, frame, el)
            end, panel, false)
        end
    end
    for k, v in pairs(en) do
        local uk = on and type(v) == "string" and W.Exact(v)
        if uk then d[k] = uk
        elseif d[k] ~= v and type(d[k]) == "string" and d[k]:find(CYR) then d[k] = v end
    end
end

-- ── On, off, the hold key ─────────────────────────────────────────────────────────────────────

function S.Install()
    if not S.slash and type(SlashCmdList) == "table" and type(SlashCmdList.LOOTTRIAGE) == "function" then
        S.slash = true
        hooksecurefunc(SlashCmdList, "LOOTTRIAGE", ns.Guard(function() if Find() then WalkAll() end end))
    end
    if not S.loot and type(LootFrame) == "table" and LootFrame.HookScript then
        S.loot = true                                     -- its delete button may be made on a later show
        pcall(LootFrame.HookScript, LootFrame, "OnShow", function() if not delete then searched = false end end)
    end
    Find()
    FindDelete()
end

-- Now as it should be: ours or the English, in the window, its choices and the panel row.
function S.Sync()
    local on = Wanted()
    U.SafeCall(Panel, on)
    Rows(on)
    if not win then return end
    if win:IsShown() then pcall(win.Refresh) end
    WalkAll()
end

-- Off: everything back as the addon draws it.
function S.Remove()
    for row, r in pairs(rows) do
        if row.choices == r.mine then row.choices = r.orig end
    end
    rows = {}
    -- the panel's click stays wrapped (the game may hold it): it only finds the window
    U.SafeCall(Panel, false)
    Rows(false)
    if win then
        if win:IsShown() then pcall(win.Refresh) end
        WalkAll()
    end
    for fs in pairs(fonted) do Unfont(fs) end
    if A and A.Stop then pcall(A.Stop, APP) end
    count = 0
end

function S.Count() return count end
function S.Window() return win end
