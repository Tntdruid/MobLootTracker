-- MobLootTracker.lua – AzerothCore WotLK + MI2 Skinning Method + Kill-Fix + Auto-Loot + F1xx GUID Parser
MobLootDB = MobLootDB or {}

---------------------------------------------------------
-- GUID parser (AzerothCore F1xx creature GUIDs)
---------------------------------------------------------
function ResolveNPCIDFromGUID(guid)
    if not guid then return nil end

    if type(guid) == "number" then return guid end
    if type(guid) == "string" and guid:match("^%d+$") then return tonumber(guid) end

    local entryHex = guid:match("^0xF1%x%x(%x%x%x%x%x%x)")
    if entryHex then
        return tonumber(entryHex, 16)
    end

    return nil
end

---------------------------------------------------------
-- SavedVariables
---------------------------------------------------------
local saveFrame = CreateFrame("Frame")
saveFrame:RegisterEvent("PLAYER_LOGOUT")
saveFrame:SetScript("OnEvent", function()
    MobLootDB = MobLootDB or {}
end)

---------------------------------------------------------
-- MI2 Skinning Method: corpse reopen detection
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
-- Kill tracking (WotLK combatlog)
---------------------------------------------------------
local recentKills = {}
local lastGUID = nil

local mainFrame = CreateFrame("Frame")
mainFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
mainFrame:RegisterEvent("LOOT_OPENED")
mainFrame:RegisterEvent("LOOT_SLOT_CLEARED")

mainFrame:SetScript("OnEvent", function(self, event, ...)

    ---------------------------------------------------------
    -- UNIT_DIED → kill detection
    ---------------------------------------------------------
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subEvent, hideCaster,
              srcGUID, srcName, srcFlags,
              dstGUID, dstName, dstFlags = ...

        if subEvent == "UNIT_DIED" and dstGUID then
            local npcID = ResolveNPCIDFromGUID(dstGUID)
            if npcID then
                recentKills[npcID] = true
                lastGUID = dstGUID
            end
        end
    end

    ---------------------------------------------------------
    -- LOOT_OPENED → normal loot + skinning loot
    ---------------------------------------------------------
    if event == "LOOT_OPENED" then

        local npcID = nil

        -- 1) Combatlog kill
        for id in pairs(recentKills) do
            npcID = id
            break
        end

        -- 2) Target fallback
        if not npcID then
            local guid = UnitGUID("target")
            if guid then
                npcID = ResolveNPCIDFromGUID(guid)
                lastGUID = guid
            end
        end

        -- 3) Mouseover fallback
        if not npcID then
            local guid = UnitGUID("mouseover")
            if guid then
                npcID = ResolveNPCIDFromGUID(guid)
                lastGUID = guid
            end
        end

        -- 4) Last GUID fallback
        if not npcID and lastGUID then
            npcID = ResolveNPCIDFromGUID(lastGUID)
        end

        if not npcID then
            print("MobLootTracker: Ingen NPCID ved loot.")
            return
        end

        MobLootDB[npcID] = MobLootDB[npcID] or { kills = 0, items = {}, skinning = {} }

        -- Kill fix
        MobLootDB[npcID].kills = MobLootDB[npcID].kills + 1
        recentKills[npcID] = nil

        ---------------------------------------------------------
        -- MI2 Skinning Method: corpse reopen = skinning
        ---------------------------------------------------------
        local corpseID = GetCorpseID()
        local isSkinning = IsCorpseReopen(corpseID)

        ---------------------------------------------------------
        -- Register loot
        ---------------------------------------------------------
        for slot = 1, GetNumLootItems() do
            local itemLink = GetLootSlotLink(slot)
            if itemLink then
                local itemID = tonumber(itemLink:match("item:(%d+)"))
                if itemID then

                    if isSkinning then
                        ---------------------------------------------------------
                        -- ⭐ SKINNING LOOT
                        ---------------------------------------------------------
                        MobLootDB[npcID].skinning[itemID] = MobLootDB[npcID].skinning[itemID] or { count = 0 }
                        MobLootDB[npcID].skinning[itemID].count = MobLootDB[npcID].skinning[itemID].count + 1

                        print("MobLootTracker: Skinning registreret for NPCID", npcID, "item", itemID)

                    else
                        ---------------------------------------------------------
                        -- NORMAL LOOT
                        ---------------------------------------------------------
                        MobLootDB[npcID].items[itemID] = MobLootDB[npcID].items[itemID] or { count = 0 }
                        MobLootDB[npcID].items[itemID].count = MobLootDB[npcID].items[itemID].count + 1

                        print("MobLootTracker: Loot registreret for NPCID", npcID, "item", itemID)
                    end
                end
            end
        end

        ---------------------------------------------------------
        -- First loot = normal loot → store corpse ID
        ---------------------------------------------------------
        StoreCorpseID(corpseID)
    end

    ---------------------------------------------------------
    -- LOOT_SLOT_CLEARED → update corpse ID
    ---------------------------------------------------------
    if event == "LOOT_SLOT_CLEARED" then
        local npcID = ResolveNPCIDFromGUID(UnitGUID("target") or UnitGUID("mouseover"))
        if npcID then
            StoreCorpseID(GetCorpseID())
        end
    end
end)

---------------------------------------------------------
-- Debug command
---------------------------------------------------------
SLASH_MLTDEBUG1 = "/mltdebug"
SlashCmdList["MLTDEBUG"] = function()
    local guid = UnitGUID("mouseover")
    local npcID = guid and ResolveNPCIDFromGUID(guid)
    print("GUID:", guid, "NPCID:", npcID)

    if npcID and MobLootDB[npcID] then
        print("DB entry found for", npcID)
    else
        print("NO DB for", npcID)
    end
end

print("MobLootTracker (MI2 Skinning Method + Kill-Fix + F1xx GUID Parser) loaded")
