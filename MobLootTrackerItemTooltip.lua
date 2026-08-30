-- MobLootTrackerTooltip.lua – FINAL FIX v5 (garanteret ingen duplikering)

local function SafeDB()
    if MobLootTracker.db and MobLootTracker.db.global and MobLootTracker.db.global.MobLootDB then
        return MobLootTracker.db.global.MobLootDB
    end
    return MobLootTrackerDB.global.MobLootDB
end

local function ResolveNPCIDFromGUID(guid)
    if not guid then return nil end
    local entryHex = guid:match("^0xF1%x%x(%x%x%x%x%x%x)")
    return entryHex and tonumber(entryHex, 16) or nil
end

-- Check if tooltip already contains our sections
local function TooltipHasMLT(tooltip)
    for i = 1, tooltip:NumLines() do
        local line = _G["GameTooltipTextLeft"..i]
        if line then
            local txt = line:GetText()
            if txt and (txt:find("Known Drops") or txt:find("Skinning")) then
                return true
            end
        end
    end
    return false
end

local function AddMobLootToTooltip(tooltip, unit)
    if not unit then return end

    -- If tooltip already has our text → stop
    if TooltipHasMLT(tooltip) then return end

    local guid = UnitGUID(unit)
    if not guid or not guid:match("^0xF1") then return end

    local npcID = ResolveNPCIDFromGUID(guid)
    if not npcID then return end

    local db = SafeDB()
    local npcData = db[npcID]
    if not npcData then return end

    npcData.items    = npcData.items    or {}
    npcData.skinning = npcData.skinning or {}
    npcData.zones    = npcData.zones    or {}
    npcData.kills    = npcData.kills    or 0

    tooltip:AddLine(npcData.name or ("NPC "..npcID), 1, 0.9, 0.4)

    if next(npcData.zones) then
        local zones = ""
        for z in pairs(npcData.zones) do zones = zones..z..", " end
        zones = zones:gsub(", $","")
        tooltip:AddLine("Zone: "..zones, 0.7, 0.9, 1)
    end

    if next(npcData.items) then
        tooltip:AddLine("Known Drops:", 0.8, 0.8, 0.2)
        for itemID, data in pairs(npcData.items) do
            local name   = GetItemInfo(itemID)
            local rarity = select(3, GetItemInfo(itemID)) or 1
            local color  = select(4, GetItemQualityColor(rarity))
            local rate   = npcData.kills > 0 and (data.count / npcData.kills * 100) or 0

            tooltip:AddLine(string.format(
                "  %s%s|r x%d (%.1f%%)",
                color or "|cffffffff",
                name or ("Item "..itemID),
                data.count,
                rate
            ))
        end
    end

    if next(npcData.skinning) then
        tooltip:AddLine("Skinning:", 0.8, 0.6, 0.2)
        for itemID, data in pairs(npcData.skinning) do
            local name   = GetItemInfo(itemID)
            local rarity = select(3, GetItemInfo(itemID)) or 1
            local color  = select(4, GetItemQualityColor(rarity))

            tooltip:AddLine(string.format(
                "  %s%s|r x%d",
                color or "|cffffffff",
                name or ("Item "..itemID),
                data.count
            ))
        end
    end
end

GameTooltip:HookScript("OnTooltipSetUnit", function(tooltip)
    local _, unit = tooltip:GetUnit()
    AddMobLootToTooltip(tooltip, unit)
end)
