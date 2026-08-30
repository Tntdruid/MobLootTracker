-- MobLootTrackerGUI.lua – Complete GUI with integrated settings menu

local AceGUI = LibStub("AceGUI-3.0")

---------------------------------------------------------
-- MAIN WINDOW
---------------------------------------------------------
function MobLootTracker:ShowGUI()
    if self.GUI and self.GUI.frame and self.GUI.frame:IsShown() then
        self.GUI.frame:Hide()
        return
    end

    local frame = AceGUI:Create("Frame")
    frame:SetTitle("MobLootTracker")
    frame:SetStatusText("Loot, NPCs, Zones, Settings")
    frame:SetLayout("Fill")
    frame:SetWidth(650)
    frame:SetHeight(550)
    frame:EnableResize(true)

    self.GUI = { frame = frame }

    -----------------------------------------------------
    -- TAB GROUP
    -----------------------------------------------------
    local tabs = {
        { text = "Loot",     value = "loot" },
        { text = "Skinning", value = "skin" },
        { text = "NPCs",     value = "npc" },
        { text = "Stats",    value = "stats" },
        { text = "Settings", value = "settings" },
    }

    local tabGroup = AceGUI:Create("TabGroup")
    tabGroup:SetTabs(tabs)
    tabGroup:SetLayout("Flow")
    tabGroup:SelectTab("loot")
    frame:AddChild(tabGroup)

    tabGroup:SetCallback("OnGroupSelected", function(container, _, group)
        container:ReleaseChildren()

        if group == "loot" then
            self:BuildLootTab(container)
        elseif group == "skin" then
            self:BuildSkinTab(container)
        elseif group == "npc" then
            self:BuildNPCTab(container)
        elseif group == "stats" then
            self:BuildStatsTab(container)
        elseif group == "settings" then
            self:BuildSettingsTab(container)
        end
    end)

    self:BuildLootTab(tabGroup)
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
        if npcData.items and next(npcData.items) then
            local header = AceGUI:Create("Heading")
            header:SetText(string.format("%s (ID %d) – %d kills",
                npcData.name or ("NPC "..npcID),
                npcID,
                npcData.kills or 0))
            scroll:AddChild(header)

            for itemID, data in pairs(npcData.items) do
                local name = GetItemInfo(itemID) or ("Item "..itemID)
                local rate = npcData.kills > 0 and (data.count / npcData.kills * 100) or 0

                local label = AceGUI:Create("Label")
                label:SetText(string.format("• %s x%d (%.1f%%)", name, data.count, rate))
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
        if npcData.skinning and next(npcData.skinning) then
            local header = AceGUI:Create("Heading")
            header:SetText(string.format("%s (ID %d) – Skinning",
                npcData.name or ("NPC "..npcID), npcID))
            scroll:AddChild(header)

            for itemID, data in pairs(npcData.skinning) do
                local name = GetItemInfo(itemID) or ("Item "..itemID)

                local label = AceGUI:Create("Label")
                label:SetText(string.format("• %s x%d", name, data.count))
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
-- STATS TAB
---------------------------------------------------------
function MobLootTracker:BuildStatsTab(container)
    local db = self:GetDB()

    local totalKills = 0
    local totalItems = 0

    for _, npcData in pairs(db) do
        totalKills = totalKills + (npcData.kills or 0)
        for _, data in pairs(npcData.items or {}) do
            totalItems = totalItems + (data.count or 0)
        end
    end

    local label = AceGUI:Create("Label")
    label:SetText(string.format(
        "Total kills: %d\nTotal items looted: %d",
        totalKills, totalItems
    ))
    label:SetFullWidth(true)
    container:AddChild(label)
end

---------------------------------------------------------
-- SETTINGS TAB (FULL IN-GUI SETTINGS MENU)
---------------------------------------------------------
function MobLootTracker:BuildSettingsTab(container)
    local db = MobLootTrackerDB

    -----------------------------------------------------
    -- Minimap Icon Toggle
    -----------------------------------------------------
    local minimapToggle = AceGUI:Create("CheckBox")
    minimapToggle:SetLabel("Show Minimap Icon")
    minimapToggle:SetValue(not db.minimap.hide)
    minimapToggle:SetCallback("OnValueChanged", function(_, _, val)
        db.minimap.hide = not val
        local icon = LibStub("LibDBIcon-1.0")
        if val then icon:Show("MobLootTracker") else icon:Hide("MobLootTracker") end
    end)
    container:AddChild(minimapToggle)

    -----------------------------------------------------
    -- Reset Minimap Position
    -----------------------------------------------------
    local resetButton = AceGUI:Create("Button")
    resetButton:SetText("Reset Minimap Position")
    resetButton:SetCallback("OnClick", function()
        db.minimap.minimapPos = 220
        LibStub("LibDBIcon-1.0"):Refresh("MobLootTracker", db.minimap)
        MobLootTracker:Print("Minimap icon position reset.")
    end)
    container:AddChild(resetButton)

    -----------------------------------------------------
    -- Debug Mode Toggle
    -----------------------------------------------------
    local debugToggle = AceGUI:Create("CheckBox")
    debugToggle:SetLabel("Enable Debug Mode")
    debugToggle:SetValue(self:GetSetting("debugMode"))
    debugToggle:SetCallback("OnValueChanged", function(_, _, val)
        self:SetSetting("debugMode", val)
    end)
    container:AddChild(debugToggle)

    -----------------------------------------------------
    -- Show NPC ID Toggle
    -----------------------------------------------------
    local npcIDToggle = AceGUI:Create("CheckBox")
    npcIDToggle:SetLabel("Show NPC ID in Tooltip")
    npcIDToggle:SetValue(self:GetSetting("showNPCID"))
    npcIDToggle:SetCallback("OnValueChanged", function(_, _, val)
        self:SetSetting("showNPCID", val)
    end)
    container:AddChild(npcIDToggle)

    -----------------------------------------------------
    -- Reset Database Button
    -----------------------------------------------------
    local resetDB = AceGUI:Create("Button")
    resetDB:SetText("Reset All Loot Data")
    resetDB:SetCallback("OnClick", function()
        MobLootTrackerDB.global.MobLootDB = {}
        MobLootTracker:Print("All loot data has been reset.")
    end)
    container:AddChild(resetDB)
end
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
