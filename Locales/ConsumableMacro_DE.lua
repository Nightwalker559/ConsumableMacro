if GetLocale() ~= "deDE" then return end

local L = _G["ConsumableMacroLocale"] or {}
L["TAB_FLASK"] = "Fläschchen"
L["TAB_POTION"] = "Kampftrank"
L["TAB_HEALPOTION"] = "Heiltränke"
L["TAB_HEALTHSTONE"] = "Gesundheitsstein"

L["INFO_FLASK"] = "Maximale Stärke"
L["INFO_POTION"] = "Kampf-Boost"
L["INFO_HEAL"] = "Lebensretter"
L["INFO_STONE"] = "Dämonische Vitalität"

L["SUB_FLASK"] = "Lang anhaltende Stärkung. Sorge dafür, dass immer eines aktiv ist!"
L["SUB_POTION"] = "Kurzzeitige Verstärkung für Bossphasen. Nutze sie weise!"
L["SUB_HEAL"] = "Notfall-Heiltränke. Wenn es brenzlig wird."
L["SUB_STONE"] = "Ein Geschenk des Hexenmeisters. Sag niemals nein zu einem gratis Heal."

L["ITEM_LABEL"] = "%s (|cff888888%d|r)"
L["ITEM_LOADING"] = "Lade Item-Daten (%d)..."
L["IN_BAGS"] = "Im Inventar"
L["NOT_IN_BAGS"] = "Nicht gefunden"

L["LABEL_INPUT_PREFIX"] = "Item-ID >"
L["LABEL_INPUT_TIP"] = "Tipp: Item-IDs findest du auf\nWowhead oder im Tooltip"
L["BTN_ADD"] = "Hinzufügen"
L["DROP_ZONE_TITLE"] = "Item-Drop >"
L["DROP_ZONE_TEXT"] = "Gegenstand hierher ziehen"

L["OPTIONS_TITLE"]      = "Optionen"
L["OPTIONS_MIN_HEADER"] = "Mindestmenge Warnung"
L["OPTIONS_MIN_DESC"]   = "Warnen, wenn dein höchstpriorisiertes Item diese Menge erreicht oder darunter liegt.\nAlle 0 = kein Reminder nach Instanz."
L["OPTIONS_GENERAL"]    = "Allgemein"
L["CHECKBOX_REMINDER"] = "Fehlenden Reminder beim Login anzeigen"
L["CHECKBOX_AUTO"] = "Auto-Update bei Taschenänderung"
L["BTN_UPDATE"] = "Aktualisieren"
L["ERROR_INVALID_ITEM"] = "Ungültiger Gegenstand!"
L["ERR_COMBAT"] = "Aktion während des Kampfes nicht erlaubt!"
L["REMINDER_SETUP_HINT"]     = "|cffAAAAAA/cm — ConsumableMacro öffnen um fehlende Tabs zu konfigurieren.|r"
L["REMINDER_MISSING"] = "Fehlende Verbrauchsgüter:"
L["HELP_TEXT"] = "|cff00FF98ConsumableMacro Befehle:|r\n/cm - UI Fenster öffnen/schließen\n/cm update - Makros sofort aktualisieren\n/cm reset - Item-Listen zurücksetzen (mit Rückfrage)\n/cm profile <name> - Profil wechseln\n/cm help - Diese Hilfe anzeigen"

-- Detection Patterns
L["PATTERN_FLASK"] = {"fläschchen", "phiole"}
L["PATTERN_HEAL"] = {"heil", "belebend"}
L["PATTERN_HEALTHSTONE"] = {"Gesundheitsstein"}
L["PATTERN_EXCLUDE"] = {"tee", "wasser"}

L["TAB_BUFFFOOD"] = "Bufffood"
L["INFO_FOOD"] = "Stärkung"
L["SUB_FOOD"] = "Vor jedem Pull kochen oder kaufen. Nie auf nüchternem Magen raiden."

L["IE_HEADER"]         = "Import / Export"
L["BTN_EXPORT"]        = "Exportieren"
L["BTN_IMPORT"]        = "Importieren"
L["IMPORT_INVALID"]    = "Ungültiger Import-String."
L["IE_EXPORT_DESC"]    = "Tabs zum Exportieren auswählen:"
L["IE_IMPORT_DESC"]    = "Tabs zum Importieren auswählen:"
L["IE_NONE_SELECTED"]  = "Mindestens einen Tab auswählen."

L["RESET_HEADER"]        = "Zurücksetzen"
L["BTN_RESET"]           = "Listen zurücksetzen"
L["RESET_TITLE"]         = "Item-Listen zurücksetzen"
L["RESET_DESC"]          = "Tabs zum Zurücksetzen auswählen:"
L["RESET_NONE_SELECTED"] = "Mindestens einen Tab auswählen."

L["AUTOPOTION_HEADER"]              = "AutoPotion"
L["CHECKBOX_AUTOPOTION_ENABLE"]     = "AutoPotion-Makro aktivieren"
L["CHECKBOX_AUTOPOTION_STOPCAST"]   = "Vor Nutzung Zauber abbrechen"
L["LABEL_AUTOPOTION_RESET_SECONDS"] = "Reset (Sek.):"
L["BTN_AUTOPOTION_SYNC"]            = "Sync"
L["AUTOPOTION_RESET_DESC"]          = "Setzt die Sequenz nach dieser Anzahl Sekunden seit der letzten Nutzung zurück, statt nur bei Kampfbeginn. 0 = nur Kampfbeginn."
L["AUTOPOTION_SYNC_TOOLTIP"]        = "Aus Cooldown übernehmen\nLiest den Cooldown des Zaubers. Klingt er gerade ab, wird der exakte (talentierte) Wert genutzt, sonst die Basis-Abklingzeit als Näherung."
L["AUTOPOTION_SYNC_NO_SPELL"]       = "Kein bekannter Klassen-/Rassenzauber erkannt."
L["AUTOPOTION_SYNC_NOT_ON_CD"]      = "Cooldown für diesen Zauber konnte nicht ausgelesen werden."
L["AUTOPOTION_SYNC_SUCCESS"]        = "Reset-Verzögerung auf %d Sekunden gesetzt."
L["AUTOPOTION_SYNC_SUCCESS_APPROX"] = "Reset-Verzögerung auf %d Sekunden gesetzt (Basis-Cooldown - Talente evtl. nicht berücksichtigt)."
L["AUTOPOTION_TALENT_CHANGED_HINT"] = "Talente geändert - falls das die Abklingzeit deines AutoPotion-Zaubers betrifft, klicke erneut auf 'Sync'."
L["BTN_AUTOPOTION_CONFIGURE"]       = "Priorität konfigurieren"
L["AUTOPOTION_PRIORITY_TITLE"]      = "AutoPotion-Priorität"
L["AUTOPOTION_PRIORITY_DESC"]       = "Mit +/- die Reihenfolge festlegen, in der AutoPotion die Kategorien versucht."
L["LABEL_AUTOPOTION_CLASSSPELL"]    = "Klassen-/Rassenzauber"

L["RESTOCK_HEADER"]             = "Auktionshaus-Nachkauf"
L["BTN_RESTOCK_CONFIGURE"]      = "Nachkauf konfigurieren"
L["RESTOCK_CONFIG_TITLE"]       = "Nachkauf-Einstellungen"
L["CHECKBOX_RESTOCK_ENABLE"]    = "Nachkauf-Liste am AH anzeigen"
L["CHECKBOX_RESTOCK_BANK"]      = "Bank / Warband-Bank mitzählen"
L["RESTOCK_CONFIG_DESC"]        = "Items zum Nachkaufen anhaken und je eine Zielmenge festlegen."
L["RESTOCK_EMPTY"]              = "Noch keine Items. Zuerst im Hauptfenster hinzufügen."
L["RESTOCK_TITLE"]              = "Nachkauf"
L["RESTOCK_HINT"]               = "Zeile anklicken zum Suchen."
L["RESTOCK_MORE"]               = "+%d weitere"

L["PATTERN_FLEETING"]           = {"flüchtig"}

L["TAB_WEAPONENHANCE"]  = "Waffenverzauberung"
L["INFO_WEAPONENHANCE"] = "Geschärfte Klinge"
L["SUB_WEAPONENHANCE"]  = "Wetzsteine, Gewichtsteine und Waffenöle. Wird automatisch auf die Hand angewendet, der es fehlt."

L["PROFILE_HEADER"]         = "Profil"
L["PROFILE_NEW"]            = "Neues Profil"
L["PROFILE_COPY"]           = "Aktuelles Profil kopieren"
L["PROFILE_RENAME"]         = "Profil umbenennen"
L["PROFILE_DELETE"]         = "Profil löschen"
L["PROFILE_NAME_DESC"]      = "Profilnamen eingeben:"
L["PROFILE_COPY_NAME"]      = "%s Kopie"
L["PROFILE_DELETE_CONFIRM"] = "Profil \"%s\" löschen?\nChars, die es nutzen, erhalten ein neues Profil."
L["PROFILE_ERR_EMPTY"]      = "Profilnamen eingeben."
L["PROFILE_ERR_EXISTS"]     = "Profil existiert bereits."
L["PROFILE_ERR_UNKNOWN"]    = "Unbekanntes Profil: %s"
L["PROFILE_IMPORT_DESC"]    = "In neues Profil importieren? Namen eingeben oder ins aktuelle Profil importieren."
L["PROFILE_IMPORT_NAME"]    = "Import"
L["PROFILE_IMPORT_NEW"]     = "Neues Profil"
L["PROFILE_IMPORT_CURRENT"] = "Aktuelles"
L["PROFILE_SWITCHED"]       = "Profil: %s"

_G["ConsumableMacroLocale"] = L
