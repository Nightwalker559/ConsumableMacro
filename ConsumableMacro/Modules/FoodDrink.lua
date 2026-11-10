-- ConsumableMacro Food & Drink (WoW Forever only)
-- Two priority lists (Food, Drink) feed one macro. Eating and drinking run at the same
-- time and don't trigger the global cooldown, so a plain press uses the first food AND
-- the first drink that are in the bags. Shift alone uses only the drink, Ctrl alone
-- only the food.
local CM = ConsumableMacroAddon
if not CM.IS_FOREVER then return end

-- The food and the drink the macro uses right now: the first of each list that is in the bags.
function CM.GetFoodDrinkIDs()
    return CM.GetFirstInBags(CM.db.food.items), CM.GetFirstInBags(CM.db.drink.items)
end

function CM.BuildFoodDrinkMacroBody()
    local food, drink = CM.db.food.items, CM.db.drink.items

    -- the tooltip follows the first item in the bags, food before drink
    local all = {}
    for _, list in ipairs({ food, drink }) do
        for _, item in ipairs(list) do tinsert(all, item) end
    end

    local lines = { CM.GetShowtooltipLine(all) }
    local foodID, drinkID = CM.GetFoodDrinkIDs()
    if drinkID then tinsert(lines, "/use [mod:shift,nomod:ctrl] item:" .. drinkID) end
    if foodID  then tinsert(lines, "/use [mod:ctrl,nomod:shift] item:" .. foodID) end
    -- no modifier: both; an item that restores both sits in both lists and is used once
    if foodID  then tinsert(lines, "/use [nomod] item:" .. foodID) end
    if drinkID and drinkID ~= foodID then tinsert(lines, "/use [nomod] item:" .. drinkID) end
    return CM.TrimMacroLines(lines)
end
