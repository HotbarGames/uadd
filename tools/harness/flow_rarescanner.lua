-- Lua helpers for flow_rarescanner.py, on the RareScanner stand-in (tools/harness/rarescanner). Reached
-- from Python as HARNESS.rs. Run before the game starts.
--
-- Stand-in data: until tools/make_rs_text.py has written UADD_RareScanner/data, a few made-up lines are
-- given to the module (ns.AL, ns.SORT) right after its files ran, only for keys its data lacks. They
-- cover each case: plain words, templates whose slots hold its own words (t) or a value (v), one with a
-- game name (n: must stay English) and CHAT_NOTIFICATION_RARE (sent to other players: must stay English).
local H = HARNESS
local M = {}
H.rs = M

local function NS() return H.ns.UADD_RareScanner end
local function S() return rawget(_G, "RareScannerStandIn") end
local function L() return LibStub("AceLocale-3.0").apps.RareScanner end

M.data = {
    SOUND = { "Звук" },
    DISPLAY = { "Показувати" },
    EXPLORER_FILTERS = { "Фільтри" },
    EXPLORER_FILTER_COLLECTIONS = { "Колекції" },
    EXPLORER_FILTER_MOUNTS = { "Бракує їздових тварин" },
    EXPLORER_FILTER_TOYS = { "Бракує іграшок" },
    EXPLORER_MOUNTS = { "Їздові тварини" },
    EXPLORER_SCAN_NOT_DONE = { "Пошук ще не зроблено." },
    EXPLORER_FILTERING_DESC = { "Фільтрує все за «%s - %s».", "tt" },
    EXPLORER_FILTERING_DIALOG = { "Буде відфільтровано все за «%s - %s» (наприклад, лише '%s' без '%s').", "tttt" },
    EXPLORER_CUSTOM_ITEMS_TOOLTIP_ID = { "ID предмета: %s", "v" },
    ALARM_MESSAGE = { "Знайдено: %s!", "n" },
    CHAT_NOTIFICATION_RARE = { "Рідкісний [%s] у %s", "nn" },
    CUSTOM_NPC_GROUP_DEFAULT = { "Типова група" },
    EXPLORER_CUSTOM_ITEMS_GROUP_DEFAULT = { "Типова група" },
}
M.stay = { "CHAT_NOTIFICATION_RARE", "CUSTOM_NPC_GROUP_DEFAULT", "EXPLORER_CUSTOM_ITEMS_GROUP_DEFAULT", "CONTAINER" }
function M.stayed()                            -- STAY keys that hold anything but RareScanner's English
    local bad, ns = {}, NS()
    for _, key in ipairs(M.stay) do
        if ns.English(key) ~= nil or L()[key] ~= rawget(L(), key) then bad[#bad + 1] = key end
    end
    return bad
end
M.used = {}                                    -- keys that took the stand-in's line

local watch = CreateFrame("Frame")
watch:RegisterEvent("ADDON_LOADED")
watch:SetScript("OnEvent", function(_, _, name)
    if name ~= "UADD_RareScanner" then return end
    local ns = NS()
    for key, row in pairs(M.data) do
        if ns.AL[key] == nil then
            ns.AL[key], ns.SORT[key] = row[1], row[2]
            M.used[key] = true
        end
    end
end)

function M.want(key) return NS().AL[key] end
function M.L(key) return L()[key] end
function M.english(key) return NS().English(key) or L()[key] end
function M.tr(s) return NS().Options.Translate(s) end
function M.swapped() return NS().Swapped() end
function M.templates()
    local out, ns = {}, NS()
    for key in pairs(ns.Templates) do out[key] = { ns.English(key), ns.SORT[key] or "" } end
    return out
end

-- What RareScanner read at load, now.
function M.baked()
    local s, lib = S(), LibStub("LibDialog-1.0RS")
    return {
        page = s.options.name, row = s.options.args.show.name, desc = s.options.args.show.desc,
        value = s.options.args.pick.values.a, other = s.options.args.pick.values.b,
        category = s.category:GetName(), title = s.group.title,
        dialog = lib.delegates.RS_FILTERING.text, scan = lib.delegates.RS_SCAN.text,
        tip = RSExplorerFrame.RareInfo.Mounts.Texture.tooltip,
    }
end

-- The page built by a function: its name and a row's name, as AceConfigDialog gets them.
function M.npcs()
    local t = LibStub("AceConfigRegistry-3.0"):GetOptionsTable("RareScanner Custom NPCs", "dialog", "AceConfigDialog-3.0")
    return { page = t.name, row = t.args.filter.name }
end
function M.rebuild() S().refresh = true end     -- as after an import
-- The explorer's labels set once when it opens, and RareScanner's own compare with one of them.
function M.explorer()
    S().OpenExplorer()
    local ex = RSExplorerFrame
    return { rescan = ex.Filters.RestartScanningButton:GetText(), tip = ex.Control.ApplyFiltersButton.tooltip,
        scan = ex.ScanRequired.ScanRequiredText:GetText(), manual = S().ManualScan() }
end
-- Our line for `key` changed (nil: none), the module started again; returns the old one.
function M.set(key, uk)
    local ns = NS()
    local old = ns.AL[key]
    ns.AL[key] = uk
    ns.End()
    ns.Begin()
    return old
end

function M.show(key, ...) return S().Show(key, ...) end
function M.line(key, ...) return S().Line(key, ...) end
function M.titleCyr() return UADD.IsCyrFont((S().button.Title:GetFont())) and true or false end
function M.spawn(name)
    local f = LibStub("LibDialog-1.0RS"):Spawn(name)
    return f.text:GetText(), UADD.IsCyrFont((f.text:GetFont())) and true or false
end
function M.fonts() return NS().Fonts.Count() end

function M.key(down)
    H.keys.SHIFT = down
    H.fire("MODIFIER_STATE_CHANGED", "LSHIFT", down and 1 or 0)
    M.wait(0.4)                         -- UADD/Original.lua switches once the key is held a while
end
function M.wait(seconds) for _ = 1, math.ceil(seconds / 0.05 - 1e-6) do H.step(0.05) end end
function M.uadd(msg) return H.call("/uadd " .. msg, SlashCmdList.UADD, msg) end

-- Load time: the module's own start (data, swap, settings, pop-ups), in ms.
function M.time(n)
    local ns, t0 = NS(), debugprofilestop()
    for _ = 1, n do ns.End() ns.Begin() end
    return (debugprofilestop() - t0) / n
end
