-- ConsumableMacro Restock
-- Per-item restock targets. A small panel next to the Auction House lists
-- every ticked item that is below its target amount; clicking a row searches
-- for it (Auctionator if present, otherwise the default Blizzard AH).
-- Item entries in CM.db[tab].items: { id = n, restock = bool, target = n, minCount = n }
-- minCount (optional) gates when the item shows up in the AH panel: only once
-- have <= minCount, instead of as soon as have < target. 0/empty falls back to
-- the tab's minCount (Options).
local CM = ConsumableMacroAddon

local ROW_H     = 28   -- AH panel row height
local MAX_ROWS  = 12   -- AH panel row cap (rest is summarised as "+N more")
local CFG_ROW_H = 26   -- config frame row height
local CFG_ROW_W = 360  -- config frame row width
local CFG_BOX_W = 40   -- target/min edit box width

-- AH state (reset on every AH visit)
local ahOpen    = false
local dismissed = false  -- panel closed via X for this AH visit

-- ── Helpers ────────────────────────────────────────────────────────────────────
local function GetHave(itemID)
    local rs = CM.db and CM.db.restock
    local withBank = rs and rs.countBank or false
    -- GetItemCount(item, includeBank, includeUses, includeReagentBank, includeAccountBank)
    return C_Item.GetItemCount(itemID, withBank, false, withBank, withBank) or 0
end

-- Crafting quality (rank) of an item. Every rank has its own item ID, so the
-- rank can be read straight from the ID (nil for non-tiered items).
function CM.GetItemRank(itemID)
    local api = _G.C_TradeSkillUI
    if not api then return nil end
    local q = api.GetItemCraftedQualityByItemInfo and api.GetItemCraftedQualityByItemInfo(itemID)
    if not q and api.GetItemReagentQualityByItemInfo then
        q = api.GetItemReagentQualityByItemInfo(itemID)
    end
    if type(q) == "number" and q > 0 then return q end
    return nil
end

-- Rank icon markup (falls back to plain text if the atlas is missing).
local function RankMarkup(itemID)
    local q = CM.GetItemRank(itemID)
    if not q then return "" end
    for _, fmt in ipairs({ "Professions-ChatIcon-Quality-12-Tier%d", "Professions-ChatIcon-Quality-Tier%d" }) do
        local atlas = fmt:format(q)
        if not (C_Texture and C_Texture.GetAtlasInfo) or C_Texture.GetAtlasInfo(atlas) then
            return "|A:" .. atlas .. ":14:14|a "
        end
    end
    return "|cffAAAAAA[" .. q .. "]|r "
end

-- Item name prefixed with its rank icon (icon first so it survives truncation).
local function DisplayName(itemID)
    return RankMarkup(itemID) .. CM.GetItemDisplayName(itemID)
end

local function SkinRowWidgets(chk, ...)
    local S = CM.GetElvSkins()
    if not S then return end
    CM.SkinCheckbox(S, chk)
    for _, box in ipairs({ ... }) do
        if box and S.HandleEditBox then S:HandleEditBox(box) end
    end
end

-- Items that can't be bought at the AH are conjured/fleeting (cauldron) items
-- (IsConjured) and bound items - BoP, quest, account/Warband-bound, e.g. Hearty
-- dishes (IsBoundNoAH). CM.IsAuctionable combines both.
local conjuredCache = {}

local function IsConjured(itemID)
    local cached = conjuredCache[itemID]
    if cached ~= nil then return cached end

    local name = C_Item.GetItemNameByID(itemID)
    if not name then return false end  -- data not loaded yet, don't cache
    if CM.MatchesAny(name:lower(), CM.L["PATTERN_FLEETING"]) then
        conjuredCache[itemID] = true
        return true
    end

    -- Tooltip line "Conjured Item" (localized global string)
    local conj = _G.ITEM_CONJURED
    if conj and C_TooltipInfo and C_TooltipInfo.GetItemByID then
        local ok, data = pcall(C_TooltipInfo.GetItemByID, itemID)
        if ok and data and data.lines then
            for _, line in ipairs(data.lines) do
                local text = line.leftText
                if type(text) == "string"
                   and not (_G.issecretvalue and _G.issecretvalue(text))
                   and text:find(conj, 1, true) then
                    conjuredCache[itemID] = true
                    return true
                end
            end
            conjuredCache[itemID] = false
        end
    end
    return false
end
CM.IsConjured = IsConjured  -- exposed for Reminder.lua (fleeting items aren't worth restocking)

local function IsBoundNoAH(itemID)
    -- bindType is the 14th return of C_Item.GetItemInfo (nil until cached)
    local bindType = select(14, C_Item.GetItemInfo(itemID))
    local B = Enum and Enum.ItemBind
    if not bindType or not B then return false end
    return bindType == B.OnAcquire or bindType == B.Quest
        or bindType == B.ToWoWAccount or bindType == B.ToBnetAccount
end

function CM.IsAuctionable(itemID)
    return not IsConjured(itemID) and not IsBoundNoAH(itemID)
end

-- Returns { {id, have, target, missing}, ... } for ticked items below target
-- AND at/below their (effective) minimum count.
function CM.GetRestockList()
    local list = {}
    if not CM.db then return list end
    for _, t in ipairs(CM.TABS) do
        if not CM.RESTOCK_SKIP[t.key] then
            local items  = CM.db[t.key] and CM.db[t.key].items or {}
            local tabMin = tonumber(CM.db[t.key] and CM.db[t.key].minCount) or 0
            for _, item in ipairs(items) do
                local target = tonumber(item.target) or 0
                if item.restock and target > 0 and CM.IsAuctionable(item.id) then
                    local have = GetHave(item.id)
                    if have < target then
                        local min = tonumber(item.minCount) or 0
                        if min <= 0 then min = tabMin end
                        if min <= 0 or have <= min then
                            tinsert(list, { id = item.id, have = have, target = target, missing = target - have })
                        end
                    end
                end
            end
        end
    end
    return list
end

-- ── AH search ──────────────────────────────────────────────────────────────────
-- Auctionator: public API (selects its Shopping tab itself).
-- Default AH: drives Blizzard's own search bar. These are internals, not a
-- stable API, so every step is pcall'd and degrades to "press Enter yourself".
-- qty: amount still missing; passed on so the buy quantity is pre-filled.
local pendingBuy = nil  -- { itemID, qty, selected } for the default AH

function CM.SearchAuctionHouse(itemID, qty)
    local name = C_Item.GetItemNameByID(itemID)
    if not name then
        C_Item.RequestLoadItemDataByID(itemID)
        return
    end
    pendingBuy = nil

    -- Auctionator: term table with exact name, rank (tier) and purchase quantity.
    -- Falls back to fewer fields if a build rejects one of them.
    local api = _G.Auctionator and _G.Auctionator.API and _G.Auctionator.API.v1
    if api and api.MultiSearchAdvanced then
        local rank = CM.GetItemRank(itemID)
        local variants = {
            { searchString = name, isExact = true, quantity = qty, tier = rank },
            { searchString = name, isExact = true, quantity = qty },
            { searchString = name, isExact = true },
        }
        for _, term in ipairs(variants) do
            if pcall(api.MultiSearchAdvanced, CM.ADDON_NAME, { term }) then return end
        end
    end

    -- Default AH: search by name, then open this exact rank and fill the quantity
    -- (see the browse/commodity events below).
    local ah  = _G.AuctionHouseFrame
    local box = ah and ah.SearchBar and ah.SearchBar.SearchBox
    if not box then return end
    pendingBuy = { itemID = itemID, qty = qty }
    box:SetText(name)
    if pcall(function() ah.SearchBar:StartSearch() end) then return end
    if pcall(function() box:GetScript("OnEnterPressed")(box) end) then return end
    pcall(function()
        C_AuctionHouse.SendBrowseQuery({
            searchString = name, sorts = {}, filters = {}, itemClassFilters = {},
        })
    end)
end

-- ── AH panel ───────────────────────────────────────────────────────────────────
local function GetPanelRow(f, i)
    local row = f.rows[i]
    if row then return row end

    row = CreateFrame("Button", nil, f)
    row:SetHeight(ROW_H - 2)
    row:SetPoint("TOPLEFT",  f, "TOPLEFT",  10, -30 - (i - 1) * ROW_H)
    row:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -30 - (i - 1) * ROW_H)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(0.2, 0.2, 0.2, 0.4)

    row.hl = row:CreateTexture(nil, "HIGHLIGHT")
    row.hl:SetAllPoints()
    row.hl:SetColorTexture(1, 1, 1, 0.08)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT", 4, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.count = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.count:SetPoint("RIGHT", -6, 0)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.name:SetPoint("LEFT",  row.icon,  "RIGHT", 6, 0)
    row.name:SetPoint("RIGHT", row.count, "LEFT", -6, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row:SetScript("OnClick", function(self)
        if self.itemID then CM.SearchAuctionHouse(self.itemID, self.missing) end
    end)
    row:SetScript("OnEnter", function(self) CM.ShowItemTooltip(self, self.itemID, "ANCHOR_LEFT") end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)

    f.rows[i] = row
    return row
end

local function AnchorPanel(f)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", _G.AuctionHouseFrame or UIParent, "TOPRIGHT", 4, 0)
end

function CM.GetRestockFrame()
    if CM.restockFrame then return CM.restockFrame end
    local L = CM.L

    local f = CreateFrame("Frame", "CMRestockFrame", UIParent, "BasicFrameTemplateWithInset")
    f:SetSize(270, 100)
    AnchorPanel(f)
    f:SetFrameStrata(CM.FRAME_STRATA)
    f:SetClampedToScreen(true)
    f:Hide()
    f.TitleText:SetText("|cff00FF98CM|r " .. L["RESTOCK_TITLE"])
    f.CloseButton:HookScript("OnClick", function() dismissed = true end)

    f.rows = {}
    f.foot = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    f.foot:SetPoint("BOTTOMLEFT", 12, 10)
    f.foot:SetPoint("BOTTOMRIGHT", -12, 10)
    f.foot:SetJustifyH("LEFT")

    CM.restockFrame = f
    CM.ApplyElvUISkin()
    return f
end

-- Shows/hides/updates the AH panel. Safe to call at any time.
function CM.RefreshRestockFrame()
    if not ahOpen then return end
    local rs = CM.db and CM.db.restock
    local f  = CM.restockFrame
    if not rs or not rs.enabled then
        if f then f:Hide() end
        return
    end
    if dismissed then return end

    local list = CM.GetRestockList()
    if #list == 0 then
        if f then f:Hide() end
        return
    end

    f = CM.GetRestockFrame()
    local shown = math.min(#list, MAX_ROWS)
    for i = 1, shown do
        local row, e = GetPanelRow(f, i), list[i]
        row.itemID = e.id
        row.icon:SetTexture(CM.GetItemIcon(e.id))
        row.missing = e.missing
        row.name:SetText(DisplayName(e.id))
        local color = e.have == 0 and "|cffFF4444" or "|cffFFAA00"
        row.count:SetText(color .. e.have .. "/" .. e.target .. "|r")
        row:Show()
    end
    for i = shown + 1, #f.rows do f.rows[i]:Hide() end

    local extra = #list - shown
    f.foot:SetText(CM.L["RESTOCK_HINT"] .. (extra > 0 and ("  " .. (CM.L["RESTOCK_MORE"]):format(extra)) or ""))
    f:SetHeight(30 + shown * ROW_H + 26)
    -- the AH frame may not have existed yet when the panel was created
    if not f:IsShown() then AnchorPanel(f) end
    f:Show()
end

-- ── Config frame (tick items + target per item) ────────────────────────────────
local function GetConfigRow(f, i)
    local row = f.rows[i]
    if row then return row end

    row = CreateFrame("Frame", nil, f.content)
    row:SetSize(CFG_ROW_W, CFG_ROW_H - 2)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * CFG_ROW_H)

    row.header = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.header:SetPoint("LEFT", 6, 0)

    row.chk = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    row.chk:SetSize(22, 22)
    row.chk:SetPoint("LEFT", 2, 0)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(18, 18)
    row.icon:SetPoint("LEFT", row.chk, "RIGHT", 2, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.box = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    row.box:SetSize(CFG_BOX_W, 20)
    row.box:SetPoint("RIGHT", -6, 0)
    row.box:SetMaxLetters(4)
    CM.AttachTooltip(row.box, CM.L["RESTOCK_TARGET_TOOLTIP"], "ANCHOR_TOP")

    row.minBox = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
    row.minBox:SetSize(CFG_BOX_W, 20)
    row.minBox:SetPoint("RIGHT", row.box, "LEFT", -6, 0)
    row.minBox:SetMaxLetters(4)
    CM.AttachTooltip(row.minBox, CM.L["RESTOCK_MIN_TOOLTIP"], "ANCHOR_TOP")

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    row.name:SetPoint("LEFT",  row.icon, "RIGHT", 6, 0)
    row.name:SetPoint("RIGHT", row.minBox, "LEFT", -10, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.chk:SetScript("OnClick", function(self)
        local item = row.item
        if not item then return end
        item.restock = self:GetChecked() and true or false
        -- No target yet: jump into the amount box so the tick has an effect.
        if item.restock and (tonumber(item.target) or 0) <= 0 then row.box:SetFocus() end
        CM.RefreshRestockFrame()
    end)

    -- each box commits its number into one field of the row's item
    for box, field in pairs({ [row.box] = "target", [row.minBox] = "minCount" }) do
        CM.BindNumberBox(box, function(self)
            local item = row.item
            if not item then return end
            item[field] = tonumber(self:GetText()) or 0
            CM.RefreshRestockFrame()
        end)
    end

    SkinRowWidgets(row.chk, row.box, row.minBox)
    f.rows[i] = row
    return row
end

function CM.RefreshRestockConfig()
    local f = CM.restockConfigFrame
    if not f or not CM.db then return end
    local L = CM.L
    local n = 0

    for _, t in ipairs(CM.TABS) do
        if not CM.RESTOCK_SKIP[t.key] then
            -- only items that can be bought at the AH are listed
            local items = {}
            for _, item in ipairs(CM.db[t.key] and CM.db[t.key].items or {}) do
                if CM.IsAuctionable(item.id) then tinsert(items, item) end
            end
            if #items > 0 then
                n = n + 1
                local hRow = GetConfigRow(f, n)
                hRow.item = nil
                hRow.chk:Hide(); hRow.icon:Hide(); hRow.name:Hide(); hRow.box:Hide(); hRow.minBox:Hide()
                hRow.header:SetText(L[t.tabL] or t.key)
                hRow.header:SetTextColor(unpack(t.color))
                hRow.header:Show()
                hRow:Show()

                for _, item in ipairs(items) do
                    n = n + 1
                    local r = GetConfigRow(f, n)
                    r.item = item
                    r.header:Hide()
                    r.chk:Show(); r.icon:Show(); r.name:Show(); r.box:Show(); r.minBox:Show()
                    r.chk:SetChecked(item.restock and true or false)
                    r.icon:SetTexture(CM.GetItemIcon(item.id))
                    r.name:SetText(DisplayName(item.id))
                    -- don't overwrite what the user is typing right now
                    if not r.box:HasFocus() then
                        local target = tonumber(item.target) or 0
                        r.box:SetText(target > 0 and tostring(target) or "")
                    end
                    if not r.minBox:HasFocus() then
                        local min = tonumber(item.minCount) or 0
                        r.minBox:SetText(min > 0 and tostring(min) or "")
                    end
                    r:Show()
                end
            end
        end
    end

    for i = n + 1, #f.rows do
        f.rows[i]:Hide()
        f.rows[i].item = nil
    end
    f.content:SetHeight(math.max(1, n * CFG_ROW_H))
    f.emptyLbl:SetShown(n == 0)
end

function CM.BuildRestockConfigFrame()
    if CM.restockConfigFrame then return CM.restockConfigFrame end
    local L = CM.L

    local f = CM.CreateWindow("CMRestockConfigFrame")
    f:SetSize(410, 500)
    f:SetPoint("LEFT", CM.optionsFrame, "RIGHT", 8, 0)
    f.TitleText:SetText(L["RESTOCK_CONFIG_TITLE"])
    f.rows = {}

    -- Save any box that still has pending text (focus-lost may not fire on hide)
    f:SetScript("OnHide", function()
        for _, row in ipairs(f.rows) do
            if row:IsShown() and row.item then
                row.item.target   = tonumber(row.box:GetText()) or 0
                row.item.minCount = tonumber(row.minBox:GetText()) or 0
            end
        end
        CM.RefreshRestockFrame()
    end)

    f.enableChk = CM.CreateCheckbox(f, L["CHECKBOX_RESTOCK_ENABLE"], 14, -30)
    f.enableChk:SetScript("OnClick", function(self)
        CM.db.restock.enabled = self:GetChecked() and true or false
        dismissed = false
        CM.RefreshRestockFrame()
    end)

    f.bankChk = CM.CreateCheckbox(f, L["CHECKBOX_RESTOCK_BANK"], 14, -58)
    f.bankChk:SetScript("OnClick", function(self)
        CM.db.restock.countBank = self:GetChecked() and true or false
        CM.RefreshRestockFrame()
    end)

    f.descLbl = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    f.descLbl:SetPoint("TOPLEFT",  14, -90)
    f.descLbl:SetPoint("TOPRIGHT", -14, -90)
    f.descLbl:SetJustifyH("LEFT")
    f.descLbl:SetWordWrap(true)
    f.descLbl:SetText(L["RESTOCK_CONFIG_DESC"])
    f.descLbl:SetTextColor(0.65, 0.65, 0.65)

    f.scrollBg = CreateFrame("Frame", nil, f, "InsetFrameTemplate")
    f.scrollBg:SetPoint("TOPLEFT",     10, -115)
    f.scrollBg:SetPoint("BOTTOMRIGHT", -10, 12)

    local scroll = CreateFrame("ScrollFrame", "CMRestockScroll", f.scrollBg, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",     4, -4)
    scroll:SetPoint("BOTTOMRIGHT", -26, 4)
    f.content = CreateFrame("Frame", nil, scroll)
    scroll:SetScrollChild(f.content)
    f.content:SetWidth(CFG_ROW_W)
    f.content:SetHeight(1)

    f.emptyLbl = f.scrollBg:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    f.emptyLbl:SetPoint("TOPLEFT", 12, -14)
    f.emptyLbl:SetPoint("TOPRIGHT", -12, -14)
    f.emptyLbl:SetJustifyH("LEFT")
    f.emptyLbl:SetWordWrap(true)
    f.emptyLbl:SetText(L["RESTOCK_EMPTY"])

    CM.restockConfigFrame = f
    return f
end

function CM.ShowRestockConfigFrame()
    local f = CM.BuildRestockConfigFrame()
    if f:IsShown() then
        f:Hide()
        return
    end
    local rs = CM.db and CM.db.restock
    f.enableChk:SetChecked(rs and rs.enabled or false)
    f.bankChk:SetChecked(rs and rs.countBank or false)
    CM.RefreshRestockConfig()
    f:Show()
    CM.ApplyElvUISkin()
end

-- ── Default AH: open the exact rank and pre-fill the quantity ──────────────────
-- Blizzard internals (SelectBrowseResult, BuyDisplay.QuantityInput) are not a
-- stable API: everything is guarded/pcall'd, worst case the player clicks the
-- result and types the amount themselves.
local function TrySelectBrowseResult()
    local p  = pendingBuy
    local ah = _G.AuctionHouseFrame
    if not p or p.selected or not ah or not ah.SelectBrowseResult then return end
    if not (C_AuctionHouse and C_AuctionHouse.GetBrowseResults) then return end
    for _, result in ipairs(C_AuctionHouse.GetBrowseResults() or {}) do
        if result.itemKey and result.itemKey.itemID == p.itemID then
            if pcall(ah.SelectBrowseResult, ah, result) then p.selected = true end
            return
        end
    end
end

local function ApplyPendingQuantity(itemID, last)
    local p = pendingBuy
    if not p or p.itemID ~= itemID then return end
    local ah    = _G.AuctionHouseFrame
    local buy   = ah and ah.CommoditiesBuyFrame
    local input = buy and buy.BuyDisplay and buy.BuyDisplay.QuantityInput
    if input and input.SetQuantity and (tonumber(p.qty) or 0) > 0 then
        pcall(input.SetQuantity, input, p.qty)
    end
    if last then pendingBuy = nil end
end

-- ── Events ─────────────────────────────────────────────────────────────────────
local ev = CreateFrame("Frame")
ev:RegisterEvent("AUCTION_HOUSE_SHOW")
ev:RegisterEvent("AUCTION_HOUSE_CLOSED")
ev:RegisterEvent("BAG_UPDATE_DELAYED")
ev:RegisterEvent("ITEM_DATA_LOAD_RESULT")
ev:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED")
ev:RegisterEvent("AUCTION_HOUSE_BROWSE_RESULTS_ADDED")
ev:RegisterEvent("COMMODITY_SEARCH_RESULTS_UPDATED")
ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "AUCTION_HOUSE_SHOW" then
        ahOpen    = true
        dismissed = false
        CM.RefreshRestockFrame()
    elseif event == "AUCTION_HOUSE_CLOSED" then
        ahOpen = false
        pendingBuy = nil
        if CM.restockFrame then CM.restockFrame:Hide() end
    elseif event == "BAG_UPDATE_DELAYED" then
        if ahOpen then CM.RefreshRestockFrame() end
    elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" or event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then
        TrySelectBrowseResult()
    elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
        -- arg1 = itemID. Blizzard may reset the quantity while it populates,
        -- so set it a little later, twice; the second pass ends the pending buy.
        if pendingBuy and pendingBuy.itemID == arg1 then
            C_Timer.After(0.05, function() ApplyPendingQuantity(arg1, false) end)
            C_Timer.After(0.4,  function() ApplyPendingQuantity(arg1, true) end)
        end
    elseif event == "ITEM_DATA_LOAD_RESULT" then
        if ahOpen and CM.restockFrame and CM.restockFrame:IsShown() then
            CM.Defer("restockPanel", CM.RefreshRestockFrame)
        end
        if CM.restockConfigFrame and CM.restockConfigFrame:IsShown() then
            CM.Defer("restockConfig", CM.RefreshRestockConfig)
        end
    end
end)
