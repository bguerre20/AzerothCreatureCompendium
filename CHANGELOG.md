# Azeroth Creature Compendium

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
