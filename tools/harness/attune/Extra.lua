-- Not Attune: more of the stand-in for tools/harness/flow_att_fix.py, copied in spirit from Attune
-- 16001's Attune.lua: the texts Attune sets and measures before they are inside its windows.
--   * Attune_AceCreate: AceGUI:Create with AceGUI.WidgetBase.SetWidth and SetHeight swapped for the
--     time of the call (Attune's is a local function; this one is global so Attune.lua can use it).
--   * The header of a picked attunement (Attune_Select): a Label given its text and measured before
--     AddChild, in a group whose old labels are released first.
--   * The "Will not do" check box (Attune_CreateSkipCheck): made once, its text set from
--     Attune_WillNotDoLabel and the box sized to the text.
--   * The icon view's section header (Attune_IconViewHeader, then its text set and measured).
--   * A text a player typed that reads like our words (SI.Typed), on the step graph.
local L = AttuneLang
local SI = AttuneStandIn
local AceGUI = LibStub("AceGUI-3.0")

function Attune_AceCreate(widgetType)
    local base = AceGUI.WidgetBase
    local origWidth, origHeight = base.SetWidth, base.SetHeight
    base.SetWidth = function(self, width) return origWidth(self, width) end
    base.SetHeight = function(self, height) return origHeight(self, height) end
    local ok, widget = pcall(AceGUI.Create, AceGUI, widgetType)
    base.SetWidth, base.SetHeight = origWidth, origHeight
    if not ok then error(widget, 0) end
    return widget
end

function Attune_WillNotDoLabel()
    return L["WillNotDo"] or "Will not do"
end

function Attune_CreateSkipCheck()
    local holder = rawget(_G, "AttuneSkipCheck")
    if holder == nil then
        holder = CreateFrame("Button", nil, SI.frame.content)
        holder:SetHeight(24)
        holder.text = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        holder.text:SetPoint("LEFT")
        AttuneSkipCheck = holder
    end
    local label = Attune_WillNotDoLabel()
    holder.text:SetText(label)
    local w = holder.text:GetStringWidth()
    if not SI.skipSeen then SI.skipSeen, SI.skipW = holder.text:GetText(), w end   -- its first draw
    holder:SetWidth(w + 28)
    holder:Show()
end

function Attune_IconViewHeader(view)
    local header = CreateFrame("Frame", nil, view.content)
    header:SetHeight(16)
    header.text = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    header.text:SetPoint("CENTER", header, "CENTER", 0, 0)
    return header
end

local view
local function IconHeader()
    if not view then view = { content = CreateFrame("Frame", nil, SI.frame.content) } end
    if SI.iconHeader then return end
    local header = Attune_IconViewHeader(view)
    header.text:SetText(L["RAIDS"])
    SI.iconSeen, SI.iconW = header.text:GetText(), header.text:GetStringWidth()
    header:SetWidth(SI.iconW + 40)
    SI.iconHeader = header
end

local head
function SI.Header(id)
    if not SI.frame then return end
    if not head then
        head = Attune_AceCreate("SimpleGroup")
        head:SetFullWidth(true)
        SI.frame:AddChild(head)
    end
    head:ReleaseChildren()
    local label = Attune_AceCreate("Label")
    label:SetText(L["Required level"])
    SI.headSeen, SI.headW = label.label:GetText(), label.label:GetStringWidth()
    head:AddChild(label)
    SI.headLabel = label
    Attune_CreateSkipCheck()
    IconHeader()
end

function SI.Typed(show)
    local graph = rawget(_G, "Attune_GraphRoot")
    if not SI.typed then SI.typed = graph:CreateFontString(nil, "OVERLAY", "GameFontNormal") end
    SI.typed:SetText("Потрібен рівень")
    SI.typed:SetShown(show)
end
