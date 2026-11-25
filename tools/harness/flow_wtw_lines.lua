-- Lua helpers for flow_wtw_lines.py (UADD_WhatTheWhisper, Lines.lua), added to HARNESS.wtw of flow_wtw.lua.
local H = HARNESS
local M = H.wtw
local function NS() return rawget(_G, "WhatTheWhisper") end

-- Made-up zones (lesson 20: the stub patches UADD.UALL). mode: nil answers, "wait" not known yet, "error" throws.
M.zones, M.asked = {}, {}
function M.zoneStub(mode)
    M.zoneReal = M.zoneReal or UADD.UALL.Zone
    M.asked = {}
    UADD.UALL.Zone = function(en)
        M.asked[#M.asked + 1] = en
        if mode == "error" then error("harness: zone route") end
        return M.zones[en], mode == "wait" or nil
    end
end
function M.zoneBack() if M.zoneReal then UADD.UALL.Zone = M.zoneReal M.zoneReal = nil end end
function M.nAsked() return #M.asked end

-- What its Print sends to the chat window for these texts (its own prefix cut off).
function M.print(...)
    local chat, got = DEFAULT_CHAT_FRAME, nil
    local add = chat.AddMessage
    chat.AddMessage = function(_, t) got = t end
    local ok, err = pcall(NS().Print, ...)
    chat.AddMessage = add
    if not ok then return "failed: " .. tostring(err) end
    local p = NS().CHAT_PREFIX or ""
    if type(got) == "string" and got:sub(1, #p) == p then got = got:sub(#p + 1) end
    return got
end
-- The zone alert as its code builds it: its own template (the key) through its L, then Print.
function M.alert(key, name, zone) return M.print(NS().L[key]:format(name, zone)) end
function M.english(key, name, zone) return key:format(name, zone) end
function M.printIsOwn() return NS().Print == WhatTheWhisperStandIn.print end

function M.icon(shown) NS().IconPicker.Open(shown) end
function M.export(id, name) NS().Dialogs.ShowExport({ id = id, name = name, isGroup = id:sub(1, 3) == "CH:" }) end
function M.hideWindows()
    for _, n in ipairs({ "WhatTheWhisperIconDialog", "WhatTheWhisperCopyDialog" }) do
        if _G[n] then _G[n]:Hide() end
    end
end
-- The open windows' texts.
function M.windows()
    local d, out = _G.WhatTheWhisperIconDialog, {}
    if d and d:IsShown() then
        out.title, out.hint, out.empty = d.title:GetText(), d.hint:GetText(), d.empty:GetText()
        out.reset = d.reset:GetText()
    end
    d = _G.WhatTheWhisperCopyDialog
    if d and d:IsShown() then out.export = d.title:GetText() end
    return out
end
function M.feedKey(field)
    local f = WhatTheWhisperStandInFeed
    return field == "export" and f.export or f.icon[field]
end
