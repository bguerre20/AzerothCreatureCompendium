# Azeroth Creature Compendium

[![WoW Classic](https://img.shields.io/badge/WoW_Classic-1.15.x-blue.svg)](https://worldofwarcraft.blizzard.com/)
[![Zero Taint](https://img.shields.io/badge/Security-Zero_Taint-brightgreen.svg)](docs/ARCHITECTURE.md)
[![Architecture](https://img.shields.io/badge/Docs-Architecture_Specification-informational.svg)](docs/ARCHITECTURE.md)
[![License](https://img.shields.io/badge/License-MIT-lightgrey.svg)](LICENSE)

**A Pokédex for every creature you encounter across World of Warcraft Classic.**

The **Azeroth Creature Compendium (ACC)** dynamically observes, catalogs, and indexes every mob you encounter on your journey. As you explore, fight, and loot, the compendium records:
- **Mob Identity & Visual Classification**: Level ranges, creature type/family (Beast, Humanoid, Undead, Dragonkin, etc.), and distinctive badge styling:
  - 🥈 **Rare Spawns**: Silver styling with persistent discovery coordinates.
  - 🥇 **Elites**: Authentic golden styling highlighting dangerous world encounters.
- **Combat Profile & Auto-Attacks**: Melee swing damage ranges (min, max, average) and damage school.
- **Spells & Abilities**: Every spell cast by the mob, tracked with spell icon, damage/healing values, buffs/debuffs, and cast frequency.
- **Taint-Free Immunities Verification**: Automatically identifies creature immunities as they happen in combat—including **Spell Schools** (*Fire, Frost, Nature, Shadow, Arcane, Holy, Physical*) and **Mechanics** (*Taunt, Bleed, Stun, Polymorph, Fear, Snare/Root, Silence, Sleep, Poison*).
- **Loot Table & Drop Rates**: Exact percentage (%) and decimal drop chances, sample sizes (e.g. `4/28 drops`), empty loot occurrences, and average coin drop.
- **Profession Corpse Harvesting**: Separate tracking for Skinning, Mining, Herbalism, and Engineering corpse gathers with individual drop rates and harvest counts.

---

> ### 🧭 Core Philosophy: Journey Before Destination
> This addon is developed with the core gameplay pillar of **Journey Before Destination**. While there may be many addons out there that have all this information baked in, and you can absolutely Google this and get all the answers on Wowhead, I felt that in the spirit of the game I wanted something that feels like an explorer's journal you are appending to as you play. You may not have all the info today, but if you keep playing you will keep accruing it and you can reference your personal compendium at any time.

---

## 🏗️ System Architecture Overview

The compendium follows a decoupled, event-driven architecture designed for zero game taint, zero performance overhead, and low memory consumption:

```mermaid
graph TD
    Client["Blizzard WoW Client<br/>(Unit, Spell, Loot & Error Events)"] --> Engines["Observation Engines<br/>(Core.lua & CombatLog.lua)"]
    Engines --> DB[("Authoritative Database<br/>(AzerothCreatureCompendiumDB)")]
    DB --> Tooltips["3x Companion Sidecars<br/>(Loot, Combat, Professions)"]
    DB --> Browser["Pokédex Window (/acc)<br/>(3D Model, Search & Tabs)"]
    DB --> Minimap["Draggable Minimap Button"]
    DB --> Options["Blizzard Settings Panel"]
```

> 📖 **Deep Dive Documentation:**  
> For complete component diagrams, lifecycle sequence diagrams, database schemas, taint-safety design decisions, and AI agent guidelines, refer to **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)**.

---

## 🏛️ Data Hierarchy

The compendium organizes all data into an intuitive, scalable tree:

```text
Zone (e.g., Elwynn Forest / Westfall / Dun Morogh)
  └── Mob (e.g., Hogger / Timber / Vagash)
        ├── Metadata: Level range, Classification (Rare/Elite), Creature Family, Kills, First/Last seen
        ├── Subzones: Local areas where the creature was sighted (e.g., Coldridge Valley, Kharanos)
        ├── Research Rank: Bestiary mastery tier (Safari Greenhorn -> The Hemetinator) with medallion badges
        ├── Coordinates: Verified map coordinates (strictly tracked for Rare Spawns)
        ├── Combat (Sibling Child 1):
        │     ├── Melee / Auto-Attacks (Min, Max, Avg damage, Swings)
        │     ├── Spells & Abilities (Icons, Schools, Cast counts, Damage/Heals)
        │     └── Known Immunities (Fire, Nature, Taunt, Bleed, etc.)
        ├── Loot (Sibling Child 2):
        │     ├── Drop rate percentages (%) and decimals
        │     ├── Occurrence counts & sample sizes
        │     ├── Empty loot tracking
        │     └── Average copper/silver/gold drop
        └── Professions (Sibling Child 3):
              ├── Skinning, Mining, Herbalism, and Engineering corpse drops
              ├── Harvest counts & drop rates per gathered item
              └── Skill breakdown (e.g. Skinning vs Mining)
```

---

## 🎮 Features

### 1. Flexible Creature Tooltips (Sidecars or Embedded)
- **Three Data Categories:**
  - **Loot Drops (Default: `[SHIFT]`):** Displays the mob's item drop table, drop chance percentages, sample sizes, and average coin dropped.
  - **Combat Profile (Default: `[CTRL]`):** Displays the mob's level, classification, verified immunity badges, auto-attack damage range, and spells cast with spell school colors.
  - **Profession Loot (Default: `[ALT]`):** Displays gathered corpse loot (Skinning, Mining, Herbalism, Engineering) with drop chance percentages, sample sizes, and skill badges.
- **Activation Modes:** Configure each category independently to require a modifier key (`SHIFT`, `CTRL`, `ALT`), `ALWAYS` show automatically on mouseover, or `NEVER` show.
- **Layout & Docking Options:**
  - **Dedicated Sidecars (`SIDECAR`):** Dock companion tooltips horizontally **Beside** or vertically **Above/Below** Blizzard's `GameTooltip`.
  - **Embedded Mode (`EMBEDDED`):** Merge creature drop tables, combat profiles, and profession loot directly inside Blizzard's default `GameTooltip`.
  - **Anchor Selection:** Attach tooltips to Blizzard's main tooltip or directly at your mouse cursor.
- **First Encounter Feedback:** Instant visual indicator when encountering an undocumented creature for the first time.

### 2. Standalone Three-Tab Pokédex Browser (`/acc`)
- **Left Registry Pane:** Searchable tree listing all discovered zones and mobs, with **Zone Mastery Hover Tooltips** showing species documented and Bestiary ranks earned in each zone.
- **Right Pokédex Entry Card:**
  - **3D Interactive Creature Model:** Rendered in real-time with 360-degree mouse drag rotation.
  - **Bestiary Progression Ranks & Medallions:** Creatures level up as you interact with them (kills, loots, and harvests) from *Safari Greenhorn* (Bronze Talisman) $\rightarrow$ *Nesingwary's Apprentice* (Silver Talisman) $\rightarrow$ *Master of the Hunt* (Gold Medallion) $\rightarrow$ *The Hemetinator* (Dwarf Hunter Portrait).
  - **Local Subzone Tracking (`Found in:`):** Automatically records and displays the specific local subzones where you have encountered each creature (e.g., *"Found in: Coldridge Valley and Kharanos"*).
  - **Distinct Visual Classification:** Silver rarity tags for rare spawns with coordinates; golden tags for elite encounters.
  - **[Combat & Abilities] Tab:** Displays verified immunities in color-coded badges, melee damage, and every spell cast by the creature. Hovering any spell displays the full Blizzard spell tooltip!
  - **[Loot Table] Tab:** Shows total loot sessions, empty loots, average coin, and a scrollable table of all drops with quality colors and drop rates. Shift-click any item to link it in chat!
  - **[Professions] Tab:** Dedicated harvesting loot table consolidated for Skinning, Mining, Herbalism, and Engineering corpse gathers! Tracks harvest counts, drop rates, and tags each drop with its gathering skill.
- **Fast Search:** Live filtering across Zone names, Local Subzones, Creature names, Spells/Attacks, Loot items, or Profession materials.

### 3. Draggable Minimap Tome Icon
- Authentic golden tome icon framed in warm classic bronze.
- Dynamically calculates distance to match custom HUD scale and Edit Mode adjustments.
- **Left-Click:** Open Pokédex Window.
- **Right-Click:** Open Addon Settings.
- **Left-Drag:** Move around the minimap rim.

---

## ⌨️ Slash Commands

Use `/acc`, `/compendium`, `/pokedex`, or the legacy aliases `/bgl` / `/bgloot`:

| Command | Action |
| :--- | :--- |
| `/acc` | Toggle the Pokédex Compendium Browser window |
| `/acc options` | Open the Blizzard Interface Settings panel |
| `/acc minimap` | Toggle the minimap tome button |
| `/acc status` | Print database summary (creatures, spells, drops, harvests, immunities) |
| `/acc lootkey <SHIFT\|CTRL\|ALT\|ALWAYS\|NEVER>` | Configure activation mode for Loot tooltip |
| `/acc combatkey <SHIFT\|CTRL\|ALT\|ALWAYS\|NEVER>` | Configure activation mode for Combat tooltip |
| `/acc profkey <SHIFT\|CTRL\|ALT\|ALWAYS\|NEVER>` | Configure activation mode for Profession tooltip |
| `/acc layout <sidecar\|embedded>` | Switch between Dedicated Sidecars and Embedded main tooltip |
| `/acc dock <beside\|above>` | Dock sidecar tooltips horizontally beside or vertically above/below |
| `/acc anchor <tooltip\|cursor>` | Anchor tooltips to Blizzard's main tooltip or mouse cursor |
| `/acc max <1-25>` | Change maximum items displayed in tooltip |
| `/acc lookup <name>` | Search recorded creature in chat |
| `/acc reset confirm` | Permanently wipe recorded history |

---

## 🔄 Automatic Data Migration
- **Legacy Migration:** If you previously used `BgLootLogger`, your existing database (`BgLootLoggerDB`) is **automatically detected and migrated** into `AzerothCreatureCompendiumDB` on first launch with zero data loss.
