-- ConsumableMacro Items
local CM = ConsumableMacroAddon

-- ── Item Classification ────────────────────────────────────────────────────────
CM.HEALTHSTONE_IDS = {
    [5512]   = true,  -- Healthstone
    [224464] = true,  -- Demonic Healthstone (Pact of Gluttony)
}

-- Whetstones ("edged"), Weightstones ("blunt") and oils ("any"), one entry per
-- quality tier. Name matching was unreliable for these, so the IDs are listed
-- explicitly; add new tiers here as they turn up.
CM.WEAPONENHANCE_IDS = {
    [237367] = "blunt",  -- Glänzender Gewichtstein / Refulgent Weightstone (rank 1)
    [237369] = "blunt",  -- Glänzender Gewichtstein / Refulgent Weightstone (rank 2)
    [237370] = "edged",  -- Glänzender Schleifstein / Refulgent Whetstone (rank 1)
    [237371] = "edged",  -- Glänzender Schleifstein / Refulgent Whetstone (rank 2)
    [243733] = "any",    -- Thalassisches Phönixöl / Thalassian Phoenix Oil (rank 1)
    [243734] = "any",    -- Thalassisches Phönixöl / Thalassian Phoenix Oil (rank 2)
    [243735] = "any",    -- Oil of Dawn (rank 1)
    [243736] = "any",    -- Oil of Dawn (rank 2)
    [243737] = "any",    -- Smuggler's Enchanted Edge (rank 1)
    [243738] = "any",    -- Smuggler's Enchanted Edge (rank 2)
}

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

-- Tab key for an item ID, or nil if it fits none. ID lists win, then the name
-- patterns, then the class/subclass fallback.
function CM.GetTargetTabForItem(targetID)
    if not targetID then return nil end
    local L = CM.L

    if CM.HEALTHSTONE_IDS[targetID] then return "healthstone" end
    if CM.WEAPONENHANCE_IDS[targetID] then return "weaponenhance" end

    -- Class IDs come without an item data load; the name may still be missing for
    -- very recent items, in which case only the class checks apply.
    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(targetID)
    local name = C_Item.GetItemNameByID(targetID)
    name = name and name:lower()

    local isConsumable = classID == CLASS_CONSUMABLE
    -- Forever: drinks are mostly "... Water" / "... Tea", which the exclude list below
    -- would reject, so food and drink are decided by their subclass first.
    if CM.IS_FOREVER and isConsumable and subclassID == SUB.Fooddrink then return GetForeverFoodTab() end

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

    if not isConsumable then return nil end
    if subclassID == SUB.Potion then return "potion" end
    if subclassID == SUB.Elixir or subclassID == SUB.Flasksphials then return "flask" end
    if subclassID == SUB.Itemenhancement then return "weaponenhance" end
    return nil
end

-- Tabs an item is added to: normally the one GetTargetTabForItem names. Forever: food
-- that restores health goes to Food, mana to Drink, both to both lists (the macro uses
-- such an item once); where the tooltip doesn't say, the open list is kept.
function CM.GetTargetTabsForItem(itemID)
    local tab = CM.GetTargetTabForItem(itemID)
    if tab == "food" or tab == "drink" then
        local kind = GetRestoreKind(itemID)
        if kind == "health" then return { "food" } end
        if kind == "mana"   then return { "drink" } end
        if kind == "both"   then return { "food", "drink" } end
    end
    return tab and { tab } or nil
end

-- ── Data Mutation ──────────────────────────────────────────────────────────────
function CM.AddItemToDatabase(itemID)
    if not itemID then return end
    if InCombatLockdown() then
        CM.ShowError(CM.L["ERR_COMBAT"])
        return
    end

    local itemObj = Item:CreateFromItemID(itemID)
    itemObj:ContinueOnItemLoad(function()
        local id = itemObj:GetItemID()
        if not id or not CM.db then return end

        local targetTabs = CM.GetTargetTabsForItem(id)
        if targetTabs then
            local added = {}
            for _, tab in ipairs(targetTabs) do
                local known = false
                for _, existing in ipairs(CM.db[tab].items) do
                    if existing.id == id then known = true end
                end
                if not known then
                    tinsert(CM.db[tab].items, { id = id })
                    tinsert(added, tab)
                end
            end
            if #added == 0 then return end
            CM.activeTab = added[1]
            CM.RefreshList()
            CM.UpdateMacro(added[1])
        else
            CM.ShowError(CM.L["ERROR_INVALID_ITEM"])
        end
    end)
end

function CM.OnRowButtonClick(self)
    if InCombatLockdown() or not CM.db then return end
    local parent  = self:GetParent()
    local index   = parent.index
    local items   = CM.db[CM.activeTab].items
    local item    = items[index]

    if self.action == "delete" then
        tremove(items, index)
    elseif self.action == "up" and index > 1 then
        tremove(items, index)
        tinsert(items, index - 1, item)
    elseif self.action == "down" and index < #items then
        tremove(items, index)
        tinsert(items, index + 1, item)
    else
        return
    end

    CM.RefreshList()
    CM.UpdateMacro(CM.activeTab)
end

-- ── Import / Export ────────────────────────────────────────────────────────────
-- Format: CM:1:flask=191534,191533:potion=191338:healpotion=191380:bufffood=197784
-- Tabs without items are omitted; item order is priority order.

-- filter: optional { [tabKey] = true } - only those tabs (default: all tabs with items).
function CM.ExportString(filter)
    if not CM.db then return "" end
    local parts = {}
    for _, t in ipairs(CM.TABS) do
        if not filter or filter[t.key] then
            local items = CM.db[t.key] and CM.db[t.key].items or {}
            if #items > 0 then
                local ids = {}
                for _, item in ipairs(items) do
                    tinsert(ids, tostring(item.id))
                end
                tinsert(parts, t.key .. "=" .. table.concat(ids, ","))
            end
        end
    end
    return "CM:1:" .. table.concat(parts, ":")
end

-- Returns { [tabKey] = { {id=n}, ... } } or nil if the string is invalid.
function CM.ParseImportString(str)
    if type(str) ~= "string" then return nil end
    str = str:trim()
    if not str:match("^CM:1:") then return nil end

    local validKeys = {}
    for _, t in ipairs(CM.TABS) do validKeys[t.key] = true end

    local result = {}
    -- the sentinel ":" makes the last segment match too
    for segment in (str:sub(6) .. ":"):gmatch("([^:]*):") do
        if segment ~= "" then
            local key, idList = segment:match("^([^=]+)=(.*)$")
            if key and validKeys[key] then
                result[key] = {}
                local seen = {}
                for idStr in (idList .. ","):gmatch("([^,]*),") do
                    local id = tonumber(idStr)
                    if id and id > 0 and id == math.floor(id) and not seen[id] then
                        seen[id] = true
                        tinsert(result[key], { id = id })
                    end
                end
            end
        end
    end
    return next(result) and result or nil
end

-- Empties the item lists of the tabs in filter (default: all) and rebuilds the macros.
function CM.ClearTabs(filter)
    if not CM.db then return end
    for _, t in ipairs(CM.TABS) do
        if not filter or filter[t.key] then CM.db[t.key].items = {} end
    end
    CM.UpdateAllMacros()
    CM.RefreshList()
end

-- Overwrites the item lists of the tabs in `parsed` (optionally only those in filter)
-- and rebuilds the macros.
function CM.ApplyImport(parsed, filter)
    if not CM.db or not parsed then return end
    for _, t in ipairs(CM.TABS) do
        if parsed[t.key] and (not filter or filter[t.key]) then
            -- keep restock settings of IDs that are already in this tab
            local old = {}
            for _, it in ipairs(CM.db[t.key].items or {}) do old[it.id] = it end
            for _, it in ipairs(parsed[t.key]) do
                local prev = old[it.id]
                if prev then it.restock = prev.restock; it.target = prev.target; it.minCount = prev.minCount end
            end
            CM.db[t.key].items = parsed[t.key]
        end
    end
    CM.UpdateAllMacros()
    CM.RefreshList()
end
