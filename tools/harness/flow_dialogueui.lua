-- Lua helpers for flow_dialogueui.py, on the DialogueUI stand-in (tools/harness/dialogueui).
-- Reached from Python as HARNESS.dui. Run before the game starts: it lets the stand-in's font file
-- load (the harness knows only the client's own font files).
local H = HARNESS
local M = {}
H.dui = M
H.fontFiles["interface\\addons\\dialogueui\\fonts\\frizqt__.ttf"] = true
H.fontFiles["interface/addons/dialogueui/fonts/frizqt__.ttf"] = true

local function S() return rawget(_G, "DialogueUIStandIn") end
local function Has(t) return type(t) == "string" and t:find("[\208-\210]") ~= nil end

-- string.upper, with the Ukrainian letters too (Lua's upper leaves them as they are).
local function UpperUK(s)
    s = s:upper()
    s = s:gsub("\208([\176-\191])", function(c) return "\208" .. string.char(c:byte() - 32) end)
    s = s:gsub("\209([\128-\143])", function(c) return "\208" .. string.char(c:byte() + 32) end)
    s = s:gsub("\209([\144-\159])", function(c) return "\208" .. string.char(c:byte() - 16) end)
    return (s:gsub("\210\145", "\210\144"))
end
M.UpperUK = UpperUK

-- The stand-in's L with our Ukrainian in it (ns.UA of UADD_DialogueUI/ui/locale.lua), key pictures
-- made the way the stand-in makes them; a key we have no Ukrainian for stays English.
local ukL
local function UK()
    if ukL then return ukL end
    local ns = H.ns and H.ns.UADD_DialogueUI
    local ua = ns and ns.UA or {}
    ukL = {}
    for k, v in pairs(S().L) do
        local u = ua[k]
        ukL[k] = type(u) == "string" and S().KeyMarkup(u) or v
    end
    return ukL
end

-- What a widget should show: "en" (DialogueUI's own) or "uk" (our words).
function M.want(name, mode)
    local s = S()
    local r = s.recipes[name]
    if not r then return nil end
    if mode == "uk" and not s.readBack[name] then return s.Join(r(UK(), UpperUK)) end
    return s.Join(r(s.L, string.upper))
end
function M.text(name) local fs = S().texts[name] return fs and fs:GetText() end
function M.size(name) local _, size = S().texts[name]:GetFont() return size end

-- Every shown widget against what it should show. Returns the wrong ones and how many were looked at.
function M.compare(mode)
    local bad, n = {}, 0
    for name, fs in pairs(S().texts) do
        if fs:IsVisible() then
            n = n + 1
            local want, got = M.want(name, mode), fs:GetText()
            if got ~= want then bad[#bad + 1] = name .. ": " .. tostring(got) .. " | want " .. tostring(want) end
        end
    end
    table.sort(bad)
    return bad, n
end

-- Every shown Ukrainian text in a font with Ukrainian letters, at the size and flags of its font object.
function M.fontsCyr()
    local bad = {}
    for _, e in ipairs(S().all) do
        local fs = e.fs
        if fs:IsVisible() and Has(fs:GetText()) then
            local p, size, flags = fs:GetFont()
            local _, osize, oflags = e.object:GetFont()
            if not UADD.IsCyrFont(p) or size ~= osize or flags ~= oflags then
                bad[#bad + 1] = ("%s %s %s %s"):format(tostring(fs:GetText()):sub(1, 40), tostring(p), tostring(size),
                    tostring(flags))
            end
        end
    end
    return bad
end

-- Every FontString exactly as DialogueUI made it: its own font object, that object's file, size, flags.
function M.fontsOriginal()
    local bad = {}
    for _, e in ipairs(S().all) do
        local fs = e.fs
        local p, size, flags = fs:GetFont()
        local op, osize, oflags = e.object:GetFont()
        if fs:GetFontObject() ~= e.object or p ~= op or size ~= osize or flags ~= oflags then
            bad[#bad + 1] = ("%s: %s %s %s | want %s %s %s"):format(tostring(fs:GetText()):sub(1, 40), tostring(p),
                tostring(size), tostring(flags), op, osize, oflags)
        end
    end
    return bad
end

-- DialogueUI's windows: a quest, the settings, the item tooltip, a book.
function M.showAll()
    H.fire("QUEST_DETAIL")
    DialogueUI_ShowSettingsFrame()
    S().ShowItemTooltip()
    S().ShowBook()
end
function M.event(e) H.fire(e) end
function M.root(name, show) local f = _G[name] if show then f:Show() else f:Hide() end end
function M.made() return S().Made() end
function M.serverText()
    for name, fs in pairs(S().texts) do
        if fs:IsVisible() and fs:GetText() == S().SERVER then return name end
    end
end

-- FontUtil: the size setting changes the DUIFont_* objects; the FontStrings that still follow their
-- object follow (the client does that by itself, the harness does not: it is done here without
-- calling SetFont on them). One that got its own SetFont (our Cyrillic file) keeps its old size.
function M.fontSize(size)
    S().SetFontSize(size)
    for _, e in ipairs(S().all) do
        if not UADD.IsCyrFont((e.fs:GetFont())) then
            local p, sz, flags = e.object:GetFont()
            rawset(e.fs, "__font", { p, sz, flags })
        end
    end
end

-- Words.Text straight (body: as on a quest page).
function M.words(t, body) return H.ns.UADD_DialogueUI.Words.Text(t, body) end
function M.dupes() return #H.ns.UADD_DialogueUI.Words.Dupes() end

-- Words.Shape (Lua, made in game from a game global) against what tools/make_dui_data.py stored for
-- the same text (Python): the keys whose game global the harness has with DialogueUI's own English
-- (where the two differ, e differs and the game's text is the one shown). Returns how many, the bad ones.
local function Same(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return a == b end
    for k, v in pairs(a) do if not Same(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end
function M.shapes()
    local ns, n, bad = H.ns.UADD_DialogueUI, 0, {}
    for key, s in pairs(ns.DUI_HASH) do
        local g = s.g and rawget(_G, s.g)
        local made = type(g) == "string" and ns.Words.Shape(g)
        if made and made.e == s.e then
            n = n + 1
            local stored = {}
            for k, v in pairs(s) do if k ~= "g" then stored[k] = v end end
            if not Same(made, stored) then
                local diff = {}
                for k in pairs(made) do if not Same(made[k], stored[k]) then diff[#diff + 1] = k end end
                for k in pairs(stored) do if made[k] == nil then diff[#diff + 1] = k end end
                bad[#bad + 1] = key .. " (" .. table.concat(diff, " ") .. ")"
            end
        end
    end
    return n, table.concat(bad, ", ")
end
function M.isBody(name) return UADD.DialogueUIScreen.IsBody(S().texts[name]) end

-- Its page in the game's options. setL: an English read from the installed DialogueUI (never kept in
-- the repo), key pictures made as the stand-in makes them.
function M.setL(key, text) S().L[key] = S().KeyMarkup(text) ukL = nil end
function M.makeCanvas() S().MakeCanvas() end
function M.openCanvas()             -- Options opened, then the Dialogue UI page picked
    SettingsPanel:Show()
    SettingsPanel:SelectCategory(S().canvasCategory)
end
function M.closeCanvas()
    S().canvas:Hide()
    SettingsPanel:Hide()
end
function M.canvasFound() return UADD.DialogueUIScreen.Canvas() == S().canvas end
function M.useSpare() S().UseSpare() end
function M.setAgain(name) S().SetAgain(name) end

-- Read back: DialogueUI finds L["Item Level"] in line 2 and adds the difference; text-to-speech
-- reads the quest name from the header.
function M.readBack()
    S().ShowItemTooltip()
    return S().itemLevelParsed == true, S().tip:GetLeftLineText(2) == M.want("itemLevel", "en"),
        S().TTSTitle() == S().QUEST, S().TTSTitle()
end

-- Two chat lines from PrintMessage, against "en" or "uk". Returns the wrong ones.
function M.chat(mode)
    local from = #H.chat
    S().Chat()
    local bad = {}
    for i, r in ipairs(S().chatRecipes) do
        local want, got = r(mode == "uk" and UK() or S().L), H.chat[from + i]
        if got ~= want then bad[#bad + 1] = tostring(got) .. " | want " .. want end
    end
    return bad
end
function M.chatPutBack() return rawget(DEFAULT_CHAT_FRAME, "AddMessage") == nil end
function M.lastChat(n)
    local out = {}
    for i = math.max(1, #H.chat - n + 1), #H.chat do out[#out + 1] = H.chat[i] end
    return table.concat(out, "\n")
end

function M.combat(on)
    H.combat = on
    if not on then H.fire("PLAYER_REGEN_ENABLED") end
end
function M.key(down)
    H.keys.SHIFT = down
    H.fire("MODIFIER_STATE_CHANGED", "LSHIFT", down and 1 or 0)
end
function M.wait(seconds) for _ = 1, math.ceil(seconds / 0.05 - 1e-6) do H.step(0.05) end end
function M.uadd(msg) return H.call("/uadd " .. msg, SlashCmdList.UADD, msg) end
function M.standIn() return S() ~= nil end
