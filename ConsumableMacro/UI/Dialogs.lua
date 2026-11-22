-- ConsumableMacro Dialogs
-- Import/export and reset dialogs (one checkbox per tab) and the profile dialog.
local CM = ConsumableMacroAddon

-- ── Tab selection dialogs ─────────────────────────────────────────────────────
-- Dialog with one checkbox per tab plus OK / Cancel: f.descLbl, f.checkboxes[tabKey],
-- f.okBtn, f.cancelBtn.
local function BuildTabDialog(frameName, width, btnWidth)
    local rowH   = 28
    local frameH = 30 + 22 + (#CM.TABS * rowH) + 14 + 24 + 20

    local f = CM.CreateWindow(frameName)
    f:SetSize(width, frameH)
    CM.AnchorSidePanel(f)

    local y = -30

    f.descLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.descLbl:SetPoint("TOPLEFT", 14, y)
    f.descLbl:SetTextColor(0.7, 0.7, 0.7)
    y = y - 22

    f.checkboxes = {}
    for _, t in ipairs(CM.TABS) do
        local chk = CM.CreateCheckbox(f, CM.L[t.tabL] or t.key, 14, y)
        chk.enabledColor = t.color
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

-- Set of ticked (and, if requested, enabled) tab keys; nil if none.
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
-- One tab-selection frame for export and import (see CM.ShowIEFrame).
function CM.BuildIEFrame()
    if CM.ieFrame then return CM.ieFrame end
    CM.ieFrame = BuildTabDialog("CMIEFrame", 250, 110)
    return CM.ieFrame
end

-- Ticks and enables the tabs for which isAvailable(key) is true; greys out the rest.
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

-- mode "export": tabs with items are selectable, OK writes the string.
-- mode "import": tabs present in `parsed` are selectable, OK asks for the target profile.
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
            CM.ShowProfileDialog("import", { parsed = parsed, filter = filter })
        end)
    end

    CM.AnchorSidePanel(f)
    CM.HideSidePanels("ieFrame")
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
        if CM.BlockedByCombat() then return end
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
    CM.AnchorSidePanel(f)
    CM.HideSidePanels("resetFrame")
    f:Show()
    CM.ApplyElvUISkin()
end

-- ── Profile dialog ─────────────────────────────────────────────────────────────
-- One dialog for all profile actions (see CM.ShowProfileDialog).
function CM.BuildProfileFrame()
    if CM.profileFrame then return CM.profileFrame end

    local f = CM.CreateWindow("CMProfileFrame")
    f:SetSize(280, 140)
    CM.AnchorSidePanel(f)

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

    -- import only: apply to the current profile instead of a new one
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

-- Applies a parsed import to the active profile and closes the import window.
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
-- target: profile name (delete) or { parsed, filter } (import).
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
        CM.AnchorSidePanel(f)
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
            -- into a new profile: create, switch, apply
            local name = CM.CreateProfile(text)
            ok = name and CM.SetProfile(name)
            if ok then FinishImport(target) end
        else
            ok = CM.DeleteProfile(target)
        end
        if ok then f:Hide() end
    end)

    -- the import dialog stacks below the import/export window
    if isImp then CM.HideSidePanels("profileFrame", "ieFrame") else CM.HideSidePanels("profileFrame") end
    f:Show()
    if not isDel then
        f.editBox:SetFocus()
        f.editBox:HighlightText()
    end
    CM.ApplyElvUISkin()
end
