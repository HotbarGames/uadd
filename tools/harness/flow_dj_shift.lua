-- Helpers for flow_dj_shift.py: the show-original key on the search results and on a shut journal.
-- Reached as HARNESS.djs.
local H = HARNESS
local D = {}
H.djs = D

local function Frame() return rawget(_G, "ForeverDungeonJournalFrame") end

-- The shown result rows, as "name<TAB>source".
function D.rows()
    local f = Frame()
    local r = {}
    if not (f and f.searchResultsFrame and f.searchResultsFrame:IsVisible()) then return r end
    for _, row in ipairs(H.dj.buttons(f.searchResultsFrame)) do
        if row:IsShown() and row.name then
            r[#r + 1] = (row.name:GetText() or "") .. "\t" .. (row.source and row.source:GetText() or "")
        end
    end
    return r
end

-- Counts the searches started through the window's own entry (frame.RefreshSearchResults: every
-- search UADD starts goes through it) from now on.
function D.countSearches()
    local f = Frame()
    if not D.wrapped then
        local orig = f.RefreshSearchResults
        f.RefreshSearchResults = function(...) D.searches = D.searches + 1 return orig(...) end
        D.wrapped = true
    end
    D.searches = 0
end
function D.searchesSince() return D.searches end

function D.close() Frame():Hide() end
function D.open() Frame():Show() end

-- In combat (on) and out of it (off: the end-of-combat event, twice: nothing may stack).
function D.combat(on)
    H.combat = on
    if not on then
        H.fire("PLAYER_REGEN_ENABLED")
        H.fire("PLAYER_REGEN_ENABLED")
    end
end

-- The Favourites window (FDJ's Systems/Favourites.lua) with one test favourite in it.
local FAV = 999001
local function Favs()
    ForeverDungeonJournalCharacterDB = ForeverDungeonJournalCharacterDB or {}
    ForeverDungeonJournalCharacterDB.favouriteItems = ForeverDungeonJournalCharacterDB.favouriteItems or {}
    return ForeverDungeonJournalCharacterDB.favouriteItems
end
function D.favAdd(slot)
    Favs()[tostring(FAV)] = { id = FAV, name = "Test Axe", slot = slot, quality = 2,
        dungeon = "Razorfen Kraul", boss = "Charlga Razorflank" }
end
function D.favRemove() Favs()[tostring(FAV)] = nil end
function D.favToggle() ForeverDungeonJournal_NS.ToggleFavouritesWindow(Frame()) end
function D.favShow(on)
    local w = Frame().favouritesWindow
    if on then w:Show() else w:Hide() end
end
-- Title, empty-list text (set on every draw, shown or not), the test row's slot line, shown.
function D.favWords()
    local w = Frame().favouritesWindow
    if not w then return nil end
    local slot
    for _, row in ipairs(w.fdjRows or {}) do
        if row:IsShown() and row.fdjItemID == FAV then slot = row.slot:GetText() end
    end
    return w.fdjTitle:GetText(), w.fdjEmpty:GetText(), slot, w:IsShown()
end
