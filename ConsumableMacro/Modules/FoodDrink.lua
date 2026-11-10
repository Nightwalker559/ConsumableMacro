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

-- GetActionText gives a macro's name straight from the slot; GetActionInfo + GetMacroInfo
-- is the fallback (some clients answer the first with nothing for #showtooltip macros).
local function MacroNameOfSlot(slot)
    if type(slot) ~= "number" then return nil end
    local text = _G.GetActionText and _G.GetActionText(slot)
    if type(text) == "string" and text ~= "" then return text end
    local kind, id = _G.GetActionInfo(slot)
    if kind == "macro" and id then return (_G.GetMacroInfo(id)) end
    return nil
end

-- Macro name of the action button that owns the tooltip, or nil. The tooltip knows its
-- action slot (processingInfo); the owner button is the fallback.
local function GetTooltipMacroName(tooltip)
    local info = tooltip.processingInfo
    if info and info.getterName == "GetAction" and info.getterArgs then
        local name = MacroNameOfSlot(info.getterArgs[1])
        if name then return name end
    end
    local owner = tooltip:GetOwner()
    if not owner then return nil end
    if type(owner.action) == "number" then            -- Blizzard action buttons
        return MacroNameOfSlot(owner.action)
    elseif type(owner.GetAction) == "function" then   -- LibActionButton (ElvUI, Bartender)
        local kind, a = owner:GetAction()
        if kind == "action" then return MacroNameOfSlot(a) end
        if kind == "macro" and a then return (_G.GetMacroInfo(a)) end
    end
    return nil
end

-- Everything Syndicator knows about the item: all characters, guild banks, warband bank
-- (the ones it shows in its own tooltips). nil without Syndicator.
local function GetSyndicatorTotal(itemID)
    local api = _G.Syndicator and _G.Syndicator.API
    if not (api and api.GetInventoryInfoByItemID) then return nil end
    if api.IsReady and not api.IsReady() then return nil end
    local ok, info = pcall(api.GetInventoryInfoByItemID, itemID, false, false)
    if not ok or type(info) ~= "table" then return nil end
    local total = info.warband and info.warband[1] or 0
    for _, c in ipairs(info.characters or {}) do
        total = total + (c.bags or 0) + (c.bank or 0) + (c.mail or 0) + (c.equipped or 0) + (c.void or 0) + (c.auctions or 0)
    end
    for _, g in ipairs(info.guilds or {}) do total = total + (g.bank or 0) end
    return total
end

-- "12", or "12 (Total 18)" with Syndicator, or "12 (+5 Bank)": the bags of this character,
-- plus what Syndicator counts overall, else what only this character's bank holds.
local function CountText(itemID)
    local bags  = C_Item.GetItemCount(itemID) or 0
    local total = GetSyndicatorTotal(itemID)
    if total then
        if total > bags then return ("%d (%s %d)"):format(bags, CM.L["TOOLTIP_TOTAL"], total) end
        return tostring(bags)
    end
    local all = C_Item.GetItemCount(itemID, true) or 0
    if all > bags then return ("%d (+%d %s)"):format(bags, all - bags, CM.L["TOOLTIP_BANK"]) end
    return tostring(bags)
end

function CM.AddFoodDrinkTooltipLines(tooltip)
    if not CM.db or GetTooltipMacroName(tooltip) ~= CM.MACRO_NAMES.food then return end
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

-- /cm tipdebug: prints what the hook sees for every tooltip (one line per change), to
-- find out why the lines don't show on a given action bar.
local debugTip, lastDebug = false, nil

local function DescribeTooltip(tooltip)
    local info, owner = tooltip.processingInfo, tooltip:GetOwner()
    local args = info and info.getterArgs
    local slot = args and args[1]
    local kind, id = nil, nil
    if type(slot) == "number" then kind, id = _G.GetActionInfo(slot) end
    return ("owner=%s action=%s getter=%s arg1=%s text=%s info=%s/%s macro=%s"):format(
        tostring(owner and owner.GetName and owner:GetName()), tostring(owner and owner.action),
        tostring(info and info.getterName), tostring(slot),
        tostring(type(slot) == "number" and _G.GetActionText and _G.GetActionText(slot)),
        tostring(kind), tostring(id), tostring(GetTooltipMacroName(tooltip)))
end

function CM.ToggleTipDebug()
    debugTip, lastDebug = not debugTip, nil
    CM.Print("tooltip debug " .. (debugTip and "on - hover the macro button" or "off"))
end

if _G.TooltipDataProcessor and _G.TooltipDataProcessor.AddTooltipPostCall then
    _G.TooltipDataProcessor.AddTooltipPostCall(_G.TooltipDataProcessor.AllTypes, function(tooltip)
        if tooltip ~= _G.GameTooltip or tooltip:IsForbidden() then return end
        if debugTip then
            local ok, text = pcall(DescribeTooltip, tooltip)
            if text ~= lastDebug then lastDebug = text; CM.Print((ok and "" or "ERR ") .. tostring(text)) end
        end
        local ok, err = pcall(CM.AddFoodDrinkTooltipLines, tooltip)
        if not ok and debugTip then CM.Print("ERR " .. tostring(err)) end
    end)
end
