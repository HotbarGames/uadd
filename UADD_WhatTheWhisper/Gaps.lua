-- Texts it draws that Swap.lua cannot reach through its English table, drawn where they show:
--   * Labels its code draws through L though its enUS table lacks the key (its L then gives the key itself):
--     the profile panel's rows (ProfilePanel.New, each panel's Refresh) and the settings captions (each fresh
--     Options.BuildSchema). Ours is keyed "X." .. UADD.Hash(English); a key its enUS table has is never touched.
--   * The History page's size line: a template whose slot its Format.Bytes fills with its own English units, so
--     Swap.lua leaves it English (sort u, lesson 15). Here the line is ours only when the size is in a unit we say
--     (B, KB, MB); any other text keeps the whole line English (no half lines). Format.Bytes itself is never
--     changed: its "/wtw" diagnostics line uses it too.
-- Ours only while ours is in its table (Swap.On: on, not held, English in force, not saving). Off, held or another
-- language: its own redraw (Relocalize, each Refresh; a hidden panel's Refresh runs when it shows) writes what its
-- L gives now (lesson 23), and ours is not put back on it.
-- Hooks run under a plain pcall (lesson 19): errors are reported and counted, and the English still comes back
-- after an off for errors. No English of it is stored here.

local _, ns = ...
local U = UADD
local G = {}
ns.Gaps = G

local SIZE = "L.17d2f1f2"
local UNITS = { { "^(%d+) B$", "%s Б" }, { "^(%d+%.%d) KB$", "%s КБ" }, { "^(%d+%.%d) MB$", "%s МБ" } }
local FIELDS = { "label", "caption", "title" }

local shown = setmetatable({}, { __mode = "k" })     -- a row label of ours -> { its English, ours }
local panels = setmetatable({}, { __mode = "k" })    -- each profile panel seen (true: its Refresh is hooked)
local news, schemas                                  -- { orig, fn } while ours wraps them

local function Want()
    local W = ns.Swap
    return W.On() and not W.Saving() and W.Active() == "enUS"
end

local function Guarded(fn)
    return function(...)
        local ok, err = pcall(fn, ...)
        if ok then return end
        err = tostring(err)
        pcall(U.ReportError, err)
        if type(U.Fault) == "function" then pcall(U.Fault, "wtw", err) end
    end
end

-- Ours for a text it draws by a key its enUS table lacks, or nil.
local function Gap(en)
    if type(en) ~= "string" or en == "" then return nil end
    local base = ns.Swap.Base()
    if not base or rawget(base, en) ~= nil then return nil end
    local ua = ns.AL["X." .. U.Hash(en)]
    return type(ua) == "string" and ua ~= "" and ua or nil
end

-- ── The profile panel ─────────────────────────────────────────────────────────────────────────

local function Rows(panel)
    local rows = type(panel) == "table" and panel.rows
    if type(rows) ~= "table" then return end
    local want = Want()
    for _, row in ipairs(rows) do
        local fs = type(row) == "table" and row.label
        if type(fs) == "table" and type(fs.GetText) == "function" then
            local text, was = fs:GetText(), shown[fs]
            if was and text ~= was[2] then shown[fs], was = nil, nil end      -- it wrote its own text since
            if want and not was then
                local ua = Gap(text)
                if ua then
                    fs:SetText(ua)
                    shown[fs] = { text, ua }
                end
            end
        end
    end
end
local SafeRows = Guarded(Rows)

local function Panel(p)
    if type(p) ~= "table" or panels[p] or type(p.Refresh) ~= "function" then return end
    panels[p] = true
    hooksecurefunc(p, "Refresh", SafeRows)
    SafeRows(p)
end
local SafePanel = Guarded(Panel)

-- ── The settings schema ───────────────────────────────────────────────────────────────────────

-- The size line in ours, or nil: `tpl` is its English template, `en` the line it made from it.
local function SizeLine(tpl, en)
    local ua = ns.AL[SIZE]
    local at = tpl:find("%s", 1, true)
    if type(ua) ~= "string" or not at or tpl:find("%", at + 2, true) or not ua:find("%s", 1, true) then return nil end
    local pre, post = tpl:sub(1, at - 1), tpl:sub(at + 2)
    if #en < #pre + #post or en:sub(1, #pre) ~= pre or en:sub(#en - #post + 1) ~= post then return nil end
    local slot = en:sub(#pre + 1, #en - #post)
    for _, u in ipairs(UNITS) do
        local n = slot:match(u[1])
        if n then return (ua:gsub("%%s", function() return u[2]:format(n) end, 1)) end
    end
    return nil
end

local function SizeRow(spec)
    local tpl, orig = spec.label, spec.value
    spec.value = function(...)
        local en = orig(...)
        if type(en) ~= "string" or not Want() then return en end
        local ok, ua = pcall(SizeLine, tpl, en)
        if not ok then
            Guarded(error)(ua, 0)
            return en
        end
        return ua or en
    end
end

local function Spec(spec, want)
    if type(spec) ~= "table" then return end
    if spec.type == "info" and type(spec.label) == "string" and type(spec.value) == "function"
        and "L." .. U.Hash(spec.label) == SIZE then
        SizeRow(spec)
    end
    if not want then return end
    for _, f in ipairs(FIELDS) do
        local ua = Gap(spec[f])
        if ua then spec[f] = ua end
    end
end

-- Its schema is made fresh on each open and each language change: categories, their cards, the cards' rows.
local function Walk(schema)
    if type(schema) ~= "table" then return end
    local want = Want()
    for _, cat in ipairs(schema) do
        Spec(cat, want)
        for _, card in ipairs(type(cat) == "table" and type(cat.cards) == "table" and cat.cards or {}) do
            Spec(card, want)
            for _, row in ipairs(type(card) == "table" and type(card.rows) == "table" and card.rows or {}) do
                Spec(row, want)
            end
        end
    end
end
local SafeWalk = Guarded(Walk)

-- ── In and out ────────────────────────────────────────────────────────────────────────────────

function G.Install()
    local a = ns.Swap.Addon()
    if not a then return end
    local P = a.ProfilePanel
    if not news and type(P) == "table" and type(P.New) == "function" then
        local orig = P.New
        local function Out(p, ...)
            SafePanel(p)
            return p, ...
        end
        news = { orig = orig, fn = function(...) return Out(orig(...)) end }
        P.New = news.fn
    end
    local O = a.Options
    if not schemas and type(O) == "table" and type(O.BuildSchema) == "function" then
        local orig = O.BuildSchema
        local function Out(s, ...)
            SafeWalk(s)
            return s, ...
        end
        schemas = { orig = orig, fn = function(...) return Out(orig(...)) end }
        O.BuildSchema = schemas.fn
    end
    -- Panels it made before us: the main window's, and each popout's.
    local MW = a.MainWindow
    local ok, win = U.SafeCall(type(MW) == "table" and MW.Existing)
    local view = ok and type(win) == "table" and win.view
    if type(view) == "table" then SafePanel(view.profile) end
    local PO = a.Popout
    if type(PO) == "table" and type(PO.Each) == "function" then
        U.SafeCall(PO.Each, function(_, w)
            if type(w) == "table" and type(w.view) == "table" then SafePanel(w.view.profile) end
        end)
    end
end

-- Off: its own functions back, unless someone wrapped them after us (ours then only passes through).
function G.Remove()
    local a = ns.Swap.Addon()
    local P, O = a and a.ProfilePanel, a and a.Options
    if news and type(P) == "table" and P.New == news.fn then
        P.New = news.orig
        news = nil
    end
    if schemas and type(O) == "table" and O.BuildSchema == schemas.fn then
        O.BuildSchema = schemas.orig
        schemas = nil
    end
end

-- Labels of ours shown now.
function G.Count()
    local n = 0
    for _ in pairs(shown) do n = n + 1 end
    return n
end
