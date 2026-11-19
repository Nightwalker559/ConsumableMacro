-- ConsumableMacro Poisons (WoW Forever, rogues only)
-- Two priority lists feed one macro: Poison 1 goes on the main hand, Poison 2 on the off
-- hand (the first of each list that is in the bags). Like the weapon enhancements the
-- macro poisons ONE hand per press, because several in one press don't work reliably:
-- a bare hand first, then the hand with the least time left (CM.PickWeaponHand). A poison
-- that still has more than 5 minutes left is not replaced, so a press never wastes one.
local CM = ConsumableMacroAddon
if not CM.MACRO_NAMES.poison then return end

local MAINHAND = 16
local REFRESH_BELOW_MS = 5 * 60 * 1000

-- True for a hand without a weapon enchant, or one that is about to run out.
local function NeedsPoison(slot)
    local hasMain, mainExp, _, _, hasOff, offExp = _G.GetWeaponEnchantInfo()
    local has, exp = hasMain, mainExp
    if slot ~= MAINHAND then has, exp = hasOff, offExp end
    return not has or (exp or 0) < REFRESH_BELOW_MS
end

-- Hand the next press poisons and the poison for it: slot, itemID (nil, nil if no hand
-- needs one and holds a weapon with a poison in the bags).
function CM.GetPoisonTarget()
    local main, off = CM.db.poison.items, CM.db.poisonoff.items
    return CM.PickWeaponHand(function(slot)
        return NeedsPoison(slot) and CM.GetFirstInBags(slot == MAINHAND and main or off) or nil
    end)
end

function CM.BuildPoisonMacroBody()
    local slot, itemID = CM.GetPoisonTarget()

    -- the tooltip follows the poison to be applied, else the first one in the bags
    local all = {}
    for _, list in ipairs({ CM.db.poison.items, CM.db.poisonoff.items }) do
        for _, item in ipairs(list) do tinsert(all, item) end
    end
    local lines = { CM.GetShowtooltipLine(all, itemID) }

    if itemID then
        tinsert(lines, "/use item:" .. itemID)
        tinsert(lines, "/use " .. slot)
        tinsert(lines, "/click StaticPopup1Button1")  -- confirms "replace enchant?"
    end
    return CM.TrimMacroLines(lines)
end

CM.HAND_MACROS.poison = {
    lists  = { "poison", "poisonoff" },
    target = function() return (CM.GetPoisonTarget()) end,
}
