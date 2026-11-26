-- ConsumableMacro Items
-- Which tab an item belongs to (catalog, name patterns, item class), and adding items to the lists.
local CM = ConsumableMacroAddon

-- ── Item Classification ────────────────────────────────────────────────────────
-- The item catalog (Data\Catalog*.lua, lookup in Catalog.lua) decides first; items it
-- doesn't list are sorted by class and name.
local CLASS_CONSUMABLE = Enum.ItemClass.Consumable
local SUB = Enum.ItemConsumableSubclass

-- Forever: tab a food/drink item goes to - the Food/Drink list being edited (Buff Food
-- while that tab is open), else Food. CM.GetTargetTabsForItem refines Food/Drink by
-- what the item restores.
local FOOD_TABS = { bufffood = true, food = true, drink = true }
local function GetForeverFoodTab()
    return FOOD_TABS[CM.activeTab] and CM.activeTab or "food"
end

-- "health" | "mana" | "both" | nil (no use line yet), read from the "Use:" line of the
-- tooltip - the only place that says what an item restores. Other lines (the name,
-- "Mana Biscuit") don't count.
local function GetRestoreKind(itemID)
    local api, trigger = _G.C_TooltipInfo, _G.ITEM_SPELL_TRIGGER_ONUSE
    if not (api and api.GetItemByID and trigger) then return nil end
    local ok, data = pcall(api.GetItemByID, itemID)
    if not ok or not data or not data.lines then return nil end
    local L = CM.L
    for _, line in ipairs(data.lines) do
        local text = line.leftText
        if type(text) == "string" and not (_G.issecretvalue and _G.issecretvalue(text))
           and text:find(trigger, 1, true) then
            local lower = text:lower()
            local health = CM.MatchesAny(lower, L["PATTERN_RESTORE_HEALTH"])
            local mana   = CM.MatchesAny(lower, L["PATTERN_RESTORE_MANA"])
            if health and mana then return "both" end
            if health then return "health" end
            if mana then return "mana" end
        end
    end
    return nil
end

-- Tab key for an item ID, or nil if it fits none. The catalog wins (the open tab if it
-- lists the item, else the first one that does), then the name patterns, then the
-- class/subclass fallback.
function CM.GetTargetTabForItem(targetID)
    if not targetID then return nil end
    local L = CM.L

    local listed = CM.GetCatalogTabs(targetID)
    if listed then
        for _, key in ipairs(listed) do
            if key == CM.activeTab then return key end
        end
        return listed[1]
    end

    -- Class IDs come without an item data load; the name may still be missing for
    -- very recent items, in which case only the class checks apply.
    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(targetID)
    local name = C_Item.GetItemNameByID(targetID)
    name = name and name:lower()

    local isConsumable = classID == CLASS_CONSUMABLE
    -- Forever: drinks are mostly "... Water" / "... Tea", which the exclude list below
    -- would reject, so food and drink are decided by their subclass first.
    if CM.IS_FOREVER and isConsumable and subclassID == SUB.Fooddrink then return GetForeverFoodTab() end
    -- Forever: bandages are their own subclass.
    if CM.GetTabInfo("bandage") and isConsumable and subclassID and subclassID == SUB.Bandage then return "bandage" end
    -- Mana potions have their own tab; ones that restore both count as heal potions here
    -- and are added to Mana Pots as well (GetTargetTabsForItem).
    if isConsumable and subclassID == SUB.Potion then
        local kind = GetRestoreKind(targetID)
        if kind == "mana" then return "manapotion" end
        if kind == "both" then return "healpotion" end
    end

    if name then
        -- word-end match: a plain "tea" would also hit "steak" / "steamed fish"
        if CM.MatchesWordEnd(name, L["PATTERN_EXCLUDE"]) then return nil end
        if CM.MatchesAny(name, L["PATTERN_HEALTHSTONE"]) then return "healthstone" end
    end

    -- Food before the name patterns, so e.g. "Heilbutt" (halibut) doesn't match "heil".
    if isConsumable and subclassID == SUB.Fooddrink then return "bufffood" end
    if name then
        if CM.MatchesAny(name, L["PATTERN_FLASK"]) then return "flask" end
        if CM.MatchesAny(name, L["PATTERN_HEAL"])  then return "healpotion" end
    end

    -- Forever: poisons are subclass "Other" and stones have no Item Enhancement subclass
    -- either, so they are recognised by name. PATTERN_ENHANCE is matched as a whole word
    -- (leading space + word end): "Gift" hits, "Gegengift" / "Giftreinigung" don't.
    if isConsumable and name and subclassID ~= SUB.Potion and subclassID ~= SUB.Elixir
       and subclassID ~= SUB.Flasksphials
       and (CM.MatchesAny(name, L["PATTERN_EDGED"]) or CM.MatchesAny(name, L["PATTERN_BLUNT"])
            or CM.MatchesWordEnd(" " .. name, L["PATTERN_ENHANCE"])) then
        return "weaponenhance"
    end

    if not isConsumable then return nil end
    if subclassID == SUB.Potion then return "potion" end
    if subclassID == SUB.Elixir then return CM.GetTabInfo("elixir") and "elixir" or "flask" end
    if subclassID == SUB.Flasksphials then return "flask" end
    if subclassID == SUB.Itemenhancement then return "weaponenhance" end
    return nil
end

-- Tabs an item is added to. A catalog item goes to every tab that lists it (a potion that
-- restores health and mana: Heal Pots and Mana Pots; the macro uses it once). Buff Food
-- and Food/Drink never share an item: food with a buff is only Buff Food. A poison goes to
-- one list only, see below.
-- Other items go to the tab GetTargetTabForItem names; Forever food that restores health
-- goes to Food, mana to Drink, both to both lists, and where the tooltip doesn't say,
-- the open list is kept.
function CM.GetTargetTabsForItem(itemID)
    local listed = CM.GetCatalogTabs(itemID)
    if listed then
        -- a poison fits either hand: the list being edited, else Poison 1
        if listed[1] == "poison" and listed[2] == "poisonoff" then
            return { CM.activeTab == "poisonoff" and "poisonoff" or "poison" }
        end
        return listed
    end

    local tab = CM.GetTargetTabForItem(itemID)
    if tab == "food" or tab == "drink" then
        local kind = GetRestoreKind(itemID)
        if kind == "health" then return { "food" } end
        if kind == "mana"   then return { "drink" } end
        if kind == "both"   then return { "food", "drink" } end
    elseif tab == "healpotion" and GetRestoreKind(itemID) == "both" then
        return { "healpotion", "manapotion" }
    end
    return tab and { tab } or nil
end

-- ── Data Mutation ──────────────────────────────────────────────────────────────
-- Appends the item to the list of `tab`; false if it is already in it.
function CM.AddItemToTab(itemID, tab)
    local items = CM.db[tab].items
    if CM.ListHasItem(items, itemID) then return false end
    tinsert(items, { id = itemID })
    return true
end

function CM.AddItemToDatabase(itemID)
    if not itemID then return end
    if CM.BlockedByCombat() then return end

    local itemObj = Item:CreateFromItemID(itemID)
    itemObj:ContinueOnItemLoad(function()
        local id = itemObj:GetItemID()
        if not id or not CM.db then return end

        local targetTabs = CM.GetTargetTabsForItem(id)
        if targetTabs then
            -- don't put an item where this character can't see it at all
            local visible = false
            for _, tab in ipairs(targetTabs) do
                if not CM.IsTabHidden(tab) then visible = true end
            end
            if not visible then
                CM.ShowError(CM.L["ERR_NO_MANAPOTION"])
                return
            end

            local added = {}
            for _, tab in ipairs(targetTabs) do
                if CM.AddItemToTab(id, tab) then tinsert(added, tab) end
            end
            if #added == 0 then return end
            for _, tab in ipairs(added) do
                if not CM.IsTabHidden(tab) then CM.activeTab = tab break end
            end
            CM.RefreshList()
            for _, tab in ipairs(added) do CM.UpdateMacro(tab) end  -- an item for two tabs changes two macros
        else
            CM.ShowError(CM.L["ERROR_INVALID_ITEM"])
        end
    end)
end
