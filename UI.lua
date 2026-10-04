-- ConsumableMacro UI
-- Main window, list rendering and ElvUI skinning.
local CM = ConsumableMacroAddon

-- ── ElvUI Skin ─────────────────────────────────────────────────────────────────
-- Skins every addon frame that exists so far. Missing frames/handlers are
-- skipped, so it is safe to call at any time (e.g. after a frame was created).
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
    local function scrollbar(name)
        local sb = _G[name]
        if sb and S.HandleScrollBar then S:HandleScrollBar(sb) end
    end
    -- checkbox + button + tab pairs shared by the IE and Reset frames
    local function dialog(f)
        if not f then return end
        frame(f)
        button(f.okBtn); button(f.cancelBtn)
        for _, chk in pairs(f.checkboxes or {}) do check(chk) end
    end

    -- Main window
    frame(mf); frame(mf.scrollBg)
    edit(mf.editBox); edit(mf.dropSkin)
    button(mf.addBtn); button(mf.updateBtn)
    -- optionsBtn intentionally excluded: it is an icon-only button;
    -- HandleButton would cover the texture with ElvUI's backdrop
    for _, b in pairs(mf.tabBtns) do button(b) end
    close(mf.CloseButton)
    scrollbar("CMScrollScrollBar")
    -- Reminder frame: backdrop and okBtn are skinned at creation time in GetReminderFrame.

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
        -- Blizzard DropdownButton (Menu API): skin is best-effort, width kept explicit
        if o.profileDD and S.HandleDropDownBox then pcall(S.HandleDropDownBox, S, o.profileDD, 288) end
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
        for _, row in ipairs(ap.rows or {}) do button(row.upBtn); button(row.downBtn) end
    end

    -- Restock: AH panel + config frame
    frame(CM.restockFrame)
    local rc = CM.restockConfigFrame
    if rc then
        frame(rc); frame(rc.scrollBg)
        check(rc.enableChk); check(rc.bankChk)
        scrollbar("CMRestockScrollScrollBar")
    end

    -- IE selection + Reset frames
    dialog(CM.ieFrame)
    dialog(CM.resetFrame)
end

-- ── RefreshList ────────────────────────────────────────────────────────────────
-- One list row: icon, name, in-bags status and the up / down / delete buttons.
local function CreateRow(i)
    local content = CM.mainFrame.content
    local row = CreateFrame("Frame", nil, content)
    row:SetSize(content:GetWidth(), 32)
    row:SetPoint("TOPLEFT", 5, -(i - 1) * 35)

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
    row.status:SetPoint("RIGHT", -100, 0)

    local function rowButton(action, label, width, anchor, relPoint, x)
        local b = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        b:SetSize(width, 20)
        b:SetText(label)
        b:SetPoint("RIGHT", anchor, relPoint, x, 0)
        b.action = action
        b:SetScript("OnClick", CM.OnRowButtonClick)
        return b
    end
    row.delBtn  = rowButton("delete", "X", 24, row,        "RIGHT", -5)
    row.downBtn = rowButton("down",   "-", 28, row.delBtn, "LEFT",  -3)
    row.upBtn   = rowButton("up",     "+", 28, row.downBtn, "LEFT", -3)

    row:SetScript("OnEnter", function(s) CM.ShowItemTooltip(s, s.itemID) end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local S = CM.GetElvSkins()
    if S and S.HandleButton then
        S:HandleButton(row.delBtn)
        S:HandleButton(row.downBtn)
        S:HandleButton(row.upBtn)
    end
    return row
end

function CM.RefreshList()
    local f = CM.mainFrame
    if not f or not f:IsShown() or not CM.db then return end
    local items = CM.db[CM.activeTab].items
    for _, row in ipairs(CM.rowPool) do row:Hide() end

    local currentTabInfo = nil
    for _, t in ipairs(CM.TABS) do
        local btn = f.tabBtns[t.key]
        if t.key == CM.activeTab then
            currentTabInfo = t
            if btn.Text then btn.Text:SetTextColor(1, 1, 1) end
        else
            if btn.Text then btn.Text:SetTextColor(0.5, 0.5, 0.5) end
        end
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
        row:Show()

        row.icon:SetTexture(CM.GetItemIcon(item.id))
        row.text:SetText((CM.L["ITEM_LABEL"]):format(CM.GetItemDisplayName(item.id), item.id))

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
-- Windows opened from the main window. They close together with it.
local SUB_FRAMES = { "optionsFrame", "ieFrame", "resetFrame", "autoPotionFrame", "restockConfigFrame", "profileFrame" }

function CM.HideSubFrames()
    CM.HideFrames(SUB_FRAMES)
end

function CM.BuildUI()
    if CM.mainFrame then return end
    -- Tab-button layout (margin/width/gap) drives the window width, so adding
    -- a tab to CM.TABS can never make the strip overflow the frame again.
    local TAB_MARGIN, TAB_WIDTH, TAB_GAP = 10, 116, 4
    local windowWidth = TAB_MARGIN * 2 + (#CM.TABS - 1) * (TAB_WIDTH + TAB_GAP) + TAB_WIDTH
    -- Both derived from windowWidth so the whole frame scales together:
    -- content matches the scroll viewport (window margins + scrollbar inset);
    -- the drop-zone box keeps the same right margin the item-ID row has.
    local CONTENT_WIDTH  = windowWidth - 50
    local DROPZONE_WIDTH = windowWidth - 130

    local f = CM.CreateWindow("ConsumableMacroFrame")
    f:SetSize(windowWidth, 485)
    f:SetPoint("CENTER")
    f.TitleText:SetText(CM.TITLE)
    CM.mainFrame = f

    -- Tab buttons
    f.tabBtns = {}
    for i, t in ipairs(CM.TABS) do
        local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        btn:SetSize(TAB_WIDTH, 26)
        btn:SetPoint("TOPLEFT", TAB_MARGIN + (i-1)*(TAB_WIDTH + TAB_GAP), -30)
        btn:SetText(CM.L[t.tabL] or t.key)
        btn.Text = btn:GetFontString()
        btn:SetScript("OnClick", function() CM.activeTab = t.key; CM.RefreshList() end)
        f.tabBtns[t.key] = btn
    end

    -- Info labels
    f.infoLabel  = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.infoLabel:SetPoint("TOPLEFT", 15, -70)
    f.countLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.countLabel:SetPoint("LEFT", f.infoLabel, "RIGHT", 5, 0)
    f.countLabel:SetTextColor(0.5, 0.5, 0.5)
    f.subLabel   = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.subLabel:SetPoint("TOPLEFT", f.infoLabel, "BOTTOMLEFT", 0, -2)
    f.subLabel:SetTextColor(0.6, 0.6, 0.6)

    -- Scroll area
    local scrollBg = CreateFrame("Frame", nil, f, "InsetFrameTemplate")
    scrollBg:SetPoint("TOPLEFT",  10, -110)
    scrollBg:SetPoint("TOPRIGHT", -10, 0)
    scrollBg:SetHeight(190)
    f.scrollBg = scrollBg

    local scroll = CreateFrame("ScrollFrame", "CMScroll", scrollBg, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",     4, -4)
    scroll:SetPoint("BOTTOMRIGHT", -26, 4)

    f.content = CreateFrame("Frame", nil, scroll)
    scroll:SetScrollChild(f.content)
    f.content:SetWidth(CONTENT_WIDTH)
    f.content:SetHeight(1)

    -- ID Input
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
    f.editTip:SetText(CM.L["LABEL_INPUT_TIP"])

    -- Drag & Drop
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

    -- Preview text
    f.previewText = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.previewText:SetPoint("BOTTOMLEFT",  15, 46)
    f.previewText:SetPoint("BOTTOMRIGHT", -15, 46)
    f.previewText:SetHeight(50)
    f.previewText:SetJustifyH("LEFT")

    -- Bottom bar: Update button + Options button
    f.updateBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.updateBtn:SetSize(120, 26)
    f.updateBtn:SetText(CM.L["BTN_UPDATE"])
    f.updateBtn:SetPoint("BOTTOMRIGHT", -12, 12)
    f.updateBtn:SetScript("OnClick", function() CM.UpdateAllMacros() end)

    f.optionsBtn = CreateFrame("Button", nil, f)
    f.optionsBtn:SetSize(26, 26)
    f.optionsBtn:SetPoint("RIGHT", f.updateBtn, "LEFT", -4, 0)
    -- PNG textures are supported natively since Patch 10.0.7; the ".png"
    -- extension must be included explicitly (unlike TGA/BLP).
    local optionsIcon = "Interface\\AddOns\\ConsumableMacro\\Media\\options.png"
    f.optionsBtn:SetNormalTexture(optionsIcon)
    f.optionsBtn:SetHighlightTexture(optionsIcon)
    f.optionsBtn:GetHighlightTexture():SetAlpha(0.6)
    f.optionsBtn:SetPushedTexture(optionsIcon)
    f.optionsBtn:GetPushedTexture():SetVertexColor(0, 1, 0.5)
    f.optionsBtn:SetScript("OnClick", function() CM.ToggleOptionsFrame() end)
    CM.AttachTooltip(f.optionsBtn, CM.L["OPTIONS_TITLE"])

    f:SetScript("OnShow", function() CM.RefreshList(); CM.ApplyElvUISkin() end)
    f:SetScript("OnHide", CM.HideSubFrames)
end
