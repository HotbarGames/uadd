-- UADD core: /uadd test for the UALL Forever routes (uall.lua). Per kind, how many sample names
-- UALL Forever answered and how long the probes took.

local U = UADD.UALL

local KINDS_IN_ORDER = { "zone", "npc", "item", "quest", "spell" }

local SAMPLES = {
    zone  = { "Elwynn Forest", "Stormwind City", "Durotar", "Orgrimmar", "Westfall",
              "Ironforge", "The Barrens", "Mulgore", "Teldrassil", "Tirisfal Glades" },
    npc   = { "Thrall", "Marshal Dughan", "Hogger", "Cairne Bloodhoof", "Gryan Stoutmantle",
              "Deputy Willem", "Lady Sylvanas Windrunner", "Magni Bronzebeard" },
    item  = { "Hearthstone", "Linen Cloth", "Copper Ore", "Light Leather", "Peacebloom",
              "Silverleaf", "Rough Stone", "Wool Cloth" },
    quest = { "Kobold Camp Cleanup", "A Threat Within", "Wolves Across the Border",
              "Brotherhood of Thieves", "Rest and Relaxation", "Investigate Echo Ridge",
              "The Defias Brotherhood", "Your Place In The World" },
    spell = { "Fireball", "Frostbolt", "Healing Touch", "Innervate", "Evocation",
              "Mana Tide Totem", "Dark Sacrifice", "Arcane Intellect" },
}

-- Goes straight to the probe (no cache), so the time is the real cost per lookup.
function U.SelfTest()
    local function say(msg) print("|cff4fc3f7UADD|r UALL: " .. msg) end
    local ok, err = pcall(function()
        local P = U.probe
        if not U.IsAvailable() then say("UALL Forever is not loaded, or its translation is switched off.") return end
        if InCombatLockdown and InCombatLockdown() then say("in combat: lookups wait until combat ends.") return end
        local s = P.Settings()
        if not s.reverseOriginal and P.KeyHeld(s) then say("let go of the show-original key and try again.") return end
        for _, kind in ipairs(KINDS_IN_ORDER) do
            local spec, list = P.KINDS[kind], SAMPLES[kind]
            if s[spec.gate] == false then
                say(("%s: off in UALL settings (%s)."):format(kind, spec.gate))
            elseif not P.Widget(spec) then
                say(("%s: no widget for this route (frame missing, or a cast on every bar)."):format(kind))
            else
                local hits, first = 0, nil
                local t0 = debugprofilestop()
                for _, en in ipairs(list) do
                    local ua = P.Raw(kind, en)
                    ua = ua and P.Clean(ua)
                    if ua and P.HasCyrillic(ua) then
                        hits = hits + 1
                        first = first or (en .. " -> " .. ua)
                    end
                end
                local ms = debugprofilestop() - t0
                say(("%s: %d/%d resolved, %.2f ms (%.3f ms each)%s"):format(kind, hits, #list, ms,
                    ms / #list, first and (", e.g. " .. first) or ""))
            end
        end
    end)
    if not ok then say("self-test error: " .. tostring(err)) end
end
