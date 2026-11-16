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
-- Skinning target materials are defined in the core addon and reused here.
---------------------------------------------------------

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

    self.GUI = { frame = frame }
    frame:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
        self.GUI = nil
    end)

    local tabs = {
        { text="Loot",     value="loot" },
        { text="Skinning", value="skin" },
        { text="Quest",    value="quest" },
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
        elseif group=="quest" then self:BuildQuestTab(container)
        elseif group=="npc" then self:BuildNPCTab(container)
        elseif group=="stats" then self:BuildStatsTab(container)
        elseif group=="settings" then self:BuildSettingsTab(container)
        end
    end)

    self:BuildLootTab(tabGroup)
end

---------------------------------------------------------
-- QUEST TAB
---------------------------------------------------------
function MobLootTracker:BuildQuestTab(container)
    local db = SafeDB()
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    container:AddChild(scroll)

    for npcID, npcData in pairs(db) do
        if npcData.quest and next(npcData.quest) then
            local header = AceGUI:Create("Heading")
            header:SetText(string.format("%s (ID %d) - Quest items", npcData.name or ("NPC "..npcID), npcID))
            scroll:AddChild(header)

            for itemID, data in pairs(npcData.quest) do
                local name = GetItemInfo(itemID) or ("Item "..itemID)
                local rarity = select(3, GetItemInfo(itemID)) or 1
                local color = select(4, GetItemQualityColor(rarity))
                local rate = npcData.kills > 0 and (data.count / npcData.kills * 100) or 0

                local label = AceGUI:Create("Label")
                label:SetText(string.format("- %s%s|r x%d (%.1f%%)", color, name, data.count, rate))
                label:SetFullWidth(true)
                scroll:AddChild(label)
            end
        end
    end
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
                if MobLootTracker:IsSkinningItem(itemID) then
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
end

---------------------------------------------------------
-- NPC TAB
---------------------------------------------------------
local function GetNPCSummary(npcData)
    local lootCount = 0
    local skinCount = 0
    local questCount = 0

    for _, itemData in pairs(npcData.items or {}) do
        lootCount = lootCount + (itemData.count or 0)
    end

    for _, itemData in pairs(npcData.skinning or {}) do
        skinCount = skinCount + (itemData.count or 0)
    end

    for _, itemData in pairs(npcData.quest or {}) do
        questCount = questCount + (itemData.count or 0)
    end

    local kills = npcData.kills or 0
    local totalDrops = lootCount + skinCount + questCount

    return {
        kills = kills,
        loot = lootCount,
        skinning = skinCount,
        quest = questCount,
        totalDrops = totalDrops,
        money = npcData.money or 0,
        lootRate = kills > 0 and (lootCount / kills * 100) or 0,
        skinRate = kills > 0 and (skinCount / kills * 100) or 0,
        questRate = kills > 0 and (questCount / kills * 100) or 0,
        totalRate = kills > 0 and (totalDrops / kills * 100) or 0,
    }
end

local function GetTopDropItem(npcData)
    local bestItemID = nil
    local bestCount = 0
    local combined = {}

    for itemID, itemData in pairs(npcData.items or {}) do
        combined[itemID] = (combined[itemID] or 0) + (itemData.count or 0)
    end
    for itemID, itemData in pairs(npcData.skinning or {}) do
        combined[itemID] = (combined[itemID] or 0) + (itemData.count or 0)
    end
    for itemID, itemData in pairs(npcData.quest or {}) do
        combined[itemID] = (combined[itemID] or 0) + (itemData.count or 0)
    end

    for itemID, count in pairs(combined) do
        if count > bestCount then
            bestCount = count
            bestItemID = itemID
        end
    end

    if not bestItemID then
        return "None", 0, 0
    end

    local summary = GetNPCSummary(npcData)
    local bestName = GetItemInfo(bestItemID) or ("Item " .. bestItemID)
    local bestRate = summary.kills > 0 and ((bestCount / summary.kills) * 100) or 0
    return bestName, bestCount, bestRate
end

local function ParsePositiveInteger(value)
    local number = tonumber(value)
    if not number then
        return nil
    end

    number = math.floor(number)
    return number > 0 and number or nil
end

local function GetSortedItemEntries(entries)
    local itemList = {}
    for itemID, itemData in pairs(entries or {}) do
        table.insert(itemList, { id = tonumber(itemID), data = itemData })
    end

    table.sort(itemList, function(a, b)
        local aName = GetItemInfo(a.id) or ("Item " .. tostring(a.id))
        local bName = GetItemInfo(b.id) or ("Item " .. tostring(b.id))
        if aName ~= bName then
            return aName < bName
        end
        return a.id < b.id
    end)

    return itemList
end

local function AddEditorRow(container, npcID, category, itemID, itemData, refresh)
    local row = AceGUI:Create("SimpleGroup")
    row:SetLayout("Flow")
    row:SetFullWidth(true)
    container:AddChild(row)

    local itemLabel = AceGUI:Create("Label")
    itemLabel:SetText(string.format("%s (%d)", GetItemInfo(itemID) or ("Item " .. itemID), itemID))
    itemLabel:SetWidth(250)
    row:AddChild(itemLabel)

    local countBox = AceGUI:Create("EditBox")
    countBox:SetLabel("Antal")
    countBox:SetText(tostring(itemData.count or 0))
    countBox:SetWidth(90)
    countBox:SetCallback("OnEnterPressed", function(_, _, value)
        local count = tonumber(value)
        if count and count >= 0 then
            itemData.count = math.floor(count)
            if itemData.count == 0 then
                SafeDB()[npcID][category][itemID] = nil
            end
            refresh()
        else
            countBox:SetText(tostring(itemData.count or 0))
        end
    end)
    row:AddChild(countBox)

    local removeButton = AceGUI:Create("Button")
    removeButton:SetText("Fjern")
    removeButton:SetWidth(80)
    removeButton:SetCallback("OnClick", function()
        local db = SafeDB()
        if db[npcID] and db[npcID][category] then
            db[npcID][category][itemID] = nil
        end
        refresh()
    end)
    row:AddChild(removeButton)
end

function MobLootTracker:BuildNPCEditor(container, npcID, npcData, onBack)
    local backButton = AceGUI:Create("Button")
    backButton:SetText("Tilbage til NPC'er")
    backButton:SetWidth(140)
    backButton:SetCallback("OnClick", onBack)
    container:AddChild(backButton)

    local deleteArmed = false
    local deleteButton = AceGUI:Create("Button")
    deleteButton:SetText("Slet NPC")
    deleteButton:SetWidth(160)
    deleteButton:SetCallback("OnClick", function()
        if not deleteArmed then
            deleteArmed = true
            deleteButton:SetText("Klik igen for at slette")
            return
        end
        local db = SafeDB()
        db[npcID] = nil
        db[tostring(npcID)] = nil
        self:Print("Deleted saved data for " .. (npcData.name or "NPC") .. " (ID " .. npcID .. ").")
        onBack()
    end)
    container:AddChild(deleteButton)

    local header = AceGUI:Create("Heading")
    header:SetText(string.format("Rediger: %s (ID %d)", npcData.name or ("NPC " .. npcID), npcID))
    header:SetFullWidth(true)
    container:AddChild(header)

    local info = AceGUI:Create("Label")
    local summary = GetNPCSummary(npcData)
    info:SetText(string.format(
        "Kills: %d  |  Loot: %d  |  Skinning: %d  |  Quest: %d\nRet antal, fjern forkerte drops eller tilfoej et item med ID.",
        summary.kills, summary.loot, summary.skinning, summary.quest))
    info:SetFullWidth(true)
    container:AddChild(info)

    local editor = AceGUI:Create("ScrollFrame")
    editor:SetLayout("Flow")
    editor:SetFullWidth(true)
    editor:SetFullHeight(true)
    container:AddChild(editor)

    local refresh = function()
        container:ReleaseChildren()
        self:BuildNPCEditor(container, npcID, npcData, onBack)
    end

    local categories = {
        { key = "items", label = "Loot" },
        { key = "skinning", label = "Skinning" },
        { key = "quest", label = "Quest" },
    }

    for _, category in ipairs(categories) do
        local entries = npcData[category.key] or {}
        if next(entries) then
            local categoryHeader = AceGUI:Create("Heading")
            categoryHeader:SetText(category.label)
            categoryHeader:SetFullWidth(true)
            editor:AddChild(categoryHeader)

            for _, entry in ipairs(GetSortedItemEntries(entries)) do
                AddEditorRow(editor, npcID, category.key, entry.id, entry.data, refresh)
            end
        end
    end

    local addHeader = AceGUI:Create("Heading")
    addHeader:SetText("Tilfoej drop")
    addHeader:SetFullWidth(true)
    editor:AddChild(addHeader)

    local itemIDBox = AceGUI:Create("EditBox")
    itemIDBox:SetLabel("Item-ID")
    itemIDBox:SetWidth(110)
    editor:AddChild(itemIDBox)

    local categoryDropdown = AceGUI:Create("Dropdown")
    categoryDropdown:SetLabel("Kategori")
    categoryDropdown:SetList({ items = "Loot", skinning = "Skinning", quest = "Quest" })
    categoryDropdown:SetValue("items")
    categoryDropdown:SetWidth(120)
    editor:AddChild(categoryDropdown)

    local addCountBox = AceGUI:Create("EditBox")
    addCountBox:SetLabel("Antal")
    addCountBox:SetText("1")
    addCountBox:SetWidth(80)
    editor:AddChild(addCountBox)

    local addButton = AceGUI:Create("Button")
    addButton:SetText("Tilfoej")
    addButton:SetWidth(100)
    addButton:SetCallback("OnClick", function()
        local itemID = ParsePositiveInteger(itemIDBox:GetText())
        local count = ParsePositiveInteger(addCountBox:GetText())
        local category = categoryDropdown:GetValue() or "items"

        if not itemID or not count then
            self:Print("Indtast et gyldigt item-ID og antal.")
            return
        end

        npcData[category] = npcData[category] or {}
        npcData[category][itemID] = npcData[category][itemID] or { count = 0 }
        npcData[category][itemID].count = npcData[category][itemID].count + count
        refresh()
    end)
    editor:AddChild(addButton)
end

-- Search, sort and filters survive opening the editor and switching tabs.
function MobLootTracker:GetNPCBrowserState()
    self.npcBrowserState = self.npcBrowserState or {
        search = "",
        sort = "rate",
        filters = { loot = true, skinning = true, quest = true, empty = true },
    }
    return self.npcBrowserState
end

function MobLootTracker:BuildNPCTab(container)
    local db = SafeDB()
    local state = self:GetNPCBrowserState()
    local filters = state.filters
    local RefreshNPCList

    local overviewHeader = AceGUI:Create("Heading")
    overviewHeader:SetText("NPC overview")
    overviewHeader:SetFullWidth(true)
    container:AddChild(overviewHeader)

    local toolbar = AceGUI:Create("SimpleGroup")
    toolbar:SetLayout("Flow")
    toolbar:SetFullWidth(true)
    container:AddChild(toolbar)

    local searchBox = AceGUI:Create("EditBox")
    searchBox:SetLabel("Sog navn eller ID")
    searchBox:SetWidth(220)
    searchBox:DisableButton(true)
    searchBox:SetText(state.search)
    searchBox:SetCallback("OnTextChanged", function(_, _, value)
        state.search = string.lower(value or "")
        RefreshNPCList()
    end)
    toolbar:AddChild(searchBox)

    local sortDropdown = AceGUI:Create("Dropdown")
    sortDropdown:SetLabel("Sorter efter")
    sortDropdown:SetList({
        rate = "Drop rate",
        kills = "Kills",
        name = "Navn",
        id = "NPC ID",
    })
    sortDropdown:SetValue(state.sort)
    sortDropdown:SetWidth(150)
    sortDropdown:SetCallback("OnValueChanged", function(_, _, value)
        state.sort = value or "rate"
        RefreshNPCList()
    end)
    toolbar:AddChild(sortDropdown)

    local filterGroup = AceGUI:Create("SimpleGroup")
    filterGroup:SetLayout("Flow")
    filterGroup:SetFullWidth(true)
    container:AddChild(filterGroup)

    local function AddFilter(key, label)
        local checkBox = AceGUI:Create("CheckBox")
        checkBox:SetLabel(label)
        checkBox:SetWidth(110)
        checkBox:SetValue(filters[key])
        checkBox:SetCallback("OnValueChanged", function(_, _, val)
            filters[key] = val and true or false
            RefreshNPCList()
        end)
        filterGroup:AddChild(checkBox)
    end
    AddFilter("loot", "Loot")
    AddFilter("skinning", "Skinning")
    AddFilter("quest", "Quest")
    AddFilter("empty", "Uden drops")

    local countLabel = AceGUI:Create("Label")
    countLabel:SetFullWidth(true)
    container:AddChild(countLabel)

    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("List")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    container:AddChild(scroll)

    local function OpenEditor(npcID, npcData)
        container:ReleaseChildren()
        self:BuildNPCEditor(container, npcID, npcData, function()
            container:ReleaseChildren()
            self:BuildNPCTab(container)
        end)
    end

    RefreshNPCList = function()
        scroll:ReleaseChildren()

        local npcList = {}
        local total = 0
        for npcID, npcData in pairs(db) do
            if type(npcData) == "table" then
                total = total + 1
                local hasLoot = next(npcData.items or {}) ~= nil
                local hasSkin = next(npcData.skinning or {}) ~= nil
                local hasQuest = next(npcData.quest or {}) ~= nil
                local visible = (filters.loot and hasLoot)
                    or (filters.skinning and hasSkin)
                    or (filters.quest and hasQuest)
                    or (filters.empty and not hasLoot and not hasSkin and not hasQuest)

                local npcName = npcData.name or ("NPC " .. tostring(npcID))
                local search = state.search
                local searchMatch = search == ""
                    or string.find(string.lower(npcName), search, 1, true)
                    or string.find(tostring(npcID), search, 1, true)

                if visible and searchMatch then
                    npcList[#npcList + 1] = {
                        id = tonumber(npcID) or 0,
                        data = npcData,
                        name = npcName,
                        summary = GetNPCSummary(npcData),
                    }
                end
            end
        end

        local sortMode = state.sort
        table.sort(npcList, function(a, b)
            if sortMode == "name" then
                local aName, bName = string.lower(a.name), string.lower(b.name)
                if aName ~= bName then
                    return aName < bName
                end
            elseif sortMode == "kills" and a.summary.kills ~= b.summary.kills then
                return a.summary.kills > b.summary.kills
            elseif sortMode == "rate" and a.summary.totalRate ~= b.summary.totalRate then
                return a.summary.totalRate > b.summary.totalRate
            end
            return a.id < b.id
        end)

        countLabel:SetText(string.format("Viser %d af %d NPC'er", #npcList, total))

        if #npcList == 0 then
            local emptyLabel = AceGUI:Create("Label")
            emptyLabel:SetText("Ingen NPC'er matcher dine filtre.")
            emptyLabel:SetFullWidth(true)
            scroll:AddChild(emptyLabel)
        end

        for _, entry in ipairs(npcList) do
            local npcID = entry.id
            local npcData = entry.data
            local summary = entry.summary
            local topItemName, topItemCount, topItemRate = GetTopDropItem(npcData)

            local zoneList = {}
            for zone in pairs(npcData.zones or {}) do
                zoneList[#zoneList + 1] = zone
            end
            table.sort(zoneList)
            local zones = #zoneList > 0 and table.concat(zoneList, ", ") or "Unknown"

            local row = AceGUI:Create("SimpleGroup")
            row:SetLayout("Flow")
            row:SetFullWidth(true)

            local label = AceGUI:Create("Label")
            label:SetText(string.format(
                "|cffffd200%s|r (ID %d)  |  Kills: %d  |  Rate: %.1f%%\nLoot: %d (%.1f%%)  |  Skin: %d (%.1f%%)  |  Quest: %d (%.1f%%)\nMoney: %s  |  Top: %s x%d (%.1f%%)\nZone: %s",
                entry.name,
                npcID,
                summary.kills,
                summary.totalRate,
                summary.loot,
                summary.lootRate,
                summary.skinning,
                summary.skinRate,
                summary.quest,
                summary.questRate,
                MobLootTracker:FormatMoney(summary.money),
                topItemName,
                topItemCount,
                topItemRate,
                zones))
            label:SetRelativeWidth(0.78)
            row:AddChild(label)

            local editButton = AceGUI:Create("Button")
            editButton:SetText("Rediger")
            editButton:SetRelativeWidth(0.2)
            editButton:SetCallback("OnClick", function()
                OpenEditor(npcID, npcData)
            end)
            row:AddChild(editButton)
            scroll:AddChild(row)
        end

        scroll:SetScroll(0)
    end

    RefreshNPCList()
end

---------------------------------------------------------
-- STATS TAB
---------------------------------------------------------
function MobLootTracker:BuildStatsTab(container)
    local db = SafeDB()
    local totalKills, totalItems, totalSkin, totalQuest, totalMoney = 0, 0, 0, 0, 0

    for _, npcData in pairs(db) do
        totalKills = totalKills + (npcData.kills or 0)
        totalMoney = totalMoney + (npcData.money or 0)

        for itemID, data in pairs(npcData.items or {}) do
            totalItems = totalItems + (data.count or 0)
        end

        for itemID, data in pairs(npcData.skinning or {}) do
            if MobLootTracker:IsSkinningItem(itemID) then
                totalSkin = totalSkin + (data.count or 0)
            end
        end

        for itemID, data in pairs(npcData.quest or {}) do
            totalQuest = totalQuest + (data.count or 0)
        end
    end

    local summaryHeader = AceGUI:Create("Heading")
    summaryHeader:SetText("Summary")
    container:AddChild(summaryHeader)

    local label = AceGUI:Create("Label")
    label:SetText(string.format(
        "Kills: %d\nLoot: %d\nSkinning: %d\nQuest: %d\nMoney looted: %s",
        totalKills, totalItems, totalSkin, totalQuest, MobLootTracker:FormatMoney(totalMoney)))
    label:SetFullWidth(true)
    container:AddChild(label)

    local topHeader = AceGUI:Create("Heading")
    topHeader:SetText("Top 10 NPCs")
    container:AddChild(topHeader)

    local npcList = {}
    for npcID, npcData in pairs(db) do
        table.insert(npcList, { id = npcID, data = npcData })
    end

    table.sort(npcList, function(a, b)
        local aSummary = GetNPCSummary(a.data)
        local bSummary = GetNPCSummary(b.data)
        if aSummary.totalRate ~= bSummary.totalRate then
            return aSummary.totalRate > bSummary.totalRate
        end
        if aSummary.kills ~= bSummary.kills then
            return aSummary.kills > bSummary.kills
        end
        return a.id < b.id
    end)

    for index = 1, math.min(10, #npcList) do
        local entry = npcList[index]
        local npcID = entry.id
        local npcData = entry.data
        local summary = GetNPCSummary(npcData)
        local topItemName, topItemCount, topItemRate = GetTopDropItem(npcData)

        local line = AceGUI:Create("Label")
        line:SetText(string.format(
            "%d. %s\n   Kills: %d | Rate: %.1f%% | Top: %s x%d (%.1f%%)",
            index,
            npcData.name or ("NPC " .. npcID),
            summary.kills,
            summary.totalRate,
            topItemName,
            topItemCount,
            topItemRate))
        line:SetFullWidth(true)
        container:AddChild(line)
    end
end

---------------------------------------------------------
-- SETTINGS TAB
---------------------------------------------------------
function MobLootTracker:BuildSettingsTab(container)
    local db = MobLootTracker.db
    local minimapDB = db.global.minimap

    local minimapToggle = AceGUI:Create("CheckBox")
    minimapToggle:SetLabel("Show Minimap Icon")
    minimapToggle:SetValue(not minimapDB.hide)
    minimapToggle:SetCallback("OnValueChanged", function(_, _, val)
        minimapDB.hide = not val
        local icon = LibStub("LibDBIcon-1.0")
        if val then icon:Show("MobLootTracker") else icon:Hide("MobLootTracker") end
    end)
    container:AddChild(minimapToggle)

    local resetButton = AceGUI:Create("Button")
    resetButton:SetText("Reset Minimap Position")
    resetButton:SetCallback("OnClick", function()
        minimapDB.minimapPos = 220
        LibStub("LibDBIcon-1.0"):Refresh("MobLootTracker", minimapDB)
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

    local mobIDToggle = AceGUI:Create("CheckBox")
    mobIDToggle:SetLabel("Show Mob ID in Tooltip")
    mobIDToggle:SetValue(MobLootTracker:GetSetting("showNPCID"))
    mobIDToggle:SetCallback("OnValueChanged", function(_, _, val)
        MobLootTracker:SetSetting("showNPCID", val)
    end)
    container:AddChild(mobIDToggle)

    local mobNameToggle = AceGUI:Create("CheckBox")
    mobNameToggle:SetLabel("Show MobLootTracker mob name in Tooltip")
    mobNameToggle:SetValue(MobLootTracker:GetSetting("showMobName") ~= false)
    mobNameToggle:SetCallback("OnValueChanged", function(_, _, val)
        MobLootTracker:SetSetting("showMobName", val)
    end)
    container:AddChild(mobNameToggle)

    local resetDB = AceGUI:Create("Button")
    resetDB:SetText("Reset All Loot Data")
    resetDB:SetCallback("OnClick", function()
        db.global.MobLootDB = {}
        MobLootTracker:Print("All loot data has been reset.")
    end)
    container:AddChild(resetDB)
end
