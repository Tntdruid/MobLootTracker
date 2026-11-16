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
    [783]=true,[2318]=true,[2319]=true,[2934]=true,[4231]=true,[4232]=true,[4233]=true,[4234]=true,[4235]=true,
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

-- Gathering spells that open a corpse loot window (Skinning, Herb Gathering, Mining).
-- Everything looted right after one of these casts is profession loot, whatever the item is.
local GATHER_SPELL_IDS = { 8613, 2366, 2575 }
local gatherSpellNames = nil

function MobLootTracker:IsGatherSpell(spellName)
    if not spellName then
        return false
    end
    if not gatherSpellNames then
        gatherSpellNames = {}
        for _, spellID in ipairs(GATHER_SPELL_IDS) do
            local name = GetSpellInfo and GetSpellInfo(spellID)
            if name then
                gatherSpellNames[name] = true
            end
        end
    end
    return gatherSpellNames[spellName] == true
end

function MobLootTracker:GetLootCategory(itemID, fromGathering)
    -- Only loot from a gathering cast on a corpse is skinning loot. A leather that drops
    -- as normal corpse loot stays a regular drop.
    if fromGathering then
        if not self:GetSetting("enableSkinning") then
            return nil
        end
        return "skinning"
    end
    if self:IsQuestItem(itemID) and self:GetSetting("enableQuestItems") then
        return "quest"
    end
    return "loot"
end

-- Skinning rates are per skin, not per kill: not every kill gets skinned.
-- Falls back to kills for NPCs that have no recorded skins.
function MobLootTracker:GetSkinCount(npcData)
    local skins = npcData and tonumber(npcData.skins) or 0
    if skins > 0 then
        return skins
    end
    return npcData and tonumber(npcData.kills) or 0
end

-- Older data has skinning counts but no skin counter. Each skin normally yields one
-- leather/hide, so the sum of the existing skinning counts (capped at kills) is the estimate.
function MobLootTracker:MigrateSkinCounts(db)
    local migrated = 0
    for _, npcData in pairs(db or {}) do
        if type(npcData) == "table" and npcData.skins == nil and npcData.skinning and next(npcData.skinning) then
            local total = 0
            for _, itemData in pairs(npcData.skinning) do
                total = total + (tonumber(itemData.count) or 0)
            end
            local kills = tonumber(npcData.kills) or 0
            if kills > 0 and total > kills then
                total = kills
            end
            npcData.skins = total
            migrated = migrated + 1
        end
    end
    return migrated
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
        maxItemSources = 8,
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
    self:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    self:RegisterEvent("LOOT_OPENED")
    self:RegisterEvent("LOOT_CLOSED")
    self:RegisterEvent("PLAYER_MONEY")
    self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
    self:RegisterChatCommand("mlt", "ShowGUI")
    self:RegisterChatCommand("mltfixloot", "RepairLootCommand")
    self:RegisterChatCommand("mltdelete", "DeleteNPCCommand")

    -- RepairLootCategories is list-based, so it only runs on demand (/mltfixloot):
    -- at login it would move genuine leather drops into skinning every time.
    self:MigrateSkinCounts(SafeDB())

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
local lootGenerationByGUID = {}

local function IsPlayerOrGroupMemberGUID(guid)
    if not guid then
        return false
    end

    if guid == UnitGUID("player") or guid == UnitGUID("pet") then
        return true
    end

    local raidMemberCount = GetNumRaidMembers and GetNumRaidMembers() or 0
    for i = 1, raidMemberCount do
        if guid == UnitGUID("raid" .. i) or guid == UnitGUID("raid" .. i .. "pet") then
            return true
        end
    end

    local partyMemberCount = GetNumPartyMembers and GetNumPartyMembers() or 0
    for i = 1, partyMemberCount do
        if guid == UnitGUID("party" .. i) or guid == UnitGUID("party" .. i .. "pet") then
            return true
        end
    end

    return false
end

function MobLootTracker:COMBAT_LOG_EVENT_UNFILTERED(_, ...)
    local info
    if _G.CombatLogGetCurrentEventInfo then
        info = { _G.CombatLogGetCurrentEventInfo() }
    else
        info = { ... }
    end

    local subEvent = info[2]
    if not subEvent then
        return
    end

    local srcGUID, dstGUID, dstName
    if _G.CombatLogGetCurrentEventInfo then
        srcGUID, dstGUID, dstName = info[4], info[8], info[9]
    else
        -- 3.3.5a signature: timestamp, event, srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags
        srcGUID, dstGUID, dstName = info[3], info[6], info[7]
    end

    if (subEvent == "UNIT_DIED" or subEvent == "PARTY_KILL" or subEvent == "SPELL_INSTAKILL") and dstGUID then
        -- UNIT_DIED has no source on 3.3.5a, so PARTY_KILL supplies the killer GUID.
        if not IsPlayerOrGroupMemberGUID(srcGUID) then
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
        lootGenerationByGUID[dstGUID] = (lootGenerationByGUID[dstGUID] or 0) + 1
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
            -- Name comes from the combat log (the actual victim), never from target/mouseover.
            -- Overwriting also heals names that were saved wrongly by older versions.
            if dstName and dstName ~= "" then
                db[npcID].name = dstName
            else
                db[npcID].name = db[npcID].name or ("NPC " .. npcID)
            end
            db[npcID].kills = (db[npcID].kills or 0) + 1
        end
    end
end

---------------------------------------------------------
-- LOOT TRACKING
-- 3.3.5a has no GetLootSourceInfo / GetLootMoney, so the loot source
-- is the dead mob under the mouse cursor. Nodes, chests, fishing and
-- pickpocketing never match that, so they are ignored.
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

local lastHoveredCorpseGUID = nil
local lastHoveredCorpseTime = 0

function MobLootTracker:UPDATE_MOUSEOVER_UNIT()
    if not UnitExists("mouseover") or not UnitIsDead("mouseover") then
        return
    end

    local guid = UnitGUID("mouseover")
    if ResolveNPCIDFromGUID(guid) then
        lastHoveredCorpseGUID = guid
        lastHoveredCorpseTime = GetTime()
    end
end

local function GetLootCorpse()
    if UnitExists("mouseover") and UnitIsDead("mouseover") then
        local guid = UnitGUID("mouseover")
        local npcID = ResolveNPCIDFromGUID(guid)
        if npcID then
            return npcID, guid
        end
    end

    if lastHoveredCorpseGUID and (GetTime() - lastHoveredCorpseTime) <= 5 then
        local npcID = ResolveNPCIDFromGUID(lastHoveredCorpseGUID)
        if npcID then
            return npcID, lastHoveredCorpseGUID
        end
    end

    return nil
end

-- corpseGUID:itemID -> time counted. Prevents double counting when a corpse is reopened.
local countedLoot = {}
local countedLootSize = 0
local nextCountedLootPrune = 0
local pendingMoney = nil
local lastGatherCastTime = nil

function MobLootTracker:UNIT_SPELLCAST_SUCCEEDED(_, unit, spellName)
    if unit == "player" and self:IsGatherSpell(spellName) then
        lastGatherCastTime = GetTime()
    end
end

local function PruneCountedLoot()
    local now = GetTime()
    if countedLootSize < 500 and now < nextCountedLootPrune then
        return
    end
    nextCountedLootPrune = now + 60
    countedLootSize = 0
    for key, t in pairs(countedLoot) do
        if now - t > 600 then
            countedLoot[key] = nil
        else
            countedLootSize = countedLootSize + 1
        end
    end
end

function MobLootTracker:LOOT_OPENED()
    pendingMoney = nil

    local db = SafeDB()
    if not db then
        return
    end

    if IsFishingLoot and IsFishingLoot() then
        return
    end

    local npcID, guid = GetLootCorpse()
    if not npcID then
        if self:GetSetting("debugMode") then
            self:Print("Loot ignored: no dead mob under the mouse (node/chest/fishing?).")
        end
        return
    end

    local npcData = EnsureLootNPCData(db, npcID)
    local now = GetTime()
    local fromGathering = lastGatherCastTime ~= nil and (now - lastGatherCastTime) <= 3
    lastGatherCastTime = nil
    local seenNow = {}
    local hasCoin = false
    local debugMode = self:GetSetting("debugMode")

    for slot = 1, GetNumLootItems() do
        if LootSlotIsCoin and LootSlotIsCoin(slot) then
            hasCoin = true
            if debugMode then
                self:Print("Loot slot " .. slot .. ": currency")
            end
        else
            local link = GetLootSlotLink(slot)
            local itemID = link and tonumber(link:match("item:(%d+)"))
            if debugMode then
                self:Print("Loot slot " .. slot .. ": " .. (itemID and ("item ID " .. itemID) or "item link unavailable or unparsed"))
            end
            if itemID then
                local generation = lootGenerationByGUID[guid] or 0
                local key = guid .. ":" .. generation .. ":" .. (fromGathering and "gather:" or "") .. itemID
                local duplicate = countedLoot[key] and not seenNow[key]
                local category = self:GetLootCategory(itemID, fromGathering)
                if debugMode then
                    local outcome = (duplicate and "duplicate skipped")
                        or (category and ("recorded as " .. category))
                        or "ignored (skinning tracking disabled)"
                    self:Print("Loot item " .. itemID .. ": " .. outcome)
                end
                if not duplicate and category then
                    seenNow[key] = true

                    local bucket = (category == "skinning" and npcData.skinning)
                        or (category == "quest" and npcData.quest)
                        or npcData.items

                    bucket[itemID] = bucket[itemID] or { count = 0 }
                    bucket[itemID].count = bucket[itemID].count + 1

                    if category == "skinning" then
                        local skinKey = guid .. ":" .. generation .. ":skinned"
                        if not countedLoot[skinKey] then
                            countedLoot[skinKey] = now
                            countedLootSize = countedLootSize + 1
                            npcData.skins = (npcData.skins or 0) + 1
                        end
                    end
                end
            end
        end
    end

    for key in pairs(seenNow) do
        if not countedLoot[key] then
            countedLootSize = countedLootSize + 1
        end
        countedLoot[key] = now
    end
    PruneCountedLoot()

    if hasCoin then
        pendingMoney = { npcID = npcID, before = GetMoney(), open = true }
    end

    if self:GetSetting("debugMode") then
        self:Print("Loot attributed to " .. tostring(npcData.name) .. " (ID " .. npcID .. ").")
    end
end

function MobLootTracker:LOOT_CLOSED()
    if pendingMoney then
        pendingMoney.open = false
        pendingMoney.closedAt = GetTime()
    end
end

-- Money is picked up either while the loot window is open or right after it closes (autoloot).
function MobLootTracker:PLAYER_MONEY()
    local p = pendingMoney
    if not p then
        return
    end

    if not p.open and (GetTime() - (p.closedAt or 0)) > 2 then
        pendingMoney = nil
        return
    end

    local delta = GetMoney() - p.before
    pendingMoney = nil

    if delta > 0 then
        local db = SafeDB()
        if db and db[p.npcID] then
            db[p.npcID].money = (db[p.npcID].money or 0) + delta
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
