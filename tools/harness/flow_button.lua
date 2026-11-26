-- Lua helpers for flow_button.py: the core alone (docs/LESSONS4.md lesson 46): the button font helper
-- (UADD/ButtonFont.lua), U.SaveFont / U.FontBack on a button's label (UADD/Font.lua), the box guard
-- (UADD/BoxGuard.lua) and its record (Guard.lua guardLast). Reached from Python as HARNESS.btn. Every text is made
-- up. Run before the game starts. Each M.<step>() returns a list of what went wrong (empty: passed).
local H = HARNESS
local M = {}
H.btn = M

local FRIZ = "Fonts\\FRIZQT__.TTF"
local OWNCYR = "Interface\\AddOns\\FlowButton\\Letters_cyr.ttf"   -- an addon's own file with Cyrillic (made up)
H.fontFiles[OWNCYR:lower()] = true
M.EN, M.UK = "Wobbly gizmo", "Хитка штучка"

-- The proof that a step has teeth: with M.cut set, one core file runs without one fix (in memory only).
local CUTS = {}
M.cut, M.wasCut = nil, false
function M.addCut(name, file, old, new) CUTS[name] = { file, old, new } end
local runFile = H.runFile
function H.runFile(addon, path, code)
    local c = M.cut and CUTS[M.cut]
    if c and addon .. ":" .. path == c[1] then
        local a, b = code:find(c[2], 1, true)
        if a then code, M.wasCut = code:sub(1, a - 1) .. c[3] .. code:sub(b + 1), true end
    end
    return runFile(addon, path, code)
end

-- ── Small helpers ──────────────────────────────────────────────────────────────────────────────
local function Bad(list, ok, what) if not ok then list[#list + 1] = what end end
local function Name(o) return type(o) == "table" and o.GetName and tostring(o:GetName()) or tostring(o) end
local function Ours(o) return Name(o):find("^UADD_") ~= nil end
local function Objects(b) return { b:GetNormalFontObject(), b:GetHighlightFontObject(), b:GetDisabledFontObject() } end
local function Same(a, b) return a[1] == b[1] and a[2] == b[2] and a[3] == b[3] end
local function Button(name, template)
    local b = CreateFrame("Button", name, UIParent, template)
    b:SetPoint("CENTER")
    b:SetSize(120, 22)
    b:Show()
    return b, b:GetFontString()
end
-- The label draws its Cyrillic as letters now (wow_button.lua), and the static rule finds no state without it.
local function Draws(fs) return H.drawsCyr(fs) and not H.boxSuspect(fs) end
local function Pump(s) H.pump(math.floor(s / 0.05), function() return false end, 0.05) end
-- A step with boxes on purpose: they stay out of the segment's box check; its frames hidden after.
local function Quiet(fn, frames)
    local q = H.boxQuiet
    H.boxQuiet = true
    local ok, bad = pcall(fn)
    for _, f in ipairs(frames) do f:Hide() end
    H.step(0.016)
    H.boxQuiet = q
    if not ok then return { "error: " .. tostring(bad) } end
    return bad
end

-- ── 1 on and back ──────────────────────────────────────────────────────────────────────────────
function M.onBack()
    local U, bad = UADD, {}
    local b, fs = Button("FlowBtnOn", "UIPanelButtonTemplate")
    b:SetText(M.EN)
    local own = Objects(b)
    Bad(bad, U.ButtonCyr(b, true) == false, "look: true on a button with Latin states")
    Bad(bad, Same(Objects(b), own), "look changed the button")
    Bad(bad, U.ButtonCyr(b) == true, "ButtonCyr: false")
    local now = Objects(b)
    for i, o in ipairs(now) do
        Bad(bad, Ours(o) and U.FontBase(o) == own[i], "state " .. i .. ": not our copy of its own: " .. Name(o))
        local p, s = o:GetFont()
        local _, s0 = own[i]:GetFont()
        Bad(bad, U.IsCyrFont(p) and s == s0, "state " .. i .. ": copy's font " .. tostring(p) .. " " .. tostring(s))
        local r, g, bl = o:GetTextColor()
        local r0, g0, b0 = own[i]:GetTextColor()
        Bad(bad, r == r0 and g == g0 and bl == b0, "state " .. i .. ": colour not copied")
    end
    Bad(bad, U.ButtonCyr(b, true) == true, "look after: not every state Cyrillic")
    Bad(bad, U.IsCyrFont((fs:GetFont())), "label not in our copy")
    local made = U.ButtonFonts()
    local b2 = Button("FlowBtnOn2", "UIPanelButtonTemplate")
    U.ButtonCyr(b2)
    Bad(bad, U.ButtonFonts() == made and Same(Objects(b2), now), "a second button with the same objects: new copies")
    U.ButtonBack(b)
    U.ButtonBack(b2)
    Bad(bad, Same(Objects(b), own) and Same(Objects(b2), own), "back: the button's own objects not back")
    Bad(bad, U.ButtonFonts(b) == nil, "back: a record left")
    Bad(bad, fs:GetFontObject() == own[1] and not U.IsCyrFont((fs:GetFont())), "back: the label not on its own")
    return bad
end

-- ── 2 a state object the addon set since ──────────────────────────────────────────────────────
function M.kept()
    local U, bad = UADD, {}
    local b = Button("FlowBtnKept", "UIPanelButtonTemplate")
    b:SetText(M.EN)
    local own = Objects(b)
    U.ButtonCyr(b)
    local cyr = CreateFont("FlowBtnKeptCyr")                -- the addon's own object with Cyrillic: never copied
    cyr:SetFont(U.CyrFontPath(), 12, "")
    b:SetNormalFontObject(cyr)                              -- the addon's own change, English on the label
    H.step(0.016)
    U.ButtonBack(b)
    Bad(bad, b:GetNormalFontObject() == cyr, "back: the addon's normal object lost: " .. Name(b:GetNormalFontObject()))
    Bad(bad, b:GetHighlightFontObject() == own[2] and b:GetDisabledFontObject() == own[3], "back: the other states")
    local b2, fs2 = Button("FlowBtnKept2", "UIPanelButtonTemplate")
    local kept = {}
    U.CyrFix(fs2, kept)
    b2:SetText(M.UK)
    b2:SetHighlightFontObject(GameFontNormalSmall)          -- the addon's change with our text on
    local h = b2:GetHighlightFontObject()
    Bad(bad, Ours(h) and U.FontBase(h) == GameFontNormalSmall, "ours on: the addon's new object not ours: " .. Name(h))
    H.hover(b2)
    Bad(bad, Draws(fs2), "ours on: hover on the addon's new object: boxes")
    H.unhover(b2)
    b2:SetText(M.EN)
    U.CyrUnfix(fs2, kept)
    Bad(bad, b2:GetHighlightFontObject() == GameFontNormalSmall, "ours off: the addon's object not back: "
        .. Name(b2:GetHighlightFontObject()))
    return bad
end

-- ── 3 protected and forbidden ─────────────────────────────────────────────────────────────────
function M.locked()
    local U, bad = UADD, {}
    local b, fs = Button("FlowBtnSecure", "UIPanelButtonTemplate")
    rawset(b, "IsProtected", function() return true end)
    b:SetText(M.EN)
    local own = Objects(b)
    Bad(bad, U.ButtonCyr(b) == false, "protected: ButtonCyr true")
    Bad(bad, Same(Objects(b), own) and U.ButtonFonts(b) == nil, "protected: its objects changed")
    Bad(bad, U.CyrOnLocked(fs) == false, "protected: our font on its label")
    Bad(bad, fs:GetFontObject() == own[1] and not U.IsCyrFont((fs:GetFont())), "protected: its label's font changed")
    local f, ffs = Button("FlowBtnForbidden", "UIPanelButtonTemplate")
    rawset(f, "IsForbidden", function() return true end)
    local fown = Objects(f)
    Bad(bad, U.ButtonCyr(f) == false, "forbidden: ButtonCyr true")
    Bad(bad, Same(Objects(f), fown) and U.ButtonFonts(f) == nil, "forbidden: its objects changed")
    Bad(bad, U.LabelButton(ffs) == nil, "forbidden: taken for a label")
    return bad
end

-- ── 4 the client's own state switches ─────────────────────────────────────────────────────────
function M.states()
    local U, bad = UADD, {}
    local b, fs = Button("FlowBtnStates", "UIPanelButtonTemplate")
    local kept = {}
    local fixed = U.CyrFix(fs, kept)
    b:SetText(M.UK)
    Bad(bad, fixed and Draws(fs), "on: boxes (" .. tostring(H.boxSuspect(fs)) .. ")")
    local function After(what)
        Bad(bad, Draws(fs), what .. ": boxes (" .. tostring(H.boxSuspect(fs)) .. ")")
        H.step(0.016)
        Bad(bad, Draws(fs), what .. ", a frame later: boxes")
    end
    H.hover(b) After("hover")
    H.unhover(b) After("unhover")
    b:Disable() After("Disable")
    b:Enable() After("Enable")
    b:SetEnabled(false) After("SetEnabled(false)")
    b:SetEnabled(true) After("SetEnabled(true)")
    b:LockHighlight() After("LockHighlight")
    b:UnlockHighlight() After("UnlockHighlight")
    b:SetDisabledFontObject(GameFontNormalSmall)
    b:Disable() After("the addon's new disabled object, Disable")
    b:Enable()
    b:SetText(M.EN)
    U.CyrUnfix(fs, kept)
    local o = Objects(b)
    Bad(bad, not Ours(o[1]) and not Ours(o[2]) and not Ours(o[3]), "back: a copy of ours left on a state")
    Bad(bad, o[3] == GameFontNormalSmall, "back: the addon's disabled object lost")
    Bad(bad, not Ours(fs:GetFontObject()) and not U.IsCyrFont((fs:GetFont())), "back: our font on the label")
    return bad
end

-- ── 5 SaveFont on a label whose font differs from its object's ─────────────────────────────────
-- In the client a button's label may draw another font than its GetFontObject names (the client changes the
-- object with the state, Font.lua SaveFont), so the two differing proves no hand-set font there.
function M.saveFont()
    local U, bad = UADD, {}
    local b, fs = Button("FlowBtnSave")
    local mine = CreateFont("FlowBtnSaveFont")
    mine:SetFont(FRIZ, 14, "")
    local later = CreateFont("FlowBtnLaterFont")
    later:SetFont(FRIZ, 16, "")
    fs:SetFontObject(mine)
    b:SetText(M.EN)
    rawset(fs, "__font", { FRIZ, 12, "" })                  -- drawn natively: GetFont differs from its object's
    local was = U.SaveFont(fs)
    Bad(bad, not was.own, "SaveFont marked a label's font as set by hand")
    local kept = {}
    local fixed = U.CyrFix(fs, kept)
    b:SetText(M.UK)
    Bad(bad, fixed and Draws(fs), "on: boxes")
    b:SetText(M.EN)
    U.CyrUnfix(fs, kept)
    Bad(bad, not rawget(fs, "__hand"), "back: a file pinned on the label by hand: " .. tostring((fs:GetFont())))
    Bad(bad, fs:GetFontObject() == mine, "back: the label's object: " .. Name(fs:GetFontObject()))
    fs:SetFontObject(later)                                 -- the addon's next font object takes
    local _, s = fs:GetFont()
    Bad(bad, s == 16, "a later font object did not take (size " .. tostring(s) .. ")")
    return bad
end

-- ── 6 a font saved while our copy is on ───────────────────────────────────────────────────────
function M.fontBase()
    local U, bad = UADD, {}
    local b, fs = Button("FlowBtnHand", "UIPanelButtonTemplate")
    fs:SetFont(FRIZ, 14, "")                                -- the addon's own font, set by hand
    local kept = {}
    U.CyrFix(fs, kept)
    b:SetText(M.UK)
    Bad(bad, Draws(fs), "on: boxes")
    H.hover(b)
    Bad(bad, Draws(fs), "hover: boxes")
    local was = U.SaveFont(fs)                              -- saved again while our copy is on (a rebuilt record)
    Bad(bad, was.object == GameFontHighlight, "saved our copy as the label's own object: " .. Name(was.object))
    H.unhover(b)
    b:SetText(M.EN)
    U.CyrUnfix(fs, kept)
    local p, s = fs:GetFont()
    Bad(bad, p == FRIZ and s == 14, "back: the addon's hand-set file not back: " .. tostring(p) .. " " .. tostring(s))
    Bad(bad, fs:GetFontObject() == GameFontNormal, "back: the label's object: " .. Name(fs:GetFontObject()))
    return bad
end

-- ── 11 a state object set while the label is empty, then our text ─────────────────────────────
function M.emptyThen()
    local U, bad = UADD, {}
    local b, fs = Button("FlowBtnEmpty", "UIPanelButtonTemplate")
    local kept = {}
    U.CyrFix(fs, kept)
    b:SetText("")
    b:SetNormalFontObject(GameFontNormalSmall)              -- the addon's new looks, the label empty
    b:SetHighlightFontObject(GameFontHighlightSmall)
    b:SetText(M.UK)                                         -- our text, no frame between: no later look
    local o = Objects(b)
    Bad(bad, Draws(fs), "our text: boxes (" .. tostring(H.boxSuspect(fs)) .. ")")
    Bad(bad, Ours(o[1]) and U.FontBase(o[1]) == GameFontNormalSmall, "normal state: not our copy: " .. Name(o[1]))
    H.hover(b)
    Bad(bad, Draws(fs), "hover: boxes")
    H.unhover(b)
    b:SetText(M.EN)
    U.CyrUnfix(fs, kept)
    o = Objects(b)
    Bad(bad, o[1] == GameFontNormalSmall and o[2] == GameFontHighlightSmall,
        "back: not the addon's objects: " .. Name(o[1]) .. ", " .. Name(o[2]))
    b:Hide()
    return bad
end

-- ── 12 back on a label the addon gave a new object while ours was on ─────────────────────────
-- A button with no state objects: the label's own object is all it has. Back: the addon's newer object, not the
-- one saved before ours went on (lesson 23), through U.FontBase in U.FontBack.
function M.labelBack()
    local U, bad = UADD, {}
    local t = Button("FlowBtnLB0", "UIPanelButtonTemplate")
    U.ButtonCyr(t)                                          -- copies of the game's two objects exist from here
    local b = CreateFrame("Button", "FlowBtnLB", UIParent)
    b:SetSize(120, 22)
    b:Show()
    local fs = b:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(GameFontNormal)
    b:SetFontString(fs)
    local kept = {}
    local fixed = U.CyrFix(fs, kept)
    b:SetText(M.UK)
    Bad(bad, fixed and Draws(fs) and Ours(fs:GetFontObject()), "on: not our copy: " .. Name(fs:GetFontObject()))
    fs:SetFontObject(GameFontHighlight)                     -- the addon's own new object while ours is on
    H.hover(b)
    H.step(0.016)
    local o = fs:GetFontObject()
    Bad(bad, Draws(fs) and U.FontBase(o) == GameFontHighlight, "the new object: not its copy: " .. Name(o))
    H.unhover(b)
    b:SetText(M.EN)
    U.CyrUnfix(fs, kept)
    Bad(bad, fs:GetFontObject() == GameFontHighlight, "back: not the addon's newer object: " .. Name(fs:GetFontObject()))
    U.ButtonBack(t)
    t:Hide()
    b:Hide()
    return bad
end

-- Steps 7-10 (the box guard and the cap): flow_button_guard.lua, with these helpers.
M.h = { Bad = Bad, Name = Name, Objects = Objects, Same = Same, Pump = Pump, Quiet = Quiet, FRIZ = FRIZ,
        OWNCYR = OWNCYR }
