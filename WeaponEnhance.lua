-- ConsumableMacro Weapon Enhancement
-- Whetstones, Weightstones and Weapon Oils share one priority list. The macro
-- picks the right item by matching its weapon-type restriction (edged/blunt/
-- any) against the equipped weapon, and only ever targets ONE hand per click
-- - mainhand first, then offhand once mainhand is covered - since applying
-- the same item to both hands in a single macro press doesn't work reliably.
local CM = ConsumableMacroAddon

-- classID 2 (Weapon) subclassIDs, grouped by what Whetstone/Weightstone accept.
local EDGED_SUBCLASS = { [0] = true, [1] = true, [6] = true, [7] = true, [8] = true, [13] = true, [15] = true }
local BLUNT_SUBCLASS = { [4] = true, [5] = true, [10] = true }

-- "edged" | "blunt" | "other" | nil (empty slot, or not a weapon - e.g. a shield)
function CM.GetEquippedWeaponType(slot)
    local itemID = _G.GetInventoryItemID("player", slot)
    if not itemID then return nil end
    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(itemID)
    if classID ~= 2 then return nil end
    if EDGED_SUBCLASS[subclassID] then return "edged" end
    if BLUNT_SUBCLASS[subclassID] then return "blunt" end
    return "other"
end

-- "edged" | "blunt" | "any" - which weapon type a weapon-enhancement item
-- accepts. Known Whetstone/Weightstone IDs are listed in CM.WEAPONENHANCE_IDS
-- (Items.lua); anything else (oils, and any not-yet-listed item) is treated
-- as usable on any weapon.
function CM.GetWeaponEnhanceType(itemID)
    return CM.WEAPONENHANCE_IDS[itemID] or "any"
end

-- First item in the priority list that's in the bags and usable on weaponType.
local function GetBestItemFor(items, weaponType)
    for _, item in ipairs(items) do
        if CM.IsInBags(item.id) then
            local wtype = CM.GetWeaponEnhanceType(item.id)
            if wtype == "any" or wtype == weaponType then return item.id end
        end
    end
    return nil
end

-- Applies itemID to equip slot, confirming the "replace enchant?" popup if
-- one appears (community-verified macro pattern for these items).
local function AppendApplyLines(lines, itemID, slot)
    tinsert(lines, "/use item:" .. itemID)
    tinsert(lines, "/use " .. slot)
    tinsert(lines, "/click StaticPopup1Button1")
end

-- Only one hand per click - using the same item twice (once per hand) inside
-- a single macro press doesn't reliably apply both in practice, so the macro
-- only ever targets ONE hand: mainhand first, then offhand once mainhand is
-- covered. Using the item consumes it from the bags, which triggers the
-- normal bag-update rebuild - so the very next rebuild already points at the
-- other hand, ready for a second press.
function CM.BuildWeaponEnhanceMacroBody(items)
    -- GetWeaponEnchantInfo(): hasMainHandEnchant, mainHandExpiration,
    -- mainHandCharges, mainHandEnchantID, hasOffHandEnchant, ... (5th value,
    -- not 4th - mainHandEnchantID sits in between and is easy to miscount).
    local hasMainHandEnchant, _, _, _, hasOffHandEnchant = _G.GetWeaponEnchantInfo()

    local slot, weaponType
    if not hasMainHandEnchant then
        slot, weaponType = 16, CM.GetEquippedWeaponType(16)
    elseif not hasOffHandEnchant then
        slot, weaponType = 17, CM.GetEquippedWeaponType(17)
    end

    local itemID = slot and weaponType and GetBestItemFor(items, weaponType)

    -- Always show an item on the button, like every other tab - even when
    -- there's nothing to apply this cycle (both hands already covered, or
    -- the hand that needs it currently holds no weapon), or nothing from the
    -- list is currently in the bags at all (falls back to the top-priority
    -- configured item, same as GetMacroBodyText in Core.lua) - so the macro
    -- never looks like a dead/empty button.
    local showID = itemID or CM.GetFirstInBags(items) or (items[1] and items[1].id)
    local lines = { showID and ("#showtooltip item:" .. showID) or "#showtooltip" }

    if itemID then AppendApplyLines(lines, itemID, slot) end

    return CM.TrimMacroLines(lines)
end

-- ── Keep the macro in sync when a buff expires or a weapon is swapped ──────────
-- Neither fires a bag event, so this tab also rebuilds on a timer and on
-- equipment changes, in addition to the normal bag-update trigger that already
-- covers "just applied it" (the item leaving the bag).
local lastMain, lastOff = nil, nil

local function CheckEnchantState()
    local items = CM.db and CM.db.weaponenhance and CM.db.weaponenhance.items
    if not items or #items == 0 then return end
    local hasMain, _, _, _, hasOff = _G.GetWeaponEnchantInfo()
    if hasMain ~= lastMain or hasOff ~= lastOff then
        lastMain, lastOff = hasMain, hasOff
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
