-- ConsumableMacro Catalog lookup
-- Reads the item catalog of the running client (Data\CatalogRetail.lua or
-- Data\CatalogForever.lua): which tabs an item ID belongs to, and the items of a tab.
-- A tab's catalog is either a plain ID list or split into groups (Retail: Midnight / The
-- War Within, CM.CATALOG_GROUPS), which the catalog window shows under headings.
local CM = ConsumableMacroAddon

CM.CATALOG = CM.CATALOG or {}                        -- [tab key] = { IDs } or { [group key] = { IDs } }
CM.CATALOG_GROUPS = CM.CATALOG_GROUPS or {}          -- ordered { key, name = locale key }
CM.WEAPONENHANCE_IDS = CM.WEAPONENHANCE_IDS or {}    -- [item ID] = "edged" | "blunt" | "any"

local groupsOfTab = {}  -- [tab key] = { { key, name, items } }, built on first use
local itemsOfTab  = {}  -- [tab key] = { IDs of all groups }
local tabsOfItem        -- [item ID] = { tab keys in CM.TABS order }

local function BuildTab(tabKey)
    local src = CM.CATALOG[tabKey]
    if not src and tabKey == "weaponenhance" then  -- no list of its own: the IDs of the type map
        src = {}
        for id in pairs(CM.WEAPONENHANCE_IDS) do src[#src + 1] = id end
        table.sort(src)
    end

    local groups, flat = {}, {}
    if src and type(src[1]) == "number" then
        groups[1] = { items = src }
    elseif src then
        for _, g in ipairs(CM.CATALOG_GROUPS) do
            if src[g.key] then groups[#groups + 1] = { key = g.key, name = g.name, items = src[g.key] } end
        end
    end
    for _, g in ipairs(groups) do
        for _, id in ipairs(g.items) do flat[#flat + 1] = id end
    end
    groupsOfTab[tabKey], itemsOfTab[tabKey] = groups, flat
end

-- The catalog of a tab as groups { key, name, items }; a plain list is one group without
-- key. Empty if the tab has no catalog. Do not modify the result.
function CM.GetCatalogGroups(tabKey)
    if not groupsOfTab[tabKey] then BuildTab(tabKey) end
    return groupsOfTab[tabKey]
end

-- Item IDs of a tab's catalog, all groups together.
function CM.GetCatalogItems(tabKey)
    if not itemsOfTab[tabKey] then BuildTab(tabKey) end
    return itemsOfTab[tabKey]
end

-- Tab keys whose catalog lists the item, in tab order; nil if the item is in none.
function CM.GetCatalogTabs(itemID)
    if not tabsOfItem then
        tabsOfItem = {}
        for _, tab in ipairs(CM.TABS) do
            for _, id in ipairs(CM.GetCatalogItems(tab.key)) do
                local keys = tabsOfItem[id]
                if not keys then keys = {}; tabsOfItem[id] = keys end
                keys[#keys + 1] = tab.key
            end
        end
    end
    return tabsOfItem[itemID]
end
