# ConsumableMacro – Changelog

All notable changes to this project are documented here.

---

## [Unreleased]

### Changed
- AutoPotion: removed the passive Healing Elixir talent from the spell list (it can't be cast).
- Internal: item detection uses Blizzard's item class names instead of bare numbers (no behavior change).

### Fixed
- AutoPotion: talent-granted self-heal spells are now recognized reliably.

---

## [2.0.5] – October 2026

### Changed
- Internal: next-frame deferrals now use `RunNextFrame` instead of `C_Timer.After(0, …)`.
- List rows and AutoPotion priority window: text buttons (+ / - / X) replaced by icon buttons (up / down arrows, red cross). The first row's up arrow and the last row's down arrow are greyed out.
- Windows next to Options (AutoPotion priority, Restock setup, import/export, reset, profile) no longer overlap: opening one closes the other. Closing Options closes them all.
- List rows show the item's crafting quality (rank) icon in front of the name, so the order is readable at a glance.
- Options: gear icon replaced by a normal "Options" button.
- Internal: Lua files moved into `Core/`, `Modules/` and `UI/` folders (load order unchanged).

---

## [2.0.4] – October 2026

### New
- Restock: new section "Other Items" for items without a tab. Add by ID, item link or drag & drop; remove with the X.
- Restock setup: click a section header to fold/unfold it.

---

## [2.0.3] – October 2026

### Fixed
- Weapon Enhancements: macro can now re-apply while an enchant is still running (refreshes the hand with the least time left).
- Weapon Enhancements: skips a hand no item in the list fits instead of leaving the macro empty.
- Weapon Enhancements: the periodic rebuild now respects Auto-Update.
- Adding items: food like "Steak" or "Steamed Fish" is no longer rejected as tea/water, and "Heilbutt" is no longer taken for a heal potion.

### Changed
- Internal cleanup: shared helpers, removed dead code and outdated comments. No behavior change.

---

## [2.0.2] – September 2026

### New
- Restock: optional per-item minimum count. When set, the item only shows in the AH panel once you're at or below it, instead of as soon as you're below target. Empty/0 falls back to the tab's minimum count (Options).

### Changed
- Reminder (login & post-instance) skips fleeting/conjured items (e.g. cauldron flasks) when picking the top-priority item in bags - they can't be restocked, so a low count on one isn't actionable.

### Fixed
- Weapon Enhancements macro still went blank when nothing from the list was in the bags at all (the 2.0.1 fix only covered "something's in bags but nothing to apply this cycle"). Now falls back to the top-priority configured item, matching every other tab.

---

## [2.0.1] – September 2026

### Fixed
- Weapon Enhancements macro showed a blank `#showtooltip` (no icon/tooltip) whenever there was nothing to apply that cycle (both hands already enchanted, or the hand that needs it has no weapon equipped - e.g. two-handers). It now always shows the top-priority item in bags, like every other tab, even when there's no action to append.

---

## [2.0.0] – September 2026

### New
- Weapon Enhancements tab: Whetstones, Weightstones and Weapon Oils share one priority list.
  - Correct item is auto-picked per weapon type (edged → Whetstone, blunt → Weightstone; Oils work on any weapon).
  - Only applies to a hand without an active temporary enchant - the other hand is left alone.
  - Only ever targets one hand per macro press (mainhand first, then offhand) - applying the same item to both hands in one click doesn't reliably work client-side. Using the item consumes it from the bags, which triggers the normal rebuild and points the macro at the other hand for the next press.
  - Whetstone/Weightstone/Oil are recognized by an explicit item-ID list (`CM.WEAPONENHANCE_IDS`) instead of name matching - some Midnight items didn't classify correctly by name/subclass alone (locale-dependent, unreliable). Confirmed: Refulgent Weightstone (237367, 237369) = blunt, Refulgent Whetstone (237370, 237371) = edged, Thalassian Phoenix Oil (243733, 243734), Oil of Dawn (243735, 243736) and Smuggler's Enchanted Edge (243737, 243738) = any. Add further quality-tier IDs there as they're found.
  - Macro rebuilds on bag changes, weapon swaps, and periodically (also catches a naturally expired buff).
  - Supports Restock, Reminder and Min-Count like the other tabs.

### Changed
- Main window width now scales with the number of tabs; item list, rows and the drop-zone box scale with it too, so adding a tab can't overflow the frame or leave a dead gap.

### Fixed
- `.toc` IconTexture pointed at a non-existent `icon.png`; addon list showed no icon. Corrected to the actual `Icon.tga`.

### Cleanup
- New `WeaponEnhance.lua`: weapon-type detection, per-hand macro body builder, enchant-state polling.
- New `CM.HideFrames(keys)` helper (Core.lua); replaces the duplicated hide-these-windows loop in `UI.lua` and `Profiles.lua`.
- Full pre-release audit: no dead code, no unused locale strings, all 10 Lua files verified with `luac -p`.

---

## [1.9.1] – September 2026

### New
- Profiles: item lists and all settings are stored per profile instead of account-wide (Options → Profile).
  - New / copy / rename / delete; `/cm profile <name>` switches.
  - Each character remembers its profile; new characters start with their own (`Name-Realm`).
  - Existing data is migrated once into the profile "Default".
  - Import asks whether to create a new profile or apply to the current one.

### Changed
- Reminder toggle, AutoPotion order and reset delay moved from per-character to the profile.
- Options window is smaller (520 px) and scrolls with the mouse wheel (no scrollbar).
- Options sections: features first, then Import/Export, Profile and Reset last.
- `/cm reset` opens the reset dialog (all tabs pre-ticked, OK confirms) instead of clearing everything at once.
- Login no longer rewrites existing macros (bag data may not be cached yet); it only creates missing ones. Existing macros update on the first bag change with Auto-Update on.
- Entering combat also closes dialogs opened without the main window; reset is blocked in combat.

### Fixed
- Reminder and main list now also follow bag changes with Auto-Update off (only the macro rebuild depends on it).
- Restock panel is re-anchored to the AH frame each time it opens (could stay misplaced if created before the AH UI existed).

### Cleanup
- New `Profiles.lua` (storage, migration, profile actions); `CM.db` points at the active profile.
- New `Core.lua` helpers: `CreateWindow`, `BindNumberBox`, `GetFirstInBags`, `GetItemIcon`, `ShowItemTooltip`, `TITLE`.
- Window boilerplate and numeric edit-box handling deduplicated across Options, AutoPotion, Restock and UI.
- Import/Export tab checkbox setup and the bag-refresh sequence in Events shared.
- Fixed a misplaced comment in `AutoPotion.lua`.

---

## [1.9.0] – September 2026

### New
- Restock: tick items per tab and set a target amount per item (Options → Configure Restock).
- AH panel next to the Auction House lists ticked items below target, with rank icon.
- Click a row to search that exact rank and pre-fill the missing amount as buy quantity.
  - Auctionator: exact name + rank + quantity via its API.
  - Default AH: opens the matching rank and fills the buy quantity.
- Optional: count bank / warband bank in the stock.
- Items that can't be bought at the AH (conjured/fleeting, bound incl. Warband-bound) are hidden from the setup.

### Changed
- Import keeps existing restock settings for IDs already in the list; duplicate/invalid IDs are ignored.
- All addon windows share one frame strata (same as the main window).
- Options frame made taller for the new section; sections reordered (features first, import/export and reset last).
- Closing the main window also closes Options, Import/Export, Reset, AutoPotion and Restock setup frames.
- Macros are only rewritten when their body changed; bag and item-data events are coalesced (less work on bag updates).

### Fixed
- Reminder "Okay" button is now localized.
- Export box no longer truncates long export strings.
- Minimum-count option text now describes what is actually checked (top-priority item in the bags).

### Cleanup
- `UI.lua` split into `UI.lua` (main window, skin), `Options.lua` (options, import/export, reset) and `Events.lua` (events, slash commands).
- Shared helpers in `Core.lua`: chat/error output, deferred calls, macro writing, pattern matching, item names, ElvUI skin access, checkbox creation.
- Import/Export and Reset frames share one dialog builder.
- Removed dead code: dev-only `/cm test` command, unused local, `PLAYER_LOGOUT` handler, redundant SavedVariables init, duplicate list refresh on `/cm`.
- TOC comments translated to English.

---

## [1.8.2] – September 2026

### Changed 
- Toc updated
### Fixed
- AutoPotion "talent changed" hint no longer fires from profession trait trees — now filtered to the active class talent config only.

---

## [1.8.1] – September 2026
### Fixed
- Reminder (login & post-instance) no longer shows on non-max-level characters.

---

## [1.8.0] – September 2026
### New
- AutoPotion: optional `CM_AutoPotion` panic-button macro (class/racial spell + Heal Potion + Healthstone via `/castsequence`), configurable priority order, per-character reset delay with cooldown "Sync".

### Fixed
- Class/racial spell detection switched to `C_SpellBook.IsSpellKnown` (legacy API unreliable in current retail).
- Removed spell ID 108238 (Renewal) from the Warrior entry — it's a Druid talent, not Warrior; was never correctly matched anyway.
- AutoPotion reset delay and priority order now saved per character (was account-wide).
- Options gear icon switched from `.tga` to `.png`.

### Cleanup
- Deduplicated macro-trim and ElvUI checkbox-skin logic; removed unused locale keys.

---

## [1.7.3] – August 2026
### Fixed
- Post-instance reminder no longer fires when leaving player housing (neighborhood/interior instance types excluded).

---

## [1.7.1] – August 2026
### Changed
- TOC bumped to `120100` for Patch 12.1.0. No code changes needed (API check only).

---

## [1.7.0] – June 2026
### Fixed
- Post-instance reminder now also fires for delves (`ZONE_CHANGED_NEW_AREA` monitored alongside `PLAYER_ENTERING_WORLD`).
- `isLoginPending` no longer gets stuck `true` after an unmatched login event (e.g. `/reload`).

### Changed
- Login reminder check now fires ~1s after `PLAYER_ENTERING_WORLD` instead of a fixed 5s delay.

### Cleanup
- Removed unused `reminderTimerPending`.

---

## [1.6.9] – June 2026
### Changed
- TOC updated.

---

## [1.6.8] – June 2026
### Fixed
- Reminder no longer fires on open-world teleports to unusual instance zones — switched to `IsInInstance()`'s `inInstance` boolean.

---

## [1.6.7] – June 2026
### Fixed
- Reminder no longer fires on open-world teleports — replaced `GROUP_LEFT` detection with a single `wasInInstance` flag.

### Cleanup
- Unregistered unused `GROUP_LEFT` event.

---

## [1.6.6] – June 2026
### Fixed
- IE/Reset frames now anchor next to the Options frame instead of screen center.
- `CreateMacro` account-wide macro limit check corrected.
- `UpdateReminderFrame` recalculates frame height after text updates.
- Removed redundant ElvUI skin call on reminder Okay button.

### Changed
- `ExportString`/`ApplyImport` accept an optional tab filter.
- Removed `CM_IMPORT_CONFIRM` popup (IE frame now confirms imports).

### Cleanup
- Removed dead `CM.SKIP_TABS`; version strings removed from Lua headers (TOC/CHANGELOG are authoritative).

---

## [1.6.5] – June 2026
### New
- Import/Export for item lists (tab-selection frame, shared between both modes).
- Reset frame — per-tab checkboxes, resets only selected tabs.
- All new UI elements ElvUI-skinned.

---

## [1.6.4] – June 2026
### Fixed
- Stale `wasInInstance` flags from portal transitions now cleaned up on `PLAYER_ENTERING_WORLD`.
- State variables moved before the event handler frame (were implicit globals).
- `GetNumMacros()` — both account-wide and per-character limits now checked.
- Macro body length guard corrected to 254 chars (null terminator counts toward 255).

### Cleanup
- `REMINDER_SKIP`/`MINCOUNT_SKIP` made independent copies instead of shared-table aliases.
- Removed dead `reminderShownThisLogin`.

---

## [1.6.3] – May 2026
### Fixed
- Reminder no longer appears leaving an open-world group or using a portal while grouped.
- Reminder no longer appears after leaving an instance with all minimum counts at 0.

---

## [1.6.2] – May 2026
### Fixed
- Reminder no longer appears when teleporting straight into a new instance after leaving one.

---

## [1.6.1] – May 2026
### Fixed
- Reminder no longer appears when using teleport items (never actually entered an instance).

---

## [1.6.0] – May 2026
### New
- Post-instance reminder via `GROUP_LEFT`, shown 2s after returning to the open world.
- Only fires if at least one tab has `minCount > 0`.

### Fixed
- Removed duplicate `InCombatLockdown()` check in `AddItemToDatabase`.

---

## [1.5.1] – May 2026
### Fixed
- Replaced race-prone `reminderShownThisLogin` with `isLoginPending` flag.

---

## [1.5.0] – May 2026
### New
- Reminder also appears after leaving a dungeon/raid if consumables are missing/low.

### Fixed
- Reminder no longer appears when entering an instance during the login timer.

---

## [1.4.1] – May 2026
### Fixed
- Reminder no longer reappears on every portal/zone change — login and relog only.

---

## [1.4.0] – May 2026
### New
- Options window (gear icon) — Auto-Update, Reminder toggle, per-tab minimum count.
- Minimum count warning, shown as `(current/min)` in orange.
- Setup hint line (`/cm`) when tabs are unconfigured.

### Improved
- Reminder shows top-priority item count per tab (green/orange/red).
- Gold countdown bar instead of fade animation.
- ElvUI-matched backdrop; drop-shadow text.

### Fixed
- Several reminder display/timing bugs (color flash, relog reappearance, save-on-close).

---

## [1.3.0] – May 2026
### New
- Login reminder (draggable, auto-dismiss, per-character toggle).

### Refactor
- Split into `Core.lua`, `Reminder.lua`, `Items.lua`, `UI.lua`.

### Fixed
- Reminder no longer appears after `/reload`; various nil-guard and combat-end bugs.

---

## [1.2.0] – May 2026
### New
- Name-based Healthstone pattern detection; `HEALTHSTONE_IDS` for fast ID matching.

### Fixed
- Demonic Healthstone now addable (was rejected as soulbound).
- Pattern matching switched to plain-text search (no regex crashes).

---

## [1.1.1] – April 2026
### Cleanup
- Removed trailing whitespace and dead state; verified locale key parity.

---

## [1.1.0] – April 2026
### Improved
- Polished EN/DE UI text and fixed a mixed-language string.

---

## [1.0.9] – April 2026
### Fixed
- Macro now uses only the first available item per priority list.

---

## [1.0.8] – April 2026
### Changed
- Dropped Interface 12.0.1 — targeting 12.0.5 only.

---

## [1.0.7] – April 2026
### Fixed
- Added subclass fallback for Flasks/Elixirs; dynamic scroll height; nil-guarded ElvUI calls.

---

## [1.0.6] – Initial Release
- Auto-managed macros for Flask, Potion, Heal Pots, Healthstone, Buff Food.
- Priority lists, Item-ID/drag & drop, auto-update on bag change.
- Combat-safe, ElvUI skin support, full EN/DE localization.
