local L = _G["ConsumableMacroLocale"] or {}

L["TAB_FLASK"] = "Flasks"
L["TAB_POTION"] = "Potions"
L["TAB_HEALPOTION"] = "Heal Pots"
L["TAB_HEALTHSTONE"] = "Healthstone"

L["INFO_FLASK"] = "Ultimate Power"
L["INFO_POTION"] = "Combat Burst"
L["INFO_HEAL"] = "Life Savers"
L["INFO_STONE"] = "Demonic Vitality"

L["SUB_FLASK"] = "Long-lasting enhancements. Always keep one active!"
L["SUB_POTION"] = "Timed bursts for boss phases. Use them wisely!"
L["SUB_HEAL"] = "Emergency healing potions. For when things get tight."
L["SUB_STONE"] = "A Warlock's gift. Never say no to a free heal."

L["ITEM_LABEL"] = "%s (|cff888888%d|r)"
L["ITEM_LOADING"] = "Loading item data (%d)..."
L["IN_BAGS"] = "In Bags"
L["NOT_IN_BAGS"] = "Not found"

L["LABEL_INPUT_PREFIX"] = "Item-ID >"
L["LABEL_INPUT_TIP"] = "Tip: Find Item-IDs on\nWowhead or in Tooltip"
L["BTN_ADD"] = "Add"
L["DROP_ZONE_TITLE"] = "Item-Drop >"
L["DROP_ZONE_TEXT"] = "Drag item here"

L["OPTIONS_TITLE"]      = "Options"
L["OPTIONS_MIN_HEADER"] = "Minimum Count Warning"
L["OPTIONS_MIN_DESC"]   = "Warn when your top-priority item is at or below this count.\nAll 0 = no post-instance reminder."
L["OPTIONS_GENERAL"]    = "General"
L["CHECKBOX_REMINDER"] = "Show missing reminder on login"
L["CHECKBOX_AUTO"] = "Auto-Update on bag change"
L["BTN_UPDATE"] = "Update"
L["ERROR_INVALID_ITEM"] = "Invalid Item!"
L["ERR_COMBAT"] = "Action not allowed during combat!"
L["REMINDER_SETUP_HINT"]     = "|cffAAAAAA/cm — open ConsumableMacro to configure missing tabs.|r"
L["REMINDER_MISSING"] = "Missing consumables:"
L["HELP_TEXT"] = "|cff00FF98ConsumableMacro Commands:|r\n/cm - Toggle UI window\n/cm update - Update macros immediately\n/cm reset - Reset item lists (asks first)\n/cm profile <name> - Switch profile\n/cm help - Show this help message"

-- Detection Patterns
L["PATTERN_FLASK"] = {"flask", "phial"}
L["PATTERN_HEAL"] = {"heal", "vivacious"}
L["PATTERN_HEALTHSTONE"] = {"healthstone"}
L["PATTERN_EXCLUDE"] = {"tea", "water"}

L["TAB_BUFFFOOD"] = "Buff Food"
L["INFO_FOOD"] = "Nourishment"
L["SUB_FOOD"] = "Cook or buy before every pull. Never raid on an empty stomach."

L["IE_HEADER"]         = "Import / Export"
L["BTN_EXPORT"]        = "Export"
L["BTN_IMPORT"]        = "Import"
L["IMPORT_INVALID"]    = "Invalid import string."
L["IE_EXPORT_DESC"]    = "Select tabs to export:"
L["IE_IMPORT_DESC"]    = "Select tabs to import:"
L["IE_NONE_SELECTED"]  = "Select at least one tab."

L["RESET_HEADER"]        = "Reset"
L["BTN_RESET"]           = "Reset Lists"
L["RESET_TITLE"]         = "Reset Item Lists"
L["RESET_DESC"]          = "Select tabs to reset:"
L["RESET_NONE_SELECTED"] = "Select at least one tab."

L["AUTOPOTION_HEADER"]              = "AutoPotion"
L["CHECKBOX_AUTOPOTION_ENABLE"]     = "Enable AutoPotion macro"
L["CHECKBOX_AUTOPOTION_STOPCAST"]   = "Stop casting before use"
L["LABEL_AUTOPOTION_RESET_SECONDS"] = "Reset (sec.):"
L["BTN_AUTOPOTION_SYNC"]            = "Sync"
L["AUTOPOTION_RESET_DESC"]          = "Resets the sequence this many seconds after the last use, instead of only on combat start. 0 = combat only."
L["AUTOPOTION_SYNC_TOOLTIP"]        = "Sync from cooldown\nReads the spell's cooldown. If it's currently on cooldown, the exact talent-adjusted value is used; otherwise the base cooldown is used as an approximation."
L["AUTOPOTION_SYNC_NO_SPELL"]       = "No known class/racial spell detected."
L["AUTOPOTION_SYNC_NOT_ON_CD"]      = "Could not read a cooldown for this spell."
L["AUTOPOTION_SYNC_SUCCESS"]        = "Reset delay set to %d seconds."
L["AUTOPOTION_SYNC_SUCCESS_APPROX"] = "Reset delay set to %d seconds (base cooldown - may not reflect talents)."
L["AUTOPOTION_TALENT_CHANGED_HINT"] = "Talents changed - if this affects your AutoPotion spell's cooldown, click 'Sync' again."
L["BTN_AUTOPOTION_CONFIGURE"]       = "Configure Priority"
L["AUTOPOTION_PRIORITY_TITLE"]      = "AutoPotion Priority"
L["AUTOPOTION_PRIORITY_DESC"]       = "Use +/- to set the order AutoPotion tries each category in."
L["LABEL_AUTOPOTION_CLASSSPELL"]    = "Class/Racial Spell"

L["RESTOCK_HEADER"]             = "Auction House Restock"
L["BTN_RESTOCK_CONFIGURE"]      = "Configure Restock"
L["RESTOCK_CONFIG_TITLE"]       = "Restock Setup"
L["CHECKBOX_RESTOCK_ENABLE"]    = "Show restock list at the AH"
L["CHECKBOX_RESTOCK_BANK"]      = "Count bank / warband bank"
L["RESTOCK_CONFIG_DESC"]        = "Tick the items to restock and set a target amount for each. Optional per-item minimum (hover the left box for details)."
L["RESTOCK_EMPTY"]              = "No items yet. Add items in the main window first."
L["RESTOCK_TITLE"]              = "Restock"
L["RESTOCK_HINT"]               = "Click a row to search."
L["RESTOCK_MORE"]               = "+%d more"
L["RESTOCK_TARGET_TOOLTIP"]     = "Target amount to restock up to."
L["RESTOCK_MIN_TOOLTIP"]        = "Only shows in the AH panel once you're at or below this amount, instead of as soon as you're below target. Empty/0 = use this tab's minimum count (Options)."

L["PATTERN_FLEETING"]           = {"fleeting"}

L["TAB_WEAPONENHANCE"]  = "Weapon Enhancements"
L["INFO_WEAPONENHANCE"] = "Sharpened Edge"
L["SUB_WEAPONENHANCE"]  = "Whetstones, Weightstones and Weapon Oils. Auto-applied to whichever hand needs it."

L["PROFILE_HEADER"]         = "Profile"
L["PROFILE_NEW"]            = "New profile"
L["PROFILE_COPY"]           = "Copy current profile"
L["PROFILE_RENAME"]         = "Rename profile"
L["PROFILE_DELETE"]         = "Delete profile"
L["PROFILE_NAME_DESC"]      = "Enter a profile name:"
L["PROFILE_COPY_NAME"]      = "%s Copy"
L["PROFILE_DELETE_CONFIRM"] = "Delete profile \"%s\"?\nCharacters using it get a new profile."
L["PROFILE_ERR_EMPTY"]      = "Enter a profile name."
L["PROFILE_ERR_EXISTS"]     = "Profile already exists."
L["PROFILE_ERR_UNKNOWN"]    = "Unknown profile: %s"
L["PROFILE_IMPORT_DESC"]    = "Import into a new profile? Enter a name, or import into the current profile."
L["PROFILE_IMPORT_NAME"]    = "Import"
L["PROFILE_IMPORT_NEW"]     = "New profile"
L["PROFILE_IMPORT_CURRENT"] = "Current"
L["PROFILE_SWITCHED"]       = "Profile: %s"

_G["ConsumableMacroLocale"] = L
