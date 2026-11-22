-- UADD_WaypointUI route: Waypoint UI draws its texts with its own ui-kit. A ui-kit Text is a frame with a
-- child font string (frame.__Text); its SetText calls the raw font string method it kept at load, then fires
-- the frame event "OnTextChanged". So we never hook the font string metatable: each Text frame under the
-- named roots gets our handler through its own frame:HookEvent (tools offline test, local/new-addon/
-- WaypointUI.md "Stage 3 result": about 4 times cheaper than a scan, and no English shown between ticks).
-- Each handler compares with the last text first (lesson 12) and keeps {English, our Ukrainian} per frame,
-- so off and the hold key put back the English only where our Ukrainian still stands (lessons 15, 23).
local _, ns = ...
local U = UADD

local S = { roots = {} }
ns.Screen = S
local state = setmetatable({}, { __mode = "k" })    -- frame -> { en, uk, look }
local busy = false
local MAX_DEPTH, MAX_FRAMES = 14, 6000

local function TextOf(f)
    local fs = f.__Text
    local ok, t = pcall(fs.GetText, fs)
    return ok and U.Plain(t) or nil
end

-- The ui-kit's own SetText: it fits the frame to the text and runs its events again (we skip ours).
-- It can fail after it drew the text (its FitContent): what shows counts, and the error is ours to count,
-- so 5 of them turn the module off and the English comes back (lesson 26).
local function Put(f, text)
    busy = true
    local ok, err = pcall(f.SetText, f, text)
    busy = false
    if not ok then U.Fault("waypointui", err) end
    return ok or TextOf(f) == text
end

-- A map's name that ClassicUA or UALL Forever does not know yet (Words.lua Place: "wait"): ask again a few
-- times, a few seconds apart; the answer is not kept meanwhile. Then it stays English.
local tries, later = 0, false
local function Later()
    if later or tries >= 10 or not (C_Timer and C_Timer.After) then return end
    later, tries = true, tries + 1
    C_Timer.After(3, U.Safe("waypointui", function()
        later = false
        if ns.On() then S.Apply() end
    end))
end

local function Changed(f, text)
    if busy then return end
    local st = state[f]
    if not st then return end
    text = U.Plain(text) or TextOf(f)
    if text == nil or text == st.uk then return end
    st.en, st.uk, st.wait = text, nil, nil
    if not ns.WordsWanted() or not ns.Fonts.CanDraw(f) then return end
    local uk, wait          -- each frame keeps its last answer: the footer sets two lines on every tick (lesson
    -- 12). A map name's or a quest title's answer also hangs on the waypoint's and the player's map and the
    -- tracked quest, so those are in the key.
    local maps = (st.look == ns.Info or st.look == ns.Pinpoint) and ns.PlaceMaps() or nil
    if st.ken == text and st.klook == st.look and st.kmaps == maps then uk = st.kuk
    else
        uk, wait = st.look(text)
        if not wait then st.ken, st.kuk, st.klook, st.kmaps = text, uk, st.look, maps end
    end
    if wait then st.wait = true Later() end
    if uk and uk ~= text and Put(f, uk) then
        st.uk = uk
    elseif not uk and not wait and st.look ~= ns.Units and st.look ~= ns.Pinpoint and st.look ~= ns.Info
        and U.MissedOn() and text:find("%a%a%a") then
        U.Missed("waypointui", text, f.__Text)
    end
end
local OnChanged = U.Safe("waypointui", function(f, text) Changed(f, text) end)
local OnFormatted = U.Safe("waypointui", function(f) Changed(f, nil) end)

local function IsText(f)
    return type(f) == "table" and type(f.__Text) == "table" and type(f.HookEvent) == "function"
        and type(f.SetText) == "function" and type(f.__Text.GetText) == "function"
end

local function Hook(f, look)
    local st = state[f]
    if st then st.look = look return end
    state[f] = { look = look }
    ns.Fonts.Collect(f)
    f:HookEvent("OnTextChanged", OnChanged)
    f:HookEvent("OnFormattedTextChanged", OnFormatted)
    Changed(f, TextOf(f))                       -- what it shows already
end

-- Every ui-kit Text under `root` (forbidden-safe walk, U.Children), with a cap on depth and count.
local function Walk(root, look, skip)
    local seen, count = {}, 0
    local function Visit(f, depth)
        if depth > MAX_DEPTH or count > MAX_FRAMES or seen[f] or (skip and skip[f]) then return end
        seen[f], count = true, count + 1
        if IsText(f) then Hook(f, look) end
        for _, c in ipairs(U.Children(f)) do Visit(c, depth + 1) end
    end
    if type(root) == "table" then Visit(root, 0) end
    return count
end
S.Walk = Walk

-- What each root shows (local/new-addon/WaypointUI.md, stage 1 map 3). The player's names stay as typed
-- (lesson 13): the waypoint's destination line and the pinpoint's name change only when they are the pin's
-- map name or the tracked quest's title (Words.lua Place, Quest); the Navigator (step and destination names)
-- is never looked up.
local function TextOrUnits(t) return ns.Text(t) or ns.Units(t) end
local function Field(f, ...)
    for i = 1, select("#", ...) do
        if type(f) ~= "table" then return nil end
        f = f[select(i, ...)]
    end
    return f
end

function S.Scan()
    for _, name in ipairs({ "DistanceText", "ArrivalTimeText" }) do
        local f = Field(_G.WUIWaypointFrame, "Footer", name)
        if IsText(f) then Hook(f, ns.Units) end
    end
    local info = Field(_G.WUIWaypointFrame, "Footer", "InfoText")   -- the destination: a map or a quest
    if IsText(info) then Hook(info, ns.Info) end
    Walk(_G.WUIPinpointFrame, ns.Pinpoint)
    Walk(_G.WUISharedPrompt, ns.Text)
    Walk(_G.WUISharedInputPrompt, ns.Text)
    Walk(_G.WUISettingFrame, TextOrUnits)
end

-- The settings are built on their first show, after its OnShow, and each tab on its first pick: while
-- they are open a walk every second finds new Text frames (a frame already hooked costs one look-up).
local ticker
local function SettingsShown()
    if not ticker and C_Timer and C_Timer.NewTicker then
        ticker = C_Timer.NewTicker(1, U.Safe("waypointui", function()
            local f = _G.WUISettingFrame
            if not (f and f:IsShown()) or not ns.On() then
                if ticker then ticker:Cancel() ticker = nil end
                return
            end
            Walk(f, TextOrUnits)
        end))
    end
    if C_Timer and C_Timer.After then C_Timer.After(0, U.Safe("waypointui", S.Scan)) end
end

function S.Watch()
    for _, name in ipairs({ "WUISettingFrame", "WUISharedPrompt", "WUISharedInputPrompt" }) do
        local f = _G[name]
        if type(f) == "table" and f.HookScript and not S.roots[name] then
            S.roots[name] = true
            f:HookScript("OnShow", U.Safe("waypointui", name == "WUISettingFrame" and SettingsShown or S.Scan))
        end
    end
    S.Scan()
end

-- Off or the hold key: the English back where our Ukrainian still stands. On: our Ukrainian again.
-- only(f): just those frames (a font that lost its Cyrillic file).
function S.Restore(only)
    for f, st in pairs(state) do
        if st.uk and st.en and TextOf(f) == st.uk and (not only or only(f)) then
            local en = st.en
            st.uk = nil
            Put(f, en)
            if TextOf(f) ~= en then pcall(f.__Text.SetText, f.__Text, en) end  -- its SetText failed first
        end
    end
end

function S.Apply()
    for f, st in pairs(state) do
        local t = TextOf(f)
        if t and t ~= st.uk then Changed(f, t)
        elseif t and st.wait and st.en and ns.WordsWanted() then      -- ours, but a part was not known yet
            Changed(f, st.en)
        end
    end
end

function S.Count()
    local n, uk = 0, 0
    for _, st in pairs(state) do
        n = n + 1
        if st.uk then uk = uk + 1 end
    end
    return n, uk
end
