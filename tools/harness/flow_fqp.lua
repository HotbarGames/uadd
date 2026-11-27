-- Lua helpers for flow_fqp.py, on the real Forever Quest Pins (GPL-3.0: its English may be used here). Reached
-- from Python as HARNESS.fqp. Run before the game starts: it turns on the harness Menu API (HARNESS.menuApi).
local H = HARNESS
local M = {}
H.fqp = M
H.menuApi()

local MOD = "UADD_ForeverQuestPins"
local CAT = "Forever Quest Pins"
local CYR = "[\208-\211]"
local function NS() return H.ns[MOD] end
M.subs = {}                                      -- its pages under the main one (flow_fqp_pages.lua)

-- The proof that a step has teeth: with M.cut set, one file runs without one fix (this run's copy, in memory
-- only; the module's file is never changed). Each: { file, plain text found, its replacement }.
local CUTS = {
    usable = { "Locale.lua", '    if type(en) ~= "string" or type(uk) ~= "string" or en == "" or uk == "" then return false end\n',
               '    do return type(uk) == "string" end\n' },
    menu = { "Menu.lua", '    b:HookScript("OnClick", Lc.Guard(OnClick))\n', "" },
    roots = { "Screen.lua", ', "ForeverQuestPinsMapFilterList" }', " }" },
    hold = { "Module.lua", "        U.SafeCall(ns.Locale.Sync)\n        U.SafeCall(ns.Screen.Apply)\n    end, ",
             "        U.SafeCall(ns.Locale.Sync)\n    end, " },
    names = { "Breadcrumb.lua", "        if not (u2 and uz) then return nil end\n", "        u2, uz = u2 or t2, uz or z\n" },
    lines = { "Screen.lua", 'if t:find("\\n", 1, true) and #t <= 400 then', "if false then" },
    tail = { "Breadcrumb.lua", "        if text:sub(nl + 1) ~= HINT then return nil end\n", "" },
    restore = { "Screen.lua", "function S.Restore() Run(false) end", "function S.Restore() end" },
    fault = { "Menu.lua", "Lc.Guard(OnClick)", "function() pcall(OnClick) end" },
    range = { "Screen.lua", 'local TAILS = { " %(%d+%-%d+%)", " %(BETA%)" }', 'local TAILS = { " %(BETA%)" }' },
    beta = { "Screen.lua", 'local TAILS = { " %(%d+%-%d+%)", " %(BETA%)" }', 'local TAILS = { " %(%d+%-%d+%)" }' },
    join = { "Screen.lua", "local JOINS = 8 ", "local JOINS = 0 " },
    tiphook = { "Screen.lua", '    f:HookScript("OnEnter", TipHook)\n', '    f:HookScript("OnEnter", U.Safe("foreverquestpins", OnTip))\n' },
    guard = { "Breadcrumb.lua", "Lc.Guard(OnBody)", "U.Safe(KEY, OnBody)" },
    guardlist = { "Menu.lua", "Lc.Guard(OnClick)", 'UADD.Safe("foreverquestpins", OnClick)' },
    filter = { "Screen.lua", "    U.SafeCall(ns.Tracker.Switch, want)\n", "" },
    pages = { "Pages.lua", "    Subs(main)\n", "" },
    rename = { "Screen.lua", "    for _, cat in ipairs(subs) do U.SafeCall(Rename, cat, want) end\n", "" },
    labels = { "Locale.lua", "                    t[k] = uk\n", "" },
    plain = { "Breadcrumb.lua",
              '    if type(t) ~= "string" or type(word) ~= "string" or word == QUEST then return t end\n',
              "    do return t end\n" },
}
M.cut, M.wasCut, M.bad = nil, false, nil
local runFile = H.runFile
function H.runFile(addon, path, code)
    local c = M.cut and CUTS[M.cut]
    if addon == MOD and c and path == c[1] then
        local a, b = code:find(c[2], 1, true)
        if a then code, M.wasCut = code:sub(1, a - 1) .. c[3] .. code:sub(b + 1), true end
    end
    local r = runFile(addon, path, code)
    if addon == MOD and path == "data/uk_other.lua" and M.bad then M.spoil() end
    return r
end

-- Bad data (step 1): one word with a % spec the English lacks, one with an escape the English lacks.
M.spoiled = {}
function M.spoil()
    local UK, keys = NS().UK or {}, {}
    for en in pairs(UK) do keys[#keys + 1] = en end
    table.sort(keys)
    local spec, esc
    for _, en in ipairs(keys) do
        if not en:find("[%%|\n]") and #en > 6 then
            if not spec then spec = en elseif not esc then esc = en end
        end
    end
    UK[spec] = UK[spec] .. " %s"
    UK[esc] = "|cffff0000" .. UK[esc] .. "|r"
    M.spoiled = { spec, esc }
end
function M.badKeys() return M.spoiled[1], M.spoiled[2] end

function M.L(en)
    local fqp = rawget(_G, "ForeverQuestPins")
    return fqp and type(fqp.L) == "table" and rawget(fqp.L, en) or nil
end
function M.uk(en) return NS().UK[en] end
function M.word(en) return NS().Locale.Word(en) end
function M.written() return NS().Locale.Written() end
function M.on() return NS().On() == true end

-- Every key we wrote into L that still holds our word (off: none should).
function M.left()
    local n = 0
    for en in pairs(NS().UK) do
        local v = M.L(en)
        if v and v ~= en and v:find(CYR) then n = n + 1 end
    end
    return n
end

-- Its World Map filter list and button: flow_fqp_pages.lua.

local function Collect(f, out, depth)
    if type(f) ~= "table" or depth > 6 then return out end
    for _, r in ipairs(UADD.Regions(f)) do
        if r.GetObjectType and r:GetObjectType() == "FontString" then
            local t = r:GetText()
            if t and t ~= "" then out[#out + 1] = t end
        end
    end
    for _, c in ipairs(UADD.Children(f)) do Collect(c, out, depth + 1) end
    return out
end

local function Root(which)
    if which == "canvas" then
        local cat = Settings.GetCategory(CAT)
        return cat and cat.frame
    end
    return rawget(_G, which == "setup" and "ForeverQuestPinsSetup" or "ForeverQuestPinsBreadcrumb")
end
-- "canvas": its main page and every page under it.
local function Roots(which)
    local out = { Root(which) }
    if which == "canvas" then for _, c in ipairs(M.subs) do out[#out + 1] = c.frame end end
    return out
end
local function CollectAll(which)
    local out = {}
    for _, f in ipairs(Roots(which)) do Collect(f, out, 0) end
    return out
end
function M.there(which) local f = Root(which) return f ~= nil and (which ~= "canvas" or f.built == true) end

-- The canvas text with the player's level range glued on (" (50-61)"), or nil.
function M.label()
    for _, t in ipairs(CollectAll("canvas")) do
        if t:find(" %(%d+%-%d+%)$") then return t end
    end
    return nil
end

-- Its What's New chat head (Chat.lua builds it whole around a version), as Locale.lua lists it.
function M.head()
    for en in pairs(NS().Locale.CHAT or {}) do return en end
    return nil
end

-- How many Lc.NAMES keys (lines built whole, Breadcrumb.lua and Chat.lua) hold anything in L (none should).
function M.namesWritten()
    local n = 0
    for en in pairs(NS().Locale.NAMES) do if M.L(en) ~= nil then n = n + 1 end end
    return n
end

-- (how many texts, how many Cyrillic, the texts we have a word for that still show English, the Cyrillic ones;
-- both "|"-joined).
function M.scan(which)
    local all, cyr, miss = CollectAll(which), {}, {}
    for _, t in ipairs(all) do
        if t:find(CYR) then cyr[#cyr + 1] = t
        elseif NS().Locale.Uk(UADD.Plain(t) or t) then miss[#miss + 1] = t end
    end
    return #all, #cyr, table.concat(miss, " | "), table.concat(cyr, " | ")
end

-- GameTooltip's lines get their text (AddLine only counts lines in the harness), as in flow_auc.lua.
local tip = GameTooltip
local function Clear(self)
    for i = 1, 8 do _G["GameTooltipTextLeft" .. i]:SetText(nil) end
    self.__lines = 0
end
local function Add(self, l)
    self.__lines = (self.__lines or 0) + 1
    local fs = rawget(_G, "GameTooltipTextLeft" .. self.__lines)
    if fs then fs:SetText(l) end
end
tip.ClearLines = Clear
tip.SetOwner = function(self, owner) self.__owner = owner Clear(self) end
tip.SetText = function(self, t) Clear(self) Add(self, t) end
tip.AddLine = function(self, t) Add(self, t) end

-- The settings window opened on its main page, then each page under it (each builds on its first show).
function M.openCanvas()
    SettingsPanel:Show()
    SettingsPanel:SelectCategory(Settings.GetCategory(CAT))
    for _, c in ipairs(M.subs) do SettingsPanel:SelectCategory(c) end
    SettingsPanel:SelectCategory(Settings.GetCategory(CAT))
end

-- Its settings checkboxes' tooltips: (how many shown, how many with Cyrillic in their lines).
function M.tips()
    local shown, cyr = 0, 0
    local function Visit(f, depth)
        if type(f) ~= "table" or depth > 6 then return end
        local enter = f.GetScript and f:GetScript("OnEnter")
        if enter and GameTooltip then
            GameTooltip:Hide()
            enter(f)
            local n = GameTooltip:NumLines() or 0
            if n > 0 then
                shown = shown + 1
                for i = 1, n do
                    local fs = rawget(_G, "GameTooltipTextLeft" .. i)
                    local t = fs and fs:GetText()
                    if t and t:find(CYR) then cyr = cyr + 1 break end
                end
            end
            GameTooltip:Hide()
        end
        for _, c in ipairs(UADD.Children(f)) do Visit(c, depth + 1) end
    end
    for _, f in ipairs(Roots("canvas")) do Visit(f, 0) end
    return shown, cyr
end

-- What's New: (lines, lines that are ours, lines we have a word for that are English).
function M.news()
    local fqp = rawget(_G, "ForeverQuestPins")
    local lines = fqp and fqp.WhatsNew and fqp.WhatsNew.lines or {}
    local ours, miss = 0, 0
    for _, line in ipairs(lines) do
        if line:find(CYR) then ours = ours + 1 elseif NS().Locale.Word(line) then miss = miss + 1 end
    end
    return #lines, ours, miss
end
-- Its What's New lines as they are now, "\n"-joined.
function M.newsLines()
    local fqp = rawget(_G, "ForeverQuestPins")
    return table.concat(fqp and fqp.WhatsNew and fqp.WhatsNew.lines or {}, "\n")
end

-- Our data's word for one key, swapped for a while (nil: as if we had none); gives back the old one.
function M.setUk(en, uk)
    local old = NS().UK[en]
    NS().UK[en] = uk
    return old
end

function M.hold(on)
    M.held = on
    UADD.KeyHeld = function() return M.held end
    UADD.CheckOriginal()
end
function M.shown() return UADD.originalShown == true end

-- The breadcrumb dialog: made by its own /fqp breadcrumbtest; its body set as Forever Quest Pins sets it.
function M.crumbtest() SlashCmdList.FOREVERQUESTPINS("breadcrumbtest") end
function M.body()
    local p = rawget(_G, "ForeverQuestPinsBreadcrumb")
    return p and p.body and p.body:GetText()
end
function M.setBody(t) ForeverQuestPinsBreadcrumb.body:SetText(t) end

-- Game names through UADD.UALL (lesson 20): titles and zones this table knows, nothing else.
M.names = {}
function M.known(on)
    UADD.UALL.Quest = on and function(_, t) return M.names[t] end or function() return nil end
    UADD.UALL.Zone = on and function(z) return M.names[z] end or function() return nil end
end
function M.know(en, uk) M.names[en] = uk end
-- The wrong place: UADD's root has no routes; a stub there must change nothing.
function M.rootOnly()
    M.known(false)
    UADD.Quest = function(_, t) return M.names[t] end
    UADD.Zone = function(z) return M.names[z] end
end

-- A chat line as Forever Quest Pins prints it; the last line in chat.
function M.say(msg) DEFAULT_CHAT_FRAME:AddMessage(msg) end

-- The halves check's path for one template (flow_fqp.py builds the texts as the addon does): the breadcrumb
-- sentence through Breadcrumb.Make, the two chat lines through ChatWords, any other key as Forever Quest Pins
-- would print it: L's word for it (if one were written) with the slots filled.
function M.half(id, t)
    local ns = NS()
    if id == "crumb" then return ns.Breadcrumb.Make(t) or t end
    if id == "chat" then
        local out = ns.ChatWords.Translate(t:sub(5))
        return out and ("|cff" .. out) or t
    end
    local word = M.L(id)
    if type(word) ~= "string" or word == id then return t end
    local vals = { t:match(ns.Locale.Shape(id)) }
    return vals[1] and ns.Locale.Put(word, unpack(vals)) or t
end

function M.wait(seconds) for _ = 1, math.ceil(seconds / 0.05 - 1e-6) do H.step(0.05) end end
function M.uadd(msg) return H.call("/uadd " .. msg, SlashCmdList.UADD, msg) end
