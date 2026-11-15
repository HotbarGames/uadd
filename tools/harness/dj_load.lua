-- Dungeon Journal probes (used by flow_dj.py). Runs inside the harness session, after the
-- harness stubs and wow_api_dj.lua, before the addon loads. Nothing here changes what the addon
-- does: it only reads widgets and clicks them through their own scripts.
-- Strings are UTF-8 bytes here; flow_dj.py converts them.
local H = HARNESS
local DJ = {}
H.dj = DJ

-- ── pcall watch ──────────────────────────────────────────────────────────────────────────────
-- The addon wraps risky calls in pcall, so a missing stub can hide there. Every pcall that fails
-- inside a Dungeon Journal file is kept here (message only), so the runner can show it.
DJ.swallowed = {}
local realPcall = pcall
function pcall(fn, ...)
    local res = { realPcall(fn, ...) }
    if not res[1] then
        local msg = tostring(res[2])
        if msg:find("AddOns/ForeverDungeonJournal", 1, true) or msg:find("AddOns\\ForeverDungeonJournal", 1, true) then
            DJ.swallowed[#DJ.swallowed + 1] = msg
        end
    end
    return unpack(res, 1, table.maxn(res))
end

-- ── Reading what is on screen ────────────────────────────────────────────────────────────────

local function byId(a, b) return a.__id < b.__id end

local function sortedChildren(f)
    local r = {}
    for c in pairs(f.__children) do r[#r + 1] = c end
    table.sort(r, byId)
    return r
end

-- A widget draws only when it and all its parents are shown and not fully transparent.
local function drawn(w)
    local f = w
    while f do
        if not f.__shown or (f.__alpha or 1) <= 0 then return false end
        f = f.__parent
    end
    return true
end

local function nearestName(w)
    local f = w
    while f do
        if f.__name then return f.__name end
        f = f.__parent
    end
    return nil
end

-- Every visible text under root, in creation order: { text = ..., at = nearest named ancestor }.
-- Covers FontStrings (also those of Buttons) and EditBoxes. Empty strings are skipped.
function DJ.visibleDetailed(root)
    local out, seen = {}, {}
    local function walk(f)
        if seen[f] then return end
        seen[f] = true
        if (f.__type == "FontString" or f.__type == "EditBox") and type(f.__text) == "string" and f.__text ~= "" and drawn(f) then
            out[#out + 1] = { text = f.__text, at = nearestName(f) }
        end
        for _, c in ipairs(sortedChildren(f)) do walk(c) end
    end
    walk(root)
    return out
end

function DJ.visible(root)
    local r = {}
    for _, e in ipairs(DJ.visibleDetailed(root)) do r[#r + 1] = e.text end
    return r
end

-- Texts set through SetText / SetFormattedText since a mark (H.textLog logs every one of them).
function DJ.logMark() return #H.textLog end
function DJ.logSince(mark)
    local r = {}
    for i = (mark or 0) + 1, #H.textLog do
        local e = H.textLog[i]
        if e[2] and e[2] ~= "" then r[#r + 1] = e[2] end
    end
    return r
end

-- ── Driving the UI through its own scripts ───────────────────────────────────────────────────

function DJ.click(w, button)
    local s = w.__scripts
    if s.PreClick then H.call("PreClick", s.PreClick, w, button or "LeftButton") end
    if s.OnClick then H.call("OnClick", s.OnClick, w, button or "LeftButton", false) end
    if s.PostClick then H.call("PostClick", s.PostClick, w, button or "LeftButton") end
end

function DJ.slash(msg) return H.call("/dj " .. msg, SlashCmdList.FOREVERDUNGEONJOURNAL, msg) end

-- Child Buttons of a frame, in creation order.
function DJ.buttons(parent)
    local r = {}
    for _, c in ipairs(sortedChildren(parent)) do if c.__type == "Button" then r[#r + 1] = c end end
    return r
end

-- The quest list rows (frame.questContent children that carry a questID).
function DJ.questRows()
    local frame = _G.ForeverDungeonJournalFrame
    local r = {}
    if not (frame and frame.questContent) then return r end
    for _, b in ipairs(DJ.buttons(frame.questContent)) do
        if b.questID then
            r[#r + 1] = { button = b, id = b.questID, name = b.name and b.name.__text, meta = b.meta and b.meta.__text,
                shown = drawn(b) }
        end
    end
    return r
end

-- Language choices: the menu's option buttons and their labels.
function DJ.languageOptions()
    local frame = _G.ForeverDungeonJournalFrame
    local r = {}
    if not (frame and frame.languageMenu) then return r end
    for _, b in ipairs(DJ.buttons(frame.languageMenu)) do
        local label
        for _, c in ipairs(sortedChildren(b)) do if c.__type == "FontString" then label = c.__text end end
        r[#r + 1] = { button = b, label = label }
    end
    return r
end

function DJ.selectedLanguageText()
    local frame = _G.ForeverDungeonJournalFrame
    return frame and frame.languageSelectorText and frame.languageSelectorText.__text
end
