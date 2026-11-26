-- ConsumableMacro Catalog window
-- Side window next to the main window: the catalog of the open tab (Data\Catalog*.lua) as
-- a searchable list. A click adds the item to that tab's list.
local CM = ConsumableMacroAddon

local ROW_H, WIDTH = 28, 400

local requested = {}  -- item IDs whose data was asked for (the name arrives later)
-- reused by every refresh: [id] = name; the rows to show (an item ID, or the locale key of
-- a group heading); [heading] = how many items follow it; the IDs of the group being filled
local names, list, counts, bucket = {}, {}, {}, {}
local headings  -- [heading name] = group key

-- Folded groups, by group key: kept account-wide, so a group folded in one tab stays folded
-- in the others.
local function Collapsed()
    local root = _G.ConsumableMacroDB
    if not root then return {} end
    root.catalogCollapsed = root.catalogCollapsed or {}
    return root.catalogCollapsed
end

local function OnRowClick(self)
    if type(self.groupKey) == "string" then  -- a heading folds or unfolds its group
        local folded = Collapsed()
        folded[self.groupKey] = not folded[self.groupKey] or nil
        CM.RefreshCatalog()
        return
    end
    if type(self.itemID) ~= "number" or self.inList or CM.GetMissingLevel(self.itemID) or CM.BlockedByCombat() then return end
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

    row.icon = CM.CreateRowIcon(row, 22)
    row.icon:SetPoint("LEFT", 4, 0)

    -- fold marker of a heading: a real button (without mouse, the row takes the click) so
    -- that ElvUI's collapse skin can restyle its +/- texture
    row.arrow = CreateFrame("Button", nil, row)
    row.arrow:SetSize(16, 16)
    row.arrow:SetPoint("LEFT", 6, 0)
    row.arrow:EnableMouse(false)
    row.arrow:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
    row.arrow:Hide()
    CM.SkinCollapseButton(row.arrow)

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

-- Group heading: fold marker, gold label and the number of items; a click folds the group.
local function ShowHeading(row, name, groupKey, folded)
    row.itemID, row.inList, row.groupKey = nil, false, groupKey
    row:EnableMouse(true)
    row.icon:Hide()
    row.arrow:SetNormalTexture(folded and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
    row.arrow:Show()
    row.text:ClearAllPoints()
    row.text:SetPoint("LEFT", 26, 0)
    row.text:SetPoint("RIGHT", row.status, "LEFT", -6, 0)
    row.text:SetText(("%s |cff888888(%d)|r"):format(CM.L[name], counts[name]))
    row.text:SetTextColor(1, 0.82, 0)
    row.status:SetText("")
end

local function ShowItem(row, id, listed)
    local inBags = CM.IsInBags(id)
    row.itemID, row.inList, row.groupKey = id, listed, nil
    row:EnableMouse(true)
    row.arrow:Hide()
    row.icon:Show()
    row.icon:SetTexture(CM.GetItemIcon(id))
    row.icon:SetDesaturated(listed)
    row.text:ClearAllPoints()
    row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.text:SetPoint("RIGHT", row.status, "LEFT", -6, 0)
    row.text:SetText(CM.RankMarkup(id) .. (CM.L["ITEM_LABEL"]):format(names[id] or (CM.L["ITEM_LOADING"]):format(id), id))
    -- an item above the player's level is red and can't be added
    local needLevel = not listed and CM.GetMissingLevel(id)
    if needLevel then
        row.text:SetTextColor(1, 0.2, 0.2)
        row.status:SetText((CM.L["CATALOG_NEEDS_LEVEL"]):format(needLevel)); row.status:SetTextColor(1, 0.2, 0.2)
        return
    end
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
    local folded = Collapsed()
    headings = headings or {}
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
            local fold = group.name and folded[group.key] and query == ""  -- a search unfolds, to show every hit
            if group.name then
                counts[group.name] = #bucket
                headings[group.name] = group.key
                list[#list + 1] = group.name
            end
            if not fold then
                for _, id in ipairs(bucket) do list[#list + 1] = id end
            end
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
        if type(entry) == "string" then
            ShowHeading(row, entry, headings[entry], folded[headings[entry]] and query == "")
        else ShowItem(row, entry, inList[entry] == true)
        end
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

    f.descLbl = CM.CreateHint(f)
    f.descLbl:SetPoint("TOPLEFT", f.tabLabel, "BOTTOMLEFT", 0, -4)
    f.descLbl:SetPoint("TOPRIGHT", -14, -52)
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
    f.scrollBg:SetPoint("BOTTOMRIGHT", -10, 70)
    f.scroll = CM.CreateScrollFrame(f.scrollBg)
    f.content = CreateFrame("Frame", nil, f.scroll)
    f.content:SetHeight(1)
    CM.FitScrollFrame(f.scroll, f.scrollBg, f.content, 4)

    f.emptyLabel = f.scrollBg:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    f.emptyLabel:SetPoint("CENTER")
    f.emptyLabel:SetText(L["CATALOG_EMPTY"])
    f.emptyLabel:Hide()

    -- items the catalog doesn't know yet (new patch, other client): add them by item ID
    local idTip = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    idTip:SetPoint("BOTTOMLEFT", 14, 42)
    idTip:SetPoint("BOTTOMRIGHT", -14, 42)
    idTip:SetJustifyH("LEFT")
    idTip:SetText(L["CATALOG_ID_TIP"])

    local idLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    idLabel:SetPoint("BOTTOMLEFT", 14, 17)
    idLabel:SetText(L["CATALOG_ID_LABEL"])

    f.idBox = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
    f.idBox:SetSize(120, 22)
    f.idBox:SetPoint("LEFT", idLabel, "RIGHT", 12, 0)
    f.idBox:SetAutoFocus(false)
    f.idBox:SetNumeric(true)
    local function AddByID()
        local id = tonumber(f.idBox:GetText())
        if id then CM.AddItemToDatabase(id); f.idBox:SetText("") end
        f.idBox:ClearFocus()
    end
    f.idBox:SetScript("OnEnterPressed", AddByID)
    f.idBox:SetScript("OnEscapePressed", f.idBox.ClearFocus)

    f.idAddBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.idAddBtn:SetSize(100, 22)
    f.idAddBtn:SetText(L["BTN_ADD"])
    f.idAddBtn:SetPoint("LEFT", f.idBox, "RIGHT", 5, 0)
    f.idAddBtn:SetScript("OnClick", AddByID)

    -- names arrive after the item data loads; coalesce the burst into one refresh
    f:SetScript("OnEvent", function() CM.Defer("catalogRefresh", CM.RefreshCatalog, 0.2) end)
    f:SetScript("OnShow", function(self) self:RegisterEvent("GET_ITEM_INFO_RECEIVED") end)
    f:SetScript("OnHide", function(self) self:UnregisterEvent("GET_ITEM_INFO_RECEIVED") end)

    CM.catalogFrame = f
    return f
end

-- Options calls this when it opens and closes, so an open catalog window never overlaps it.
function CM.AnchorCatalogFrame()
    if CM.catalogFrame then CM.AnchorSidePanel(CM.catalogFrame) end
end

-- Opens the window, closes it again if shown.
function CM.ToggleCatalogFrame()
    local f = BuildCatalogFrame()
    if f:IsShown() then
        f:Hide()
        return
    end
    CM.AnchorCatalogFrame()
    f.search:SetText("")
    CM.HideSidePanels("catalogFrame")
    f:Show()
    CM.RefreshCatalog()
    CM.ApplyElvUISkin()
end
