-- Searching the journal in Ukrainian. FDJ lowers only A-Z before it compares, so "стратгольм"
-- would miss «Стратгольм». After each search FDJ draws (it sets the results' height), we look:
-- when the query has Cyrillic, we run FDJ's search once more with the query in lower case while
-- the names are handed out in lower case too (Content.lua, K.folding), then put the proper names
-- back on the rows. English searches are left as FDJ does them.
-- Item names are found in English only. FDJ reads them from the game's item data inside its own
-- local functions and matches one query against them, so the only way in would be to swap the
-- whole query for one English name; that would lose the dungeon, boss and quest matches, and a
-- part of a word matches many items with no English text in common.
-- Known limit: with more than 6 results for a Cyrillic query the mouse wheel may jump back to
-- the top, because FDJ clamps the scroll position to its own (unfolded) search first.

local _, ns = ...
local S = {}
ns.Search = S

local busy = false
local hooked = false

local function HasCyrillic(s)
    return type(s) == "string" and s:find("[\208\209\210]") ~= nil
end

local function Proper(text)
    local K = ns.Content
    if type(text) ~= "string" then return nil end
    if K.proper[text] then return K.proper[text] end
    local parts, any = {}, false
    for part in (text .. "  -  "):gmatch("(.-)  %-  ") do
        local p = K.proper[part]
        parts[#parts + 1] = p or part
        any = any or p ~= nil
    end
    return any and table.concat(parts, "  -  ") or nil
end

local function FixRows(container)
    for _, row in ipairs({ container:GetChildren() }) do
        for _, key in ipairs({ "name", "source" }) do
            local fs = row[key]
            if type(fs) == "table" and fs.GetText then
                local p = Proper(UADD.Plain(fs:GetText()))
                if p then fs:SetText(p) end
            end
        end
    end
end

-- FDJ's search with the query and the names in lower case, then the proper names on the rows.
-- `keep`: keep the scroll position FDJ just set (mouse wheel).
local function Folded(f, text, keep, container)
    local K = ns.Content
    busy, K.folding, K.proper = true, true, {}
    local ok, err = pcall(f.RefreshSearchResults, K.Fold(text), keep)
    K.folding = false
    if ok then ok, err = pcall(FixRows, container) end
    busy = false
    ns.Screen.Schedule()
    if not ok then error(err, 0) end
end

local function Again(container)
    local f = rawget(_G, "ForeverDungeonJournalFrame")
    local box = f and f.searchEditBox
    local text = box and UADD.Plain(box:GetText()) or ""
    if busy or not (ns.Lang.Active() and HasCyrillic(text)) then return end
    -- In combat FDJ's own results stay; the redraw after combat (Lang.Light) searches again.
    if InCombatLockdown and InCombatLockdown() then return ns.Lang.Light() end
    Folded(f, text, true, container)
end

-- The search again for `text` (a language switch). A Cyrillic query in our language runs only
-- the folded search: FDJ's own search first would be thrown away by Again at once.
function S.Refresh(text)
    local f = rawget(_G, "ForeverDungeonJournalFrame")
    local c = S.Container()
    if not (f and c and type(f.RefreshSearchResults) == "function") then return end
    if busy or not (ns.Lang.Active() and HasCyrillic(text)) then return f.RefreshSearchResults(text) end
    Folded(f, text, nil, c)
end

-- The results box under the search field (frame.searchResultsFrame). FDJ sets its height at the
-- end of every search, the "nothing found" one too.
function S.Container()
    local f = rawget(_G, "ForeverDungeonJournalFrame")
    local c = f and f.searchResultsFrame
    return type(c) == "table" and c.SetHeight and c or nil
end

function S.Install()
    if hooked then return true end
    local c = S.Container()
    local f = rawget(_G, "ForeverDungeonJournalFrame")
    if not (c and f and type(f.RefreshSearchResults) == "function") then return false end
    hooked = true
    hooksecurefunc(c, "SetHeight", function(self) UADD.SafeCall(Again, self) end)
    return true
end
