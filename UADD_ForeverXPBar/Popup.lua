-- ForeverXP Bar's questions in the game's StaticPopup dialogs ("FOREVERXP..." ones only: reload the
-- UI, delete a profile, turn the challenge on or off) in Ukrainian.
--   * hooksecurefunc("StaticPopup_Show"): after the game has shown the dialog, its text and button
--     labels get our words and a font with Ukrainian letters (only texts Words.lua knows; the game's
--     own YES / NO / CANCEL stay). StaticPopupDialogs is never written, nor any field of the dialog.
--   * The dialog grows or shrinks by what the text's height changed (SetHeight only; the game's
--     StaticPopup_Resize writes fields, so it is not called).
--   * When the dialog hides (or the game shows another question in it), its fonts go back.
--   * The hold key and "/uadd fxpb off": the English and the fonts back. Nothing in combat.

local _, ns = ...
local U = UADD
local P = {}
ns.Popup = P

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

-- Its text and buttons as the game set them: English, or Ukrainian (uk) where we know the words.
local function Show(d, rec, uk)
    local h0 = rec.text and rec.text:GetHeight()
    for _, p in ipairs(rec.parts) do
        local want, other = uk and p.uk or p.en, uk and p.en or p.uk
        if UADD.Plain(p.fs:GetText()) == other then p.fs:SetText(want) end
        if uk then ns.Fonts.Fix(p.fs) else ns.Fonts.Back(p.fs) end
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
    Show(d, rec, false)
end

local function OnShow(which)
    for d, rec in pairs(open) do               -- the game put another question in one of ours
        if not d:IsShown() or rawget(d, "which") ~= rec.which then U.SafeCall(Forget, d) end
    end
    if type(which) ~= "string" or which:sub(1, 9) ~= "FOREVERXP" or not ns.WordsWanted() then return end
    if InCombatLockdown and InCombatLockdown() then return end
    for _, d in ipairs(Dialogs()) do
        if d:IsShown() and rawget(d, "which") == which then
            if open[d] then Forget(d) end      -- shown again: the game set its English again
            local name = d.GetName and d:GetName() or ""
            local text = rawget(d, "text") or rawget(_G, name .. "Text")
            local rec = { which = which, text = text, parts = {} }
            for _, fs in ipairs({ text, Button(d, 1), Button(d, 2), Button(d, 3) }) do
                local en = fs and fs.GetText and UADD.Plain(fs:GetText())
                local uk = en and ns.Words.Text(en)
                if uk then rec.parts[#rec.parts + 1] = { fs = fs, en = en, uk = uk } end
            end
            if rec.parts[1] then
                open[d] = rec
                if not hookedHide[d] and d.HookScript then
                    hookedHide[d] = true
                    d:HookScript("OnHide", function(self) U.SafeCall(Forget, self) end)
                end
                Show(d, rec, true)
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

-- "/uadd fxpb off": English and the fonts back.
function P.Restore()
    for d in pairs(open) do U.SafeCall(Forget, d) end
end

-- For the checks: how many dialogs show our words.
function P.Count()
    local n = 0
    for _ in pairs(open) do n = n + 1 end
    return n
end
