-- MobLootTrackerMobTooltip.lua – Mob tooltips med loot + skinning

function MobLootTracker:OnTooltipSetUnit(tooltip)
    local _, unit = tooltip:GetUnit()
    if not unit then return end

    local guid = UnitGUID(unit)
    if not guid or not guid:match("^0xF1") then return end

    local entryHex = guid:match("^0xF1%x%x(%x%x%x%x%x%x)")
    local npcID = entryHex and tonumber(entryHex, 16) or nil
    if not npcID then return end

    local npcName = UnitName(unit) or ("NPC "..npcID)

    -- Stop duplikering
    for i = 1, tooltip:NumLines() do
        local line = _G["GameTooltipTextLeft"..i]
        if line then
            local txt = line:GetText()
            if txt and (txt == npcName or txt:find("NPC "..npcID) or txt:find("Zone: ") or txt:find("Drops:") or txt:find("Skinning:")) then
                return
            end
        end
    end

    local db = MobLootTrackerDB.global.MobLootDB
    if not db or not db[npcID] then return end

    local npcData = db[npcID]
    npcData.items    = npcData.items    or {}
    npcData.skinning = npcData.skinning or {}
    npcData.zones    = npcData.zones    or {}
    npcData.kills    = npcData.kills    or 0

    -----------------------------------------------------
    -- HEADER
    -----------------------------------------------------
    tooltip:AddLine(npcName, 1, 0.9, 0.4)

    -----------------------------------------------------
    -- ZONES
    -----------------------------------------------------
    if next(npcData.zones) then
        local zones = ""
        for z in pairs(npcData.zones) do zones = zones..z..", " end
        zones = zones:gsub(", $","")
        tooltip:AddLine("Zone: "..zones, 0.7, 0.9, 1)
    end

    -----------------------------------------------------
    -- NORMAL LOOT
    -----------------------------------------------------
    if next(npcData.items) then
        tooltip:AddLine("Drops:", 0.8, 0.8, 0.2)
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

    -----------------------------------------------------
    -- SKINNING LOOT
    -----------------------------------------------------
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
