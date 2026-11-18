-- UADD - Questie: while the show-original key is held (UADD.OnOriginal, UADD/Original.lua),
-- Questie shows English; when it is let go, Ukrainian again (in UALLF's reverse mode the other way
-- round). Only on/off of the key does work.
--
-- Questie's l10n() looks the language up on every call (Localization/l10n.lua, SetUILocale and
-- GetUILocale), so we switch it to enUS and back. Its menus, messages and tooltip lines that are
-- built from now on are English. On top of that we redraw what can be seen:
--   a map or minimap pin tooltip under the mouse: shown again from the start, the way Questie
--                refreshes it (MapIconTooltip.lua, _RefreshTooltip): the "!" and "?" pin titles
--                are built when it is shown, so redrawing it (_Rebuild) would keep them Ukrainian;
--   quest names from QuestieLib:GetColoredQuestName (pin tooltips, Journey, quest lists):
--                the Ukrainian name is swapped for QuestieDB's English one.
-- Not switched: NPC, item and object names inside Questie's data (QuestieDB keeps its own
-- copies; changing its language is too heavy for a key press), and windows drawn earlier.
-- The tracker is always drawn in English (Tracker.lua), so the key never redraws it.
-- No item or unit tooltip is touched, so Shift still compares items.
--
-- Shift is also Questie's own key: held over a map pin it shows a fuller tooltip. With Shift as
-- our key that fuller tooltip turns English once the key has been held for the core's delay
-- (0.25 s). That is wanted: holding the key means "show the original", as in UALL. A quick
-- shift-click (hide a pin, post a quest link) ends before the delay, so it stays Ukrainian.

local _, ns = ...
local U = UADD
local L, N = ns.Locale, ns.Names
local O = { held = false }
ns.Original = O

local function Module(name)
    local ok, mod = pcall(function() return QuestieLoader:ImportModule(name) end)
    return ok and type(mod) == "table" and mod or nil
end

local function SetLocale(locale)
    local l10n = L.Questie_l10n()
    if l10n and l10n.SetUILocale then pcall(l10n.SetUILocale, l10n, locale) end
end

local function Current()
    local l10n = L.Questie_l10n()
    local ok, current = pcall(function() return l10n:GetUILocale() end)
    return ok and current or nil
end

-- ── Quest names ───────────────────────────────────────────────────────────────────────────────

function O.EnglishName(text, questId)
    local uk = type(questId) == "number" and N.maps.Quest and N.maps.Quest[questId]
    local fixed, raw = N.EnglishNames("Quest", questId)
    local en = type(fixed) == "string" and fixed ~= "" and fixed or raw
    if type(uk) ~= "string" or uk == "" or type(en) ~= "string" or en == "" then return text end
    local at = text:find(uk, 1, true)
    return at and (text:sub(1, at - 1) .. en .. text:sub(at + #uk)) or text
end

local nameDone
local function WrapQuestName()
    local lib = Module("QuestieLib")
    local original = lib and lib.GetColoredQuestName
    if nameDone or type(original) ~= "function" then return end
    nameDone = true
    lib.GetColoredQuestName = function(self, questId, ...)
        local text = original(self, questId, ...)
        if not O.held or type(text) ~= "string" then return text end
        local ok, en = pcall(O.EnglishName, text, questId)
        return ok and en or text
    end
end

-- ── What is on screen ─────────────────────────────────────────────────────────────────────────

local function Over(frame)
    if not (frame and frame.IsShown and frame:IsShown()) then return false end
    local compat = _G.QuestieCompat
    local ok, yes = pcall(function()
        if compat and compat.MouseIsOver then return compat.MouseIsOver(frame) end
        return frame:IsMouseOver()
    end)
    return ok and yes and true or false
end

-- Only a Questie pin's tooltip, only while the mouse is on the map or minimap. Shown again with
-- MapIconTooltip.ShowOnTooltip(icon, GameTooltip, owner, icons), as Questie's _RefreshTooltip
-- does; hiding it first gets past ShowOnTooltip's 0.05 s throttle (it only skips a shown tooltip).
function O.RebuildPinTooltip()
    local tip = GameTooltip
    local icon = tip and tip._owner
    if not (tip and tip:IsShown() and icon) then return false end
    local owner = tip._showOwner                    -- a path's tooltip belongs to the path
    if tip.GetOwner and tip:GetOwner() ~= (owner or icon) then return false end  -- not Questie's: leave it
    if not (Over(WorldMapFrame) or Over(Minimap)) then return false end
    local MIT = Module("MapIconTooltip")
    local show = MIT and MIT.ShowOnTooltip
    if type(show) == "function" and tip.ShownAsMapIcon and icon.data and icon.data == tip._showData then
        -- Showing a faded out icon does nothing: keep its tooltip as it is.
        local alpha = 1
        if icon.texture and icon.texture.GetVertexColor then alpha = select(4, icon.texture:GetVertexColor()) end
        if alpha == 0 and not owner then return false end
        local icons                                 -- pooled: drop icons reused since it was shown
        if tip._showIcons then
            icons = {}
            for _, listed in ipairs(tip._showIcons) do
                if listed.data and tip._showIconData and listed.data == tip._showIconData[listed] then
                    icons[#icons + 1] = listed
                end
            end
        end
        local QF = Module("QuestieFrame")
        if QF and QF.ResetHoverHighlights then pcall(QF.ResetHoverHighlights, icon) end
        tip:Hide()
        show(icon, tip, owner, icons)
        return true
    end
    -- An older Questie without ShowOnTooltip: redraw what it built.
    if type(tip._Rebuild) ~= "function" then return false end
    tip:Hide()
    tip:ClearLines()
    tip:SetOwner(owner or icon, "ANCHOR_CURSOR")
    tip:_Rebuild()
    tip:SetFrameStrata("TOOLTIP")
    tip:Show()
    return true
end

-- ── The key ───────────────────────────────────────────────────────────────────────────────────

function O.Changed(show)
    if show then
        if O.held or L.state ~= "on" or not L.IsActive() then return end
        WrapQuestName()
        O.held = true
        SetLocale("enUS")
    else
        if not O.held then return end
        O.held = false
        -- After "/uadd questie off" Questie already speaks the client's language: leave it.
        if L.state ~= "on" or Current() ~= "enUS" then return end
        SetLocale(L.LOCALE)
    end
    U.SafeCall(O.RebuildPinTooltip)
end

if U.OnOriginal then U.OnOriginal(O.Changed, "Questie") end
