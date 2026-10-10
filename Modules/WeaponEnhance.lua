-- ConsumableMacro Weapon Enhancement
-- Whetstones, Weightstones and oils share one priority list. The macro matches an
-- item's weapon-type restriction (edged/blunt/any) against the equipped weapon and
-- targets ONE hand per press (both hands in one press doesn't work reliably): a
-- bare hand first, then the hand with the least time left.
local CM = ConsumableMacroAddon

local MAINHAND, OFFHAND = 16, 17

-- Weapon (class 2) subclassIDs, grouped by what Whetstone/Weightstone accept.
local EDGED_SUBCLASS = { [0] = true, [1] = true, [6] = true, [7] = true, [8] = true, [13] = true, [15] = true }
local BLUNT_SUBCLASS = { [4] = true, [5] = true, [10] = true }

-- "edged" | "blunt" | "other" | nil (empty slot, or not a weapon - e.g. a shield)
local function GetEquippedWeaponType(slot)
    local itemID = _G.GetInventoryItemID("player", slot)
    if not itemID then return nil end
    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
    if classID ~= 2 then return nil end
    if EDGED_SUBCLASS[subclassID] then return "edged" end
    if BLUNT_SUBCLASS[subclassID] then return "blunt" end
    return "other"
end

-- First item in the list that's in the bags and usable on weaponType. Items not in
-- CM.WEAPONENHANCE_IDS count as usable on any weapon.
local function GetBestItemFor(items, weaponType)
    for _, item in ipairs(items) do
        if CM.IsInBags(item.id) then
            local wtype = CM.WEAPONENHANCE_IDS[item.id] or "any"
            if wtype == "any" or wtype == weaponType then return item.id end
        end
    end
    return nil
end

-- Hand the next press should target and the item for it: slot, itemID (nil, nil if
-- no hand has a weapon an item fits). Bare hands first (mainhand, then offhand),
-- then by least time left.
function CM.GetWeaponEnhanceTarget(items)
    -- returns: hasMain, mainExpiration (ms), mainCharges, mainEnchantID, hasOff, offExpiration, ...
    local hasMain, mainExp, _, _, hasOff, offExp = _G.GetWeaponEnchantInfo()

    local order
    if hasMain and hasOff then
        order = (offExp or 0) < (mainExp or 0) and { OFFHAND, MAINHAND } or { MAINHAND, OFFHAND }
    elseif hasOff then
        order = { MAINHAND, OFFHAND }  -- mainhand is bare
    elseif hasMain then
        order = { OFFHAND, MAINHAND }  -- offhand is bare
    else
        order = { MAINHAND, OFFHAND }
    end

    for _, slot in ipairs(order) do
        local weaponType = GetEquippedWeaponType(slot)
        local itemID = weaponType and GetBestItemFor(items, weaponType)
        if itemID then return slot, itemID end
    end
    return nil, nil
end

function CM.BuildWeaponEnhanceMacroBody(items)
    local slot, itemID = CM.GetWeaponEnhanceTarget(items)

    local lines = { CM.GetShowtooltipLine(items, itemID) }

    if itemID then
        tinsert(lines, "/use item:" .. itemID)
        tinsert(lines, "/use " .. slot)
        tinsert(lines, "/click StaticPopup1Button1")  -- confirms "replace enchant?"
    end

    return CM.TrimMacroLines(lines)
end

-- ── Keep the macro in sync ─────────────────────────────────────────────────────
-- An expiring buff or a weapon swap fires no bag event, so this tab also rebuilds
-- on a timer and on equipment changes.
local lastMain, lastOff, lastSlot

local function CheckEnchantState()
    local db = CM.db
    if not db or not db.autoUpdate then return end
    local items = db.weaponenhance and db.weaponenhance.items
    if not items or #items == 0 then return end

    local hasMain, _, _, _, hasOff = _G.GetWeaponEnchantInfo()
    local slot = CM.GetWeaponEnhanceTarget(items)
    if hasMain ~= lastMain or hasOff ~= lastOff or slot ~= lastSlot then
        lastMain, lastOff, lastSlot = hasMain, hasOff, slot
        CM.UpdateMacro("weaponenhance")
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        _G.C_Timer.NewTicker(30, CheckEnchantState)
    end
    CM.Defer("weaponEnchantCheck", CheckEnchantState, 0.5)
end)
