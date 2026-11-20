-- Words Scrap wrote once, when its parts loaded, switched both ways (lesson 15).
--   * Settings pages (Scrap_Config, Sushi OptionsGroups): each page keeps its name (title, also its name in
--     the game's settings list) and its line under the name (subtitle) in fields, and makes its header from
--     them on each rebuild. Ours goes in those fields; the English comes back on off. The settings list
--     shows a new page name the next time it is drawn.
--   * The help and patrons pages add buttons with English its code writes (keyed "Code." .. UADD.Hash):
--     those two pages get their own Add for as long as the module is on, which hands the button ours while
--     our words are wanted. Off, the page's own Add is back.
--   * The junk list window (Scrap_Merchant): its two tabs (an icon, then a word) and two buttons; a button's
--     width follows its text, as Scrap does.
--   * The tutorial (CustomTutorials): Scrap's own Register reads the table again. A step already open
--     keeps its text until the next step.
-- Item names, patron names, the copyright line and the game's own words are never changed.

local _, ns = ...
local U = UADD
local S = {}
ns.Screen = S

local GROUPS = { "Main", "Filters", "Help", "Credits" }
local WRAP = { Help = true, Credits = true }
local orig = {}        -- page -> { title, subtitle } in English
local count = 0

local function Scrap() local a = rawget(_G, "Scrap") return type(a) == "table" and a or nil end
local function Module(name)
    local a = Scrap()
    local m = a and a[name]
    return type(m) == "table" and m or nil
end

-- A name with an icon glued after it: (the words, the rest).
local function Split(s)
    local a, b = s:match("^(.-)(%s*|[TA].*)$")
    if a then return a, b end
    return s, ""
end

local function English(s)
    if type(s) ~= "string" then return s end
    local w, rest = Split(s)
    local en = ns.Swap.English(w)
    return en and (en .. rest) or s
end

local function Ukrainian(s)
    if type(s) ~= "string" then return s end
    local w, rest = Split(s)
    local ua = ns.Swap.Translate(w)
    return ua and (ua .. rest) or s
end

local function SetName(g, name)
    local O = Module("Options")
    local get = O and O.GetCategory
    if type(get) ~= "function" or type(name) ~= "string" then return end
    local ok, cat = pcall(get, g)
    if not ok or type(cat) ~= "table" or not cat.GetName or cat:GetName() == name then return end
    if cat.SetName then cat:SetName(name) else cat.name = name end
end

local function Wrap(g, on)
    if not on then
        if rawget(g, "Add") then rawset(g, "Add", nil) end
        return
    end
    if rawget(g, "Add") then return end
    local add = g.Add
    if type(add) ~= "function" then return end
    rawset(g, "Add", function(self, kind, text, ...)
        if kind == "RedButton" and type(text) == "string" and ns.WordsWanted() then
            text = ns.AL["Code." .. U.Hash(text)] or text
        end
        return add(self, kind, text, ...)
    end)
end

local function Pages(on)
    local O = Module("Options")
    if not O then return end
    for _, id in ipairs(GROUPS) do
        local g = rawget(O, id)
        if type(g) == "table" then
            local o = orig[g]
            if not o then
                o = { title = English(g.title), subtitle = English(g.subtitle) }
                orig[g] = o
            end
            g.title = on and Ukrainian(o.title) or o.title
            g.subtitle = on and Ukrainian(o.subtitle) or o.subtitle
            if g.title ~= o.title or g.subtitle ~= o.subtitle then count = count + 1 end
            SetName(g, g.title)
            if WRAP[id] then Wrap(g, on) end
            if g.IsVisible and g:IsVisible() and g.UpdateChildren then U.SafeCall(g.UpdateChildren, g, true) end
        end
    end
end

-- A text in its word form for now: ours (on) or Scrap's English (off).
local function Want(text, on)
    if type(text) ~= "string" then return nil end
    local en = ns.Swap.English(text) or text
    return on and (ns.Swap.Translate(en) or en) or en
end

local function Tab(tab, on)
    local t = tab and tab.GetText and tab:GetText()
    if type(t) ~= "string" then return end
    local icon, w = t:match("^(|T.-|t%s*)(.*)$")
    if not icon then icon, w = "", t end
    local want = Want(w, on)
    if want and want ~= w then tab:SetText(icon .. want) end
    if want ~= Want(w, false) then count = count + 1 end
end

local function Button(b, on)
    local t = b and b.GetText and b:GetText()
    local want = Want(t, on)
    if want and want ~= t then
        b:SetText(want)
        if b.GetTextWidth and b.SetWidth then b:SetWidth(b:GetTextWidth() + 20) end
    end
    if want and want ~= Want(t, false) then count = count + 1 end
end

local function List(on)
    local V = Module("Visualizer") or rawget(_G, "ScrapVisualizer")
    if type(V) ~= "table" then return end
    Tab(V.Tab1, on)
    Tab(V.Tab2, on)
    Button(V.ForgetButton, on)
    Button(V.ToggleButton, on)
end

local function Tutorial()
    local T = Module("Tutorials")
    local a = Scrap()
    if T and type(T.Register) == "function" and a and type(a.sets) == "table" then
        U.SafeCall(T.Register, T)
    end
end

local function Set(on)
    count = 0
    Pages(on)
    List(on)
end

function S.Apply() Set(true) end
function S.Restore() Set(false) end
S.Tutorial = Tutorial  -- after the table changed (Module.lua): Register reads it
function S.Count() return count end
