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

    local entryHex = guid:match("^0xF130(%x%x%x%x%x%x)")
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
                or text:find("Quest items:", 1, true)
                or text:find("Skinning sources:", 1, true)
                or text:find("Quest item sources:", 1, true)
                or text:find("Drops from:", 1, true)
                or text:find("Money looted:", 1, true)
                or text:find("MobLootTracker", 1, true)
                or text:find("Zone:", 1, true)
            then
                return true
            end
        end
    end
    return false
end

local DEFAULT_MAX_ITEM_SOURCES = 8
local LOW_SAMPLE_KILLS = 5
local CONFIDENCE_Z = 1.96

-- Wilson lower bound: a rate from few kills ranks below an equal rate from many.
local function GetSourceScore(source)
    local kills = source.kills or 0
    if kills <= 0 then
        return 0
    end

    local rate = math.min((source.count or 0) / kills, 1)
    local z2 = CONFIDENCE_Z * CONFIDENCE_Z
    local margin = CONFIDENCE_Z * math.sqrt((rate * (1 - rate) + z2 / (4 * kills)) / kills)
    return (rate + z2 / (2 * kills) - margin) / (1 + z2 / kills)
end

local function RankSources(list)
    for _, source in ipairs(list) do
        source.score = GetSourceScore(source)
    end

    table.sort(list, function(a, b)
        if a.score ~= b.score then
            return a.score > b.score
        end
        if a.count ~= b.count then
            return a.count > b.count
        end
        return a.name < b.name
    end)
end

local function AddSourceSection(tooltip, title, r, g, b, list, limit)
    if not next(list) then
        return
    end

    tooltip:AddLine(title, r, g, b)

    local shown = limit and math.min(limit, #list) or #list
    for i = 1, shown do
        local source = list[i]
        local detail
        if source.kills > 0 then
            detail = string.format("%.0f%% (%d/%d)", (source.count / source.kills) * 100, source.count, source.kills)
        else
            detail = "x" .. source.count
        end

        local shade = source.kills >= LOW_SAMPLE_KILLS and 1 or 0.6
        tooltip:AddDoubleLine("  " .. source.name, detail, 1, 1, 1, shade, shade, shade)
    end

    if shown < #list then
        tooltip:AddLine(string.format("  +%d more (hold Shift to show all)", #list - shown), 0.6, 0.6, 0.6)
    end
end

local function GetTrackedItemSources(itemID)
    local db = SafeDB()
    if not itemID or not db then
        return { drops = {}, skinning = {}, quest = {} }
    end

    local sources = { drops = {}, skinning = {}, quest = {} }

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
                    kills = MobLootTracker:GetSkinCount(npcData),
                    kind = "skinning",
                }
            end

            local questData = npcData.quest and npcData.quest[itemID]
            if questData then
                sources.quest[#sources.quest + 1] = {
                    name = npcData.name or ("NPC " .. npcID),
                    count = questData.count or 0,
                    kills = npcData.kills or 0,
                    kind = "quest",
                }
            end
        end
    end

    RankSources(sources.drops)
    RankSources(sources.skinning)
    RankSources(sources.quest)

    return sources
end

local function AddUnitLootToTooltip(tooltip, unit)
    if not unit or TooltipHasMobLootLines(tooltip) then
        return
    end

    local guid = UnitGUID(unit)
    if not guid or not guid:match("^0xF130") then
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
    npcData.quest = npcData.quest or {}
    npcData.zones = npcData.zones or {}
    npcData.kills = npcData.kills or 0
    npcData.money = npcData.money or 0

    if MobLootTracker:GetSetting("showMobName") ~= false then
        tooltip:AddLine(npcData.name or ("NPC " .. npcID), 1, 0.9, 0.4)
    end

    if MobLootTracker:GetSetting("showNPCID") then
        tooltip:AddLine("Mob ID: " .. tostring(npcID), 0.7, 0.9, 1)
    end

    if next(npcData.zones) then
        local zones = ""
        for zone in pairs(npcData.zones) do
            zones = zones .. zone .. ", "
        end
        zones = zones:gsub(", $", "")
        tooltip:AddLine("Zone: " .. zones, 0.7, 0.9, 1)
    end

    tooltip:AddLine("Kills: " .. tostring(npcData.kills), 0.7, 1, 0.7)

    if npcData.money > 0 then
        tooltip:AddLine("Money looted: " .. MobLootTracker:FormatMoney(npcData.money), 1, 0.82, 0)
    end

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
        local skins = MobLootTracker:GetSkinCount(npcData)
        tooltip:AddLine(string.format("Skinning: %d skins", skins), 0.8, 0.6, 0.2)
        for itemID, data in pairs(npcData.skinning) do
            local itemName = GetItemInfo(itemID)
            local rarity = select(3, GetItemInfo(itemID)) or 1
            local color = select(4, GetItemQualityColor(rarity))
            local rate = skins > 0 and (data.count / skins * 100) or 0

            tooltip:AddLine(string.format(
                "  %s%s|r x%d (%.1f%%)",
                color or "|cffffffff",
                itemName or ("Item " .. itemID),
                data.count,
                rate
            ))
        end
    end

    if next(npcData.quest) then
        tooltip:AddLine("Quest items:", 0.5, 0.8, 1)
        for itemID, data in pairs(npcData.quest) do
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
    local questSources = sources.quest or {}

    if not next(dropSources) and not next(skinningSources) and not next(questSources) then
        return
    end

    tooltip:AddLine("MobLootTracker sources", 0.8, 0.8, 0.2)

    local limit
    if not IsShiftKeyDown() then
        limit = tonumber(MobLootTracker:GetSetting("maxItemSources")) or DEFAULT_MAX_ITEM_SOURCES
    end

    AddSourceSection(tooltip, "Drops from:", 0.8, 0.8, 0.2, dropSources, limit)
    AddSourceSection(tooltip, "Skinning sources:", 0.8, 0.6, 0.2, skinningSources, limit)
    AddSourceSection(tooltip, "Quest item sources:", 0.5, 0.8, 1, questSources, limit)
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

-- Rebuild the hovered item's tooltip so Shift expands and collapses it immediately.
local modifierFrame = CreateFrame("Frame")
modifierFrame:RegisterEvent("MODIFIER_STATE_CHANGED")
modifierFrame:SetScript("OnEvent", function(_, _, key)
    if key ~= "LSHIFT" and key ~= "RSHIFT" then
        return
    end
    if not GameTooltip:IsVisible() or not GetItemIDFromTooltip(GameTooltip) then
        return
    end

    local owner = GameTooltip:GetOwner()
    local onEnter = owner and owner:GetScript("OnEnter")
    if onEnter then
        onEnter(owner, true)
    end
end)
