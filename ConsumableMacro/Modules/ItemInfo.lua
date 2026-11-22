-- ConsumableMacro Item info
-- What the addon knows about an item beyond its tab: crafting quality (rank) with its icon
-- markup, and whether it can be bought at the Auction House.
local CM = ConsumableMacroAddon

-- Crafting quality (rank) of an item; every rank has its own item ID. Nil for
-- items without ranks.
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

-- Rank icon markup per rank (plain text if the atlas is missing).
local rankMarkup = {}
local function MarkupForRank(q)
    local markup = rankMarkup[q]
    if markup then return markup end
    markup = "|cffAAAAAA[" .. q .. "]|r "
    for _, fmt in ipairs({ "Professions-ChatIcon-Quality-12-Tier%d", "Professions-ChatIcon-Quality-Tier%d" }) do
        local atlas = fmt:format(q)
        if C_Texture.GetAtlasInfo(atlas) then
            markup = "|A:" .. atlas .. ":14:14|a "
            break
        end
    end
    rankMarkup[q] = markup
    return markup
end

function CM.RankMarkup(itemID)
    local q = CM.GetItemRank(itemID)
    return q and MarkupForRank(q) or ""
end

-- Not buyable at the AH: conjured/fleeting items (IsConjured) and bound items
-- (BoP, quest, account/Warband-bound; IsBoundNoAH). CM.IsAuctionable covers both.
local conjuredCache = {}

local function IsConjured(itemID)
    local cached = conjuredCache[itemID]
    if cached ~= nil then return cached end

    local name = C_Item.GetItemNameByID(itemID)
    if not name then return false end  -- not loaded yet, don't cache
    if CM.MatchesAny(name:lower(), CM.L["PATTERN_FLEETING"]) then
        conjuredCache[itemID] = true
        return true
    end

    -- tooltip line "Conjured Item" (localized global string)
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
CM.IsConjured = IsConjured

local function IsBoundNoAH(itemID)
    local bindType = select(14, C_Item.GetItemInfo(itemID))  -- nil until cached
    if not bindType then return false end
    local B = Enum.ItemBind
    return bindType == B.OnAcquire or bindType == B.Quest
        or bindType == B.ToWoWAccount or bindType == B.ToBnetAccount
end

-- The level the item needs when that is above the player's, else nil (also while the item
-- isn't cached yet: it can't be told, so it counts as usable).
function CM.GetMissingLevel(itemID)
    local minLevel = select(5, C_Item.GetItemInfo(itemID))
    if type(minLevel) == "number" and minLevel > _G.UnitLevel("player") then return minLevel end
    return nil
end

function CM.IsAuctionable(itemID)
    return not IsConjured(itemID) and not IsBoundNoAH(itemID)
end
