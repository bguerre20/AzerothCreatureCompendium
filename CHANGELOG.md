# Azeroth Creature Compendium

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
