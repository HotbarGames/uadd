-- H2, part 2: step 13 of flow_rts_mod.lua (combat and the off for errors), split off for the file budget.
-- Run right after flow_rts_mod.lua; it adds R[13] to HARNESS.rtsmod and uses that file's helpers (R._).
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
