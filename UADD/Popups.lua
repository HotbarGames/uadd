-- UADD.Popups: the game's StaticPopup questions of a translated addon in Ukrainian (docs/LESSONS3.md,
-- "Lesson 1 again, in Auctionator's popups"). One helper for every module whose addon has its own
-- StaticPopupDialogs entries.
--   * A module registers its dialogs (by name, or by a name start in any case) and the words of their
--     buttons: game globals (ACCEPT, CANCEL, ...) and the addon's own L words, each with a glossary id.
--   * Each button field (button1..4) of those entries holds our word while it still holds the English,
--     and the English again on the hold key and off, only while it still holds our word. So the game
--     itself shows our word. The globals are never written: the game and other addons read them too.
--     A global that is already Cyrillic (another addon set it) is left as it is, and so is its button.
--   * hooksecurefunc("StaticPopup_Show"): a shown dialog of ours gets our words on its text (the module's
--     own lookup) and buttons, and flips both ways on the hold key and off. The edit box is never touched.
--     The dialog grows or shrinks by the text's height change (SetHeight only). In combat only the fields;
--     a dialog shown then gets its buttons' English back on the hold key and off (Unrecorded).
--   * Every hook runs under UADD.Safe(key): 5 errors turn the module off, and Off puts the English back
--     under a plain pcall. The worst case is a dialog left English.
local U = UADD
local P = {}
U.Popups = P

local CYR = "[\208-\211][\128-\191]"
local FIELDS = { "button1", "button2", "button3", "button4" }
local specs = {}         -- module key -> spec
local order = {}         -- module keys, in register order
local open = {}          -- dialog frame -> { spec, which, text, parts = { { fs, en, uk } } }
local hookedHide = {}    -- dialog frame -> true once its OnHide is hooked
local installed = false

local function GL(id)
    local v = U.Glossary and U.Glossary.Text and U.Glossary.Text(id)
    return type(v) == "string" and v ~= "" and v or nil
end

-- { en, uk } while en is a whole English string and uk a different word; else nil.
local function Pair(en, id)
    if type(en) ~= "string" or en == "" or en:find(CYR) then return nil end
    local uk = GL(id)
    if not uk or uk == en then return nil end
    return { en, uk }
end

-- The word pairs of a spec now: its globals, then its own L words.
local function PairsOf(s)
    local out = {}
    for _, name in ipairs(s.gorder) do
        local p = Pair(rawget(_G, name), s.globals[name])
        if p then out[#out + 1] = p end
    end
    if s.L then
        for _, k in ipairs(s.oorder) do
            local ok, en = pcall(s.L, k)
            local p = ok and Pair(en, s.own[k]) or nil
            if p then out[#out + 1] = p end
        end
    end
    return out
end

local function Of(s, t)
    if type(t) ~= "string" then return nil end
    for _, p in ipairs(PairsOf(s)) do
        if t == p[1] or t == p[2] then return p[1], p[2] end
    end
    return nil
end

local function Ours(s, which)
    if type(which) ~= "string" then return false end
    if s.names[which] then return true end
    return s.prefix ~= nil and which:sub(1, #s.prefix):upper() == s.prefix
end

-- One entry's button fields: our word (want) or the English back while still ours.
local function One(s, d, want)
    local w = s.written[d]
    for _, f in ipairs(FIELDS) do
        local v = rawget(d, f)
        local rec = w and w[f]
        if want and type(v) == "string" then
            local en, uk = Of(s, v)
            if en and v == en then
                d[f] = uk
                w = w or {}
                s.written[d], w[f] = w, { en, uk }
            end
        elseif not want and rec then
            if v == rec[2] then d[f] = rec[1] end     -- still ours: the English back; else theirs stays
            w[f] = nil
        end
    end
end

local function Fields(s, want)
    local D = rawget(_G, "StaticPopupDialogs")
    if type(D) ~= "table" then return end
    for which, d in pairs(D) do
        if type(d) == "table" and Ours(s, which) then pcall(One, s, d, want) end
    end
end

local function Dialogs()
    local out, n = {}, tonumber(rawget(_G, "STATICPOPUP_NUMDIALOGS")) or 4
    for i = 1, n do
        local d = rawget(_G, "StaticPopup" .. i)
        if type(d) == "table" then out[#out + 1] = d end
    end
    return out
end

local function Button(d, i)
    local name = d.GetName and d:GetName() or ""
    local b = rawget(d, "button" .. i) or rawget(_G, name .. "Button" .. i)
    if not b and type(rawget(d, "ButtonContainer")) == "table" and type(d.ButtonContainer.Buttons) == "table" then
        b = d.ButtonContainer.Buttons[i]
    end
    return type(b) == "table" and b.GetFontString and b:GetFontString() or nil
end

-- Its text and buttons as the game set them: English, or ours (uk) where we know the words.
local function Show(d, rec, uk)
    local s = rec.spec
    local h0 = rec.text and rec.text:GetHeight()
    for _, p in ipairs(rec.parts) do
        local want, other = uk and p.uk or p.en, uk and p.en or p.uk
        if U.Plain(p.fs:GetText()) == other then p.fs:SetText(want) end
        local font = uk and s.fix or s.back
        if font then pcall(font, p.fs) end
    end
    local h1 = rec.text and rec.text:GetHeight()
    local h = d.GetHeight and d:GetHeight()
    if h and h0 and h1 and h1 ~= h0 then d:SetHeight(h + h1 - h0) end
end

local function Forget(d)
    local rec = open[d]
    if not rec then return end
    open[d] = nil
    Show(d, rec, false)
end

local function Wanted(s)
    local ok, yes = pcall(s.wanted)
    return ok and yes and true or false
end

local function ShowOne(s, which)
    if not Wanted(s) then return end
    if InCombatLockdown and InCombatLockdown() then return end
    for _, d in ipairs(Dialogs()) do
        if d:IsShown() and rawget(d, "which") == which then
            if open[d] then Forget(d) end      -- shown again: the game set its English again
            local name = d.GetName and d:GetName() or ""
            local text = rawget(d, "text") or rawget(_G, name .. "Text")
            local rec = { spec = s, which = which, text = text, parts = {} }
            for i, fs in pairs({ text, Button(d, 1), Button(d, 2), Button(d, 3), Button(d, 4) }) do
                local now = fs.GetText and U.Plain(fs:GetText())
                local en, uk
                if i > 1 then en, uk = Of(s, now) end    -- a button: the game's or the addon's word, or ours
                if not uk and s.text and now and not now:find(CYR) then
                    local ok, v = pcall(s.text, now)
                    if ok and type(v) == "string" and v ~= "" and v ~= now then en, uk = now, v end
                end
                if not uk and s.english and now and now:find(CYR) then   -- drawn in our words by the addon
                    local ok, v = pcall(s.english, now)
                    if ok and type(v) == "string" and v ~= "" and v ~= now and not v:find(CYR) then en, uk = v, now end
                end
                if uk then rec.parts[#rec.parts + 1] = { fs = fs, en = en, uk = uk } end
            end
            if rec.parts[1] then
                open[d] = rec
                if not hookedHide[d] and d.HookScript then
                    hookedHide[d] = true
                    d:HookScript("OnHide", function(self) pcall(Forget, self) end)
                end
                Show(d, rec, true)
            end
        end
    end
end

local function OnShow(which)
    for d, rec in pairs(open) do               -- the game put another question in one of ours
        if not d:IsShown() or rawget(d, "which") ~= rec.which then pcall(Forget, d) end
    end
    for _, key in ipairs(order) do
        local s = specs[key]
        if Ours(s, which) then s.onShow(which) end
    end
end

-- A dialog of ours that shows with no record (shown while off or in combat): look at it now.
local function Rescan(s)
    for _, d in ipairs(Dialogs()) do
        local which = rawget(d, "which")
        if not open[d] and d:IsShown() and Ours(s, which) then ShowOne(s, which) end
    end
end

-- A dialog of ours shown with no record (in combat) shows our words from the fields: on the hold key and off,
-- its buttons that still hold our word get the English back (SetText on a button's text only).
local function Unrecorded(s)
    for _, d in ipairs(Dialogs()) do
        if not open[d] and d:IsShown() and Ours(s, rawget(d, "which")) then
            for i = 1, 4 do
                local fs = Button(d, i)
                local t = fs and fs.GetText and U.Plain(fs:GetText())
                local en, uk = Of(s, t)
                if en and t == uk then fs:SetText(en) end
            end
        end
    end
end

local function SyncNow(s)
    local uk = Wanted(s)
    Fields(s, uk)
    if not installed and type(StaticPopup_Show) == "function" and hooksecurefunc then
        installed = true
        hooksecurefunc("StaticPopup_Show", function(which) pcall(OnShow, which) end)
    end
    for d, rec in pairs(open) do
        if rec.spec == s then Show(d, rec, uk) end
    end
    if uk and installed then Rescan(s) end
    if not uk then Unrecorded(s) end
end

-- spec: names = { WHICH = true } and/or prefix (a name start, any case); globals = { ACCEPT = "ui.accept" };
-- own = { Yes = "ui.yes" } with L(key) giving the addon's English; text(en) -> ours (the dialog text and
-- other buttons); english(uk) -> the addon's English for a text it drew in our words (so it flips back too);
-- wanted() -> our words now; fix(fs) / back(fs): the module's font on a shown line.
function P.Register(key, spec)
    local s = {
        key = key, names = spec.names or {}, prefix = spec.prefix and spec.prefix:upper() or nil,
        globals = spec.globals or {}, own = spec.own or {}, L = spec.L, text = spec.text, english = spec.english,
        wanted = spec.wanted or function() return false end, fix = spec.fix, back = spec.back,
        written = setmetatable({}, { __mode = "k" }), gorder = {}, oorder = {},
    }
    for name in pairs(s.globals) do s.gorder[#s.gorder + 1] = name end
    for k in pairs(s.own) do s.oorder[#s.oorder + 1] = k end
    table.sort(s.gorder) table.sort(s.oorder)
    s.onShow = U.Safe(key, function(which) ShowOne(s, which) end)
    s.sync = U.Safe(key, function() SyncNow(s) end)
    if not specs[key] then order[#order + 1] = key end
    specs[key] = s
end

-- On, the hold key, after combat: the fields and the shown dialogs as wanted() says now.
function P.Sync(key)
    local s = specs[key]
    if s then s.sync() end
end

-- Off (also after the module went off for errors): the English back, only where it is still ours.
function P.Off(key)
    local s = specs[key]
    if not s then return end
    pcall(Fields, s, false)
    for d, rec in pairs(open) do
        if rec.spec == s then pcall(Forget, d) end
    end
    pcall(Unrecorded, s)
end

-- The { en, uk } pairs now (for a module's own word tables), and the pair of one text.
function P.Pairs(key) return specs[key] and PairsOf(specs[key]) or {} end
function P.Of(key, t) if specs[key] then return Of(specs[key], t) end end

-- For the checks: shown dialogs with our words, and fields that hold our word now.
function P.Count(key)
    local n = 0
    for _, rec in pairs(open) do if rec.spec == specs[key] then n = n + 1 end end
    return n
end

function P.FieldCount(key)
    local s, n = specs[key], 0
    if not s then return 0 end
    for d, w in pairs(s.written) do
        for f, rec in pairs(w) do if rawget(d, f) == rec[2] then n = n + 1 end end
    end
    return n
end
