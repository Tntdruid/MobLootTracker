-- MobLootTrackerItemTooltip.lua – Item tooltips (bags, loot, links) med skinning + drop-rate

local function AddMLTItemTooltip(tooltip, itemID)
    if not itemID then return end

    -- Brug den globale DB fra din core
    local db = MobLootTrackerDB.global.MobLootDB
    if not db then return end

    local dropped, skinned = {}, {}   -- FIX: begge initialiseres som tabeller

    -- Loop igennem alle mobs i DB
    for npcID, npcData in pairs(db) do
        if npcData.items and npcData.items[itemID] then
            local rate = npcData.kills > 0 and (npcData.items[itemID].count / npcData.kills * 100) or 0
            table.insert(dropped, string.format("%s (%d kills, %.1f%%)", npcData.name or ("NPC "..npcID), npcData.kills or 0, rate))
        end
        if npcData.skinning and npcData.skinning[itemID] then
            table.insert(skinned, string.format("%s (%d skins)", npcData.name or ("NPC "..npcID), npcData.skinning[itemID].count))
        end
    end

    -- Hvis ingen data → stop
    if (#dropped == 0 and #skinned == 0) then return end

    -- Tilføj header
    tooltip:AddLine(" ")
    tooltip:AddLine("MobLootTracker: Known drops", 0.9, 0.8, 0.2)

    -- Skinning sektion
    if #skinned > 0 then
        tooltip:AddLine("Skindet fra:", 0.8, 0.6, 0.2)
        for _, txt in ipairs(skinned) do
            tooltip:AddLine("  "..txt)
        end
    end

    -- Drop sektion
    if #dropped > 0 then
        tooltip:AddLine("Drop fra:", 0.8, 0.8, 0.2)
        for _, txt in ipairs(dropped) do
            tooltip:AddLine("  "..txt)
        end
    end

    tooltip:Show()
end

-- Hook til GameTooltip (tasker, loot, links)
local function OnTooltipSetItem(tooltip)
    local _, link = tooltip:GetItem()
    if not link then return end

    local itemID = tonumber(link:match("item:(%d+)"))
    if not itemID then return end

    AddMLTItemTooltip(tooltip, itemID)
end

-- Hook både GameTooltip og ItemRefTooltip
GameTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
ItemRefTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
