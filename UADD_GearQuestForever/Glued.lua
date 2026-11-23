-- UADD - GearQuest Forever: three texts GearQuest glues in code, each made whole (lessons 6, 27, 31).
--
-- Locale.lua gives our words through its locale table, so most texts are whole already. These three are not:
--   * Its guide's pages: each page is drawn whole from parts, and its own lookup is not asked for them. Our page is
--     keyed X.<hash> of the page as it is drawn (tools/gq_source.py). A post-hook on the bubble body's SetText puts
--     our page in right there, so GearQuest measures our text for the bubble's height. Only on a Cyrillic face
--     (Fonts.lua, read back): no face, no Ukrainian page.
--   * Its "no upgrade hunts for <slot>" chat line: our template around a slot label it made at load (English) and a
--     hint. Ours only when the slot has our word and the hint is ours (or empty); else the whole line goes back to
--     its English (its template and hint, learned by Locale.lua). Its slot table is never changed: other windows
--     glue it too.
--   * Its Orders rows: an item name, then its grey skill template (Rows.lua, with the helpers below).
-- On, held and off: the guide is laid out again and the Orders page painted again (by GearQuest itself), so each
-- shows whole English or whole Ukrainian. Lines already in the chat stay as they were printed.
-- Each hook runs under a plain pcall, counts its errors (U.Fault) and checks the state itself (lesson 19); any
-- error leaves GearQuest's own text. No English of GearQuest is stored here.

local _, ns = ...
local U = UADD

local G = {}
ns.Glued = G

local KEY = "gq"
local NONE = "L.7daf35e5"           -- its "no upgrade hunts" template (a text slot)
local made = 0

local function InForce() return ns.Loc.InForce() == true end

local function Guard(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if not ok then
            pcall(U.ReportError, tostring(err))
            pcall(U.Fault, KEY, tostring(err))
        end
    end
end

local function GetText(fs)
    if type(fs) ~= "table" or type(fs.GetText) ~= "function" then return nil end
    local ok, t = pcall(fs.GetText, fs)
    return ok and U.Plain(t) or nil
end

local function Shown(f)
    if type(f) ~= "table" or type(f.IsShown) ~= "function" then return false end
    local ok, yes = pcall(f.IsShown, f)
    return ok and yes == true
end

-- Our own SetText on a text: hooks of ours stay out, and what shows counts, not the call (lesson 26).
local busy = false
local function SetRaw(fs, text)
    busy = true
    local ok, err = pcall(fs.SetText, fs, text)
    busy = false
    if not ok then pcall(U.Fault, KEY, tostring(err)) end
    return GetText(fs) == text
end

-- A template of ours split at its one slot: the part before it and the part after it, or nil.
local function Split(t, slot)
    if type(t) ~= "string" then return nil end
    local a, b = t:find(slot, 1, true)
    if not a or t:find("%", b + 1, true) then return nil end
    return t:sub(1, a - 1), t:sub(b + 1)
end

local function Addon() return ns.Loc.Addon() end

G.InForce, G.Guard, G.GetText, G.Shown, G.SetRaw, G.Split = InForce, Guard, GetText, Shown, SetRaw, Split

-- ── The guide ─────────────────────────────────────────────────────────────────────────────────

local body, last = nil, nil          -- the bubble's body text, and { its English page, ours } on it now
local pages, npages = {}, 0          -- English page -> ours or false (13 pages; never more than 64 kept)

local function Page(en)
    local hit = pages[en]
    if hit ~= nil then return hit or nil end
    local ours = ns.Loc.Text(en)
    if npages >= 64 then pages, npages = {}, 0 end
    pages[en], npages = ours or false, npages + 1
    return ours
end

local function CyrFace(fs)
    pcall(ns.Fonts.Put, fs)
    local ok, face = pcall(fs.GetFont, fs)
    return ok and U.IsCyrFont(face)
end

local function OnBody(fs, text)
    if busy then return end
    text = U.Plain(text)
    last = nil
    if not text or text == "" or not InForce() then return end
    local ours = Page(text)
    if not ours or not CyrFace(fs) then return end
    if SetRaw(fs, ours) then
        last = { text, ours }
        made = made + 1
    elseif GetText(fs) ~= text then
        SetRaw(fs, text)                 -- its English page back whole
    end
end

local function Catch(guide)
    if body then return end
    local b = type(guide) == "table" and rawget(guide, "bubble")
    local fs = type(b) == "table" and rawget(b, "body")
    if type(fs) ~= "table" or type(fs.SetText) ~= "function" or type(fs.GetText) ~= "function" then return end
    body = fs
    hooksecurefunc(fs, "SetText", Guard(OnBody))
end

-- Its layout step: our hook goes on its body before it draws the page.
local function WrapGuide(g)
    local guide = rawget(g, "PortraitGuide")
    local own = type(guide) == "table" and rawget(guide, "Refresh")
    if type(own) ~= "function" then return end
    guide.Refresh = function(self, ...)
        local ok, err = pcall(Catch, self)
        if not ok then pcall(U.Fault, KEY, tostring(err)) end
        return own(self, ...)
    end
end

local function SyncGuide(on)
    local g = Addon()
    local guide = g and rawget(g, "PortraitGuide")
    if type(guide) ~= "table" then return end
    local b = rawget(guide, "bubble")
    if Shown(b) and type(guide.Refresh) == "function" then
        local ok, err = pcall(guide.Refresh, guide)          -- its text and its height follow
        if not ok then pcall(U.Fault, KEY, tostring(err)) end
    elseif on and body then
        OnBody(body, GetText(body))
    end
    -- Off and held: no page of ours stays, also when its layout failed or the bubble is hidden (lesson 23).
    if not on and body and last and GetText(body) == last[2] then
        if SetRaw(body, last[1]) then last = nil end
    end
end

-- ── The "no upgrade hunts" chat line ───────────────────────────────────────────────────────────

-- The line to print instead, or nil (print it as it is). `english`: its whole English only (after an error).
local function ChatLine(msg, english)
    msg = U.Plain(msg)
    local tpl = ns.AL[NONE]
    if not msg or #msg > 2000 or type(tpl) ~= "string" then return nil end
    local head, tail = Split(tpl, "%s")
    if not head or head == "" then return nil end
    local a = msg:find(head, 1, true)
    if not a or a > 64 then return nil end
    local from = a + #head
    local c = tail ~= "" and msg:find(tail, from, true) or nil
    if not c then return nil end
    local lead, slot, hint = msg:sub(1, a - 1), msg:sub(from, c - 1), msg:sub(c + #tail)
    local back = ns.Loc.Back()
    if not english then
        local ours = ns.Loc.Ours(slot) or (back[slot] and slot) or nil
        local hintOurs = hint == "" or back[hint] ~= nil
        if ours and hintOurs and not slot:find("|", 1, true) then
            if ours == slot then return nil end
            return lead .. head .. ours .. tail .. hint
        end
    end
    -- Whole English: its template and its hint, the slot as it made it (lesson 27).
    local en = back[tpl]
    if type(en) ~= "string" then return nil end
    local ok, line = pcall(string.format, en, back[slot] or slot)
    if not ok then return nil end
    return lead .. line .. (hint == "" and "" or (back[hint] or hint))
end
G.ChatLine = ChatLine

local function WrapChat(g)
    local own = rawget(g, "Chat")
    if type(own) ~= "function" then return end
    g.Chat = function(self, ...)
        if select("#", ...) == 1 and InForce() then
            local msg = (...)
            local ok, line = pcall(ChatLine, msg)
            if not ok then
                pcall(U.Fault, KEY, tostring(line))
                ok, line = pcall(ChatLine, msg, true)        -- its whole English, if that much still works
            end
            if ok and line then
                return own(self, line)
            end
        end
        return own(self, ...)
    end
end

-- ── Install and switch ─────────────────────────────────────────────────────────────────────────
-- Its Orders rows are Rows.lua's (loaded after this file, so called here only at run time).

local installed = false
function G.Install()
    if installed then return end
    local g = Addon()
    if not g then return end
    installed = true
    WrapGuide(g)
    WrapChat(g)
    local R = ns.Rows
    if R then
        local ok, err = pcall(R.Install)
        if not ok then pcall(U.Fault, KEY, tostring(err)) end
    end
end

-- After Locale.lua's switch (Module.lua, out of combat): the guide and the Orders page follow it.
function G.Sync(on)
    if not installed then return end
    local ok, err = pcall(SyncGuide, on)
    if not ok then pcall(U.Fault, KEY, tostring(err)) end
    if ns.Rows then
        ok, err = pcall(ns.Rows.Sync, on)
        if not ok then pcall(U.Fault, KEY, tostring(err)) end
    end
end

function G.Count() return made + (ns.Rows and ns.Rows.Count() or 0) end
