-- Stand-in for RareScanner (tools/harness/flow_rarescanner.py). Every word comes from RareScanner's own
-- AceLocale table (its enUS file, run from the installed addon before this file); this file names keys
-- only. Like RareScanner, it reads the words at load: its settings table, its page names, its pop-ups
-- (its own LibDialog copy) and the explorer's icon tooltips. Two lines are read each time they show.

local AL = LibStub("AceLocale-3.0"):GetLocale("RareScanner")
local S = {}
RareScannerStandIn = S

-- Its own LibDialog copy: just the delegates and Spawn.
local Dlg = LibStub:NewLibrary("LibDialog-1.0RS", 1)
Dlg.delegates, Dlg.active_dialogs = {}, {}
function Dlg:Register(name, d) self.delegates[name] = d end
function Dlg:Spawn(name)
    local d = self.delegates[name]
    local f = CreateFrame("Frame", nil, UIParent)
    f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.text:SetText(d.text)
    f:Show()
    self.active_dialogs[#self.active_dialogs + 1] = f
    return f
end

Dlg:Register("RS_FILTERING", { text = string.format(AL["EXPLORER_FILTERING_DIALOG"], AL["EXPLORER_FILTERS"],
    AL["EXPLORER_FILTER_COLLECTIONS"], AL["EXPLORER_FILTER_MOUNTS"], AL["EXPLORER_FILTER_TOYS"]) })
Dlg:Register("RS_SCAN", { text = AL["EXPLORER_SCAN_NOT_DONE"] })

-- A settings page: an AceConfig table, read at load.
local function noop() end
S.options = {
    type = "group", name = AL["SOUND"],
    args = {
        show = { type = "toggle", order = 1, name = AL["DISPLAY"], get = noop, set = noop,
            desc = string.format(AL["EXPLORER_FILTERING_DESC"], AL["EXPLORER_FILTERS"], AL["EXPLORER_FILTER_MOUNTS"]) },
        pick = { type = "select", order = 2, name = AL["EXPLORER_FILTERS"], get = noop, set = noop,
            values = { a = AL["EXPLORER_FILTER_TOYS"], b = "Quixwood Vale" } },
    },
}
LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("RareScanner Sound", S.options)

-- Its page in the game's settings list, the way AceConfigDialog:AddToBlizOptions makes it.
local Acd = LibStub:NewLibrary("AceConfigDialog-3.0", 1)
local frame = CreateFrame("Frame")
local cat = Settings.RegisterCanvasLayoutCategory(frame, AL["SOUND"])
local group = { frame = frame, title = AL["SOUND"] }
function group:SetTitle(t) self.title = t end
frame.name = cat.ID
Acd.BlizOptions = { ["RareScanner Sound"] = { ["RareScanner Sound"] = group } }
S.group, S.category = group, cat

-- A page built by a function (like Custom NPCs): built on first use, kept, built again after an import.
local npcs
LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("RareScanner Custom NPCs", function()
    if not npcs or S.refresh then
        S.refresh = nil
        npcs = { type = "group", name = AL["DISPLAY"], args = {
            filter = { type = "toggle", order = 1, name = AL["EXPLORER_FILTERS"], get = noop, set = noop } } }
    end
    return npcs
end)

-- The explorer's icon tooltips, set on load.
local ex = CreateFrame("Frame", "RSExplorerFrame", UIParent)
ex.RareInfo = { Mounts = { Texture = { tooltip = AL["EXPLORER_MOUNTS"] } } }
-- Its other labels, set once, when it first opens (each part's Initialize, guarded).
ex.Filters = { RestartScanningButton = ex:CreateFontString(nil, "OVERLAY", "GameFontNormal") }
ex.Control = { ApplyFiltersButton = {} }
ex.ScanRequired = { ScanRequiredText = ex:CreateFontString(nil, "OVERLAY", "GameFontNormal") }
local initialized
function S.OpenExplorer()
    if not initialized then
        initialized = true
        ex.Filters.RestartScanningButton:SetText(AL["EXPLORER_RESCANN"])
        ex.Control.ApplyFiltersButton.tooltip = string.format(AL["EXPLORER_FILTERING_DESC"], AL["EXPLORER_FILTERS"],
            AL["EXPLORER_FILTER_COLLECTIONS"])
        ex.ScanRequired.ScanRequiredText:SetText(AL["EXPLORER_SCAN_MANUAL"])
    end
    ex:Show()
end
-- On a click it compares the text with the manual-scan line (RSExplorerMixin).
function S.ManualScan() return ex.ScanRequired.ScanRequiredText:GetText() == AL["EXPLORER_SCAN_MANUAL"] end

-- The scanner button and its title.
local button = CreateFrame("Button", "RARESCANNER_BUTTON", UIParent)
button.Title = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
button:Hide()
S.button = button

-- Read each time they show: one with a value slot, one with a game name.
function S.Show(key, ...)
    button:Show()
    button.Title:SetText(select("#", ...) > 0 and string.format(AL[key], ...) or AL[key])
    return button.Title:GetText()
end
function S.Line(key, ...) return string.format(AL[key], ...) end
