-- Lua helpers for flow_tomtom.py, on the TomTom stand-in (tools/harness/tomtom). Reached from Python as
-- HARNESS.tt. Run before the game starts.
local H = HARNESS
local M = {}
H.tt = M

-- The game's ScrollUtil has this; the harness does not. A settings page's list calls each callback
-- with every row it makes (the stand-in's Rows).
if type(ScrollUtil.AddInitializedFrameCallback) ~= "function" then
    function ScrollUtil.AddInitializedFrameCallback(box, cb, owner)
        box.__onRow = box.__onRow or {}
        box.__onRow[#box.__onRow + 1] = { cb, owner }
    end
end

-- The proof that the late-window step has teeth: with M.cut set, UADD_TomTom's Fonts.lua runs without
-- its late-window code (the CreateFrame hook). Only this run's copy of the code, in memory; the
-- module's file is never changed.
M.cut, M.wasCut = false, false
local runFile = H.runFile
function H.runFile(addon, path, code)
    if M.cut and addon == "UADD_TomTom" and path == "Fonts.lua" then
        local a = code:find("    -- A window TomTom makes late", 1, true)
        local b = a and code:find("    local p = rawget(_G, \"SettingsPanel\")", a, true)
        if a and b then code, M.wasCut = code:sub(1, a - 1) .. code:sub(b), true end
    end
    return runFile(addon, path, code)
end

TomTomStandInFeed = { L = {}, settings = {}, popups = {}, paste = {}, late = {} }
function M.feedL(en) local t = TomTomStandInFeed.L t[#t + 1] = en end
function M.feed(group, name, en) TomTomStandInFeed[group][name] = en end
function M.feedPopup(which, field, en)
    local p = TomTomStandInFeed.popups
    p[which] = p[which] or {}
    p[which][field] = en
end

local function S() return rawget(_G, "TomTomStandIn") end
local function NS() return H.ns.UADD_TomTom end
M.S = S
function M.loaded() return S() ~= nil and NS() ~= nil and NS().Words ~= nil end
function M.on() return NS().On() end
function M.uk(t) return NS().Words.Translate(t) end
function M.count() return NS().Words.Count() end
function M.swapped() return NS().Swapped() end
function M.fontCount() return NS().Fonts.Count() end
function M.L(en) return rawget(TomTom.L, en) end
function M.swapOf(key) return NS().TT.swap[key] end
local function Cyr(fs) return fs ~= nil and UADD.IsCyrFont((fs:GetFont())) and true or false end
M.cyr = Cyr

-- Our Ukrainian for a whole text, straight from the module's data.
function M.want(key)
    local uk = NS().TT.exact[key]
    return uk and UADD.Plural(uk, true)
end

-- A template filled by hand from its record (uk: pieces, numbers are slots), with the plural picked.
function M.fill(id, a, b, c, d)
    local vals = { a, b, c, d }
    for _, rec in ipairs(NS().TT.templates) do
        if rec.id == id then
            local out = {}
            for _, p in ipairs(rec.uk) do out[#out + 1] = type(p) == "number" and tostring(vals[p]) or p end
            return UADD.Plural(table.concat(out), true)
        end
    end
end
function M.hasTemplate(id)
    for _, rec in ipairs(NS().TT.templates) do if rec.id == id then return true end end
    return false
end

-- A made-up name UALL Forever "has": its Ukrainian for the module's game-name slots.
function M.names(en, uk)
    local A = UADD.UALL          -- the routes Words.lua asks (UADD itself has none)
    for _, k in ipairs({ "Text", "Zone", "Npc", "Item", "Spell" }) do
        local old = A[k]
        A[k] = function(s, ...)
            if s == en then return uk end
            if old then return old(s, ...) end
        end
    end
end

-- ── Settings ──────────────────────────────────────────────────────────────────────────────────

-- The first page (BuildSettings at login), opened in the game's settings window: {role: text},
-- {role: our font?}, its name, a row's tooltip and its dropdown entry as the game gets them.
function M.page(which)
    local page = which == "late" and S().late or S().page
    if which ~= "late" then
        SettingsPanel:Show()
        SettingsPanel:SelectCategory(page.category)
    end
    local texts, fonts = {}, {}
    for role, fs in pairs(page.rows or {}) do texts[role], fonts[role] = fs:GetText() or "", Cyr(fs) end
    local row = page.inits[1] and page.inits[1].data or {}
    local opts = type(row.options) == "function" and row.options() or {}
    return texts, fonts, page.name or "", row.tooltip or "", opts[1] and opts[1].label or ""
end
function M.latePage() S().LatePage() M.wait(0.1) return M.page("late") end
function M.options()
    local row = S().page.inits[1].data
    local opts = row.options()
    return opts[1] and opts[1].label or ""
end

-- ── Arrow, tooltip, chat, pop-ups ─────────────────────────────────────────────────────────────

function M.status(en, a, b)
    if b ~= nil then S().Status(en, a, b) else S().Status(en, a) end
    local fs = TomTomCrazyArrow.status
    return fs:GetText() or "", Cyr(fs)
end

-- Each call of the status line's SetText (every frame in the game), n times with a new number:
-- (average ms, slowest ms) of the whole call, our hooks included.
function M.statusSpeed(en, n)
    local fs, f = TomTomCrazyArrow.status, rawget(TomTom.L, en) or en
    local total, worst = 0, 0
    for i = 1, n do
        local text = format(f, 100 + i)
        local t0 = debugprofilestop()
        fs:SetText(text)
        local dt = debugprofilestop() - t0
        total = total + dt
        if dt > worst then worst = dt end
    end
    return total / n, worst
end

local function Line(i)
    local fs = _G["TomTomTooltipTextLeft" .. i]
    return fs:GetText() or "", Cyr(fs)
end
function M.pin(title, dist, yards, coords, zone, x, y)
    S().Pin(title, dist, yards, coords, zone, x, y)
    local a, ac = Line(2)
    local b, bc = Line(3)
    return a, ac, b, bc
end
function M.pinUpdate(dist, yards)
    S().PinUpdate(dist, yards)
    return Line(2)
end

function M.printf(en, ...) S().Printf(en, ...) return H.chat[#H.chat] end
function M.chat(en, ...) S().Chat(en, ...) return H.chat[#H.chat] end
function M.say(text) DEFAULT_CHAT_FRAME:AddMessage(text) return H.chat[#H.chat] end
function M.lastChat(n)
    local out = {}
    for i = math.max(1, #H.chat - n + 1), #H.chat do out[#out + 1] = H.chat[i] end
    return table.concat(out, " | ")
end

function M.popupField(which, field) local d = StaticPopupDialogs[which] return d and d[field] or "" end
-- A pop-up shown as the game shows it (its text in StaticPopup1), then StaticPopup_Show: (text, our font?).
function M.popup(which)
    local d = StaticPopup1
    d.which = which
    d.text = d.text or d:CreateFontString("StaticPopup1Text", "ARTWORK", "GameFontHighlight")
    d.text:SetText(format(StaticPopupDialogs[which].text, "Quix"))
    d:Show()
    StaticPopup_Show(which, "Quix")
    local text, cyr = d.text:GetText() or "", Cyr(d.text)
    d:Hide()
    return text, cyr
end

-- ── The paste window (made on first open) ─────────────────────────────────────────────────────

function M.paste()
    local f = S().OpenPaste()
    M.wait(0.1)                        -- the C_Timer tick the module waits for
    return f.title:GetText() or "", Cyr(f.title), f.button:GetFontString():GetText() or "",
        Cyr(f.button:GetFontString())
end
function M.repaste(en)
    local f = S().paste
    f:Hide()
    f:Show()
    f.title:SetText(rawget(TomTom.L, en) or en)
    return f.title:GetText() or "", Cyr(f.title)
end

-- ── Review fixes (flow_tomtom_review.py, lesson 12) ───────────────────────────────────────────

-- fn() run while the module's Words.Translate is counted: (calls, fn's two results).
local function Counting(fn)
    local W, calls = NS().Words, 0
    local orig = W.Translate
    W.Translate = function(...) calls = calls + 1 return orig(...) end
    local ok, a, b = pcall(fn)
    W.Translate = orig
    if not ok then error(a, 0) end
    return calls, a, b
end

-- The profile dropdown's entry, as the game gets it (a profile the player named).
function M.profileEntry()
    for _, init in ipairs(S().page.inits) do
        if init.role == "profile" then
            local o = init.data.options()
            return o[1] and o[1].label or ""
        end
    end
    return ""
end

-- A chat line written by code that is not TomTom's: (Translate calls, Words cache growth, line shown).
function M.otherChat(line)
    local W = NS().Words
    local before = W.CacheSize()
    local calls = Counting(function() DEFAULT_CHAT_FRAME:AddMessage(line) end)
    return calls, W.CacheSize() - before, H.chat[#H.chat]
end

-- The arrow's status written n times with the same text (as on each frame): (Translate calls, text, font).
function M.arrowSame(en, n, a)
    local fs = TomTomCrazyArrow.status
    local text = format(rawget(TomTom.L, en) or en, a)
    return Counting(function()
        for _ = 1, n do fs:SetText(text) end
        return fs:GetText() or "", Cyr(fs)
    end)
end

-- A unit's GameTooltip shown by the game (one line: English, or ua in a Cyrillic font as UALL Forever
-- gives it): how many times debugstack ran.
function M.unitTip(ua)
    local calls, orig = 0, debugstack
    debugstack = function(...) calls = calls + 1 return orig(...) end
    local ok, err = pcall(function()
        GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
        GameTooltip:AddLine("Quixwood Boar")
        GameTooltipTextLeft1:SetText(ua or "Quixwood Boar")
        if ua then GameTooltipTextLeft1:SetFont(UADD.CyrFontPath(), 12, "") end
        GameTooltip:Show()
    end)
    debugstack = orig
    GameTooltip:Hide()
    GameTooltipTextLeft1:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    if not ok then error(err, 0) end
    return calls
end

-- TomTom's code showing the GameTooltip with one of its L texts: (text, our font?).
function M.gameTip(en)
    S().GameTip(en)
    local fs = GameTooltipTextLeft1
    local text, cyr = fs:GetText() or "", Cyr(fs)
    GameTooltip:Hide()
    return text, cyr
end

-- ── Keys, time, commands ──────────────────────────────────────────────────────────────────────

function M.key(down)
    H.keys.SHIFT = down
    H.fire("MODIFIER_STATE_CHANGED", "LSHIFT", down and 1 or 0)
    M.wait(0.4)                         -- UADD/Original.lua switches once the key is held a while
end
function M.wait(seconds) for _ = 1, math.ceil(seconds / 0.05 - 1e-6) do H.step(0.05) end end
function M.uadd(msg) return H.call("/uadd " .. msg, SlashCmdList.UADD, msg) end
