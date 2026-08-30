-- MobLootTrackerMinimap.lua – stabil minimap-knap med Ace3 + LibDBIcon

local addon = MobLootTracker
local icon  = LibStub("LibDBIcon-1.0")
local LDB   = LibStub("LibDataBroker-1.1"):NewDataObject("MobLootTracker", {
    type = "launcher",
    text = "MobLootTracker",
    icon = "Interface\\Icons\\INV_Misc_Pelt_01",

    OnClick = function(_, button)
        if button == "LeftButton" then
            addon:ShowGUI()
        elseif button == "RightButton" then
            addon:OpenMinimapMenu()
        end
    end,

    OnTooltipShow = function(tooltip)
        tooltip:AddLine("MobLootTracker")
        tooltip:AddLine("Left-click: Open window")
        tooltip:AddLine("Right-click: Minimap options")
    end,
})

---------------------------------------------------------
-- MINIMAP MENU
---------------------------------------------------------
local menuFrame = CreateFrame("Frame", "MobLootTrackerMinimapMenu", UIParent, "UIDropDownMenuTemplate")

function addon:OpenMinimapMenu()
    local menu = {
        {
            text = "MobLootTracker",
            isTitle = true,
            notCheckable = true,
        },
        {
            text = "Open Window",
            notCheckable = true,
            func = function() addon:ShowGUI() end,
        },
        {
            text = "Hide Minimap Icon",
            notCheckable = true,
            func = function()
                MobLootTrackerDB.minimap.hide = true
                icon:Hide("MobLootTracker")
            end,
        },
        {
            text = "Reset Position",
            notCheckable = true,
            func = function()
                MobLootTrackerDB.minimap.minimapPos = 220
                icon:Refresh("MobLootTracker", MobLootTrackerDB.minimap)
            end,
        },
    }

    EasyMenu(menu, menuFrame, "cursor", 0, 0, "MENU", 2)
end

---------------------------------------------------------
-- INITIALIZE MINIMAP ICON
---------------------------------------------------------
function addon:InitMinimap()
    MobLootTrackerDB.minimap = MobLootTrackerDB.minimap or { hide = false, minimapPos = 220 }

    icon:Register("MobLootTracker", LDB, MobLootTrackerDB.minimap)

    if MobLootTrackerDB.minimap.hide then
        icon:Hide("MobLootTracker")
    else
        icon:Show("MobLootTracker")
    end
end

---------------------------------------------------------
-- HOOK INTO ADDON INITIALIZATION
---------------------------------------------------------
addon:RegisterEvent("PLAYER_LOGIN", function()
    addon:InitMinimap()
end)
