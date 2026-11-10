-- ConsumableMacro Macro Tooltip
-- #showtooltip shows one item, and the action bar tooltip of a macro isn't an item
-- tooltip, so inventory addons (Syndicator, Baganator) add nothing to it. For every
-- CM_ macro the tooltip is set to the item the macro shows, as an item tooltip, so
-- Syndicator decorates it like a bag item; the other items the macro uses follow as
-- lines with their counts - only for Food & Drink, where the drink is the second item.
local CM = ConsumableMacroAddon

local KEY_BY_MACRO = {}
for key, name in pairs(CM.MACRO_NAMES) do KEY_BY_MACRO[name] = key end

-- Item IDs the tooltip is about, in macro order; the first one is what #showtooltip shows.
-- Food & Drink has two (food, drink), every other macro one.
function CM.GetMacroItems(key)
    local db, out = CM.db, {}
    if not db then return out end
    local function add(id)
        if not id then return end
        for _, have in ipairs(out) do
            if have == id then return end  -- an item that sits in both lists counts once
        end
        tinsert(out, id)
    end
    if key == "food" then
        local foodID, drinkID = CM.GetFoodDrinkIDs()
        add(foodID)
        add(drinkID)
    elseif key == "weaponenhance" then
        local _, id = CM.GetWeaponEnhanceTarget(db.weaponenhance.items)
        add(id)
    elseif db[key] then
        add(CM.GetFirstInBags(db[key].items))
    end
    return out
end

-- ── Which macro is this tooltip for ───────────────────────────────────────────
-- GetActionText gives a macro's name straight from the slot; GetActionInfo + GetMacroInfo
-- is the fallback (GetMacroInfo answers nothing for #showtooltip macros on Forever).
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

-- ── Counts ────────────────────────────────────────────────────────────────────
-- Everything Syndicator knows about the item (all characters, guild banks, warband bank),
-- or nil without Syndicator.
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

-- "12", "12 (Total 18)" with Syndicator, or "12 (+5 Bank)" without: the bags of this
-- character, plus everything else Syndicator counts, else this character's bank.
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

-- ── Tooltip ───────────────────────────────────────────────────────────────────
local busy = false  -- SetItemByID runs the tooltip hooks again, this one included

function CM.DecorateMacroTooltip(tooltip)
    if busy or not CM.db then return end
    local key = KEY_BY_MACRO[GetTooltipMacroName(tooltip) or ""]
    if not key then return end
    local items = CM.GetMacroItems(key)
    if #items == 0 then return end

    busy = true
    local ok = pcall(tooltip.SetItemByID, tooltip, items[1])
    busy = false
    if not ok then return end

    if #items > 1 then
        tooltip:AddLine(" ")
        tooltip:AddLine(CM.L["TOOLTIP_ALSO_IN_MACRO"], 1, 0.82, 0)
        for i = 2, #items do
            tooltip:AddDoubleLine(CM.GetItemDisplayName(items[i]), CountText(items[i]), 1, 1, 1, 1, 1, 1)
        end
    end
    if key == "food" then tooltip:AddLine(CM.L["TOOLTIP_FOODDRINK_HINT"], 0.6, 0.6, 0.6) end
    tooltip:Show()  -- resize to the added lines
end

-- /cm tipdebug: prints what the hook sees for every tooltip (one line per change), to
-- find out why a given action bar button isn't recognised.
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
        local ok, err = pcall(CM.DecorateMacroTooltip, tooltip)
        if not ok and debugTip then CM.Print("ERR " .. tostring(err)) end
    end)
end
