-- Our words in what GatherMate2's settings copied at load, and its English back.
--   * Option tables: GatherMate2 builds them once, with its English copied in (names, descriptions, confirm
--     texts, the lists of professions and expansions). Each is walked and every English text Swap.lua knows
--     gets ours. A list (`values`) is changed only when every entry in it is ours: its node and zone lists
--     hold game names and stay as they are (lesson 9).
--   * Page names: its sub-pages in the game's settings list ("Panel.<app>" rows); the root keeps its name.
--   * Profiles tab: AceDBOptions shares one table of its English between every addon that uses it, so
--     GatherMate2's tab gets its own copy with ours; off gives the shared one back. Profile names are never
--     changed (lesson 13).
--   * Key binding hint: AceGUI's Keybinding widget writes it once, and widgets are pooled; ours goes on the
--     widgets GatherMate2's pages get, and its English back when the widget is released.
-- A text is changed only while it is still the English our row was made from (data/libs.lua hashes).

local _, ns = ...
local U = UADD
local O = {}
ns.Options = O

local APP = "GatherMate2"
local ROOT = "GatherMate 2"
local PROFILES = "GM2/Profiles"
local FIELDS = { "name", "desc", "confirmText" }
local DBO_MINOR = 17                -- the AceDBOptions-3.0 our "current profile" line is made for
local edits, cats, hints = {}, {}, {}
local dbo                           -- { tbl, args, name, desc } while GatherMate2's Profiles tab is ours
local hooked = false

function O.IsOurs(app)
    return app == ROOT or (type(app) == "string" and app:sub(1, 4) == "GM2/")
end

-- Ours for a lib or panel row, when `en` is still the English the row was made from.
local function Lib(key, en)
    local ua = ns.AL[key]
    if type(en) == "string" and ua and ns.EN and ns.EN[key] == U.Hash(en) then return ua end
end

-- ── Option tables ─────────────────────────────────────────────────────────────────────────────

local function Put(t, k, ua)
    local en = t[k]
    if not ua or en == ua then return end
    t[k] = ua
    edits[#edits + 1] = { t = t, k = k, en = en, ua = ua }
end

local function Walk(opt, seen)
    if type(opt) ~= "table" or seen[opt] then return end
    seen[opt] = true
    for _, f in ipairs(FIELDS) do Put(opt, f, ns.Swap.Translate(rawget(opt, f))) end
    local vals = rawget(opt, "values")
    if type(vals) == "table" and next(vals) ~= nil then
        local all = true
        for _, v in pairs(vals) do
            if not ns.Swap.Translate(v) then all = false break end
        end
        if all then
            for k, v in pairs(vals) do Put(vals, k, ns.Swap.Translate(v)) end
        end
    end
    if type(rawget(opt, "args")) == "table" then
        for _, sub in pairs(opt.args) do Walk(sub, seen) end
    end
end

local function Registry() return LibStub and LibStub("AceConfigRegistry-3.0", true) end

local function Tables()
    local reg = Registry()
    if not reg or type(reg.tables) ~= "table" then return end
    for app in pairs(reg.tables) do
        if O.IsOurs(app) and app ~= PROFILES then
            local ok, t = pcall(reg.GetOptionsTable, reg, app, "dialog", "UADD-1.0")
            if ok and type(t) == "table" then Walk(t, {}) end
        end
    end
end

-- ── Page names ────────────────────────────────────────────────────────────────────────────────

local function Pages()
    local acd = LibStub and LibStub("AceConfigDialog-3.0", true)
    local list = acd and acd.BlizOptions
    if type(list) ~= "table" or not Settings or type(Settings.GetCategory) ~= "function" then return end
    for app, groups in pairs(list) do
        if O.IsOurs(app) and app ~= ROOT and type(groups) == "table" then
            for _, g in pairs(groups) do
                local id = type(g) == "table" and g.frame and g.frame.name
                local ok, cat = pcall(Settings.GetCategory, id)
                local en = ok and type(cat) == "table" and (cat.GetName and cat:GetName() or cat.name)
                local ua = Lib("Panel." .. app:sub(5), en)
                if ua then
                    if type(cat.SetName) == "function" then cat:SetName(ua) else cat.name = ua end
                    if type(g.SetTitle) == "function" then g:SetTitle(ua) end
                    cats[#cats + 1] = { g = g, cat = cat, en = en, ua = ua }
                end
            end
        end
    end
end

-- ── Profiles tab ──────────────────────────────────────────────────────────────────────────────

-- { arg, field, AceDBOptions key, how the English sits there: "" alone, "<" after a line break, ">" before one }
local DBO = {
    { "desc", "name", "intro", ">" }, { "descreset", "name", "reset_desc", "" },
    { "reset", "name", "reset", "" }, { "reset", "desc", "reset_sub", "" },
    { "choosedesc", "name", "choose_desc", "<" }, { "new", "name", "new", "" }, { "new", "desc", "new_sub", "" },
    { "choose", "name", "choose", "" }, { "choose", "desc", "choose_sub", "" },
    { "copydesc", "name", "copy_desc", "<" }, { "copyfrom", "name", "copy", "" },
    { "copyfrom", "desc", "copy_desc", "" }, { "deldesc", "name", "delete_desc", "<" },
    { "delete", "name", "delete", "" }, { "delete", "desc", "delete_sub", "" },
    { "delete", "confirmText", "delete_confirm", "" },
}

local function Core(s, how)
    if type(s) ~= "string" then return nil end
    if how == "<" then return s:sub(1, 1) == "\n" and s:sub(2) or nil end
    if how == ">" then return s:sub(-1) == "\n" and s:sub(1, -2) or nil end
    return s
end

local function Wrap(ua, how)
    return (how == "<" and "\n" .. ua) or (how == ">" and ua .. "\n") or ua
end

local function Profiles()
    local lib = LibStub and LibStub("AceDBOptions-3.0", true)
    local AA = LibStub and LibStub("AceAddon-3.0", true)
    local gm = AA and AA:GetAddon(APP, true)
    local tbl = lib and gm and type(lib.optionTables) == "table" and lib.optionTables[gm.db]
    if dbo or type(tbl) ~= "table" or type(tbl.args) ~= "table" then return end
    local copy = {}
    for k, a in pairs(tbl.args) do
        local c = {}
        for f, v in pairs(type(a) == "table" and a or {}) do c[f] = v end
        copy[k] = type(a) == "table" and c or a
    end
    local n = 0
    for _, r in ipairs(DBO) do
        local a = copy[r[1]]
        local ua = type(a) == "table" and Lib("AceDBO." .. r[3], Core(a[r[2]], r[4]))
        if ua then
            a[r[2]] = Wrap(ua, r[4])
            n = n + 1
        end
    end
    local cur, word = copy.current, ns.AL["AceDBO.current"]
    if type(cur) == "table" and word and LibStub.minors and LibStub.minors["AceDBOptions-3.0"] == DBO_MINOR then
        cur.name = function(info)
            local h = info and info.handler
            local p = h and h.GetCurrentProfile and h:GetCurrentProfile() or ""
            return word .. " " .. (NORMAL_FONT_COLOR_CODE or "") .. p .. (FONT_COLOR_CODE_CLOSE or "")
        end
        n = n + 1
    end
    if n == 0 then return end
    dbo = { tbl = tbl, args = tbl.args, name = tbl.name, desc = tbl.desc, n = n }
    tbl.args = copy
    tbl.name = Lib("AceDBO.profiles", tbl.name) or tbl.name
    tbl.desc = Lib("AceDBO.profiles_sub", tbl.desc) or tbl.desc
end

local function ProfilesBack()
    if not dbo then return end
    dbo.tbl.args, dbo.tbl.name, dbo.tbl.desc = dbo.args, dbo.name, dbo.desc
    dbo = nil
end

-- ── Key binding hint ──────────────────────────────────────────────────────────────────────────

local function Hint(w)
    local msg = type(w) == "table" and w.type == "Keybinding" and w.msgframe and w.msgframe.msg
    if not msg or hints[w] then return end
    local en = msg.GetText and msg:GetText()
    local ua = Lib("AceGUI.keybinding_hint", en)
    if ua then
        hints[w] = en
        msg:SetText(ua)
        UADD.AceFont.Set(msg, APP)
    end
end

local function Children(w, depth)
    Hint(w)
    if depth < 8 and type(w) == "table" and type(w.children) == "table" then
        for _, c in ipairs(w.children) do Children(c, depth + 1) end
    end
end

local function HintBack(w)
    local en = hints[w]
    if not en then return end
    hints[w] = nil
    local msg = w.msgframe and w.msgframe.msg
    if msg then
        msg:SetText(en)
        UADD.AceFont.Back(msg)
    end
end

function O.Install()
    if hooked then return end
    local acd = LibStub and LibStub("AceConfigDialog-3.0", true)
    local gui = LibStub and LibStub("AceGUI-3.0", true)
    if not acd or not gui or type(acd.FeedGroup) ~= "function" or type(gui.Release) ~= "function" then return end
    hooked = true
    hooksecurefunc(acd, "FeedGroup", function(_, app, _, container)
        if O.IsOurs(app) and ns.WordsWanted() then U.SafeCall(Children, container, 0) end
    end)
    hooksecurefunc(gui, "Release", function(_, w)
        if hints[w] then U.SafeCall(HintBack, w) end
    end)
end

-- ── On and off ────────────────────────────────────────────────────────────────────────────────

local function Notify()
    local reg = Registry()
    if not reg or type(reg.tables) ~= "table" then return end
    for app in pairs(reg.tables) do
        if O.IsOurs(app) then pcall(reg.NotifyChange, reg, app) end
    end
end

-- Ours on every word it copied at load (again after the hold key: nothing twice).
function O.Apply()
    if not ns.WordsWanted() then return end
    Tables()
    Pages()
    Profiles()
    Notify()
end

-- GatherMate2's English back, where ours still is.
function O.Restore()
    for i = #edits, 1, -1 do
        local e = edits[i]
        if e.t[e.k] == e.ua then e.t[e.k] = e.en end
        edits[i] = nil
    end
    for i = #cats, 1, -1 do
        local c = cats[i]
        local now = c.cat.GetName and c.cat:GetName() or c.cat.name
        if now == c.ua then
            if type(c.cat.SetName) == "function" then c.cat:SetName(c.en) else c.cat.name = c.en end
            if type(c.g.SetTitle) == "function" then c.g:SetTitle(c.en) end
        end
        cats[i] = nil
    end
    ProfilesBack()
    for w in pairs(hints) do U.SafeCall(HintBack, w) end
    Notify()
end

function O.Count() return #edits + #cats + (dbo and dbo.n or 0) end
