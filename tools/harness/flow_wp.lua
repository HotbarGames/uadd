-- Lua helpers for flow_wp.py, on the Waypoint UI stand-in (tools/harness/waypointui). Reached from Python as
-- HARNESS.wp. Run before the game starts.
local H = HARNESS
local M = {}
H.wp = M

M.CUSTOM = "Interface\\AddOns\\WaypointUI\\Fonts\\standin.ttf"     -- a font from its list, no Cyrillic
H.fontFiles[M.CUSTOM:lower()] = true

-- The proof that a step has teeth: with M.cut set, Screen.lua runs without one fix (this run's copy, in memory
-- only; the module's file is never changed). fault: lesson 26 (its SetText failing after it drew ours);
-- cache: lesson 12 (each frame's last answer); busy: our own SetText runs our handler again. place: the
-- destination line's hook; pinplace: the pinpoint name's map look-up (Words.lua); wait: a "not known yet"
-- answer kept as if final, so the later ask never comes. quest: the tracked quest's title look-up (Words.lua).
-- guard: its text hooks under U.Safe, dead after an off for errors; guardshow: its windows' OnShow so;
-- guardfont: its fonts' SetFont so (lesson 19).
local CUTS = {
    guard = { { "local OnChanged = Guard(function", "(function", 'local OnChanged = U.Safe("waypointui", function' },
              { "local OnFormatted = Guard(function", "(function", 'local OnFormatted = U.Safe("waypointui", function' } },
    guardshow = { { 'f:HookScript("OnShow", Guard(', "Guard(", 'f:HookScript("OnShow", U.Safe("waypointui", ' } },
    guardfont = { { "ns.Guard(Refit)", "Refit)", 'U.Safe("waypointui", Refit)', file = "Fonts.lua" } },
    busy = { { "    busy = true\n    local ok, err", "local ok, err", "    local ok, err" } },
    fault = { { "    if not ok then U.Fault(", "return ok or TextOf(f) == text\n", "    return ok\n" },
              { "            if TextOf(f) ~= en then pcall(", "its SetText failed first\n", "" } },
    cache = { { "    local uk, wait          ", "st.kmaps = text, uk, st.look, maps end\n    end\n",
                "    local uk, wait = st.look(text)\n" } },
    place = { { "    if IsText(info) then Hook(info, ns.Info)", "\n", "" } },
    pinplace = { { "    local place, w = ns.Place(en)", "\n", "    local place, w = nil, nil\n",
                   file = "Words.lua" } },
    quest = { { "    local isQuest, uk, wait = ns.Quest(en)", "\n", "    local isQuest, uk, wait = false, nil, nil\n",
                file = "Words.lua" } },
    wait = { { "        if not wait then st.ken", "\n", "        st.ken, st.kuk, st.klook, st.kmaps = text, uk, st.look, maps\n" } },
}
M.cut, M.wasCut = nil, false
local hits = 0
local runFile = H.runFile
function H.runFile(addon, path, code)
    if addon == "UADD_WaypointUI" and M.cut then
        for _, c in ipairs(CUTS[M.cut]) do
            if path == (c.file or "Screen.lua") then
                local a = code:find(c[1], 1, true)
                local b = a and select(2, code:find(c[2], a, true))
                if a and b then
                    code = code:sub(1, a - 1) .. c[3] .. code:sub(b + 1)
                    hits = hits + 1
                end
            end
        end
        M.wasCut = hits == #CUTS[M.cut]
    end
    return runFile(addon, path, code)
end

-- The pin's map (Words.lua Place): the user waypoint on a made-up map tree, and a made-up UADD.UALL.Zone
-- (lesson 20: the stub patches UADD.UALL, never the root). zones: English -> Ukrainian; wait: every answer
-- is "not known yet".
M.zones, M.waiting = {}, false
function M.place(mapID)
    local tree = { [7001] = { name = "Zorpwood Vale", parentMapID = 7000 },
                   [7002] = { name = "Fizzle Marsh", parentMapID = 7000 },
                   [7000] = { name = "Blatter Reach", parentMapID = 0 } }
    local info = C_Map.GetMapInfo
    if not M.mapInfo then M.mapInfo = info end
    C_Map.GetMapInfo = function(id)
        local t = tree[id]
        if t then return { mapID = id, name = t.name, mapType = 3, parentMapID = t.parentMapID } end
        return M.mapInfo(id)
    end
    C_Map.GetUserWaypoint = function() return mapID and { uiMapID = mapID, position = { x = 0.5, y = 0.5 } } end
    UADD.UALL.Zone = function(en)
        if M.waiting then return nil, true end
        return M.zones[en]
    end
end
function M.zone(en, uk) M.zones[en] = uk end
function M.wait4(on) M.waiting = on and true or false end

-- The tracked quest (Words.lua Quest): a made-up super-tracked quest whose title the quest API gives, and a
-- made-up UADD.UALL.Quest (lesson 20). quests: English title -> Ukrainian; M.waiting: "not known yet" too.
-- track(nil): nothing tracked.
M.quests = {}
function M.quest(en, uk) M.quests[en] = uk end
function M.track(id, title)
    if id then H.questTitles[id] = title end
    C_SuperTrack.GetSuperTrackedQuestID = function() return id or 0 end
    UADD.UALL.Quest = function(_, en)
        if M.waiting then return nil, true end
        return M.quests[en]
    end
end

WaypointUIStandInFeed = { settings = {}, missing = {} }
function M.feed(k, v) WaypointUIStandInFeed[k] = v end
function M.feedSetting(en) local t = WaypointUIStandInFeed.settings t[#t + 1] = en end
function M.miss(name) WaypointUIStandInFeed.missing[name] = true end

local function S() return rawget(_G, "WaypointUIStandIn") end
local function NS() return H.ns.UADD_WaypointUI end
M.S = S
function M.fits() return S().fits end
function M.gamePath() return (GameFontNormal:GetFont()) end
function M.loaded() return S() ~= nil and NS() ~= nil and NS().Words ~= nil end
function M.on() return NS().On() and true or false end
function M.text(name) local f = S().texts[name] return f and f:GetText() end
function M.set(name, t) S().texts[name]:SetText(t) return S().texts[name]:GetText() end
function M.setRaw(name, t) S().texts[name].__Text:SetText(t) end   -- the addon writes its font string itself
function M.count() local n, uk = NS().Screen.Count() return n, uk end
function M.words() return NS().Words.Count() end
function M.Text(t) return NS().Text(t) end
function M.Units(t) return NS().Units(t) end
function M.Pinpoint(t) return NS().Pinpoint(t) end
function M.throw(mode) S().throw = mode end
function M.setf(name, t) S().texts[name]:SetFormattedText("%s", t) return S().texts[name]:GetText() end
-- Our own hook throws (each text it looks at), as when its code is odd; back on false.
local canDraw
function M.trip(on)
    local F = NS().Fonts
    canDraw = canDraw or F.CanDraw
    F.CanDraw = on and function() error("stand-in: our hook fails") end or canDraw
end

-- Our Ukrainian for a whole text, straight from the module's data.
function M.want(key)
    local uk = NS().WP.exact[key]
    return uk and UADD.Plural(uk, true)
end
-- A template filled by hand from its record (uk: pieces, numbers are slots).
function M.fill(id, a)
    for _, rec in ipairs(NS().WP.templates) do
        if rec.id == id then
            local out = {}
            for _, p in ipairs(rec.uk) do out[#out + 1] = type(p) == "number" and tostring(a) or p end
            return UADD.Plural(table.concat(out), true)
        end
    end
end
function M.prompt(template, name) S().Prompt(template, name) return M.text("prompt") end

-- The footer: n ticks with the same two lines; how many unit look-ups they cost (the distance pattern runs
-- once per Units call that is not cached).
function M.ticks(n, dist, time)
    local match, calls = string.match, 0
    string.match = function(s, p, ...)                              -- luacheck: ignore
        if p == "^(%d[%d,]*) yds$" then calls = calls + 1 end
        return match(s, p, ...)
    end
    local ok, err = pcall(function() for _ = 1, n do S().Tick(dist, time) end end)
    string.match = match                                            -- luacheck: ignore
    if not ok then error(err) end
    return calls, M.text("dist"), M.text("time")
end

-- Fonts: (path, size, flags) of one of its font objects: footer, pinpoint, ui1..ui3.
local function Obj(which)
    local f = S().fonts
    return f[which] or f.ui[tonumber(which:match("%d+$") or 0)]
end
function M.font(which) return Obj(which):GetFont() end
function M.cyr(which) return UADD.IsCyrFont((Obj(which):GetFont())) and true or false end
function M.updateFonts(path, footerFlags, pinFlags)
    FontHandler.fontPath = path
    FontHandler.footerFlags, FontHandler.pinpointFlags = footerFlags or "", pinFlags or ""
    FontHandler.UpdateFonts()
end
M.backs = 0
function M.after()                                  -- after login: count U.FontBack on its footer font
    local back = UADD.FontBack
    UADD.FontBack = function(o, was)
        if o == S().fonts.footer then M.backs = M.backs + 1 end
        return back(o, was)
    end
end

function M.open() S().OpenSettings() end
function M.close() S().CloseSettings() end
function M.tab(en, key) S().Tab(en, key) return M.text(key) end

function M.focus() return GetCurrentKeyBoardFocus() end
function M.lastChat(n)
    local out = {}
    for i = math.max(1, #H.chat - n + 1), #H.chat do out[#out + 1] = H.chat[i] end
    return table.concat(out, " | ")
end
function M.chats() return #H.chat end
function M.key(down)
    H.keys.SHIFT = down
    H.fire("MODIFIER_STATE_CHANGED", "LSHIFT", down and 1 or 0)
    M.wait(0.4)
end
function M.wait(seconds) for _ = 1, math.ceil(seconds / 0.05 - 1e-6) do H.step(0.05) end end
function M.uadd(msg) return H.call("/uadd " .. msg, SlashCmdList.UADD, msg) end

-- The slowest of three runs of fn(text), in ms.
function M.slow(fn, text)
    local f, worst = NS()[fn] or function(t) return M.set("input", t) end, 0
    for _ = 1, 3 do
        local t0 = debugprofilestop()
        f(text)
        worst = math.max(worst, debugprofilestop() - t0)
    end
    return worst
end
