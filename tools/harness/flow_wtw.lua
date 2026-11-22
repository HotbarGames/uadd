-- Lua helpers for flow_wtw.py, on the WhatTheWhisper stand-in (tools/harness/whatthewhisper), which runs the
-- installed addon's own locale, date, sound and export files. Reached from Python as HARNESS.wtw.
local H = HARNESS
local M = {}
H.wtw = M

local MOD = "UADD_WhatTheWhisper"
local function S() return rawget(_G, "WhatTheWhisperStandIn") end
local function NS() return rawget(_G, "WhatTheWhisper") end
local DAY = 86400

-- The proof that a step has teeth: with M.cut set, one module file runs without one fix (in memory only).
-- flow_wtw.py adds the cuts (M.addCut) before the game starts.
local CUTS = {}
M.cut, M.wasCut = nil, false
function M.addCut(name, file, old, new) CUTS[name] = { file, old, new } end
local runFile = H.runFile
function H.runFile(addon, path, code)
    local c = M.cut and CUTS[M.cut]
    if addon == MOD and c and path == c[1] then
        local a, b = code:find(c[2], 1, true)
        if a then code, M.wasCut = code:sub(1, a - 1) .. c[3] .. code:sub(b + 1), true end
    end
    return runFile(addon, path, code)
end

function M.feed(code) assert(loadstring(code))() end
function M.wait(seconds) for _ = 1, math.ceil(seconds / 0.05 - 1e-6) do H.step(0.05) end end
function M.uadd(msg) return H.call("/uadd " .. msg, SlashCmdList.UADD, msg) end
function M.key(down)
    H.keys.SHIFT = down
    H.fire("MODIFIER_STATE_CHANGED", "LSHIFT", down and 1 or 0)
    M.wait(0.4)
end
function M.combat(on)
    H.combat = on
    if not on then H.fire("PLAYER_REGEN_ENABLED") end
    M.wait(on and 0.2 or 1.3)          -- U.AfterCombat looks again each second
end
function M.ru(key) return NS().LocaleData.ruRU[key] end
-- Its own Russian for the profile panel's row i (some match ours letter for letter).
function M.ruRow(i) return NS().LocaleData.ruRU[(WhatTheWhisperStandInFeed.profile or {})[i] or ""] end

-- Keys whose word through its L shows Cyrillic now (another language picked: none may), and the first one.
function M.cyrL()
    local n, first = 0, nil
    for k in pairs(S().enUS) do
        local v = NS().L[k]
        if type(v) == "string" and v:find("[\208-\211][\128-\191]") then n, first = n + 1, first or k end
    end
    return n, first
end

-- The saved-file export (Export.ToFile, its file is WhatTheWhisperExportDB) of a made-up talk with Zorp, one text per
-- format, its time stamps taken out (they change by the second). The file must hold the addon's English.
function M.exportFile()
    local ns, out = NS(), {}
    local day = ns.Format.DayStart(time())          -- whole minutes after midnight: its clock column stays the same
    local conv = { id = "Zorp-Realm", name = "Zorp", messages = {} }
    for i, back in ipairs({ 40, 3, 1, 0, 0 }) do
        conv.messages[i] = { day - back * DAY + 60 * i, i % 2 == 0 and ns.DIR_OUT or ns.DIR_IN, "hello " .. i }
    end
    local saved = rawget(_G, "WhatTheWhisperExportDB")
    _G.WhatTheWhisperExportDB = nil
    for _, f in ipairs(ns.Export.FORMATS) do
        local ok, err = ns.Export.ToFile(conv, f.id)
        local e = ok and _G.WhatTheWhisperExportDB.exports[conv.id .. "." .. f.id]
        out[f.id] = e and (e.text:gsub("%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d", "<stamp>")) or ("failed: " .. tostring(err))
    end
    _G.WhatTheWhisperExportDB = saved
    return out
end

-- The language picker: its setting, then its own redraw path.
function M.locale(code)
    NS().db.profile.appearance.locale = code
    NS().Options.Apply("appearance.locale")
    M.wait(0.2)
    return NS().ActiveLocale()
end

function M.build(i) return S().buildDialog(i) ~= nil end
function M.picker() return S().openPicker() ~= nil end
function M.throw(n) S().trap(n) end
function M.thrown() return S().throw end
function M.on() return H.ns[MOD].On() == true end
function M.swapped() return H.ns[MOD].Swap.On() == true end
function M.redraws() return S().redraws end

-- Everything a player can read, by place: main lines (L:key), bindings, sounds, export formats, the date
-- line and the list's stamp for each day back, the stub, dialog buttons, emoji tabs.
function M.snap()
    local ns, s, out = NS(), S(), {}
    for k, fs in pairs(s.lines) do out["L:" .. k] = fs:GetText() end
    for _, n in ipairs({ "TOGGLE", "EXPOSE", "REPLY" }) do out["B:" .. n] = _G["BINDING_NAME_WHATTHEWHISPER_" .. n] end
    for i, e in ipairs(ns.Sounds.LIBRARY) do out["X:sound:" .. i] = e.label end
    for i, e in ipairs(ns.Export.FORMATS) do out["X:export:" .. i] = e.label end
    local now = time()
    for n = 0, 6 do
        out["D:day:" .. n] = ns.Format.DayLabel(now - n * DAY)
        if n > 0 then out["D:stamp:" .. n] = ns.Format.ListStamp(now - n * DAY) end
    end
    out["P:body"], out["P:button"] = s.stub.body:GetText(), s.stub.button:GetText()
    for i, f in pairs(s.dialogs) do
        for field, b in pairs(f) do
            if type(b) == "table" and b.label then out["G:" .. i .. "." .. field] = b:GetText() end
        end
    end
    for _, b in ipairs(s.tabs or {}) do out["E:" .. b.categoryID] = b:GetText() end
    for i, row in ipairs(s.window.view.profile.rows) do out["R:main:" .. i] = row.label:GetText() end
    for id, w in pairs(s.popouts) do
        for i, row in ipairs(w.view.profile.rows) do out["R:pop" .. id .. ":" .. i] = row.label:GetText() end
    end
    out["S:size"] = s.settings.size
    for i, c in ipairs(s.settings.caps) do out["S:cap:" .. i] = c end
    return out
end

-- The profile panel and the settings' size line (Stand.lua).
function M.bytes(n) S().bytes, S().raw = n, nil S().render() end
function M.raw(text) S().raw = text S().render() end
function M.popout(id) S().popout(id) end
function M.closePopout(id) local w = S().popouts[id] if w then w:Hide() S().popouts[id] = nil end end
function M.hidePanel() S().window.view.profile:Hide() end
function M.showPanel()
    local p = S().window.view.profile
    p:Show()
    p:Refresh()
end
-- Its English size line for a size text, from its own template (the feed's key: its enUS value may be `true`).
function M.sizeEn(text) return WhatTheWhisperStandInFeed.size:format(text) end

-- The enUS table against its copy taken before the module loaded: keys whose value differs, added, gone.
function M.enusDiff()
    local now, was, n, sample = NS().LocaleData.enUS, S().enUS, 0, nil
    for k, v in pairs(now) do if was[k] ~= v then n, sample = n + 1, sample or k end end
    for k in pairs(was) do if now[k] == nil then n, sample = n + 1, sample or k end end
    return n, sample
end

function M.weekdaysSame()
    for d, v in pairs(S().weekdays) do if _G["WEEKDAY_" .. d] ~= v then return false, d end end
    return true, nil
end

-- The stub's game fonts (lesson 32): its line's font file, if UADD counts it Cyrillic, and its font object.
function M.stubFont()
    local st = S().stub
    local out = {}
    for i, fs in ipairs({ st.body, st.button:GetFontString() }) do
        local path = fs:GetFont()
        out[i] = { path, UADD.IsCyrFont(path) and true or false, fs:GetFontObject() }
    end
    return out[1][1], out[1][2], out[1][3] == GameFontHighlightSmall, out[2][1], out[2][2]
end
function M.stubPaths() local st = S().stub return (st.body:GetFont()), (st.button:GetFontString():GetFont()) end

-- The half-line check's path: the addon's own formatting of its locale table (ours while on).
function M.line(key, ...) return NS().L[key]:format(...) end
function M.softErrors() return #NS().softErrors end
