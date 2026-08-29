-- MobLootTrackerGUI.lua – AceGUI tabs for Loot / Skinning / Stats (AzerothCore/WotLK)

local MobLootTracker = LibStub("AceAddon-3.0"):GetAddon("MobLootTracker")
local AceGUI = LibStub("AceGUI-3.0")

---------------------------------------------------------
-- Main GUI frame
---------------------------------------------------------
local mainFrame = nil

---------------------------------------------------------
-- Public API: Show GUI for NPCID
---------------------------------------------------------
function MobLootTracker:ShowGUI(npcID)
    local db = self:GetDB()
    local npcData = db[npcID]

    if not npcData then
        self:Print("Ingen data for NPCID:", npcID)
        return
    end

    -- Close old frame
    if mainFrame then
        mainFrame:Release()
        mainFrame = nil
    end

    -----------------------------------------------------
    -- Frame
    -----------------------------------------------------
    mainFrame = AceGUI:Create("Frame")
    mainFrame:SetTitle("MobLootTracker – NPC " .. npcID)
    mainFrame:SetStatusText("Kills: " .. (npcData.kills or 0))
    mainFrame:SetLayout("Fill")
    mainFrame:SetWidth(550)
    mainFrame:SetHeight(550)

    -----------------------------------------------------
    -- TabGroup
    -----------------------------------------------------
    local tabs = {
        { text = "Loot",    value = "loot" },
        { text = "Skinning", value = "skinning" },
        { text = "Stats",   value = "stats" },
    }

    local tabGroup = AceGUI:Create("TabGroup")
    tabGroup:SetTabs(tabs)
    tabGroup:SetLayout("Flow")
    mainFrame:AddChild(tabGroup)

    -----------------------------------------------------
    -- Loot Tab
    -----------------------------------------------------
    local function DrawLootTab(container)
        container:ReleaseChildren()

        local header = AceGUI:Create("Heading")
        header:SetText("Loot Drops")
        container:AddChild(header)

        if not next(npcData.items) then
            local empty = AceGUI:Create("Label")
            empty:SetText("Ingen loot registreret.")
            container:AddChild(empty)
            return
        end

        for itemID, data in pairs(npcData.items) do
            local name = GetItemInfo(itemID) or ("Item " .. itemID)
            local count = data.count or 0
            local rate = (count / (npcData.kills or 1)) * 100

            local color = "|cffffffff"
            if MobLootTracker:GetSetting("showItemColors") then
                local _, _, quality = GetItemInfo(itemID)
                if quality == 2 then color = "|cff1eff00"
                elseif quality == 3 then color = "|cff0070dd"
                elseif quality == 4 then color = "|cffa335ee"
                elseif quality == 5 then color = "|cffff8000"
                end
            end

            local label = AceGUI:Create("Label")
            label:SetText(string.format(
                "%s%s|r x%d (%.1f%%)",
                color, name, count, rate
            ))
            container:AddChild(label)
        end
    end

    -----------------------------------------------------
    -- Skinning Tab
    -----------------------------------------------------
    local function DrawSkinningTab(container)
        container:ReleaseChildren()

        local header = AceGUI:Create("Heading")
        header:SetText("Skinning Drops")
        container:AddChild(header)

        if not next(npcData.skinning) then
            local empty = AceGUI:Create("Label")
            empty:SetText("Ingen skinning registreret.")
            container:AddChild(empty)
            return
        end

        local totalSkin = 0
        for _, d in pairs(npcData.skinning) do totalSkin = totalSkin + (d.count or 0) end

        for itemID, data in pairs(npcData.skinning) do
            local name = GetItemInfo(itemID) or ("Item " .. itemID)
            local count = data.count or 0
            local rate = totalSkin > 0 and (count / totalSkin * 100) or 0

            local color = "|cffffffff"
            if MobLootTracker:GetSetting("showItemColors") then
                local _, _, quality = GetItemInfo(itemID)
                if quality == 2 then color = "|cff1eff00"
                elseif quality == 3 then color = "|cff0070dd"
                elseif quality == 4 then color = "|cffa335ee"
                elseif quality == 5 then color = "|cffff8000"
                end
            end

            local label = AceGUI:Create("Label")
            label:SetText(string.format(
                "%s%s|r x%d (%.1f%%)",
                color, name, count, rate
            ))
            container:AddChild(label)
        end
    end

    -----------------------------------------------------
    -- Stats Tab
    -----------------------------------------------------
    local function DrawStatsTab(container)
        container:ReleaseChildren()

        local header = AceGUI:Create("Heading")
        header:SetText("Statistik")
        container:AddChild(header)

        local totalLoot = 0
        local totalSkin = 0

        for _, d in pairs(npcData.items) do totalLoot = totalLoot + (d.count or 0) end
        for _, d in pairs(npcData.skinning) do totalSkin = totalSkin + (d.count or 0) end

        local stats = AceGUI:Create("Label")
        stats:SetText(string.format(
            "Kills: %d\nLoot items: %d\nSkinning items: %d",
            npcData.kills or 0,
            totalLoot,
            totalSkin
        ))
        container:AddChild(stats)
    end

    -----------------------------------------------------
    -- Tab switch handler
    -----------------------------------------------------
    tabGroup:SetCallback("OnGroupSelected", function(self, event, group)
        if group == "loot" then
            DrawLootTab(self)
        elseif group == "skinning" then
            DrawSkinningTab(self)
        elseif group == "stats" then
            DrawStatsTab(self)
        end
    end)

    tabGroup:SelectTab("loot")
end
