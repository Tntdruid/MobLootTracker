-- MobLootTrackerMinimap.lua – LibDataBroker + LibDBIcon launcher

local LDB = LibStub("LibDataBroker-1.1"):NewDataObject("MobLootTracker", {
    type = "launcher",
    text = "MobLootTracker",

    -- 🐺 Wolf icon
    icon = "Interface\\Icons\\Ability_Hunter_BeastCall",

    OnClick = function(_, button)
        if button == "LeftButton" then
            MobLootTracker:ShowGUI()
        elseif button == "RightButton" then
            MobLootTracker:Print("Use /mlt to open GUI")
        end
    end,

    OnTooltipShow = function(tooltip)
        tooltip:AddLine("MobLootTracker")
        tooltip:AddLine("Left-click: Open GUI")
        tooltip:AddLine("Right-click: Info")
    end,
})

local DBIcon = LibStub("LibDBIcon-1.0")

---------------------------------------------------------
-- INIT MINIMAP ICON
---------------------------------------------------------
function MobLootTracker:InitMinimap()
    -- Ensure SavedVariables exist
    if not MobLootTrackerDB.minimap then
        MobLootTrackerDB.minimap = { hide = false }
    end

    -- Register icon
    DBIcon:Register("MobLootTracker", LDB, MobLootTrackerDB.minimap)

    -- Show or hide based on saved settings
    if MobLootTrackerDB.minimap.hide then
        DBIcon:Hide("MobLootTracker")
    else
        DBIcon:Show("MobLootTracker")
    end
end
