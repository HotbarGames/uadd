-- Lua helpers for flow_litemount_shots.py: the texts the owner's shots showed English or as boxes (2026-11-21), and
-- the game names in LiteMount's lists (the stand-in's litemount/Shots.lua). Runs after flow_litemount.lua, on the
-- same HARNESS.litemount.
local H = HARNESS
local M = H.litemount
local MOD = "UADD_LiteMount"
local function Lc() return H.ns[MOD].Locale end
local function T() return rawget(_G, "LiteMountStandIn").shots end

-- One more fix cut out per mutant, as in flow_litemount.lua (in memory only).
local CUTS = {
    sfont = { "Fonts.lua", "    local ok, took = pcall(UADD.CyrFix, fs, changed)", "    local ok, took = true, true" },
    sgiveup = { "Fonts.lua", "if type(put) == \"function\" and select(2, pcall(put, fs)) == true then break end", "" },
    spages = { "Screen.lua", '"MOUNTS", "MACROS", "GROUP", ', "" },
    shint = { "Screen.lua", 'Swap(rawget(c, "Instructions"), want)', "false" },
    scounts = { "Rows.lua", 'Line(rawget(m, "Counts"), Counts)', "" },
    schars = { "Rows.lua", 'Line(rawget(mac, "Count"), Chars)', "" },
    sprio = { "Locale.lua", "Lc.NEVER = {\n", 'Lc.NEVER = {\n    LM_PRIORITY_DESC0 = "cut", LM_PRIORITY_DESC4 = "cut",\n' },
    srows = { "Rows.lua", 'hooksecurefunc(mix, "Initialize", OnRow)', "" },
    smounts = { "Rows.lua", 'hooksecurefunc(mm, "Initialize", OnMount)', "" },
    sfalling = { "Rows.lua", "Line(n, NAMES[kind] or NONE)", "" },
    skind = { "Rows.lua", "NAMES[kind] or NONE", "NAMES.spell" },
}
local runFile = H.runFile
function H.runFile(addon, path, code)
    local c = M.cut and CUTS[M.cut]
    if addon == MOD and c and path == c[1] then
        local a, b = code:find(c[2], 1, true)
        if a then code, M.wasCut = code:sub(1, a - 1) .. c[3] .. code:sub(b + 1), true end
    end
    return runFile(addon, path, code)
end

-- want "uk": our word, "en": the English; nil when we have no word.
local function Want(g, want)
    local en, uk = Lc().Global(g)
    if not uk then return nil end
    return want == "uk" and uk or en
end

-- LiteMount's lines with Cyrillic drawn in a font without it (boxes), its panels shown for the look.
function M.shotBoxes()
    local shown = {}
    for _, n in ipairs({ "LiteMountMountsPanel", "LiteMountMacroPanel", "LiteMountGroupsPanel", "LiteMountProfilesPanel",
        "LiteMountFallingPanel" }) do
        local f = rawget(_G, n)
        if type(f) == "table" and f.Show and not f:IsShown() then f:Show() shown[#shown + 1] = f end
    end
    local out = {}
    for _, l in ipairs(H.cyrBoxes(200)) do if l:find("LiteMount", 1, true) then out[#out + 1] = l end end
    for _, f in ipairs(shown) do f:Hide() end
    return table.concat(out, " || ")
end

-- The page titles, the search box's hint, the macro tabs and labels, in T().globals' order.
function M.shotTexts()
    local out = {}
    for _, fs in ipairs(T().texts) do out[#out + 1] = tostring(fs:GetText()) end
    return table.concat(out, " | ")
end
function M.shotTextsExpect(want)
    local out = {}
    for _, g in ipairs(T().globals) do
        local w = Want(g, want)
        if not w then return nil end
        out[#out + 1] = w
    end
    return table.concat(out, " | ")
end

-- The counts line and the character count as shown, then after LiteMount sets them again.
local function Lines()
    local m, mac = rawget(_G, "LiteMountMountsPanel"), rawget(_G, "LiteMountMacroPanel")
    return tostring(m.Counts:GetText()) .. " || " .. tostring(mac.Macro.Count:GetText())
end
function M.shotCounts() local a = Lines() T().refresh() return a .. " ### " .. Lines() end
local function W(n) return "|cffffffff" .. n .. "|r" end
function M.shotCountsExpect(want)
    local t, c, u = Want("TOTAL", want), Want("COLLECTED", want), want == "uk" and Lc().Word("LM_USABLE") or Lc().En("LM_USABLE")
    local m = Want("MACROFRAME_CHAR_LIMIT", want)
    if not (t and c and u and m) then return nil end
    local a = t .. ": " .. W(120) .. " " .. c .. ": " .. W(64) .. " " .. u .. ": " .. W(31) .. " || " .. m:gsub("%%d", "42")
    return a .. " ### " .. a
end

-- Priority 0 and 4 (L.LM_PRIORITY_DESC0 = DISABLE, DESC4 = ALWAYS).
function M.shotPrio()
    return tostring(M.L("LM_PRIORITY_DESC0")) .. " | " .. tostring(M.L("LM_PRIORITY_DESC4"))
end
function M.shotPrioExpect(want)
    local a, b = rawget(_G, "DISABLE"), rawget(_G, "ALWAYS")
    if want == "uk" then a, b = Lc().Word("LM_PRIORITY_DESC0"), Lc().Word("LM_PRIORITY_DESC4") end
    if not (a and b) then return nil end
    return a .. " | " .. b
end

-- The Falling rows' Delete: a row made at login and one made now.
function M.shotRows()
    local out = {}
    for _, b in ipairs(T().rows) do out[#out + 1] = tostring(b.DeleteButton:GetText()) end
    return table.concat(out, " | ")
end
function M.shotRowsExpect(want)
    local w = Want("DELETE", want)
    if not w then return nil end
    local out = {}
    for i = 1, #T().rows do out[i] = w end
    return table.concat(out, " | ")
end
function M.shotRow(data) return T().row(data) end

-- Game names: a stand-in UALL Forever that knows a few made-up names (UADD.UALL, lesson 20).
local SPELL = { ["Quix Drift"] = "Квікс-дрейф", ["Quix Strider"] = "Квікс-крокун", ["Quix Lynx"] = "Квікс-рись" }
local ITEM = { ["Quix Plume"] = "Квікс-перо" }
M.asked = {}
function M.shotStub(mode)
    local U = UADD.UALL
    U.Spell = function(t) M.asked[#M.asked + 1] = t if mode == "later" then return nil, true end return SPELL[t] end
    U.Item = function(t) M.asked[#M.asked + 1] = t if mode == "later" then return nil, true end return ITEM[t] end
end
function M.shotAsked() return table.concat(M.asked, " | ") end
-- The mount rows and the Falling rows (spell names come later, as ContinueOnSpellLoad does), " | "-joined.
function M.shotNames()
    T().flush()
    local out = {}
    for _, b in ipairs(T().mountRows) do out[#out + 1] = tostring(b.Name:GetText()) end
    out[#out + 1] = "##"
    for _, b in ipairs(T().rows) do if b.Name then out[#out + 1] = tostring(b.Name:GetText()) end end
    return table.concat(out, " | ")
end
function M.shotNamesExpect(want)
    local function N(en, tab) return want == "uk" and tab[en] or en end
    local out = {}
    for _, b in ipairs(T().mountRows) do out[#out + 1] = N(b.mount.name, SPELL) end
    out[#out + 1] = "##"
    for _, b in ipairs(T().rows) do
        if b.Name then
            local en = T().NAME[b.data]
            local kind = b.data:match("^(%a+):")
            out[#out + 1] = kind == "spell" and N(en, SPELL) or kind == "item" and N(en, ITEM) or en
        end
    end
    return table.concat(out, " | ")
end
function M.shotMount(name, collected) return T().mount(name, collected) end

-- Texts no Cyrillic font can take (lessons 45, 46): a secure Profiles button whose states stay Latin, and a new
-- Falling row's name the box guard gave up on (U.BoxGiveUp). A failed fix is never watched, so each must show its
-- whole English. made(): both made, the walk run, LiteMount's own SetText with our word, the row named again.
-- now(): the button's text | the row's name | the box hits.
local giveUp = {}
function M.shotGiveUpNow()
    return tostring(giveUp.b:GetText()) .. " | " .. tostring(giveUp.r.Name:GetText()) .. " | " .. M.shotBoxes()
end
function M.shotGiveUp()
    local b = CreateFrame("Button", nil, rawget(_G, "LiteMountProfilesPanel"))
    b:SetNormalFontObject(GameFontNormal)
    b:SetHighlightFontObject(GameFontHighlight)
    b:SetDisabledFontObject(GameFontDisable)
    rawset(b, "IsProtected", function() return true end)
    b:SetText(Lc().En("LM_NEW_PROFILE"))
    local r = T().row("spell:130")
    T().flush()
    giveUp.b, giveUp.r = b, r
    H.ns[MOD].Screen.Apply()                          -- the walk: ours on, no font takes
    b:SetText(Lc().Word("LM_NEW_PROFILE"))            -- LiteMount's own SetText, with its L word (ours)
    local named = tostring(r.Name:GetText())
    UADD.BoxGiveUp(r.Name)                            -- the guard found boxes on it twice
    H.pump(2)
    r:Initialize("spell:130")
    T().flush()
    return named .. " ## " .. M.shotGiveUpNow()
end
function M.shotGiveUpExpect()
    return Lc().En("LM_NEW_PROFILE") .. " | " .. T().NAME["spell:130"] .. " | "
end
function M.shotReuse(i, data) T().rows[i]:Initialize(data) T().flush() end
