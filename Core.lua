-- ConsumableMacro Core
-- Compatibility: WoW Midnight (12.0+) & ElvUI

-- Shared namespace — all files access state through this table
ConsumableMacroAddon = {}
local CM = ConsumableMacroAddon

CM.ADDON_NAME = "ConsumableMacro"

-- Locale (loaded before Core.lua via TOC)
CM.L = _G["ConsumableMacroLocale"] or {}
setmetatable(CM.L, {__index = function(_, k) return k end})

-- Shared state
CM.db                     = nil   -- active profile (stored account-wide, see Profiles.lua)
CM.charDb                 = nil   -- per-character SavedVariables (profile name, reminder position)
CM.mainFrame              = nil
CM.FRAME_STRATA           = "MEDIUM"  -- one strata for all addon windows
CM.activeTab              = "flask"
CM.rowPool                = {}
CM.needsUpdateAfterCombat = false

CM.MACRO_NAMES = {
    flask         = "CM_Flask",
    potion        = "CM_Potion",
    healpotion    = "CM_HealPotion",
    healthstone   = "CM_Healthstone",
    bufffood      = "CM_Bufffood",
    weaponenhance = "CM_WeaponEnhance",
}

-- Independent copies — mutating one does not affect the others.
CM.REMINDER_SKIP  = { healthstone = true }
CM.MINCOUNT_SKIP  = { healthstone = true }
CM.RESTOCK_SKIP   = { healthstone = true }  -- not sold at the AH

CM.TABS = {
    { key = "flask",         tabL = "TAB_FLASK",         info = "INFO_FLASK",         sub = "SUB_FLASK",         color = {0, 1, 1} },
    { key = "potion",        tabL = "TAB_POTION",        info = "INFO_POTION",        sub = "SUB_POTION",        color = {0, 0.8, 1} },
    { key = "healpotion",    tabL = "TAB_HEALPOTION",    info = "INFO_HEAL",          sub = "SUB_HEAL",          color = {0.2, 1, 0.2} },
    { key = "healthstone",   tabL = "TAB_HEALTHSTONE",   info = "INFO_STONE",         sub = "SUB_STONE",         color = {0.7, 0.3, 1} },
    { key = "bufffood",      tabL = "TAB_BUFFFOOD",      info = "INFO_FOOD",          sub = "SUB_FOOD",          color = {1, 0.7, 0} },
    { key = "weaponenhance", tabL = "TAB_WEAPONENHANCE", info = "INFO_WEAPONENHANCE", sub = "SUB_WEAPONENHANCE", color = {0.85, 0.6, 0.3} },
}

-- ── Utilities ──────────────────────────────────────────────────────────────────
function CM.IsInBags(itemID)
    return itemID and C_Item.GetItemCount(itemID) > 0
end

-- Chat line with addon prefix.
function CM.Print(msg)
    _G.print("|cff00FF98Consumable|rMacro: " .. msg)
end

-- Red on-screen error message.
function CM.ShowError(msg)
    _G.UIErrorsFrame:AddMessage("|cffFF0000" .. msg .. "|r", 1.0, 0.1, 0.1, 1.0)
end

-- Runs fn once after `delay` seconds. Further calls with the same key are
-- dropped until it has run (coalesces bursts of events into one update).
local deferred = {}
function CM.Defer(key, fn, delay)
    if deferred[key] then return end
    deferred[key] = true
    _G.C_Timer.After(delay or 0.1, function()
        deferred[key] = nil
        fn()
    end)
end

-- Item name, or a "loading" placeholder while the item data is requested.
function CM.GetItemDisplayName(itemID)
    local name = C_Item.GetItemNameByID(itemID)
    if not name then
        C_Item.RequestLoadItemDataByID(itemID)
        name = (CM.L["ITEM_LOADING"]):format(itemID)
    end
    return name
end

-- Plain-text, case-insensitive match of an already lowercased name against a
-- locale pattern list.
function CM.MatchesAny(lowerName, patterns)
    for _, p in ipairs(patterns or {}) do
        if lowerName:find(p:lower(), 1, true) then return true end
    end
    return false
end

-- ElvUI Skins module, or nil if ElvUI isn't loaded.
function CM.GetElvSkins()
    local E = _G.ElvUI and _G.ElvUI[1]
    return E and E:GetModule("Skins", true) or nil
end

-- Some ElvUI versions expose HandleCheckBox, older ones HandleCheckButton.
function CM.SkinCheckbox(S, cb)
    if not S or not cb then return end
    if S.HandleCheckBox then S:HandleCheckBox(cb)
    elseif S.HandleCheckButton then S:HandleCheckButton(cb) end
end

-- Checkbox with a text label to its right, anchored at (x, y) from the top left.
function CM.CreateCheckbox(parent, label, x, y)
    local chk = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    chk:SetSize(24, 24)
    chk:SetPoint("TOPLEFT", x, y)
    chk.text = chk:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    chk.text:SetPoint("LEFT", chk, "RIGHT", 4, 0)
    chk.text:SetText(label)
    return chk
end

CM.TITLE        = "|cff00FF98Consumable|r|cffffffffMacro|r"
CM.ICON_UNKNOWN = 134400  -- question mark

-- Item icon texture (question mark while the item data isn't loaded yet).
function CM.GetItemIcon(itemID)
    return C_Item.GetItemIconByID(itemID) or CM.ICON_UNKNOWN
end

-- First item of a priority list that is in the bags; nil if none.
function CM.GetFirstInBags(items)
    for _, item in ipairs(items or {}) do
        if CM.IsInBags(item.id) then return item.id end
    end
    return nil
end

function CM.ShowItemTooltip(owner, itemID, anchor)
    if not itemID then return end
    GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    GameTooltip:SetItemByID(itemID)
    GameTooltip:Show()
end

-- Movable addon window: Blizzard frame, shared strata, closes on Escape, hidden.
-- The caller sets size, anchor and title.
function CM.CreateWindow(name)
    local f = CreateFrame("Frame", name, UIParent, "BasicFrameTemplateWithInset")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:SetFrameStrata(CM.FRAME_STRATA)
    f:Hide()
    tinsert(_G.UISpecialFrames, name)
    return f
end

-- Numeric edit box that commits via onSave(box) whenever it loses focus.
-- Enter and Escape just drop the focus (which triggers the save).
function CM.BindNumberBox(box, onSave)
    box:SetAutoFocus(false)
    box:SetNumeric(true)
    box:SetScript("OnEnterPressed",  box.ClearFocus)
    box:SetScript("OnEscapePressed", box.ClearFocus)
    box:SetScript("OnEditFocusLost", onSave)
end

-- Reminder should only bother max-level characters (consumables are
-- irrelevant while leveling).
function CM.IsMaxLevel()
    local maxLevel = _G.GetMaxPlayerLevel and _G.GetMaxPlayerLevel() or 80
    return _G.UnitLevel("player") >= maxLevel
end

-- ── Macro Generation ───────────────────────────────────────────────────────────
-- Shared by Core.lua and AutoPotion.lua: trims a list of macro lines to fit the
-- 254-char macro body limit (255 incl. null terminator) and joins them.
local function TrimMacroLines(lines)
    local finalLines, currentLength = {}, 0
    for _, line in ipairs(lines) do
        local lineLen = #line + (currentLength == 0 and 0 or 1)
        if currentLength + lineLen > 254 then break end
        tinsert(finalLines, line)
        currentLength = currentLength + lineLen
    end
    return table.concat(finalLines, "\n")
end
CM.TrimMacroLines = TrimMacroLines

local function GetMacroBodyText(key)
    local db = CM.db
    if not db or not db[key] or not db[key].items then return "" end
    local items = db[key].items

    -- Weapon Enhancements (Whetstone/Weightstone/Oil) build their body very
    -- differently (per-hand, weapon-type and enchant-state aware) - see
    -- WeaponEnhance.lua. Guarded in case that file somehow isn't loaded.
    if key == "weaponenhance" then
        return CM.BuildWeaponEnhanceMacroBody and CM.BuildWeaponEnhanceMacroBody(items) or "#showtooltip"
    end

    local lines = { "#showtooltip", "/cqs", "/stopcasting" }

    -- Only potion and healpotion get the stacked fallback chain.
    -- Flask, healthstone and bufffood use single best item only.
    local useConditionalChain = (key == "potion" or key == "healpotion")

    if useConditionalChain then
        local available = {}
        for _, item in ipairs(items) do
            if CM.IsInBags(item.id) then tinsert(available, item.id) end
        end
        if #available == 0 then
            if #items > 0 then lines[1] = "#showtooltip item:" .. items[1].id end
        else
            lines[1] = "#showtooltip item:" .. available[1]
            for _, id in ipairs(available) do
                tinsert(lines, "/use item:" .. id)
            end
        end
    else
        local firstMatch = CM.GetFirstInBags(items)
        if firstMatch then
            lines[1] = "#showtooltip item:" .. firstMatch
            tinsert(lines, "/use item:" .. firstMatch)
        elseif #items > 0 then
            lines[1] = "#showtooltip item:" .. items[1].id
        end
    end

    return TrimMacroLines(lines)
end

-- Creates or updates an account macro. The write is skipped when the body is
-- unchanged (macros are rebuilt on every bag update). createOnly: never touch
-- an existing macro (used at login, when bag data may not be cached yet).
function CM.WriteMacro(name, body, createOnly)
    createOnly = createOnly == true
    local idx = _G.GetMacroIndexByName(name)
    if idx == 0 then
        local accountMacros = _G.GetNumMacros()
        if accountMacros < 120 then
            _G.CreateMacro(name, CM.ICON_UNKNOWN, body, false)
        end
        return
    end
    if createOnly then return end
    local getBody = _G.GetMacroBody or (_G.C_Macro and _G.C_Macro.GetMacroBody)
    if getBody and getBody(idx) == body then return end
    _G.EditMacro(idx, name, nil, body)
end

function CM.UpdateMacro(key, createOnly)
    if InCombatLockdown() then
        CM.needsUpdateAfterCombat = true
        return
    end
    if not CM.db or not CM.MACRO_NAMES[key] then return end
    CM.WriteMacro(CM.MACRO_NAMES[key], GetMacroBodyText(key), createOnly)
end

-- createOnly == true: only create missing macros, leave existing ones alone.
function CM.UpdateAllMacros(createOnly)
    if not CM.db then return end
    for key in pairs(CM.MACRO_NAMES) do
        CM.UpdateMacro(key, createOnly)
    end
    if CM.UpdateAutoPotionMacro then CM.UpdateAutoPotionMacro(createOnly) end
end

-- GetMacroBodyText is local; expose via CM for UI.lua access
CM.GetMacroBodyText = GetMacroBodyText
