-- Harness loading glue: runs one addon file the way the client does (its own environment, the
-- (addonName, ns) varargs), applies XML templates, and saves/restores SavedVariables as text.
local H = HARNESS

H.ns = {}                 -- addon name -> its private namespace table
function H.nsFor(addon) H.ns[addon] = H.ns[addon] or {} return H.ns[addon] end

-- Compiles and runs a file. Returns true when it ran without error.
function H.runFile(addon, path, code)
    local chunk, err = loadstring(code, "@AddOns/" .. addon .. "/" .. path)
    if not chunk then H.report("compile " .. addon .. "/" .. path, err) return false end
    setfenv(chunk, H.envFor(addon))
    return (H.call("load " .. addon .. "/" .. path, chunk, addon, H.nsFor(addon)))
end

-- Inline <Script> text inside an XML file.
function H.runSnippet(addon, where, code)
    local chunk, err = loadstring(code, "@AddOns/" .. addon .. "/" .. where)
    if not chunk then H.report("compile " .. where, err) return false end
    setfenv(chunk, H.envFor(addon))
    return (H.call("xml script " .. where, chunk))
end

-- Templates: BackdropTemplate mixes in the backdrop API; a font object name (CreateFontString
-- with inherits) becomes the FontString's font object, as in the client; others are not modelled.
function H.applyTemplate(w, template)
    local fontObject = type(template) == "string" and rawget(_G, template)
    if type(fontObject) == "table" and rawget(fontObject, "__type") == "Font" then
        w.__fontObject, w.__font = fontObject, { unpack(fontObject.__font) }
    end
    if type(template) == "string" and template:find("BackdropTemplate") then
        for k, v in pairs(BackdropTemplateMixin) do rawset(w, k, v) end
    end
    local name = w:GetName()
    if template == "ScrollFrameTemplate" or template == "UIPanelScrollFrameTemplate" then
        w.ScrollBar = CreateFrame("Slider", name and name .. "ScrollBar", w)
    end
    if template == "PortraitFrameTemplate" then     -- the parts Questie's own options window uses
        w.CloseButton = CreateFrame("Button", nil, w)
        w.PortraitContainer = CreateFrame("Frame", nil, w)
        w.PortraitContainer.portrait = w.PortraitContainer:CreateTexture()
        w.Bg = w:CreateTexture()
        w.SetTitle = function(self, text) self.__title = text end
        w.SetPortraitTextureRaw = function() end
    end
    -- The scroll parts of a Questie 12.8 options tab (QuestieOptionsEngine.lua:204-230).
    if template == "ResizeLayoutFrame" then
        w.SetFixedWidth = function(self, v) self:SetWidth(v) end
        w.Layout, w.MarkDirty = function() end, function() end
    end
    if template == "WowScrollBox" then w.FullUpdate = function() end end
    if template == "MinimalScrollBar" then w:SetWidth(8) end
    if template == "WowStyle1DropdownTemplate" then H.menuDropdown(w) end
    -- A slider's label and end labels (parentKey Text, Low, High), as Questie 12.8's sliders use them.
    if template == "OptionsSliderTemplate" then
        w.Text = w:CreateFontString(name and name .. "Text", "ARTWORK", "GameFontHighlight")
        w.Low = w:CreateFontString(name and name .. "Low", "ARTWORK", "GameFontHighlightSmall")
        w.High = w:CreateFontString(name and name .. "High", "ARTWORK", "GameFontHighlightSmall")
    end
    if template == "UIDropDownMenuTemplate" and name then
        for _, part in ipairs({ "Left", "Middle", "Right", "Icon" }) do w:CreateTexture(name .. part) end
        w:CreateFontString(name .. "Text")
        CreateFrame("Button", name .. "Button", w)
    end
end

-- A named, non-virtual frame declared in XML.
function H.xmlFrame(kind, name, parentName, hidden)
    local parent = parentName and rawget(_G, parentName) or UIParent
    if not H.frameTypes[kind] then kind = "Frame" end
    local f = CreateFrame(kind, name, parent)
    if hidden then f:Hide() end
    return f
end

-- ── SavedVariables ───────────────────────────────────────────────────────────────────────────

local function ser(v, out, seen, depth)
    local t = type(v)
    if t == "string" then out[#out + 1] = string.format("%q", v)
    elseif t == "number" then
        if v ~= v then out[#out + 1] = "0/0" elseif v == math.huge then out[#out + 1] = "math.huge"
        elseif v == -math.huge then out[#out + 1] = "-math.huge" else out[#out + 1] = string.format("%.17g", v) end
    elseif t == "boolean" then out[#out + 1] = tostring(v)
    elseif t == "table" and not seen[v] and depth < 60 and not H.isMagic(v) then
        seen[v] = true
        out[#out + 1] = "{"
        for k, x in pairs(v) do
            local tk = type(k)
            if (tk == "string" or tk == "number" or tk == "boolean") and type(x) ~= "function" and type(x) ~= "userdata" then
                out[#out + 1] = "["
                ser(k, out, seen, depth + 1)
                out[#out + 1] = "]="
                ser(x, out, seen, depth + 1)
                out[#out + 1] = ","
            end
        end
        out[#out + 1] = "}"
        seen[v] = nil
    else out[#out + 1] = "nil" end
end

-- Returns Lua source that restores the given globals, like WTF/.../SavedVariables/<Addon>.lua.
function H.dumpSaved(names)
    local out = {}
    for _, name in ipairs(names) do
        local v = rawget(_G, name)
        if v ~= nil then
            out[#out + 1] = name .. " = "
            ser(v, out, {}, 0)
            out[#out + 1] = "\n"
        end
    end
    return table.concat(out)
end

function H.loadSaved(src, where)
    if not src or src == "" then return true end
    local chunk, err = loadstring(src, "@WTF/" .. where)
    if not chunk then H.report("saved variables " .. where, err) return false end
    return (H.call("saved variables " .. where, chunk))
end

-- Lists globals our files wrote, so the runner can compare with what the TOCs declare.
function H.ourWriteList() local r = {} for k in pairs(H.ourWrites) do r[#r + 1] = tostring(k) end table.sort(r) return r end
function H.listOf(t) local r = {} for k, v in pairs(t) do r[#r + 1] = tostring(k) .. " = " .. tostring(v) end table.sort(r) return r end
function H.errorList() return H.errors end
function H.count(t) local n = 0 if type(t) == "table" then for _ in pairs(t) do n = n + 1 end end return n end
