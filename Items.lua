-- ConsumableMacro Items
local CM = ConsumableMacroAddon

-- ── Item Classification ────────────────────────────────────────────────────────
-- Known Healthstone item IDs across expansions
CM.HEALTHSTONE_IDS = {
    [5512]   = true,  -- Classic Healthstone
    [224464] = true,  -- Demonic Healthstone (Midnight 12.0+)
}

-- Known Whetstone ("edged") / Weightstone ("blunt") item IDs, one entry per
-- quality tier. Name-based detection turned out unreliable for these (locale-
-- dependent, and some Midnight items didn't match even the right pattern) -
-- an explicit ID list is deterministic and works in any client language.
-- Add further quality-tier IDs here as they turn up in-game.
CM.WEAPONENHANCE_IDS = {
    [237367] = "blunt",  -- Glänzender Gewichtstein / Refulgent Weightstone (rank 1)
    [237369] = "blunt",  -- Glänzender Gewichtstein / Refulgent Weightstone (rank 2)
    [237370] = "edged",  -- Glänzender Schleifstein / Refulgent Whetstone (rank 1)
    [237371] = "edged",  -- Glänzender Schleifstein / Refulgent Whetstone (rank 2)
    [243733] = "any",    -- Thalassisches Phönixöl / Thalassian Phoenix Oil (rank 1)
    [243734] = "any",    -- Thalassisches Phönixöl / Thalassian Phoenix Oil (rank 2)
}

function CM.GetTargetTabForItem(targetID)
    if not targetID then return nil end
    local L = CM.L

    -- Direct ID match for soulbound items like Healthstones, and for
    -- Whetstone/Weightstone (see CM.WEAPONENHANCE_IDS - name-based detection
    -- for those turned out unreliable, an ID list works in any language)
    if CM.HEALTHSTONE_IDS[targetID] then return "healthstone" end
    if CM.WEAPONENHANCE_IDS[targetID] then return "weaponenhance" end

    -- GetItemInfoInstant: 7 returns – classID=[6], subclassID=[7]. Unlike the
    -- name, this needs no data load and is always available immediately.
    local _, _, _, _, _, classID, subclassID = C_Item.GetItemInfoInstant(targetID)
    local name = C_Item.GetItemNameByID(targetID)

    -- Name-based checks only run once the name is actually cached - some very
    -- recent items report a nil name for a while even via ContinueOnItemLoad.
    -- Without a name we fall straight through to the classID/subclassID
    -- checks below instead of bailing out as "invalid".
    if name then
        name = name:lower()
        if CM.MatchesAny(name, L["PATTERN_EXCLUDE"])     then return nil end
        if CM.MatchesAny(name, L["PATTERN_HEALTHSTONE"]) then return "healthstone" end
        if CM.MatchesAny(name, L["PATTERN_FLASK"])       then return "flask" end
        if CM.MatchesAny(name, L["PATTERN_HEAL"])        then return "healpotion" end
    end

    if classID == 0 and subclassID == 5 then return "bufffood" end
    if classID == 0 and subclassID == 1 then return "potion" end
    if classID == 0 and subclassID == 3 then return "flask" end
    if classID == 0 and subclassID == 2 then return "flask" end
    -- "Item Enhancement" subclass - fallback for anything not caught by name above
    if classID == 0 and subclassID == 6 then return "weaponenhance" end

    return nil
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

        local targetTab = CM.GetTargetTabForItem(id)
        if targetTab then
            for _, existing in ipairs(CM.db[targetTab].items) do
                if existing.id == id then return end
            end
            tinsert(CM.db[targetTab].items, { id = id })
            CM.activeTab = targetTab
            if CM.mainFrame and CM.mainFrame:IsShown() then CM.RefreshList() end
            CM.UpdateMacro(targetTab)
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
-- Tabs with no items are omitted. All tabs including healthstone are supported.
-- Item order reflects priority (index 1 = highest priority).

-- filter: optional { [tabKey] = true } — only include those tabs.
-- If nil, all tabs with items are exported.
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
    str = str:match("^%s*(.-)%s*$")  -- trim whitespace
    if not str:match("^CM:1:") then return nil end

    local validKeys = {}
    for _, t in ipairs(CM.TABS) do validKeys[t.key] = true end

    local result = {}
    -- append sentinel ":" so the last segment is captured by the pattern
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

-- Empties the item lists of the tabs in filter (all tabs if nil) and rebuilds
-- the macros.
function CM.ClearTabs(filter)
    if not CM.db then return end
    for _, t in ipairs(CM.TABS) do
        if not filter or filter[t.key] then CM.db[t.key].items = {} end
    end
    CM.UpdateAllMacros()
    if CM.mainFrame and CM.mainFrame:IsShown() then CM.RefreshList() end
end

-- Overwrites item lists for tabs present in parsed and selected by filter,
-- then rebuilds macros.
-- filter: optional { [tabKey] = true } — only apply those tabs.
-- If nil, all tabs present in parsed are applied.
function CM.ApplyImport(parsed, filter)
    if not CM.db or not parsed then return end
    for _, t in ipairs(CM.TABS) do
        if parsed[t.key] and (not filter or filter[t.key]) then
            -- keep restock settings for IDs that already exist in this tab
            local old = {}
            for _, it in ipairs(CM.db[t.key].items or {}) do old[it.id] = it end
            for _, it in ipairs(parsed[t.key]) do
                local prev = old[it.id]
                if prev then it.restock = prev.restock; it.target = prev.target end
            end
            CM.db[t.key].items = parsed[t.key]
        end
    end
    CM.UpdateAllMacros()
    if CM.mainFrame and CM.mainFrame:IsShown() then CM.RefreshList() end
end
