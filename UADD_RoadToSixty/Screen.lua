-- UADD - Road to Sixty: its windows (the map window, its panel and stats view with the compare window, the minimap
-- button, the What's New frame) and its canvas in the game's Settings window, walked by the core walker (U.Walk):
-- each text of theirs that is a whole text of ours shows our Ukrainian, in UADD's Cyrillic font; off and the hold key
-- give the English back where ours still shows (lesson 23).
--   * The named windows are roots; a frame Road to Sixty makes later under them (or by its name prefix) starts a
--     walk again (U.Walk's OnNewFrame), so windows made on first open are covered (lesson 2).
--   * The Settings canvas has no name. It is found through the game's Settings API by the category Road to Sixty
--     registers (its own title), never by a search over other addons' pages (lesson 30); when the game's Settings
--     window shows, the walker walks again.
--   * The player's own text is never changed: the walker skips text boxes and any text that already has Cyrillic,
--     and a character's name is kept as it is only inside a whole line of ours (Words.lua).
-- Any error leaves the English as it was (U.Walk runs each hook under a pcall that reports and counts).

local _, ns = ...
local U = UADD

local S = {}
ns.Screen = S

local ROOTS = { "RoadToSixtyJourneyFrame", "RoadToSixtyMinimapButton", "RoadToSixtyCompareWindow" }
-- Its What's New window stays English (lesson 43: never its news), also when made later by the name prefix.
local SKIP = { RoadToSixtyWhatsNew = true }
local CATEGORY = "Road to Sixty"                 -- the addon's own name, as it registers its Settings category

local canvas                                     -- its Settings canvas, once found

-- Its canvas in the game's Settings window: by its category, through the game's API, each step under a pcall.
-- When the game's API does not give it (no such category call, or no frame on it), as Forever Quest Pins does:
-- the canvas the Settings window holds (its Container, or the Container's SettingsCanvas) whose own name field
-- is the addon's title. Only that window's direct children: never a search over other addons' pages (lesson 30).
local function IsCanvas(f)
    return type(f) == "table" and rawget(f, "name") == CATEGORY and type(f.GetObjectType) == "function"
end
local function Container()
    local panel = rawget(_G, "SettingsPanel")
    local box = type(panel) == "table" and rawget(panel, "Container") or nil
    for _, holder in ipairs({ box, type(box) == "table" and rawget(box, "SettingsCanvas") or nil }) do
        if type(holder) == "table" then
            for _, c in ipairs(U.Children(holder)) do
                if IsCanvas(c) then return c end
            end
        end
    end
    return nil
end

local function Canvas()
    if canvas then return canvas end
    local ok, cat = false, nil
    if type(Settings) == "table" and type(Settings.GetCategory) == "function" then
        ok, cat = pcall(Settings.GetCategory, CATEGORY)
    end
    if not ok or type(cat) ~= "table" then cat = nil end
    local f
    local panel = rawget(_G, "SettingsPanel")
    if cat and type(panel) == "table" and type(panel.GetLayout) == "function" then
        local okL, layout = pcall(panel.GetLayout, panel, cat)
        if okL and type(layout) == "table" and type(layout.GetFrame) == "function" then
            local okF, fr = pcall(layout.GetFrame, layout)
            if okF and type(fr) == "table" then f = fr end
        end
    end
    if not f and cat and type(cat.frame) == "table" then f = cat.frame end
    if not f then f = Container(cat) end
    if f then canvas = f end
    return f
end

local function Roots()
    local list = {}
    for _, name in ipairs(ROOTS) do
        local f = rawget(_G, name)
        if type(f) == "table" then list[#list + 1] = f end
    end
    local c = Canvas()
    if c then list[#list + 1] = c end
    return list
end

-- Lesson 13: a label that shows a character's name stays as it is, also when the name reads like a text of ours.
-- Told apart by where it is, never by what it says:
--   * a map marker's label: its frame keeps the character's entry and this label (.entry, .label);
--   * a compare row's name under the stats chart: one line (no word wrap), its only point its top left on its
--     own frame's bottom left (the pane's other texts there wrap, or sit on a sibling);
--   * a row's first cell in the compare window: one line, its only point its top left on the window's top left
--     (the other cells sit by their top right). It shows the player's own row with a word of the addon's, so
--     that one word stays English there too.
local COMPARE = "RoadToSixtyCompareWindow"
local function NameLabel(fs)
    local okP, p = pcall(fs.GetParent, fs)
    if not okP or type(p) ~= "table" then return false end
    if rawget(p, "label") == fs and type(rawget(p, "entry")) == "table" then return true end
    if type(fs.CanWordWrap) ~= "function" or type(fs.GetPoint) ~= "function" then return false end
    local okW, wrap = pcall(fs.CanWordWrap, fs)
    if not okW or wrap ~= false then return false end
    local okN, n = pcall(fs.GetNumPoints, fs)
    if not okN or n ~= 1 then return false end
    local okA, point, rel, relPoint = pcall(fs.GetPoint, fs, 1)
    if not okA or point ~= "TOPLEFT" or rel ~= p then return false end
    if relPoint == "BOTTOMLEFT" then return true end
    return relPoint == "TOPLEFT" and p == rawget(_G, COMPARE)
end

local W = U.Walk({
    key = "rts",
    title = "Road to Sixty",
    On = function() return ns.On() end,
    Wanted = function() return ns.WordsWanted() end,
    roots = Roots,
    skip = SKIP,
    Lookup = function(en, fs)
        if type(fs) == "table" and NameLabel(fs) then return nil, false end
        return ns.Words.Translate(en)
    end,
    prefix = "RoadToSixty",
    font = true,
})
S.W = W

-- The game's Settings window: walk again when it shows (its canvas may be made then). Hooked once.
local settingsHooked = false
local function HookSettings()
    if settingsHooked then return end
    local panel = rawget(_G, "SettingsPanel")
    if type(panel) ~= "table" or type(panel.HookScript) ~= "function" then return end
    settingsHooked = true
    pcall(panel.HookScript, panel, "OnShow", ns.Guard(function()
        if ns.On() then W.Later() end
    end))
end

function S.Install()
    if not ns.On() then return end
    HookSettings()
    W.Install()
end
-- On: walk again; off or held: the English back where ours shows.
function S.Sync() W.Sync() end
function S.Remove()
    W.Sync()
    W.Remove()
    W.Forget()
end
function S.Later() W.Later() end
function S.Count() return W.Count() end
function S.Shown() return W.Shown() end
function S.Canvas() return Canvas() end
