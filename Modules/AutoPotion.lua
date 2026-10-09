-- ConsumableMacro AutoPotion
-- Builds an optional "panic button" macro (CM_AutoPotion) that cycles through
-- a class/racial self-heal spell, the top Heal Potion, and the Healthstone,
-- in a user-defined order, using /castsequence.
local CM = ConsumableMacroAddon

CM.AUTOPOTION_MACRO_NAME = "CM_AutoPotion"

-- ── Known self-heal / panic-button spell IDs (retail, Patch 12.x) ──────────────
-- IsSpellKnown() filters this down to whatever the current class/race actually
-- has, so stale or removed IDs are simply skipped - no per-class lookup needed.
-- Note: only classes with a clear, reliable self-only heal cooldown are listed;
-- classes without one (Druid, Shaman, Mage, Demon Hunter, Evoker) fall back to
-- the Heal Potion / Healthstone slots only. Passive talents (e.g. the Monk's
-- Healing Elixir, which triggers by itself below 40% health) can't go in a
-- castsequence and are deliberately left out.
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

    -- Racial: Gift of the Naaru (Draenei) - tooltip/effect differs per class
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

-- The legacy global IsSpellKnown() has become unreliable in current retail
-- (Blizzard moved spellbook queries to C_SpellBook in the API overhaul), so
-- C_SpellBook.IsSpellKnown is checked first, with a fallback for older clients.
-- IsPlayerSpell is the extra fallback: talent-granted spells are not always
-- reported as "known" by the spellbook query alone.
local function isSpellKnown(id)
    if C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(id) then
        return true
    end
    if IsSpellKnown and IsSpellKnown(id) then return true end
    return IsPlayerSpell and IsPlayerSpell(id) or false
end

-- Returns the spell ID of the first known self-heal/racial spell, or nil.
function CM.GetKnownAutoPotionSpellID()
    for _, id in ipairs(CM.AUTOPOTION_SPELLS) do
        if isSpellKnown(id) then return id end
    end
    return nil
end

-- ── Macro body ───────────────────────────────────────────────────────────────
local function getTopAvailableItemID(tabKey)
    return CM.GetFirstInBags(CM.db and CM.db[tabKey] and CM.db[tabKey].items)
end

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
            local itemID = getTopAvailableItemID(key)
            if itemID then tinsert(seq, "item:" .. itemID) end
        end
    end

    local lines = { "#showtooltip" }
    if ap.stopCasting then tinsert(lines, "/stopcasting") end

    if #seq > 0 then
        local resetStr = "combat"
        local resetSeconds = tonumber(CM.db.autoPotionResetSeconds) or 0
        if resetSeconds > 0 then
            resetStr = "combat/" .. resetSeconds
        end
        tinsert(lines, "/castsequence [@player] reset=" .. resetStr .. " " .. table.concat(seq, ", "))
    end

    -- Respect the 254-byte macro body limit (shared helper, see Core.lua)
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

-- Reads the spell's cooldown to prefill the reset-seconds field.
-- While the spell is actively cooling down, C_Spell.GetSpellCooldown reports
-- the exact, talent-adjusted duration - this is the accurate path.
-- If it's ready (not on cooldown), that API only ever returns 0, so we fall
-- back to the legacy GetSpellBaseCooldown, which works in any state but does
-- NOT account for talent-based cooldown reduction (flagged as approximate).
function CM.SyncAutoPotionResetFromCooldown()
    local L = CM.L
    local spellID = CM.GetKnownAutoPotionSpellID()
    if not spellID then
        CM.ShowError(L["AUTOPOTION_SYNC_NO_SPELL"])
        return
    end

    local seconds, approximate = nil, false
    local cd = C_Spell.GetSpellCooldown(spellID)
    if cd and cd.startTime and cd.startTime > 0 and cd.duration and cd.duration > 0 then
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

-- Swaps the row at `index` with `index + direction`, saves, and redraws.
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
    -- PLAYER_SPECIALIZATION_CHANGED fires for ANY unit whose spec changes
    -- (e.g. raid members on join/spec-sync), not just the player - filter it.
    if event == "PLAYER_SPECIALIZATION_CHANGED" and arg1 ~= "player" then return end

    -- TRAIT_CONFIG_UPDATED fires for ANY trait config commit, including
    -- profession trees, not just class talents. arg1 is the configID; only react
    -- to the player's active class talent config so leveling a profession
    -- doesn't spam the hint.
    if event == "TRAIT_CONFIG_UPDATED" then
        local activeConfigID = C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
        if not activeConfigID or arg1 ~= activeConfigID then return end
    end
    if CM.db and CM.db.autoPotion and CM.db.autoPotion.enabled then
        CM.UpdateAutoPotionMacro()
        -- Talent ranks can change a spell's cooldown (e.g. a talent that
        -- reduces it by a fixed amount). We can't reliably re-read that
        -- without the spell actually being on cooldown, so just nudge the
        -- user to re-sync manually if they use a manual reset delay.
        if (CM.db.autoPotionResetSeconds or 0) > 0 then
            CM.Print(CM.L["AUTOPOTION_TALENT_CHANGED_HINT"])
        end
    end
end)
