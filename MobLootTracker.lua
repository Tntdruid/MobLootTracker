-- MobLootTracker.lua – Core tracking + tooltip + NPCID toggle

---------------------------------------------------------
-- SavedVariables
---------------------------------------------------------
MobLootDB = MobLootDB or {}
MobLootTracker_ShowNPCID = MobLootTracker_ShowNPCID or false

---------------------------------------------------------
-- Leather items
---------------------------------------------------------
local LeatherItems = {
    [4231] = true, [4232] = true, [4233] = true,
    [4234] = true, [4235] = true, [4304] = true,
    [8167] = true, [8170] = true, [8171] = true,
}

---------------------------------------------------------
-- GUID → NPCID parser (AzerothCore F1xx)
---------------------------------------------------------
function ResolveNPCIDFromGUID(guid)
    if not guid then return nil end
    if type(guid) == "number" then return guid end
    if type(guid) == "string" and guid:match("^%d+$") then
        return tonumber(guid)
    end

    local entryHex = guid:match("^0xF1%x%x(%x%x%x%x%x%x)")
    return entryHex and tonumber(entryHex, 16) or nil
end

---------------------------------------------------------
-- MI2 Skinning Method
---------------------------------------------------------
local lastCorpseID = nil

local function GetCorpseID()
    return UnitGUID("target") or UnitGUID("mouseover")
end

local function IsCorpseReopen(corpseID)
    return corpseID ~= nil and corpseID == lastCorpseID
end

local function StoreCorpseID(corpseID)
    lastCorpseID = corpseID
end

---------------------------------------------------------
-- Item color
---------------------------------------------------------
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

---------------------------------------------------------
-- Kill + loot tracking
---------------------------------------------------------
local recentKills = {}
local lastGUID = nil

local frame = CreateFrame("Frame")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("LOOT_OPENED")
frame:RegisterEvent("LOOT_SLOT_CLEARED")

frame:SetScript("OnEvent", function(self, event, ...)

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subEvent, _, _, _, _, dstGUID = ...
        if subEvent == "UNIT_DIED" and dstGUID then
            local npcID = ResolveNPCIDFromGUID(dstGUID)
            if npcID then
                recentKills[npcID] = true
                lastGUID = dstGUID
            end
        end
    end

    if event == "LOOT_OPENED" then
        local npcID = nil

        for id in pairs(recentKills) do npcID = id break end

        if not npcID then
            local guid = UnitGUID("target")
            if guid then npcID = ResolveNPCIDFromGUID(guid) lastGUID = guid end
        end

        if not npcID then
            local guid = UnitGUID("mouseover")
            if guid then npcID = ResolveNPCIDFromGUID(guid) lastGUID = guid end
        end

        if not npcID and lastGUID then
            npcID = ResolveNPCIDFromGUID(lastGUID)
        end

        if not npcID then
            print("MobLootTracker: Ingen NPCID ved loot.")
            return
        end

        MobLootDB[npcID] = MobLootDB[npcID] or { kills = 0, items = {}, skinning = {} }
        MobLootDB[npcID].kills = MobLootDB[npcID].kills + 1
        recentKills[npcID] = nil

        local corpseID = GetCorpseID()
        local isSkinning = IsCorpseReopen(corpseID)

        for slot = 1, GetNumLootItems() do
            local itemLink = GetLootSlotLink(slot)
            if itemLink then
                local itemID = tonumber(itemLink:match("item:(%d+)"))
                if itemID then
                    if isSkinning then
                        MobLootDB[npcID].skinning[itemID] = MobLootDB[npcID].skinning[itemID] or { count = 0 }
                        MobLootDB[npcID].skinning[itemID].count = MobLootDB[npcID].skinning[itemID].count + 1
                    else
                        MobLootDB[npcID].items[itemID] = MobLootDB[npcID].items[itemID] or { count = 0 }
                        MobLootDB[npcID].items[itemID].count = MobLootDB[npcID].items[itemID].count + 1
                    end
                end
            end
        end

        StoreCorpseID(corpseID)
    end

    if event == "LOOT_SLOT_CLEARED" then
        local npcID = ResolveNPCIDFromGUID(UnitGUID("target") or UnitGUID("mouseover"))
        if npcID then StoreCorpseID(GetCorpseID()) end
    end
end)

---------------------------------------------------------
-- Tooltip
---------------------------------------------------------
GameTooltip:HookScript("OnTooltipSetUnit", function(self)
    local _, unit = self:GetUnit()
    if not unit then return end

    local guid = UnitGUID(unit)
    local npcID = ResolveNPCIDFromGUID(guid)
    if not npcID then return end

    local npcData = MobLootDB[npcID]
    if not npcData then return end

    -- NPCID toggle
    if MobLootTracker_ShowNPCID then
        self:AddLine("NPCID: " .. npcID, 0.6, 0.6, 0.6)
    end

    -- Loot
    if npcData.items and next(npcData.items) then
        self:AddLine("Known Drops:", 0.8, 0.8, 0.2)
        for itemID, data in pairs(npcData.items) do
            local name = GetItemInfo(itemID)
            local count = data.count or 0
            local rate = (count / npcData.kills) * 100
            local color = GetItemColor(itemID)

            self:AddLine("  " .. color .. (name or ("Item "..itemID)) ..
                         "|r x" .. count .. " (" .. string.format("%.1f", rate) .. "%)")
        end
    end

    -- Skinning
    if npcData.skinning and next(npcData.skinning) then
        self:AddLine("Skinning Drops:", 0.2, 0.8, 1)
        for itemID, data in pairs(npcData.skinning) do
            local name = GetItemInfo(itemID)
            local count = data.count or 0
            local rate = (count / npcData.kills) * 100
            local color = GetItemColor(itemID)

            self:AddLine("  " .. color .. (name or ("Item "..itemID)) ..
                         "|r x" .. count .. " (" .. string.format("%.1f", rate) .. "%)")
        end
    end
end)

---------------------------------------------------------
-- NPCID Toggle Command
---------------------------------------------------------
local function ToggleNPCIDDisplay(state)
    if state == "on" then
        MobLootTracker_ShowNPCID = true
        print("MobLootTracker: NPCID vises i tooltip.")
    elseif state == "off" then
        MobLootTracker_ShowNPCID = false
        print("MobLootTracker: NPCID skjules i tooltip.")
    else
        print("Brug: /mltnpcid on  eller  /mltnpcid off")
    end
end

SLASH_MLTNPCID1 = "/mltnpcid"
SlashCmdList["MLTNPCID"] = function(msg)
    msg = msg:lower():gsub("%s+", "")
    ToggleNPCIDDisplay(msg)
end

print("MobLootTracker Core loaded")
-- MobLootTracker.lua – Core: tracking, tooltip, leather filter, drop-rates, colors

MobLootDB = MobLootDB or {}

---------------------------------------------------------
-- Leather item list
---------------------------------------------------------
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

---------------------------------------------------------
-- Drop-rate + item color
---------------------------------------------------------
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

---------------------------------------------------------
-- GUID parser (AzerothCore F1xx creature GUIDs)
---------------------------------------------------------
function ResolveNPCIDFromGUID(guid)
    if not guid then return nil end
    if type(guid) == "number" then return guid end
    if type(guid) == "string" and guid:match("^%d+$") then return tonumber(guid) end
    local entryHex = guid:match("^0xF1%x%x(%x%x%x%x%x%x)")
    return entryHex and tonumber(entryHex, 16) or nil
end

---------------------------------------------------------
-- SavedVariables
---------------------------------------------------------
local saveFrame = CreateFrame("Frame")
saveFrame:RegisterEvent("PLAYER_LOGOUT")
saveFrame:SetScript("OnEvent", function() MobLootDB = MobLootDB or {} end)

---------------------------------------------------------
-- MI2 Skinning Method: corpse reopen detection
---------------------------------------------------------
local lastCorpseID = nil

local function GetCorpseID()
    return UnitGUID("target") or UnitGUID("mouseover")
end

local function IsCorpseReopen(corpseID)
    return corpseID ~= nil and corpseID == lastCorpseID
end

local function StoreCorpseID(corpseID)
    lastCorpseID = corpseID
end

---------------------------------------------------------
-- Kill + loot tracking
---------------------------------------------------------
local recentKills = {}
local lastGUID = nil

local mainFrame = CreateFrame("Frame")
mainFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
mainFrame:RegisterEvent("LOOT_OPENED")
mainFrame:RegisterEvent("LOOT_SLOT_CLEARED")

mainFrame:SetScript("OnEvent", function(self, event, ...)

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subEvent, _, _, _, _, dstGUID = ...
        if subEvent == "UNIT_DIED" and dstGUID then
            local npcID = ResolveNPCIDFromGUID(dstGUID)
            if npcID then recentKills[npcID] = true lastGUID = dstGUID end
        end
    end

    if event == "LOOT_OPENED" then
        local npcID = nil

        for id in pairs(recentKills) do npcID = id break end

        if not npcID then
            local guid = UnitGUID("target")
            if guid then npcID = ResolveNPCIDFromGUID(guid) lastGUID = guid end
        end

        if not npcID then
            local guid = UnitGUID("mouseover")
            if guid then npcID = ResolveNPCIDFromGUID(guid) lastGUID = guid end
        end

        if not npcID and lastGUID then npcID = ResolveNPCIDFromGUID(lastGUID) end
        if not npcID then print("MobLootTracker: Ingen NPCID ved loot.") return end

        MobLootDB[npcID] = MobLootDB[npcID] or { kills = 0, items = {}, skinning = {} }
        MobLootDB[npcID].kills = MobLootDB[npcID].kills + 1
        recentKills[npcID] = nil

        local corpseID = GetCorpseID()
        local isSkinning = IsCorpseReopen(corpseID)

        for slot = 1, GetNumLootItems() do
            local itemLink = GetLootSlotLink(slot)
            if itemLink then
                local itemID = tonumber(itemLink:match("item:(%d+)"))
                if itemID then
                    if isSkinning then
                        MobLootDB[npcID].skinning[itemID] = MobLootDB[npcID].skinning[itemID] or { count = 0 }
                        MobLootDB[npcID].skinning[itemID].count = MobLootDB[npcID].skinning[itemID].count + 1
                    else
                        MobLootDB[npcID].items[itemID] = MobLootDB[npcID].items[itemID] or { count = 0 }
                        MobLootDB[npcID].items[itemID].count = MobLootDB[npcID].items[itemID].count + 1
                    end
                end
            end
        end

        StoreCorpseID(corpseID)
    end

    if event == "LOOT_SLOT_CLEARED" then
        local npcID = ResolveNPCIDFromGUID(UnitGUID("target") or UnitGUID("mouseover"))
        if npcID then StoreCorpseID(GetCorpseID()) end
    end
end)

---------------------------------------------------------
-- Tooltip: loot + leather skinning, with colors + drop-rates
---------------------------------------------------------
GameTooltip:HookScript("OnTooltipSetUnit", function(self)
    local _, unit = self:GetUnit()
    if not unit then return end

    local guid = UnitGUID(unit)
    local npcID = ResolveNPCIDFromGUID(guid)
    if not npcID then return end

    local npcData = MobLootDB[npcID]
    if not npcData then return end

    -- Normal loot
    if npcData.items and next(npcData.items) then
        self:AddLine("Known Drops:", 0.8, 0.8, 0.2)
        for itemID, data in pairs(npcData.items) do
            local name = GetItemInfo(itemID)
            local count = data.count or 0
            local rate = GetDropRate(npcData, itemID, false)
            local color = GetItemColor(itemID)

            self:AddLine("  " .. color .. (name or ("Item "..itemID)) ..
                         "|r x" .. count .. " (" .. string.format("%.1f", rate) .. "%)")
        end
    end

    -- Skinning loot (only leather)
    if NPCHasLeatherSkinning(npcData) then
        self:AddLine("Skinning Drops:", 0.2, 0.8, 1)
        for itemID, data in pairs(npcData.skinning) do
            if LeatherItems[itemID] then
                local name = GetItemInfo(itemID)
                local count = data.count or 0
                local rate = GetDropRate(npcData, itemID, true)
                local color = GetItemColor(itemID)

                self:AddLine("  " .. color .. (name or ("Item "..itemID)) ..
                             "|r x" .. count .. " (" .. string.format("%.1f", rate) .. "%)")
            end
        end
    end
end)

---------------------------------------------------------
-- Debug
---------------------------------------------------------
SLASH_MLTDEBUG1 = "/mltdebug"
SlashCmdList["MLTDEBUG"] = function()
    local guid = UnitGUID("mouseover")
    local npcID = guid and ResolveNPCIDFromGUID(guid)
    print("GUID:", guid, "NPCID:", npcID)
    if npcID and MobLootDB[npcID] then
        print("DB entry found for", npcID)
    else
        print("NO DB for", npcID)
    end
end

print("MobLootTracker Core loaded")
-- MobLootTracker.lua – Full addon with GUI, Tooltip Loot + Skinning, Leather Filter, MI2 Skinning Method, F1xx GUID Parser

MobLootDB = MobLootDB or {}

---------------------------------------------------------
-- Leather item list (WotLK / AzerothCore)
---------------------------------------------------------
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

---------------------------------------------------------
-- GUID parser (AzerothCore F1xx creature GUIDs)
---------------------------------------------------------
function ResolveNPCIDFromGUID(guid)
    if not guid then return nil end
    if type(guid) == "number" then return guid end
    if type(guid) == "string" and guid:match("^%d+$") then return tonumber(guid) end
    local entryHex = guid:match("^0xF1%x%x(%x%x%x%x%x%x)")
    return entryHex and tonumber(entryHex, 16) or nil
end

---------------------------------------------------------
-- SavedVariables
---------------------------------------------------------
local saveFrame = CreateFrame("Frame")
saveFrame:RegisterEvent("PLAYER_LOGOUT")
saveFrame:SetScript("OnEvent", function() MobLootDB = MobLootDB or {} end)

---------------------------------------------------------
-- MI2 Skinning Method: corpse reopen detection
---------------------------------------------------------
local lastCorpseID = nil

local function GetCorpseID()
    return UnitGUID("target") or UnitGUID("mouseover")
end

local function IsCorpseReopen(corpseID)
    return corpseID ~= nil and corpseID == lastCorpseID
end

local function StoreCorpseID(corpseID)
    lastCorpseID = corpseID
end

---------------------------------------------------------
-- Kill tracking (WotLK combatlog)
---------------------------------------------------------
local recentKills = {}
local lastGUID = nil

local mainFrame = CreateFrame("Frame")
mainFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
mainFrame:RegisterEvent("LOOT_OPENED")
mainFrame:RegisterEvent("LOOT_SLOT_CLEARED")

mainFrame:SetScript("OnEvent", function(self, event, ...)

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, subEvent, _, _, _, _, dstGUID = ...
        if subEvent == "UNIT_DIED" and dstGUID then
            local npcID = ResolveNPCIDFromGUID(dstGUID)
            if npcID then recentKills[npcID] = true lastGUID = dstGUID end
        end
    end

    if event == "LOOT_OPENED" then
        local npcID = nil

        for id in pairs(recentKills) do npcID = id break end

        if not npcID then
            local guid = UnitGUID("target")
            if guid then npcID = ResolveNPCIDFromGUID(guid) lastGUID = guid end
        end

        if not npcID then
            local guid = UnitGUID("mouseover")
            if guid then npcID = ResolveNPCIDFromGUID(guid) lastGUID = guid end
        end

        if not npcID and lastGUID then npcID = ResolveNPCIDFromGUID(lastGUID) end
        if not npcID then print("MobLootTracker: Ingen NPCID ved loot.") return end

        MobLootDB[npcID] = MobLootDB[npcID] or { kills = 0, items = {}, skinning = {} }
        MobLootDB[npcID].kills = MobLootDB[npcID].kills + 1
        recentKills[npcID] = nil

        local corpseID = GetCorpseID()
        local isSkinning = IsCorpseReopen(corpseID)

        for slot = 1, GetNumLootItems() do
            local itemLink = GetLootSlotLink(slot)
            if itemLink then
                local itemID = tonumber(itemLink:match("item:(%d+)"))
                if itemID then
                    if isSkinning then
                        MobLootDB[npcID].skinning[itemID] = MobLootDB[npcID].skinning[itemID] or { count = 0 }
                        MobLootDB[npcID].skinning[itemID].count = MobLootDB[npcID].skinning[itemID].count + 1
                    else
                        MobLootDB[npcID].items[itemID] = MobLootDB[npcID].items[itemID] or { count = 0 }
                        MobLootDB[npcID].items[itemID].count = MobLootDB[npcID].items[itemID].count + 1
                    end
                end
            end
        end

        StoreCorpseID(corpseID)
    end

    if event == "LOOT_SLOT_CLEARED" then
        local npcID = ResolveNPCIDFromGUID(UnitGUID("target") or UnitGUID("mouseover"))
        if npcID then StoreCorpseID(GetCorpseID()) end
    end
end)

---------------------------------------------------------
-- Tooltip: show normal loot + leather skinning
---------------------------------------------------------
GameTooltip:HookScript("OnTooltipSetUnit", function(self)
    local _, unit = self:GetUnit()
    if not unit then return end

    local guid = UnitGUID(unit)
    local npcID = ResolveNPCIDFromGUID(guid)
    if not npcID then return end

    local npcData = MobLootDB[npcID]
    if not npcData then return end

    ---------------------------------------------------------
    -- Normal loot
    ---------------------------------------------------------
    if npcData.items and next(npcData.items) then
        self:AddLine("Known Drops:", 0.8, 0.8, 0.2)
        for itemID, data in pairs(npcData.items) do
            local name = GetItemInfo(itemID)
            local count = data.count or 0
            self:AddLine("  " .. (name or ("Item "..itemID)) .. " x" .. count, 1, 1, 1)
        end
    end

    ---------------------------------------------------------
    -- Skinning loot (only leather)
    ---------------------------------------------------------
    if NPCHasLeatherSkinning(npcData) then
        self:AddLine("Skinning Drops:", 0.2, 0.8, 1)
        for itemID, data in pairs(npcData.skinning) do
            if LeatherItems[itemID] then
                local name = GetItemInfo(itemID)
                local count = data.count or 0
                self:AddLine("  " .. (name or ("Item "..itemID)) .. " x" .. count, 1, 1, 1)
            end
        end
    end
end)

---------------------------------------------------------
-- GUI (AceGUI)
---------------------------------------------------------
local AceGUI = LibStub("AceGUI-3.0")

function MobLootTracker_ShowGUI(npcID)
    local npcData = MobLootDB[npcID]
    if not npcData then print("MobLootTracker: Ingen data for NPCID", npcID) return end

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
            local label = AceGUI:Create("Label")
            label:SetText((name or ("Item "..itemID)) .. " x" .. count)
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
                local label = AceGUI:Create("Label")
                label:SetText((name or ("Item "..itemID)) .. " x" .. count)
                container:AddChild(label)
            end
        end
    end

    tabGroup:SetCallback("OnGroupSelected", function(self, event, group)
        if group == "loot" then DrawLootTab(self)
        elseif group == "skinning" then DrawSkinningTab(self)
        end
    end)

    tabGroup:SelectTab("loot")
end

---------------------------------------------------------
-- Slash commands
---------------------------------------------------------
SLASH_MLTGUI1 = "/mltgui"
SlashCmdList["MLTGUI"] = function(msg)
    local npcID = tonumber(msg)
    if npcID then MobLootTracker_ShowGUI(npcID)
    else print("Brug: /mltgui <npcID>") end
end

print("MobLootTracker (Full GUI + Tooltip Loot + Leather Skinning + MI2 Method + F1xx Parser) loaded")
-- MobLootTracker.lua – AzerothCore WotLK + MI2 Skinning Method + Kill-Fix + Auto-Loot + F1xx GUID Parser
MobLootDB = MobLootDB or {}

---------------------------------------------------------
-- GUID parser (AzerothCore F1xx creature GUIDs)
---------------------------------------------------------
function ResolveNPCIDFromGUID(guid)
    if not guid then return nil end

    if type(guid) == "number" then return guid end
    if type(guid) == "string" and guid:match("^%d+$") then return tonumber(guid) end

    local entryHex = guid:match("^0xF1%x%x(%x%x%x%x%x%x)")
    if entryHex then
        return tonumber(entryHex, 16)
    end

    return nil
end

---------------------------------------------------------
-- SavedVariables
---------------------------------------------------------
local saveFrame = CreateFrame("Frame")
saveFrame:RegisterEvent("PLAYER_LOGOUT")
saveFrame:SetScript("OnEvent", function()
    MobLootDB = MobLootDB or {}
end)

---------------------------------------------------------
-- MI2 Skinning Method: corpse reopen detection
---------------------------------------------------------
local lastCorpseID = nil

local function GetCorpseID()
    return UnitGUID("target") or UnitGUID("mouseover")
end

local function IsCorpseReopen(corpseID)
    return corpseID ~= nil and corpseID == lastCorpseID
end

local function StoreCorpseID(corpseID)
    lastCorpseID = corpseID
end

---------------------------------------------------------
-- Kill tracking (WotLK combatlog)
---------------------------------------------------------
local recentKills = {}
local lastGUID = nil

local mainFrame = CreateFrame("Frame")
mainFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
mainFrame:RegisterEvent("LOOT_OPENED")
mainFrame:RegisterEvent("LOOT_SLOT_CLEARED")

mainFrame:SetScript("OnEvent", function(self, event, ...)

    ---------------------------------------------------------
    -- UNIT_DIED → kill detection
    ---------------------------------------------------------
    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local timestamp, subEvent, hideCaster,
              srcGUID, srcName, srcFlags,
              dstGUID, dstName, dstFlags = ...

        if subEvent == "UNIT_DIED" and dstGUID then
            local npcID = ResolveNPCIDFromGUID(dstGUID)
            if npcID then
                recentKills[npcID] = true
                lastGUID = dstGUID
            end
        end
    end

    ---------------------------------------------------------
    -- LOOT_OPENED → normal loot + skinning loot
    ---------------------------------------------------------
    if event == "LOOT_OPENED" then

        local npcID = nil

        -- 1) Combatlog kill
        for id in pairs(recentKills) do
            npcID = id
            break
        end

        -- 2) Target fallback
        if not npcID then
            local guid = UnitGUID("target")
            if guid then
                npcID = ResolveNPCIDFromGUID(guid)
                lastGUID = guid
            end
        end

        -- 3) Mouseover fallback
        if not npcID then
            local guid = UnitGUID("mouseover")
            if guid then
                npcID = ResolveNPCIDFromGUID(guid)
                lastGUID = guid
            end
        end

        -- 4) Last GUID fallback
        if not npcID and lastGUID then
            npcID = ResolveNPCIDFromGUID(lastGUID)
        end

        if not npcID then
            print("MobLootTracker: Ingen NPCID ved loot.")
            return
        end

        MobLootDB[npcID] = MobLootDB[npcID] or { kills = 0, items = {}, skinning = {} }

        -- Kill fix
        MobLootDB[npcID].kills = MobLootDB[npcID].kills + 1
        recentKills[npcID] = nil

        ---------------------------------------------------------
        -- MI2 Skinning Method: corpse reopen = skinning
        ---------------------------------------------------------
        local corpseID = GetCorpseID()
        local isSkinning = IsCorpseReopen(corpseID)

        ---------------------------------------------------------
        -- Register loot
        ---------------------------------------------------------
        for slot = 1, GetNumLootItems() do
            local itemLink = GetLootSlotLink(slot)
            if itemLink then
                local itemID = tonumber(itemLink:match("item:(%d+)"))
                if itemID then

                    if isSkinning then
                        ---------------------------------------------------------
                        -- ⭐ SKINNING LOOT
                        ---------------------------------------------------------
                        MobLootDB[npcID].skinning[itemID] = MobLootDB[npcID].skinning[itemID] or { count = 0 }
                        MobLootDB[npcID].skinning[itemID].count = MobLootDB[npcID].skinning[itemID].count + 1

                        print("MobLootTracker: Skinning registreret for NPCID", npcID, "item", itemID)

                    else
                        ---------------------------------------------------------
                        -- NORMAL LOOT
                        ---------------------------------------------------------
                        MobLootDB[npcID].items[itemID] = MobLootDB[npcID].items[itemID] or { count = 0 }
                        MobLootDB[npcID].items[itemID].count = MobLootDB[npcID].items[itemID].count + 1

                        print("MobLootTracker: Loot registreret for NPCID", npcID, "item", itemID)
                    end
                end
            end
        end

        ---------------------------------------------------------
        -- First loot = normal loot → store corpse ID
        ---------------------------------------------------------
        StoreCorpseID(corpseID)
    end

    ---------------------------------------------------------
    -- LOOT_SLOT_CLEARED → update corpse ID
    ---------------------------------------------------------
    if event == "LOOT_SLOT_CLEARED" then
        local npcID = ResolveNPCIDFromGUID(UnitGUID("target") or UnitGUID("mouseover"))
        if npcID then
            StoreCorpseID(GetCorpseID())
        end
    end
end)

---------------------------------------------------------
-- Debug command
---------------------------------------------------------
SLASH_MLTDEBUG1 = "/mltdebug"
SlashCmdList["MLTDEBUG"] = function()
    local guid = UnitGUID("mouseover")
    local npcID = guid and ResolveNPCIDFromGUID(guid)
    print("GUID:", guid, "NPCID:", npcID)

    if npcID and MobLootDB[npcID] then
        print("DB entry found for", npcID)
    else
        print("NO DB for", npcID)
    end
end

print("MobLootTracker (MI2 Skinning Method + Kill-Fix + F1xx GUID Parser) loaded")
