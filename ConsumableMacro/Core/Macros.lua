-- ConsumableMacro Macros
-- Builds the macro bodies and writes the account macros (CM_Flask, CM_Potion, ...).
local CM = ConsumableMacroAddon

-- Joins macro lines, dropping the ones that no longer fit the 254-char body limit.
function CM.TrimMacroLines(lines)
    local finalLines, currentLength = {}, 0
    for _, line in ipairs(lines) do
        local lineLen = #line + (currentLength == 0 and 0 or 1)
        if currentLength + lineLen > 254 then break end
        tinsert(finalLines, line)
        currentLength = currentLength + lineLen
    end
    return table.concat(finalLines, "\n")
end

-- "#showtooltip" line for an item list: `itemID` if given, else the first item in
-- the bags, else the top-priority configured item - so a button never looks empty.
function CM.GetShowtooltipLine(items, itemID)
    local id = itemID or CM.GetFirstInBags(items) or (items[1] and items[1].id)
    return id and ("#showtooltip item:" .. id) or "#showtooltip"
end

function CM.GetMacroBodyText(key)
    key = CM.MACRO_OWNER[key] or key
    local db = CM.db
    if not db or not db[key] or not db[key].items then return "" end
    local items = db[key].items

    -- Weapon Enhancements build their body very differently (per-hand,
    -- weapon-type and enchant-state aware) - see WeaponEnhance.lua.
    if key == "weaponenhance" then
        return CM.BuildWeaponEnhanceMacroBody(items)
    end
    -- Food + Drink (Forever): one macro over two lists - see FoodDrink.lua.
    if key == "food" then
        return CM.BuildFoodDrinkMacroBody()
    end

    local lines = { CM.GetShowtooltipLine(items), "/cqs", "/stopcasting" }

    -- Only potion, healpotion and manapotion get the stacked fallback chain (every
    -- item in the bags, in priority order). Flask, healthstone and bufffood use the
    -- single best item only.
    if key == "potion" or key == "healpotion" or key == "manapotion" then
        for _, item in ipairs(items) do
            if CM.IsInBags(item.id) then tinsert(lines, "/use item:" .. item.id) end
        end
    else
        local firstMatch = CM.GetFirstInBags(items)
        if firstMatch then tinsert(lines, "/use item:" .. firstMatch) end
    end

    return CM.TrimMacroLines(lines)
end

-- Creates or updates an account macro. The write is skipped when the body is
-- unchanged (macros are rebuilt on every bag update). createOnly: never touch
-- an existing macro (used at login, when bag data may not be cached yet).
function CM.WriteMacro(name, body, createOnly)
    createOnly = createOnly == true
    local idx = _G.GetMacroIndexByName(name)
    if idx == 0 then
        local accountMacros = _G.GetNumMacros()
        if accountMacros < 120 then
            _G.CreateMacro(name, CM.ICON_UNKNOWN, body, false)
        end
        return
    end
    if createOnly then return end
    local getBody = _G.GetMacroBody or (_G.C_Macro and _G.C_Macro.GetMacroBody)
    if getBody and getBody(idx) == body then return end
    _G.EditMacro(idx, name, nil, body)
end

function CM.UpdateMacro(key, createOnly)
    if InCombatLockdown() then
        CM.needsUpdateAfterCombat = true
        return
    end
    key = CM.MACRO_OWNER[key] or key
    if not CM.db or not CM.MACRO_NAMES[key] then return end
    CM.WriteMacro(CM.MACRO_NAMES[key], CM.GetMacroBodyText(key), createOnly)
end

-- createOnly == true: only create missing macros, leave existing ones alone.
function CM.UpdateAllMacros(createOnly)
    if not CM.db then return end
    for key in pairs(CM.MACRO_NAMES) do
        CM.UpdateMacro(key, createOnly)
    end
    if CM.HAS_AUTOPOTION then CM.UpdateAutoPotionMacro(createOnly) end
end
