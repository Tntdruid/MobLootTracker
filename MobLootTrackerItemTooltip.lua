-- MobLootTrackerItemTooltip.lua – Safe Tooltip Handler

local function ResolveNPCIDFromGUID(guid)
    if not guid then return nil end
    local entryHex = guid:match("^0xF1%x%x(%x%x%x%x%x%x)")
    return entryHex and tonumber(entryHex, 16) or nil
end

local function GetItemColor(itemID)
    local _, _, rarity = GetItemInfo(itemID)
    if not rarity then
        return "|cffffffff"
    end
    return select(4, GetItemQualityColor(rarity))
end

---------------------------------------------------------
-- SAFE DB ACCESS (works before OnInitialize)
---------------------------------------------------------
local function SafeDB()
    -- AceDB ready?
    if MobLootTracker.db and MobLootTracker.db.global and MobLootTracker.db.global.MobLootDB then
        return MobLootTracker.db.global.MobLootDB
    end

    -- Fallback BEFORE OnInitialize
    MobLootTrackerDB.global = MobLootTrackerDB.global or {}
    MobLootTrackerDB.global.MobLootDB = MobLootTrackerDB.global.MobLootDB or {}

    return MobLootTrackerDB.global.MobLootDB
end

---------------------------------------------------------
-- TOOLTIP HOOK
---------------------------------------------------------
function MobLootTracker:OnTooltipSetUnit(tooltip)
    local _, unit = tooltip:GetUnit()
    if not unit then return end

    local guid = UnitGUID(unit)
    if not guid then return end

    -- Only AzerothCore NPC GUIDs
    if not guid:match("^0xF1") then return end

    local npcID = ResolveNPCIDFromGUID(guid)
    if not npcID then return end

    local db = SafeDB()
    local npcData = db[npcID]
    if not npcData then return end

    npcData.items    = npcData.items    or {}
    npcData.skinning = npcData.skinning or {}
    npcData.zones    = npcData.zones    or {}
    npcData.kills    = npcData.kills    or 0

    -----------------------------------------------------
    -- NPC NAME
    -----------------------------------------------------
    local npcName = npcData.name or ("NPC "..npcID)
    tooltip:AddLine(npcName, 1, 0.9, 0.4)

    -----------------------------------------------------
    -- ZONES
    -----------------------------------------------------
    if next(npcData.zones) then
        local zoneList = ""
        for zoneName in pairs(npcData.zones) do
            zoneList = zoneList .. zoneName .. ", "
        end
        zoneList = zoneList:gsub(", $", "")
        tooltip:AddLine("Zone: " .. zoneList, 0.7, 0.9, 1)
    end

    -----------------------------------------------------
    -- DROPS
    -----------------------------------------------------
    if next(npcData.items) then
        tooltip:AddLine("Known Drops:", 0.8, 0.8, 0.2)

        for itemID, data in pairs(npcData.items) do
            local name  = GetItemInfo(itemID)
            local count = data.count or 0
            local rate  = npcData.kills > 0 and (count / npcData.kills * 100) or 0
            local color = GetItemColor(itemID)

            tooltip:AddLine(string.format(
                "  %s%s|r x%d (%.1f%%)",
                color, name or ("Item "..itemID), count, rate
            ))
        end
    end
end
