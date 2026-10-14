# AI Agent Guidelines & Operating Rules

> **Repository:** Azeroth Creature Compendium (World of Warcraft Classic)  
> **Target Audience:** All AI Coding Agents (Antigravity, Cursor, Claude Code, GitHub Copilot) & Pair Programmers  
> **Status:** Mandatory / Enforced

---

## 🧭 Core Architectural Principles

1. **Journey Before Destination:** This addon serves as an in-game personal journal and compendium that dynamically discovers mob data as the player explores, fights, and loots. It does NOT pre-populate full world drop tables.
2. **Zero-Taint Execution:** Never subscribe to restricted combat log streams (`COMBAT_LOG_EVENT_UNFILTERED`) or hook protected action buttons. All discovery must use public, unrestricted unit and UI events (`UNIT_SPELLCAST_*`, `UI_ERROR_MESSAGE`, `LOOT_OPENED`, etc.) to prevent combat action taint in Classic raids and PvP.
3. **Single Source of Truth:** Technical architecture, sequence flows, database schemas, and module interfaces are centralized in **[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)**. Never create separate redundant architecture files.

---

## 🤖 Specialist Agent Pipeline (`wow-addon-studio`)

This repository uses the global **`wow-addon-studio`** plugin pipeline. Activate the matching specialist skill/subagent for each phase of work:
1. **Requirements & Design (`wow-spec-architect`):** Use when brainstorming, gathering requirements, or designing a new feature/bugfix spec before coding.
2. **Implementation & Local Deploy (`wow-addon-engineer`):** Use when writing Lua code on a dedicated branch, enforcing zero-taint/secret-value safety, syncing `docs/ARCHITECTURE.md`, and running `lint.ps1` + `deploy.ps1`.
3. **Branch Closeout & CurseForge Release (`wow-release-engineer`):** Use after in-game testing to audit `.pkgmeta`/`README.md`, merge/prune branches, author player-centric `CHANGELOG.md` notes, and push annotated `vX.Y.Z` tags.

---

## 🚨 MANDATORY RULE: Architecture & Doc Sync (Definition of Done)

**Every feature, bugfix, or refactoring branch MUST update [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) and [`README.md`](README.md) whenever architectural components or player-facing features are affected—even if the user or issue prompt does not explicitly request it.**

Before declaring any task complete or submitting a pull request, you **MUST** run through this Architecture Audit checklist:

| If your code touched... | You MUST update in `docs/ARCHITECTURE.md` & `README.md`: |
| :--- | :--- |
| **`Database.lua`** | • Update the **Database Architecture & Schema Specification** (ER tree).<br/>• Document any new fields, types, or backward-compatibility migrations.<br/>• Update data factory references if mutation methods changed. |
| **`CombatLog.lua` or `Core.lua`** | • Update the **Combat & Immunity** or **Loot & Gathering** Mermaid sequence diagrams.<br/>• Update registered WoW client events in the **System Architecture Diagram**.<br/>• Document any new mechanic patterns or spell school mappings. |
| **`Tooltip.lua` or `CompendiumWindow.lua`** | • Update the **Dual Tooltip Layout & Docking Engine** diagram.<br/>• Document new Pokédex tabs, 3D model behaviors, or search filters in the Component Breakdown and `README.md`. |
| **`Config.lua`** | • Update default configuration options, color hex codes, or slash commands in `docs/ARCHITECTURE.md` and the Slash Commands table in `README.md`. |
| **`Options.lua`** | • Document new settings controls or Blizzard Interface Options categories. |
| **New Files / TOC / Art Folders** | • Update the **Component Breakdown & File Registry** table and TOC load order list.<br/>• Ensure any non-runtime files/folders (e.g., `Art/`, docs, scripts) are excluded in **both** [`.pkgmeta`](.pkgmeta) and [`deploy.ps1`](deploy.ps1). |

---

## 🛡️ Non-Negotiable Coding Standards

### 1. Database Mutations via Factory Only
- Never write raw tables directly into `db.zones[mapID].mobs[npcID]`.
- Always mutate through `addon:GetOrCreateMob(mapID, zoneName, npcID, mobName)` or designated recording methods (`RecordLoot`, `RecordProfessionLoot`, `RecordSpellCast`, `RecordImmunity`, etc.).

### 2. Coordinate Tracking Policy
- **Coordinates are strictly reserved for Rare Spawns** (`classification == "rare"` or `"rareelite"`).
- Never persist map coordinates for standard normal or elite mobs. This keeps SavedVariables lean and prevents megabytes of redundant coordinate bloat.

### 3. Memory-Bounded Ring Buffers
- Any corpse or session tracking caches (`lootedCorpseGUIDs`, `harvestedCorpseGUIDs`) must be bounded using a FIFO ring buffer (capped at 400 entries) to prevent memory leaks during extended farming sessions.

### 4. Zero Absolute Paths in Documentation
- Never commit absolute local filesystem URIs (e.g. `file:///C:/Users/...` or drive letters) into markdown documents or Lua source files.
- All file links in documentation must be **repository-relative** (e.g. `[Config.lua](../Config.lua)` or `[ARCHITECTURE.md](docs/ARCHITECTURE.md)`).

### 5. TOC Manifest Integrity
- Maintain strictly sequential file dependencies in `AzerothCreatureCompendium.toc`:
  1. `Config.lua` (constants, defaults)
  2. `Database.lua` (data layer, schema, factory)
  3. `CombatLog.lua` (combat discovery)
  4. `Core.lua` (master event listener & loot coordinator)
  5. `Tooltip.lua` (sidecar frames)
  6. `CompendiumWindow.lua` (Pokédex UI & minimap button)
  7. `Options.lua` (Blizzard settings)

---

## 🔄 Git & Branching Workflow

1. **Always Work on a Dedicated Branch:** Never commit directly to `main`.
   - Feature: `feat/<issue-num>-<short-description>`
   - Bugfix: `fix/<issue-num>-<short-description>`
   - Documentation / Workflow: `docs/<short-description>` or `chore/<short-description>`
2. **Commit Convention:** Use Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`).
3. **Issue Linking:** Reference issue numbers in commits and pull requests (e.g., `Closes #12`).
4. **Deploy & Validate:** Always test using `powershell -ExecutionPolicy Bypass -File .\deploy.ps1` before proposing changes.

---

## 📝 User-Facing Documentation, Changelogs & CurseForge Standards

**All public player documentation (`README.md`, `CHANGELOG.md`, `.toc` Notes, and CurseForge descriptions) must read like a concise, natural human developer wrote them for fellow players.**

1. **Natural Human Tone (Zero "AI Slop"):**
   - ❌ **NO decorative emojis** in headings or bullet points in `README.md`, `CHANGELOG.md`, or CurseForge copy.
   - ❌ **NO em dashes (`—`)** or exclamation marks (`!`). Use simple punctuation (commas, periods, parentheses).
   - ❌ **NO marketing fluff or buzzwords** (avoid phrases like *"dynamically observes, catalogs, and indexes"*, *"seamless"*, *"intuitive, scalable"*, *"authentic golden styling"*).
   - ❌ **NO bold marketing lead-ins on `CHANGELOG.md` bullets.** Start changelog bullets directly with a clear verb (`Added ...`, `Fixed ...`, `Simplified ...`) rather than `- **Feature Name:** Verbose explanation...`.
   - ❌ **NO raw Lua error strings** (e.g., `"attempt to perform string conversion..."`) in `CHANGELOG.md`. Describe the fix in plain English from a player's perspective.
   - Keep `README.md` focused on player features and slash commands; keep Mermaid diagrams and ASCII data trees strictly in `docs/ARCHITECTURE.md`.
2. **Player-Centric Summaries Only:** Focus solely on what is new, what changed, or what bug was fixed from a player's in-game perspective (e.g., *"Added an Embedded tooltip mode to show creature data directly inside Blizzard's default tooltip"*, *"Fixed a bug where looting a corpse counted as an extra kill"*).
3. **Zero Internal Repository Metadata:** Never include internal GitHub repository details in public changelogs:
   - ❌ **NO issue numbers or closure syntax** (e.g., `Closes #22`, `Fixes #14`, `#8`).
   - ❌ **NO branch names** (e.g., `feat/22-tooltip-sidecar-options`).
   - ❌ **NO pull request references** (e.g., `Merge pull request #25 from ...`).
   - ❌ **NO commit SHAs or developer git jargon.**
4. **CHANGELOG.md is Mandatory for CurseForge:** `BigWigsMods/packager` only publishes clean release notes to CurseForge if `CHANGELOG.md` exists at repository root (configured via `manual-changelog` in `.pkgmeta`). If `CHANGELOG.md` is missing, the packager silently falls back to running `git log` between tags, exposing internal commit messages, branch names, and issue closures. Always update `CHANGELOG.md` with the new player-facing version section prior to tagging.
5. **Annotated Release Tags:** Always create annotated tags (`git tag -a vX.Y.Z -m "..."`) containing the clean release summary for GitHub Releases and git history clarity.

