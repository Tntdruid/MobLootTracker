# MobLootTracker

MobLootTracker is a lightweight loot‑tracking addon for **AzerothCore (WotLK)**.  
It records item drops from NPCs and displays the collected data directly inside item tooltips, giving players accurate, personal drop‑rate information while farming.

---

## Features

### ✔ Automatic loot tracking
- Records every item dropped by NPCs you kill  
- Tracks how many times each NPC has been killed  
- Stores NPC names directly in the database  
- Calculates drop rates based on your own gameplay  

### ✔ Tooltip integration
Item tooltips show:
- Which NPCs drop the item  
- Drop percentages  
- Number of drops  
- Skinning sources (optional)

### ✔ Full bag addon compatibility
Works with:
- Bagnon  
- Adibags  
- ElvUI bags  
- ArkInventory  
- Combuctor  
- TSM bags  
- Any custom inventory addon

### ✔ Debug mode
Enable debug mode to show extra information such as:
- Items with no collected data  
- Internal tracking details  

Toggle with:
/mltdebug

---

## How it works

MobLootTracker listens for:
- `UNIT_DIED` (to detect NPC kills)  
- `LOOT_OPENED` (to record item drops)

When you loot an NPC:
1. The addon identifies the NPC by GUID  
2. Stores the NPC name  
3. Records each item dropped  
4. Increments kill count  
5. Updates drop statistics  

When you hover an item, the tooltip displays all collected data for that item.

---

## Commands

/mltnpcid on/off   – show NPC ID in unit tooltips
/mltdebug          – toggle debug mode

---

## Compatibility

- AzerothCore (WotLK)  
- All major bag addons  
- All tooltip addons (TipTac, TinyTip, ElvUI, etc.)  
- Works alongside other loot addons without conflict  

---

## Why use MobLootTracker?

MobLootTracker is ideal for:
- Farmers  
- Gold makers  
- Completionists  
- Developers  
- Anyone who wants accurate, personal drop‑rate data  

It gives you **your own** statistics — not database averages — making farming more efficient and predictable.

---

## License

MIT License (recommended for open‑source projects)

