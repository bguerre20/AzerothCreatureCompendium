# Azeroth Creature Compendium

[![WoW Forever](https://img.shields.io/badge/WoW_Forever-1.60.1-blue.svg)](https://worldofwarcraft.blizzard.com/)
[![Zero Taint](https://img.shields.io/badge/Security-Zero_Taint-brightgreen.svg)](docs/ARCHITECTURE.md)
[![Architecture](https://img.shields.io/badge/Docs-Architecture_Specification-informational.svg)](docs/ARCHITECTURE.md)
[![License](https://img.shields.io/badge/License-MIT-lightgrey.svg)](LICENSE)

**A personal creature journal and Pokédex for World of Warcraft Forever.**

**Azeroth Creature Compendium (ACC)** records information about the creatures you encounter as you explore, fight, and loot:
- **Creature Info**: Level ranges, creature family (Beast, Humanoid, Undead, Dragonkin, etc.), local subzones, and rare/elite classification. Map coordinates are saved for rare spawns.
- **Spells & Abilities**: Spells cast by each mob, tracked with spell icons, school colors, and cast counts.
- **Immunities**: Tracks creature immunities observed during combat, including spell schools (*Fire, Frost, Nature, Shadow, Arcane, Holy, Physical*) and mechanics (*Taunt, Bleed, Stun, Polymorph, Fear, Snare/Root, Silence, Sleep, Poison*) without using restricted combat log events.
- **Loot & Drop Rates**: Item drop percentages, sample sizes (e.g., `4/28 drops`), empty loot counts, and average coin dropped.
- **Profession Harvesting**: Separate tracking for Skinning, Mining, Herbalism, and Engineering corpse gathers with harvest counts and drop rates.

---

> ### Core Philosophy: Journey Before Destination
> This addon is developed with the core gameplay pillar of **Journey Before Destination**. While there may be many addons out there that have all this information baked in, and you can absolutely Google this and get all the answers on Wowhead, I felt that in the spirit of the game I wanted something that feels like an explorer's journal you are appending to as you play. You may not have all the info today, but if you keep playing you will keep accruing it and you can reference your personal compendium at any time.

---

## Features

### 1. Creature Tooltips (Sidecars or Embedded)
- **Three Data Sections:**
  - **Loot Drops (Default: `[SHIFT]`):** Item drop list, drop rates, sample sizes, and average coin.
  - **Combat Profile (Default: `[CTRL]`):** Level range, classification, recorded immunities, and spells cast.
  - **Profession Loot (Default: `[ALT]`):** Gathered corpse loot (Skinning, Mining, Herbalism, Engineering) with drop rates and skill tags.
- **Activation Modes:** Set each section independently to require a hotkey (`SHIFT`, `CTRL`, `ALT`), `ALWAYS` show on mouseover, or `NEVER` show.
- **Layout & Positioning:**
  - **Sidecar Mode (`SIDECAR`):** Attach companion tooltips horizontally beside or vertically above/below the main tooltip.
  - **Embedded Mode (`EMBEDDED`):** Append creature data directly inside Blizzard's default `GameTooltip`.
  - **Anchor Point:** Attach tooltips to Blizzard's main tooltip or follow the mouse cursor.
- **New Creature Indicator:** Shows a brief prompt on tooltips when you encounter an undocumented creature for the first time.

### 2. Compendium Browser (`/acc`)
- **Zone & Creature List:** Searchable list of discovered zones and creatures. Hover over any zone to view how many creatures and research ranks you have recorded there.
- **Creature Entry Card:**
  - **3D Model Preview:** Interactive creature model with click-and-drag rotation.
  - **Bestiary Ranks:** Creatures gain research ranks as you kill, loot, and harvest them, progressing from *Safari Greenhorn* to *Nesingwary's Apprentice*, *Master of the Hunt*, and *The Hemetinator*.
  - **Subzone Locations (`Found in:`):** Lists the local subzones where you have spotted each creature (for example, *Coldridge Valley and Kharanos*).
  - **Combat & Abilities Tab:** Lists recorded immunities and spells cast by the creature. Hover over any spell to view its Blizzard spell tooltip.
  - **Loot Table Tab:** Shows total looted corpses, empty loots, average coin, and item drop rates. Shift-click any item to link it in chat.
  - **Professions Tab:** Lists corpse gathering yields for Skinning, Mining, Herbalism, and Engineering.
- **Search Filter:** Filter the compendium by zone, subzone, creature name, spell, loot item, or profession material.

### 3. Minimap Button
- **Left-Click:** Open the Compendium window.
- **Right-Click:** Open Addon Settings.
- **Left-Drag:** Reposition around the minimap border.

---

## Slash Commands

Use `/acc`, `/compendium`, `/pokedex`, or the legacy aliases `/bgl` and `/bgloot`:

| Command | Action |
| :--- | :--- |
| `/acc` | Toggle the Compendium browser window |
| `/acc options` | Open the Interface Settings panel |
| `/acc minimap` | Toggle the minimap button |
| `/acc status` | Print database totals in chat |
| `/acc lootkey <SHIFT\|CTRL\|ALT\|ALWAYS\|NEVER>` | Set activation mode for the Loot tooltip |
| `/acc combatkey <SHIFT\|CTRL\|ALT\|ALWAYS\|NEVER>` | Set activation mode for the Combat tooltip |
| `/acc profkey <SHIFT\|CTRL\|ALT\|ALWAYS\|NEVER>` | Set activation mode for the Profession tooltip |
| `/acc layout <sidecar\|embedded>` | Switch between sidecar tooltips and the embedded tooltip |
| `/acc dock <beside\|above>` | Position sidecar tooltips beside or above/below the main tooltip |
| `/acc anchor <tooltip\|cursor>` | Anchor tooltips to the main tooltip or mouse cursor |
| `/acc max <1-25>` | Set the maximum number of items shown in tooltips |
| `/acc lookup <name>` | Search for a recorded creature in chat |
| `/acc reset confirm` | Clear all recorded compendium data |

---

## Data Migration & Technical Documentation

- **BgLootLogger Migration:** Existing `BgLootLoggerDB` saved data is automatically imported into `AzerothCreatureCompendiumDB` on first load.
- **Architecture & Development Docs:** For event flows, database schema details, and contributor guidelines, see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
