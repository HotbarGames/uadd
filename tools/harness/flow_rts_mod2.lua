-- H2, part 2: step 13 of flow_rts_mod.lua (combat and the off for errors) and more of step 7 (joined names, the
-- History filter menu), split off for the file budget. Run right after flow_rts_mod.lua; it adds R[13], wraps R[7]
-- and uses that file's helpers (R._). R.tr gives W.Translate to flow_rts_mod.py's real joined lines.
local H = HARNESS
local R = H.rtsmod
local S, M = RTSStandIn, H.rts
local ns = H.ns.UADD_RoadToSixty
local W = ns.Words
local T = S.T
local Res, Title = R._.Res, R._.Title

R[13] = function()
    local out = {}
    local names = { "SetPoint", "SetSize", "SetWidth", "SetHeight", "Show", "Hide", "SetParent", "ClearAllPoints", "SetAttribute" }
    local ours, any, saved = {}, 0, {}
    for _, k in ipairs(names) do
        local o = H.Widget[k]
        if o then
            saved[k] = o
            H.Widget[k] = function(self, ...)
                if H.combat then
                    any = any + 1
                    if debugstack():find("AddOns/UADD", 1, true) then ours[#ours + 1] = k end
                end
                return o(self, ...)
            end
        end
    end
    local ok, err = pcall(function()
        M.combat(true)
        S.Tick(3) S.Redraw()
        local key = next(S.Popups()) and select(2, next(S.Popups()))
        StaticPopup_Show(key, "Quix") M.key(true) M.key(false) StaticPopup_Hide(key)
        M.combat(false)
    end)
    M.combat(false)
    for k, o in pairs(saved) do H.Widget[k] = o end
    M.wait(0.3)
    Res(out, "combat: no layout call from UADD on any frame", ok and #ours == 0, tostring(err or "") .. table.concat(ours, ","))
    Res(out, "combat: the watch saw calls (not empty)", any > 0, any)
    -- 5 errors in the module's look-up turn it off; the English comes back.
    local mt = getmetatable(ns.RTS)
    setmetatable(ns.RTS, { __index = function() error("rts: planted error") end })
    for i = 1, 6 do pcall(W.Translate, "Plonk wibble " .. i) end
    setmetatable(ns.RTS, mt)
    M.wait(0.3) S.Redraw() M.wait(0.1)
    local on = type(ns.On) == "function" and ns.On()
    Res(out, "5 errors turn the module off, English back", not on and Title() == T.title, tostring(on) .. " | " .. Title())
    return out
end

-- Step 7 more: a name between two pieces the code glues (a joined row, sort f), of one or two words; and the
-- History filter menu, a nameless frame the addon makes on first right-click under its pane (Panel.lua
-- ShowFilterMenu: a title and check boxes with labels, set again on each open, more boxes made later).
local U = UADD
local function Key(en) return "Code." .. U.Hash(en) end
local function Put(en, uk, sort) ns.RTS[Key(en)] = uk ns.SORT[Key(en)] = sort end
local function Cyr(s) return tostring(s or ""):find("[\208\209]") ~= nil end
local function CyrFont(fs) local p = fs and fs.GetFont and fs:GetFont() return p and U.IsCyrFont(p) and true or false end
function R.tr(s) local uk = W.Translate(s) return uk, ns.RTS[Key(s)] end
local base7 = R[7]
R[7] = function()
    local out = base7()
    Put("Poke %s's gizmo", "Тицьнути гаджет: %s", "f") W.Forget()
    local a, b = W.Translate("Poke Quix's gizmo"), W.Translate("Poke Quix Zorpson's gizmo")
    Res(out, "joined: a name of one word between two pieces: whole Ukrainian, the name kept", a == "Тицьнути гаджет: Quix", a)
    Res(out, "joined: a name of two words (First Last) inside the text: whole Ukrainian, kept", b == "Тицьнути гаджет: Quix Zorpson", b)
    local bad = {}
    for _, s in ipairs({ "Poke quix zorp's gizmo", "Poke Quix zorp's gizmo", "Poke Quix - Zorp's gizmo",
        "Poke Quix Zorp Blip's gizmo", "Poke Quix  Zorp's gizmo", "Poke Quix: Zorp's gizmo" }) do
        local g = W.Translate(s)
        if g ~= nil then bad[#bad + 1] = s .. " -> " .. g end
    end
    Res(out, "joined: an unknown middle (small letters, a dash, three words, two spaces, a colon) stays English", #bad == 0, table.concat(bad, " | "))
    Put("Gizmo kinds", "Види гаджетів") Put("Wobbly gizmos", "Хиткі гаджети") Put("Bent gizmos", "Гнуті гаджети")
    Put("Shiny gizmos", "Блискучі гаджети") W.Forget()
    local pane = CreateFrame("Frame", nil, RoadToSixtyJourneyFrame)
    M.wait(0.2)
    local menu = CreateFrame("Frame", nil, pane, "BackdropTemplate")
    menu.title = menu:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    menu.boxes = {}
    local function Open(title, labels)
        menu.title:SetText(title)
        for i, en in ipairs(labels) do
            local box = menu.boxes[i]
            if not box then
                box = CreateFrame("CheckButton", nil, menu, "UICheckButtonTemplate")
                box.label = box:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                menu.boxes[i] = box
            end
            box.label:SetText(en)
        end
        menu:Show() M.wait(0.2)
    end
    local function Seen()
        local t = { menu.title:GetText() }
        for _, box in ipairs(menu.boxes) do t[#t + 1] = box.label:GetText() end
        return t
    end
    local function AllOurs(want)
        local t = Seen()
        if #t ~= #want then return false end
        for i, s in ipairs(t) do if s ~= want[i] then return false end end
        if not CyrFont(menu.title) then return false end
        for _, box in ipairs(menu.boxes) do if not CyrFont(box.label) then return false end end
        return true
    end
    Open("Gizmo kinds", { "Wobbly gizmos" })
    Res(out, "filter menu: made late under the pane, its title and box ours in a Cyrillic font",
        AllOurs({ "Види гаджетів", "Хиткі гаджети" }), table.concat(Seen(), " | "))
    Open("Gizmo kinds", { "Bent gizmos", "Shiny gizmos", "Wobbly gizmos" })
    local want = { "Види гаджетів", "Гнуті гаджети", "Блискучі гаджети", "Хиткі гаджети" }
    Res(out, "filter menu: opened again with more boxes, all ours", AllOurs(want), table.concat(Seen(), " | "))
    M.key(true)
    local held = Seen()
    M.key(false)
    local again = AllOurs(want)
    SlashCmdList.UADD("rts off") M.wait(0.3)
    local off = Seen()
    SlashCmdList.UADD("rts on") M.wait(0.3)
    local eng = true
    for _, s in ipairs(held) do if Cyr(s) then eng = false end end
    for _, s in ipairs(off) do if Cyr(s) then eng = false end end
    Res(out, "filter menu: English while held and off, ours again on release",
        eng and again and held[2] == "Bent gizmos" and off[1] == "Gizmo kinds",
        table.concat(held, " | ") .. " || " .. table.concat(off, " | "))
    menu:Hide()
    return out
end
