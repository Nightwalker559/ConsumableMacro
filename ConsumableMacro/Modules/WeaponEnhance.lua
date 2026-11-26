-- ConsumableMacro Weapon Enhancement
-- Whetstones, Weightstones and oils share one priority list. The macro matches an
-- item's weapon-type restriction (edged/blunt/any) against the equipped weapon and
-- targets ONE hand per press (both hands in one press doesn't work reliably): a
-- bare hand first, then the hand with the least time left. The poison macro of the
-- rogue (Poison.lua) picks its hand the same way (CM.PickWeaponHand).
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

-- "edged" | "blunt" | "any": the listed ID wins, then the name (Forever's Classic
-- stones aren't in the ID list), else usable on any weapon (oils, poisons).
local function GetEnhanceType(itemID)
    local listed = CM.WEAPONENHANCE_IDS[itemID]
    if listed then return listed end
    local name = C_Item.GetItemNameByID(itemID)  -- nil until cached
    name = name and name:lower()
    if name then
        if CM.MatchesAny(name, CM.L["PATTERN_BLUNT"]) then return "blunt" end
        if CM.MatchesAny(name, CM.L["PATTERN_EDGED"]) then return "edged" end
    end
    return "any"
end

-- First item in the list that's in the bags and usable on weaponType.
local function GetBestItemFor(items, weaponType)
    for _, item in ipairs(items) do
        if CM.IsInBags(item.id) then
            local wtype = GetEnhanceType(item.id)
            if wtype == "any" or wtype == weaponType then return item.id end
        end
    end
    return nil
end

-- Hand the next press should target and the item for it: slot, itemID (nil, nil if
-- no hand has a weapon an item fits). Bare hands first (mainhand, then offhand), then by
-- least time left. itemFor(slot, weaponType) names the item for a hand holding a weapon.
function CM.PickWeaponHand(itemFor)
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
        local itemID = weaponType and itemFor(slot, weaponType)
        if itemID then return slot, itemID end
    end
    return nil, nil
end

function CM.GetWeaponEnhanceTarget(items)
    return CM.PickWeaponHand(function(_, weaponType) return GetBestItemFor(items, weaponType) end)
end

-- Body of a macro that puts `itemID` on the weapon in `slot` (no use lines without one);
-- `items` are what the tooltip falls back to.
function CM.BuildHandMacroBody(items, slot, itemID)
    local lines = { CM.GetShowtooltipLine(items, itemID) }
    if itemID then
        tinsert(lines, "/use item:" .. itemID)
        tinsert(lines, "/use " .. slot)
        tinsert(lines, "/click StaticPopup1Button1")  -- confirms "replace enchant?"
    end
    return CM.TrimMacroLines(lines)
end

function CM.BuildWeaponEnhanceMacroBody(items)
    local slot, itemID = CM.GetWeaponEnhanceTarget(items)
    return CM.BuildHandMacroBody(items, slot, itemID)
end

-- ── Keep the macros in sync ────────────────────────────────────────────────────
-- An expiring buff or a weapon swap fires no bag event, so the macros that pick a hand
-- also rebuild on a timer and on equipment changes. CM.HAND_MACROS[macro key] =
-- { lists = tab keys whose items feed it, target = function returning the next hand }.
CM.HAND_MACROS = {
    weaponenhance = {
        lists  = { "weaponenhance" },
        target = function() return (CM.GetWeaponEnhanceTarget(CM.db.weaponenhance.items)) end,
    },
}

local last = {}  -- [macro key] = { main, off, slot } as of the last rebuild

local function HasItems(lists)
    for _, tab in ipairs(lists) do
        local items = CM.db[tab] and CM.db[tab].items
        if items and #items > 0 then return true end
    end
    return false
end

local function CheckEnchantState()
    local db = CM.db
    if not db or not db.autoUpdate then return end

    local hasMain, _, _, _, hasOff = _G.GetWeaponEnchantInfo()
    for key, macro in pairs(CM.HAND_MACROS) do
        if HasItems(macro.lists) then
            local slot = macro.target()
            local state = last[key]
            if not state then state = {}; last[key] = state end
            if hasMain ~= state.main or hasOff ~= state.off or slot ~= state.slot then
                state.main, state.off, state.slot = hasMain, hasOff, slot
                CM.UpdateMacro(key)
            end
        end
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
