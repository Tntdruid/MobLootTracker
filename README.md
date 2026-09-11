# MobLootTracker

## Dansk

MobLootTracker er en letvaegts World of Warcraft-addon til **WoW 3.3.5a** og **AzerothCore**. Den registrerer dine egne kills, loot og skinning-drops og viser resultaterne direkte i spillets tooltips.

### Funktioner

- Registrerer antal kills pr. NPC
- Gemmer normale loot-drops, quest items og skinning-materialer separat
- Viser NPC-navn, zone og personlige dropdata
- Viser hvilke NPC'er der dropper et bestemt item
- Viser antal registrerede drops og personlige drop rates for hver kategori
- Virker med bag- og inventory-tooltips
- Gemmer data i WoW SavedVariables
- Indeholder en enkel oversigt via `/mlt`

### Saadan virker det

1. Drab registreres fra combat loggen.
2. NPC'ens GUID bruges til at finde NPC-ID'et.
3. Loot og skinning registreres, naar loot-vinduet aabnes.
4. Data gemmes lokalt og vises, naar du holder musen over NPC'er eller items.

### Installation

Kopiér addon-mappen til:

`World of Warcraft\Interface\AddOns\MobLootTracker`

Aktivér **Load out of date AddOns** i 3.3.5a-klienten, hvis det er nødvendigt.

### Kommandoer

- `/mlt` aabner addonens oversigt.

Addonens statistik er personlig og baseret paa dine egne kills og drops, ikke paa en global drop database.

## English

MobLootTracker is a lightweight World of Warcraft addon for **WoW 3.3.5a** and **AzerothCore**. It records your personal kills, loot, and skinning drops, then displays the collected data directly in in-game tooltips.

### Features

- Tracks kill totals for each NPC
- Separates regular loot, quest items, and skinning materials
- Stores NPC names, zones, and personal drop data
- Shows which NPCs can drop a selected item
- Displays recorded drop totals and personal drop rates for each category
- Works with bag and inventory tooltips
- Stores data in WoW SavedVariables
- Includes a simple overview opened with `/mlt`

### How it works

1. NPC deaths are detected through the combat log.
2. The NPC GUID is resolved to an NPC ID.
3. Loot and skinning are recorded when the loot window opens.
4. The data is stored locally and shown when hovering NPCs or items.

### Installation

Copy the addon folder to:

`World of Warcraft\Interface\AddOns\MobLootTracker`

Enable **Load out of date AddOns** in the 3.3.5a client if required.

### Commands

- `/mlt` opens the addon overview.

All statistics are personal and based on your own kills and drops rather than a global drop database.

## Compatibility

- World of Warcraft 3.3.5a
- AzerothCore WotLK servers
- Standard unit, item, bag, and inventory tooltips

## License

MIT License

