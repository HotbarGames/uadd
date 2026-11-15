-- Harness widgets, part 2: methods that only store a value or do nothing visible.
local H = HARNESS
local Widget = H.Widget

-- Pure setters with no effect the addons can observe.
for _, name in ipairs({ "SetMotionScriptsWhileDisabled", "SetPropagateKeyboardInput", "EnableKeyboard",
    "SetVerticalScroll", "SetHorizontalScroll", "UpdateScrollChildRect", "SetOrientation", "SetStatusBarColor",
    "SetObeyStepOnDrag", "SetValueStep", "SetResizable", "SetResizeBounds", "SetMinResize", "SetMaxResize",
    "StartMoving", "StartSizing", "StopMovingOrSizing", "SetUserPlaced", "SetDontSavePosition", "SetIgnoreParentAlpha",
    "SetIgnoreParentScale", "SetScale", "SetFlattensRenderLayers", "SetClipsChildren", "SetShadowColor",
    "SetShadowOffset", "SetSpacing", "SetIndentedWordWrap", "SetTextInsets", "SetHighlightColor", "SetFading",
    "SetFadeDuration", "SetTimeVisible", "SetInsertMode", "SetMaxResize", "SetCountInvisibleLetters",
    "SetHyperlinksEnabled", "SetJustifyH", "SetRotation", "SetSnapToPixelGrid", "SetTexelSnappingBias",
    "SetHorizTile", "SetVertTile", "SetGradient", "SetMask", "AddMaskTexture", "SetStartPoint", "SetEndPoint",
    "SetThickness", "SetFromAlpha", "SetToAlpha", "SetDuration", "SetLooping", "SetOrder", "SetSmoothing",
    "SetStartDelay", "SetOffset", "SetScaleFrom", "SetScaleTo", "SetChange", "SetTarget", "SetChildKey",
    "LockHighlight", "UnlockHighlight", "SetButtonState", "Click", "RegisterForMouse", "SetMouseClickEnabled",
    "SetMouseMotionEnabled", "SetCooldown", "Clear", "SetDrawEdge", "SetDrawSwipe",
    "SetHideCountdownNumbers", "SetReverse", "SetSwipeColor", "SetFrameBuffer", "SetPadding", "SetMinimumWidth",
    "SetAnchorType", "AddTexture", "SetHyperlink", "SetBagItem", "SetInventoryItem", "SetUnit", "SetSpellByID",
    "SetItemByID", "SetQuestLogItem", "SetText_", "FadeOut", "AppendText", "ScrollToBottom", "ScrollToTop",
    "SetBackdropColor", "SetBackdropBorderColor", "ApplyBackdrop", "SetCursor", "SetArrowShown",
    "SetPortraitToAsset", "EnableMouseWheel", "SetCursorPosition", "HighlightText", "SetPortraitTextureRaw", "SetDragTarget" }) do
    if not Widget[name] then Widget[name] = function() end end
end

-- Button textures and font objects: real child regions, so Get* returns what Set* gave.
for _, part in ipairs({ "Normal", "Pushed", "Highlight", "Disabled", "Checked", "DisabledChecked", "Thumb",
    "StatusBar" }) do
    local key = "__tex" .. part
    Widget["Set" .. part .. "Texture"] = function(self, t)
        local tex = rawget(self, key) or self:CreateTexture()
        rawset(self, key, tex)
        if type(t) == "table" then rawset(self, key, t) else tex:SetTexture(t) end
    end
    Widget["Get" .. part .. "Texture"] = function(self)
        local tex = rawget(self, key) or self:CreateTexture()
        rawset(self, key, tex)
        return tex
    end
    Widget["Set" .. part .. "Atlas"] = function(self, a) Widget["Get" .. part .. "Texture"](self):SetAtlas(a) end
end
for _, part in ipairs({ "Normal", "Highlight", "Disabled" }) do
    Widget["Set" .. part .. "FontObject"] = function(self, o) rawset(self, "__font" .. part, o) end
    Widget["Get" .. part .. "FontObject"] = function(self) return rawget(self, "__font" .. part) end
end
function Widget:SetScrollChild(c) rawset(self, "__scrollChild", c) end
function Widget:GetScrollChild() return rawget(self, "__scrollChild") end
function Widget:GetVerticalScroll() return 0 end
function Widget:GetHorizontalScroll() return 0 end
function Widget:GetVerticalScrollRange() return 0 end
function Widget:GetHorizontalScrollRange() return 0 end
function Widget:IsUserPlaced() return false end
function Widget:GetBoundsRect() return 0, 0, self.__w, self.__h end
function Widget:GetRect() return 0, 0, self.__w, self.__h end
function Widget:GetScaledRect() return 0, 0, self.__w, self.__h end
function Widget:IsMouseEnabled() return false end
function Widget:IsMouseMotionFocus() return false end
function Widget:IsDragging() return false end
function Widget:GetButtonState() return "NORMAL" end
function Widget:GetAnimationGroups() return end
function Widget:GetTextWidth() return self:GetStringWidth() end
function Widget:GetPadding() return 0 end
function Widget:GetJustifyH() return "CENTER" end
function Widget:GetJustifyV() return "MIDDLE" end
function Widget:GetSpacing() return 0 end
function Widget:GetShadowColor() return 0, 0, 0, 1 end
function Widget:GetShadowOffset() return 0, 0 end
function Widget:GetCursorPosition() return 0 end
function Widget:GetNumLetters() local t = self:GetText() return t and #t or 0 end
function Widget:GetZoom() return rawget(self, "__zoom") or 0 end
function Widget:SetZoom(z) rawset(self, "__zoom", z) end
function Widget:GetZoomLevels() return 6 end
function Widget:GetPingPosition() return 0, 0 end
function Widget:GetAtlas() return rawget(self, "__atlas") end
function Widget:GetTexCoord() return 0, 1, 0, 1 end
function Widget:GetTextureFilePath() return rawget(self, "__tex") end
function Widget:GetTextureFileID() return 0 end
function Widget:GetDrawLayer() return "ARTWORK", 0 end
function Widget:GetBlendMode() return "BLEND" end
function Widget:IsDesaturated() return false end
function Widget:GetRotation() return 0 end
function Widget:GetHyperlinksEnabled() return false end

TOOLTIP_DEFAULT_COLOR = CreateColor(1, 1, 1)
TOOLTIP_DEFAULT_BACKGROUND_COLOR = CreateColor(0, 0, 0)
C_UIFileAsset = { IsKnownFile = function() return true end }
C_CurrencyInfo = { GetCurrencyInfo = function() return nil end, GetCoinTextureString = function(n) return tostring(n) end,
    GetBasicCurrencyInfo = function() return nil end, GetCurrencyLink = function() return nil end }
for _, name in ipairs({ "SetToFinalAlpha", "SetAlphaFromBoolean" }) do Widget[name] = function() end end
function CloseMenus() end
function Widget:SetAttribute(k, v) local a = rawget(self, "__attr") or {} rawset(self, "__attr", a) a[k] = v end
function Widget:GetAttribute(k) local a = rawget(self, "__attr") return a and a[k] end
function Widget:IsMovable() return rawget(self, "__movable") or false end
function Widget:IsResizable() return false end
function Widget:IsProtected() return false end
function Widget:GetWrappedWidth() return self:GetStringWidth() end
function Widget:SetTextToFit(t) self:SetText(t) end
function Widget:GetValueStep() return 1 end
function Widget:EnableGamePadButton() end
function Widget:GetCanvasScale() return 1 end
function Widget:GetNormalizedCursorPosition() return 0.5, 0.5 end
function Widget:SetPassThroughButtons(...) rawset(self, "__pass", { ... }) end
function Widget:ShouldButtonPassThrough(b)
    for _, x in ipairs(rawget(self, "__pass") or {}) do if x == b then return true end end
    return false
end

-- The guard: shown FontStrings with Ukrainian letters in a font file that has none (the game
-- draws them as squares). The fonts with Ukrainian letters are UADD/Font.lua's list (UADD.IsCyrFont).
-- Returns { "frame font: text", ... }, at most `limit` (default 10).
-- Skipped: text in a top frame nothing ever placed or showed. AceGUI makes its dropdown lists
-- like that (AceGUIWidget-DropDown.lua: SetPoint and Show() come only when the list opens); the
-- game draws no frame without a point, but frames here start shown, so they only look shown.
local function Unplaced(w)
    local top = w
    while top.__parent and top.__parent ~= UIParent do top = top.__parent end
    return top ~= UIParent and #top.__points == 0 and not top.__showed
end

function H.cyrBoxes(limit)
    local out, isCyr = {}, rawget(_G, "UADD") and UADD.IsCyrFont
    if not isCyr then return out end
    for _, w in ipairs(H.widgets()) do
        local t = w.__type == "FontString" and w.__text
        if type(t) == "string" and t:find("[\208\209]") and w:IsVisible() and (w.__alpha or 1) > 0
            and not Unplaced(w) then
            local font = w.__font and w.__font[1]
            if not isCyr(font) and #out < (limit or 10) then
                local p, name = w, nil
                while p and not name do name = p.__name p = p.__parent end
                out[#out + 1] = ("%s %s: %s"):format(name or "?", tostring(font), t:sub(1, 60))
            end
        end
    end
    return out
end
