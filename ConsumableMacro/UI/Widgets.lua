-- ConsumableMacro Widgets
-- Shared window and control builders: panels, scroll frames, checkboxes, number boxes,
-- icon buttons, tooltips and the side-panel bookkeeping.
local CM = ConsumableMacroAddon

-- Checkbox with a text label to its right, anchored at (x, y) from the top left.
function CM.CreateCheckbox(parent, label, x, y)
    local chk = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    chk:SetSize(24, 24)
    chk:SetPoint("TOPLEFT", x, y)
    chk.text = chk:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    chk.text:SetPoint("LEFT", chk, "RIGHT", 4, 0)
    chk.text:SetText(label)
    return chk
end

-- Item tooltip of `itemID` next to `owner`.
function CM.ShowItemTooltip(owner, itemID, anchor)
    if not itemID then return end
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(itemID)
    GameTooltip:Show()
end

-- Plain-text tooltip while the mouse is over `frame`.
function CM.AttachTooltip(frame, text, anchor)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, anchor or "ANCHOR_RIGHT")
        GameTooltip:SetText(text, nil, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- Hides every shown frame named by a CM.<key>, e.g. { "optionsFrame", "ieFrame" }.
function CM.HideFrames(keys)
    for _, key in ipairs(keys) do
        local f = CM[key]
        if f and f:IsShown() then f:Hide() end
    end
end

-- Windows that open next to Options and would overlap: opening one closes the
-- others, closing Options closes all of them.
local SIDE_PANELS = { "minCountFrame", "ieFrame", "resetFrame", "autoPotionFrame", "restockConfigFrame", "profileFrame" }

-- Hides all side panels except the given keys (e.g. the one about to open).
function CM.HideSidePanels(...)
    local keep = {}
    for _, key in ipairs({ ... }) do keep[key] = true end
    for _, key in ipairs(SIDE_PANELS) do
        local f = CM[key]
        if not keep[key] and f and f:IsShown() then f:Hide() end
    end
end

-- Current Blizzard window frame (the one Settings and Click Bindings use): flat
-- nine-slice border, no portrait, plus a close button. f.TitleText is the title.
function CM.CreatePanel(name)
    local f = CreateFrame("Frame", name, UIParent, "DefaultPanelTemplate")
    f.CloseButton = CreateFrame("Button", nil, f, "UIPanelCloseButtonDefaultAnchors")
    f.TitleText   = f.TitleContainer.TitleText
    return f
end

-- Scroll frame with the current minimal scrollbar (hidden while nothing scrolls),
-- reachable as scroll.ScrollBar. The caller sets anchors and the scroll child.
function CM.CreateScrollFrame(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent, "ScrollFrameTemplate")
    scroll.ScrollBar:SetHideIfUnscrollable(true)
    return scroll
end

-- Fills `parent` with the scroll frame (`inset` px from the edges) and makes
-- `child` as wide as the scroll area. The scrollbar only takes its 26 px while it
-- is shown, so the list reaches the edge when nothing scrolls.
function CM.FitScrollFrame(scroll, parent, child, inset)
    local bar = scroll.ScrollBar
    local function fit()
        scroll:ClearAllPoints()
        scroll:SetPoint("TOPLEFT",     parent, "TOPLEFT",      inset,  -inset)
        scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", bar:IsShown() and -26 or -inset, inset)
    end
    bar:HookScript("OnShow", fit)
    bar:HookScript("OnHide", fit)
    scroll:HookScript("OnSizeChanged", function(_, width) child:SetWidth(width) end)
    scroll:SetScrollChild(child)
    fit()
end

-- Movable, hidden window that closes on Escape. The caller sets size, anchor and title.
function CM.CreateWindow(name)
    local f = CM.CreatePanel(name)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:SetFrameStrata(CM.FRAME_STRATA)
    f:Hide()
    tinsert(_G.UISpecialFrames, name)
    return f
end

-- Dark background texture of a list row.
function CM.AddRowBackground(row)
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0.2, 0.2, 0.2, 0.4)
end

-- Numeric edit box that calls onSave(box) when it loses focus (Enter/Escape drop the focus).
function CM.BindNumberBox(box, onSave)
    box:SetAutoFocus(false)
    box:SetNumeric(true)
    box:SetScript("OnEnterPressed",  box.ClearFocus)
    box:SetScript("OnEscapePressed", box.ClearFocus)
    box:SetScript("OnEditFocusLost", onSave)
end

-- ── Icon Buttons ───────────────────────────────────────────────────────────────
-- Icon-only buttons (no ElvUI skin needed). The white icon files are tinted;
-- `size` is the drawn size of the 64x64 file and may exceed the 20x20 button.
-- A disabled button greys out. The caller sets position and OnClick.
local ICON_PATH = "Interface\\AddOns\\ConsumableMacro\\Media\\"
local GOLD, RED = { 1, 0.82, 0 }, { 0.9, 0.15, 0.15 }
local ICON_KINDS = {
    up     = { file = "up.png",     tint = GOLD, size = 32 },
    down   = { file = "down.png",   tint = GOLD, size = 32 },
    delete = { file = "remove.png", tint = RED,  size = 20 },
}

function CM.CreateIconButton(parent, kind)
    local k = ICON_KINDS[kind]
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(20, 20)
    b:SetNormalTexture(ICON_PATH .. k.file)
    b:SetHighlightTexture(ICON_PATH .. k.file, "ADD")
    local normal, glow = b:GetNormalTexture(), b:GetHighlightTexture()
    for _, t in ipairs({ normal, glow }) do
        t:ClearAllPoints()
        t:SetPoint("CENTER")
        t:SetSize(k.size, k.size)
        t:SetVertexColor(k.tint[1], k.tint[2], k.tint[3])
    end
    glow:SetAlpha(0.35)
    b:SetScript("OnMouseDown", function() normal:SetAlpha(0.6) end)
    b:SetScript("OnMouseUp",   function() normal:SetAlpha(1) end)
    b:SetScript("OnDisable", function() normal:SetDesaturated(true); normal:SetAlpha(0.3); glow:SetAlpha(0) end)
    b:SetScript("OnEnable",  function() normal:SetDesaturated(false); normal:SetAlpha(1); glow:SetAlpha(0.35) end)
    return b
end
