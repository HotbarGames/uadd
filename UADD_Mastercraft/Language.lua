-- UADD - Mastercraft: «Українська» in Mastercraft's own language menu (the globe button, top right).
--
-- Mastercraft lists its languages as rows: a flag, the name, a tick on the one in use. We add one more
-- row of the same shape under them. Picking it: Mastercraft on its English (its own English row is
-- pressed for that), and our words over it. Picking any other row: the module does nothing, that
-- language is whole, until «Українська» is picked again. The button shows "UA" while ours is in use.
--
-- Our choice lives in UADD_DB.modules.mastercraft.choice: nil (never picked: on, as before this menu
-- entry), "uk" or "other". Mastercraft's saved data is only read, never written (lesson 14).
-- A menu that does not look like the one we know is left as it was (lesson 19). Which language
-- Mastercraft draws in: LangCodes.lua.

local ADDON, ns = ...
local U = UADD
local L = ns.Lang

local done = setmetatable({}, { __mode = "k" })     -- menu -> our entry
local buttons = setmetatable({}, { __mode = "k" })  -- lang button -> its menu
local watched = setmetatable({}, { __mode = "k" })  -- Mastercraft's window: OnShow hooked
local pressing = false                             -- we press Mastercraft's English row ourselves

local FLAG_TOP = { 0, 0.34, 0.72 }                  -- the Ukrainian flag: blue over yellow
local FLAG_BOTTOM = { 1, 0.84, 0 }
local NAME = "Українська"

local function Safe(fn) return U.Safe and U.Safe("mastercraft", fn) or fn end
local function Active() return ns.On and ns.On() == true end

-- ── Finding the menu ──────────────────────────────────────────────────────────────────────────

-- The language button: a Button with .menu (a frame with .rows and :Paint) and .code (a FontString).
local function Menu(b)
    if type(b) ~= "table" or type(rawget(b, "menu")) ~= "table" or type(rawget(b, "Paint")) ~= "function" then return end
    local code = rawget(b, "code")
    if type(code) ~= "table" or type(code.SetText) ~= "function" then return end
    local menu = b.menu
    local rows = rawget(menu, "rows")
    if type(rows) ~= "table" or #rows < 2 or type(rawget(menu, "Paint")) ~= "function" then return end
    local en
    for _, r in ipairs(rows) do
        if type(r) ~= "table" or type(rawget(r, "code")) ~= "string" or type(rawget(r, "label")) ~= "table"
            or type(r.GetPoint) ~= "function" or type(r.HookScript) ~= "function" then return end
        if r.code == "en" then en = r end
        if r.code == "uk" then return end                       -- Mastercraft has its own Ukrainian now
    end
    if not en then return end
    return menu, rows, en
end

local function Find(root, depth, left)
    if depth > 4 or left[1] <= 0 then return end
    for _, kid in ipairs(U.Children(root)) do
        left[1] = left[1] - 1
        if Menu(kid) then return kid end
        local hit = Find(kid, depth + 1, left)
        if hit then return hit end
    end
end

-- ── Our row ───────────────────────────────────────────────────────────────────────────────────

-- A region's first point offsets (x, y): the last two numbers GetPoint gives, so the short form
-- SetPoint("LEFT", 7, 0) reads the same as the long one.
local function Offs(r)
    if type(r) ~= "table" or type(r.GetPoint) ~= "function" then return end
    local function Last(...)
        local n = select("#", ...)
        local x, y = select(n - 1 > 0 and n - 1 or 1, ...)
        if n >= 2 and type(x) == "number" and type(y) == "number" then return x, y end
    end
    return Last(r:GetPoint(1))
end
local function X(r) return (Offs(r)) end
local function Y(r) return select(2, Offs(r)) end

local function Copy(dst, src)                       -- a texture like one of Mastercraft's
    if type(src) ~= "table" or not src.GetObjectType or src:GetObjectType() ~= "Texture" then return false end
    local tex = src:GetTexture()
    if tex == nil then return false end
    dst:SetTexture(tex)
    dst:SetTexCoord(src:GetTexCoord())
    dst:SetVertexColor(src:GetVertexColor())
    dst:SetAlpha(src:GetAlpha())
    local w, h = src:GetSize()
    if w and w > 0 then dst:SetSize(w, h) end
    return true
end

local function Paint(menu, hover)
    local e = done[menu]
    if not e or not e:IsShown() then return end
    local on = Active()
    local rows = rawget(menu, "rows")
    local onC, offC
    for _, r in ipairs(rows) do                     -- the colours Mastercraft just used
        local tick = rawget(r, "tick")
        local shown = type(tick) == "table" and tick.IsShown and tick:IsShown()
        if shown then onC = { r.label:GetTextColor() } elseif r ~= hover then offC = offC or { r.label:GetTextColor() } end
    end
    if on then
        for _, r in ipairs(rows) do
            local tick = rawget(r, "tick")
            if r.code == "en" and type(tick) == "table" and tick.Hide then
                tick:Hide()
                if offC and r ~= hover then r.label:SetTextColor(unpack(offC)) end
            end
        end
    end
    local c = (on or hover == e) and onC or offC
    if c then e.label:SetTextColor(unpack(c)) end
    if e.tick then e.tick:SetShown(on) end
    e.hl:SetShown(hover == e)
end

local function ButtonPaint(b)
    if Active() then b.code:SetText("UA") end
end

-- Seen Mastercraft in another language (its menu, its language command, its setup): that is the player's
-- pick. Any of our words still left on its strings go (ns.End: each drawn again by Mastercraft itself).
-- Only when sure: a code it does not know is no pick of another language (it draws English then).
function L.Check()
    local db = ns.db
    local lang, sure = L.MastercraftLang()
    if db and db.choice ~= "other" and sure and lang ~= "en" then
        db.choice = "other"
        if ns.End then ns.End() end
    end
end

local function Pick(menu, en)
    local db = ns.db
    if not db then return end
    menu:Hide()
    db.enabled = true
    db.choice = "uk"
    if not L.MastercraftEnglish() then              -- Mastercraft's own English row does the switch
        local fn = en:GetScript("OnClick")
        if type(fn) == "function" then
            pressing = true
            local ok = pcall(fn, en, "LeftButton", false)
            pressing = false
            if not ok then return end
        end
    end
    if ns.Begin then ns.Begin() end
    L.Redraw()
end

local function Other(row)
    if pressing or not ns.db then return end
    ns.db.choice = "other"                          -- before Mastercraft switches, so our words are gone
    if ns.End then ns.End() end                     -- and its new language is whole
    L.Redraw()
end

local function Add(button, menu, rows, en)
    local first, last = rows[1], rows[#rows]
    local y1, y2, yl = Y(rows[1]), Y(rows[2]), Y(last)
    local w, h = first:GetSize()
    if not (y1 and y2 and yl and w and h and h > 0) then return end
    local step = y1 - y2
    if step <= 0 then return end
    local x = X(first) or 5

    local e = CreateFrame("Button", nil, menu)
    e:SetSize(w, h)
    e:SetPoint("TOPLEFT", menu, "TOPLEFT", x, yl - step)
    e.hl = e:CreateTexture(nil, "BACKGROUND")
    e.hl:SetAllPoints()
    if not Copy(e.hl, rawget(first, "hl")) then e.hl:SetColorTexture(1, 0.74, 0.36, 0.22) end
    e.hl:SetAllPoints()
    e.hl:Hide()
    -- the flag: two halves, the size and place of Mastercraft's flags
    local fw, fh, fx = 20, 13, 7
    local flag = rawget(first, "flag")
    if type(flag) == "table" and flag.GetSize then
        local a, b = flag:GetSize()
        if a and a > 0 and b and b > 0 then fw, fh = a, b end
        fx = X(flag) or fx
    end
    local top = e:CreateTexture(nil, "ARTWORK")
    top:SetColorTexture(FLAG_TOP[1], FLAG_TOP[2], FLAG_TOP[3], 1)
    top:SetSize(fw, fh / 2)
    top:SetPoint("BOTTOMLEFT", e, "LEFT", fx, 0)
    local bottom = e:CreateTexture(nil, "ARTWORK")
    bottom:SetColorTexture(FLAG_BOTTOM[1], FLAG_BOTTOM[2], FLAG_BOTTOM[3], 1)
    bottom:SetSize(fw, fh / 2)
    bottom:SetPoint("TOPLEFT", e, "LEFT", fx, 0)
    -- the name: a game font object (its family has Cyrillic letters), at the place of the others
    e.label = e:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    e.label:SetPoint("LEFT", e, "LEFT", X(first.label) or 35, 0)
    e.label:SetText(NAME)
    -- the tick: a copy of Mastercraft's; without one the colour alone says it is in use
    local tick = rawget(first, "tick")
    local t = e:CreateTexture(nil, "OVERLAY")
    if Copy(t, tick) then
        t:SetPoint("RIGHT", e, "RIGHT", X(tick) or -6, 0)
        e.tick = t
    else
        t:Hide()
    end
    t:Hide()
    -- a thin line above it, as between Mastercraft's rows
    local sep = menu:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(0.6, 0.5, 0.3, 0.35)
    sep:SetHeight(1)
    sep:SetPoint("LEFT", menu, "TOPLEFT", 8, yl - step + 1)
    sep:SetPoint("RIGHT", menu, "TOPRIGHT", -8, yl - step + 1)

    e:SetScript("OnEnter", Safe(function() menu:Paint(e) end))
    e:SetScript("OnLeave", Safe(function() menu:Paint() end))
    e:SetScript("OnClick", Safe(function() Pick(menu, en) end))
    menu:SetHeight(menu:GetHeight() + step)
    done[menu] = e
    buttons[button] = menu

    hooksecurefunc(menu, "Paint", Safe(Paint))
    hooksecurefunc(button, "Paint", Safe(function(b) L.Check() ButtonPaint(b) end))
    for _, r in ipairs(rows) do r:HookScript("PreClick", Safe(Other)) end
    return e
end

-- Mastercraft's window now: its language button, once per menu (a new window style builds a new one).
-- Mastercraft sets the window's own OnShow after it made it, and SetScript drops a hook put on before:
-- so ours goes on again after each such SetScript.
local OnShow = Safe(function() L.Install() end)
local rehooking = false
local function Watch(root)
    if type(root) ~= "table" or type(root.HookScript) ~= "function" or watched[root] then return end
    watched[root] = true
    root:HookScript("OnShow", OnShow)
    if type(root.SetScript) == "function" then
        hooksecurefunc(root, "SetScript", function(self, kind)
            if kind ~= "OnShow" or rehooking then return end
            rehooking = true
            pcall(self.HookScript, self, "OnShow", OnShow)
            rehooking = false
        end)
    end
end

function L.Install()
    if not ns.db or not ns.Ready or not ns.Ready() then return end
    local before = Active()
    L.Check()
    local root = rawget(_G, "MastercraftFrame")
    if type(root) ~= "table" then return end
    Watch(root)
    local b = Find(root, 1, { 400 })
    if not b or buttons[b] then return end
    local menu, rows, en = Menu(b)
    if menu then L.Learn(rows) end
    if menu and not done[menu] then Add(b, menu, rows, en) L.Redraw() end
    -- its codes now known: a saved code it does not know turned out to be English (ours on), or another
    -- language it really draws (the player's pick)
    L.Check()
    if not before and Active() and ns.Begin then ns.Begin() L.Redraw() end
end

-- The button and the list painted again (after on, off, or a pick).
function L.Redraw()
    for b, menu in pairs(buttons) do
        pcall(b.Paint, b)
        pcall(menu.Paint, menu)
    end
end

-- Mastercraft makes its window the first time it opens, after login: we learn of it by its name, one
-- compare per new frame of the game, and none once it is there.
if type(hooksecurefunc) == "function" then
    hooksecurefunc("CreateFrame", function(_, name)
        if name ~= "MastercraftFrame" then return end
        U.SafeCall(Watch, rawget(_G, "MastercraftFrame"))
    end)
end

function L.Entry()                                 -- for the harness: our row, if it is there
    for _, menu in pairs(buttons) do return done[menu] end
end
