-- MobLootTrackerGUI.lua – Ny GUI med leather-integration

local AceGUI = LibStub("AceGUI-3.0")

---------------------------------------------------------
-- SAFE DB ACCESS
---------------------------------------------------------
local function SafeDB()
    if MobLootTracker.db and MobLootTracker.db.global and MobLootTracker.db.global.MobLootDB then
        return MobLootTracker.db.global.MobLootDB
    end
    return MobLootTrackerDB.global.MobLootDB
end

---------------------------------------------------------
-- LEATHER LIST (samme som core)
---------------------------------------------------------
local LEATHER_ITEMS = {
    [2318]=true,[2319]=true,[4231]=true,[4232]=true,[4233]=true,[4234]=true,[4235]=true,
    [4461]=true,[6470]=true,[6471]=true,[7286]=true,[7287]=true,[7392]=true,[8167]=true,
    [8169]=true,[8170]=true,[8171]=true,
    [21887]=true,[25649]=true,[25700]=true,[25707]=true,[25708]=true,[25703]=true,[25702]=true,
    [23248]=true,[25421]=true,[25420]=true,
    [33568]=true,[33567]=true,[38557]=true,[38558]=true,[38561]=true,[44128]=true,
}

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
    frame:SetStatusText("Loot, Skinning, NPCs, Stats, Settings")
    frame:SetLayout("Fill")
    frame:SetWidth(650)
    frame:SetHeight(550)
    frame:EnableResize(true)

    self.GUI = { frame = frame }

    local tabs = {
        { text="Loot",     value="loot" },
        { text="Skinning", value="skin" },
        { text="NPCs",     value="npc" },
        { text="Stats",    value="stats" },
        { text="Settings", value="settings" },
    }

    local tabGroup = AceGUI:Create("TabGroup")
    tabGroup:SetTabs(tabs)
    tabGroup:SetLayout("Flow")
    tabGroup:SelectTab("loot")
    frame:AddChild(tabGroup)

    tabGroup:SetCallback("OnGroupSelected", function(container, _, group)
        container:ReleaseChildren()
        if group=="loot" then self:BuildLootTab(container)
        elseif group=="skin" then self:BuildSkinTab(container)
        elseif group=="npc" then self:BuildNPCTab(container)
        elseif group=="stats" then self:BuildStatsTab(container)
        elseif group=="settings" then self:BuildSettingsTab(container)
        end
    end)

    self:BuildLootTab(tabGroup)
end

---------------------------------------------------------
-- LOOT TAB
---------------------------------------------------------
function MobLootTracker:BuildLootTab(container)
    local db = SafeDB()
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    container:AddChild(scroll)

    for npcID, npcData in pairs(db) do
        if npcData.items and next(npcData.items) then
            local header = AceGUI:Create("Heading")
            header:SetText(string.format("%s (ID %d) – Loot", npcData.name or ("NPC "..npcID), npcID))
            scroll:AddChild(header)

            for itemID, data in pairs(npcData.items) do
                local name   = GetItemInfo(itemID) or ("Item "..itemID)
                local rarity = select(3, GetItemInfo(itemID)) or 1
                local color  = select(4, GetItemQualityColor(rarity))
                local rate   = npcData.kills > 0 and (data.count / npcData.kills * 100) or 0

                local label = AceGUI:Create("Label")
                label:SetText(string.format("• %s%s|r x%d (%.1f%%)", color, name, data.count, rate))
                label:SetFullWidth(true)
                scroll:AddChild(label)
            end
        end
    end
end

---------------------------------------------------------
-- SKINNING TAB (Leather Integration)
---------------------------------------------------------
function MobLootTracker:BuildSkinTab(container)
    local db = SafeDB()
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    container:AddChild(scroll)

    for npcID, npcData in pairs(db) do
        if npcData.skinning and next(npcData.skinning) then
            local header = AceGUI:Create("Heading")
            header:SetText(string.format("%s (ID %d) – Skinning Loot", npcData.name or ("NPC "..npcID), npcID))
            scroll:AddChild(header)

            for itemID, data in pairs(npcData.skinning) do
                if LEATHER_ITEMS[itemID] then
                    local name   = GetItemInfo(itemID) or ("Item "..itemID)
                    local rarity = select(3, GetItemInfo(itemID)) or 1
                    local color  = select(4, GetItemQualityColor(rarity))

                    local label = AceGUI:Create("Label")
                    label:SetText(string.format("• %s%s|r x%d", color, name, data.count))
                    label:SetFullWidth(true)
                    scroll:AddChild(label)
                end
            end
        end
    end
end

---------------------------------------------------------
-- NPC TAB
---------------------------------------------------------
function MobLootTracker:BuildNPCTab(container)
    local db = SafeDB()
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    container:AddChild(scroll)

    for npcID, npcData in pairs(db) do
        local zones = ""
        for z in pairs(npcData.zones or {}) do zones = zones..z..", " end
        zones = zones:gsub(", $","")

        local label = AceGUI:Create("Label")
        label:SetText(string.format("|cffffd200%s|r (ID %d)\nKills: %d\nZones: %s",
            npcData.name or ("NPC "..npcID),
            npcID,
            npcData.kills or 0,
            zones ~= "" and zones or "Unknown"))
        label:SetFullWidth(true)
        scroll:AddChild(label)
    end
end

---------------------------------------------------------
-- STATS TAB
---------------------------------------------------------
function MobLootTracker:BuildStatsTab(container)
    local db = SafeDB()
    local totalKills, totalItems, totalSkin = 0, 0, 0

    for _, npcData in pairs(db) do
        totalKills = totalKills + (npcData.kills or 0)

        for itemID, data in pairs(npcData.items or {}) do
            totalItems = totalItems + (data.count or 0)
        end

        for itemID, data in pairs(npcData.skinning or {}) do
            if LEATHER_ITEMS[itemID] then
                totalSkin = totalSkin + (data.count or 0)
            end
        end
    end

    local label = AceGUI:Create("Label")
    label:SetText(string.format(
        "Total kills: %d\nTotal items looted: %d\nTotal leather items: %d",
        totalKills, totalItems, totalSkin))
    label:SetFullWidth(true)
    container:AddChild(label)
end

---------------------------------------------------------
-- SETTINGS TAB
---------------------------------------------------------
function MobLootTracker:BuildSettingsTab(container)
    local db = MobLootTrackerDB

    local minimapToggle = AceGUI:Create("CheckBox")
    minimapToggle:SetLabel("Show Minimap Icon")
    minimapToggle:SetValue(not db.minimap.hide)
    minimapToggle:SetCallback("OnValueChanged", function(_, _, val)
        db.minimap.hide = not val
        local icon = LibStub("LibDBIcon-1.0")
        if val then icon:Show("MobLootTracker") else icon:Hide("MobLootTracker") end
    end)
    container:AddChild(minimapToggle)

    local resetButton = AceGUI:Create("Button")
    resetButton:SetText("Reset Minimap Position")
    resetButton:SetCallback("OnClick", function()
        db.minimap.minimapPos = 220
        LibStub("LibDBIcon-1.0"):Refresh("MobLootTracker", db.minimap)
        MobLootTracker:Print("Minimap icon position reset.")
    end)
    container:AddChild(resetButton)

    local debugToggle = AceGUI:Create("CheckBox")
    debugToggle:SetLabel("Enable Debug Mode")
    debugToggle:SetValue(MobLootTracker:GetSetting("debugMode"))
    debugToggle:SetCallback("OnValueChanged", function(_, _, val)
        MobLootTracker:SetSetting("debugMode", val)
    end)
    container:AddChild(debugToggle)

    local skinToggle = AceGUI:Create("CheckBox")
    skinToggle:SetLabel("Enable Skinning Tracking")
    skinToggle:SetValue(MobLootTracker:GetSetting("enableSkinning"))
    skinToggle:SetCallback("OnValueChanged", function(_, _, val)
        MobLootTracker:SetSetting("enableSkinning", val)
    end)
    container:AddChild(skinToggle)

    local resetDB = AceGUI:Create("Button")
    resetDB:SetText("Reset All Loot Data")
    resetDB:SetCallback("OnClick", function()
        MobLootTrackerDB.global.MobLootDB = {}
        MobLootTracker:Print("All loot data has been reset.")
    end)
    container:AddChild(resetDB)
end
