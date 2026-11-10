-- ConsumableMacro Food & Drink (WoW Forever only)
-- Two priority lists (Food, Drink) feed one macro. Eating and drinking run at the same
-- time and don't trigger the global cooldown, so a plain press uses the first food AND
-- the first drink that are in the bags. Shift alone uses only the drink, Ctrl alone
-- only the food.
local CM = ConsumableMacroAddon
if not CM.IS_FOREVER then return end

function CM.BuildFoodDrinkMacroBody()
    local food, drink = CM.db.food.items, CM.db.drink.items

    -- the tooltip follows the first item in the bags, food before drink
    local all = {}
    for _, list in ipairs({ food, drink }) do
        for _, item in ipairs(list) do tinsert(all, item) end
    end

    local lines = { CM.GetShowtooltipLine(all) }
    local foodID, drinkID = CM.GetFirstInBags(food), CM.GetFirstInBags(drink)
    if drinkID then tinsert(lines, "/use [mod:shift,nomod:ctrl] item:" .. drinkID) end
    if foodID  then tinsert(lines, "/use [mod:ctrl,nomod:shift] item:" .. foodID) end
    -- no modifier: both; an item that restores both sits in both lists and is used once
    if foodID  then tinsert(lines, "/use [nomod] item:" .. foodID) end
    if drinkID and drinkID ~= foodID then tinsert(lines, "/use [nomod] item:" .. drinkID) end
    return CM.TrimMacroLines(lines)
end

-- ── Action bar tooltip ────────────────────────────────────────────────────────
-- #showtooltip can only show one item, so the tooltip of the CM_FoodDrink button gets
-- two extra lines: the food and the drink the macro uses, with their counts.

-- Name of the macro on the action button that owns the tooltip, or nil.
local function GetOwnerMacroName(owner)
    if not owner then return nil end
    local kind, id
    if type(owner.action) == "number" then            -- Blizzard action buttons
        kind, id = _G.GetActionInfo(owner.action)
    elseif type(owner.GetAction) == "function" then   -- LibActionButton (ElvUI, Bartender)
        local t, a = owner:GetAction()
        if t == "action" then kind, id = _G.GetActionInfo(a)
        elseif t == "macro" then kind, id = "macro", a end
    end
    if kind == "macro" and id then return (_G.GetMacroInfo(id)) end
    return nil
end

-- "12" or "12 (+5 Bank)": what is in the bags, plus what only the bank holds.
local function CountText(itemID)
    local bags = C_Item.GetItemCount(itemID) or 0
    local all  = C_Item.GetItemCount(itemID, true) or 0
    if all > bags then return ("%d (+%d %s)"):format(bags, all - bags, CM.L["TOOLTIP_BANK"]) end
    return tostring(bags)
end

function CM.AddFoodDrinkTooltipLines(tooltip)
    if not CM.db or GetOwnerMacroName(tooltip:GetOwner()) ~= CM.MACRO_NAMES.food then return end
    local foodID, drinkID = CM.GetFirstInBags(CM.db.food.items), CM.GetFirstInBags(CM.db.drink.items)
    if not (foodID or drinkID) then return end

    tooltip:AddLine(" ")
    tooltip:AddLine(CM.L["TAB_FOODDRINK"], 1, 0.82, 0)
    if foodID then
        tooltip:AddDoubleLine(CM.GetItemDisplayName(foodID), CountText(foodID), 1, 1, 1, 1, 1, 1)
    end
    if drinkID and drinkID ~= foodID then  -- an item that restores both is listed once
        tooltip:AddDoubleLine(CM.GetItemDisplayName(drinkID), CountText(drinkID), 1, 1, 1, 1, 1, 1)
    end
    tooltip:AddLine(CM.L["TOOLTIP_FOODDRINK_HINT"], 0.6, 0.6, 0.6)
    tooltip:Show()  -- resize to the added lines
end

if _G.TooltipDataProcessor and _G.TooltipDataProcessor.AddTooltipPostCall then
    _G.TooltipDataProcessor.AddTooltipPostCall(_G.TooltipDataProcessor.AllTypes, function(tooltip)
        if tooltip == _G.GameTooltip and not tooltip:IsForbidden() then
            pcall(CM.AddFoodDrinkTooltipLines, tooltip)
        end
    end)
end
