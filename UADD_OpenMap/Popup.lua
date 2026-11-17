-- OpenMap's questions in the game's StaticPopup dialogs ("OPENMAP_..." ones only: pins someone
-- shared, delete all pins, the report's second step, ClassicUI Forever's World map option) in
-- Ukrainian, in a font with Ukrainian letters. The same way as UADD_Attune/Popup.lua:
--   * hooksecurefunc("StaticPopup_Show"): after the game has shown the dialog, its text and button
--     labels get a font with Ukrainian letters (the client's standard font has none: squares). A
--     text OpenMap took from L as it asked is ours already; one it read while its files loaded
--     (the buttons, the report's text) gets our words here (Words.lua). StaticPopupDialogs is never
--     written, nor any field of the dialog. The edit box (the report's sentence) is never touched.
--   * Shared pins: only the first line is ours. The zones and the players' notes under it stay
--     exactly as they came, on, held or off.
--   * The dialog grows or shrinks by what the text's height changed (SetHeight only; the game's
--     StaticPopup_Resize writes fields, so it is not called).
--   * When the dialog hides (or the game shows another question in it), its fonts go back, so
--     other addons' questions in the same dialog look as they did.
--   * The hold key: OpenMap's English; the font stays only on a text that still has Ukrainian
--     letters (a player's note). "/uadd openmap off": the English and the fonts back. Nothing in
--     combat.

local _, ns = ...
local U = UADD
local P = {}
ns.Popup = P
if type(UADD) == "table" then UADD.OpenMapPopup = P end   -- for the checks (tools/harness)

local CYR = "[\208\209]"
local OWN_LINES = { OPENMAP_PINS_SHARED = 1 }   -- dialogs whose text is ours in its first lines only

local open = {}          -- dialog -> { which, text = FontString, parts = { { fs, en, uk } } }
local hookedHide = {}    -- dialog -> true once its OnHide is hooked
local installed = false

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

-- One shown text in English and in Ukrainian (the same text when only its font is ours), or nil.
-- `own`: how many first lines are ours; the rest is kept as it is.
local function Both(now, own)
    local head, rest = now, ""
    if own then
        local a = 0
        for _ = 1, own do
            a = now:find("\n", a + 1, true)
            if not a then break end
        end
        if a then head, rest = now:sub(1, a - 1), now:sub(a) end
    end
    local en, uk
    if head:find(CYR) then                       -- from L: our words already
        uk, en = head, ns.Locale.English(head) or ns.Words.English(head)
    else                                         -- read before we ran: English
        en, uk = head, ns.Locale.entries[head] or ns.Words.Text(head)
    end
    if en and uk and en ~= uk then return en .. rest, uk .. rest end
    if now:find(CYR) then return now, now end    -- a word we cannot read back: its font only
end

-- Its text and buttons with our words (uk) or OpenMap's English. `done`: the dialog is let go, so
-- every font goes back; else a text with Ukrainian letters keeps ours.
local function Show(d, rec, uk, done)
    local h0 = rec.text and rec.text:GetHeight()
    for _, p in ipairs(rec.parts) do
        local want, other = uk and p.uk or p.en, uk and p.en or p.uk
        local now = U.Plain(p.fs:GetText())
        if now == other and want ~= other then
            p.fs:SetText(want)
            now = want
        end
        if not done and ns.On() and type(now) == "string" and now:find(CYR) then
            ns.Fonts.Fix(p.fs)
        else
            ns.Fonts.Back(p.fs)
        end
    end
    local h1 = rec.text and rec.text:GetHeight()
    local h = d.GetHeight and d:GetHeight()
    if h and h0 and h1 and h1 ~= h0 then d:SetHeight(h + h1 - h0) end
end

-- The dialog as the game left it, and forgotten.
local function Forget(d)
    local rec = open[d]
    if not rec then return end
    open[d] = nil
    Show(d, rec, false, true)
end

local function OnShow(which)
    for d, rec in pairs(open) do               -- the game put another question in one of ours
        if not d:IsShown() or rawget(d, "which") ~= rec.which then U.SafeCall(Forget, d) end
    end
    if type(which) ~= "string" or which:sub(1, 8) ~= "OPENMAP_" or not ns.On() then return end
    if InCombatLockdown and InCombatLockdown() then return end
    for _, d in ipairs(Dialogs()) do
        if d:IsShown() and rawget(d, "which") == which then
            if open[d] then Forget(d) end      -- shown again: the game set its text again
            local name = d.GetName and d:GetName() or ""
            local text = rawget(d, "text") or rawget(_G, name .. "Text")
            local rec = { which = which, text = text, parts = {} }
            local list = { text, Button(d, 1), Button(d, 2), Button(d, 3) }
            for i = 1, 4 do
                local fs = list[i]
                local now = fs and fs.GetText and U.Plain(fs:GetText())
                local en, uk
                if type(now) == "string" and now ~= "" then en, uk = Both(now, i == 1 and OWN_LINES[which]) end
                if en then rec.parts[#rec.parts + 1] = { fs = fs, en = en, uk = uk } end
            end
            if rec.parts[1] then
                open[d] = rec
                if not hookedHide[d] and d.HookScript then
                    hookedHide[d] = true
                    d:HookScript("OnHide", function(self) U.SafeCall(Forget, self) end)
                end
                Show(d, rec, ns.WordsWanted())
            end
        end
    end
end

function P.Install()
    if installed or type(StaticPopup_Show) ~= "function" then return end
    installed = true
    hooksecurefunc("StaticPopup_Show", function(which) U.SafeCall(OnShow, which) end)
end

-- The hold key: English or ours on the shown dialogs.
function P.Sync()
    local uk = ns.WordsWanted()
    for d, rec in pairs(open) do U.SafeCall(Show, d, rec, uk) end
end

-- "/uadd openmap off": English and the fonts back.
function P.Restore()
    for d in pairs(open) do U.SafeCall(Forget, d) end
end

-- For the checks: how many dialogs show our words or fonts.
function P.Count()
    local n = 0
    for _ in pairs(open) do n = n + 1 end
    return n
end
