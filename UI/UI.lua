-- ConsumableMacro UI
-- Main window, list rendering and ElvUI skinning.
local CM = ConsumableMacroAddon

-- ── ElvUI Skin ─────────────────────────────────────────────────────────────────
-- Skins every addon frame that exists so far; missing frames/handlers are skipped,
-- so it is safe to call at any time.
function CM.ApplyElvUISkin()
    local mf = CM.mainFrame
    if not mf then return end
    local S = CM.GetElvSkins()
    if not S then return end

    local function frame(f)  if f and S.HandleFrame       then S:HandleFrame(f)       end end
    local function button(b) if b and S.HandleButton      then S:HandleButton(b)      end end
    local function edit(e)   if e and S.HandleEditBox     then S:HandleEditBox(e)     end end
    local function close(b)  if b and S.HandleCloseButton then S:HandleCloseButton(b) end end
    local function check(c)  CM.SkinCheckbox(S, c) end
    local function scrollbar(scroll)  -- the minimal scrollbar of CM.CreateScrollFrame
        local sb = scroll and scroll.ScrollBar
        if sb and S.HandleTrimScrollBar then S:HandleTrimScrollBar(sb) end
    end
    -- shared by the IE and Reset frames
    local function dialog(f)
        if not f then return end
        frame(f)
        button(f.okBtn); button(f.cancelBtn)
        for _, chk in pairs(f.checkboxes or {}) do check(chk) end
    end

    -- Main window
    frame(mf); frame(mf.scrollBg)
    edit(mf.editBox); edit(mf.dropSkin)
    button(mf.addBtn); button(mf.updateBtn); button(mf.optionsBtn)
    frame(mf.sideBar)
    -- flat selection tint in ElvUI's accent colour instead of Blizzard's list atlases
    local E = _G.ElvUI[1]
    CM.flatTabColor = E.media and E.media.rgbvaluecolor or { 1, 0.82, 0 }
    for _, b in pairs(mf.tabBtns) do CM.SetSideTabSelected(b, b.selected) end
    close(mf.CloseButton)
    scrollbar(mf.scroll)
    -- the reminder frame skins itself when it is created

    -- Options
    local o = CM.optionsFrame
    if o then
        frame(o)
        check(o.autoUpdateChk); check(o.reminderChk)
        for _, box in pairs(o.minBoxes or {}) do edit(box) end
        button(o.exportBtn); button(o.importBtn); edit(o.ieBox)
        button(o.resetBtn)
        check(o.apEnableChk); check(o.apStopCastChk); edit(o.apResetBox)
        button(o.apSyncBtn); button(o.apConfigureBtn)
        button(o.rsConfigBtn)
        -- best-effort, once only: ElvUI adds a new arrow texture on every call
        if o.profileDD and S.HandleDropDownBox and not o.profileDD.cmSkinned then
            o.profileDD.cmSkinned = true
            pcall(S.HandleDropDownBox, S, o.profileDD, 288)
        end
    end

    -- Profile name / delete dialog
    local pf = CM.profileFrame
    if pf then
        frame(pf); edit(pf.editBox)
        button(pf.okBtn); button(pf.altBtn); button(pf.cancelBtn)
    end

    -- AutoPotion priority frame
    local ap = CM.autoPotionFrame
    if ap then
        frame(ap); button(ap.closeBtn)
    end

    -- Restock: AH panel + config frame
    frame(CM.restockFrame)
    local rc = CM.restockConfigFrame
    if rc then
        frame(rc); frame(rc.scrollBg)
        check(rc.enableChk); check(rc.bankChk)
        edit(rc.addBox); button(rc.addBtn)
        scrollbar(rc.scroll)
    end

    -- IE selection + Reset frames
    dialog(CM.ieFrame)
    dialog(CM.resetFrame)
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

-- ── Side Tabs ──────────────────────────────────────────────────────────────────
-- Category list entry in the style of the Blizzard settings list: a bar in the
-- category colour, the label, and a highlight on the selected / hovered entry.
CM.SIDE_TAB_HEIGHT = 26

-- Selection fill: Blizzard's list atlases, or a flat tint once ElvUI skinned the window.
local function StyleSideTabFill(btn, atlas)
    local flat = CM.flatTabColor
    if flat then
        btn.fill:SetColorTexture(flat[1], flat[2], flat[3], atlas == "Options_List_Active" and 0.3 or 0.15)
    else
        btn.fill:SetAtlas(atlas)
    end
end

function CM.CreateSideTab(parent, tabInfo)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetHeight(CM.SIDE_TAB_HEIGHT)

    btn.fill = btn:CreateTexture(nil, "BACKGROUND")
    btn.fill:SetAllPoints()
    btn.fill:Hide()

    btn.bar = btn:CreateTexture(nil, "ARTWORK")
    btn.bar:SetSize(3, 16)
    btn.bar:SetPoint("LEFT", 5, 0)
    btn.bar:SetColorTexture(unpack(tabInfo.color))

    btn.Text = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.Text:SetPoint("LEFT", 14, 0)
    btn.Text:SetPoint("RIGHT", -4, 0)
    btn.Text:SetJustifyH("LEFT")
    btn.Text:SetWordWrap(false)
    btn.Text:SetText(CM.L[tabInfo.tabL] or tabInfo.key)

    btn:SetScript("OnEnter", function(self)
        if self.selected then return end
        StyleSideTabFill(self, "Options_List_Hover")
        self.fill:Show()
    end)
    btn:SetScript("OnLeave", function(self)
        if not self.selected then self.fill:Hide() end
    end)
    return btn
end

function CM.SetSideTabSelected(btn, selected)
    btn.selected = selected
    btn.Text:SetFontObject(selected and "GameFontHighlight" or "GameFontNormal")
    if selected then
        StyleSideTabFill(btn, "Options_List_Active")
        btn.fill:Show()
    else
        btn.fill:Hide()
    end
end

-- ── RefreshList ────────────────────────────────────────────────────────────────
-- One list row: icon, name, in-bags status and the up / down / delete buttons.
local function CreateRow(i)
    local content = CM.mainFrame.content
    local row = CreateFrame("Frame", nil, content)
    row:SetHeight(32)
    row:SetPoint("TOPLEFT",  0, -(i - 1) * 35)
    row:SetPoint("TOPRIGHT", 0, -(i - 1) * 35)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0.2, 0.2, 0.2, 0.4)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(24, 24)
    row.icon:SetPoint("LEFT", 5, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)

    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.status:SetPoint("RIGHT", -80, 0)
    row.status:SetJustifyH("RIGHT")
    row.text:SetPoint("RIGHT", row.status, "LEFT", -6, 0)  -- long names clip instead of overlapping
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)

    local function rowButton(kind, anchor, relPoint, x)
        local b = CM.CreateIconButton(row, kind)
        b:SetPoint("RIGHT", anchor, relPoint, x, 0)
        b.action = kind
        b:SetScript("OnClick", CM.OnRowButtonClick)
        return b
    end
    row.delBtn  = rowButton("delete", row,         "RIGHT", -5)
    row.downBtn = rowButton("down",   row.delBtn,  "LEFT",  -4)
    row.upBtn   = rowButton("up",     row.downBtn, "LEFT",  -4)

    row:SetScript("OnEnter", function(s) CM.ShowItemTooltip(s, s.itemID) end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return row
end

function CM.RefreshList()
    local f = CM.mainFrame
    if not f or not f:IsShown() or not CM.db then return end
    local items = CM.db[CM.activeTab].items
    for _, row in ipairs(CM.rowPool) do row:Hide() end

    local currentTabInfo = nil
    for _, t in ipairs(CM.TABS) do
        local selected = t.key == CM.activeTab
        if selected then currentTabInfo = t end
        CM.SetSideTabSelected(f.tabBtns[t.key], selected)
    end

    if currentTabInfo then
        f.infoLabel:SetText(CM.L[currentTabInfo.info])
        f.infoLabel:SetTextColor(unpack(currentTabInfo.color))
        f.countLabel:SetText("(" .. #items .. ")")
        f.subLabel:SetText(CM.L[currentTabInfo.sub])
    end

    for i, item in ipairs(items) do
        local row = CM.rowPool[i]
        if not row then
            row = CreateRow(i)
            CM.rowPool[i] = row
        end

        row.index  = i
        row.itemID = item.id
        row.upBtn:SetEnabled(i > 1)
        row.downBtn:SetEnabled(i < #items)
        row:Show()

        row.icon:SetTexture(CM.GetItemIcon(item.id))
        row.text:SetText(CM.RankMarkup(item.id) .. (CM.L["ITEM_LABEL"]):format(CM.GetItemDisplayName(item.id), item.id))

        local inBags = CM.IsInBags(item.id)
        row.text:SetTextColor(inBags and 1 or 0.5, inBags and 1 or 0.5, inBags and 1 or 0.5)
        row.status:SetText(inBags and CM.L["IN_BAGS"] or CM.L["NOT_IN_BAGS"])
        row.status:SetTextColor(inBags and 0 or 1, inBags and 1 or 0, 0)
    end

    local body = CM.GetMacroBodyText(CM.activeTab)
    f.previewText:SetText(body ~= "" and body or "...")
    f.content:SetHeight(math.max(1, #items * 35))
    if CM.restockConfigFrame and CM.restockConfigFrame:IsShown() then CM.RefreshRestockConfig() end
end

-- ── BuildUI ────────────────────────────────────────────────────────────────────
-- Options and the windows next to it close together with the main window.
function CM.HideSubFrames()
    CM.HideFrames({ "optionsFrame" })
    CM.HideSidePanels()
end

function CM.BuildUI()
    if CM.mainFrame then return end
    -- Category list on the left, the item list and inputs in the area to its right.
    local MARGIN, SIDEBAR_WIDTH, AREA_WIDTH = 10, 140, 500
    local AREA_LEFT = MARGIN + SIDEBAR_WIDTH + 8
    local windowWidth    = AREA_LEFT + AREA_WIDTH + MARGIN
    local DROPZONE_WIDTH = AREA_WIDTH - 110

    local f = CM.CreateWindow("ConsumableMacroFrame")
    f:SetSize(windowWidth, 485)
    f:SetPoint("CENTER")
    f.TitleText:SetText(CM.TITLE)
    CM.mainFrame = f

    local sideBar = CreateFrame("Frame", nil, f, "InsetFrameTemplate")
    sideBar:SetPoint("TOPLEFT",    MARGIN, -30)
    sideBar:SetPoint("BOTTOMLEFT", MARGIN, 12)
    sideBar:SetWidth(SIDEBAR_WIDTH)
    f.sideBar = sideBar

    f.tabBtns = {}
    for i, t in ipairs(CM.TABS) do
        local btn = CM.CreateSideTab(sideBar, t)
        btn:SetPoint("TOPLEFT",  sideBar, "TOPLEFT",  4, -6 - (i - 1) * (CM.SIDE_TAB_HEIGHT + 2))
        btn:SetPoint("TOPRIGHT", sideBar, "TOPRIGHT", -4, -6 - (i - 1) * (CM.SIDE_TAB_HEIGHT + 2))
        btn:SetScript("OnClick", function() CM.activeTab = t.key; CM.RefreshList() end)
        f.tabBtns[t.key] = btn
    end

    f.infoLabel  = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.infoLabel:SetPoint("TOPLEFT", AREA_LEFT + 5, -36)
    f.countLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.countLabel:SetPoint("LEFT", f.infoLabel, "RIGHT", 5, 0)
    f.countLabel:SetTextColor(0.5, 0.5, 0.5)
    f.subLabel   = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.subLabel:SetPoint("TOPLEFT", f.infoLabel, "BOTTOMLEFT", 0, -2)
    f.subLabel:SetTextColor(0.6, 0.6, 0.6)

    local scrollBg = CreateFrame("Frame", nil, f, "InsetFrameTemplate")
    scrollBg:SetPoint("TOPLEFT", AREA_LEFT, -76)
    scrollBg:SetSize(AREA_WIDTH, 220)
    f.scrollBg = scrollBg

    local scroll = CM.CreateScrollFrame(scrollBg)
    f.scroll = scroll

    f.content = CreateFrame("Frame", nil, scroll)
    f.content:SetHeight(1)
    CM.FitScrollFrame(scroll, scrollBg, f.content, 4)

    -- item ID input
    f.editLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.editLabel:SetPoint("TOPLEFT", scrollBg, "BOTTOMLEFT", 10, -15)
    f.editLabel:SetText(CM.L["LABEL_INPUT_PREFIX"])

    f.editBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    f.editBox:SetSize(120, 24)
    f.editBox:SetPoint("LEFT", f.editLabel, "LEFT", 85, 0)
    f.editBox:SetAutoFocus(false)
    f.editBox:SetNumeric(true)
    f.editBox:SetScript("OnEnterPressed", function(self)
        local id = tonumber(self:GetText())
        if id then CM.AddItemToDatabase(id); self:SetText("") end
        self:ClearFocus()
    end)
    f.editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

    f.addBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.addBtn:SetSize(100, 24)
    f.addBtn:SetText(CM.L["BTN_ADD"])
    f.addBtn:SetPoint("LEFT", f.editBox, "RIGHT", 5, 0)
    f.addBtn:SetScript("OnClick", function()
        local id = tonumber(f.editBox:GetText())
        if id then CM.AddItemToDatabase(id); f.editBox:SetText("") end
    end)

    f.editTip = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.editTip:SetPoint("LEFT", f.addBtn, "RIGHT", 10, 0)
    f.editTip:SetJustifyH("LEFT")
    f.editTip:SetText(CM.L["LABEL_INPUT_TIP"])

    -- drop zone for items dragged from the bags
    f.dropLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.dropLabel:SetPoint("TOPLEFT", f.editLabel, "BOTTOMLEFT", 0, -20)
    f.dropLabel:SetText(CM.L["DROP_ZONE_TITLE"])

    f.dropSkin = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    f.dropSkin:SetSize(DROPZONE_WIDTH, 24)
    f.dropSkin:SetPoint("LEFT", f.dropLabel, "LEFT", 85, 0)
    f.dropSkin:SetEnabled(false)
    f.dropSkin:SetText("")

    f.dropZone = CreateFrame("Frame", nil, f)
    f.dropZone:SetAllPoints(f.dropSkin)
    f.dropZone:SetFrameLevel(f.dropSkin:GetFrameLevel() + 10)
    f.dropZone:EnableMouse(true)

    f.dropText = f.dropZone:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.dropText:SetPoint("CENTER")
    f.dropText:SetText(CM.L["DROP_ZONE_TEXT"])

    f.dropZone:SetScript("OnEnter", function()
        local t, id = GetCursorInfo()
        id = tonumber(id)
        if t == "item" and id then
            local target = CM.GetTargetTabForItem(id)
            if target then
                f.dropText:SetText("|cff00FF00" .. CM.L["DROP_ZONE_TEXT"] .. " (OK)|r")
            else
                f.dropText:SetText("|cffFF0000" .. CM.L["ERROR_INVALID_ITEM"] .. "|r")
            end
        end
    end)
    f.dropZone:SetScript("OnLeave", function()
        f.dropText:SetText(CM.L["DROP_ZONE_TEXT"])
    end)
    local function handleDrop()
        local t, id = GetCursorInfo()
        id = tonumber(id)
        if t == "item" and id then CM.AddItemToDatabase(id); ClearCursor() end
        f.dropText:SetText(CM.L["DROP_ZONE_TEXT"])
    end
    f.dropZone:SetScript("OnReceiveDrag", handleDrop)
    f.dropZone:SetScript("OnMouseDown",   handleDrop)

    -- macro preview
    f.previewText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.previewText:SetPoint("BOTTOMLEFT",  AREA_LEFT + 5, 46)
    f.previewText:SetPoint("BOTTOMRIGHT", -15, 46)
    f.previewText:SetHeight(50)
    f.previewText:SetJustifyH("LEFT")

    f.optionsBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.optionsBtn:SetSize(100, 26)
    f.optionsBtn:SetText(CM.L["OPTIONS_TITLE"])
    f.optionsBtn:SetPoint("BOTTOMRIGHT", -12, 12)
    f.optionsBtn:SetScript("OnClick", function() CM.ToggleOptionsFrame() end)

    f.updateBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.updateBtn:SetSize(120, 26)
    f.updateBtn:SetText(CM.L["BTN_UPDATE"])
    f.updateBtn:SetPoint("RIGHT", f.optionsBtn, "LEFT", -4, 0)
    f.updateBtn:SetScript("OnClick", function() CM.UpdateAllMacros() end)

    f:SetScript("OnShow", function() CM.RefreshList(); CM.ApplyElvUISkin() end)
    f:SetScript("OnHide", CM.HideSubFrames)
end
