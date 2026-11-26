-- Lua helpers for flow_button.py, part 2: the box guard (UADD/BoxGuard.lua, by width: H.glyphWidths) and its
-- record (Guard.lua guardLast), and the cap of the button copies (UADD/ButtonFont.lua). Run after flow_button.lua,
-- before the game starts. Each M.<step>() returns a list of what went wrong (empty: passed).
local H = HARNESS
local M = H.btn
local Bad, Objects, Same, Pump, Quiet = M.h.Bad, M.h.Objects, M.h.Same, M.h.Pump, M.h.Quiet
local FRIZ, OWNCYR = M.h.FRIZ, M.h.OWNCYR

local function Holder(name)
    local f = CreateFrame("Frame", name, UIParent)
    f:SetPoint("CENTER")
    f:SetSize(240, 60)
    f:Show()
    return f
end
local function Last(kind)
    local h = UADD.DB().health
    local last = type(h) == "table" and type(h.guardLast) == "table" and h.guardLast[kind]
    return type(last) == "table" and last or nil
end

-- ── 7 no alarm where there are no boxes ───────────────────────────────────────────────────────
function M.boxFine()
    local f = Holder("FlowBoxFine")
    return Quiet(function()
        local U, bad = UADD, {}
        local a = f:CreateFontString(nil, "ARTWORK")
        a:SetFont(OWNCYR, 12, "")                           -- a file UADD does not know by name, with Cyrillic
        local fam = f:CreateFontString(nil, "ARTWORK")
        fam:SetFontObject(GameFontHighlightSmall)           -- a family on a plain text: draws its Cyrillic member
        local arial = f:CreateFontString(nil, "ARTWORK")
        arial:SetFont("Fonts\\ARIALN.TTF", 12, "")
        for _, x in ipairs({ a, fam, arial }) do
            x:SetText(M.UK)
            U.BoxWatch(x)
            Bad(bad, U.BoxWatched(x), "not watched")
        end
        local n = U.BoxRepairs()
        Pump(2.5)
        Bad(bad, U.BoxRepairs() == n, "repairs where no box was: " .. (U.BoxRepairs() - n))
        Bad(bad, a:GetFont() == OWNCYR, "its own Cyrillic file changed: " .. tostring((a:GetFont())))
        Bad(bad, fam:GetFontObject() == GameFontHighlightSmall and not rawget(fam, "__hand"), "the family changed")
        Bad(bad, arial:GetFont() == "Fonts\\ARIALN.TTF", "the Cyrillic file changed")
        return bad
    end, { f })
end

-- ── 8 boxes found and repaired; guardLast.box ─────────────────────────────────────────────────
function M.boxFind()
    local f = Holder("FlowBoxFrame")
    return Quiet(function()
        local U, bad = UADD, {}
        local fs = f:CreateFontString(nil, "ARTWORK")
        fs:SetFontObject(GameFontNormal)
        fs:SetText(M.EN)
        local kept = {}
        Bad(bad, U.CyrFix(fs, kept), "our font did not go on")
        fs:SetText(M.UK)
        Bad(bad, U.BoxWatched(fs), "not watched")
        fs:SetFontObject(GameFontNormal)                    -- the addon puts its object back: no hook of ours sees it
        Bad(bad, not H.drawsCyr(fs), "the setup: no boxes to find")
        local n = U.BoxRepairs()
        Pump(2.5)
        Bad(bad, U.BoxRepairs() == n + 1, "repairs: " .. (U.BoxRepairs() - n) .. ", want 1")
        Bad(bad, H.drawsCyr(fs) and U.IsCyrFont((fs:GetFont())), "boxes not repaired: " .. tostring((fs:GetFont())))
        local last = Last("box")
        Bad(bad, last, "no guardLast.box")
        last = last or {}
        Bad(bad, type(last.at) == "number" and math.abs(last.at - time()) < 600, "guardLast.box.at: " .. tostring(last.at))
        Bad(bad, U.version ~= nil and last.version == U.version, "guardLast.box.version: " .. tostring(last.version))
        local s = tostring(last.sample)
        Bad(bad, s:find("^FlowBoxFrame: ") and s:find(M.UK:sub(1, 6), 1, true), "guardLast.box.sample: " .. s)
        return bad
    end, { f })
end

-- ── 9 a repair that does not take ─────────────────────────────────────────────────────────────
function M.boxFail()
    local f = Holder("FlowBoxFail")
    return Quiet(function()
        local U, bad = UADD, {}
        local fs = f:CreateFontString(nil, "ARTWORK")
        fs:SetFontObject(GameFontNormal)
        fs:SetText(M.UK)
        rawset(fs, "SetFont", function() return false end)  -- a text that keeps its font whatever we do
        rawset(fs, "SetFontObject", function() end)
        U.BoxWatch(fs, function(x) x:SetText(M.EN) end)    -- its module's English
        Pump(2.5)
        Bad(bad, fs:GetText() == M.EN, "not English after a repair that did not take: " .. tostring(fs:GetText()))
        Bad(bad, U.BoxBad(fs), "not marked: our font would go on again")
        Bad(bad, U.CyrOnLocked(fs) == false, "our font goes on again")
        local last = Last("boxfail")
        Bad(bad, last and tostring(last.sample):find("^FlowBoxFail: "), "guardLast.boxfail: "
            .. tostring(last and last.sample))
        return bad
    end, { f })
end

-- ── 10 the cap (a client of its own) ──────────────────────────────────────────────────────────
-- ── 13 the cap reached while ours is on: a new state object of the addon gives English, never boxes ──
-- lateBefore (before the cap step): a button with our text, its English given back by its module (a callback).
local late = {}
function M.lateBefore()
    local U, bad = UADD, {}
    local b = CreateFrame("Button", "FlowBtnLate", UIParent, "UIPanelButtonTemplate")
    b:SetSize(120, 22)
    b:Show()
    late.b, late.fs, late.kept = b, b:GetFontString(), {}
    Bad(bad, U.CyrFix(late.fs, late.kept), "on: our font did not take")
    b:SetText(M.UK)
    U.BoxWatch(late.fs, function() b:SetText(M.EN) end)
    return bad
end
function M.late()
    local U, bad = UADD, {}
    local b, fs = late.b, late.fs
    local o = CreateFont("FlowBtnLateFont")
    o:SetFont(FRIZ, 12, "")
    b:SetNormalFontObject(o)                                -- no copy left for it
    H.step(0.016)
    Bad(bad, not (fs:GetText() or ""):find("[\208\209]"), "Ukrainian left on a Latin state: " .. tostring(fs:GetText()))
    Bad(bad, U.BoxBad(fs), "not marked: our font may go on again")
    U.CyrUnfix(fs, late.kept)
    Bad(bad, U.CyrFix(fs, late.kept) == false, "our font on again")
    b:Hide()
    return bad
end

function M.cap()
    local U, bad = UADD, {}
    local n, top, tripled, refused = 0, U.ButtonFonts(), false, 0
    local function Font()
        n = n + 1
        local o = CreateFont("FlowCapFont" .. n)
        o:SetFont(FRIZ, 10, "")
        return o
    end
    for i = 1, 80 do
        if U.ButtonFonts() == 63 and not tripled then
            tripled = true
            local b = CreateFrame("Button", "FlowCapTriple", UIParent)
            local o = { Font(), Font(), Font() }
            b:SetNormalFontObject(o[1])
            b:SetHighlightFontObject(o[2])
            b:SetDisabledFontObject(o[3])
            Bad(bad, U.ButtonCyr(b) == false, "3 objects, 1 copy left: true")
            Bad(bad, Same(Objects(b), o) and U.ButtonFonts(b) == nil, "3 objects, 1 copy left: changed (whole or nothing)")
        end
        local b = CreateFrame("Button", "FlowCap" .. i, UIParent)
        local fs = b:GetFontString()
        local o = Font()
        b:SetNormalFontObject(o)
        if not U.ButtonCyr(b) then
            refused = refused + 1
            Bad(bad, b:GetNormalFontObject() == o and U.ButtonFonts(b) == nil, "refused button " .. i .. " changed")
            b:SetText(M.EN)
            Bad(bad, U.CyrOnLocked(fs) == false and fs:GetFontObject() == o, "no copy left: our font on label " .. i)
        end
        top = math.max(top, U.ButtonFonts())
    end
    Bad(bad, top <= 64, "copies made: " .. top)
    Bad(bad, top == 64 and refused > 0 and tripled, "the cap never reached: " .. top .. ", refused " .. refused)
    return bad
end
