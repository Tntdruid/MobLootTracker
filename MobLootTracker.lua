-- MobLootTracker.lua – Fully Safe Core (AzerothCore F1 GUID + Zones + Colors)

MobLootTracker = LibStub("AceAddon-3.0"):NewAddon(
    "MobLootTracker",
    "AceConsole-3.0",
    "AceEvent-3.0",
    "AceHook-3.0"
)

local AceDB = LibStub("AceDB-3.0")

---------------------------------------------------------
-- SAFE SAVEDVARIABLES BOOTSTRAP
---------------------------------------------------------
MobLootTrackerDB = MobLootTrackerDB or {}

MobLootTrackerDB.global  = MobLootTrackerDB.global or {}
MobLootTrackerDB.global.MobLootDB = MobLootTrackerDB.global.MobLootDB or {}

MobLootTrackerDB.profile = MobLootTrackerDB.profile or {}

-- Minimap is NOT part of AceDB defaults
MobLootTrackerDB.minimap = MobLootTrackerDB.minimap or {
    hide = false,
    minimapPos = 220,
}

---------------------------------------------------------
-- ACEDB DEFAULTS (NO MINIMAP HERE!)
---------------------------------------------------------
local defaults = {
    profile = {
        showNPCID      = false,
        showDropRates  = true,
        enableSkinning = true,
        debugMode      = false,
    },
    global = {
        MobLootDB = MobLootTrackerDB.global.MobLootDB,
    },
}

---------------------------------------------------------
-- SAFE DB ACCESS
---------------------------------------------------------
function MobLootTracker:GetDB()
    if self.db and self.db.global and self.db.global.MobLootDB then
        return self.db.global.MobLootDB
    end

    -- Fallback BEFORE OnInitialize
    MobLootTrackerDB.global = MobLootTrackerDB.global or {}
    MobLootTrackerDB.global.MobLootDB = MobLootTrackerDB.global.MobLootDB or {}

    return MobLootTrackerDB.global.MobLootDB
end

function MobLootTracker:GetSetting(key)
    if self.db and self.db.profile then
        return self.db.profile[key]
    end
    return MobLootTrackerDB.profile[key]
end

function MobLootTracker:SetSetting(key, val)
    MobLootTrackerDB.profile[key] = val
    if self.db and self.db.profile then
        self.db.profile[key] = val
    end
end

---------------------------------------------------------
-- ITEM COLOR HELPER
---------------------------------------------------------
local function MLT_GetItemColor(itemID)
    local _, _, itemRarity = GetItemInfo(itemID)
    if not itemRarity then
        return "|cffffffff"
    end
    return select(4, GetItemQualityColor(itemRarity))
end

---------------------------------------------------------
-- GUID → NPCID (AzerothCore F1xx format)
---------------------------------------------------------
local function ResolveNPCIDFromGUID(guid)
    if not guid then return nil end
    local entryHex = guid:match("^0xF1%x%x(%x%x%x%x%x%x)")
    return entryHex and tonumber(entryHex, 16) or nil
end

---------------------------------------------------------
-- INITIALIZE (SAFE)
---------------------------------------------------------
function MobLootTracker:OnInitialize()
    -- AceDB init (binds to existing SavedVariables)
    self.db = AceDB:New("MobLootTrackerDB", defaults, true)

    -- Events
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:RegisterEvent("LOOT_OPENED")

    -- Tooltip hook
    self:HookScript(GameTooltip, "OnTooltipSetUnit", "OnTooltipSetUnit")

    -- Slash command
    self:RegisterChatCommand("mlt", "ShowGUI")

    -- Minimap icon (external SavedVariables)
    if self.InitMinimap then
        self:InitMinimap()
    end

    self:Print("MobLootTracker loaded (safe DB + AzerothCore F1 GUID)")
end

---------------------------------------------------------
-- KILL TRACKING
---------------------------------------------------------
local recentKills = {}
local lastGUID = nil

function MobLootTracker:COMBAT_LOG_EVENT_UNFILTERED(_, ...)
    local _, subEvent, _, _, _, _, dstGUID = ...

    if subEvent == "UNIT_DIED" and dstGUID then
        local npcID = ResolveNPCIDFromGUID(dstGUID)
        if npcID then
            recentKills[npcID] = true
            lastGUID = dstGUID
        end
    end
end

---------------------------------------------------------
-- LOOT TRACKING + NPC NAME + ZONE STORAGE
---------------------------------------------------------
function MobLootTracker:LOOT_OPENED()
    local db = self:GetDB()
    local npcID = nil

    -- Prefer recent kill
    for id in pairs(recentKills) do npcID = id break end

    -- Fallback: target/mouseover
    if not npcID then
        local guid = UnitGUID("target") or UnitGUID("mouseover")
        npcID = guid and ResolveNPCIDFromGUID(guid)
        lastGUID = guid
    end

    -- Fallback: last GUID
    if not npcID and lastGUID then
        npcID = ResolveNPCIDFromGUID(lastGUID)
    end

    if not npcID then return end

    -- Ensure mob entry exists
    db[npcID] = db[npcID] or {
        kills    = 0,
        items    = {},
        skinning = {},
        zones    = {},
    }

    local npcData = db[npcID]

    -- Store NPC name
    local name = UnitName("target") or UnitName("mouseover") or ("NPC "..npcID)
    npcData.name = name

    -- Store zone
    local zoneName = GetZoneText() or "Unknown Zone"
    npcData.zones[zoneName] = true

    -- Increment kill count
    npcData.kills = (npcData.kills or 0) + 1
    recentKills[npcID] = nil

    -- Record loot
    for slot = 1, GetNumLootItems() do
        local link = GetLootSlotLink(slot)
        if link then
            local itemID = tonumber(link:match("item:(%d+)"))
            if itemID then
                npcData.items[itemID] = npcData.items[itemID] or { count = 0 }
                npcData.items[itemID].count = npcData.items[itemID].count + 1
            end
        end
    end
end

---------------------------------------------------------
-- NPC TOOLTIP (Zones + Colors + Drop Rates)
---------------------------------------------------------
function MobLootTracker:OnTooltipSetUnit(tooltip)
    local _, unit = tooltip:GetUnit()
    if not unit then return end

    local guid = UnitGUID(unit)
    if not guid then return end

    if not guid:match("^0xF1") then return end

    local npcID = ResolveNPCIDFromGUID(guid)
    if not npcID then return end

    local db = self:GetDB()
    local npcData = db[npcID]
    if not npcData then return end

    npcData.items    = npcData.items    or {}
    npcData.skinning = npcData.skinning or {}
    npcData.zones    = npcData.zones    or {}
    npcData.kills    = npcData.kills    or 0

    local npcName = npcData.name or ("NPC "..npcID)
    tooltip:AddLine(npcName, 1, 0.9, 0.4)

    if next(npcData.zones) then
        local zoneList = ""
        for zoneName in pairs(npcData.zones) do
            zoneList = zoneList .. zoneName .. ", "
        end
        zoneList = zoneList:gsub(", $", "")
        tooltip:AddLine("Zone: " .. zoneList, 0.7, 0.9, 1)
    end

    if next(npcData.items) then
        tooltip:AddLine("Known Drops:", 0.8, 0.8, 0.2)

        for itemID, data in pairs(npcData.items) do
            local name  = GetItemInfo(itemID)
            local count = data.count or 0
            local rate  = npcData.kills > 0 and (count / npcData.kills * 100) or 0
            local color = MLT_GetItemColor(itemID)

            tooltip:AddLine(string.format(
                "  %s%s|r x%d (%.1f%%)",
                color, name or ("Item "..itemID), count, rate
            ))
        end
    end
end
-- MobLootTracker.lua – FINAL FULL VERSION (AzerothCore F1 GUID + Zones + Colors)

MobLootTracker = LibStub("AceAddon-3.0"):NewAddon(
    "MobLootTracker",
    "AceConsole-3.0",
    "AceEvent-3.0",
    "AceHook-3.0"
)


local AceDB = LibStub("AceDB-3.0")

---------------------------------------------------------
-- DATABASE
---------------------------------------------------------
local defaults = {
    profile = {
        showNPCID      = false,
        showDropRates  = true,
        enableSkinning = true,
        debugMode      = false,
    },
    global = {
        MobLootDB = {},
    },
}

function MobLootTracker:GetDB()
    return self.db.global.MobLootDB
end

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
-- GUID → NPCID (AzerothCore F1xx format)
---------------------------------------------------------
local function ResolveNPCIDFromGUID(guid)
    if not guid then return nil end
    local entryHex = guid:match("^0xF1%x%x(%x%x%x%x%x%x)")
    return entryHex and tonumber(entryHex, 16) or nil
end

---------------------------------------------------------
-- INITIALIZE
---------------------------------------------------------
function MobLootTracker:OnInitialize()
    self.db = AceDB:New("MobLootTrackerDB", defaults, true)

    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:RegisterEvent("LOOT_OPENED")

    self:HookScript(GameTooltip, "OnTooltipSetUnit", "OnTooltipSetUnit")

    self:Print("MobLootTracker loaded (zones + colors + AzerothCore F1 GUID)")
end

---------------------------------------------------------
-- KILL TRACKING
---------------------------------------------------------
local recentKills = {}
local lastGUID = nil

function MobLootTracker:COMBAT_LOG_EVENT_UNFILTERED(_, ...)
    local _, subEvent, _, _, _, _, dstGUID = ...

    if subEvent == "UNIT_DIED" and dstGUID then
        local npcID = ResolveNPCIDFromGUID(dstGUID)
        if npcID then
            recentKills[npcID] = true
            lastGUID = dstGUID
        end
    end
end

---------------------------------------------------------
-- LOOT TRACKING + NPC NAME + ZONE STORAGE
---------------------------------------------------------
function MobLootTracker:LOOT_OPENED()
    local db = self:GetDB()
    local npcID = nil

    -- Prefer recent kill
    for id in pairs(recentKills) do npcID = id break end

    -- Fallback: target or mouseover
    if not npcID then
        local guid = UnitGUID("target") or UnitGUID("mouseover")
        npcID = guid and ResolveNPCIDFromGUID(guid)
        lastGUID = guid
    end

    -- Fallback: last GUID
    if not npcID and lastGUID then
        npcID = ResolveNPCIDFromGUID(lastGUID)
    end

    if not npcID then return end

    -- Ensure mob entry exists
    db[npcID] = db[npcID] or {
        kills = 0,
        items = {},
        skinning = {},
        zones = {},
    }

    local npcData = db[npcID]

    -- Store NPC name
    local name = UnitName("target") or UnitName("mouseover") or ("NPC "..npcID)
    npcData.name = name

    -- Store zone
    local zoneName = GetZoneText() or "Unknown Zone"
    npcData.zones[zoneName] = true

    -- Increment kill count
    npcData.kills = npcData.kills + 1
    recentKills[npcID] = nil

    -- Record loot
    for slot = 1, GetNumLootItems() do
        local link = GetLootSlotLink(slot)
        if link then
            local itemID = tonumber(link:match("item:(%d+)"))
            if itemID then
                npcData.items[itemID] = npcData.items[itemID] or { count = 0 }
                npcData.items[itemID].count = npcData.items[itemID].count + 1
            end
        end
    end
end

---------------------------------------------------------
-- NPC TOOLTIP (Zones + Colors + Drop Rates)
---------------------------------------------------------
function MobLootTracker:OnTooltipSetUnit(tooltip)
    local _, unit = tooltip:GetUnit()
    if not unit then return end

    local guid = UnitGUID(unit)
    if not guid then return end

    -- Must be AzerothCore NPC GUID
    if not guid:match("^0xF1") then return end

    local npcID = ResolveNPCIDFromGUID(guid)
    if not npcID then return end

    local db = self:GetDB()
    local npcData = db[npcID]
    if not npcData then return end

    -- Ensure all tables exist (fixes nil errors)
    npcData.items   = npcData.items   or {}
    npcData.skinning = npcData.skinning or {}
    npcData.zones   = npcData.zones   or {}
    npcData.kills   = npcData.kills   or 0

    -----------------------------------------------------
    -- NPC NAME
    -----------------------------------------------------
    local npcName = npcData.name or ("NPC "..npcID)
    tooltip:AddLine(npcName, 1, 0.9, 0.4)

    -----------------------------------------------------
    -- ZONE DISPLAY
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
            local name = GetItemInfo(itemID)
            local count = data.count or 0
            local rate = npcData.kills > 0 and (count / npcData.kills * 100) or 0
            local color = MLT_GetItemColor(itemID)

            tooltip:AddLine(string.format(
                "  %s%s|r x%d (%.1f%%)",
                color, name or ("Item "..itemID), count, rate
            ))
        end
    end
end
