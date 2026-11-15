-- Questie's quest list (tracker) gets the "UADD Cyrillic" font, so Ukrainian is not boxes.
-- Questie draws every tracker text (lines, header, timers, item counts, the auto-complete popup)
-- with LibSharedMedia fonts named by four settings (Modules/Options/QuestieOptionsDefaults.lua:
-- 126-133). The English client's "Friz Quadrata TT" has no Cyrillic.
--
-- Automatic: while the module is on, every setting still on that Latin-only default switches to
-- ours. A font the player picked is never touched. The old values wait in UADD_DB and come back
-- on "/uadd questie font off" (which also stops the automatic switch) and "/uadd questie off".
-- "/uadd questie font" switches all four, even picked ones. Blizzard's shared font objects are
-- never touched.

local _, ns = ...
local F = {}
ns.Font = F

local FIELDS = { "trackerFontHeader", "trackerFontZone", "trackerFontQuest", "trackerFontObjective" }
local DEFAULT = "Friz Quadrata TT"

local function Profile()
    local ok, profile = pcall(function() return Questie.db.profile end)
    return ok and type(profile) == "table" and profile or nil
end

local function RefreshTracker()
    ns.Tracker.Refresh()
end

function F.IsOn()
    local profile = Profile()
    return profile ~= nil and profile.trackerFontQuest == UADD.FONT_NAME
end

-- Switches the fields (only those on DEFAULT unless `all`). Returns how many changed, or nil
-- when the font or Questie's settings are missing.
local function Switch(db, all)
    local profile = Profile()
    if not profile or not UADD.RegisterFont() then return nil end
    db.fontBackup = type(db.fontBackup) == "table" and db.fontBackup or {}
    local n = 0
    for _, field in ipairs(FIELDS) do
        local current = profile[field]
        if current ~= UADD.FONT_NAME and (all or current == nil or current == DEFAULT) then
            db.fontBackup[field] = current
            profile[field] = UADD.FONT_NAME
            n = n + 1
        end
    end
    if n > 0 then RefreshTracker() end
    return n
end

-- Called at our ADDON_LOADED (before the tracker is first drawn) and again once Questie is
-- ready (Questie's one-time v9 migration resets its settings in between).
function F.Auto(db)
    if db.fontAuto == false then return end
    Switch(db, false)
end

function F.On(db, say)
    db.fontAuto = nil
    if not UADD.RegisterFont() then
        say("не вдалося знайти шрифт з кирилицею. Шрифти Questie не змінено.")
    elseif not Switch(db, true) then
        say("Questie ще не готовий. Спробуйте за хвилину.")
    else
        say("список завдань тепер зі шрифтом «" .. UADD.FONT_NAME .. "». Повернути старий: /uadd questie font off")
    end
end

-- Puts back what we changed. `say` is nil when "/uadd questie off" calls it.
function F.Off(db, say)
    if say then db.fontAuto = false end
    local profile = Profile()
    if not profile then
        if say then say("Questie ще не готовий. Спробуйте за хвилину.") end
        return
    end
    local backup = type(db.fontBackup) == "table" and db.fontBackup or {}
    for _, field in ipairs(FIELDS) do
        if profile[field] == UADD.FONT_NAME then profile[field] = backup[field] or DEFAULT end
    end
    db.fontBackup = nil
    RefreshTracker()
    if say then say("шрифти списку завдань повернуто, як були. Знову наш: /uadd questie font") end
end

-- One hint, once ever, when the player's own tracker font stayed: it may have no Cyrillic.
function F.MaybeHint(db, say)
    if db.fontHint or F.IsOn() then return end
    db.fontHint = true
    say("якщо в списку завдань квадратики замість літер, введіть /uadd questie font")
end
