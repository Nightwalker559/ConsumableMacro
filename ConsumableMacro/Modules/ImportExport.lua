-- ConsumableMacro Import / Export
-- Item lists as a text string (export), parsed and applied to a profile (import), and the
-- bulk operations on whole lists (clear, overwrite).
local CM = ConsumableMacroAddon

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
