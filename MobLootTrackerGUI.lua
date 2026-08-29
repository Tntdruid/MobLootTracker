-- MobLootTracker_GUI.lua – AceGUI GUI with loot + leather-skinning, colors + drop-rates

local AceGUI = LibStub("AceGUI-3.0")

local LeatherItems = {
    [4231] = true, [4232] = true, [4233] = true,
    [4234] = true, [4235] = true, [4304] = true,
    [8167] = true, [8170] = true, [8171] = true,
}

local function NPCHasLeatherSkinning(npcData)
    if not npcData or not npcData.skinning then return false end
    for itemID in pairs(npcData.skinning) do
        if LeatherItems[itemID] then return true end
    end
    return false
end

local function GetDropRate(npcData, itemID, isSkinning)
    local total = npcData.kills or 1
    local count = 0

    if isSkinning then
        count = npcData.skinning[itemID] and npcData.skinning[itemID].count or 0
    else
        count = npcData.items[itemID] and npcData.items[itemID].count or 0
    end

    return (count / total) * 100
end

local function GetItemColor(itemID)
    local _, _, quality = GetItemInfo(itemID)
    if not quality then return "|cffffffff" end

    local colors = {
        [0] = "|cffffffff",
        [1] = "|cffffffff",
        [2] = "|cff1eff00",
        [3] = "|cff0070dd",
        [4] = "|cffa335ee",
        [5] = "|cffff8000",
    }

    return colors[quality] or "|cffffffff"
end

function MobLootTracker_ShowGUI(npcID)
    local npcData = MobLootDB[npcID]
    if not npcData then
        print("MobLootTracker: Ingen data for NPCID", npcID)
        return
    end

    local frame = AceGUI:Create("Frame")
    frame:SetTitle("MobLootTracker – NPC " .. npcID)
    frame:SetStatusText("Kills: " .. (npcData.kills or 0))
    frame:SetLayout("Fill")
    frame:SetWidth(450)
    frame:SetHeight(400)

    local tabs = {
        {text = "Loot", value = "loot"},
    }

    if NPCHasLeatherSkinning(npcData) then
        table.insert(tabs, {text = "Skinning", value = "skinning"})
    end

    local tabGroup = AceGUI:Create("TabGroup")
    tabGroup:SetTabs(tabs)
    tabGroup:SetLayout("Flow")
    frame:AddChild(tabGroup)

    local function DrawLootTab(container)
        container:ReleaseChildren()

        local header = AceGUI:Create("Heading")
        header:SetText("Loot Drops")
        container:AddChild(header)

        for itemID, data in pairs(npcData.items) do
            local name = GetItemInfo(itemID)
            local count = data.count or 0
            local rate = GetDropRate(npcData, itemID, false)
            local color = GetItemColor(itemID)

            local label = AceGUI:Create("Label")
            label:SetText(color .. (name or ("Item "..itemID)) ..
                          "|r x" .. count .. " (" .. string.format("%.1f", rate) .. "%)")
            container:AddChild(label)
        end
    end

    local function DrawSkinningTab(container)
        container:ReleaseChildren()

        local header = AceGUI:Create("Heading")
        header:SetText("Skinning Drops (Leather Only)")
        container:AddChild(header)

        for itemID, data in pairs(npcData.skinning) do
            if LeatherItems[itemID] then
                local name = GetItemInfo(itemID)
                local count = data.count or 0
                local rate = GetDropRate(npcData, itemID, true)
                local color = GetItemColor(itemID)

                local label = AceGUI:Create("Label")
                label:SetText(color .. (name or ("Item "..itemID)) ..
                              "|r x" .. count .. " (" .. string.format("%.1f", rate) .. "%)")
                container:AddChild(label)
            end
        end
    end

    tabGroup:SetCallback("OnGroupSelected", function(self, event, group)
        if group == "loot" then
            DrawLootTab(self)
        elseif group == "skinning" then
            DrawSkinningTab(self)
        end
    end)

    tabGroup:SelectTab("loot")
end

SLASH_MLTGUI1 = "/mltgui"
SlashCmdList["MLTGUI"] = function(msg)
    local npcID = tonumber(msg)
    if npcID then
        MobLootTracker_ShowGUI(npcID)
    else
        print("Brug: /mltgui <npcID>")
    end
end

print("MobLootTracker GUI loaded")
-- MobLootTrackerGUI.lua – fuld GUI til MobLootTracker
-- Kræver: MobLootDB fra MobLootTracker.lua

local MLT_GUI = {}
local guiFrame = nil
local currentNPCID = nil

---------------------------------------------------------
-- Helper: get mob name from NPCID (via tooltip / cache)
---------------------------------------------------------
local function GetMobNameFromNPCID(npcID)
    return "NPC "..tostring(npcID)
end

---------------------------------------------------------
-- Helper: drop-rate beregning
---------------------------------------------------------
local function GetDropRate(npcData, itemID, isSkinning)
    if not npcData then return 0 end
    local kills = npcData.kills or 0
    if kills <= 0 then return 0 end

    local tbl = isSkinning and npcData.skinning or npcData.items
    if not tbl or not tbl[itemID] then return 0 end

    local count = tbl[itemID].count or 0
    return (count / kills) * 100
end

---------------------------------------------------------
-- GUI: hovedvindue
---------------------------------------------------------
local function CreateMainFrame()
    if guiFrame then return end

    guiFrame = CreateFrame("Frame", "MobLootTrackerMainFrame", UIParent)
    guiFrame:SetSize(500, 400)
    guiFrame:SetPoint("CENTER")
    guiFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    guiFrame:SetMovable(true)
    guiFrame:EnableMouse(true)
    guiFrame:RegisterForDrag("LeftButton")
    guiFrame:SetScript("OnDragStart", guiFrame.StartMoving)
    guiFrame:SetScript("OnDragStop", guiFrame.StopMovingOrSizing)

    local title = guiFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText("MobLootTracker")

    local close = CreateFrame("Button", nil, guiFrame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)

    -- Tabs
    local lootTab = CreateFrame("Button", nil, guiFrame, "OptionsFrameTabButtonTemplate")
    lootTab:SetID(1)
    lootTab:SetText("Loot")
    lootTab:SetPoint("TOPLEFT", guiFrame, "BOTTOMLEFT", 10, 7)

    local skinTab = CreateFrame("Button", nil, guiFrame, "OptionsFrameTabButtonTemplate")
    skinTab:SetID(2)
    skinTab:SetText("Skinning")
    skinTab:SetPoint("LEFT", lootTab, "RIGHT", 4, 0)

    local statsTab = CreateFrame("Button", nil, guiFrame, "OptionsFrameTabButtonTemplate")
    statsTab:SetID(3)
    statsTab:SetText("Stats")
    statsTab:SetPoint("LEFT", skinTab, "RIGHT", 4, 0)

    PanelTemplates_SetNumTabs(guiFrame, 3)
    PanelTemplates_SetTab(guiFrame, 1)

    guiFrame.lootTab = lootTab
    guiFrame.skinTab = skinTab
    guiFrame.statsTab = statsTab

    lootTab:SetScript("OnClick", function()
        PanelTemplates_SetTab(guiFrame, 1)
        MLT_GUI.ShowLootTab()
    end)

    skinTab:SetScript("OnClick", function()
        PanelTemplates_SetTab(guiFrame, 2)
        MLT_GUI.ShowSkinningTab()
    end)

    statsTab:SetScript("OnClick", function()
        PanelTemplates_SetTab(guiFrame, 3)
        MLT_GUI.ShowStatsTab()
    end)

    -- Content frame
    local content = CreateFrame("Frame", nil, guiFrame)
    content:SetPoint("TOPLEFT", 15, -40)
    content:SetPoint("BOTTOMRIGHT", -15, 15)
    guiFrame.content = content
end

---------------------------------------------------------
-- GUI: loot-liste
---------------------------------------------------------
function MLT_GUI.ShowLootTab()
    if not guiFrame then return end
    local content = guiFrame.content
    content:Hide()
    content:Show()

    -- Clear previous children
    for _, child in ipairs({content:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end

    local npcID = currentNPCID
    local npcData = npcID and MobLootDB[npcID]
    local mobName = npcID and GetMobNameFromNPCID(npcID) or "Ingen NPC valgt"

    local header = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetText("Loot – "..mobName)

    local scrollFrame = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", -26, 0)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(1, 1)
    scrollFrame:SetScrollChild(scrollChild)

    local y = -5

    if npcData and npcData.items and next(npcData.items) ~= nil then
        for itemID, data in pairs(npcData.items) do
            local name = GetItemInfo(itemID)
            local count = data.count or 0
            local rate = GetDropRate(npcData, itemID, false)

            local line = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            line:SetPoint("TOPLEFT", 0, y)
            line:SetText(string.format("%s x%d (%.1f%%)", name or ("Item "..itemID), count, rate))

            y = y - 16
        end
    else
        local line = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        line:SetPoint("TOPLEFT", 0, y)
        line:SetText("Ingen loot registreret.")
    end
end

---------------------------------------------------------
-- GUI: skinning-liste
---------------------------------------------------------
function MLT_GUI.ShowSkinningTab()
    if not guiFrame then return end
    local content = guiFrame.content
    content:Hide()
    content:Show()

    for _, child in ipairs({content:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end

    local npcID = currentNPCID
    local npcData = npcID and MobLootDB[npcID]
    local mobName = npcID and GetMobNameFromNPCID(npcID) or "Ingen NPC valgt"

    local header = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetText("Skinning – "..mobName)

    local scrollFrame = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, -30)
    scrollFrame:SetPoint("BOTTOMRIGHT", -26, 0)

    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(1, 1)
    scrollFrame:SetScrollChild(scrollChild)

    local y = -5

    if npcData and npcData.skinning and next(npcData.skinning) ~= nil then
        for itemID, data in pairs(npcData.skinning) do
            local name = GetItemInfo(itemID)
            local count = data.count or 0
            local rate = GetDropRate(npcData, itemID, true)

            local line = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            line:SetPoint("TOPLEFT", 0, y)
            line:SetText(string.format("%s x%d (%.1f%%)", name or ("Item "..itemID), count, rate))

            y = y - 16
        end
    else
        local line = scrollChild:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        line:SetPoint("TOPLEFT", 0, y)
        line:SetText("Ingen skinning-loot registreret.")
    end
end

---------------------------------------------------------
-- GUI: stats-tab (kills, total items)
---------------------------------------------------------
function MLT_GUI.ShowStatsTab()
    if not guiFrame then return end
    local content = guiFrame.content
    content:Hide()
    content:Show()

    for _, child in ipairs({content:GetChildren()}) do
        child:Hide()
        child:SetParent(nil)
    end

    local npcID = currentNPCID
    local npcData = npcID and MobLootDB[npcID]
    local mobName = npcID and GetMobNameFromNPCID(npcID) or "Ingen NPC valgt"

    local header = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    header:SetPoint("TOPLEFT", 0, 0)
    header:SetText("Stats – "..mobName)

    local killsLine = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    killsLine:SetPoint("TOPLEFT", 0, -30)
    local kills = npcData and npcData.kills or 0
    killsLine:SetText("Kills: "..kills)

    local itemsLine = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    itemsLine:SetPoint("TOPLEFT", 0, -50)
    local totalItems = 0
    if npcData and npcData.items then
        for _, data in pairs(npcData.items) do
            totalItems = totalItems + (data.count or 0)
        end
    end
    itemsLine:SetText("Total loot items: "..totalItems)

    local skinLine = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    skinLine:SetPoint("TOPLEFT", 0, -70)
    local totalSkin = 0
    if npcData and npcData.skinning then
        for _, data in pairs(npcData.skinning) do
            totalSkin = totalSkin + (data.count or 0)
        end
    end
    skinLine:SetText("Total skinning items: "..totalSkin)
end

---------------------------------------------------------
-- Slash command: åbner GUI
---------------------------------------------------------
SLASH_MLTGUI1 = "/mltgui"
SlashCmdList["MLTGUI"] = function(msg)
    if not guiFrame then
        CreateMainFrame()
    end

    local guid = UnitGUID("mouseover")
    local npcID = guid and ResolveNPCIDFromGUID(guid)
    if npcID and MobLootDB[npcID] then
        currentNPCID = npcID
    end

    guiFrame:Show()
    MLT_GUI.ShowLootTab()
end

---------------------------------------------------------
-- Tooltip-hook: vis loot + skinning
---------------------------------------------------------
local function MobLootTracker_AddTooltip(tooltip, unit)
    if not unit then return end
    local guid = UnitGUID(unit)
    if not guid then return end

    local npcID = ResolveNPCIDFromGUID(guid)
    if not npcID then return end

    local npcData = MobLootDB[npcID]
    if not npcData then return end

    tooltip:AddLine(" ")
    tooltip:AddLine("MobLootTracker: Known drops", 0.2, 1, 0.2)

    if npcData.items and next(npcData.items) ~= nil then
        for itemID, data in pairs(npcData.items) do
            local name = GetItemInfo(itemID)
            local count = data.count or 0
            local rate = GetDropRate(npcData, itemID, false)
            tooltip:AddLine(string.format("  %s x%d (%.1f%%)", name or ("Item "..itemID), count, rate), 1, 1, 1)
        end
    else
        tooltip:AddLine("  (no loot)", 1, 1, 1)
    end

    tooltip:AddLine("Skinning drops:", 0.2, 0.8, 1)
    if npcData.skinning and next(npcData.skinning) ~= nil then
        for itemID, data in pairs(npcData.skinning) do
            local name = GetItemInfo(itemID)
            local count = data.count or 0
            local rate = GetDropRate(npcData, itemID, true)
            tooltip:AddLine(string.format("  %s x%d (%.1f%%)", name or ("Item "..itemID), count, rate), 1, 1, 1)
        end
    else
        tooltip:AddLine("  (no skinning loot)", 1, 1, 1)
    end
end

GameTooltip:HookScript("OnTooltipSetUnit", function(self)
    local _, unit = self:GetUnit()
    if unit then
        MobLootTracker_AddTooltip(self, unit)
    end
end)

print("MobLootTracker GUI (Loot/Skinning/Stats + tooltip) loaded")
