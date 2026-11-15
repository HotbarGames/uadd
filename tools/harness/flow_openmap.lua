-- Helpers for flow_openmap.py: UADD_OpenMap on the OpenMap stand-in (tools/harness/openmap).
-- Reached from Python as HARNESS.om.
local H = HARNESS
local M = {}
H.om = M
local S = function() return OpenMapStandIn end

-- The texts the checks read, by short name.
local function Widgets()
    local v, c = S().view, S().card
    local side = v.side
    return {
        where = v.where, floor = v.floorName, back = v.back.Text, credit = v.credit, pin = v.pinNum,
        hint = v.hint, title = side.title, sub = side.sub, tab1 = side.tabs[1].Text, tab2 = side.tabs[2].Text,
        tab3 = side.tabs[3].Text, tab4 = side.tabs[4].Text, boss = side.rows[1].left,
        quest1 = side.rows[2].left, state1 = side.rows[2].right, quest2 = side.rows[3].left,
        state2 = side.rows[3].right, cardTitle = c.title, cardText = c.text,
    }
end

function M.text(key) return Widgets()[key]:GetText() end
function M.font(key) return Widgets()[key]:GetFont() end
function M.backWidth() return S().view.back:GetWidth() end

-- How many of the stand-in's texts are drawn in a font with Ukrainian letters, and how many there are.
function M.cyrCount()
    local n = 0
    for _, fs in ipairs(S().fontStrings) do if UADD.IsCyrFont((fs:GetFont())) then n = n + 1 end end
    return n, #S().fontStrings
end

-- Every stand-in text's font, "path size flags", joined: to compare before and after.
function M.fonts()
    local r = {}
    for _, fs in ipairs(S().fontStrings) do
        local p, size, flags = fs:GetFont()
        r[#r + 1] = ("%s %s %s"):format(tostring(p), tostring(size), tostring(flags))
    end
    return table.concat(r, "|")
end

-- A Razorfen Kraul quest whose Ukrainian title the Dungeon Journal module saved: id, en, uk.
function M.rfkQuest()
    local cache = UADD_DB and UADD_DB.modules and UADD_DB.modules.dj and UADD_DB.modules.dj.cache
    local fdj = rawget(_G, "ForeverDungeonJournal_NS")
    local d = fdj and fdj.DB and fdj.DB["Razorfen Kraul"]
    for _, q in ipairs(d and d.quests or {}) do
        local uk = cache and cache.Quest and cache.Quest[q.id]
        if type(uk) == "string" and uk:find("[\208\209]") then return q.id, q.name, uk end
    end
end

function M.cached(kind, en) return UADD.CachedName(kind, en) end

-- OpenMap's L: one text, and the whole table against our words.
-- Returns: how many of our words are in L, how many words we have, and whether every key reads
-- as OpenMap would without UADD (English, or the stand-in's own "Older pages").
local function Lc() return UADD.OpenMapLocale end
function M.L(key) return OpenMap.L[key] end
function M.lState()
    local L, ours, total, english = OpenMap.L, 0, 0, true
    for en, uk in pairs(Lc().entries) do
        if not Lc().Shared(en) then total = total + 1 end   -- shared ones come through L's __index
        if rawget(L, en) == uk then ours = ours + 1 end
        local want = en == "Older" and "Older pages" or en
        if L[en] ~= want then english = false end
    end
    return ours, total, english
end
-- Builds our words again, with `key` = `uk` instead (nil: as shipped). Returns whether it was skipped.
function M.build(key, uk)
    Lc().Build(key and { [key] = uk } or nil)
    return key and Lc().skipped[key] == true or false
end

local function Get(fs) return fs:GetText() end
local function FontOf(fs) local p, size = fs:GetFont() return ("%s %s"):format(tostring(p), tostring(size)) end

-- The menu, News and the Settings page: their texts, by short name.
function M.menu()
    S().OpenMenu()
    local m = S().menu
    return { tab1 = Get(m.tabs[1].Text), tab2 = Get(m.tabs[2].Text), row = Get(m.row), count = Get(m.count),
        close = Get(m.close.Text) }
end
function M.pinsTitle() return Get(S().pins.title) end
function M.finding() return UADD.OpenMapScreen.Finding() end
function M.shared(en) return Lc().Shared(en) end
-- A tooltip over the menu, then hidden: its line's text and font while shown, and the font after.
function M.tip()
    S().Tip()
    local fs = _G.GameTooltipTextLeft1
    local shown, font = Get(fs), FontOf(fs)
    local boxes = H.cyrBoxes and H.cyrBoxes() or {}
    local n = UADD.AceFont.Count("OpenMapTip")
    GameTooltip:Hide()
    return { text = shown, font = font, after = FontOf(fs), n = n, boxes = #boxes }
end
function M.menuText(key)
    local m = S().menu
    local w = { tab1 = m.tabs[1].Text, row = m.row, count = m.count }
    return Get(w[key])
end
function M.news()
    S().OpenNews()
    local f = S().news
    return { title = Get(f.title), version = Get(f.version), head = Get(f.head), kind = Get(f.kind),
        newer = Get(f.newer.Text), older = Get(f.older.Text), dungeon = Get(f.dungeon),
        dungeons = Get(f.dungeons), titleFont = FontOf(f.title),
        versionFont = FontOf(f.version) }
end
function M.newsText(key) return Get(S().news[key].Text or S().news[key]) end
function M.closeNews() S().news:Hide() end
function M.panel()
    local p = S().panel
    p:Show()
    return { title = Get(p.title), button = Get(p.button.Text), caught = UADD.OpenMapLocale ~= nil }
end
function M.closePanel() S().panel:Hide() end

-- Combat: on, or off with the event the game sends when it ends.
function M.combat(on)
    H.combat = on
    if not on then H.fire("PLAYER_REGEN_ENABLED") end
end

-- Opens the stand-in's view of Razorfen Kraul with two quests: one done, one in the log.
function M.open(title1, title2)
    WorldMapFrame:Show()
    S().Open({ name = "Razorfen Kraul", range = "24-33", zone = "The Barrens", boss = "Charlga Razorflank",
        quests = { { level = 30, title = title1, state = "done" }, { level = 29, title = title2, state = "log" } } })
end

function M.refont() S().Refont() end
function M.map(show) if show then WorldMapFrame:Show() else WorldMapFrame:Hide() end end
function M.close() S().Close() WorldMapFrame:Hide() end

function M.key(down)
    H.keys.SHIFT = down
    H.fire("MODIFIER_STATE_CHANGED", "LSHIFT", down and 1 or 0)
end
function M.wait(seconds) for _ = 1, math.ceil(seconds / 0.05 - 1e-6) do H.step(0.05) end end
function M.uadd(msg) return H.call("/uadd " .. msg, SlashCmdList.UADD, msg) end

-- Inside Razorfen Kraul (instance 47) with the World Map open: is the Dungeon Journal's map panel shown?
function M.insideRFK()
    local wasIn, wasInfo = IsInInstance, GetInstanceInfo
    IsInInstance = function() return true, "party" end
    GetInstanceInfo = function() return "Razorfen Kraul", "party", 1, "Normal", 5, 0, false, 47 end
    WorldMapFrame:Hide()
    WorldMapFrame:Show()
    H.fire("ZONE_CHANGED_NEW_AREA")
    H.pump(30)
    local fdj = rawget(_G, "ForeverDungeonJournalFrame")
    local panel = fdj and fdj.dungeonMapPanel
    local shown = type(panel) == "table" and panel.IsVisible and panel:IsVisible() or false
    return shown, function()
        IsInInstance, GetInstanceInfo = wasIn, wasInfo
        WorldMapFrame:Hide()
        H.fire("ZONE_CHANGED_NEW_AREA")
    end
end
