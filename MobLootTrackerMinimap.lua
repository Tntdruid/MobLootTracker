-- MobLootTrackerMinimap.lua – LibDBIcon minimap-knap

local MobLootTracker = LibStub("AceAddon-3.0"):GetAddon("MobLootTracker")
local LDB = LibStub("LibDataBroker-1.1")
local DBIcon = LibStub("LibDBIcon-1.0")

---------------------------------------------------------
-- DataBroker objekt
---------------------------------------------------------
local broker = LDB:NewDataObject("MobLootTracker", {
    type = "launcher",
    icon = "Interface\\Icons\\INV_Misc_Bone_01",
    label = "MobLootTracker",

    OnClick = function(_, button)
        if button == "LeftButton" then
            if MobLootTracker.lastNPCID then
                MobLootTracker:ShowGUI(MobLootTracker.lastNPCID)
            else
                MobLootTracker:Print("Ingen NPC valgt endnu.")
            end

        elseif button == "RightButton" then
            InterfaceOptionsFrame_OpenToCategory("MobLootTracker")
            InterfaceOptionsFrame_OpenToCategory("MobLootTracker")
        end
    end,

    OnTooltipShow = function(tooltip)
        tooltip:AddLine("MobLootTracker")
        tooltip:AddLine("Venstreklik: Åbn GUI")
        tooltip:AddLine("Højreklik: Åbn indstillinger")
    end,
})

---------------------------------------------------------
-- Init minimap-knap
---------------------------------------------------------
function MobLootTracker:InitMinimap()
    -- Opret profil-felt hvis det ikke findes
    self.db.profile.minimap = self.db.profile.minimap or { hide = false }

    -- Registrer knappen
    DBIcon:Register("MobLootTracker", broker, self.db.profile.minimap)

    -- Vis/skjul baseret på settings
    if self:GetSetting("enableMinimap") then
        DBIcon:Show("MobLootTracker")
    else
        DBIcon:Hide("MobLootTracker")
    end
end

---------------------------------------------------------
-- Opdatering når settings ændres
---------------------------------------------------------
function MobLootTracker:UpdateMinimap()
    if self:GetSetting("enableMinimap") then
        self.db.profile.minimap.hide = false
        DBIcon:Show("MobLootTracker")
    else
        self.db.profile.minimap.hide = true
        DBIcon:Hide("MobLootTracker")
    end
end
