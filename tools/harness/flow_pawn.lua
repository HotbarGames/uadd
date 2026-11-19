-- Lua helpers for flow_pawn.py, on the Pawn stand-in (tools/harness/pawn). Reached from Python as
-- HARNESS.pawn. Run before the game starts.
--
-- Test Ukrainian: until tools/make_pawn_text.py has written UADD_Pawn/data, the flow makes a test line for
-- each key from Pawn's English (its words become Cyrillic, its slots, colour codes and ": " stay) and
-- gives it to the module (ns.AL, ns.SORT) right after the module's files ran, only for keys its data lacks.
local H = HARNESS
local M = {}
H.pawn = M

VgerCore = VgerCore or { IsForever = true }        -- what UIStrings.lua asks about the game's version
-- Game globals UIStrings.lua reads that the harness lacks: each holds its own name (game text, not ours).
for _, n in ipairs({ "ARMOR", "DELETE", "EMPTY_SOCKET_META", "INVTYPE_RELIC", "PETITION_CREATOR",
    "PLAYERSTAT_SPELL_COMBAT", "PVP", "STAT_AVOIDANCE", "STAT_CATEGORY_ATTRIBUTES", "STAT_CATEGORY_ENHANCEMENTS",
    "STAT_DPS_SHORT", "STAT_HASTE", "STAT_LIFESTEAL", "STAT_MASTERY", "STAT_MOVEMENT_SPEED", "STAT_SPELLDAMAGE",
    "STAT_STURDINESS", "STAT_VERSATILITY", "WEAPON_SPEED" }) do
    if rawget(_G, n) == nil then _G[n] = n end
end
for _, p in ipairs({ "ITEM_MOD_%s_SHORT", "RESISTANCE%d_NAME", "SPELL_STAT%d_NAME" }) do
    for _, w in ipairs({ "ARCANE_DAMAGE_DONE", "ARMOR_PENETRATION_RATING", "ATTACK_POWER", "BLOCK_RATING",
        "BLOCK_VALUE", "CRIT_RATING", "CRIT_SPELL_RATING", "CR_MULTISTRIKE", "DEFENSE_SKILL_RATING", "DODGE_RATING",
        "EXPERTISE_RATING", "FERAL_ATTACK_POWER", "FIRE_DAMAGE_DONE", "FROST_DAMAGE_DONE", "HASTE_SPELL_RATING",
        "HEALTH_REGEN", "HIT_RATING", "HIT_SPELL_RATING", "HOLY_DAMAGE_DONE", "NATURE_DAMAGE_DONE", "PARRY_RATING",
        "POWER_REGEN0", "PVP_POWER", "RANGED_ATTACK_POWER", "RESILIENCE_RATING", "SHADOW_DAMAGE_DONE",
        "SPELL_HEALING_DONE", "SPELL_PENETRATION", "SPELL_POWER", 1, 2, 3, 4, 5, 6 }) do
        local ok, n = pcall(format, p, w)
        if ok and type(w) == (p:find("%%d") and "number" or "string") and rawget(_G, n) == nil then _G[n] = n end
    end
end

local function NS() return H.ns.UADD_Pawn end
local function S() return rawget(_G, "PawnStandIn") end
local CYR = "[\208-\210]"

M.data, M.used = {}, {}
function M.put(path, uk, sort) M.data[path] = { uk, sort ~= "" and sort or nil } end

local watch = CreateFrame("Frame")
watch:RegisterEvent("ADDON_LOADED")
watch:SetScript("OnEvent", function(_, _, name)
    if name ~= "UADD_Pawn" then return end
    local ns = NS()
    if S() then M.data["Code." .. UADD.Hash(S().THANKS)] = { "Квікс дякує команді." } end
    for path, row in pairs(M.data) do
        if ns.AL[path] == nil then
            ns.AL[path], ns.SORT[path] = row[1], row[2]
            M.used[path] = true
        end
    end
end)

-- GameTooltip's lines get their text (the harness only counts lines), with Pawn-like fonts.
local tip = GameTooltip
for i = 1, 8 do
    _G["GameTooltipTextLeft" .. i]:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    _G["GameTooltipTextRight" .. i]:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
end
local function Clear(self)
    for i = 1, 8 do _G["GameTooltipTextLeft" .. i]:SetText(nil) _G["GameTooltipTextRight" .. i]:SetText(nil) end
    self.__lines = 0
    local f = self:GetScript("OnTooltipCleared")
    if f then f(self) end
end
local function Add(self, l, r)
    self.__lines = (self.__lines or 0) + 1
    _G["GameTooltipTextLeft" .. self.__lines]:SetText(l)
    _G["GameTooltipTextRight" .. self.__lines]:SetText(r)
end
tip.ClearLines = Clear
tip.SetOwner = function(self, owner) self.__owner = owner Clear(self) end
tip.SetText = function(self, t) Clear(self) Add(self, t) end
tip.AddLine = function(self, t) Add(self, t) end
tip.AddDoubleLine = function(self, l, r) Add(self, l, r) end
tip.NumLines = function(self) return self.__lines or 0 end

-- ── Reading the game ──────────────────────────────────────────────────────────────────────────

local function At(path)                              -- PawnLocal's value at path, now
    local part, leaf = path:match("^(%a+)%.([%w_]+)$")
    if part then
        local t = rawget(PawnLocal, part)
        return type(t) == "table" and rawget(t, leaf) or nil
    end
    return rawget(PawnLocal, path)
end
M.at = At

local function cyrFont(fs) return UADD.IsCyrFont((fs:GetFont())) and true or false end
M.cyrFont = cyrFont

-- Every word Pawn shows that UADD_Pawn may change, as a flat map: PawnLocal (all of it), the UI globals,
-- the tab label and header lists, the stat rows, every text in Pawn's windows, the saved scales.
local function Texts(f, out, seen)
    if type(f) ~= "table" or seen[f] or not f.GetObjectType then return end
    seen[f] = true
    local name = f:GetName()
    if f:GetObjectType() == "FontString" or f:GetObjectType() == "EditBox" then
        if name then out["F:" .. name] = f:GetText() end
        return
    end
    if name and f.GetFontString and f:GetFontString() then out["F:" .. name] = f:GetFontString():GetText() end
    for _, g in ipairs({ f:GetRegions() }) do Texts(g, out, seen) end
    for _, c in ipairs({ f:GetChildren() }) do Texts(c, out, seen) end
end

function M.snap()
    local out = {}
    for k, v in pairs(PawnLocal) do
        if type(v) == "string" then out["L:" .. k] = v
        elseif type(v) == "table" then
            for k2, v2 in pairs(v) do if type(v2) == "string" then out["L:" .. k .. "." .. tostring(k2)] = v2 end end
        end
    end
    for k, v in pairs(_G) do
        if type(k) == "string" and type(v) == "string" and (k:find("^PawnUIFrame_") or k:find("^BINDING_NAME_PAWN")
            or k:find("^PawnInterfaceOptionsFrame_")) then out["G:" .. k] = v end
    end
    for i, v in ipairs(PawnUITabLabels) do out["T:" .. i] = v end
    for i, v in pairs(PawnUIHeaders) do out["H:" .. i] = v end
    for i, row in ipairs(PawnStats) do
        for _, j in ipairs({ 1, 3, 5 }) do if type(row[j]) == "string" then out["S:" .. i .. ":" .. j] = row[j] end end
    end
    local seen = {}
    for _, r in ipairs({ "PawnUIFrame", "PawnInterfaceOptionsFrame" }) do Texts(_G[r], out, seen) end
    for k, s in pairs(PawnCommon.Scales) do
        out["C:" .. k .. ":Header"] = s.Header
        out["C:" .. k .. ":Name"] = s.LocalizedName
    end
    return out
end

-- Fonts in Pawn's windows: [name] = true for a shown text whose font is wrong (Cyrillic in a font without
-- our letters, or our font on a text with none), and how many have ours.
function M.fonts()
    local bad, n, seen = {}, 0, {}
    local function walk(f)
        if type(f) ~= "table" or seen[f] or not f.GetObjectType then return end
        seen[f] = true
        local fs = f:GetObjectType() == "FontString" and f or nil
        if fs and fs:IsVisible() and fs:GetText() then
            local cyr, ours = fs:GetText():find(CYR) ~= nil, cyrFont(fs)
            if ours then n = n + 1 end
            if cyr ~= ours then bad[#bad + 1] = (f:GetName() or "?") .. "=" .. fs:GetText() end
        end
        if f:GetObjectType() ~= "FontString" then
            for _, g in ipairs({ f:GetRegions() }) do walk(g) end
            for _, c in ipairs({ f:GetChildren() }) do walk(c) end
        end
    end
    walk(PawnUIFrame)
    walk(PawnInterfaceOptionsFrame)
    return bad, n
end

-- Paths the module was given whose PawnLocal value is not what the swap should leave there.
function M.wrong()
    local bad, ns = {}, NS()
    for path, row in pairs(M.data) do
        local en = ns.Swap.English(path) or At(path)
        local want = ns.Swap.Usable(path, en)
        if path:find("^Code%.") or ns.Swap.DISPLAY[path] then want = nil end
        local now = At(path)
        if want and now ~= want then bad[#bad + 1] = path .. " (not ours)" end
        if not want and now ~= en and not path:find("^Code%.") then bad[#bad + 1] = path .. " (changed)" end
    end
    return bad
end
function M.usable(path) local ns = NS(); return ns.Swap.Usable(path, ns.Swap.English(path) or At(path)) end
function M.english(path) return NS().Swap.English(path) or At(path) end
function M.shown(path) return NS().Swap.Shown(path) end
function M.want(path) return NS().AL[path] end
function M.count() return NS().Swap.Count() end
function M.fontCount() return NS().Fonts.Count() end

-- ── Doing things ──────────────────────────────────────────────────────────────────────────────

function M.open() S().Open() end
function M.close() S().Close() end
function M.about(on) S().ShowAbout(on) end
function M.save() S().SaveScales() end
function M.text(name) local f = _G[name]; return f and (f.GetFontString and f:GetFontString() or f):GetText() end
function M.isCyrFont(name) local f = _G[name]; return cyrFont(f.GetFontString and f:GetFontString() or f) end
function M.header(tab, scale)
    PawnUICurrentTabNumber = tab
    PawnUICurrentScale = scale or PawnLocal.NoScale
    PawnUI_ScalesTab_Refresh()
    PawnUIUpdateHeader()
    return PawnUIHeader:GetText(), PawnUIFrame_ScaleNameLabel:GetText()
end

-- One of Pawn's whole texts (no slots) that we translate, a single word when there is one: English, ours.
-- Read from the module's data at run time (no English here). NoScale and the provider headers are not it.
function M.wholeText()
    local ns, paths, best = NS(), {}, nil
    for path in pairs(ns.AL) do paths[#paths + 1] = path end
    table.sort(paths)
    for _, path in ipairs(paths) do
        local en = ns.Swap.English(path)
        local uk = type(en) == "string" and en ~= PawnLocal.NoScale and not ns.Swap.DISPLAY[path]
            and ns.Swap.Translate(en)
        if uk then
            if not en:find("%s") then return en, uk end
            best = best or { en, uk }
        end
    end
    if best then return best[1], best[2] end
end

-- The player's scale named `name` chosen (nil: no scale), shown in the scale-name label as Pawn does.
function M.pickScale(name)
    local sc = PawnCommon.Scales
    sc.Typed = name and { LocalizedName = name } or nil
    PawnUICurrentScale = name and "Typed" or PawnLocal.NoScale
    PawnUI_ScalesTab_Refresh()
    return PawnUIFrame_ScaleNameLabel:GetText()
end

-- Tooltip lines: {left, right, left in our font, right in our font} for each line.
local function Lines()
    local out = {}
    for i = 1, tip:NumLines() do
        local l, r = _G["GameTooltipTextLeft" .. i], _G["GameTooltipTextRight" .. i]
        out[i] = { l:GetText() or "", r:GetText() or "", cyrFont(l), cyrFont(r) }
    end
    return out
end
function M.itemTip(extra)
    S().ItemTip(tip)
    if extra then tip:AddLine(extra) end              -- a line of other code, after Pawn's
    return Lines()
end
function M.helpTip()
    PawnUIFrame_TooltipOn(PawnUIFrame_AlignRightCheck)
    return Lines()
end
function M.clearTip()
    tip:ClearLines()
    for i = 1, 8 do
        if cyrFont(_G["GameTooltipTextLeft" .. i]) or cyrFont(_G["GameTooltipTextRight" .. i]) then return false end
    end
    return true
end

-- Pawn's template at path, formatted now (what Pawn itself would show), for the half-line check.
function M.fmt(path, ...)
    local t = M.shown(path) or At(path)
    local ok, out = pcall(format, t, ...)
    return ok and out or nil
end

function M.key(down)
    H.keys.SHIFT = down
    H.fire("MODIFIER_STATE_CHANGED", "LSHIFT", down and 1 or 0)
    M.wait(0.4)                         -- UADD/Original.lua switches once the key is held a while
end
function M.wait(seconds) for _ = 1, math.ceil(seconds / 0.05 - 1e-6) do H.step(0.05) end end
function M.uadd(msg) return H.call("/uadd " .. msg, SlashCmdList.UADD, msg) end
