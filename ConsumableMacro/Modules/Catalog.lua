-- ConsumableMacro Catalog lookup
-- Reads the item catalog of the running client (Data\CatalogRetail.lua or
-- Data\CatalogForever.lua): which tabs an item ID belongs to, and the item list of a tab.
local CM = ConsumableMacroAddon

CM.CATALOG = CM.CATALOG or {}                        -- [tab key] = { item IDs }
CM.WEAPONENHANCE_IDS = CM.WEAPONENHANCE_IDS or {}    -- [item ID] = "edged" | "blunt" | "any"

local tabsOfItem   -- [item ID] = { tab keys in CM.TABS order }, built on first use
local weaponIDs    -- sorted IDs of CM.WEAPONENHANCE_IDS

local function Index()
    tabsOfItem = {}
    weaponIDs = {}
    for id in pairs(CM.WEAPONENHANCE_IDS) do weaponIDs[#weaponIDs + 1] = id end
    table.sort(weaponIDs)

    for _, tab in ipairs(CM.TABS) do
        for _, id in ipairs(CM.GetCatalogItems(tab.key)) do
            local keys = tabsOfItem[id]
            if not keys then keys = {}; tabsOfItem[id] = keys end
            keys[#keys + 1] = tab.key
        end
    end
end

-- Item IDs of a tab's catalog (empty if the tab has none). Do not modify the result.
function CM.GetCatalogItems(tabKey)
    if tabKey == "weaponenhance" then
        if not weaponIDs then Index() end
        return weaponIDs
    end
    return CM.CATALOG[tabKey] or {}
end

-- Tab keys whose catalog lists the item, in tab order; nil if the item is in none.
function CM.GetCatalogTabs(itemID)
    if not tabsOfItem then Index() end
    return tabsOfItem[itemID]
end
