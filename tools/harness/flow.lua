-- Lua side of the flow checks (flow.py): small probes run inside the game session.
-- Strings are UTF-8 bytes here; flow.py converts them.
local H = HARNESS
local F = {}
H.flow = F

local function Ns() return H.ns.UADD_Questie end
local function Lib() return _G.LibQuestieDB end

-- Pumps frames until the name collection is idle. Returns frames used, idle.
function F.collect(limit)
    local N = Ns().Names
    return H.pump(limit or 200000, function() return N.Progress() == nil end, 0.05)
end

function F.l10n(key) return QuestieLoader:ImportModule("l10n")(key) end

-- Counts calls to LibQuestieDB.l10n.SetCorrection from now on.
function F.spy()
    F.setCorrection = 0
    local l10n = Lib().l10n
    local real = l10n.SetCorrection
    l10n.SetCorrection = function(...)
        F.setCorrection = F.setCorrection + 1
        return real(...)
    end
end

local function HasCyr(s) return type(s) == "string" and s:find("[\208\209]") ~= nil end

-- n English keys spread over a UALLF table whose values are plain Cyrillic (no $ tokens).
local function Spread(tbl, n)
    local keys = {}
    for k, v in pairs(tbl) do
        if type(k) == "string" and not k:find("[\128-\255]") and HasCyr(v) and not v:find("%$") then
            keys[#keys + 1] = k
        end
    end
    table.sort(keys)
    local out, step = {}, math.max(1, math.floor(#keys / n))
    for i = 1, #keys, step do
        out[#out + 1] = keys[i]
        if #out >= n then break end
    end
    return out
end

-- For each kind: samples asked through ns.UALL, and how many came back as UALLF's own text.
-- Returns { kind = { asked, same, firstMismatch } }.
function F.lookups(n)
    local U, src = Ns().UALL, H.ns.UALLF
    local out = {}
    local function check(kind, fn, list, want)
        local r = { asked = 0, same = 0 }
        for _, en in ipairs(list) do
            r.asked = r.asked + 1
            local got = fn(en)
            if got == want(en) then r.same = r.same + 1 elseif not r.bad then
                r.bad = tostring(en) .. " -> " .. tostring(got) .. " (UALLF: " .. tostring(want(en)) .. ")"
            end
        end
        out[kind] = r
    end
    check("zone", U.Zone, Spread(src.zoneNames, n), function(en) return src.zoneNames[en] end)
    check("npc", U.Npc, Spread(src.npcNames, n), function(en) return src.npcNames[en] end)
    check("item", U.Item, Spread(src.itemNames, n), function(en) return src.itemNames[en] end)
    -- Spells: UALLF's cast bar hook looks up its UI words first, then spell names.
    check("spell", U.Spell, Spread(src.spellNameEN, n),
        function(en) return src.uiStrings[en] or src.spellNameEN[en] end)
    -- Quests: UALLF keys by ID; the English title comes from QuestieDB.
    local ids, titles = {}, {}
    for id, q in pairs(src.quests) do
        local en = Lib().Quest.GetRaw(id, "name")
        -- UALLF resolves a bag title as UI text, item, NPC, then quest (its StorageHooks.lua): a quest whose
        -- English title is also one of those is never reached by title, by design (quest 91725 is an item too).
        local taken = type(en) == "string" and (src.uiStrings[en] or src.itemNames[en] or src.npcNames[en])
        if type(q.title) == "string" and HasCyr(q.title) and not q.title:find("%$") and type(en) == "string"
            and not taken then
            ids[#ids + 1] = id
            titles[id] = en
        end
    end
    table.sort(ids)
    local list, step = {}, math.max(1, math.floor(#ids / n))
    for i = 1, #ids, step do list[#list + 1] = ids[i] if #list >= n then break end end
    check("quest", function(id) return U.Quest(id, titles[id]) end, list, function(id) return src.quests[id].title end)
    return out
end

-- Made-up names: every route must say nil, and each Blizzard font string keeps text and colour. Another
-- addon's SetText hook on each string counts the calls made on that string itself (touched): the probe
-- calls the hook chain on a string of its own, so it must stay 0.
function F.madeUp()
    local U = Ns().UALL
    local strings = { ZoneTextString, SubZoneTextString, QuestFrame:GetTitleText(), GossipFrame:GetTitleText() }
    for i = 1, NUM_GROUP_LOOT_FRAMES do strings[#strings + 1] = _G["GroupLootFrame" .. i].Name end
    for i = 1, NUM_CONTAINER_FRAMES do strings[#strings + 1] = _G["ContainerFrame" .. i]:GetTitleText() end
    for _, bar in ipairs({ PetCastingBarFrame, FocusFrameSpellBar, TargetFrameSpellBar, OverlayPlayerCastingBarFrame,
        PlayerCastingBarFrame }) do strings[#strings + 1] = bar.Text end
    for i, fs in ipairs(strings) do
        fs:SetText("before " .. i)
        fs:SetTextColor(0.1, 0.2, 0.3, 0.4)
    end
    local touched = 0
    for _, fs in ipairs(strings) do
        hooksecurefunc(fs, "SetText", function(self) if self == fs then touched = touched + 1 end end)
    end
    local answers = {
        U.Zone("Zzyzx Harness Vale") or false, U.Npc("Zzyzx the Harnessed") or false,
        U.Item("Zzyzx Harness Pebble") or false, U.Quest(999999, "Zzyzx Harness Errand") or false,
        U.Spell("Zzyzx Harness Bolt") or false,
    }
    local kept = 0
    for i, fs in ipairs(strings) do
        local r, g, b, a = fs:GetTextColor()
        if fs:GetText() == "before " .. i and math.abs(r - 0.1) < 1e-6 and math.abs(g - 0.2) < 1e-6
            and math.abs(b - 0.3) < 1e-6 and math.abs(a - 0.4) < 1e-6 then
            kept = kept + 1
        end
    end
    return answers[1], answers[2], answers[3], answers[4], kept, #strings, answers[5], touched
end

-- Cast bars: one whose unit casts is never borrowed (UALLF would answer with that cast's name).
-- Returns the answer for Frostbolt while the pet casts, UALLF's Frostbolt, then the answer while all cast.
function F.castingBar()
    local U, src = Ns().UALL, H.ns.UALLF
    local frost, other = src.spellNameEN["Frostbolt"], nil
    for id, s in pairs(src.spells) do
        if type(s) == "table" and HasCyr(s.name) and s.name ~= frost then other = id break end
    end
    local real, casting = UnitCastingInfo, { pet = true }
    UnitCastingInfo = function(unit)
        if casting[unit] then return "Cast", nil, nil, 0, 1, false, nil, false, other end
    end
    local one = U.Spell("Frostbolt")
    casting = { player = true, pet = true, target = true, focus = true }
    local none, wait = U.Spell("Healing Touch")
    UnitCastingInfo = real
    return one or false, frost, none or false, wait or false
end

-- Total IDs QuestieDB lists for a kind.
function F.total(dt) return #Lib()[dt].GetAllIds() end

-- The first quest whose QuestieDB name is Ukrainian, with that name and the English one.
function F.ukQuest()
    for _, id in ipairs(Lib().Quest.GetAllIds()) do
        local name = Lib().Quest.Get(id, "name")
        if HasCyr(name) then return id, name, Lib().Quest.GetRaw(id, "name") end
    end
end

function F.questName(id) return Lib().Quest.Get(id, "name") end

-- The four tracker font settings.
function F.fonts()
    local p = Questie.db.profile
    return p.trackerFontHeader, p.trackerFontZone, p.trackerFontQuest, p.trackerFontObjective
end

-- A fresh name in combat: nil, plus the "not now" flag.
function F.combatLookup(en)
    H.combat = true
    local ua, wait = Ns().UALL.Item(en)
    return ua or false, wait or false
end

function F.list(t)
    local out = {}
    for k in pairs(t) do out[#out + 1] = tostring(k) end
    table.sort(out)
    return table.concat(out, ", ")
end

-- ── Questie options tab header ("Questie • <tab name>") ──────────────────────────────────────

-- The tab name FontString: the one anchored to the "•" (QuestieOptionsEngine.lua:183-191). Since
-- Questie 12.8 it is on canvas.content, the frame the build puts everything on; before, on the canvas.
local function Subtitle(canvas)
    local regions = { canvas:GetRegions() }
    if canvas.content then
        for _, r in ipairs({ canvas.content:GetRegions() }) do regions[#regions + 1] = r end
    end
    for _, r in ipairs(regions) do
        if r:GetObjectType() == "FontString" then
            local _, rel = r:GetPoint(1)
            if type(rel) == "table" and rel.GetText and rel:GetText() == "\226\128\162" then return r end
        end
    end
end

-- Shows a Questie options canvas (first opening Questie's own window when popup) and pumps until
-- its header is drawn and our font had time to arrive. Returns the tab name's font object name,
-- its text, its colour and its font file.
function F.header(name, popup)
    if popup then QuestieLoader:ImportModule("QuestieOptionsEngine"):ShowFrame() end
    local canvas = rawget(_G, name)
    if not canvas then return "no canvas" end
    canvas:Show()
    H.pump(100, function()
        local s = Subtitle(canvas)
        return s and s:GetFontObject() ~= Game13Font
    end, 0.05)
    local s = Subtitle(canvas)
    if not s then return "no header" end
    local o = s:GetFontObject()
    return o and o:GetName() or "none", s:GetText(), ("%.2f %.2f %.2f %.2f"):format(s:GetTextColor()),
        (s:GetFont())
end

-- A settings canvas Questie makes after its OnReady (when we scanned), with its header built the way
-- Questie 12.8 builds one (QuestieOptionsEngine.lua:172-193): on canvas.content, the tab name after
-- the "•" in Game13Font. how = "panel": the game's settings window opens, then the canvas shows;
-- "select": the window is already open and the canvas's category is picked. Returns the tab name's
-- font object name and font file.
function F.lateCanvas(key, how)
    local E = QuestieLoader:ImportModule("QuestieOptionsEngine")
    if how == "select" then SettingsPanel:Show() else SettingsPanel:Hide() end
    E.tabs[key] = E.tabs[key] or {}
    local canvas = CreateFrame("Frame", "QuestieOptionsTab_Blizz_" .. key, UIParent)
    canvas:Hide()
    canvas.content = CreateFrame("Frame", nil, canvas)
    local title = canvas.content:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    title:SetText("Questie")
    local bullet = canvas.content:CreateFontString(nil, "OVERLAY", "Game13Font")
    bullet:SetPoint("LEFT", title, "RIGHT", 4, -1)
    bullet:SetText("\226\128\162")
    local sub = canvas.content:CreateFontString(nil, "OVERLAY", "Game13Font")
    sub:SetPoint("LEFT", bullet, "RIGHT", 8, 0)
    sub:SetTextColor(0.9, 0.9, 0.9, 1)
    sub:SetText(QuestieLoader:ImportModule("l10n")("General Options"))
    canvas.UpdateScrollLayout = function() end      -- the build is done
    local category = Settings.RegisterCanvasLayoutCategory(canvas, key)
    if how == "select" then
        SettingsPanel:SelectCategory(category)
    else
        SettingsPanel:Show()
        canvas:Show()
    end
    H.pump(20, nil, 0.05)
    canvas:Hide()
    SettingsPanel:Hide()
    E.tabs[key] = nil
    local o = sub:GetFontObject()
    return o and o:GetName() or "none", (sub:GetFont())
end

-- Switches one UALLF setting off (as the player would in UALLF's options), before collecting.
function F.uallOff(key) UALLFSettingsDB[key] = false end

-- Kinds in the saved copy (a kind cut short is not saved).
function F.savedKinds()
    local cache = UADD.DB("questie").cache or {}
    local out = {}
    for _, k in ipairs({ "Quest", "Npc", "Item", "zones" }) do
        if type(cache[k]) == "table" then out[#out + 1] = k end
    end
    return table.concat(out, ",")
end

-- Spelling variants (QuestVariants.lua). A real one, then made-up keys put into this test game's
-- copy of UALLF for the cases the real data has none of; they are taken out again at the end.
function F.variants()
    local U, src = Ns().UALL, H.ns.UALLF
    local arnak = U.Quest(5147, "WANTED: Arnak Grimtotem")
    local A, B = "\208\144 \208\144", "\208\145 \208\145"         -- "А А", "Б Б"
    local C = "\208\176 \226\128\148 \194\171\208\176\194\187"   -- "а — «а»": A in another style
    local fake = {
        { src.questTitles, "Zzyzx: Harness Twin", A }, { src.questTitles, "Zzyzx - Harness Twin", B },
        { src.questTitles, "Zzyzx: Harness Pair", A }, { src.questTitles, "Zzyzx - Harness Pair", A },
        { src.questTitles, "Zzyzx: Harness Style", A }, { src.questTitles, "Zzyzx - Harness Style", C },
        { src.npcNames, "Zzyzx: Harness Npc", B },
    }
    for _, f in ipairs(fake) do f[1][f[2]] = f[3] end
    local twin, twinWait = U.Quest(nil, "ZZYZX: Harness Twin")
    local npc, npcWait = U.Quest(nil, "ZZYZX: Harness Npc")
    local pair = U.Quest(nil, "ZZYZX: Harness Pair")
    local style = U.Quest(nil, "ZZYZX - Harness Style")   -- " -" is closer than ":", though ":" comes first
    for _, f in ipairs(fake) do f[1][f[2]] = nil end
    local same = U.SameMeaning("\208\160\208\158\208\151\208\168\208\163\208\154\208\163\208\132\208\162\208\172"
        .. "\208\161\208\175: \194\171\208\147\210\144\208\176\194\187")               -- "РОЗШУКУЄТЬСЯ: «ГҐа»"
        == U.SameMeaning("\209\128\208\190\208\183\209\136\209\131\208\186\209\131\209\148\209\130\209\140"
        .. "\209\129\209\143 \226\128\148 \208\179\210\145\208\176")                   -- "розшукується — гґа"
    return arnak or false, twin or false, twinWait or false, npc or false, npcWait or false, pair == A,
        style == C, same
end
