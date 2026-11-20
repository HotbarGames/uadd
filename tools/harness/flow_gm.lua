-- Lua helpers for flow_gm.py, on the GatherMate2 stand-in (tools/harness/gathermate2). Reached from Python
-- as HARNESS.gm. Run before the game starts.
--
-- The flow names the locale keys the stand-in uses (M.word) and gives test Ukrainian for each row the
-- module's data lacks (M.put), right after the module's files ran. No English here.
local H = HARNESS
local M = {}
H.gm = M

local PIN, AUTO = "L.adde7058", "L.d7c16fbf"
local function NS() return H.ns.UADD_GatherMate2 end
local function S() return rawget(_G, "GatherMate2StandIn") end

GatherMate2StandInKeys = { other = {}, prof = {}, pages = {} }
function M.word(slot, a, b)
    local K = GatherMate2StandInKeys
    if slot == "page" then K.pages[#K.pages + 1] = { a, b }
    elseif type(K[slot]) == "table" then K[slot][#K[slot] + 1] = a
    else K[slot] = a end
end

M.data, M.used = {}, {}
function M.put(row, uk) M.data[row] = uk end

local watch = CreateFrame("Frame")
watch:RegisterEvent("ADDON_LOADED")
watch:SetScript("OnEvent", function(_, _, name)
    if name ~= "UADD_GatherMate2" then return end
    local ns = NS()
    for row, uk in pairs(M.data) do
        if ns.AL[row] == nil then
            ns.AL[row] = uk
            M.used[row] = true
        end
    end
end)

-- The game's menu calls the harness lacks: the menu's lines are recorded, in order.
M.menu = {}
if not rawget(_G, "UIDropDownMenu_AddButton") then
    function UIDropDownMenu_AddButton(info) M.menu[#M.menu + 1] = info.text end
end
if not rawget(_G, "ToggleDropDownMenu") then
    function ToggleDropDownMenu(level, _, frame)
        M.menu = {}
        frame.initialize(frame, level or 1)
    end
end

-- Data addons that load (made-up names); any other name goes to the harness as before.
M.loadable = { Quix = true }
local load = C_AddOns.LoadAddOn
C_AddOns.LoadAddOn = function(name, ...)
    if M.loadable[name] then return true, nil end
    return load(name, ...)
end

-- ── Reading the game ──────────────────────────────────────────────────────────────────────────

local FIELDS = { "name", "desc", "confirmText" }
local function Opt(t, path, out, handler, seen)
    if type(t) ~= "table" or seen[t] then return end
    seen[t] = true
    handler = rawget(t, "handler") or handler
    for _, f in ipairs(FIELDS) do
        local v = rawget(t, f)
        if type(v) == "function" then
            local ok, r = pcall(v, { handler = handler })
            v = ok and r or nil
        end
        if type(v) == "string" then out[path .. "." .. f] = v end
    end
    if type(rawget(t, "values")) == "table" then
        for k, v in pairs(t.values) do out[path .. ".values." .. tostring(k)] = v end
    end
    if type(rawget(t, "args")) == "table" then
        for k, a in pairs(t.args) do Opt(a, path .. "." .. tostring(k), out, handler, {}) end
    end
end

-- Every word the module may change, and the ones it must never change, as a flat map:
-- L its locale table, N and V its node tables, O its settings tables (P its Profiles tab, Q another addon's),
-- C its page names, B the key binding names, K the profession names it kept at load.
function M.snap()
    local out, s = {}, S()
    for _, p in ipairs({ { "L:", "GatherMate2" }, { "N:", "GatherMate2Nodes" }, { "V:", "GatherMate2NodesVanilla" } }) do
        for k, v in pairs(LibStub("AceLocale-3.0").apps[p[2]] or {}) do
            if type(v) == "string" then out[p[1] .. k] = v end
        end
    end
    Opt(s.root, "O:root", out, nil, {})
    Opt(s.mini, "O:mini", out, nil, {})
    Opt(s.profiles, "P:", out, nil, {})
    Opt(s.otherProfiles, "Q:", out, nil, {})
    for app, c in pairs(s.cats) do
        out["C:" .. app] = c.cat.GetName and c.cat:GetName() or c.cat.name
        out["C:" .. app .. ":title"] = c.group.title
    end
    out["B:mini"] = BINDING_NAME_TOGGLE_GATHERMATE2_MINIMAPICONS
    out["B:main"] = BINDING_NAME_TOGGLE_GATHERMATE2_MAINMAPICONS
    for i, v in ipairs(s.skills) do out["K:" .. i] = v end
    return out
end

-- The pin menu opened on one pin titled `title`: its lines in order.
function M.pinMenu(title)
    S().PinMenu({ title })
    local out = {}
    for i, v in ipairs(M.menu) do out[i] = v end
    return out
end

-- What one chat call printed (nil: nothing).
local function Printed(fn, ...)
    local out, p = nil, print
    print = function(...) out = table.concat({ ... }, " ") end
    local ok, err = pcall(fn, ...)
    print = p
    if not ok then error(err) end
    return out
end
function M.autoImport(name) return Printed(S().AutoImport, { name }) end
function M.loadFail(name) return Printed(S().LoadData, name) end

-- The line GatherMate2 builds from row's words with `value` glued after, for the half-line check.
function M.line(row, value)
    if row == PIN then return M.pinMenu(value)[2] end
    if row == AUTO then return M.autoImport(value) end
end

function M.want(row) return NS().AL[row] end
function M.count() return NS().Swap.Count() end
function M.optCount() return NS().Options.Count() end

function M.key(down)
    H.keys.SHIFT = down
    H.fire("MODIFIER_STATE_CHANGED", "LSHIFT", down and 1 or 0)
    M.wait(0.4)                         -- UADD/Original.lua switches once the key is held a while
end
function M.wait(seconds) for _ = 1, math.ceil(seconds / 0.05 - 1e-6) do H.step(0.05) end end
function M.uadd(msg) return H.call("/uadd " .. msg, SlashCmdList.UADD, msg) end
