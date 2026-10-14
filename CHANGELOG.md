# Azeroth Creature Compendium

## v0.10.4-beta (2026-10-14)
- Fixed the minimap button appearing as a blank white circle when used with minimap addons such as Leatrix Plus and MinimapButtonBag.
- Added support for square minimaps and LibDataBroker display bars.

## v0.10.3-beta (2026-10-14)
- Added a setting in the Options panel and `/acc newmob` slash command to hide tooltip info on unrecorded creatures.
- Fixed creature tooltips so friendly NPCs, unattackable NPCs, pets, and critters are ignored.

## v0.10.2-beta (2026-10-03)
- Fixed a Lua error when zoning into dungeons caused by restricted nameplate identifiers.

## v0.10.1-beta (2026-10-02)
- Added medallion and portrait icons to creature research ranks on Pokédex cards and zone tooltips.
- Added automated release publishing to both CurseForge and GitHub Releases.

## v0.10.0-beta (2026-10-02)
- Added subzone tracking to record the local areas where each creature is found (e.g., Coldridge Valley or Kharanos within Dun Morogh).
- Added a "Found in:" line on creature cards showing recorded subzones.
- Added subzone matching to the Compendium search bar.

## v0.9.7-beta (2026-10-02)
- Fixed Lua errors when nearby enemies cast spells with protected client values.
- Added fallback handling so restricted enemy abilities are grouped under `Unknown (Protected Ability)` instead of causing errors.
- Added automatic cleanup for placeholder spell names once out of combat.

## v0.9.6-beta (2026-10-02)
- Added Bestiary research ranks (*Safari Greenhorn* through *The Hemetinator*) that progress as you kill, loot, and harvest creatures.
- Added zone progression tooltips when hovering over zones in the Compendium list.
- Simplified tooltip headers to *Compendium - Loot*, *Compendium - Combat*, and *Compendium - Professions*.

## v0.9.5-beta (2026-10-02)
- Fixed a bug where looting a corpse counted as an extra kill.
- Fixed an issue that prevented `/acc` and `/compendium` slash commands from working.
- Fixed `/acc status` inflating the total harvest count when run multiple times.

## v0.9.4-beta (2026-10-01)
- Added an Embedded tooltip mode to show creature data directly inside Blizzard's default tooltip.
- Added `Always` and `Never` display options for Loot, Combat, and Profession tooltip sections alongside `Shift`, `Ctrl`, and `Alt`.
- Added an option to stack sidecar tooltips vertically (above/below) or horizontally (beside).
- Added an option to anchor tooltips to the mouse cursor.
- Added `/acc anchor`, `/acc layout`, and `/acc dock` slash commands.
- Adjusted button font size and padding in the Options panel so labels fit cleanly.

## v0.9.1-beta (2026-10-01)
- Added a tooltip indicator when encountering an undocumented creature for the first time.
- Improved account-wide database loading across characters.
- Added a setting to show or hide tooltip hotkey hints.

## v0.9.0-beta (2026-10-01)
- Added the Compendium browser window (`/acc`) with 3D creature models, zone lists, loot tables, abilities, and immunities.
- Added combat tracking for enemy spells and immunities using standard unit and UI events.
- Added loot and profession gathering tracking (Skinning, Mining, Herbalism, Engineering).
- Added companion tooltips for loot, combat, and profession data.
- Added a draggable minimap button.
