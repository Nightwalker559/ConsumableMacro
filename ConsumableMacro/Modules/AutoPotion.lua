-- ConsumableMacro AutoPotion
-- Optional "panic button" macro (CM_AutoPotion): one /castsequence over a
-- self-heal spell, the top Heal Potion and the Healthstone, in a user-defined order.
local CM = ConsumableMacroAddon

CM.AUTOPOTION_MACRO_NAME = "CM_AutoPotion"

-- Self-heal spell IDs (retail 12.x), filtered by isSpellKnown, so IDs the character
-- doesn't have are skipped. Only active spells with a reliable self-heal are listed;
-- passive talents (e.g. the Monk's Healing Elixir) can't go in a castsequence.
CM.AUTOPOTION_SPELLS = {
    -- Rogue
    185311, -- Crimson Vial
    -- Hunter
    109304, -- Exhilaration
    -- Warrior
    12975,  -- Last Stand
    -- Priest
    19236,  -- Desperate Prayer
    -- Monk
    322101, -- Expel Harm
    -- Death Knight
    48743,  -- Death Pact
    55233,  -- Vampiric Blood
    -- Warlock
    108416, -- Dark Pact
    -- Paladin
    633,    -- Lay on Hands

    -- Racial: Gift of the Naaru (Draenei), one ID per class
    28880,  -- Warrior
    59542,  -- Paladin
    59543,  -- Hunter
    59544,  -- Priest
    59545,  -- Death Knight
    59547,  -- Shaman
    59548,  -- Mage
    121093, -- Monk
    370626, -- Rogue
    416250, -- Warlock
}

-- IsPlayerSpell is the fallback: the spellbook query alone doesn't always report
-- talent-granted spells as known.
local function isSpellKnown(id)
    return C_SpellBook.IsSpellKnown(id) or (IsPlayerSpell and IsPlayerSpell(id)) or false
end

-- Spell ID of the first known self-heal/racial spell, or nil.
function CM.GetKnownAutoPotionSpellID()
    for _, id in ipairs(CM.AUTOPOTION_SPELLS) do
        if isSpellKnown(id) then return id end
    end
    return nil
end

-- ── Macro body ───────────────────────────────────────────────────────────────
function CM.BuildAutoPotionMacroBody()
    local ap = CM.db and CM.db.autoPotion
    local order = CM.db and CM.db.autoPotionOrder
    if not ap or not order then return "#showtooltip" end

    local seq = {}

    for _, key in ipairs(order) do
        if key == "classspell" then
            local spellID = CM.GetKnownAutoPotionSpellID()
            if spellID then
                local name = C_Spell.GetSpellName(spellID)
                if name then tinsert(seq, name) end
            end
        elseif key == "healpotion" or key == "healthstone" then
            local itemID = CM.GetFirstInBags(CM.db[key].items)
            if itemID then tinsert(seq, "item:" .. itemID) end
        end
    end

    local lines = { "#showtooltip" }
    if ap.stopCasting then tinsert(lines, "/stopcasting") end

    if #seq > 0 then
        local resetSeconds = tonumber(CM.db.autoPotionResetSeconds) or 0
        local resetStr = resetSeconds > 0 and ("combat/" .. resetSeconds) or "combat"
        tinsert(lines, "/castsequence [@player] reset=" .. resetStr .. " " .. table.concat(seq, ", "))
    end

    return CM.TrimMacroLines(lines)
end

-- ── Macro management ────────────────────────────────────────────────────────
function CM.UpdateAutoPotionMacro(createOnly)
    if not CM.db then return end
    if InCombatLockdown() then
        CM.needsUpdateAfterCombat = true
        return
    end

    if not CM.db.autoPotion or not CM.db.autoPotion.enabled then
        if createOnly == true then return end
        local idx = _G.GetMacroIndexByName(CM.AUTOPOTION_MACRO_NAME)
        if idx and idx > 0 then _G.DeleteMacro(idx) end
        return
    end

    CM.WriteMacro(CM.AUTOPOTION_MACRO_NAME, CM.BuildAutoPotionMacroBody(), createOnly)
end

-- Prefills the reset-seconds field from the spell's cooldown. A running cooldown
-- gives the exact, talent-adjusted value; a ready spell only has its base
-- cooldown (approximate). Durations up to 2s are the global cooldown, not the spell's.
local MIN_REAL_COOLDOWN = 2

function CM.SyncAutoPotionResetFromCooldown()
    local L = CM.L
    local spellID = CM.GetKnownAutoPotionSpellID()
    if not spellID then
        CM.ShowError(L["AUTOPOTION_SYNC_NO_SPELL"])
        return
    end

    local seconds, approximate = nil, false
    local cd = C_Spell.GetSpellCooldown(spellID)
    if cd and cd.startTime > 0 and cd.duration > MIN_REAL_COOLDOWN then
        seconds = math.floor(cd.duration + 0.5)
    elseif _G.GetSpellBaseCooldown then
        local baseMS = _G.GetSpellBaseCooldown(spellID)
        if baseMS and baseMS > 0 then
            seconds = math.floor(baseMS / 1000 + 0.5)
            approximate = true
        end
    end

    if not seconds then
        CM.ShowError(L["AUTOPOTION_SYNC_NOT_ON_CD"])
        return
    end

    CM.db.autoPotionResetSeconds = seconds
    if CM.optionsFrame and CM.optionsFrame.apResetBox then
        CM.optionsFrame.apResetBox:SetText(tostring(seconds))
    end
    CM.UpdateAutoPotionMacro()

    local msg = approximate and L["AUTOPOTION_SYNC_SUCCESS_APPROX"] or L["AUTOPOTION_SYNC_SUCCESS"]
    CM.Print(string.format(msg, seconds))
end

-- ── Priority Frame (reorder classspell / healpotion / healthstone) ────────────
CM.AUTOPOTION_ROW_LABELS = {
    classspell  = "LABEL_AUTOPOTION_CLASSSPELL",
    healpotion  = "TAB_HEALPOTION",
    healthstone = "TAB_HEALTHSTONE",
}

function CM.BuildAutoPotionFrame()
    if CM.autoPotionFrame then return CM.autoPotionFrame end
    local L = CM.L

    local rowH   = 30
    local frameH = 30 + 30 + (3 * rowH) + 20 + 30

    local f = CM.CreateWindow("CMAutoPotionFrame")
    f:SetSize(260, frameH)
    f:SetPoint("LEFT", CM.optionsFrame, "RIGHT", 8, 0)
    f.TitleText:SetText(L["AUTOPOTION_PRIORITY_TITLE"])

    local y = -30
    f.descLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.descLbl:SetPoint("TOPLEFT", 14, y)
    f.descLbl:SetPoint("TOPRIGHT", -14, y)
    f.descLbl:SetJustifyH("LEFT")
    f.descLbl:SetWordWrap(true)
    f.descLbl:SetText(L["AUTOPOTION_PRIORITY_DESC"])
    f.descLbl:SetTextColor(0.7, 0.7, 0.7)
    y = y - 34

    f.rows = {}
    for i = 1, 3 do
        local row = CreateFrame("Frame", nil, f)
        row:SetSize(232, rowH - 4)
        row:SetPoint("TOPLEFT", 14, y)

        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(0.2, 0.2, 0.2, 0.4)

        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.label:SetPoint("LEFT", 6, 0)

        row.downBtn = CM.CreateIconButton(row, "down")
        row.downBtn:SetPoint("RIGHT", -6, 0)
        row.downBtn:SetScript("OnClick", function() CM.MoveAutoPotionRow(row.index, 1) end)

        row.upBtn = CM.CreateIconButton(row, "up")
        row.upBtn:SetPoint("RIGHT", row.downBtn, "LEFT", -4, 0)
        row.upBtn:SetScript("OnClick", function() CM.MoveAutoPotionRow(row.index, -1) end)

        f.rows[i] = row
        y = y - rowH
    end

    y = y - 10
    f.closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.closeBtn:SetSize(100, 24)
    f.closeBtn:SetPoint("TOPLEFT", 14, y)
    f.closeBtn:SetText(OKAY)
    f.closeBtn:SetScript("OnClick", function() f:Hide() end)

    CM.autoPotionFrame = f
    return f
end

-- Swaps the row at `index` with the one `direction` (+1/-1) away.
function CM.MoveAutoPotionRow(index, direction)
    local order = CM.db and CM.db.autoPotionOrder
    if not order then return end
    local target = index + direction
    if target < 1 or target > #order then return end
    order[index], order[target] = order[target], order[index]
    CM.RefreshAutoPotionFrame()
    CM.UpdateAutoPotionMacro()
end

function CM.RefreshAutoPotionFrame()
    local f = CM.autoPotionFrame
    local order = CM.db and CM.db.autoPotionOrder
    if not f or not order then return end
    for i, row in ipairs(f.rows) do
        local key = order[i]
        row.index = i
        local label = CM.L[CM.AUTOPOTION_ROW_LABELS[key]] or key
        if key == "classspell" then
            local spellID = CM.GetKnownAutoPotionSpellID()
            local spellName = spellID and C_Spell.GetSpellName(spellID)
            if spellName then label = spellName end
        end
        row.label:SetText(i .. ".  " .. label)
        row.upBtn:SetEnabled(i > 1)
        row.downBtn:SetEnabled(i < #order)
    end
end

function CM.ShowAutoPotionFrame()
    local f = CM.BuildAutoPotionFrame()
    if f:IsShown() then
        f:Hide()
        return
    end
    CM.RefreshAutoPotionFrame()
    CM.HideSidePanels("autoPotionFrame")
    f:Show()
    CM.ApplyElvUISkin()
end

-- ── Keep the macro in sync with talent/spec changes ────────────────────────────
local apEvents = CreateFrame("Frame")
apEvents:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
apEvents:RegisterEvent("TRAIT_CONFIG_UPDATED")
apEvents:SetScript("OnEvent", function(_, event, arg1)
    -- Fires for any unit's spec change, not just the player's.
    if event == "PLAYER_SPECIALIZATION_CHANGED" and arg1 ~= "player" then return end

    -- Fires for any trait config (incl. professions); arg1 is the configID.
    -- Only the active class talent config matters here.
    if event == "TRAIT_CONFIG_UPDATED" then
        local activeConfigID = C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
        if not activeConfigID or arg1 ~= activeConfigID then return end
    end
    if CM.db and CM.db.autoPotion and CM.db.autoPotion.enabled then
        CM.UpdateAutoPotionMacro()
        -- A talent can change the spell's cooldown, which can't be re-read while it's
        -- ready: remind the user to re-sync a manual reset delay.
        if (CM.db.autoPotionResetSeconds or 0) > 0 then
            CM.Print(CM.L["AUTOPOTION_TALENT_CHANGED_HINT"])
        end
    end
end)
