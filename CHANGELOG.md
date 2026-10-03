# Azeroth Creature Compendium

## v0.10.2-beta (2026-10-03)
- **Protected Nameplate Fix:** Fixed a Lua error ("attempt to perform string conversion on a secret string value") that occurred when zoning into instances. The addon now safely handles secret GUIDs from protected nameplates (like in Ragefire Chasm) without crashing or tainting execution.

## v0.10.1-beta (2026-10-02)
- **Bestiary Progression Badges & Medals:** Added classic World of Warcraft medallion and portrait iconography to the creature research rank system. View bronze, silver, gold medallions, and the Hemet Nesingwary dwarf hunter badge directly on each creature's Pokédex card and inside zone mastery tooltips.
- **Release Channel Synchronization:** Addon updates now automatically publish package releases to both CurseForge and GitHub Releases.

## v0.10.0-beta (2026-10-02)
- **Creature Subzone Tracking:** The compendium now records the specific local areas and subzones where each creature is sighted (e.g. *Coldridge Pass* or *Kharanos* within *Dun Morogh*).
- **Sub-Location Compendium Display:** A new "Found in:" entry on each creature's Pokédex card displays all unique subzones where you've encountered that mob (e.g. *"Found in: Coldridge Valley and Kharanos"*).
- **Subzone Search Filtering:** The Compendium search bar now matches local subzone names, allowing you to instantly find all creatures documented in a specific pass, camp, valley, or town.
- **Dynamic Location Formatting:** Displays natural English phrasing for single or multiple locations, with automatic fallback to the parent zone when roaming open wilderness.

## v0.9.7-beta (2026-10-02)
- **Combat Ability & Spellcast Fix:** Fixed Lua errors ("attempt to perform string conversion on a secret string value" and "attempted to perform indexed assignment on a table that cannot be indexed with secret keys") when nearby hostile creatures cast spells in the player's presence.
- **Modern Client Compatibility:** Added automatic safeguards for restricted combat strings and secret payload numbers introduced in recent game engine updates (11.0.0+), ensuring spells cast during combat are safely captured via global API fallbacks.
- **Protected Ability Aggregation:** Abilities that are completely obfuscated by Blizzard's new engine protections are now aggregated into a single, clean `Unknown (Protected Ability)` entry in a creature's combat profile rather than causing the UI to crash or failing to record.
- **Database Self-Healing:** The compendium automatically repairs any placeholder spell names from previous combat encounters as soon as you view the creature or exit combat.

## v0.9.6-beta (2026-10-02)
- **Bestiary Progression Ranks:** Mobs will now level up in rank as you interact with them (kills, loots, and harvests). Track your progression from *Safari Greenhorn* all the way up to *The Hemetinator* directly on the creature's Pokédex card.
- **Zone Progression Tooltips:** Hover over a zone in the Compendium registry list to see a full breakdown of the species documented and ranks mastered in that area.
- **Simplified Tooltip Headers:** Streamlined tooltip section headers to *Compendium - Loot*, *Compendium - Combat*, and *Compendium - Professions*, removing redundant creature name repetitions across both embedded and sidecar views.

## v0.9.5-beta (2026-10-02)
- **Accurate Mob Kill Tracking:** Fixed an issue where looting a mob corpse would record a duplicate kill count. Mob kills are now reliably counted once per unique corpse.
- **Slash Commands Restored:** Fixed an issue preventing `/acc`, `/compendium`, and related slash commands from functioning.
- **Harvest Statistics Fix:** Fixed a bug where running `/acc status` multiple times would continuously inflate the total harvest count in the chat output.
- **Performance & Cleanup:** Optimized internal variable handling and UI drag handlers for reduced memory overhead.

## v0.9.4-beta (2026-10-01)
- **Settings UI Polish:** Reduced button text font size and optimized button padding in the Options panel so labels like `[ALWAYS]` fit cleanly without clipping.
- **Mouse Cursor Tooltip Anchoring:** Added an option to anchor creature tooltips directly at your mouse cursor or keep them attached to Blizzard's main tooltip.
- **Embedded Tooltip Mode:** Added an option to display creature drop tables, combat profiles, and profession loot directly inside Blizzard's default creature tooltip instead of separate sidecars.
- **Always & Never Activation Modes:** Each tooltip category (Loot Drops, Combat Profile, Profession Loot) can now be set to require a hotkey (Shift, Ctrl, Alt), Always show automatically on mouseover, or Never show (disabled).
- **Sidecar Docking Options:** When using sidecars, choose between docking them beside the main tooltip (horizontal) or stacked above/below it (vertical).
- **Cleaner Creature Tooltips:** Hotkey hint lines now dynamically hide any categories configured to Always or Never.
- **New Slash Commands:** Added `/acc anchor <tooltip|cursor>`, `/acc layout <sidecar|embedded>`, and `/acc dock <beside|above>`.

## v0.9.1-beta (2026-10-01)
- **First Encounter Feedback:** Added instant visual indicator on creature tooltips when encountering a new mob for the first time.
- **Account-Wide Discovery Verification:** Enhanced cross-character database synchronization for shared creature discoveries.
- **Tooltip Hint Toggle:** Added settings option to toggle tooltip keybind hint visibility.

## v0.9.0-beta (2026-10-01)
- **Pokédex Compendium UI:** Interactive creature compendium window with 3D model previews, zone mob lists, drop tables, abilities, and immunities.
- **Zero-Taint Combat Discovery:** Automatically discovers auto-attack damage types, cast spells, and immunities as you fight mobs without action bar taint.
- **Loot & Profession Logging:** Logs creature drops and gathering profession yields (Skinning, Mining, Herbalism, Engineering).
- **Sidecar Tooltips:** Contextual floating tooltips displaying creature drop tables and combat profiles on mouseover with Shift/Ctrl/Alt hotkeys.
- **Minimap Button:** Quick-access minimap button with left-click to open compendium and right-click for options.
