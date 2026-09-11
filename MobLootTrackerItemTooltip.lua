-- MobLootTrackerItemTooltip.lua

local function SafeDB()
    if MobLootTracker and MobLootTracker.db and MobLootTracker.db.global and MobLootTracker.db.global.MobLootDB then
        return MobLootTracker.db.global.MobLootDB
    end
    if MobLootTrackerDB and MobLootTrackerDB.global and MobLootTrackerDB.global.MobLootDB then
        return MobLootTrackerDB.global.MobLootDB
    end
    return nil
end

local function ResolveNPCIDFromGUID(guid)
    if not guid then
        return nil
    end

    local entryHex = guid:match("^0xF1%x%x(%x%x%x%x%x%x)")
    return entryHex and tonumber(entryHex, 16) or nil
end

local function TooltipHasMobLootLines(tooltip)
    if not tooltip or not tooltip.NumLines then
        return false
    end

    for i = 1, tooltip:NumLines() do
        local line = _G["GameTooltipTextLeft" .. i]
        if line then
            local text = line:GetText() or ""
            if text:find("Known Drops", 1, true)
                or text:find("Skinning:", 1, true)
                or text:find("Skinning sources:", 1, true)
                or text:find("Drops from:", 1, true)
                or text:find("MobLootTracker", 1, true)
                or text:find("Zone:", 1, true)
            then
                return true
            end
        end
    end
    return false
end

local function GetTrackedItemSources(itemID)
    local db = SafeDB()
    if not itemID or not db then
        return { drops = {}, skinning = {} }
    end

    local sources = { drops = {}, skinning = {} }

    for npcID, npcData in pairs(db) do
        if npcData then
            local dropData = npcData.items and npcData.items[itemID]
            if dropData then
                sources.drops[#sources.drops + 1] = {
                    name = npcData.name or ("NPC " .. npcID),
                    count = dropData.count or 0,
                    kills = npcData.kills or 0,
                    kind = "drop",
                }
            end

            local skinData = npcData.skinning and npcData.skinning[itemID]
            if skinData then
                sources.skinning[#sources.skinning + 1] = {
                    name = npcData.name or ("NPC " .. npcID),
                    count = skinData.count or 0,
                    kills = npcData.kills or 0,
                    kind = "skinning",
                }
            end
        end
    end

    table.sort(sources.drops, function(a, b)
        return (a.count or 0) > (b.count or 0)
    end)

    table.sort(sources.skinning, function(a, b)
        return (a.count or 0) > (b.count or 0)
    end)

    return sources
end

local function AddUnitLootToTooltip(tooltip, unit)
    if not unit or TooltipHasMobLootLines(tooltip) then
        return
    end

    local guid = UnitGUID(unit)
    if not guid or not guid:match("^0xF1") then
        return
    end

    local npcID = ResolveNPCIDFromGUID(guid)
    if not npcID then
        return
    end

    local db = SafeDB()
    if not db then
        return
    end

    local npcData = db[npcID]
    if not npcData then
        return
    end

    npcData.items = npcData.items or {}
    npcData.skinning = npcData.skinning or {}
    npcData.zones = npcData.zones or {}
    npcData.kills = npcData.kills or 0

    tooltip:AddLine(npcData.name or ("NPC " .. npcID), 1, 0.9, 0.4)

    if next(npcData.zones) then
        local zones = ""
        for zone in pairs(npcData.zones) do
            zones = zones .. zone .. ", "
        end
        zones = zones:gsub(", $", "")
        tooltip:AddLine("Zone: " .. zones, 0.7, 0.9, 1)
    end

    tooltip:AddLine("Kills: " .. tostring(npcData.kills), 0.7, 1, 0.7)

    if next(npcData.items) then
        tooltip:AddLine("Known Drops:", 0.8, 0.8, 0.2)
        for itemID, data in pairs(npcData.items) do
            local itemName = GetItemInfo(itemID)
            local rarity = select(3, GetItemInfo(itemID)) or 1
            local color = select(4, GetItemQualityColor(rarity))
            local rate = npcData.kills > 0 and (data.count / npcData.kills * 100) or 0

            tooltip:AddLine(string.format(
                "  %s%s|r x%d (%.1f%%)",
                color or "|cffffffff",
                itemName or ("Item " .. itemID),
                data.count,
                rate
            ))
        end
    end

    if next(npcData.skinning) then
        tooltip:AddLine("Skinning:", 0.8, 0.6, 0.2)
        for itemID, data in pairs(npcData.skinning) do
            local itemName = GetItemInfo(itemID)
            local rarity = select(3, GetItemInfo(itemID)) or 1
            local color = select(4, GetItemQualityColor(rarity))
            local rate = npcData.kills > 0 and (data.count / npcData.kills * 100) or 0

            tooltip:AddLine(string.format(
                "  %s%s|r x%d (%.1f%%)",
                color or "|cffffffff",
                itemName or ("Item " .. itemID),
                data.count,
                rate
            ))
        end
    end
end

local function AddItemSourceToTooltip(tooltip, itemID)
    if not tooltip or not itemID or TooltipHasMobLootLines(tooltip) then
        return
    end

    local sources = GetTrackedItemSources(itemID)
    local dropSources = sources.drops or {}
    local skinningSources = sources.skinning or {}

    if not next(dropSources) and not next(skinningSources) then
        return
    end

    tooltip:AddLine("MobLootTracker sources", 0.8, 0.8, 0.2)

    if next(dropSources) then
        tooltip:AddLine("Drops from:", 0.8, 0.8, 0.2)
        for _, source in ipairs(dropSources) do
            local rate = source.kills > 0 and ((source.count / source.kills) * 100) or 0
            tooltip:AddLine(string.format(
                "  %s x%d (%.1f%%)",
                source.name,
                source.count,
                rate
            ), 1, 1, 1)
        end
    end

    if next(skinningSources) then
        tooltip:AddLine("Skinning sources:", 0.8, 0.6, 0.2)
        for _, source in ipairs(skinningSources) do
            local rate = source.kills > 0 and ((source.count / source.kills) * 100) or 0
            tooltip:AddLine(string.format(
                "  %s x%d (%.1f%%)",
                source.name,
                source.count,
                rate
            ), 1, 1, 1)
        end
    end
end

local function GetItemIDFromTooltip(tooltip)
    if not tooltip or not tooltip.GetItem then
        return nil
    end

    local _, link = tooltip:GetItem()
    if not link or type(link) ~= "string" then
        return nil
    end

    local itemID = tonumber(link:match("item:(%d+)"))
    if itemID then
        return itemID
    end

    return tonumber(link:match("Hitem:(%d+)"))
end

local function OnTooltipSetUnit(tooltip)
    local _, unit = tooltip:GetUnit()
    AddUnitLootToTooltip(tooltip, unit)
end

local function OnTooltipSetItem(tooltip)
    local itemID = GetItemIDFromTooltip(tooltip)
    if not itemID then
        return
    end

    AddItemSourceToTooltip(tooltip, itemID)
end

local ITEM_TOOLTIP_NAMES = {
    "GameTooltip",
    "ItemRefTooltip",
    "ShoppingTooltip1",
    "ShoppingTooltip2",
}

for _, tooltipName in ipairs(ITEM_TOOLTIP_NAMES) do
    local tooltip = _G[tooltipName]
    if tooltip and tooltip.HookScript then
        tooltip:HookScript("OnTooltipSetItem", function(selfTooltip)
            OnTooltipSetItem(selfTooltip)
        end)
    end
end

if GameTooltip and GameTooltip.HookScript then
    GameTooltip:HookScript("OnTooltipSetUnit", function(selfTooltip)
        OnTooltipSetUnit(selfTooltip)
    end)
end
