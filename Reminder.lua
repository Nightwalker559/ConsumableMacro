-- ConsumableMacro Reminder
local CM = ConsumableMacroAddon

-- ── Timer ──────────────────────────────────────────────────────────────────────
local TIMER_DURATION  = 60
local lastShownSecond = -1
local function StopTimer()
    if CM.reminderFrame and CM.reminderFrame.bar then
        CM.reminderFrame.bar:SetScript("OnUpdate", nil)
    end
    lastShownSecond = -1
end
local function StartTimer()
    StopTimer()
    local elapsed = 0
    local bar     = CM.reminderFrame.bar
    local barText = CM.reminderFrame.barText
    bar:SetMinMaxValues(0, TIMER_DURATION)
    bar:SetValue(TIMER_DURATION)
    lastShownSecond = TIMER_DURATION
    barText:SetText(TIMER_DURATION)
    bar:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        local remaining = TIMER_DURATION - elapsed
        if remaining <= 0 then
            StopTimer()
            CM.reminderFrame:Hide()
            return
        end
        bar:SetValue(remaining)
        local ceiled = math.ceil(remaining)
        if ceiled ~= lastShownSecond then
            lastShownSecond = ceiled
            barText:SetText(ceiled)
        end
    end)
end
-- ── Reminder Frame ─────────────────────────────────────────────────────────────
CM.reminderFrame = nil

-- Resize to fit content (header + sep + label + body + hint + button + bar).
function CM.FitReminderHeight(rf)
    local bodyH = rf.body:GetStringHeight()
    local hintH = rf.hint:GetStringHeight()
    local extra = hintH > 0 and (hintH + 6) or 0
    rf:SetHeight(math.max(130, 12 + 28 + 10 + 18 + 10 + math.max(bodyH, 16) + extra + 14 + 22 + 8 + 14))
end

-- Fills label, body and setup-hint lines.
function CM.FillReminder(rf, bodyParts, unconfigured)
    rf.label:SetText(CM.L["REMINDER_MISSING"])
    rf.body:SetText(table.concat(bodyParts, "  ·  "))
    rf.hint:SetText((unconfigured or 0) > 0 and CM.L["REMINDER_SETUP_HINT"] or "")
end

function CM.GetReminderFrame()
    if CM.reminderFrame then return CM.reminderFrame end
    local S = CM.GetElvSkins()
    local f = CreateFrame("Frame", "CMReminderFrame", UIParent, "BackdropTemplate")
    f:SetSize(420, 130)
    f:SetPoint("TOP", UIParent, "TOP", 0, -200)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        if CM.charDb then
            local point, _, relPoint, x, y = self:GetPoint()
            CM.charDb.reminderPos = { point = point, relPoint = relPoint, x = x, y = y }
        end
    end)
    f:Hide()
    tinsert(UISpecialFrames, "CMReminderFrame")
    -- Backdrop: ElvUI handles its own, default UI gets Blizzard style
    if S and S.HandleFrame then
        S:HandleFrame(f)
    else
        f:SetBackdrop({
            bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        f:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
        f:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    end
    -- Header
    f.header = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.header:SetPoint("TOPLEFT", 14, -12)
    f.header:SetText(CM.TITLE)
    f.header:SetShadowOffset(1, -1)
    f.header:SetShadowColor(0, 0, 0, 1)
    -- Separator
    f.sep = f:CreateTexture(nil, "ARTWORK")
    f.sep:SetHeight(1)
    f.sep:SetPoint("TOPLEFT",  f, "TOPLEFT",  10, -38)
    f.sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -38)
    f.sep:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    -- Label
    f.label = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.label:SetPoint("TOPLEFT", 14, -48)
    f.label:SetTextColor(0.9, 0.9, 0.9)
    f.label:SetShadowOffset(1, -1)
    f.label:SetShadowColor(0, 0, 0, 1)
    -- Body
    f.body = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.body:SetPoint("TOPLEFT",  14, -66)
    f.body:SetPoint("TOPRIGHT", -14, -66)
    f.body:SetJustifyH("LEFT")
    f.body:SetWordWrap(true)
    f.body:SetShadowOffset(1, -1)
    f.body:SetShadowColor(0, 0, 0, 1)
    -- Setup hint line (shown when unconfigured tabs exist)
    f.hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.hint:SetPoint("TOPLEFT",  f.body, "BOTTOMLEFT",  0, -6)
    f.hint:SetPoint("TOPRIGHT", f.body, "BOTTOMRIGHT", 0, -6)
    f.hint:SetJustifyH("LEFT")
    f.hint:SetWordWrap(true)
    -- Okay button — skin first so OnClick is never overridden by ElvUI
    f.okBtn = CreateFrame("Button", "CMReminderOkay", f, "UIPanelButtonTemplate")
    f.okBtn:SetSize(80, 22)
    f.okBtn:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 18)
    if S and S.HandleButton then S:HandleButton(f.okBtn) end
    f.okBtn:SetText(_G.OKAY)
    f.okBtn:SetScript("OnClick", function()
        StopTimer()
        f:Hide()
    end)
    -- Countdown bar (gold, BigWigs style)
    local bar = CreateFrame("StatusBar", "CMReminderBar", f)
    bar:SetPoint("BOTTOMLEFT",  f, "BOTTOMLEFT",  8, 6)
    bar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 6)
    bar:SetHeight(8)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.8, 0.7, 0.1, 0.9)
    local barBg = bar:CreateTexture(nil, "BACKGROUND")
    barBg:SetAllPoints(bar)
    barBg:SetTexture("Interface\\TargetingFrame\\UI-StatusBar")
    barBg:SetVertexColor(0.1, 0.1, 0.1, 0.8)
    f.barText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.barText:SetPoint("RIGHT", bar, "RIGHT", -2, 0)
    f.barText:SetTextColor(1, 1, 1, 0.9)
    if S and S.HandleStatusBar then
        S:HandleStatusBar(bar)
        bar:SetStatusBarColor(0.8, 0.7, 0.1, 0.9)
    end
    f.bar = bar
    f:SetScript("OnShow", function(self)
        -- Restore saved position
        if CM.charDb and CM.charDb.reminderPos then
            local p = CM.charDb.reminderPos
            self:ClearAllPoints()
            self:SetPoint(p.point, UIParent, p.relPoint, p.x, p.y)
        end
        CM.FitReminderHeight(self)
        StartTimer()
    end)
    f:SetScript("OnHide", StopTimer)
    CM.reminderFrame = f
    return f
end

-- ── Build reminder content ─────────────────────────────────────────────────────
-- Returns top-priority item count for a tab (first item in bags, priority order)
local function getTopCount(items)
    local id = CM.GetFirstInBags(items)
    return id and C_Item.GetItemCount(id) or 0
end

-- Colored label for one tab: red = none in bags, orange = at/below the minimum,
-- green = fine. Second return value is true for red/orange.
local function StatusPart(tabName, topCount, minCount)
    if topCount == 0 then
        return "|cffFF4444" .. tabName .. "|r", true
    elseif minCount > 0 and topCount <= minCount then
        return "|cffFFAA00" .. tabName .. " (" .. topCount .. "/" .. minCount .. ")|r", true
    end
    return "|cff00FF66" .. tabName .. " (" .. topCount .. ")|r", false
end

local function BuildReminderContent()
    if not CM.db then return {}, false, 0 end
    local L          = CM.L
    local bodyParts  = {}
    local anyIssue   = false
    local unconfigured = 0
    for _, t in ipairs(CM.TABS) do
        if not CM.REMINDER_SKIP[t.key] then
            local items    = CM.db[t.key] and CM.db[t.key].items or {}
            local tabName  = L[t.tabL] or t.key
            local minCount = (not CM.MINCOUNT_SKIP[t.key]) and (CM.db[t.key].minCount or 0) or 0
            if #items == 0 then
                tinsert(bodyParts, "|cffFF4444" .. tabName .. "|r")
                anyIssue     = true
                unconfigured = unconfigured + 1
            else
                local part, issue = StatusPart(tabName, getTopCount(items), minCount)
                tinsert(bodyParts, part)
                if issue then anyIssue = true end
            end
        end
    end
    return bodyParts, anyIssue, unconfigured
end

-- ── Show reminder ──────────────────────────────────────────────────────────────
function CM.CheckMissingConsumables()
    if not CM.db or not CM.db.showReminder then return end
    if not CM.IsMaxLevel() then return end
    local bodyParts, anyIssue, unconfigured = BuildReminderContent()
    if not anyIssue then return end
    local rf = CM.GetReminderFrame()
    CM.FillReminder(rf, bodyParts, unconfigured)
    rf:Show()
end

-- ── Live update on bag change ──────────────────────────────────────────────────
function CM.UpdateReminderFrame()
    local rf = CM.reminderFrame
    if not rf or not rf:IsShown() then return end
    if not CM.db then return end
    local bodyParts, anyIssue, unconfigured = BuildReminderContent()
    CM.FillReminder(rf, bodyParts, unconfigured)
    if not anyIssue then
        StopTimer()
        rf:Hide()
        return
    end
    CM.FitReminderHeight(rf)
end

-- ── Post-Instance Reminder ─────────────────────────────────────────────────────
-- Only warns about tabs with minCount > 0 that are at/below threshold.
-- Tabs with minCount = 0 are considered "disabled" for this trigger.
function CM.CheckMissingConsumablesPostInstance()
    if not CM.db or not CM.db.showReminder then return end
    if not CM.IsMaxLevel() then return end
    local L         = CM.L
    local bodyParts = {}
    local anyIssue  = false
    for _, t in ipairs(CM.TABS) do
        if not CM.REMINDER_SKIP[t.key] and not CM.MINCOUNT_SKIP[t.key] then
            local items    = CM.db[t.key] and CM.db[t.key].items or {}
            local minCount = CM.db[t.key] and CM.db[t.key].minCount or 0
            if minCount > 0 then
                local part, issue = StatusPart(L[t.tabL] or t.key, getTopCount(items), minCount)
                tinsert(bodyParts, part)
                if issue then anyIssue = true end
            end
        end
    end
    if not anyIssue then return end
    local rf = CM.GetReminderFrame()
    CM.FillReminder(rf, bodyParts, 0)
    rf:Show()
end
