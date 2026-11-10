-- ConsumableMacro Food & Drink (WoW Forever only)
-- Two priority lists (Food, Drink) feed one macro. Eating and drinking run at the same
-- time and don't trigger the global cooldown, so one press uses the first food AND the
-- first drink that are in the bags.
local CM = ConsumableMacroAddon
if not CM.IS_FOREVER then return end

function CM.BuildFoodDrinkMacroBody()
    local food, drink = CM.db.food.items, CM.db.drink.items

    -- the tooltip follows the first item in the bags, food before drink
    local all = {}
    for _, list in ipairs({ food, drink }) do
        for _, item in ipairs(list) do tinsert(all, item) end
    end

    -- an item that restores both sits in both lists and is used only once
    local lines, used = { CM.GetShowtooltipLine(all) }, {}
    for _, list in ipairs({ food, drink }) do
        local id = CM.GetFirstInBags(list)
        if id and not used[id] then
            used[id] = true
            tinsert(lines, "/use item:" .. id)
        end
    end
    return CM.TrimMacroLines(lines)
end
