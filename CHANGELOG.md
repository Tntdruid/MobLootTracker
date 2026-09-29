# Changelog

## Unreleased

### Fixed

- Fixed loot from game objects, such as mining nodes, being attributed to the target or most recently killed NPC.
- Fixed loot, including quest items, being assigned to the wrong mob when multiple mobs die before the loot window opens.

### Added

- Added the `/mltdelete` command for deleting an NPC's saved data with confirmation.
- Added separate quest-item tracking in the saved database.
- Added independent quest-item drop rates based on recorded kills.
- Added quest-item sections to NPC and item tooltips.
- Added a Quest tab and quest-item totals to the addon GUI.
- Added an option to enable or disable quest-item tracking.

### Compatibility

- Existing regular loot and skinning data remain unchanged.