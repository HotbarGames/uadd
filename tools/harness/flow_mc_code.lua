-- Lua helpers for flow_mc_code.py: lines Mastercraft builds in its code, on the stand-in
-- (tools/harness/mastercraft). Reached from Python as HARNESS.mcCode. Run before the game starts.
local H = HARNESS
local C = {}
H.mcCode = C

local function S() return rawget(_G, "MastercraftStandIn") end
local function NS() return H.ns.UADD_Mastercraft end

-- UALL Forever's Ukrainian for made-up game names; a name held says "not now" (in combat, at login).
local names, held, stubbed = {}, {}, false
function C.names(en, uk)
    names[en] = uk
    if stubbed then return end
    stubbed = true
    UADD.UALL = UADD.UALL or {}
    for _, k in ipairs({ "Text", "Zone", "Npc", "Item" }) do
        local old = UADD.UALL[k]
        UADD.UALL[k] = function(s, ...)
            if held[s] then return nil, true end
            if names[s] then return names[s] end
            if old then return old(s, ...) end
        end
    end
end
function C.hold(en, on) held[en] = on or nil end

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
