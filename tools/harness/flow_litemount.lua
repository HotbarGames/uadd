-- Lua helpers for flow_litemount.py, on the LiteMount stand-in (tools/harness/litemount), which runs the
-- installed LiteMount's own Localization.lua. Reached from Python as HARNESS.litemount.
local H = HARNESS
local M = {}
H.litemount = M

local MOD = "UADD_LiteMount"
local NOT = "LM_NOT_FORMAT"
local function NS() return H.ns[MOD] end
local function Lc() return NS().Locale end
local function S() return rawget(_G, "LiteMountStandIn") end
local function LM() return rawget(_G, "LiteMount").LM end
local function L() return LM().L end

-- The proof that a step has teeth: with M.cut set, one file runs without one fix (in memory only).
local CUTS = {
    usable = { "Locale.lua", '    if type(en) ~= "string" or type(uk) ~= "string" or en == "" or uk == "" then return false end\n',
               '    do return type(uk) == "string" end\n' },
    restore = { "Screen.lua", "function S.Restore() Run(false) end", "function S.Restore() end" },
    hold = { "Module.lua", '        U.SafeCall(ns.Tables.Sync)\n        U.SafeCall(ns.Screen.Apply)\n    end, "LiteMount")',
             '        U.SafeCall(ns.Tables.Sync)\n    end, "LiteMount")' },
    falling = { "Tables.lua",
                "                if Want() and text == Lc.En(SLOT) and Lc.Word(SLOT) then text = Lc.Word(SLOT) end\n", "" },
    fields = { "Tables.lua", "            if want and d[p[2]] == en then d[p[2]] = uk\n", "            if false then\n" },
    keep = { "Locale.lua", "now == uk or (Lc.DYNAMIC[k] and now == EN[k])", "true" },
    filter = { "Copies.lua", "            return function(_, text, ...) return v(root, FilterWord(text), ...) end\n",
               "            return function(_, ...) return v(root, ...) end\n" },
    general = { "Copies.lua", "            data.name = new\n", "" }, rules = { "Copies.lua", '    if type(cache) == "table" then wipe(cache) end\n', "" },
    walk = { "Screen.lua", "    local skip = Theirs(f)\n", "    local skip = {}\n" },
    default = { "Locale.lua", "rawset(L, k, Cyr(g) and uk or EN[k])", "rawset(L, k, now)" },
    counts = { "Locale.lua", ', LM_USABLE = { "TOTAL", "COLLECTED" }', "" },
    whole = { "Copies.lua", "            if not pcall(theirs, owner, Stand(DRY)) then broken = true return theirs(owner, root) end\n", "" },
    announce = { "Copies.lua", "        pcall(Labels, list)\n", "" }, uidebug = { "Copies.lua", "                if ok then msg = t end\n", "" },
}
M.cut, M.wasCut, M.bad = nil, false, nil
M.tests = {}                     -- key -> a test word, used only where the real data has none
local runFile = H.runFile
function H.runFile(addon, path, code)
    local c = M.cut and CUTS[M.cut]
    if addon == MOD and c and path == c[1] then
        local a, b = code:find(c[2], 1, true)
        if a then code, M.wasCut = code:sub(1, a - 1) .. c[3] .. code:sub(b + 1), true end
    end
    local r = runFile(addon, path, code)
    if addon == MOD and path == "data/uk.lua" then
        local UK = NS().UK
        for k, w in pairs(M.tests) do if UK[k] == nil then UK[k] = w end end
        if M.bad then
            UK.LM_PROFILES = UK.LM_PROFILES .. " %s"
            UK.LM_GROUPS = "|cffff0000" .. UK.LM_GROUPS .. "|r"
        end
    end
    return r
end

function M.test(k, w) M.tests[k] = w end
function M.feed(code, noL) LiteMountStandInFeed = { locale = code, noL = noL or nil } end
function M.hold(on) M.held = on UADD.KeyHeld = function() return M.held end UADD.CheckOriginal() end
function M.shown() return UADD.originalShown == true end
function M.wait(seconds) for _ = 1, math.ceil(seconds / 0.05 - 1e-6) do H.step(0.05) end end
function M.uadd(msg) return H.call("/uadd " .. msg, SlashCmdList.UADD, msg) end
function M.on() return NS().On() == true end
function M.written() return Lc().Written() end
function M.word(k) return Lc().Word(k) end
function M.en(k) return Lc().En(k) end
function M.L(k) return rawget(L(), k) end
function M.found() return Lc().Found() end
function M.focus() return GetCurrentKeyBoardFocus() end
function M.resized() return S().resized end
function M.panel(name) return S().panels[name] end
function M.throw(n, what) S()[what or "throw"] = n end

-- ── What the checks read: each text, its English and our word ────────────────────────────────
local function Key(k, tail)
    tail = tail or ""
    return function() local w = Lc().Word(k) if w then return Lc().En(k) .. tail, w .. tail end end
end
local POPS = {
    { "LM_OPTIONS_NEW_GROUP", "text", "LM_NEW_GROUP", "LiteMount : %s" },
    { "LM_OPTIONS_NEW_GROUP", "button1", "LM_CREATE_PROFILE_GROUP", "%s" },
    { "LM_OPTIONS_NEW_GROUP", "button2", "LM_CREATE_GLOBAL_GROUP", "%s" },
    { "LM_OPTIONS_RENAME_GROUP", "text", "LM_RENAME_GROUP", "LiteMount : %s" },
    { "LM_OPTIONS_DELETE_GROUP", "text", "LM_DELETE_GROUP", "LiteMount : %s" },
    { "LM_OPTIONS_NEW_PROFILE", "text", "LM_NEW_PROFILE", "LiteMount : %s" },
    { "LM_OPTIONS_RESET_PROFILE", "text", "LM_RESET_PROFILE", "LiteMount : %s %%s" },
}
local function P(name) return S().panels[name] end
local ITEMS = {
    { "Groups title", function() return P("groups").name end, Key("LM_GROUPS") },
    { "Groups category", function() return P("groups").category.name end, Key("LM_GROUPS") },
    { "Profiles title", function() return P("profiles").name end, Key("LM_PROFILES") },
    { "Profiles category", function() return P("profiles").category.name end, Key("LM_PROFILES") },
    { "New Profile button", function() return P("profiles").LM_NEW_PROFILE:GetText() end, Key("LM_NEW_PROFILE") },
    { "Import Profile button", function() return P("profiles").LM_IMPORT_PROFILE:GetText() end, Key("LM_IMPORT_PROFILE") },
    { "Mounts priority label", function() return P("mounts").LM_PRIORITY:GetText() end, Key("LM_PRIORITY") },
    { "Mounts tab 1", function() return P("mounts").Tab1:GetText() end, Key("LM_LIST_VIEW") },
    { "Mounts tab 2", function() return P("mounts").Tab2:GetText() end, Key("LM_MODEL_VIEW") },
    { "macro help", function() return P("macro").Macro.ExplainText:GetText() end, Key("LM_MACRO_EXP") },
    { "current profile label", function() return P("profiles").CurrentProfileLabel:GetText() end,
      Key("LM_CURRENT_PROFILE", " :") },
    { "Import button", function() return P("import").ImportButton:GetText() end,
      function() return "Import", Lc().Extra("Import", "Import") end },
    { "condition name (mounted)", function() return LM().Conditions:GetCondition("mounted").name end, Key("LM_MOUNTED") },
    { "action name", function() return LM().Actions:ToDisplay("Limit") end, Key("LM_LIMIT_MOUNTS") },
    { "action description", function() return LM().Actions:GetDescription("Limit") end, Key("LM_LIMITSET_DESCRIPTION") },
    { "sort key text", function() return LM().UIFilter.GetSortKeyText("priority") end, Key("LM_PRIORITY") },
    { "filter prio:3", function() return LM().Mount.FilterToDisplay("prio:3") end, Key("LM_PRIORITY", " : 3") },
    { "rule line ~mounted", function() return S().ruleLine("~mounted") end, function()
        local n, m = Lc().Word(NOT), Lc().Word("LM_MOUNTED")
        if not (n and m) then return nil end
        return format(Lc().En(NOT), Lc().En("LM_MOUNTED")), format(n, m)
    end },
    { "filter ~prio:3", function() return LM().Mount.FilterToDisplay("~prio:3") end, function()
        local n, p = Lc().Word(NOT), Lc().Word("LM_PRIORITY")
        if not (n and p) then return nil end
        return format(Lc().En(NOT), Lc().En("LM_PRIORITY") .. " : 3"), format(n, p .. " : 3")
    end },
    { "Falling dropdown radio", function() return S().radioText() end, function()
        if not P("add"):IsShown() then return nil end
        return Key("LM_EQUIPMENT_SLOT")()
    end },
}
for _, p in ipairs(POPS) do
    ITEMS[#ITEMS + 1] = { "dialog " .. p[1] .. "." .. p[2], function() return StaticPopupDialogs[p[1]][p[2]] end,
        function()
            local w = Lc().Word(p[3])
            if not w then return nil end
            return format(p[4], Lc().En(p[3])), format(p[4], w)
        end }
end
for n = 1, 4 do
    local name = "BINDING_NAME_CLICK LM_B" .. n .. ":LeftButton"
    ITEMS[#ITEMS + 1] = { "key binding " .. n, function() return rawget(_G, name) end, function()
        local en = format("LiteMount %s %d", KEY_BINDING or "Key Binding", n)
        local w = Lc().Extra("BINDING_" .. n, en)
        if not w then return nil end
        return en, w
    end }
end
local LKEYS = { "LM_GROUPS", "LM_PROFILES", "LM_PRIORITY", "LM_NEW_GROUP", "LM_MOUNTED", "LM_EQUIPMENT_SLOT",
    "LM_LIMIT_MOUNTS", "LM_CURRENT_PROFILE", "LM_SPELL_KNOWN" }
for _, k in ipairs(LKEYS) do
    ITEMS[#ITEMS + 1] = { "L." .. k, function() return rawget(L(), k) end, Key(k) }
end

-- want "uk" or "en": every item that has our word shows it (or its English). -> ok, how many, what is wrong.
-- only: a Lua pattern on the item's name (nil: all).
function M.compare(want, only)
    local bad, n = {}, 0
    for _, it in ipairs(ITEMS) do
        local en, uk
        if not only or it[1]:find(only) then en, uk = it[3]() end
        if en and uk then
            n = n + 1
            local ok, now = pcall(it[2])
            local expect = want == "uk" and uk or en
            if not ok or now ~= expect then bad[#bad + 1] = it[1] .. " = " .. tostring(now) end
        end
    end
    return #bad == 0 and n > 0, n, table.concat(bad, "; ")
end

-- Any text of the items that is one of our words (another language's client, no L: none may be); cyr: any
-- Cyrillic at all (no L: LiteMount shows its keys).
function M.anyOurs(cyr)
    local out = {}
    for _, it in ipairs(ITEMS) do
        local ok, now = pcall(it[2])
        if ok and type(now) == "string" and (Lc().IsOurs(now) or (cyr and now:find("[\208-\211]"))) then
            out[#out + 1] = it[1]
        end
    end
    return table.concat(out, "; ")
end

-- Every L key that still holds one of our words (a word the same as its English, as "%0.1f%%", is not one).
function M.left()
    local n = 0
    for k, v in pairs(L()) do if Lc().IsOurs(v) and v ~= Lc().En(k) then n = n + 1 end end
    return n
end

function M.showAll(...)
    for _, name in ipairs({ ... }) do local f = P(name) f:Hide() f:Show() f:Hide() end
end
function M.names(group, typed, mount, arg, added) S().names(group, typed, mount, arg, added) end
function M.namesNow() return S().namesNow() end

-- The filter menu as it opens now: its top items and its submenu items, each joined with " | ".
function M.filterOpen()
    local top, sub = S().filterOpen()
    return table.concat(top, " | "), table.concat(sub, " | ")
end
function M.filterIsTheirs() return S().filterIsTheirs() end
-- What a copy should show: want "uk" our words (nil when one has none), "en" the English.
local function Words(want, keys)
    local out = {}
    for _, k in ipairs(keys) do
        out[#out + 1] = want == "uk" and Lc().Word(k) or Lc().En(k)
        if not out[#out] then return nil end
    end
    return out
end
function M.filterExpect(want)
    local w = Words(want, { "LM_HIDDEN", "LM_ZONEMATCH", "LM_PRIORITY", "LM_GROUP" })
    return w and table.concat(w, " | ")
end
-- The General page's option names now, and what they should be.
function M.generalNames() return table.concat(S().generalNames(), " | ") end
function M.generalExpect(want)
    local w, t = Words(want, S().GENERAL), Words(want, { "LM_MOUNTSPECIAL_TIMER" })
    if not (w and t) then return nil end
    w[#w + 1] = format(t[1], EMOTE171_CMD1)
    return table.concat(w, " | ")
end
function M.setGlobal(g, s) local was = rawget(_G, g) if s then _G[g] = s end return was end   -- a game global
-- A line LiteMount glues to that global, as drawn now, and the word it also shows alone (false: none).
function M.glued(g) local ok, a, b = pcall(S().glued, g) if not ok then return "error: " .. tostring(a), false end return a, b or false end
-- A rule error as LiteMount prints it now (compiled when its cache is empty), and what it should be.
function M.ruleError() return S().ruleError() end
function M.ruleExpect(want)
    local w = Words(want, { "LM_ERR_BAD_RULE", "LM_ERR_BAD_ACTION" })
    return w and format(w[1], "zorp", format(w[2], "zorp"))
end
function M.profile(name) S().profile(name) end
function M.profileNow() return P("profiles").CurrentProfile:GetText() end
function M.rule(s) return S().ruleLine(s) end
function M.filter(f) return LM().Mount.FilterToDisplay(f) end
function M.group(name) S().groups[name] = true end
function M.radios() return table.concat(S().radios, " | ") end
function M.radioText() return S().radioText() end
function M.generator() return type(rawget(P("add").Dropdown, "menuGenerator")) end
function M.showAdd() P("add"):Hide() P("add"):Show() end
function M.hideAdd() P("add"):Hide() end

-- LiteMount changes a text after we wrote ours (another language, its own code): L, a dialog, a key binding
-- name, a panel text.
function M.change(on)
    local D = StaticPopupDialogs.LM_OPTIONS_NEW_PROFILE
    local b = "BINDING_NAME_CLICK LM_B1:LeftButton"
    if on then
        rawset(L(), "LM_GROUPS", "Gruppen")
        D.text = "LiteMount : Neues Profil"
        _G[b] = "LiteMount Taste 1"
        P("profiles").LM_NEW_PROFILE:SetText("Neues Profil")
        return
    end
    rawset(L(), "LM_GROUPS", Lc().En("LM_GROUPS"))
    D.text = format("LiteMount : %s", Lc().En("LM_NEW_PROFILE"))
    _G[b] = format("LiteMount %s %d", KEY_BINDING or "Key Binding", 1)
    P("profiles").LM_NEW_PROFILE:SetText(Lc().En("LM_NEW_PROFILE"))
end
function M.changedNow()
    return rawget(L(), "LM_GROUPS"), StaticPopupDialogs.LM_OPTIONS_NEW_PROFILE.text,
        rawget(_G, "BINDING_NAME_CLICK LM_B1:LeftButton"), P("profiles").LM_NEW_PROFILE:GetText()
end

-- ── Half lines (halves_mods.litemount) ────────────────────────────────────────────────────────
local SPEC = "%%[%d%$%-%+#0]*%.?%d*[%a%%]"
local function Slots(en, text)
    local pat, specs, at = "^", {}, 1
    while true do
        local a, b = en:find(SPEC, at)
        local lit = a and en:sub(at, a - 1) or en:sub(at)
        pat = pat .. (lit:gsub("%W", "%%%0"))
        if not a then break end
        local s = en:sub(a, b)
        if s == "%%" then pat = pat .. "%%" else pat = pat .. "(.-)" specs[#specs + 1] = s end
        at = b + 1
    end
    local vals = { text:match(pat .. "$") }
    if #vals ~= #specs then return nil end
    for i, s in ipairs(specs) do if not s:find("s$") then vals[i] = tonumber(vals[i]) end end
    return vals
end

-- Keys with a slot that the module writes (not NEVER) and has a word for, the word not the English itself.
function M.templateKeys()
    local out = {}
    for k in pairs(L()) do
        local en, w = type(k) == "string" and Lc().En(k), type(k) == "string" and Lc().Word(k)
        if w and k:find("^LM_") and en:find("%%") and not Lc().NEVER[k] and w ~= en then out[#out + 1] = k end
    end
    table.sort(out)
    return table.concat(out, "\n")
end
function M.isFree(k) return Lc().FREE[k] ~= nil end

-- A text as LiteMount builds it from L: format(L[k], its values); "Not %s" through both of its paths.
function M.half(k, text)
    local vals = Slots(Lc().En(k), text)
    if not vals then return nil end
    if k == NOT then
        LM().Conditions:GetCondition("harness").name = vals[1]
        return S().ruleLine("~harness"), LM().Mount.FilterToDisplay("~" .. vals[1])
    end
    local ok, out = pcall(format, rawget(L(), k) or Lc().En(k), unpack(vals))
    return ok and out or nil
end
