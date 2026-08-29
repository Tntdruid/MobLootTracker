-- MobLootTracker.lua – AceAddon + AceEvent + AceHook + AceDB (AzerothCore/WotLK)

local MobLootTracker = LibStub("AceAddon-3.0"):NewAddon(
    "MobLootTracker",
    "AceConsole-3.0",
    "AceEvent-3.0",
    "AceHook-3.0"
)

local AceDB = LibStub("AceDB-3.0")

---------------------------------------------------------
-- Default DB (AceDB profiler)
---------------------------------------------------------
local defaults = {
    profile = {
        showNPCID      = false,
        showItemColors = true,
        showDropRates  = true,
        enableSkinning = true,
        enableGraphs   = true,
        enableMinimap  = true,
        debugMode      = false,
    },
    global = {
        MobLootDB = {}, -- NPC loot/skinning data
    },
}

---------------------------------------------------------
-- Leather items (kan bruges til filters)
---------------------------------------------------------
local LeatherItems = {
    [4231] = true, [4232] = true, [4233] = true,
    [4234] = true, [4235] = true, [4304] = true,
    [8167] = true, [8170] = true, [8171] = true,
}

---------------------------------------------------------
-- Settings API (AceDB profile)
---------------------------------------------------------
function MobLootTracker:GetSetting(key)
    return self.db.profile[key]
end

function MobLootTracker:SetSetting(key, value)
    self.db.profile[key] = value
end

function MobLootTracker:GetDB()
    return self.db.global.MobLootDB
end

---------------------------------------------------------
-- GUID → NPCID parser (AzerothCore F1xx)
---------------------------------------------------------
local function ResolveNPCIDFromGUID(guid)
    if not guid then return nil end
    if type(guid) == "number" then return guid end
    if type(guid) == "string" and guid:match("^%d+$") then
        return tonumber(guid)
    end

    local entryHex = guid:match("^0xF1%x%x(%x%x%x%x%x%x)")
    return entryHex and tonumber(entryHex, 16) or nil
end

---------------------------------------------------------
-- MI2 Skinning Method
---------------------------------------------------------
local lastCorpseID = nil

local function GetCorpseID()
    return UnitGUID("target") or UnitGUID("mouseover")
end

local function IsCorpseReopen(corpseID)
    return corpseID ~= nil and corpseID == lastCorpseID
end

local function StoreCorpseID(corpseID)
    lastCorpseID = corpseID
end

---------------------------------------------------------
-- Item color
---------------------------------------------------------
local function GetItemColor(itemID)
    if not MobLootTracker:GetSetting("showItemColors") then
        return "|cffffffff"
    end

    local _, _, quality = GetItemInfo(itemID)
    if not quality then return "|cffffffff" end

    local colors = {
        [0] = "|cffffffff",
        [1] = "|cffffffff",
        [2] = "|cff1eff00",
        [3] = "|cff0070dd",
        [4] = "|cffa335ee",
        [5] = "|cffff8000",
    }

    return colors[quality] or "|cffffffff"
end

---------------------------------------------------------
-- Skinning drop rate (drop-based)
---------------------------------------------------------
local function GetTotalSkinningDrops(npcData)
    local total = 0
    for _, data in pairs(npcData.skinning) do
        total = total + (data.count or 0)
    end
    return total
end

local function GetSkinningDropRate(npcData, itemID)
    local total = GetTotalSkinningDrops(npcData)
    local count = npcData.skinning[itemID] and npcData.skinning[itemID].count or 0

    if total == 0 then return 0 end
    return (count / total) * 100
end

---------------------------------------------------------
-- Loot drop rate (kills-based)
---------------------------------------------------------
local function GetLootDropRate(npcData, itemID)
    local totalKills = npcData.kills or 1
    local count = npcData.items[itemID] and npcData.items[itemID].count or 0
    return (count / totalKills) * 100
end

---------------------------------------------------------
-- Kill + loot tracking
---------------------------------------------------------
local recentKills = {}
local lastGUID = nil

function MobLootTracker:OnInitialize()
    -- AceDB init
    self.db = AceDB:New("MobLootTrackerDB", defaults, true)

    -- Events (AzerothCore/WotLK API)
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:RegisterEvent("LOOT_OPENED")
    self:RegisterEvent("LOOT_SLOT_CLEARED")

    -- Slash commands
    self:RegisterChatCommand("mltnpcid", "SlashNPCID")
    self:RegisterChatCommand("mltdebug", "SlashDebug")

    -- Tooltip hook via AceHook
    self:HookScript(GameTooltip, "OnTooltipSetUnit", "OnTooltipSetUnit")

    self:Print("MobLootTracker (AceAddon + AceDB, AzerothCore) initialized")
end

-- AzerothCore/WotLK: COMBAT_LOG_EVENT_UNFILTERED payload via ...
function MobLootTracker:COMBAT_LOG_EVENT_UNFILTERED(_, ...)
    local timestamp, subEvent, hideCaster,
          srcGUID, srcName, srcFlags,
          dstGUID, dstName, dstFlags = ...

    if subEvent == "UNIT_DIED" and dstGUID then
        local npcID = ResolveNPCIDFromGUID(dstGUID)
        if npcID then
            recentKills[npcID] = true
            lastGUID = dstGUID

            if self:GetSetting("debugMode") then
                self:Print("UNIT_DIED npcID:", npcID)
            end
        end
    end
end

function MobLootTracker:LOOT_OPENED()
    local db = self:GetDB()
    local npcID = nil

    for id in pairs(recentKills) do npcID = id break end

    if not npcID then
        local guid = UnitGUID("target")
        if guid then npcID = ResolveNPCIDFromGUID(guid) lastGUID = guid end
    end

    if not npcID then
        local guid = UnitGUID("mouseover")
        if guid then npcID = ResolveNPCIDFromGUID(guid) lastGUID = guid end
    end

    if not npcID and lastGUID then
        npcID = ResolveNPCIDFromGUID(lastGUID)
    end

    if not npcID then
        if self:GetSetting("debugMode") then
            self:Print("LOOT_OPENED: Ingen NPCID")
        end
        return
    end

    db[npcID] = db[npcID] or { kills = 0, items = {}, skinning = {} }
    db[npcID].kills = db[npcID].kills + 1
    recentKills[npcID] = nil

    local corpseID = GetCorpseID()
    local isSkinning = self:GetSetting("enableSkinning") and IsCorpseReopen(corpseID)

    for slot = 1, GetNumLootItems() do
        local itemLink = GetLootSlotLink(slot)
        if itemLink then
            local itemID = tonumber(itemLink:match("item:(%d+)"))
            if itemID then
                if isSkinning then
                    db[npcID].skinning[itemID] = db[npcID].skinning[itemID] or { count = 0 }
                    db[npcID].skinning[itemID].count = db[npcID].skinning[itemID].count + 1
                else
                    db[npcID].items[itemID] = db[npcID].items[itemID] or { count = 0 }
                    db[npcID].items[itemID].count = db[npcID].items[itemID].count + 1
                end
            end
        end
    end

    StoreCorpseID(corpseID)
end

function MobLootTracker:LOOT_SLOT_CLEARED()
    local npcID = ResolveNPCIDFromGUID(UnitGUID("target") or UnitGUID("mouseover"))
    if npcID then StoreCorpseID(GetCorpseID()) end
end

---------------------------------------------------------
-- Tooltip hook (AceHook)
---------------------------------------------------------
function MobLootTracker:OnTooltipSetUnit(tooltip)
    local _, unit = tooltip:GetUnit()
    if not unit then return end

    local guid = UnitGUID(unit)
    local npcID = ResolveNPCIDFromGUID(guid)
    if not npcID then return end

    local db = self:GetDB()
    local npcData = db[npcID]
    if not npcData then return end

    -- NPCID toggle
    if self:GetSetting("showNPCID") then
        tooltip:AddLine("NPCID: " .. npcID, 0.6, 0.6, 0.6)
    end

    -- Loot (kills-based)
    if npcData.items and next(npcData.items) then
        tooltip:AddLine("Known Drops:", 0.8, 0.8, 0.2)
        for itemID, data in pairs(npcData.items) do
            local name = GetItemInfo(itemID)
            local count = data.count or 0
            local rate = self:GetSetting("showDropRates") and GetLootDropRate(npcData, itemID) or 0
            local color = GetItemColor(itemID)

            local line = "  " .. color .. (name or ("Item "..itemID)) .. "|r x" .. count
            if self:GetSetting("showDropRates") then
                line = line .. " (" .. string.format("%.1f", rate) .. "%)"
            end
            tooltip:AddLine(line)
        end
    end

    -- Skinning (drop-based)
    if npcData.skinning and next(npcData.skinning) and self:GetSetting("enableSkinning") then
        tooltip:AddLine("Skinning Drops:", 0.2, 0.8, 1)

        for itemID, data in pairs(npcData.skinning) do
            local name = GetItemInfo(itemID)
            local count = data.count or 0
            local rate = self:GetSetting("showDropRates") and GetSkinningDropRate(npcData, itemID) or 0
            local color = GetItemColor(itemID)

            local line = "  " .. color .. (name or ("Item "..itemID)) .. "|r x" .. count
            if self:GetSetting("showDropRates") then
                line = line .. " (" .. string.format("%.1f", rate) .. "%)"
            end
            tooltip:AddLine(line)
        end
    end
end

---------------------------------------------------------
-- Slash commands
---------------------------------------------------------
function MobLootTracker:SlashNPCID(input)
    input = (input or ""):lower():gsub("%s+", "")
    if input == "on" then
        self:SetSetting("showNPCID", true)
        self:Print("NPCID vises i tooltip.")
    elseif input == "off" then
        self:SetSetting("showNPCID", false)
        self:Print("NPCID skjules i tooltip.")
    else
        self:Print("Brug: /mltnpcid on  eller  /mltnpcid off")
    end
end

function MobLootTracker:SlashDebug()
    local new = not self:GetSetting("debugMode")
    self:SetSetting("debugMode", new)
    self:Print("Debug mode:", new and "ON" or "OFF")
end

---------------------------------------------------------
-- Ready
---------------------------------------------------------
MobLootTracker:Print("MobLootTracker (AceAddon + AceEvent + AceHook + AceDB, AzerothCore) loaded")
