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
    [2318]=true,[2319]=true,[2934]=true,[4231]=true,[4232]=true,[4233]=true,[4234]=true,[4235]=true,
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

function MobLootTracker:FormatMoney(copper)
    local totalCopper = math.max(0, math.floor(tonumber(copper) or 0))
    local gold = math.floor(totalCopper / 10000)
    local silver = math.floor((totalCopper % 10000) / 100)
    local remainingCopper = totalCopper % 100
    local parts = {}

    if gold > 0 then
        parts[#parts + 1] = gold .. "g"
    end
    if silver > 0 then
        parts[#parts + 1] = silver .. "s"
    end
    if remainingCopper > 0 or #parts == 0 then
        parts[#parts + 1] = remainingCopper .. "c"
    end

    return table.concat(parts, " ")
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
        showNPCID      = false,
        showMobName    = true,
        enableSkinning = true,
        enableQuestItems = true,
    },
    global = {
        MobLootDB = {},
        minimap = { hide = false, minimapPos = 220 },
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

function MobLootTracker:GetDB()
    return SafeDB() or {}
end

function MobLootTracker:GetSetting(key)
    if self.db and self.db.profile then
        return self.db.profile[key]
    end
end

function MobLootTracker:SetSetting(key, val)
    if self.db and self.db.profile then
        self.db.profile[key] = val
    end
end

function MobLootTracker:RepairLootCategories()
    local db = SafeDB()
    if not db then
        return 0
    end

    local movedCount = 0
    for _, npcData in pairs(db) do
        if type(npcData) == "table" and npcData.items then
            for itemID, itemData in pairs(npcData.items) do
                local numericItemID = tonumber(itemID)
                if numericItemID and self:IsSkinningItem(numericItemID) then
                    npcData.skinning = npcData.skinning or {}
                    local skinningData = npcData.skinning[numericItemID]
                    if not skinningData then
                        skinningData = { count = 0 }
                        npcData.skinning[numericItemID] = skinningData
                    end
                    skinningData.count = (skinningData.count or 0) + (itemData.count or 0)
                    npcData.items[itemID] = nil
                    movedCount = movedCount + 1
                end
            end
        end
    end

    return movedCount
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

    local entryHex = guid:match("^0xF130(%x%x%x%x%x%x)")
    if entryHex then
        return tonumber(entryHex, 16)
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

    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:RegisterEvent("LOOT_OPENED")
    self:RegisterChatCommand("mlt", "ShowGUI")
    self:RegisterChatCommand("mltfixloot", "RepairLootCommand")
    self:RegisterChatCommand("mltdelete", "DeleteNPCCommand")

    self:RepairLootCategories()

    self:Print("MobLootTracker loaded.")
end

function MobLootTracker:RepairLootCommand()
    local movedCount = self:RepairLootCategories()
    self:Print("Loot categories repaired: " .. movedCount .. " item entries moved to Skinning.")
end

function MobLootTracker:DeleteNPCCommand(input)
    local npcIDText, confirmation = tostring(input or ""):match("^%s*(%d+)%s*(%S*)%s*$")
    local npcID = tonumber(npcIDText)
    if not npcID or npcID < 1 then
        self:Print("Usage: /mltdelete <NPC ID> [confirm]")
        return
    end

    local db = SafeDB()
    if not db then
        self:Print("NPC database is unavailable.")
        return
    end

    local npcData = db[npcID] or db[npcIDText]
    if not npcData then
        self:Print("No saved data found for NPC ID " .. npcID .. ".")
        return
    end

    local npcName = type(npcData) == "table" and npcData.name or nil
    if confirmation ~= "confirm" then
        self:Print("This will delete all saved data for " .. (npcName or "NPC") .. " (ID " .. npcID .. ").")
        self:Print("Run /mltdelete " .. npcID .. " confirm to confirm.")
        return
    end

    db[npcID] = nil
    db[npcIDText] = nil
    self:Print("Deleted saved data for " .. (npcName or "NPC") .. " (ID " .. npcID .. ").")
end

---------------------------------------------------------
-- KILL TRACKING
---------------------------------------------------------
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
    local srcGUID, dstGUID
    if _G.CombatLogGetCurrentEventInfo then
        srcGUID = info[4]
        dstGUID = info[8]
    else
        -- pre-Cataclysm signature has no hideCaster field, shifting indices back by one
        srcGUID = info[3]
        dstGUID = info[6]
    end

    if (subEvent == "UNIT_DIED" or subEvent == "PARTY_KILL" or subEvent == "SPELL_INSTAKILL") and dstGUID then
        -- UNIT_DIED fires for every nearby death and has no reliable source.
        -- Direct kill events already identify the player or pet as the source.
        local playerGUID = UnitGUID("player")
        local petGUID = UnitGUID("pet")
        local isMine = srcGUID and (srcGUID == playerGUID or (petGUID and srcGUID == petGUID))
        if subEvent == "UNIT_DIED" and not isMine then
            return
        end

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

    end
end

---------------------------------------------------------
-- LOOT TRACKING (Leather → skinning, resten → items)
---------------------------------------------------------
local function EnsureLootNPCData(db, npcID)
    db[npcID] = db[npcID] or {
        kills    = 0,
        items    = {},
        skinning = {},
        quest    = {},
        zones    = {},
    }

    local npcData = db[npcID]
    npcData.items = npcData.items or {}
    npcData.skinning = npcData.skinning or {}
    npcData.quest = npcData.quest or {}
    npcData.zones = npcData.zones or {}
    npcData.name = npcData.name or ("NPC " .. npcID)
    npcData.zones[GetZoneText() or "Unknown Zone"] = true
    return npcData
end

local function GetRecentLootNPCID()
    if not lastKillGUID or (GetTime() - lastKillTime) > 120 then
        return nil
    end

    local targetGUID = UnitGUID("target")
    if targetGUID == lastKillGUID and UnitIsDead and UnitIsDead("target") then
        return ResolveNPCIDFromGUID(targetGUID)
    end

    return ResolveNPCIDFromGUID(lastKillGUID)
end

function MobLootTracker:LOOT_OPENED()
    local db = SafeDB()
    if not db then
        return
    end

    local lootSourceNPCID = nil
    local hasLootSourceInfo = false
    local lootSlots = {}
    for slot = 1, GetNumLootItems() do
        local link = GetLootSlotLink(slot)
        if link then
            local itemID = tonumber(link:match("item:(%d+)"))
            if itemID then
                local sourceInfo = GetLootSourceInfo and { GetLootSourceInfo(slot) } or {}
                hasLootSourceInfo = hasLootSourceInfo or #sourceInfo > 0
                lootSlots[#lootSlots + 1] = { itemID = itemID, sourceInfo = sourceInfo }
            end
        end
    end

    local fallbackNPCID = not hasLootSourceInfo and GetRecentLootNPCID()
    for _, lootSlot in ipairs(lootSlots) do
        local itemID = lootSlot.itemID
        local sourceInfo = lootSlot.sourceInfo
        if fallbackNPCID then
            sourceInfo = { fallbackNPCID, 1 }
        end

        for sourceIndex = 1, #sourceInfo, 2 do
            local npcID = ResolveNPCIDFromGUID(sourceInfo[sourceIndex])
            local quantity = tonumber(sourceInfo[sourceIndex + 1]) or 1
            if npcID and quantity > 0 then
                lootSourceNPCID = lootSourceNPCID or npcID
                local npcData = EnsureLootNPCData(db, npcID)

                local category = self:GetLootCategory(itemID)
                if category == "skinning" then
                    npcData.skinning[itemID] = npcData.skinning[itemID] or { count = 0 }
                    npcData.skinning[itemID].count = npcData.skinning[itemID].count + quantity
                elseif category == "quest" then
                    npcData.quest[itemID] = npcData.quest[itemID] or { count = 0 }
                    npcData.quest[itemID].count = npcData.quest[itemID].count + quantity
                else
                    npcData.items[itemID] = npcData.items[itemID] or { count = 0 }
                    npcData.items[itemID].count = npcData.items[itemID].count + quantity
                end
            end
        end
    end

    local money = GetLootMoney and GetLootMoney() or 0
    if money > 0 then
        local npcID = lootSourceNPCID or (not hasLootSourceInfo and fallbackNPCID)
        if npcID then
            local npcData = EnsureLootNPCData(db, npcID)
            npcData.money = (npcData.money or 0) + money
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
