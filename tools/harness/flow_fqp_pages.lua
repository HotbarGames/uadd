-- Lua helpers for flow_fqp.py: Forever Quest Pins' settings pages under its main one (since 1.1) and its quest
-- tracker's sort and filter names and right-click menu. Run after flow_fqp.lua, before the game starts.
local H = HARNESS
local M = H.fqp
local CYR = "[\208-\211]"

-- Its pages under the main one: linked as the game links them (SettingsCategoryMixin: the parent's
-- GetSubcategories, the child's GetParentCategory, SetName), which the shared stand-in does not do.
M.subs = {}
Settings.RegisterCanvasLayoutSubcategory = function(parent, frame, name)
    local c, layout = Settings.RegisterCanvasLayoutCategory(frame, name)
    c.ID = {}                                    -- the game's subcategories are not found by their name
    c.parentCategory = parent
    c.GetParentCategory = function(s) return s.parentCategory end
    c.SetName = function(s, n) s.name = n end
    if type(parent) == "table" then
        parent.subcategories = parent.subcategories or {}
        table.insert(parent.subcategories, c)
        parent.GetSubcategories = function(s) return s.subcategories end
    end
    M.subs[#M.subs + 1] = c
    return c, layout
end

-- The client's right-click menus (Tracker.lua's ns.OpenTrackerMenu): the last one built, as its texts.
M.context = nil
MenuUtil.CreateContextMenu = function(_, gen)
    local items = {}
    local function Add(t) items[#items + 1] = { text = t } end
    local root = { SetTag = function() end, CreateDivider = function() end,
        CreateTitle = function(_, t) Add(t) end, CreateCheckbox = function(_, t) Add(t) end,
        CreateRadio = function(_, t) Add(t) end, Insert = function(_, d) Add(d and d.text) end }
    gen(nil, root)
    M.context = items
    return root
end

-- How many pages are under the main one, and how many of them are built.
function M.pages()
    local built = 0
    for _, c in ipairs(M.subs) do if c.frame and c.frame.built then built = built + 1 end end
    return #M.subs, built
end

-- The names of its pages in the settings tree, "|"-joined, and how many have Cyrillic.
function M.catNames()
    local out, n = {}, 0
    for _, c in ipairs(M.subs) do
        out[#out + 1] = c:GetName()
        if c:GetName():find(CYR) then n = n + 1 end
    end
    return table.concat(out, " | "), n
end

-- Its tracker's sort and filter names (Config.lua's tables, read by its drop-downs and Tracker.lua's menu):
-- "|"-joined, how many, how many with Cyrillic.
function M.trackerLabels()
    local fqp, out, n = rawget(_G, "ForeverQuestPins"), {}, 0
    for _, name in ipairs({ "TrackerSortLabels", "TrackerFilterLabels" }) do
        local t = fqp and fqp[name] or {}
        local keys = {}
        for k in pairs(t) do keys[#keys + 1] = k end
        table.sort(keys)
        for _, k in ipairs(keys) do
            out[#out + 1] = t[k]
            if t[k]:find(CYR) then n = n + 1 end
        end
    end
    return table.concat(out, " | "), #out, n
end

-- Its quest tracker's right-click menu, opened as Tracker.lua opens it: (texts "|"-joined, how many, Cyrillic).
function M.trackerMenu()
    M.context = nil
    local fqp = rawget(_G, "ForeverQuestPins")
    if not (fqp and fqp.OpenTrackerMenu and fqp.OpenTrackerMenu(UIParent)) then return "", 0, 0 end
    local out, n = {}, 0
    for _, d in ipairs(M.context or {}) do
        if d.text then
            out[#out + 1] = d.text
            if d.text:find(CYR) then n = n + 1 end
        end
    end
    return table.concat(out, " | "), #out, n
end
