-- MobLootTrackerItemTooltip.lua – FINAL VERSION WITH ITEM COLORS

print("MobLootTrackerItemTooltip.lua LOADED")

---------------------------------------------------------
-- SAFE LOAD OF ADDON
---------------------------------------------------------
local ok, MobLootTracker = pcall(function()
    return LibStub("AceAddon-3.0"):GetAddon("MobLootTracker")
end)

if not ok or not MobLootTracker then
    print("MobLootTracker NOT READY — exiting tooltip file")
    return
end

local AceTimer = LibStub("AceTimer-3.0")

---------------------------------------------------------
-- ITEM COLOR HELPER
---------------------------------------------------------
local function MLT_GetItemColor(itemID)
    local _, _, itemRarity = GetItemInfo(itemID)
    if not itemRarity then
        return "|cffffffff" -- fallback: white
    end
    return select(4, GetItemQualityColor(itemRarity))
end

---------------------------------------------------------
-- MAIN ITEM TOOLTIP HANDLER (runs ONCE per item)
---------------------------------------------------------
local function MLT_HandleItemTooltip(tooltip, link)
    if not link then return end

    -- Only block item tooltips, never NPC tooltips
    if tooltip.MLT_ItemProcessed then return end
    tooltip.MLT_ItemProcessed = true

    local itemID = tonumber(link:match("item:(%d+)"))
    if not itemID then return end

    local db = MobLootTracker:GetDB()
    if not db then return end

    local loot, skin = {}, {}

    for npcID, npcData in pairs(db) do
        if npcData.items and npcData.items[itemID] then
            table.insert(loot, {
                name  = npcData.name or ("NPC "..npcID),
                count = npcData.items[itemID].count or 0,
                kills = npcData.kills or 0,
            })
        end
        if npcData.skinning and npcData.skinning[itemID] then
            table.insert(skin, {
                name  = npcData.name or ("NPC "..npcID),
                count = npcData.skinning[itemID].count or 0,
                kills = npcData.kills or 0,
            })
        end
    end

    -----------------------------------------------------
    -- NO DATA (debug only)
    -----------------------------------------------------
    if #loot == 0 and #skin == 0 then
        if MobLootTracker and MobLootTracker.GetSetting and MobLootTracker:GetSetting("debugMode") then
            tooltip:AddLine(" ")
            tooltip:AddLine("|cffff4444No data collected yet|r")
        end
        return
    end

    -----------------------------------------------------
    -- LOOT SECTION
    -----------------------------------------------------
    if #loot > 0 then
        tooltip:AddLine(" ")
        tooltip:AddLine("|cffffd200Dropped by:|r")

        for _, mob in ipairs(loot) do
            local rate = mob.kills > 0 and (mob.count / mob.kills * 100) or 0
            local color = MLT_GetItemColor(itemID)

            tooltip:AddLine(string.format(
                "%s%s|r (%.1f%%, %d drops)",
                color, mob.name, rate, mob.count
            ))
        end
    end

    -----------------------------------------------------
    -- SKINNING SECTION
    -----------------------------------------------------
    if #skin > 0 then
        tooltip:AddLine(" ")
        tooltip:AddLine("|cff88ff88Skinned from:|r")

        for _, mob in ipairs(skin) do
            local color = MLT_GetItemColor(itemID)

            tooltip:AddLine(string.format(
                "%s%s|r (%d skins)",
                color, mob.name, mob.count
            ))
        end
    end
end

---------------------------------------------------------
-- RESET FLAGS BEFORE EACH TOOLTIP
---------------------------------------------------------
GameTooltip:HookScript("OnTooltipCleared", function(self)
    self.MLT_ItemProcessed = nil
end)

---------------------------------------------------------
-- HOOKS (ITEM ONLY)
---------------------------------------------------------
local function MLT_SafeHook(funcName, handler)
    if GameTooltip[funcName] then
        hooksecurefunc(GameTooltip, funcName, handler)
    end
end

GameTooltip:HookScript("OnTooltipSetItem", function(tooltip)
    local _, link = tooltip:GetItem()
    MLT_HandleItemTooltip(tooltip, link)
end)

MLT_SafeHook("SetBagItem", function(tooltip, bag, slot)
    MLT_HandleItemTooltip(tooltip, GetContainerItemLink(bag, slot))
end)

MLT_SafeHook("SetInventoryItem", function(tooltip, unit, slot)
    MLT_HandleItemTooltip(tooltip, GetInventoryItemLink(unit, slot))
end)

MLT_SafeHook("SetHyperlink", function(tooltip, link)
    MLT_HandleItemTooltip(tooltip, link)
end)

MLT_SafeHook("SetMerchantItem", function(tooltip, index)
    MLT_HandleItemTooltip(tooltip, GetMerchantItemLink(index))
end)

MLT_SafeHook("SetLootItem", function(tooltip, slot)
    MLT_HandleItemTooltip(tooltip, GetLootSlotLink(slot))
end)

MLT_SafeHook("SetQuestItem", function(tooltip, type, index)
    MLT_HandleItemTooltip(tooltip, GetQuestItemLink(type, index))
end)

MLT_SafeHook("SetQuestLogItem", function(tooltip, type, index)
    MLT_HandleItemTooltip(tooltip, GetQuestLogItemLink(type, index))
end)

---------------------------------------------------------
-- UNIVERSAL BAG/INVENTORY HOOK
---------------------------------------------------------
local function MLT_UniversalItemOnEnter(self)
    local link =
        (self.GetBagID and self.GetID and GetContainerItemLink(self:GetBagID(), self:GetID()))
        or self.itemLink
        or (self.GetItemLink and self:GetItemLink())

    if link then
        MLT_HandleItemTooltip(GameTooltip, link)
    end
end

local function MLT_HookAllItemButtons()
    local f = EnumerateFrames()
    while f do
        if not f.MLT_Hooked then
            if f.itemLink or f.GetItemLink or f.GetBagID then
                f:HookScript("OnEnter", MLT_UniversalItemOnEnter)
                f.MLT_Hooked = true
            end
        end
        f = EnumerateFrames(f)
    end
end

AceTimer:ScheduleRepeatingTimer(MLT_HookAllItemButtons, 1)
