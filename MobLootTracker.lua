-- MobLootTracker.lua

MobLootTracker = LibStub("AceAddon-3.0"):NewAddon(
    "MobLootTracker",
    "AceConsole-3.0",
    "AceEvent-3.0",
    "AceHook-3.0"
)

local AceDB = LibStub("AceDB-3.0")

---------------------------------------------------------
-- SKINNING TARGET MATERIALS (Vanilla + BC + WotLK)
---------------------------------------------------------
local SKINNING_ITEMS = {
    -- Classic / vanilla skinning materials
    [2318]=true,[2319]=true,[4231]=true,[4232]=true,[4233]=true,[4234]=true,[4235]=true,
    [4304]=true,[4461]=true,[6470]=true,[6471]=true,[7286]=true,[7287]=true,[7392]=true,
    [8167]=true,[8169]=true,[8170]=true,[8171]=true,[8172]=true,

    -- Burning Crusade
    [21887]=true,[25649]=true,[25700]=true,[25707]=true,[25708]=true,[25703]=true,[25702]=true,
    [23248]=true,[25421]=true,[25420]=true,

    -- WotLK
    [33568]=true,[33567]=true,[38557]=true,[38558]=true,[38561]=true,[44128]=true,
    [52976]=true,[52977]=true,[52978]=true,[52979]=true,[52980]=true,
}

function MobLootTracker:IsSkinningItem(itemID)
    return itemID and SKINNING_ITEMS[itemID] == true
end

function MobLootTracker:IsQuestItem(itemID)
    if not itemID or not GetItemInfo then
        return false
    end

    local itemType = select(6, GetItemInfo(itemID))
    return itemType == "Quest" or (ITEM_CLASS_QUEST and itemType == ITEM_CLASS_QUEST)
end

function MobLootTracker:GetLootCategory(itemID)
    if self:IsSkinningItem(itemID) and self:GetSetting("enableSkinning") then
        return "skinning"
    end
    if self:IsQuestItem(itemID) and self:GetSetting("enableQuestItems") then
        return "quest"
    end
    return "loot"
end

---------------------------------------------------------
-- SAFE SAVEDVARIABLES BOOTSTRAP
---------------------------------------------------------
MobLootTrackerDB = MobLootTrackerDB or {}

---------------------------------------------------------
-- ACEDB DEFAULTS
---------------------------------------------------------
local defaults = {
    profile = {
        debugMode      = false,
        enableSkinning = true,
        enableQuestItems = true,
    },
    global = {
        MobLootDB = {},
    },
}

---------------------------------------------------------
-- SAFE DB ACCESS
---------------------------------------------------------
local function SafeDB()
    if MobLootTracker and MobLootTracker.db and MobLootTracker.db.global and MobLootTracker.db.global.MobLootDB then
        return MobLootTracker.db.global.MobLootDB
    end
    if MobLootTrackerDB and MobLootTrackerDB.global and MobLootTrackerDB.global.MobLootDB then
        return MobLootTrackerDB.global.MobLootDB
    end
    return nil
end

function MobLootTracker:GetSetting(key)
    if self.db and self.db.profile then
        return self.db.profile[key]
    end
    return MobLootTrackerDB.profile and MobLootTrackerDB.profile[key]
end

function MobLootTracker:SetSetting(key, val)
    if self.db and self.db.profile then
        self.db.profile[key] = val
    end
    if MobLootTrackerDB and MobLootTrackerDB.profile then
        MobLootTrackerDB.profile[key] = val
    end
end

---------------------------------------------------------
-- GUID → NPCID (AzerothCore F1xx format)
---------------------------------------------------------
local function ResolveNPCIDFromGUID(guid)
    if not guid then return nil end

    if type(guid) == "number" then
        return guid > 0 and guid or nil
    end

    if type(guid) ~= "string" then
        return nil
    end

    if guid:match("^%d+$") then
        local id = tonumber(guid)
        return id and id > 0 and id or nil
    end

    local entryHex = guid:match("^0xF1%x%x(%x%x%x%x%x%x)")
    if entryHex then
        return tonumber(entryHex, 16)
    end

    local entryHex2 = guid:match("^0xF%x%x%x%x(%x%x%x%x%x%x)")
    if entryHex2 then
        return tonumber(entryHex2, 16)
    end

    return nil
end

local function ExtractMobGUIDFromEvent(info)
    if not info then
        return nil
    end

    for i = 1, #info do
        local value = info[i]
        if type(value) == "number" and value > 0 then
            return value
        end

        if type(value) == "string" then
            if value:match("^0x") or value:match("^%d+$") then
                return value
            end
        end
    end

    return nil
end

---------------------------------------------------------
-- INITIALIZE
---------------------------------------------------------
function MobLootTracker:OnInitialize()
    self.db = AceDB:New("MobLootTrackerDB", defaults, true)

    self.db.global = self.db.global or {}
    self.db.global.MobLootDB = self.db.global.MobLootDB or {}
    self.db.profile = self.db.profile or {}
    self.db.minimap = self.db.minimap or { hide = false, minimapPos = 220 }
    MobLootTrackerDB = self.db

    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:RegisterEvent("LOOT_OPENED")
    self:RegisterChatCommand("mlt", "ShowGUI")

    self:Print("MobLootTracker loaded.")
end

---------------------------------------------------------
-- KILL TRACKING
---------------------------------------------------------
local recentKills = {}
local lastGUID = nil
local lastLootGUID = nil
local lastLootTime = 0
local lastKillGUID = nil
local lastKillTime = 0
local processedDeaths = {}

function MobLootTracker:COMBAT_LOG_EVENT_UNFILTERED(_, ...)
    local info
    if _G.CombatLogGetCurrentEventInfo then
        info = { _G.CombatLogGetCurrentEventInfo() }
    else
        info = { ... }
    end

    if not info or #info < 2 then
        return
    end

    local subEvent = info[2]
    local dstGUID
    if _G.CombatLogGetCurrentEventInfo then
        dstGUID = info[8]
    else
        dstGUID = info[6]
    end

    if (subEvent == "UNIT_DIED" or subEvent == "PARTY_KILL" or subEvent == "SPELL_INSTAKILL") and dstGUID then
        local npcID = ResolveNPCIDFromGUID(dstGUID)
        if not npcID then
            return
        end

        local now = GetTime()
        if lastKillGUID == dstGUID and (now - lastKillTime) < 1 then
            return
        end

        if processedDeaths[dstGUID] and (now - processedDeaths[dstGUID]) < 1 then
            return
        end

        processedDeaths[dstGUID] = now
        lastKillGUID = dstGUID
        lastKillTime = now

        local db = SafeDB()
        if db then
            db[npcID] = db[npcID] or {
                kills = 0,
                items = {},
                skinning = {},
                quest = {},
                zones = {},
            }
            db[npcID].name = db[npcID].name or (UnitName("target") or UnitName("mouseover") or ("NPC " .. npcID))
            db[npcID].kills = (db[npcID].kills or 0) + 1
        end

        recentKills[npcID] = true
        lastGUID = dstGUID
    end
end

---------------------------------------------------------
-- LOOT TRACKING (Leather → skinning, resten → items)
---------------------------------------------------------
function MobLootTracker:LOOT_OPENED()
    local currentGUID = lastGUID or UnitGUID("target") or UnitGUID("mouseover")
    local now = GetTime()

    if currentGUID and currentGUID == lastLootGUID and (now - lastLootTime) < 1 then
        return
    end

    lastLootGUID = currentGUID
    lastLootTime = now

    local db    = SafeDB()
    local npcID = nil

    npcID = currentGUID and ResolveNPCIDFromGUID(currentGUID)

    if not npcID then
        for id in pairs(recentKills) do npcID = id break end
    end

    if not npcID and lastGUID then
        npcID = ResolveNPCIDFromGUID(lastGUID)
    end

    if not npcID then return end

    db[npcID] = db[npcID] or {
        kills    = 0,
        items    = {},
        skinning = {},
        quest    = {},
        zones    = {},
    }

    local npcData = db[npcID]
    npcData.quest = npcData.quest or {}
    npcData.name = UnitName("target") or UnitName("mouseover") or ("NPC "..npcID)
    npcData.zones[GetZoneText() or "Unknown Zone"] = true

    for slot = 1, GetNumLootItems() do
        local link = GetLootSlotLink(slot)
        if link then
            local itemID = tonumber(link:match("item:(%d+)"))
            if itemID then
                local category = self:GetLootCategory(itemID)
                if category == "skinning" then
                    npcData.skinning[itemID] = npcData.skinning[itemID] or { count = 0 }
                    npcData.skinning[itemID].count = npcData.skinning[itemID].count + 1
                elseif category == "quest" then
                    npcData.quest[itemID] = npcData.quest[itemID] or { count = 0 }
                    npcData.quest[itemID].count = npcData.quest[itemID].count + 1
                else
                    npcData.items[itemID] = npcData.items[itemID] or { count = 0 }
                    npcData.items[itemID].count = npcData.items[itemID].count + 1
                end
            end
        end
    end
end

---------------------------------------------------------
-- SIMPLE GUI
---------------------------------------------------------
function MobLootTracker:ShowGUI()
    local db = SafeDB()
    local count = 0
    for _ in pairs(db) do count = count + 1 end

    self:Print("MobLootTracker: tracked NPCs: " .. count)
    self:Print("Hover NPCs or items to view tracked loot and skinning data.")
end
