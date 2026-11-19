-- Auto Potion's lines in the game's Key Bindings window, in Ukrainian.
--   * Each of its five bindings runs a command named after a macro. The window shows
--     _G["BINDING_NAME_" .. command] when it is set, else the command itself; Auto Potion's Bindings.lua
--     sets _G["BINDING_NAME_MACRO " .. macro] to that same command text. Both globals get our words
--     (the English is read from Auto Potion's own global at run time; none is kept here).
--   * Their header is the bindings' category; the window shows _G[category] when that is set, else the
--     category itself. It gets our words only when Words.lua has them and nobody set that global
--     (not checked against the game's own Key Bindings code offline: the real client must show it).
--   * The macro names themselves, the commands and the keys never change.
-- B.Apply(false) (the hold key, or the module off) puts back exactly what was there. The window reads
-- these names when it is opened or scrolled, so an open window shows the change on its next redraw.

local _, ns = ...
local B = {}
ns.Bindings = B

local MACROS = { "AutoPotion", "AutoBandage", "AutoFood", "AutoDrink", "AutoManaPotion" }
local saved = {}      -- global name -> { value } before ours (value may be nil)
local ours = {}       -- global name -> our words

local function Set(name, uk)
    if saved[name] == nil then saved[name] = { rawget(_G, name) } end
    ours[name] = uk
    _G[name] = uk
end

-- The bindings' category (one for all five), from the game's binding list, or nil.
local function Category(command)
    if type(GetNumBindings) ~= "function" or type(GetBinding) ~= "function" then return nil end
    for i = 1, GetNumBindings() do
        local cmd, cat = GetBinding(i)
        if cmd == command then return type(cat) == "string" and cat ~= "" and cat or nil end
    end
end

-- on: our words in place; off: what was there before.
function B.Apply(on)
    if not on then
        for name, keep in pairs(saved) do
            if rawget(_G, name) == ours[name] then _G[name] = keep[1] end
        end
        wipe(saved) wipe(ours)
        return
    end
    local command
    for _, macro in ipairs(MACROS) do
        local key = "BINDING_NAME_MACRO " .. macro
        local en = saved[key] and saved[key][1] or rawget(_G, key)
        local uk = type(en) == "string" and ns.Words.Text(en)
        if uk then
            command = command or en
            Set(key, uk)
            local own = "BINDING_NAME_" .. en
            local was = saved[own] and saved[own][1] or rawget(_G, own)
            if was == nil or was == en then Set(own, uk) end
        end
    end
    local cat = command and Category(command)
    local uk = cat and ns.Words.Text(cat)
    if uk and (saved[cat] or rawget(_G, cat) == nil) then Set(cat, uk) end
end

-- For the status line and the checks: how many names show our words now.
function B.Count()
    local n = 0
    for name, uk in pairs(ours) do if rawget(_G, name) == uk then n = n + 1 end end
    return n
end
