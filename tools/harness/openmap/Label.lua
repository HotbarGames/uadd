-- More of the stand-in (OpenMap.lua): the World Map's hover label. Written for the checks, not
-- taken from the game or from OpenMap. For flow_openmap_label.py.
--   * The game's label provider: a data provider on the World Map whose .Label has a Name and a
--     Description text, with SetLabel, ClearLabel and EvaluateLabels (which sets both texts again).
--     Added as this file loads, so UALL Forever (loaded after it) finds it, as it does in the game.
--   * OpenMap's part: each frame the cursor is on the map, it clears the label and sets it again,
--     the zone's name with its level range in colour and its fishing line under it (S.Hover).

local S = OpenMapStandIn
local AREA = 1   -- the game's MAP_AREA_LABEL_TYPE.AREA_NAME

local provider = { Label = CreateFrame("Frame", nil, WorldMapFrame) }
local label = provider.Label
label:SetPoint("TOP", WorldMapFrame, "TOP", 0, -30)
label.Name = label:CreateFontString(nil, "OVERLAY")
label.Name:SetFont(STANDARD_TEXT_FONT, 20, "OUTLINE")
label.Name:SetPoint("TOP", label, "TOP")
label.Description = label:CreateFontString(nil, "OVERLAY")
label.Description:SetFont(STANDARD_TEXT_FONT, 14, "")
label.Description:SetPoint("TOP", label.Name, "BOTTOM")
label.labels = {}

function label:SetLabel(kind, name, description) self.labels[kind] = { name = name, description = description } end
function label:ClearLabel(kind) self.labels[kind] = nil end
function label:EvaluateLabels()
    local l = self.labels[AREA]
    self.Name:SetText(l and l.name or "")
    self.Description:SetText(l and l.description or "")
end

WorldMapFrame:AddDataProvider(provider)
S.label = label

-- One frame of OpenMap's OnUpdate over a zone: `range` ("1-10", or nil for a plain name),
-- `color` the range's colour code, `fish` the fishing line (or nil). With no name: off the map.
function S.Hover(name, range, color, fish)
    label:ClearLabel(AREA)
    if name then
        if range then name = ("%s %s(%s)|r"):format(name, color or "|cff40c040", range) end
        label:SetLabel(AREA, name, fish)
    end
    label:EvaluateLabels()
end
