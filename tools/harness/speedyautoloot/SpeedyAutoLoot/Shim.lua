-- Game functions Speedy AutoLoot calls that the harness lacks. Run before its own files (tools/harness/flow_sal.py
-- runs those from the installed addon). Values as on a Forever client's Mainline build.

local function fill(t, k, v) if rawget(t, k) == nil then t[k] = v end end

fill(_G, "WOW_PROJECT_MAINLINE", 1)
fill(_G, "WOW_PROJECT_CAMELOT", 99)
fill(_G, "LE_EXPANSION_WARLORDS_OF_DRAENOR", 5)
fill(_G, "LE_EXPANSION_BATTLE_FOR_AZEROTH", 7)
fill(_G, "LE_EXPANSION_DRAGONFLIGHT", 9)

C_Item = rawget(_G, "C_Item") or {}
fill(C_Item, "GetItemQualityColor", function(q)
    local hex = ({ [0] = "ff9d9d9d", "ffffffff", "ff1eff00", "ff0070dd", "ffa335ee", "ffff8000" })[q or 1] or "ffffffff"
    local r, g, b = tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255, tonumber(hex:sub(7, 8), 16) / 255
    return r, g, b, hex
end)

local W = HARNESS.Widget
for _, name in ipairs({ "SetPropagateMouseClicks", "SetCollapsesLayout", "SetTextureSliceMargins",
    "SetTextureSliceMode" }) do
    if not W[name] then W[name] = function() end end
end
