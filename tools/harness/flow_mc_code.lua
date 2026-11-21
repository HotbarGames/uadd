-- Lua helpers for flow_mc_code.py: lines Mastercraft builds in its code, on the stand-in
-- (tools/harness/mastercraft). Reached from Python as HARNESS.mcCode. Run before the game starts.
local H = HARNESS
local C = {}
H.mcCode = C

local function S() return rawget(_G, "MastercraftStandIn") end
local function NS() return H.ns.UADD_Mastercraft end

-- UALL Forever's Ukrainian for made-up game names, from every route or from one (an enchant: "Spell"
-- only); a name held says "not now" (in combat, at login).
local names, only, held, stubbed = {}, {}, {}, false
function C.names(en, uk, route)
    if route then
        only[route] = only[route] or {}
        only[route][en] = uk
    else
        names[en] = uk
    end
    if stubbed then return end
    stubbed = true
    UADD.UALL = UADD.UALL or {}
    for _, k in ipairs({ "Text", "Zone", "Npc", "Item", "Spell" }) do
        local old = UADD.UALL[k]
        UADD.UALL[k] = function(s, ...)
            if held[s] then return nil, true end
            local uk = only[k] and only[k][s] or names[s]
            if uk then return uk end
            if old then return old(s, ...) end
        end
    end
end
function C.hold(en, on) held[en] = on or nil end

-- One text through Words.Translate and the tooltip's Maybe, nothing remembered (as a name UALL Forever
-- makes wait): the slowest of the two, in ms, best of 3.
function C.slow(t)
    local best
    for _ = 1, 3 do
        NS().Words.Forget()
        local t0 = os.clock()
        NS().Words.Translate(t)
        local a = os.clock()
        NS().Tooltip.Maybe(t)
        local ms = math.max(a - t0, os.clock() - a) * 1000
        best = best and math.min(best, ms) or ms
    end
    return best
end

-- Our Ukrainian for a whole text, and a template filled by hand (numbers in rec.uk are slots).
function C.want(key)
    local uk = NS().MC.exact[key]
    return uk and UADD.Plural(uk, true) or ""
end
function C.fill(id, ...)
    local vals = { ... }
    for _, rec in ipairs(NS().MC.templates) do
        if rec.id == id then
            local out = {}
            for _, p in ipairs(rec.uk) do out[#out + 1] = type(p) == "number" and (vals[p] or "") or p end
            return UADD.Plural(table.concat(out), true)
        end
    end
    return ""
end

-- One of Mastercraft's own font strings (ns.Text), made after login, with its text set.
local frame
function C.text(name)
    if not frame then frame = CreateFrame("Frame", nil, MastercraftFrame) end
    S().Text(frame, name, 12)
    H.step(0.05) H.step(0.05)              -- found on the next frame (CreateFontString hook)
end
function C.set(name, text)
    S().Set(name, text)
    return S().texts[name]:GetText() or ""
end
function C.get(name) return S().texts[name]:GetText() or "" end
-- A guide step's row title (S.Step): made on first use, then reused as Mastercraft reuses its rows.
function C.step(name, title, count, open)
    if not S().texts[name] then C.text(name) end
    S().Step(name, title, count, open)
    return S().texts[name]:GetText() or ""
end

-- The game's own setter of one of Mastercraft's strings throws once (an error inside our write).
function C.throwOnce(name)
    local fs = S().texts[name]
    local real = rawget(fs, "mcSetText")
    local thrown = false
    rawset(fs, "mcSetText", function(self, text)
        if not thrown then thrown = true error("a test error inside the write") end
        return real(self, text)
    end)
end

-- A frame of another addon (not Mastercraft's), its GetRegions counted.
local function Foreign(parent)
    local f = CreateFrame("Frame", nil, parent or UIParent)
    local base, n = f.GetRegions, { 0 }
    f.GetRegions = function(self, ...) n[1] = n[1] + 1 return base(self, ...) end
    return f, n
end
-- A forbidden frame making a font string: never asked for its regions.
function C.forbidden()
    local f, n = Foreign()
    f.IsForbidden = function() return true end
    f:CreateFontString(nil, "OVERLAY")
    H.step(0.05) H.step(0.05)
    return n[1]
end
-- Another addon's frame making a font string on each of 10 frames: looked at twice, then left alone.
function C.foreign()
    local f, n = Foreign()
    for _ = 1, 10 do
        f:CreateFontString(nil, "OVERLAY")
        H.step(0.05)
    end
    H.step(0.05)
    return n[1]
end
-- 600 frames under UIParent, then the scan: how many it looks at in the call itself, and after.
function C.scan()
    local counts = {}
    for i = 1, 600 do
        local _, n = Foreign()
        counts[i] = n
    end
    local function Sum() local s = 0 for _, n in ipairs(counts) do s = s + n[1] end return s end
    NS().Screen.Scan()
    local now = Sum()
    for _ = 1, 10 do H.step(0.05) end
    return now, Sum()
end

-- The Crafters hub (raw strings, Raw.lua): made, then found on the next frame.
function C.hub(empty)
    S().Hub(empty)
    H.step(0.05) H.step(0.05)
end
local function Raw(which)
    local card, tile = S().hub.card, S().hub.tile
    return card[which] or tile[which]
end
function C.hubSet(which, text)
    local fs = Raw(which)
    fs:SetText(text)
    return fs:GetText() or ""
end
function C.hubGet(which) return Raw(which):GetText() or "" end
function C.hubCyr(which) return UADD.IsCyrFont((Raw(which):GetFont())) and true or false end

-- A line of Mastercraft's block at the bottom of an item's tooltip (from the stand-in's code). The
-- harness's AddLine does not draw the text itself: "" means the module left the line as it is.
function C.tip(line)
    GameTooltipTextLeft1:SetText("")
    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    S().TipAdd(line)
    GameTooltip:Show()
    local got = GameTooltipTextLeft1:GetText() or ""
    GameTooltip:Hide()
    return got
end

-- The craft orders board and cards (raw strings, Raw.lua's readers): made, then found on the next frame.
function C.orders()
    S().Orders()
    H.step(0.05) H.step(0.05)
end
local function Cell(card, field) return S().orders[card][field] end
function C.ordSet(card, field, text)
    local fs = Cell(card, field)
    fs:SetText(text)
    return fs:GetText() or ""
end
function C.ordGet(card, field) return Cell(card, field):GetText() or "" end
function C.ordCyr(card, field) return UADD.IsCyrFont((Cell(card, field):GetFont())) and true or false end
-- A board row's buyer cell, as Mastercraft fills it: "you" on your own order (row.mine set first).
function C.ordBuyer(text, mine)
    local row = S().orders.row
    row.mine = mine and 1 or nil
    row.buyer:SetText(text)
    return row.buyer:GetText() or ""
end

-- Our Ukrainian for a few of the board's words, for these checks only (whatever the data has today):
-- a text taught here wins over the data in Words.Try, the path every reader takes.
local taught, wrapped = {}, false
function C.teach(en, uk)
    taught[en] = uk
    if wrapped then return end
    wrapped = true
    local W = NS().Words
    local real = W.Try
    W.Try = function(s)
        if taught[s] then return taught[s], false end
        return real(s)
    end
end
-- A reader alone (Raw.lua R.Reader): its Ukrainian, or "" when the line stays English.
function C.read(kind, text)
    local R = NS().Raw.Reader
    local fn = kind == "piece" and R.Piece or kind == "age" and R.Age or kind == "deal" and R.Deal
        or kind == "gaps" and R.Gapped() or R.Gapped(R.Who)
    return fn(text) or ""
end

-- The new-order toast (a named window made late, one of Mastercraft's own strings).
function C.toast(text)
    S().Toast(text)
    H.step(0.05) H.step(0.05)
    return S().texts.toast:GetText() or ""
end
