## 📝 Summary of Changes
<!-- Provide a clear, high-level summary of what this PR introduces, fixes, or refactors. -->

## 🔗 Related Issue
<!-- Replace [issue-number] with the corresponding GitHub Issue number. -->
Closes #

## 📋 Pre-Merge Verification Checklist

Please verify that all applicable items are checked before requesting review:

### 🏛️ Architecture & Documentation Sync (MANDATORY)
- [ ] **`docs/ARCHITECTURE.md` Reviewed & Synchronized:**
  - [ ] Database Schema / ER tree updated (if `Database.lua` was modified)
  - [ ] Sequence diagrams updated (if events, combat inference, or loot handling changed)
  - [ ] Component breakdown updated (if new UI elements, tabs, or settings were added)
  - [ ] File registry & TOC order verified (if new files were introduced)
- [ ] No hardcoded absolute local paths in documentation or code (all links are relative).

### 🛡️ Code Quality & Taint-Safety
- [ ] **Zero-Taint Integrity:** No `COMBAT_LOG_EVENT_UNFILTERED` or protected action button hooks introduced.
- [ ] **Data Safety:** Database mutations use factory methods (`addon:GetOrCreateMob()`, `RecordLoot`, etc.).
- [ ] **Coordinate Policy:** Coordinates are strictly recorded for rare spawns (`rare`/`rareelite`), never standard mobs.
- [ ] **Memory Bounded:** Corpse and session caches respect the 400-entry ring buffer ceiling.

### 🧪 Testing & Deployment
- [ ] Ran `deploy.ps1` successfully with zero copy errors.
- [ ] In-game testing verified with `/reload` (no Lua errors, tooltips and compendium window functional).
