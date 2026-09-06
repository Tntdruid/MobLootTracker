---
name: mobloottracker-tooltip
description: Use this skill when debugging tooltip rendering, duplicate lines, item formatting, NPC lookup, or loot display issues in the MobLootTracker addon.
---

# MobLootTracker tooltip skill

## Focus area
This skill is for issues related to the visual tooltip output in MobLootTracker. It covers how NPC loot data is attached to tooltips, how duplicate sections are prevented, how loot counts are formatted, and how the addon resolves NPC identity before writing information into the tooltip.

## Relevant files
- `MobLootTracker.lua` — `OnTooltipSetUnit`, `TooltipHasMLT`, loot tracking, and event/data flow
- `MobLootTrackerItemTooltip.lua` — additional tooltip helpers and rendering logic
- `README.md` — expected UX and user-facing tooltip behavior

## Core behavior to preserve
- Tooltips should only show MobLootTracker information when a valid NPC GUID is detected.
- Only WotLK/AzerothCore-style `0xF1` GUIDs should be treated as NPC entities for this logic.
- Tooltip output should avoid duplicate entries or repeated sections when tooltip events fire repeatedly.
- The addon should present zone, drop, and skinning data in a readable format without corrupting standard game tooltip layout.
- If no data exists for a unit, the tooltip should remain otherwise unaffected.

## Key logic patterns
- GUID resolution: `ResolveNPCIDFromGUID(guid)` extracts the NPC ID from the WoW GUID format.
- Duplicate guard: `TooltipHasMLT(tooltip, npcName, npcID)` checks whether data has already been printed to the current tooltip.
- Data access: `SafeDB()` ensures the addon reads a valid saved variable table before indexing `db[npcID]`.
- Rendering: `tooltip:AddLine(...)` is used for header, zone, loot totals, and skinning entries.

## Common tooltip bugs
- Duplicate lines when `OnTooltipSetUnit` fires multiple times for the same tooltip
- Missing tooltip data because a GUID format is not recognized
- Nil access when saved variables are absent or partially initialized
- Formatting issues when `GetItemInfo` returns nil or incomplete data
- Incorrect separation between regular drops and skinning loot

## Debugging checklist
1. Confirm the target unit has a valid GUID and matches the expected pattern.
2. Check whether the NPC ID resolves correctly before reading the saved DB entry.
3. Ensure the `db[npcID]` table exists before writing or rendering data.
4. Verify that the tooltip duplicate guard is not too aggressive and does not hide valid content.
5. Confirm that items are grouped under the correct section: loot vs. skinning.
6. Validate the final output format with both known and unknown item IDs.

## Preferred fix style
- Keep the change local to tooltip logic whenever possible.
- Preserve the existing structure and formatting style used by the addon.
- Prefer small, defensive checks over broad refactors.
- Match older WoW Lua conventions rather than modern patterns that may not exist in the target client.

## Useful validation ideas
- Inspect a tooltip for a known NPC after recording kills and loot.
- Verify that zone lines and drop counts render once per tooltip.
- Test behavior when `GetItemInfo` is unavailable for a specific item ID.
- Confirm that the addon does not print data for non-NPC units or incomplete GUIDs.
