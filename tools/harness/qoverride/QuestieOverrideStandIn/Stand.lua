-- Harness stand-in (not any real addon): another addon that gives Questie a Ukrainian locale of its own at its
-- ADDON_LOADED, before UADD_Questie loads, as Quillshade 1.4.0 does (it loads first: no dependency on UADD). The first
-- addon to set QUESTIE_LOCALES_OVERRIDE wins, so UADD_Questie sees a conflict. Questie's tag name "Dungeon" then is
-- Ukrainian, and Questie cuts its first byte for the level letter (QuestieLib.lua:285): half a letter, a box.
-- The one word is ours (the glossary's «Підземелля»), keyed by Questie's own l10n key.

local NAME = ...
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, _, name)
    if name ~= NAME then return end
    self:UnregisterEvent("ADDON_LOADED")
    if QUESTIE_LOCALES_OVERRIDE == nil then
        QUESTIE_LOCALES_OVERRIDE = { locale = "ukUA", localeName = "Українська",
            translations = { ["Dungeon"] = "Підземелля" } }
    end
end)
