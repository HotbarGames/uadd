-- Harness keyboard focus, as in the client: an EditBox has autoFocus on unless told otherwise, and one that
-- is made or shown with it on takes the keyboard (after the code that made it ran, so a SetAutoFocus(false)
-- right after CreateFrame still counts). ClearFocus, or hiding it, gives the keyboard back.
-- GetCurrentKeyBoardFocus() says who has it: nil when nobody types (the game then takes Enter for chat).
local H = HARNESS
local Widget = H.Widget

H.focus = nil
local pending = {}       -- EditBoxes made or shown since the last look, in that order

local function Resolve()
    local list = pending
    pending = {}
    for _, w in ipairs(list) do
        if w.__autoFocus and w:IsVisible() then H.focus = w end
    end
    if H.focus and not H.focus:IsVisible() then H.focus = nil end
    return H.focus
end
H.resolveFocus = Resolve

local function Drop(self)
    for i = #pending, 1, -1 do if pending[i] == self then table.remove(pending, i) end end
end

function Widget:SetAutoFocus(v) self.__autoFocus = v and true or false end
function Widget:IsAutoFocus() return self.__autoFocus == true end
function Widget:SetFocus() Resolve() H.focus = self end
function Widget:ClearFocus() Drop(self) if H.focus == self then H.focus = nil end end
function Widget:HasFocus() return Resolve() == self end

local show, hide = Widget.Show, Widget.Hide
function Widget:Show()
    show(self)
    if self.__type == "EditBox" then pending[#pending + 1] = self end
end
function Widget:Hide()
    hide(self)
    Drop(self)
    if H.focus and not H.focus:IsVisible() then H.focus = nil end
end

local create = CreateFrame
function CreateFrame(...)
    local f = create(...)
    if f.__type == "EditBox" then
        f.__autoFocus = true
        pending[#pending + 1] = f
    end
    return f
end

function GetCurrentKeyBoardFocus() return Resolve() end
