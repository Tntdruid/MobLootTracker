---
name: mobloottracker
description: Use this skill when working on the MobLootTracker World of Warcraft addon. Covers addon architecture, Lua patterns, saved variables, tooltip behavior, combat log handling, and AzerothCore/WotLK compatibility.
---

# MobLootTracker skill

## Project context
This repository contains a World of Warcraft addon named MobLootTracker. It tracks NPC kills and recorded loot, stores per-NPC statistics in saved variables, and adds information to item tooltips based on the player's own observed drops.

The addon is designed for AzerothCore/WotLK and uses the Ace3 library stack. The project is intentionally lightweight and should stay compatible with standard WoW Lua APIs and the version of the game this repo targets.

## Key files
- `MobLootTracker.lua` — addon bootstrap, saved variable setup, events, kill tracking, loot recording, tooltip injection
- `MobLootTrackerItemTooltip.lua` — tooltip-specific behavior and formatting helpers
- `MobLootTrackerOptions.lua` — user option handling and UI settings
- `MobLootTrackerSettings.lua` — persistent config and defaults
- `MobLootTrackerGUI.lua` — GUI-related presentation logic
- `MobLootTrackerMinimap.lua` — minimap integration and display state
- `README.md` — user-facing feature and compatibility documentation

## Core conventions
- Preserve the addon’s existing Ace3 structure and naming patterns.
- Keep saved variables resilient: initialize missing tables before access.
- Prefer `MobLootTrackerDB` and the `SafeDB()` pattern to avoid nil access crashes.
- Maintain compatibility with WoW APIs such as `UnitGUID`, `GetLootSlotLink`, `GetNumLootItems`, `GetItemInfo`, and `GameTooltip`.
- Do not break the data shape for `db[npcID].items`, `db[npcID].skinning`, `db[npcID].zones`, and `db[npcID].kills` without a clear migration plan.
- Preserve the addon’s debug workflow and command style (`/mltdebug`, `/mlt`, `/mltnpcid`).
- Favor minimal, targeted edits over broad refactors.

## Event and data flow
- NPC kills should be detected from the combat log and resolved via GUID to NPC ID.
- Loot should be recorded when `LOOT_OPENED` fires and the most recent valid kill context is available.
- Loot entries should separate leather/skinning items from normal item drops using the existing `LEATHER_ITEMS` logic.
- Item tooltip output should be idempotent and avoid duplicate sections when tooltips are rebuilt.

## Safety rules
- Validate GUID and item IDs before using them.
- Guard all tooltip access against nil values.
- Prefer explicit fallbacks for names, zones, and item labels when the underlying API data is unavailable.
- Avoid writing code that assumes retail WoW APIs or modern API naming when this project targets older client compatibility.

## Preferred workflow for changes
1. Identify the exact event or function involved in the bug or feature change.
2. Confirm the relevant data flow from GUID -> NPC ID -> saved DB entry -> tooltip/rendering.
3. Add or update a minimal repro or validation path before fixing logic.
4. Implement the smallest possible root-cause fix.
5. Keep output consistent with existing addon styling and user-facing command conventions.
6. Verify the change with the most relevant local validation available in this repo.

## Output expectations
When helping with this project, prefer:
- Lua-first code that matches the existing style of the addon
- comments that are brief and relevant to WoW addon patterns
- compatibility-safe assumptions for classic/WotLK-era APIs
- clear explanation of any saved variable or tooltip behavior changes

## Typical tasks this skill covers
- Fixing combat log and GUID resolution issues
- Adding or modifying loot tracking logic
- Adjusting tooltip formatting or deduplication
- Updating saved variable defaults or migration behavior
- Working with minimap or config UX
- Investigating debug output and core addon state issues
