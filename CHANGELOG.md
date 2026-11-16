# Changelog

## Unreleased

## 1.2 - 2026-11-16

### Changed

- Skinning drop rates are now based on how many times an NPC was skinned instead of how many times it was killed, because not every kill is skinned. Tooltips and the GUI show the number of skins.
- The Skinning tab and Stats tab now include all skinning loot, not only known leathers and hides.
- Only loot from a Skinning, Herb Gathering or Mining cast on a corpse counts as skinning loot and as a skin. Leather or hides that drop as normal corpse loot are now recorded as regular drops.
- The list-based loot repair no longer runs automatically at login, so it cannot move genuine leather drops into skinning. It is still available with `/mltfixloot`.

### Compatibility

- Each NPC now saves a skin counter. For existing skinning data, the counter is estimated once from the saved skinning counts, capped at the kill count.

## 1.1 - 2026-11-16

### Fixed

- Fixed kills by party and raid members not being counted when the player had no target.
- Fixed loot from roll prompts being ignored when the corpse is no longer under the mouse cursor.
- Fixed loot from a respawned mob being mistaken for loot from an already-opened corpse.
- Fixed Light Hide being recorded as regular loot instead of skinning loot.
- Fixed the NPC browser's back button stacking the NPC list under the editor instead of replacing it.
- Fixed the NPC browser's Edit buttons wrapping onto their own line, and the list not scrolling back to the top after a search or filter change.
- Fixed the main window not being released when closed.
- Fixed skinning loot that is not a hide or leather, such as Worn Dragonscale and Green Dragonscale, being recorded as regular drops. Everything looted right after a Skinning, Herb Gathering or Mining cast on a corpse is now recorded as skinning loot.
- Fixed loot from game objects, such as mining nodes, being attributed to the target or most recently killed NPC.
- Fixed loot, including quest items, being assigned to the wrong mob when multiple mobs die before the loot window opens.

### Added

- Added an NPC browser filter for NPCs without drops, a match counter, and a Delete NPC button in the NPC editor.
- The NPC browser now remembers search, sort and filters while the game is running.
- Added the `/mltdelete` command for deleting an NPC's saved data with confirmation.
- Added separate quest-item tracking in the saved database.
- Added independent quest-item drop rates based on recorded kills.
- Added quest-item sections to NPC and item tooltips.
- Added a Quest tab and quest-item totals to the addon GUI.
- Added an option to enable or disable quest-item tracking.

### Changed

- Item tooltips now rank sources by reliable drop rate, so a high rate from few kills no longer outranks a proven source.
- Item tooltips now show the 8 best sources per category by default, with a configurable limit and Shift to show all.
- Item tooltip sources now show the drop rate with drops and kills in a right-aligned column, and sources with under 5 kills are greyed out.

### Compatibility

- Existing regular loot and skinning data remain unchanged.