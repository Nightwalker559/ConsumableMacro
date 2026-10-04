-- ConsumableMacro Options
-- Options window, import/export selection frame and reset frame.
local CM = ConsumableMacroAddon

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

local OPTIONS_MAX_H = 520  -- visible height of the options window; the rest scrolls

-- ── Options Frame ───────────────────────────────────────────────────────────────
function CM.BuildOptionsFrame()
    if CM.optionsFrame then return CM.optionsFrame end
    local L = CM.L

    local o = CM.CreateWindow("CMOptionsFrame")
    o:SetWidth(320)
    o:SetPoint("LEFT", CM.mainFrame, "RIGHT", 8, 0)
    o.TitleText:SetText(CM.TITLE .. " – " .. L["OPTIONS_TITLE"])
    o:SetScript("OnHide", function() CM.CommitOptionsBoxes(true) end)

    CM.optionsFrame = o

    -- Invisible scrolling: mouse wheel only, no scrollbar. All widgets live in `c`.
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

    -- ── General section ──
    y = AddSection(c, y, L["OPTIONS_GENERAL"], 14)

    -- Auto-Update checkbox
    o.autoUpdateChk = CM.CreateCheckbox(c, L["CHECKBOX_AUTO"], 14, y)
    o.autoUpdateChk:SetChecked(CM.db and CM.db.autoUpdate)
    o.autoUpdateChk:SetScript("OnClick", function(self) CM.db.autoUpdate = self:GetChecked() end)
    y = y - 30

    -- Reminder checkbox
    o.reminderChk = CM.CreateCheckbox(c, L["CHECKBOX_REMINDER"], 14, y)
    o.reminderChk:SetChecked(CM.db and CM.db.showReminder)
    o.reminderChk:SetScript("OnClick", function(self) CM.db.showReminder = self:GetChecked() end)
    y = y - 38

    -- ── Min Count section ──
    y = AddSection(c, y, L["OPTIONS_MIN_HEADER"], 8)

    local desc = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    desc:SetPoint("TOPLEFT", 14, y)
    desc:SetPoint("TOPRIGHT", -14, y)
    desc:SetText(L["OPTIONS_MIN_DESC"])
    desc:SetTextColor(0.65, 0.65, 0.65)
    desc:SetJustifyH("LEFT")
    desc:SetWordWrap(true)
    y = y - 36

    o.minBoxes = {}
    for _, t in ipairs(CM.TABS) do
        if not CM.MINCOUNT_SKIP[t.key] then
            local lbl = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            lbl:SetPoint("TOPLEFT", 14, y)
            lbl:SetText((L[t.tabL] or t.key) .. ":")
            lbl:SetTextColor(unpack(t.color))

            local box = CreateFrame("EditBox", nil, c, "InputBoxTemplate")
            box:SetSize(52, 22)
            box:SetPoint("LEFT", lbl, "LEFT", 130, 0)
            box:SetMaxLetters(3)
            box.tabKey = t.key
            CM.BindNumberBox(box, function(self)
                CM.db[self.tabKey].minCount = tonumber(self:GetText()) or 0
            end)
            o.minBoxes[t.key] = box
            y = y - 30
        end
    end

    -- ── AutoPotion section ──
    y = y - 10

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

    -- ── Restock section ──
    y = y - 38

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
            -- clear on next frame so clipboard is written before the text disappears
            _G.C_Timer.After(0, function() self:SetText("") end)
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

    -- Blizzard Menu API (DropdownButton + SetupMenu); the menu is rebuilt on each open.
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

    -- Fit the frame to the content, capped to the screen; the rest scrolls.
    local contentH = -y + 24 + 16
    c:SetHeight(contentH)
    o:SetHeight(math.min(contentH + 34, OPTIONS_MAX_H, math.floor(_G.UIParent:GetHeight() * 0.85)))

    return o
end

-- Writes the text of all number boxes into the active profile. Skipped while the
-- frame is hidden (boxes are stale/empty) unless force is set (OnHide).
function CM.CommitOptionsBoxes(force)
    local o = CM.optionsFrame
    if not o or not CM.db or not o.minBoxes then return end
    if not force and not o:IsShown() then return end
    for key, box in pairs(o.minBoxes) do
        CM.db[key].minCount = tonumber(box:GetText()) or 0
    end
    if o.apResetBox then
        CM.db.autoPotionResetSeconds = tonumber(o.apResetBox:GetText()) or 0
    end
end

-- Loads the active profile's values into all option widgets.
function CM.RefreshOptionsFrame()
    local o = CM.optionsFrame
    if not o or not CM.db then return end
    o.autoUpdateChk:SetChecked(CM.db.autoUpdate)
    o.reminderChk:SetChecked(CM.db.showReminder)
    for key, box in pairs(o.minBoxes) do
        box:SetText(tostring(CM.db[key] and CM.db[key].minCount or 0))
    end
    o.apEnableChk:SetChecked(CM.db.autoPotion.enabled)
    o.apStopCastChk:SetChecked(CM.db.autoPotion.stopCasting)
    o.apResetBox:SetText(tostring(CM.db.autoPotionResetSeconds or 0))
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
    CM.ApplyElvUISkin()
end

-- Dialogs open right of the Options window, or of the main window if Options isn't open.
local function AnchorDialog(f)
    local o = CM.optionsFrame
    f:ClearAllPoints()
    f:SetPoint("LEFT", (o and o:IsShown()) and o or CM.mainFrame, "RIGHT", 8, 0)
end

-- ── Tab selection dialogs ─────────────────────────────────────────────────────
-- Small movable dialog with one checkbox per tab plus OK / Cancel buttons.
-- Returns the frame with f.descLbl, f.checkboxes[tabKey], f.okBtn, f.cancelBtn.
local function BuildTabDialog(frameName, width, btnWidth)
    local rowH   = 28
    local frameH = 30 + 22 + (#CM.TABS * rowH) + 14 + 24 + 20

    local f = CM.CreateWindow(frameName)
    f:SetSize(width, frameH)
    AnchorDialog(f)

    local y = -30

    f.descLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.descLbl:SetPoint("TOPLEFT", 14, y)
    f.descLbl:SetTextColor(0.7, 0.7, 0.7)
    y = y - 22

    f.checkboxes = {}
    for _, t in ipairs(CM.TABS) do
        local chk = CM.CreateCheckbox(f, CM.L[t.tabL] or t.key, 14, y)
        chk.enabledColor = t.color  -- used when (re)coloring the label on show
        f.checkboxes[t.key] = chk
        y = y - rowH
    end

    y = y - 14

    f.okBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.okBtn:SetSize(btnWidth, 24)
    f.okBtn:SetPoint("TOPLEFT", 14, y)

    f.cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.cancelBtn:SetSize(btnWidth, 24)
    f.cancelBtn:SetPoint("LEFT", f.okBtn, "RIGHT", 4, 0)
    f.cancelBtn:SetText(CANCEL)
    f.cancelBtn:SetScript("OnClick", function() f:Hide() end)

    return f
end

-- Set of tab keys whose checkbox is ticked (and enabled, if requested);
-- nil if none.
local function GetCheckedTabs(f, requireEnabled)
    local filter, any = {}, false
    for key, chk in pairs(f.checkboxes) do
        if chk:GetChecked() and (not requireEnabled or chk:IsEnabled()) then
            filter[key] = true
            any = true
        end
    end
    return any and filter or nil
end

-- ── IE Selection Frame ─────────────────────────────────────────────────────────
-- Shared frame for both Export and Import tab selection.
-- mode = "export": checkboxes enabled for tabs with items; OK generates string.
-- mode = "import": checkboxes enabled for tabs present in parsed; OK applies import.

function CM.BuildIEFrame()
    if CM.ieFrame then return CM.ieFrame end
    CM.ieFrame = BuildTabDialog("CMIEFrame", 250, 110)
    return CM.ieFrame
end

-- Ticks and enables the checkbox of every tab for which isAvailable(key) is true;
-- the others are greyed out.
local function SetAvailableTabs(f, isAvailable)
    for _, t in ipairs(CM.TABS) do
        local chk     = f.checkboxes[t.key]
        local enabled = isAvailable(t.key) and true or false
        chk:SetEnabled(enabled)
        chk:SetChecked(enabled)
        if enabled then
            chk.text:SetTextColor(unpack(chk.enabledColor))
        else
            chk.text:SetTextColor(0.4, 0.4, 0.4)
        end
    end
end

-- mode: "export" or "import". parsed: only required for "import".
function CM.ShowIEFrame(mode, parsed)
    local f  = CM.BuildIEFrame()
    local L  = CM.L

    local function getFilter()
        local filter = GetCheckedTabs(f, true)
        if not filter then CM.ShowError(L["IE_NONE_SELECTED"]) end
        return filter
    end

    if mode == "export" then
        f.TitleText:SetText(L["BTN_EXPORT"])
        f.descLbl:SetText(L["IE_EXPORT_DESC"])

        SetAvailableTabs(f, function(key)
            local tab = CM.db and CM.db[key]
            return tab and #tab.items > 0
        end)

        f.okBtn:SetText(L["BTN_EXPORT"])
        f.okBtn:SetScript("OnClick", function()
            local filter = getFilter()
            if not filter then return end
            local str = CM.ExportString(filter)
            local box = _G["CMImportExportBox"]
            if box then
                box:SetText(str)
                box:SetFocus()
                box:HighlightText()
            end
            f:Hide()
        end)

    elseif mode == "import" then
        f.TitleText:SetText(L["BTN_IMPORT"])
        f.descLbl:SetText(L["IE_IMPORT_DESC"])

        SetAvailableTabs(f, function(key) return parsed[key] ~= nil end)

        f.okBtn:SetText(L["BTN_IMPORT"])
        f.okBtn:SetScript("OnClick", function()
            local filter = getFilter()
            if not filter then return end
            -- ask: new profile or current profile (dialog stays below this frame)
            CM.ShowProfileDialog("import", { parsed = parsed, filter = filter })
        end)
    end

    AnchorDialog(f)
    f:Show()
    CM.ApplyElvUISkin()
end

-- ── Reset Frame ────────────────────────────────────────────────────────────────
function CM.BuildResetFrame()
    if CM.resetFrame then return CM.resetFrame end
    local L = CM.L

    local f = BuildTabDialog("CMResetFrame", 240, 100)
    f.TitleText:SetText(L["RESET_TITLE"])
    f.descLbl:SetText(L["RESET_DESC"])
    for _, t in ipairs(CM.TABS) do
        local chk = f.checkboxes[t.key]
        chk.text:SetTextColor(unpack(t.color))
        chk:SetChecked(true)
    end

    f.okBtn:SetText(OKAY)
    f.okBtn:SetScript("OnClick", function()
        if not CM.db then f:Hide(); return end
        if InCombatLockdown() then CM.ShowError(L["ERR_COMBAT"]); return end
        local filter = GetCheckedTabs(f)
        if not filter then
            CM.ShowError(L["RESET_NONE_SELECTED"])
            return
        end
        CM.ClearTabs(filter)
        f:Hide()
    end)

    CM.resetFrame = f
    return f
end

function CM.ShowResetFrame()
    local f = CM.BuildResetFrame()
    for _, chk in pairs(f.checkboxes) do
        chk:SetChecked(true)
    end
    AnchorDialog(f)
    f:Show()
    CM.ApplyElvUISkin()
end

-- ── Profile dialog ─────────────────────────────────────────────────────────────
-- One small dialog for all profile actions: new / copy / rename (name input)
-- and delete (confirmation, `target` = profile to delete).
function CM.BuildProfileFrame()
    if CM.profileFrame then return CM.profileFrame end

    local f = CM.CreateWindow("CMProfileFrame")
    f:SetSize(280, 140)
    AnchorDialog(f)

    f.descLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.descLbl:SetPoint("TOPLEFT", 14, -34)
    f.descLbl:SetPoint("TOPRIGHT", -14, -34)
    f.descLbl:SetJustifyH("LEFT")
    f.descLbl:SetWordWrap(true)
    f.descLbl:SetTextColor(0.7, 0.7, 0.7)

    f.editBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    f.editBox:SetSize(240, 22)
    f.editBox:SetPoint("TOPLEFT", 20, -74)
    f.editBox:SetAutoFocus(false)
    f.editBox:SetMaxLetters(40)
    f.editBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    f.editBox:SetScript("OnEnterPressed", function() f.okBtn:Click() end)

    f.okBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.okBtn:SetSize(120, 24)
    f.okBtn:SetPoint("BOTTOMLEFT", 14, 14)

    -- import mode only: apply to the current profile instead of a new one
    f.altBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.altBtn:SetSize(88, 24)
    f.altBtn:SetPoint("LEFT", f.okBtn, "RIGHT", 4, 0)
    f.altBtn:Hide()

    f.cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.cancelBtn:SetSize(120, 24)
    f.cancelBtn:SetPoint("LEFT", f.okBtn, "RIGHT", 4, 0)
    f.cancelBtn:SetText(CANCEL)
    f.cancelBtn:SetScript("OnClick", function() f:Hide() end)

    CM.profileFrame = f
    return f
end

-- Applies a parsed import to the active profile and closes the import windows.
local function FinishImport(job)
    CM.ApplyImport(job.parsed, job.filter)
    local box = _G["CMImportExportBox"]
    if box then box:SetText("") end
    if CM.ieFrame then CM.ieFrame:Hide() end
end

-- Unused profile name for an import ("Import", "Import 2", ...).
local function FreeImportName()
    local base, name, n = CM.L["PROFILE_IMPORT_NAME"], nil, 1
    repeat
        name = n == 1 and base or (base .. " " .. n)
        n = n + 1
    until not ConsumableMacroDB.profiles[name]
    return name
end

-- mode: "new" | "copy" | "rename" | "delete" | "import"
-- target: profile to delete (delete) or { parsed, filter } (import).
function CM.ShowProfileDialog(mode, target)
    local f       = CM.BuildProfileFrame()
    local L       = CM.L
    local current = CM.GetProfileName() or ""
    local isDel   = mode == "delete"
    local isImp   = mode == "import"

    f.editBox:SetShown(not isDel)
    f:SetSize(isImp and 300 or 280, isDel and 110 or 140)
    f.okBtn:SetText(isDel and L["PROFILE_DELETE"] or isImp and L["PROFILE_IMPORT_NEW"] or OKAY)
    f.okBtn:SetWidth(isImp and 88 or 120)
    f.cancelBtn:SetWidth(isImp and 88 or 120)
    f.altBtn:SetShown(isImp)
    f.altBtn:SetText(L["PROFILE_IMPORT_CURRENT"])
    f.cancelBtn:ClearAllPoints()
    f.cancelBtn:SetPoint("LEFT", isImp and f.altBtn or f.okBtn, "RIGHT", 4, 0)

    f:ClearAllPoints()
    if isImp and CM.ieFrame then
        f:SetPoint("TOPLEFT", CM.ieFrame, "BOTTOMLEFT", 0, -6)
    else
        AnchorDialog(f)
    end

    if isImp then
        f.TitleText:SetText(L["BTN_IMPORT"])
        f.descLbl:SetText(L["PROFILE_IMPORT_DESC"])
        f.editBox:SetText(FreeImportName())
        f.altBtn:SetScript("OnClick", function()
            FinishImport(target)
            f:Hide()
        end)
    elseif isDel then
        f.TitleText:SetText(L["PROFILE_DELETE"])
        f.descLbl:SetText((L["PROFILE_DELETE_CONFIRM"]):format(target or ""))
    else
        local titles = { new = "PROFILE_NEW", copy = "PROFILE_COPY", rename = "PROFILE_RENAME" }
        f.TitleText:SetText(L[titles[mode]])
        f.descLbl:SetText(L["PROFILE_NAME_DESC"])
        if mode == "copy" then
            f.editBox:SetText((L["PROFILE_COPY_NAME"]):format(current))
        elseif mode == "rename" then
            f.editBox:SetText(current)
        else
            f.editBox:SetText("")
        end
    end

    f.okBtn:SetScript("OnClick", function()
        local text = f.editBox:GetText()
        local ok
        if mode == "new" or mode == "copy" then
            local name = CM.CreateProfile(text, mode == "copy" and current or nil)
            ok = name and CM.SetProfile(name)
        elseif mode == "rename" then
            ok = CM.RenameProfile(current, text)
        elseif mode == "import" then
            -- new (empty) profile, switch to it, then apply the import there
            local name = CM.CreateProfile(text)
            ok = name and CM.SetProfile(name)
            if ok then FinishImport(target) end
        else
            ok = CM.DeleteProfile(target)
        end
        if ok then f:Hide() end
    end)

    f:Show()
    if not isDel then
        f.editBox:SetFocus()
        f.editBox:HighlightText()
    end
    CM.ApplyElvUISkin()
end
