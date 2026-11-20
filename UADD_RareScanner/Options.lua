-- Words RareScanner read once while it loaded, before our words were in its locale table (Module.lua):
--   * its settings tables (AceConfig, one app per settings page): each name, desc, confirmText and
--     list entry (values) that is a finished English text of RareScanner gets ours. Fields that are
--     functions read the locale table each time, so they need nothing. A page built by a function
--     (Custom NPCs: built on first use, built again after an import) is built with RareScanner's
--     English in its table and changed here like the rest, so "off" can put the English back.
--   * its settings page names in the game's settings list (AceConfigDialog's BlizOptions): the
--     category's name and the page title. AddToBlizOptions is never called again (no second category).
--   * its pop-ups (its own copy of LibDialog: the delegates' text).
--   * the explorer's labels and tooltips (LABELS): set once, when it first opens; both ways each time.
-- A finished line is read back with RareScanner's English template (O.Translate): all of it ours, or it
-- stays as it is (no half lines). Each change is kept; Restore puts the English back where ours still is.

local _, ns = ...
local U = UADD
local O = {}
ns.Options = O

local PREFIX = "^RareScanner"                  -- its AceConfig app names start so
local SKIP = { ["RareScanner Profiles"] = true } -- AceDBOptions' own words (the player's profile names)
local FIELDS = { "name", "desc", "confirmText" }

local edits = {}                                -- { t, k, en, uk }: one changed field
local apps = {}                                 -- app names whose table we changed (NotifyChange)
local walked = setmetatable({}, { __mode = "k" }) -- settings tables already changed (until Restore)
local mine = setmetatable({}, { __mode = "k" })   -- our wrappers in AceConfigRegistry.tables
local pats = {}                                 -- key -> { pat, lit, specs } (made once per English)
local memo, memoSize, MEMO_MAX = {}, 0, 2000    -- text -> Ukrainian or false (wiped on new words, and at MEMO_MAX)

-- ── A finished line ───────────────────────────────────────────────────────────────────────────

local function Pattern(en)
    local out, lit, best, i = { "^" }, "", "", 1
    local function Cut() if #lit > #best then best = lit end lit = "" end
    while i <= #en do
        local s, e, conv = en:find("^%%[-+ #0]*%d*%.?%d*(%a)", i)
        if en:sub(i, i + 1) == "%%" then
            out[#out + 1], lit, i = "%%", lit .. "%", i + 2
        elseif s then
            out[#out + 1] = (conv == "d" or conv == "i") and "(%-?%d+)" or conv == "f" and "(%-?[%d%.]+)" or "(.-)"
            Cut()
            i = e + 1
        else
            local c = en:sub(i, i)
            out[#out + 1] = c:find("^%w$") and c or "%" .. c
            lit, i = lit .. c, i + 1
        end
    end
    Cut()
    out[#out + 1] = "$"
    return { pat = table.concat(out), lit = best, specs = ns.Specs(en) }
end

-- A slot's text RareScanner passed in: kept (a value, a free name), ours (its own word), or nil.
local function Arg(kind, a)
    if kind == "t" then
        local uk = ns.Reverse[a]
        if uk then return uk end
        return not a:find("%a") and a or nil
    end
    -- a value: a number, a time, money, a colour or a link; never English words
    local p = a:gsub("|H.-|h.-|h", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
    if kind ~= "f" and p:find("%a%a") then return nil end
    return a
end

local function FromTemplate(s)
    for key in pairs(ns.Templates) do
        local en = ns.English(key)
        local p = en and pats[key]
        if en and not p then p = Pattern(en) pats[key] = p end
        -- cheapest test first: its longest English piece must be in the text (a template with no
        -- letters around its slots would match anything: never used here)
        if p and p.lit:find("%a") and s:find(p.lit, 1, true) then
            local got = { s:match(p.pat) }
            if #got > 0 and #got == #p.specs then
                local sort, args, ok = ns.SORT[key], {}, true
                for i, a in ipairs(got) do
                    local c = p.specs:sub(i, i)
                    local kind = type(sort) == "string" and sort:sub(i, i) or (c == "s" and "t" or "v")
                    local v = kind ~= "n" and Arg(kind, a)
                    if not v then ok = false break end
                    if c ~= "s" then v = tonumber(v) if not v then ok = false break end end
                    args[i] = v
                end
                if ok then
                    local fine, uk = pcall(string.format, ns.AL[key], unpack(args))
                    if fine and type(uk) == "string" then return uk end
                end
            end
        end
    end
    return nil
end

-- Ours for one of RareScanner's finished English lines, or nil.
function O.Translate(s)
    if type(s) ~= "string" or s == "" or not s:find("%a") then return nil end
    local m = memo[s]
    if m == nil then
        m = ns.Reverse[s] or FromTemplate(s) or false
        if memoSize >= MEMO_MAX then wipe(memo) memoSize = 0 end memo[s], memoSize = m, memoSize + 1
    end
    return m or nil
end

-- ── Changes, kept for Restore ─────────────────────────────────────────────────────────────────

local function Put(t, k)
    local en = t[k]
    local uk = type(en) == "string" and O.Translate(en)
    if not uk then return end
    t[k] = uk
    edits[#edits + 1] = { t = t, k = k, en = en, uk = uk }
end

local function Walk(opt, seen)
    if type(opt) ~= "table" or seen[opt] then return end
    seen[opt] = true
    for _, f in ipairs(FIELDS) do Put(opt, f) end
    if type(opt.values) == "table" then
        for k in pairs(opt.values) do Put(opt.values, k) end
    end
    if type(opt.args) == "table" then
        for _, sub in pairs(opt.args) do Walk(sub, seen) end
    end
end

-- Each app's getter (AceConfigRegistry keeps one per app; RareScanner may give it a function that builds
-- the table) is wrapped once: with our words wanted, the table is got with RareScanner's English in its
-- locale table, and a table not yet changed is changed (and kept for Restore).
local function Wrap(reg, app)
    local get = reg.tables[app]
    if type(get) ~= "function" or mine[get] then return end
    local function wrapped(...)
        if not ns.WordsWanted() then return get(...) end
        local t = ns.WithEnglish(get, ...)
        if type(t) == "table" and not walked[t] then
            walked[t] = true
            local before = #edits
            Walk(t, {})
            if #edits > before then apps[app] = true end
        end
        return t
    end
    mine[wrapped] = true
    reg.tables[app] = wrapped
end

local function Tables()
    local reg = LibStub and LibStub("AceConfigRegistry-3.0", true)
    if not reg or type(reg.tables) ~= "table" then return end
    for app in pairs(reg.tables) do
        if type(app) == "string" and app:find(PREFIX) and not SKIP[app] then
            Wrap(reg, app)
            pcall(reg.GetOptionsTable, reg, app, "dialog", "UADD-1.0")
        end
    end
end

-- The settings page names: the category in the game's settings list and the page's title.
local cats = {}                                 -- { group, cat, en, uk }

local function Pages()
    local acd = LibStub and LibStub("AceConfigDialog-3.0", true)
    local list = acd and acd.BlizOptions
    if type(list) ~= "table" or not Settings or type(Settings.GetCategory) ~= "function" then return end
    for app, groups in pairs(list) do
        if type(app) == "string" and app:find(PREFIX) and type(groups) == "table" then
            for _, g in pairs(groups) do
                local id = type(g) == "table" and g.frame and g.frame.name
                local ok, cat = pcall(Settings.GetCategory, id)
                local en = ok and type(cat) == "table" and (cat.GetName and cat:GetName() or cat.name)
                local uk = type(en) == "string" and O.Translate(en)
                if uk then
                    if type(cat.SetName) == "function" then cat:SetName(uk) else cat.name = uk end
                    if type(g.SetTitle) == "function" then g:SetTitle(uk) end
                    cats[#cats + 1] = { g = g, cat = cat, en = en, uk = uk }
                end
            end
        end
    end
end

local function Popups()
    local lib = LibStub and LibStub("LibDialog-1.0RS", true)
    if not lib or type(lib.delegates) ~= "table" then return end
    for _, d in pairs(lib.delegates) do
        if type(d) == "table" then Put(d, "text") end
    end
end

-- The explorer's labels: "path from RSExplorerFrame, how it is set (text, tip, default), the keys it may
-- hold" (a template with its t words: "KEY+WORD+WORD"). RareScanner sets them once (OnLoad, Initialize),
-- so they are set here both ways, each time: only a label that holds either form now.
local E, C = "EXPLORER_", "EXPLORER_CUSTOM_ITEMS_"
local LABELS = {
    "Filters.FilterDropDown text FILTERS", "Filters.ContinentDropDown default NO_RESULTS",
    "Filters.LockCurrentZoneCheckButton.Text text LOCK_CURRENT_ZONE",
    "Filters.LockCurrentZoneCheckButton tip LOCK_CURRENT_ZONE_DESC", "Filters.RestartScanningButton text RESCANN",
    "Filters.RestartScanningButton tip RESCANN_DESC", "Filters.ToggleLootButton tip SHOW_LOOT HIDE_LOOT",
    "ScanRequired.ScanRequiredText text SCAN_MANUAL SCAN_REQUIRED NO_RESULTS",
    "ScanRequired.StartScanningButton text START_SCAN", "RareLoot.FilterAllCheck tip LOOT_FILTER_ALL_DESC",
    "RareLoot.FilterDropDown text FILTERS", "Control.ApplyFiltersButton text FILTERING",
    "Control.ApplyFiltersButton tip FILTERING_DESC+FILTERS+FILTER_COLLECTIONS",
    "Control.CreateProfilesBackupCheckButton.Text text CREATE_BACKUP",
    "Control.CreateProfilesBackupCheckButton tip CREATE_BACKUP_DESC+FILTERING",
    "Control.AutoFilterCheckButton.Text text AUTO_FILTER", "Control.AutoFilterCheckButton tip AUTO_FILTER_DESC",
    "CustomLoot.ControlFrame.LootGroupLabel text ~GROUP", "CustomLoot.ControlFrame.LootNewGroupLabel text ~ADD_GROUP",
    "CustomLoot.ControlFrame.LootGroupDropDown tip ~GROUP_DESC", "CustomLoot.ControlFrame.NewGroup tip ~ADD_GROUP_DESC",
    "CustomLoot.ControlFrame.ItemListLabel text ~LIST", "CustomLoot.ControlFrame.ItemList tip ~LIST_DESC",
    "CustomLoot.GroupInfo.DeleteGroup text ~DELETE_GROUP", "CustomLoot.GroupInfo.EditGroupName tip ~EDIT_GROUP",
    "CustomLoot.GroupInfo.NoItems text ~GROUP_EMPTY", "RareInfo.Mounts.Texture tip MOUNTS",
    "RareInfo.Pets.Texture tip PETS", "RareInfo.Toys.Texture tip TOYS", "RareInfo.Appearances.Texture tip APPEARANCES",
    "RareInfo.Custom.Texture tip CUSTOM",
}
local labels = 0                                -- how many hold ours now

-- RareScanner's English and ours (nil when it is not ours) for "KEY" or "KEY+WORD+WORD".
local function Forms(spec)
    local L, en, uk, ea, ua = ns.Locale(), nil, nil, {}, {}
    for short in spec:gmatch("[^+]+") do
        local key = short:find("^~") and C .. short:sub(2) or E .. short
        local e = ns.English(key) or (L and rawget(L, key))
        local u = ns.Usable(key, e)
        if not en then en, uk = e, u else ea[#ea + 1], ua[#ua + 1] = e, u or false end
    end
    for _, u in ipairs(ua) do if not u then uk = nil end end
    local ok, e = pcall(string.format, en, unpack(ea))
    local fine, u = pcall(string.format, uk or "", unpack(ua))
    return ok and e or nil, uk and fine and u or nil
end

local function Labels(on)
    local root = rawget(_G, "RSExplorerFrame")
    labels = 0
    if type(root) ~= "table" then return end
    for _, row in ipairs(LABELS) do
        local path, how, keys = row:match("^(%S+) (%S+) (.+)$")
        local o = root
        for part in path:gmatch("[^.]+") do o = type(o) == "table" and o[part] or nil end
        local now
        if type(o) ~= "table" then now = nil
        elseif how == "tip" then now = o.tooltip
        elseif how == "default" then now = o.defaultText
        elseif type(o.GetText) == "function" then now = o:GetText() end
        for spec in keys:gmatch("%S+") do
            local en, uk = Forms(spec)
            if now and en and uk and (now == en or now == uk) then
                local s = on and uk or en
                if how == "tip" then o.tooltip = s
                elseif how == "default" then if o.SetDefaultText then o:SetDefaultText(s) end
                elseif o.SetText then o:SetText(s) end
                if on then labels = labels + 1 end
                break
            end
        end
    end
end

local function Notify()
    local reg = LibStub and LibStub("AceConfigRegistry-3.0", true)
    for app in pairs(apps) do if reg then pcall(reg.NotifyChange, reg, app) end end
end

-- Ours on every word read at load that is English now (again after the hold key: nothing twice).
function O.Apply()
    if not ns.WordsWanted() then return end
    wipe(memo) memoSize = 0
    Tables()
    Pages()
    Popups()
    Labels(true)
    Notify()
end

-- RareScanner's English back, where ours still is.
function O.Restore()
    for i = #edits, 1, -1 do
        local e = edits[i]
        if e.t[e.k] == e.uk then e.t[e.k] = e.en end
        edits[i] = nil
    end
    for i = #cats, 1, -1 do
        local c = cats[i]
        local now = c.cat.GetName and c.cat:GetName() or c.cat.name
        if now == c.uk then
            if type(c.cat.SetName) == "function" then c.cat:SetName(c.en) else c.cat.name = c.en end
            if type(c.g.SetTitle) == "function" then c.g:SetTitle(c.en) end
        end
        cats[i] = nil
    end
    Labels(false)
    wipe(walked)
    wipe(memo) memoSize = 0
    Notify()
    wipe(apps)
end

function O.Count() return #edits + #cats + labels end
