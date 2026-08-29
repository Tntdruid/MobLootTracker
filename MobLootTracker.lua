-- MobLootTracker.lua – AzerothCore WotLK + Full F1xx GUID Parser + Auto-Loot + Skinning-Spell + Kill-Fix + SavedVariables
MobLootDB = MobLootDB or {}

---------------------------------------------------------
-- GLOBAL GUID parser til alle AzerothCore F1xx-creature GUIDs
---------------------------------------------------------
function ResolveNPCIDFromGUID(guid)
    if not guid then return nil end

    -- numeric fallback
    if type(guid) == "number" then return guid end
    if type(guid) == "string" and guid:match("^%d+$") then return tonumber(guid) end

    -- Match ANY creature-type GUID beginning with F1xx
    -- Format: 0xF1??xxxxxxYYYYZZ
    local entryHex = guid:match("^0xF1%x%x(%x%x%x%x%x%x)")
    if entryHex then
        return tonumber(entryHex, 16)
    end

    return nil
end

---------------------------------------------------------
-- SavedVariables / logout-fix
---------------------------------------------------------
local saveFrame = CreateFrame("Frame")
saveFrame:RegisterEvent("PLAYER_LOGOUT")
saveFrame:SetScript("OnEvent", function()
    MobLootDB = MobLootDB or {}
end)

---------------------------------------------------------
-- Kill + loot tracking via COMBAT_LOG_EVENT_UNFILTERED + LOOT_OPENED
---------------------------------------------------------
local recentKills = {}
local lastGUID = nil

local frame = CreateFrame("Frame")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("LOOT_OPENED")

frame:SetScript("OnEvent", function(self, event, ...)
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

    elseif event == "LOOT_OPENED" then
        -- 1) Combatlog kill NPCID
        local npcID = nil
        for id in pairs(recentKills) do
            npcID = id
            break
        end

        -- 2) Target GUID fallback
        if not npcID then
            local guid = UnitGUID("target")
            if guid then
                npcID = ResolveNPCIDFromGUID(guid)
                lastGUID = guid
            end
        end

        -- 3) Mouseover GUID fallback
        if not npcID then
            local guid = UnitGUID("mouseover")
            if guid then
                npcID = ResolveNPCIDFromGUID(guid)
                lastGUID = guid
            end
        end

        -- 4) Last known GUID fallback
        if not npcID and lastGUID then
            npcID = ResolveNPCIDFromGUID(lastGUID)
        end

        -- 5) Hvis stadig ingen NPCID → stop
        if not npcID then
            print("MobLootTracker: Ingen NPCID ved loot (auto-loot).")
            return
        end

        -- 6) Opret DB entry
        MobLootDB[npcID] = MobLootDB[npcID] or { kills = 0, items = {}, skinning = {} }

        ---------------------------------------------------------
        -- ⭐ KILL-FIX: Count kill on loot ALWAYS
        ---------------------------------------------------------
        MobLootDB[npcID].kills = MobLootDB[npcID].kills + 1

        -- Clear combatlog kill if present
        if recentKills[npcID] then
            recentKills[npcID] = nil
        end

        MobLootDB = MobLootDB

        ---------------------------------------------------------
        -- 8) Registrer loot
        ---------------------------------------------------------
        for slot = 1, GetNumLootItems() do
            local itemLink = GetLootSlotLink(slot)
            if itemLink then
                local itemID = tonumber(string.match(itemLink, "item:(%d+)"))
                if itemID then
                    MobLootDB[npcID].items[itemID] = MobLootDB[npcID].items[itemID] or { count = 0 }
                    MobLootDB[npcID].items[itemID].count = MobLootDB[npcID].items[itemID].count + 1
                    MobLootDB = MobLootDB

                    print("MobLootTracker: Loot registreret for NPCID", npcID, "item", itemID)
                end
            end
        end
    end
end)

---------------------------------------------------------
-- Skinning tracking (kun hvis skinning-spell blev brugt)
---------------------------------------------------------

-- ⭐ AzerothCore bruger FLERE skinning-spellIDs
local SKINNING_SPELLS = {
    [8613] = true, -- standard skinning
    [8617] = true,
    [8618] = true,
    [8619] = true,
    [8620] = true,
}

local lastSkinningTarget = nil

-- Skinning spell detection
local skinSpellFrame = CreateFrame("Frame")
skinSpellFrame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
skinSpellFrame:SetScript("OnEvent", function(self, event, unit, _, spellID)
    if unit == "player" and SKINNING_SPELLS[spellID] then
        lastSkinningTarget = UnitGUID("target")
    end
end)

local skinFrame = CreateFrame("Frame")
skinFrame:RegisterEvent("CHAT_MSG_LOOT")
skinFrame:SetScript("OnEvent", function(self, event, msg)
    local itemLink = msg:match("You receive loot: (.+)")
    if not itemLink then return end

    -- Only treat loot as skinning if we have a skinning target
    if not lastSkinningTarget then return end

    local npcID = ResolveNPCIDFromGUID(lastSkinningTarget)
    lastSkinningTarget = nil -- reset

    if not npcID then return end

    local itemID = tonumber(string.match(itemLink, "item:(%d+)"))
    if not itemID then return end

    MobLootDB[npcID] = MobLootDB[npcID] or { kills = 0, items = {}, skinning = {} }

    MobLootDB[npcID].skinning[itemID] = MobLootDB[npcID].skinning[itemID] or { count = 0 }
    MobLootDB[npcID].skinning[itemID].count = MobLootDB[npcID].skinning[itemID].count + 1
    MobLootDB = MobLootDB

    print("MobLootTracker: Skinning registreret for NPCID", npcID, "item", itemID)
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

print("MobLootTracker (AzerothCore Full F1xx GUID + Auto-Loot + Skinning-Spell + Kill-Fix) loaded")
