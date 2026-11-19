-- ConsumableMacro Catalog window
-- Side window next to the main window: the catalog of the open tab (Data\Catalog*.lua) as
-- a searchable list. A click adds the item to that tab's list.
local CM = ConsumableMacroAddon

local ROW_H, WIDTH = 28, 400

local requested = {}  -- item IDs whose data was asked for (the name arrives later)
-- reused by every refresh: [id] = name; the rows to show (an item ID, or the locale key of
-- a group heading); [heading] = how many items follow it; the IDs of the group being filled
local names, list, counts, bucket = {}, {}, {}, {}

local function OnRowClick(self)
    if type(self.itemID) ~= "number" or self.inList or CM.BlockedByCombat() then return end
    local tab = CM.activeTab
    if CM.AddItemToTab(self.itemID, tab) then
        CM.RefreshList()  -- also refreshes this window
        CM.UpdateMacro(tab)
    end
end

local function CreateRow(f, i)
    local row = CreateFrame("Button", nil, f.content)
    row:SetHeight(ROW_H - 2)
    row:SetPoint("TOPLEFT",  0, -(i - 1) * ROW_H)
    row:SetPoint("TOPRIGHT", 0, -(i - 1) * ROW_H)
    CM.AddRowBackground(row)
    row:SetHighlightTexture("Interface\\Buttons\\UI-Listbox-Highlight2", "ADD")

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(22, 22)
    row.icon:SetPoint("LEFT", 4, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.status:SetPoint("RIGHT", -6, 0)
    row.status:SetJustifyH("RIGHT")

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.text:SetPoint("RIGHT", row.status, "LEFT", -6, 0)
    row.text:SetJustifyH("LEFT")
    row.text:SetWordWrap(false)

    row:SetScript("OnClick", OnRowClick)
    row:SetScript("OnEnter", function(s) CM.ShowItemTooltip(s, s.itemID) end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return row
end

-- Named items first, alphabetically (the client's language); ranks of one item stay together.
local function ByName(a, b)
    local na, nb = names[a], names[b]
    if na and nb then
        if na ~= nb then return na < nb end
        return a < b
    end
    if na ~= nb then return na ~= nil end
    return a < b
end

-- Group heading: gold label and the number of items, no icon, not clickable.
local function ShowHeading(row, key)
    row.itemID, row.inList = nil, false
    row:EnableMouse(false)
    row.icon:Hide()
    row.text:ClearAllPoints()
    row.text:SetPoint("LEFT", 8, 0)
    row.text:SetPoint("RIGHT", row.status, "LEFT", -6, 0)
    row.text:SetText(("%s |cff888888(%d)|r"):format(CM.L[key], counts[key]))
    row.text:SetTextColor(1, 0.82, 0)
    row.status:SetText("")
end

local function ShowItem(row, id, listed)
    local inBags = CM.IsInBags(id)
    row.itemID, row.inList = id, listed
    row:EnableMouse(true)
    row.icon:Show()
    row.icon:SetTexture(CM.GetItemIcon(id))
    row.icon:SetDesaturated(listed)
    row.text:ClearAllPoints()
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.text:SetPoint("RIGHT", row.status, "LEFT", -6, 0)
    row.text:SetText(CM.RankMarkup(id) .. (CM.L["ITEM_LABEL"]):format(names[id] or (CM.L["ITEM_LOADING"]):format(id), id))
    local shade = listed and 0.45 or (inBags and 1 or 0.75)
    row.text:SetTextColor(shade, shade, shade)
    if listed then
        row.status:SetText(CM.L["CATALOG_IN_LIST"]); row.status:SetTextColor(0.5, 0.5, 0.5)
    elseif inBags then
        row.status:SetText(CM.L["IN_BAGS"]); row.status:SetTextColor(0, 1, 0)
    else
        row.status:SetText("")
    end
end

function CM.RefreshCatalog()
    local f = CM.catalogFrame
    if not f or not f:IsShown() or not CM.db then return end
    local tab = CM.activeTab
    local info = CM.GetTabInfo(tab)
    if info then
        f.tabLabel:SetText(CM.L[info.tabL] or tab)
        f.tabLabel:SetTextColor(unpack(info.color))
    end

    local inList = {}
    for _, item in ipairs(CM.db[tab].items) do inList[item.id] = true end

    local query = strtrim(f.search:GetText()):lower()
    local onlyBags = f.bagsChk:GetChecked()
    wipe(names); wipe(list); wipe(counts)
    local shown = 0
    for _, group in ipairs(CM.GetCatalogGroups(tab)) do
        wipe(bucket)
        for _, id in ipairs(group.items) do
            local name = C_Item.GetItemNameByID(id)
            if not name and not requested[id] then
                requested[id] = true
                C_Item.RequestLoadItemDataByID(id)
            end
            if (not onlyBags or CM.IsInBags(id))
               and (query == "" or (name and name:lower():find(query, 1, true)) or tostring(id):find(query, 1, true)) then
                names[id] = name
                bucket[#bucket + 1] = id
            end
        end
        if #bucket > 0 then
            table.sort(bucket, ByName)
            if group.name then
                counts[group.name] = #bucket
                list[#list + 1] = group.name
            end
            for _, id in ipairs(bucket) do list[#list + 1] = id end
            shown = shown + #bucket
        end
    end
    local total = #CM.GetCatalogItems(tab)
    f.countLabel:SetText(("(%d / %d)"):format(shown, total))

    for i, entry in ipairs(list) do
        local row = f.rows[i]
        if not row then
            row = CreateRow(f, i)
            f.rows[i] = row
        end
        if type(entry) == "string" then ShowHeading(row, entry) else ShowItem(row, entry, inList[entry] == true) end
        row:Show()
    end
    for i = #list + 1, #f.rows do
        f.rows[i]:Hide()
        f.rows[i].itemID = nil
    end
    f.content:SetHeight(math.max(1, #list * ROW_H))
    f.emptyLabel:SetShown(total == 0)
end

local function BuildCatalogFrame()
    if CM.catalogFrame then return CM.catalogFrame end
    local L = CM.L

    local f = CM.CreateWindow("CMCatalogFrame")
    f:SetSize(WIDTH, CM.mainFrame:GetHeight())
    f.TitleText:SetText(L["CATALOG_TITLE"])
    f.rows = {}

    f.tabLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.tabLabel:SetPoint("TOPLEFT", 14, -34)
    f.countLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.countLabel:SetPoint("LEFT", f.tabLabel, "RIGHT", 6, 0)
    f.countLabel:SetTextColor(0.5, 0.5, 0.5)

    f.descLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.descLbl:SetPoint("TOPLEFT", f.tabLabel, "BOTTOMLEFT", 0, -4)
    f.descLbl:SetPoint("TOPRIGHT", -14, -52)
    f.descLbl:SetJustifyH("LEFT")
    f.descLbl:SetTextColor(0.65, 0.65, 0.65)
    f.descLbl:SetText(L["CATALOG_DESC"])

    local searchLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    searchLbl:SetPoint("TOPLEFT", 14, -86)
    searchLbl:SetText(L["CATALOG_SEARCH"])

    f.search = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    f.search:SetSize(160, 22)
    f.search:SetPoint("LEFT", searchLbl, "RIGHT", 12, 0)
    f.search:SetAutoFocus(false)
    f.search:SetScript("OnTextChanged", function() CM.RefreshCatalog() end)
    f.search:SetScript("OnEnterPressed", f.search.ClearFocus)
    f.search:SetScript("OnEscapePressed", function(self)
        if self:GetText() ~= "" then self:SetText("") else self:ClearFocus() end
    end)

    f.bagsChk = CM.CreateCheckbox(f, L["CATALOG_ONLY_BAGS"], 10, -110)
    f.bagsChk:SetScript("OnClick", function() CM.RefreshCatalog() end)

    f.scrollBg = CreateFrame("Frame", nil, f, "InsetFrameTemplate")
    f.scrollBg:SetPoint("TOPLEFT",     10, -142)
    f.scrollBg:SetPoint("BOTTOMRIGHT", -10, 12)
    f.scroll = CM.CreateScrollFrame(f.scrollBg)
    f.content = CreateFrame("Frame", nil, f.scroll)
    f.content:SetHeight(1)
    CM.FitScrollFrame(f.scroll, f.scrollBg, f.content, 4)

    f.emptyLabel = f.scrollBg:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    f.emptyLabel:SetPoint("CENTER")
    f.emptyLabel:SetText(L["CATALOG_EMPTY"])
    f.emptyLabel:Hide()

    -- names arrive after the item data loads; coalesce the burst into one refresh
    f:SetScript("OnEvent", function() CM.Defer("catalogRefresh", CM.RefreshCatalog, 0.2) end)
    f:SetScript("OnShow", function(self) self:RegisterEvent("GET_ITEM_INFO_RECEIVED") end)
    f:SetScript("OnHide", function(self) self:UnregisterEvent("GET_ITEM_INFO_RECEIVED") end)

    CM.catalogFrame = f
    return f
end

-- Opens the window right of Options (or of the main window), closes it again if shown.
function CM.ToggleCatalogFrame()
    local f = BuildCatalogFrame()
    if f:IsShown() then
        f:Hide()
        return
    end
    local o = CM.optionsFrame
    f:ClearAllPoints()
    f:SetPoint("LEFT", (o and o:IsShown()) and o or CM.mainFrame, "RIGHT", 8, 0)
    f.search:SetText("")
    CM.HideSidePanels("catalogFrame")
    f:Show()
    CM.RefreshCatalog()
    CM.ApplyElvUISkin()
end
