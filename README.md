# ConsumableMacro

Automatically creates and maintains macros for the best available consumables in your bags. No manual macro editing.

For World of Warcraft: Midnight (12.1, 12.1.5) and WoW Forever. English and German. Optional: ElvUI (auto-detected skin), Auctionator (Restock search).

**Author:** Nightwalker559 · **License:** MIT with AI restriction

---

## Features

- **Auto-managed macros** for Flask, Potion, Heal Potion, Healthstone, Buff Food and Weapon Enhancements. WoW Forever adds Mana Pots, Food & Drink and, for rogues, Poisons.
- **Priority lists** per category: add items by ID or drag & drop, reorder with the arrows. Macros always use the best item currently in your bags and update on bag changes (toggleable).
- **Item catalog:** a searchable list of known items per category, one click adds an item. Works in every client language; the lists start empty.
- **Reminder** for missing or low consumables on login and after leaving a dungeon, raid, delve or scenario, with a minimum count per category.
- **AutoPotion:** an optional panic-button macro (`CM_AutoPotion`) that steps through a class/racial self-heal, your top Heal Potion and your Healthstone in one `/castsequence`.
- **Weapon Enhancements:** Whetstones, Weightstones and Oils in one list, applied to whichever hand needs it.
- **Restock:** tick items and set a target amount; a panel at the Auction House lists what is short with one-click search.
- **Profiles** and **Import/Export** per category. All actions that change macros are blocked in combat.

## Usage

| Command | What it does |
| --- | --- |
| `/cm` | Open or close the main window |
| `/cm update` | Update all macros now |
| `/cm profile <name>` | Switch profile (no name: show the current one) |
| `/cm reset` | Reset selected categories |
| `/cm help` | List the commands |

**Adding items:** open the **Catalog** next to the drop zone and click an item, type an item ID and press Enter, or drag an item from your bags. The category is detected automatically. **Options** holds the toggles, minimum counts, Import/Export, profiles, reset, AutoPotion and Restock.

## Profiles

Item lists, minimum counts, Reminder, AutoPotion and Restock settings live in a profile. Pick, create, copy, rename or delete profiles in Options; each character remembers its own. New characters start with a `Name-Realm` profile, or pick a shared one to reuse a setup. Switching rebuilds all macros (not in combat).

## AutoPotion

Enable it in Options, set the order under **Configure Priority** (Class/Racial Spell, Heal Potion, Healthstone) and drag the macro to your bar. Each press advances one step; the sequence resets on combat start or after your **Reset (sec.)** delay (**Sync** reads the exact cooldown from a spell on cooldown). Steps with nothing available are skipped. Disabling AutoPotion deletes the macro.

## Weapon Enhancements

One list for all types: Whetstones go on edged weapons, Weightstones on blunt weapons, Oils on any weapon. Each click targets one hand: one without a temporary enchant first, then the one with the least time left (you can re-apply any time). Hands no item fits are skipped.

## Restock

1. Options → **Configure Restock**, enable **Show restock list at the AH**.
2. Tick the items you use and set a target amount each. Add items without a category under **Other Items**. An optional per-item minimum shows an item only once you are at or below it.
3. At the Auction House a panel lists every ticked item below target (`have/target`) with its rank icon. A click searches that rank and pre-fills the missing amount as buy quantity.

Searches use Auctionator if installed, otherwise the default AH. Bank and warband bank can be counted. Healthstones, conjured and bound items are hidden. Purchases count once collected from the mail. Restock settings are not part of the export string.

## WoW Forever poisons (rogues)

Two lists, **Poison 1** (main hand) and **Poison 2** (off hand). The macro `CM_Poison` uses the first poison of each list that is in your bags. Each click poisons one weapon: a bare one first, otherwise the one with the least time left; a poison with more than 5 minutes left is not replaced.

## Import/Export

```
CM:1:flask=191534,191533:potion=191338:healpotion=191380:bufffood=197784
```

Item order is priority (first = highest). Empty categories are omitted. Both Export and Import let you pick the categories. On import, Restock settings are kept for item IDs that already exist.

---

See the [changelog](https://github.com/Nightwalker559/ConsumableMacro/blob/main/CHANGELOG.md) for the version history.

## Feedback

Found a bug or have an idea? [Open an issue on GitHub](https://github.com/Nightwalker559/ConsumableMacro/issues).

## License

MIT with AI restriction (no use for AI or machine learning), see [LICENSE.md](https://github.com/Nightwalker559/ConsumableMacro/blob/main/LICENSE.md).
