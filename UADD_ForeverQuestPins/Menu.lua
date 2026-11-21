-- UADD_ForeverQuestPins: its checkboxes in the World Map's tracking menu.
-- Forever Quest Pins makes its list of menu labels once, when it loads (before us), so the labels are frozen
-- English, or frozen ours when it made them later. Each time the menu opens, its own callback adds a title
-- (its name, kept English) and its checkboxes. Ours runs after it and changes only the texts of the elements
-- after that title that are our word or its English: Ukrainian while wanted, English when off or held.
-- Ours is added right after its own (its TryRegisterWorldMapDropdown is safe to call again: it does nothing
-- once done), so ours always comes later. Any error turns the module off (U.Fault): English as it was.
local _, ns = ...
local U = UADD
local Lc = ns.Locale
local M = {}
ns.Menu = M

local KEY = "foreverquestpins"
local TITLE = "Forever Quest Pins"
local done = false

local function GetText(d)
    if MenuUtil and type(MenuUtil.GetElementText) == "function" then
        local ok, t = pcall(MenuUtil.GetElementText, d)
        if ok then return t end
    end
    return type(d) == "table" and rawget(d, "text") or nil
end

local function SetText(d, t)
    if MenuUtil and type(MenuUtil.SetElementText) == "function" then
        MenuUtil.SetElementText(d, t)
    elseif type(d) == "table" and type(rawget(d, "text")) == "string" then
        d.text = t
    end
end

-- The client's checkbox draws the text it was made with (MenuTemplates.CreateCheckbox keeps it in its own
-- initializer), not the description's text, so SetText alone changes nothing on screen. Our initializer runs
-- after its own, on the drawn line (button.fontString), before the menu measures its width. An error here
-- counts (U.Fault) and leaves the line as it drew it: English.
local function Drawer(new)
    return function(button)
        local ok, err = pcall(function()
            local fs = type(button) == "table" and button.fontString or nil
            if type(fs) ~= "table" then return end
            if type(fs.SetTextToFit) == "function" then fs:SetTextToFit(new) else fs:SetText(new) end
        end)
        if not ok then U.Fault(KEY, err) end
    end
end

local function Retext(_, root)
    if type(root) ~= "table" or type(root.EnumerateElementDescriptions) ~= "function" then return end
    local want = ns.WordsWanted()
    local after, left = false, 0
    for _, d in root:EnumerateElementDescriptions() do
        local t = GetText(d)
        if t == TITLE then
            after, left = true, 16                  -- its 13 checkboxes; elements of others come after
        elseif after and left > 0 and type(t) == "string" and t ~= "" then
            left = left - 1
            local new
            if want then new = Lc.Uk(t) else new = Lc.En(t) end
            if new and new ~= t and type(d.AddInitializer) == "function" then
                SetText(d, new)
                d:AddInitializer(Drawer(new))
            end
        end
    end
end

local function Callback(owner, root)
    local ok, err = pcall(Retext, owner, root)
    if not ok then U.Fault(KEY, err) end
end

function M.Install()
    if done then return end
    if not (Menu and type(Menu.ModifyMenu) == "function") then return end
    local fqp = Lc.Target()
    if not fqp or type(fqp.TryRegisterWorldMapDropdown) ~= "function" then return end
    local ok, yes = pcall(fqp.TryRegisterWorldMapDropdown)
    if not ok or not yes then return end
    done = true
    Menu.ModifyMenu("MENU_WORLD_MAP_TRACKING", Callback)
end
