-- MobLootTrackerGUI.lua – SAFE VERSION (no top-level MobLootTracker usage)

local AceGUI = LibStub("AceGUI-3.0")

---------------------------------------------------------
-- MAIN WINDOW
---------------------------------------------------------
function MobLootTracker:ShowGUI()
    if self.GUI then
        self.GUI:Show()
        self:RefreshGUI()
        return
    end

    local frame = AceGUI:Create("Frame")
    frame:SetTitle("MobLootTracker")
    frame:SetStatusText("Loot, NPCs, Zones, Settings")
    frame:SetLayout("Flow")
    frame:SetWidth(600)
    frame:SetHeight(500)
    frame:EnableResize(true)

    self.GUI = frame

    local tabs = AceGUI:Create("TabGroup")
    tabs:SetLayout("Flow")
    tabs:SetTabs({
        {text = "Loot", value = "loot"},
        {text = "Skinning", value = "skin"},
        {text = "NPCs", value = "npc"},
        {text = "Settings", value = "settings"},
    })
    tabs:SetFullWidth(true)
    tabs:SetFullHeight(true)
    tabs:SelectTab("loot")

    frame:AddChild(tabs)

    tabs:SetCallback("OnGroupSelected", function(container, event, group)
        container:ReleaseChildren()

        if group == "loot" then
            MobLootTracker:BuildLootTab(container)
        elseif group == "skin" then
            MobLootTracker:BuildSkinTab(container)
        elseif group == "npc" then
            MobLootTracker:BuildNPCTab(container)
        elseif group == "settings" then
            MobLootTracker:BuildSettingsTab(container)
        end
    end)

    self:RefreshGUI()
end

---------------------------------------------------------
-- REFRESH GUI
---------------------------------------------------------
function MobLootTracker:RefreshGUI()
    if not self.GUI then return end
    self.GUI.children[1]:SelectTab(self.GUI.children[1].selected)
end

---------------------------------------------------------
-- LOOT TAB
---------------------------------------------------------
function MobLootTracker:BuildLootTab(container)
    local db = self:GetDB()

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    container:AddChild(scroll)

    for npcID, npcData in pairs(db) do
        if npcData.items then
            for itemID, data in pairs(npcData.items) do
                local name = GetItemInfo(itemID) or ("Item "..itemID)
                local rate = npcData.kills > 0 and (data.count / npcData.kills * 100) or 0

                local label = AceGUI:Create("Label")
                label:SetText(string.format(
                    "|cffffd200%s|r dropped by %s (%d kills) – %.1f%%",
                    name, npcData.name or ("NPC "..npcID), npcData.kills, rate
                ))
                label:SetFullWidth(true)
                scroll:AddChild(label)
            end
        end
    end
end

---------------------------------------------------------
-- SKINNING TAB
---------------------------------------------------------
function MobLootTracker:BuildSkinTab(container)
    local db = self:GetDB()

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    container:AddChild(scroll)

    for npcID, npcData in pairs(db) do
        if npcData.skinning then
            for itemID, data in pairs(npcData.skinning) do
                local name = GetItemInfo(itemID) or ("Item "..itemID)

                local label = AceGUI:Create("Label")
                label:SetText(string.format(
                    "|cff88ff88%s|r skinned from %s (%d skins)",
                    name, npcData.name or ("NPC "..npcID), data.count
                ))
                label:SetFullWidth(true)
                scroll:AddChild(label)
            end
        end
    end
end

---------------------------------------------------------
-- NPC TAB
---------------------------------------------------------
function MobLootTracker:BuildNPCTab(container)
    local db = self:GetDB()

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    container:AddChild(scroll)

    for npcID, npcData in pairs(db) do
        local zones = ""
        if npcData.zones then
            for zone in pairs(npcData.zones) do
                zones = zones .. zone .. ", "
            end
            zones = zones:gsub(", $", "")
        end

        local label = AceGUI:Create("Label")
        label:SetText(string.format(
            "|cffffd200%s|r (ID %d)\nKills: %d\nZones: %s",
            npcData.name or ("NPC "..npcID),
            npcID,
            npcData.kills or 0,
            zones ~= "" and zones or "Unknown"
        ))
        label:SetFullWidth(true)
        scroll:AddChild(label)
    end
end

---------------------------------------------------------
-- SETTINGS TAB
---------------------------------------------------------
function MobLootTracker:BuildSettingsTab(container)
    local debugToggle = AceGUI:Create("CheckBox")
    debugToggle:SetLabel("Enable Debug Mode")
    debugToggle:SetValue(self:GetSetting("debugMode"))
    debugToggle:SetCallback("OnValueChanged", function(_, _, val)
        self:SetSetting("debugMode", val)
    end)
    container:AddChild(debugToggle)

    local npcIDToggle = AceGUI:Create("CheckBox")
    npcIDToggle:SetLabel("Show NPC ID in Tooltip")
    npcIDToggle:SetValue(self:GetSetting("showNPCID"))
    npcIDToggle:SetCallback("OnValueChanged", function(_, _, val)
        self:SetSetting("showNPCID", val)
    end)
    container:AddChild(npcIDToggle)
end
