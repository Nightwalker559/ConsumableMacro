-- ConsumableMacro Options
-- Options window and the minimum-count window (the dialogs are in Dialogs.lua).
local CM = ConsumableMacroAddon

local GITHUB_URL = "https://github.com/Nightwalker559/ConsumableMacro"

-- Section header with a separator line below; returns the y offset under it.
local function AddSection(o, y, title, gap)
    local header = o:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", 14, y)
    header:SetText("|cff00FF98" .. title .. "|r")
    y = y - 22

    local sep = o:CreateTexture(nil, "OVERLAY")
    sep:SetHeight(1); sep:SetPoint("TOPLEFT", 14, y); sep:SetPoint("TOPRIGHT", -14, y)
    sep:SetColorTexture(1, 1, 1, 0.1)
    return y - gap
end

-- ── Options Frame ───────────────────────────────────────────────────────────────
function CM.BuildOptionsFrame()
    if CM.optionsFrame then return CM.optionsFrame end
    local L = CM.L

    local o = CM.CreateWindow("CMOptionsFrame")
    o:SetWidth(320)
    o:SetPoint("LEFT", CM.mainFrame, "RIGHT", 8, 0)
    o.TitleText:SetText(CM.TITLE .. " – " .. L["OPTIONS_TITLE"])
    o:SetScript("OnHide", function()
        CM.CommitOptionsBoxes(true)
        CM.HideSidePanels("catalogFrame")  -- the catalog belongs to the main window: it stays and moves back
        CM.AnchorCatalogFrame()
    end)

    CM.optionsFrame = o

    -- Mouse-wheel scrolling without a scrollbar; all widgets live in `c`.
    local scroll = CreateFrame("ScrollFrame", nil, o)
    scroll:SetPoint("TOPLEFT", 4, -26)
    scroll:SetPoint("BOTTOMRIGHT", -4, 6)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local pos = self:GetVerticalScroll() - delta * 40
        self:SetVerticalScroll(math.max(0, math.min(pos, self:GetVerticalScrollRange())))
    end)
    local c = CreateFrame("Frame", nil, scroll)
    c:SetSize(312, 1)
    scroll:SetScrollChild(c)
    o.scroll = scroll

    local y = -8

    -- Widget values are loaded by CM.RefreshOptionsFrame on every open.
    -- ── General section ──
    y = AddSection(c, y, L["OPTIONS_GENERAL"], 14)

    o.autoUpdateChk = CM.CreateCheckbox(c, L["CHECKBOX_AUTO"], 14, y)
    o.autoUpdateChk:SetScript("OnClick", function(self) CM.db.autoUpdate = self:GetChecked() end)
    y = y - 30

    o.reminderChk = CM.CreateCheckbox(c, L["CHECKBOX_REMINDER"], 14, y)
    o.reminderChk:SetScript("OnClick", function(self) CM.db.showReminder = self:GetChecked() end)
    y = y - 38

    -- ── Min Count section ──
    y = AddSection(c, y, L["OPTIONS_MIN_HEADER"], 10)

    o.minConfigBtn = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    o.minConfigBtn:SetSize(288, 24)
    o.minConfigBtn:SetPoint("TOPLEFT", 14, y)
    o.minConfigBtn:SetText(L["BTN_MINCOUNT_CONFIGURE"])
    o.minConfigBtn:SetScript("OnClick", function() CM.ShowMinCountFrame() end)
    y = y - 38

    -- ── AutoPotion section ──
    if CM.HAS_AUTOPOTION then

        y = AddSection(c, y, L["AUTOPOTION_HEADER"], 10)

        o.apEnableChk = CM.CreateCheckbox(c, L["CHECKBOX_AUTOPOTION_ENABLE"], 14, y)
        o.apEnableChk:SetScript("OnClick", function(self)
            CM.db.autoPotion.enabled = self:GetChecked()
            CM.UpdateAutoPotionMacro()
        end)
        y = y - 28

        o.apStopCastChk = CM.CreateCheckbox(c, L["CHECKBOX_AUTOPOTION_STOPCAST"], 14, y)
        o.apStopCastChk:SetScript("OnClick", function(self)
            CM.db.autoPotion.stopCasting = self:GetChecked()
            CM.UpdateAutoPotionMacro()
        end)
        y = y - 28

        o.apResetDesc = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        o.apResetDesc:SetPoint("TOPLEFT", 14, y)
        o.apResetDesc:SetPoint("TOPRIGHT", -14, y)
        o.apResetDesc:SetJustifyH("LEFT")
        o.apResetDesc:SetWordWrap(true)
        o.apResetDesc:SetText(L["AUTOPOTION_RESET_DESC"])
        o.apResetDesc:SetTextColor(0.65, 0.65, 0.65)
        y = y - 40

        o.apResetLbl = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        o.apResetLbl:SetPoint("TOPLEFT", 14, y)
        o.apResetLbl:SetText(L["LABEL_AUTOPOTION_RESET_SECONDS"])

        o.apResetBox = CreateFrame("EditBox", nil, c, "InputBoxTemplate")
        o.apResetBox:SetSize(50, 22)
        o.apResetBox:SetPoint("LEFT", o.apResetLbl, "LEFT", 150, 0)
        o.apResetBox:SetMaxLetters(3)
        CM.BindNumberBox(o.apResetBox, function(self)
            CM.db.autoPotionResetSeconds = tonumber(self:GetText()) or 0
            CM.UpdateAutoPotionMacro()
        end)

        o.apSyncBtn = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
        o.apSyncBtn:SetSize(50, 22)
        o.apSyncBtn:SetPoint("LEFT", o.apResetBox, "RIGHT", 6, 0)
        o.apSyncBtn:SetText(L["BTN_AUTOPOTION_SYNC"])
        o.apSyncBtn:SetScript("OnClick", function() CM.SyncAutoPotionResetFromCooldown() end)
        CM.AttachTooltip(o.apSyncBtn, L["AUTOPOTION_SYNC_TOOLTIP"])
        y = y - 32

        o.apConfigureBtn = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
        o.apConfigureBtn:SetSize(288, 24)
        o.apConfigureBtn:SetPoint("TOPLEFT", 14, y)
        o.apConfigureBtn:SetText(L["BTN_AUTOPOTION_CONFIGURE"])
        o.apConfigureBtn:SetScript("OnClick", function() CM.ShowAutoPotionFrame() end)
    end

    -- ── Restock section ──
    if CM.HAS_AUTOPOTION then y = y - 38 end

    y = AddSection(c, y, L["RESTOCK_HEADER"], 10)

    o.rsConfigBtn = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    o.rsConfigBtn:SetSize(288, 24)
    o.rsConfigBtn:SetPoint("TOPLEFT", 14, y)
    o.rsConfigBtn:SetText(L["BTN_RESTOCK_CONFIGURE"])
    o.rsConfigBtn:SetScript("OnClick", function() CM.ShowRestockConfigFrame() end)

    -- ── Import / Export section ──
    y = y - 38

    y = AddSection(c, y, L["IE_HEADER"], 10)

    o.ieBox = CreateFrame("EditBox", "CMImportExportBox", c, "InputBoxTemplate")
    o.ieBox:SetSize(288, 22)
    o.ieBox:SetPoint("TOPLEFT", 14, y)
    o.ieBox:SetAutoFocus(false)
    o.ieBox:SetMaxLetters(4000)  -- long export strings must not be truncated
    o.ieBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    o.ieBox:SetScript("OnKeyDown", function(self, key)
        if key == "C" and IsControlKeyDown() then
            -- next frame, so the clipboard is written before the text disappears
            _G.RunNextFrame(function() self:SetText("") end)
        end
    end)
    y = y - 32

    o.exportBtn = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    o.exportBtn:SetSize(135, 24)
    o.exportBtn:SetPoint("TOPLEFT", 14, y)
    o.exportBtn:SetText(L["BTN_EXPORT"])
    o.exportBtn:SetScript("OnClick", function()
        CM.ShowIEFrame("export", nil)
    end)

    o.importBtn = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    o.importBtn:SetSize(135, 24)
    o.importBtn:SetPoint("LEFT", o.exportBtn, "RIGHT", 4, 0)
    o.importBtn:SetText(L["BTN_IMPORT"])
    o.importBtn:SetScript("OnClick", function()
        local parsed = CM.ParseImportString(o.ieBox:GetText())
        if not parsed then
            CM.ShowError(L["IMPORT_INVALID"])
            return
        end
        CM.ShowIEFrame("import", parsed)
    end)

    -- ── Profile section ──
    y = y - 38

    y = AddSection(c, y, L["PROFILE_HEADER"], 10)

    -- Blizzard Menu API; the menu is rebuilt on each open.
    o.profileDD = CreateFrame("DropdownButton", nil, c, "WowStyle1DropdownTemplate")
    o.profileDD:SetPoint("TOPLEFT", 14, y)
    o.profileDD:SetWidth(288)
    o.profileDD:SetupMenu(function(_, root)
        local current = CM.GetProfileName()
        local names   = CM.GetProfileNames()
        for _, name in ipairs(names) do
            root:CreateRadio(name,
                function() return CM.GetProfileName() == name end,
                function() CM.SetProfile(name) end)
        end
        root:CreateDivider()
        root:CreateButton(L["PROFILE_NEW"],    function() CM.ShowProfileDialog("new") end)
        root:CreateButton(L["PROFILE_COPY"],   function() CM.ShowProfileDialog("copy") end)
        root:CreateButton(L["PROFILE_RENAME"], function() CM.ShowProfileDialog("rename") end)
        local del, others = root:CreateButton(L["PROFILE_DELETE"]), 0
        for _, name in ipairs(names) do
            if name ~= current then
                others = others + 1
                del:CreateButton(name, function() CM.ShowProfileDialog("delete", name) end)
            end
        end
        if others == 0 then del:SetEnabled(false) end
    end)

    -- ── Reset section ──
    y = y - 38

    y = AddSection(c, y, L["RESET_HEADER"], 10)

    o.resetBtn = CreateFrame("Button", nil, c, "UIPanelButtonTemplate")
    o.resetBtn:SetSize(288, 24)
    o.resetBtn:SetPoint("TOPLEFT", 14, y)
    o.resetBtn:SetText(L["BTN_RESET"])
    o.resetBtn:SetScript("OnClick", function() CM.ShowResetFrame() end)

    -- ── Feedback section ──
    -- WoW cannot open a browser, so the link sits in a read-only box to copy with Ctrl+C.
    y = y - 38

    y = AddSection(c, y, L["FEEDBACK_HEADER"], 10)

    o.linkBox = CreateFrame("EditBox", nil, c, "InputBoxTemplate")
    o.linkBox:SetSize(288, 22)
    o.linkBox:SetPoint("TOPLEFT", 14, y)
    o.linkBox:SetAutoFocus(false)
    o.linkBox:SetText(GITHUB_URL)
    o.linkBox:SetCursorPosition(0)
    o.linkBox:SetScript("OnTextChanged", function(self, byUser)
        if byUser then self:SetText(GITHUB_URL); self:HighlightText() end
    end)
    o.linkBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    o.linkBox:SetScript("OnMouseUp", function(self) self:SetFocus(); self:HighlightText() end)
    o.linkBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    y = y - 30

    local linkHint = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    linkHint:SetPoint("TOPLEFT", 14, y)
    linkHint:SetPoint("TOPRIGHT", -14, y)
    linkHint:SetJustifyH("LEFT")
    linkHint:SetText(L["FEEDBACK_HINT"])
    linkHint:SetTextColor(0.65, 0.65, 0.65)
    y = y - 12

    -- same height as the main window; the rest scrolls
    c:SetHeight(-y + 24 + 16)
    o:SetHeight(CM.mainFrame:GetHeight())

    return o
end

-- Saves all number boxes into the active profile. Skipped while the frame is
-- hidden (stale boxes) unless forced (OnHide).
function CM.CommitOptionsBoxes(force)
    if not CM.db then return end
    local o, m = CM.optionsFrame, CM.minCountFrame
    if m and (force or m:IsShown()) then
        for key, box in pairs(m.boxes) do
            CM.db[key].minCount = tonumber(box:GetText()) or 0
        end
    end
    if o and o.apResetBox and (force or o:IsShown()) then
        CM.db.autoPotionResetSeconds = tonumber(o.apResetBox:GetText()) or 0
    end
end

-- Loads the active profile's values into all option widgets.
function CM.RefreshOptionsFrame()
    local o = CM.optionsFrame
    if not o or not CM.db then return end
    o.autoUpdateChk:SetChecked(CM.db.autoUpdate)
    o.reminderChk:SetChecked(CM.db.showReminder)
    if CM.HAS_AUTOPOTION then
        o.apEnableChk:SetChecked(CM.db.autoPotion.enabled)
        o.apStopCastChk:SetChecked(CM.db.autoPotion.stopCasting)
        o.apResetBox:SetText(tostring(CM.db.autoPotionResetSeconds or 0))
    end
end

function CM.ToggleOptionsFrame()
    local o = CM.BuildOptionsFrame()
    if o:IsShown() then
        o:Hide()
        return
    end
    CM.RefreshOptionsFrame()
    o.scroll:SetVerticalScroll(0)
    o:Show()
    CM.AnchorCatalogFrame()  -- an open catalog window moves right of Options
    CM.ApplyElvUISkin()
end

-- ── Min Count Frame ────────────────────────────────────────────────────────────
-- Stacks the rows of the tabs this character has and fits the window to them.
function CM.LayoutMinCountRows()
    local m = CM.minCountFrame
    if not m then return end
    local y = -34 - 56  -- below the description
    for _, t in ipairs(CM.TABS) do
        local box = m.boxes[t.key]
        if box then
            local hidden = CM.IsTabHidden(t.key)
            m.labels[t.key]:SetShown(not hidden)
            box:SetShown(not hidden)
            if not hidden then
                m.labels[t.key]:SetPoint("TOPLEFT", 14, y)
                y = y - 30
            end
        end
    end
    m:SetHeight(-y + 12)
end

-- One number box per tab (m.boxes[tabKey]); the reminder warns at or below the value.
function CM.BuildMinCountFrame()
    if CM.minCountFrame then return CM.minCountFrame end
    local L = CM.L

    local m = CM.CreateWindow("CMMinCountFrame")
    m:SetWidth(300)
    m.TitleText:SetText(L["OPTIONS_MIN_HEADER"])
    m:SetScript("OnHide", function() CM.CommitOptionsBoxes(true) end)
    CM.AnchorSidePanel(m)

    local desc = m:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    desc:SetPoint("TOPLEFT", 14, -34)
    desc:SetWidth(272)  -- wraps to up to four lines
    desc:SetText(L["OPTIONS_MIN_DESC"])
    desc:SetTextColor(0.65, 0.65, 0.65)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)

    m.boxes, m.labels = {}, {}
    for _, t in ipairs(CM.TABS) do
        if not CM.MINCOUNT_SKIP[t.key] then
            local lbl = m:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            lbl:SetText((L[t.tabL] or t.key) .. ":")
            lbl:SetTextColor(unpack(t.color))

            local box = CreateFrame("EditBox", nil, m, "InputBoxTemplate")
            box:SetSize(52, 22)
            box:SetPoint("LEFT", lbl, "LEFT", 130, 0)
            box:SetMaxLetters(3)
            box.tabKey = t.key
            CM.BindNumberBox(box, function(self)
                CM.db[self.tabKey].minCount = tonumber(self:GetText()) or 0
            end)
            m.labels[t.key] = lbl
            m.boxes[t.key] = box
        end
    end

    CM.minCountFrame = m
    return m
end

function CM.ShowMinCountFrame()
    local m = CM.BuildMinCountFrame()
    if m:IsShown() then
        m:Hide()
        return
    end
    for key, box in pairs(m.boxes) do
        box:SetText(tostring(CM.db[key] and CM.db[key].minCount or 0))
    end
    CM.LayoutMinCountRows()
    CM.AnchorSidePanel(m)
    CM.HideSidePanels("minCountFrame")
    m:Show()
    CM.ApplyElvUISkin()
end
