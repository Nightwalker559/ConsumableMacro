-- ConsumableMacro Core
-- Compatibility: WoW Midnight (12.0+), WoW Forever (16xxx) & ElvUI

-- Shared namespace — all files access state through this table
ConsumableMacroAddon = {}
local CM = ConsumableMacroAddon

CM.ADDON_NAME   = "ConsumableMacro"
CM.TITLE        = "|cff00FF98Consumable|r|cffffffffMacro|r"
CM.ICON_UNKNOWN = 134400  -- question mark

-- Locale (loaded before Core.lua via TOC)
CM.L = _G["ConsumableMacroLocale"] or {}
setmetatable(CM.L, {__index = function(_, k) return k end})

-- Shared state (window frames - optionsFrame, ieFrame, ... - are created lazily by their files)
CM.db                    = nil   -- active profile (stored account-wide, see Profiles.lua)
CM.charDb                 = nil   -- per-character SavedVariables (profile name, reminder position)
CM.mainFrame              = nil
CM.FRAME_STRATA           = "DIALOG"  -- config windows: above other addons' HUD frames (chat buttons, quest trackers)
CM.activeTab              = "flask"
CM.rowPool                = {}
CM.needsUpdateAfterCombat = false

CM.MACRO_NAMES = {
    flask         = "CM_Flask",
    potion        = "CM_Potion",
    healpotion    = "CM_HealPotion",
    manapotion    = "CM_ManaPotion",
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
    { key = "manapotion",    tabL = "TAB_MANAPOTION",    info = "INFO_MANAPOTION",    sub = "SUB_MANAPOTION",    color = {0.3, 0.5, 1} },
    { key = "healthstone",   tabL = "TAB_HEALTHSTONE",   info = "INFO_STONE",         sub = "SUB_STONE",         color = {0.7, 0.3, 1} },
    { key = "bufffood",      tabL = "TAB_BUFFFOOD",      info = "INFO_FOOD",          sub = "SUB_FOOD",          color = {1, 0.7, 0} },
    { key = "weaponenhance", tabL = "TAB_WEAPONENHANCE", info = "INFO_WEAPONENHANCE", sub = "SUB_WEAPONENHANCE", color = {0.85, 0.6, 0.3} },
}

-- WoW Forever (TOC 16xxx) is Classic content on the Mainline client. Food and drink
-- can be consumed at the same time there, so it gets two lists (Food, Drink) behind
-- one sidebar entry (sideL, the Drink list has sideOf) that feed one macro, CM_FoodDrink.
local build = select(4, _G.GetBuildInfo())
CM.IS_FOREVER = type(build) == "number" and build >= 16000 and build < 20000
-- The AutoPotion panic macro is Retail only (it builds on class self-heals that Forever lacks).
CM.HAS_AUTOPOTION = not CM.IS_FOREVER

function CM.GetTabInfo(key)
    for _, t in ipairs(CM.TABS) do
        if t.key == key then return t end
    end
    return nil
end

-- Lists without a macro of their own: [tab key] = key of the tab that owns the macro.
CM.MACRO_OWNER = {}

if CM.IS_FOREVER then
    tinsert(CM.TABS, 7, { key = "food",  tabL = "TAB_FOOD",  sideL = "TAB_FOODDRINK", info = "INFO_FOOD_LIST", sub = "SUB_FOOD_LIST", color = {1, 0.85, 0.4} })
    tinsert(CM.TABS, 8, { key = "drink", tabL = "TAB_DRINK", sideOf = "food",         info = "INFO_DRINK",     sub = "SUB_DRINK",     color = {0.4, 0.7, 1} })
    CM.MACRO_NAMES.food = "CM_FoodDrink"
    CM.MACRO_OWNER.drink = "food"
    CM.REMINDER_SKIP.food, CM.REMINDER_SKIP.drink = true, true

    -- Flasks and elixirs are separate lists: a flask lasts through death and only one runs at a
    -- time, several elixirs run together. The reminder leaves elixirs out (they are optional).
    tinsert(CM.TABS, 2, { key = "elixir", tabL = "TAB_ELIXIR", info = "INFO_ELIXIR", sub = "SUB_ELIXIR", color = {0.3, 0.85, 0.75} })
    CM.MACRO_NAMES.elixir = "CM_Elixir"
    CM.REMINDER_SKIP.elixir = true

    -- Bandages sit after Mana Pots: first aid is used on purpose there, one press per bandage
    tinsert(CM.TABS, 5, { key = "bandage", tabL = "TAB_BANDAGE", info = "INFO_BANDAGE", sub = "SUB_BANDAGE", color = {0.95, 0.9, 0.7} })
    CM.MACRO_NAMES.bandage = "CM_Bandage"

    -- Rogues: poisons, two lists (poison 1 for the main hand, poison 2 for the off hand)
    -- behind one sidebar entry, one macro, CM_Poison (Modules\Poison.lua). Before Weapon Enhancements.
    if select(2, _G.UnitClass("player")) == "ROGUE" then
        local at = #CM.TABS
        tinsert(CM.TABS, at, { key = "poison",    tabL = "TAB_POISON1", sideL = "TAB_POISONS", info = "INFO_POISON1", sub = "SUB_POISON", color = {0.45, 0.9, 0.3} })
        tinsert(CM.TABS, at + 1, { key = "poisonoff", tabL = "TAB_POISON2", sideOf = "poison", info = "INFO_POISON2", sub = "SUB_POISON", color = {0.3, 0.75, 0.55} })
        CM.MACRO_NAMES.poison = "CM_Poison"
        CM.MACRO_OWNER.poisonoff = "poison"
    end
end

-- Tabs the reminder leaves out: the fixed ones, plus Mana Pots for a class without mana
-- (warrior, rogue, ...).
function CM.SkipsReminder(key)
    if CM.REMINDER_SKIP[key] then return true end
    return key == "manapotion" and (_G.UnitPowerMax("player", Enum.PowerType.Mana) or 0) <= 0
end

-- ── Utilities ──────────────────────────────────────────────────────────────────
function CM.IsInBags(itemID)
    return itemID and C_Item.GetItemCount(itemID) > 0
end

-- Chat line with addon prefix.
function CM.Print(msg)
    _G.print("|cff00FF98Consumable|rMacro: " .. msg)
end

-- True (with the "not in combat" error shown) while in combat lockdown: the guard for
-- everything that writes macros or profile data.
function CM.BlockedByCombat()
    if not InCombatLockdown() then return false end
    CM.ShowError(CM.L["ERR_COMBAT"])
    return true
end

-- Red on-screen error message.
function CM.ShowError(msg)
    _G.UIErrorsFrame:AddMessage("|cffFF0000" .. msg .. "|r", 1.0, 0.1, 0.1, 1.0)
end

-- Runs fn after `delay` seconds (default 0.1); calls with the same key are
-- dropped until it has run, which coalesces event bursts into one update.
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

-- True if the (already lowercased) name contains any pattern of the list, as plain text.
function CM.MatchesAny(lowerName, patterns)
    for _, p in ipairs(patterns or {}) do
        if lowerName:find(p:lower(), 1, true) then return true end
    end
    return false
end

-- Like MatchesAny, but a pattern only counts at the end of a word ("tea" hits
-- "iced tea", not "steak"). For short patterns that sit inside other words.
function CM.MatchesWordEnd(lowerName, patterns)
    for _, p in ipairs(patterns or {}) do
        local escaped = (p:lower():gsub("%p", "%%%0"))
        if lowerName:find(escaped .. "%f[%A]") then return true end
    end
    return false
end

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

-- The reminder only bothers max-level characters.
function CM.IsMaxLevel()
    local maxLevel = _G.GetMaxPlayerLevel and _G.GetMaxPlayerLevel() or 80
    return _G.UnitLevel("player") >= maxLevel
end
