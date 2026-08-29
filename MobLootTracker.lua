-- MobLootTracker.lua – FINAL FIX (no double “Dropped by”)

local MobLootTracker = LibStub("AceAddon-3.0"):NewAddon(
    "MobLootTracker",
    "AceConsole-3.0",
    "AceEvent-3.0",
    "AceHook-3.0"
)

local AceDB = LibStub("AceDB-3.0")

---------------------------------------------------------
-- DB
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
-- GUID → NPCID (Creature- GUID format)
---------------------------------------------------------
local function ResolveNPCIDFromGUID(guid)
    if not guid then return nil end
    local npcID = guid:match("Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)")
    return npcID and tonumber(npcID) or nil
end

---------------------------------------------------------
-- INIT
---------------------------------------------------------
function MobLootTracker:OnInitialize()
    self.db = AceDB:New("MobLootTrackerDB", defaults, true)

    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:RegisterEvent("LOOT_OPENED")

    self:HookScript(GameTooltip, "OnTooltipSetUnit", "OnTooltipSetUnit")

    self:Print("MobLootTracker loaded (unit tooltip fully isolated)")
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
-- LOOT TRACKING + NPC NAME STORAGE
---------------------------------------------------------
function MobLootTracker:LOOT_OPENED()
    local db = self:GetDB()
    local npcID = nil

    for id in pairs(recentKills) do npcID = id break end

    if not npcID then
        local guid = UnitGUID("target") or UnitGUID("mouseover")
        npcID = guid and ResolveNPCIDFromGUID(guid)
        lastGUID = guid
    end

    if not npcID and lastGUID then
        npcID = ResolveNPCIDFromGUID(lastGUID)
    end

    if not npcID then return end

    db[npcID] = db[npcID] or { kills = 0, items = {}, skinning = {} }

    -- Store NPC name
    local name = UnitName("target") or UnitName("mouseover") or ("NPC "..npcID)
    db[npcID].name = name

    db[npcID].kills = db[npcID].kills + 1
    recentKills[npcID] = nil

    for slot = 1, GetNumLootItems() do
        local link = GetLootSlotLink(slot)
        if link then
            local itemID = tonumber(link:match("item:(%d+)"))
            if itemID then
                db[npcID].items[itemID] = db[npcID].items[itemID] or { count = 0 }
                db[npcID].items[itemID].count = db[npcID].items[itemID].count + 1
            end
        end
    end
end

---------------------------------------------------------
-- UNIT TOOLTIP (NPC ONLY — FINAL FIX)
---------------------------------------------------------
function MobLootTracker:OnTooltipSetUnit(tooltip)
    local _, unit = tooltip:GetUnit()
    if not unit then return end

    -- HARD FILTER: must be a real NPC
    local guid = UnitGUID(unit)
    if not guid then return end

    -- Must be Creature GUID
    if not guid:match("^Creature") then return end

    -- Must NOT be player
    if UnitIsPlayer(unit) then return end

    -- Must NOT be pet
    if UnitIsUnit(unit, "pet") then return end

    -- Must NOT be vehicle
    if UnitIsUnit(unit, "vehicle") then return end

    -- Now safe: real NPC
    local npcID = ResolveNPCIDFromGUID(guid)
    if not npcID then return end

    local db = self:GetDB()
    local npcData = db[npcID]
    if not npcData then return end

    local npcName = npcData.name or ("NPC "..npcID)
    tooltip:AddLine(npcName, 1, 0.9, 0.4)

    if npcData.items and next(npcData.items) then
        tooltip:AddLine("Known Drops:", 0.8, 0.8, 0.2)
        for itemID, data in pairs(npcData.items) do
            local name = GetItemInfo(itemID)
            local count = data.count or 0
            local rate = (count / npcData.kills) * 100
            tooltip:AddLine(string.format("  %s x%d (%.1f%%)", name or ("Item "..itemID), count, rate))
        end
    end
end
