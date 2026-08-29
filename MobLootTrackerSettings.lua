-- MobLootTrackerSettings.lua – Global settings + API

---------------------------------------------------------
-- SavedVariables
---------------------------------------------------------
MobLootTrackerSettings = MobLootTrackerSettings or {
    showNPCID      = false,  -- Vis NPCID i tooltip
    showItemColors = true,   -- Vis item-farver i tooltip
    showDropRates  = true,   -- Vis droprates i tooltip
    enableSkinning = true,   -- Skinning-tracking
    enableGraphs   = true,   -- Graphs i GUI
    enableMinimap  = true,   -- Minimap-knap
    debugMode      = false,  -- Debug output
}

---------------------------------------------------------
-- API: Get setting
---------------------------------------------------------
function MobLootTracker_GetSetting(key)
    return MobLootTrackerSettings[key]
end

---------------------------------------------------------
-- API: Set setting
---------------------------------------------------------
function MobLootTracker_SetSetting(key, value)
    MobLootTrackerSettings[key] = value
end

---------------------------------------------------------
-- NPCID toggle (bruges af slash + GUI)
---------------------------------------------------------
function MobLootTracker_ToggleNPCID(state)
    if state == "on" then
        MobLootTrackerSettings.showNPCID = true
        print("MobLootTracker: NPCID vises i tooltip.")
    elseif state == "off" then
        MobLootTrackerSettings.showNPCID = false
        print("MobLootTracker: NPCID skjules i tooltip.")
    else
        print("Brug: /mltnpcid on  eller  /mltnpcid off")
    end
end

---------------------------------------------------------
-- Slash commands
---------------------------------------------------------
SLASH_MLTNPCID1 = "/mltnpcid"
SlashCmdList["MLTNPCID"] = function(msg)
    msg = msg:lower():gsub("%s+", "")
    MobLootTracker_ToggleNPCID(msg)
end

SLASH_MLTDEBUG1 = "/mltdebug"
SlashCmdList["MLTDEBUG"] = function(msg)
    MobLootTrackerSettings.debugMode = not MobLootTrackerSettings.debugMode
    print("MobLootTracker debug mode:", MobLootTrackerSettings.debugMode and "ON" or "OFF")
end

print("MobLootTracker Settings loaded")