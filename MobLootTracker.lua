-- MobLootTracker.lua – Ny core med leather-integration (Vanilla + BC + WotLK)

MobLootTracker = LibStub("AceAddon-3.0"):NewAddon(
    "MobLootTracker",
    "AceConsole-3.0",
    "AceEvent-3.0",
    "AceHook-3.0"
)

local AceDB = LibStub("AceDB-3.0")

---------------------------------------------------------
-- LEATHER LIST (Vanilla + BC + WotLK)
---------------------------------------------------------
local LEATHER_ITEMS = {
    -- Vanilla
    [2318]=true,[2319]=true,[4231]=true,[4232]=true,[4233]=true,[4234]=true,[4235]=true,
    [4461]=true,[6470]=true,[6471]=true,[7286]=true,[7287]=true,[7392]=true,[8167]=true,
    [8169]=true,[8170]=true,[8171]=true,

    -- BC
    [21887]=true,[25649]=true,[25700]=true,[25707]=true,[25708]=true,[25703]=true,[25702]=true,
    [23248]=true,[25421]=true,[25420]=true,

    -- WotLK
    [33568]=true,[33567]=true,[38557]=true,[38558]=true,[38561]=true,[44128]=true,
}

---------------------------------------------------------
-- SAFE SAVEDVARIABLES BOOTSTRAP
---------------------------------------------------------
MobLootTrackerDB = MobLootTrackerDB or {}

MobLootTrackerDB.global     = MobLootTrackerDB.global     or {}
MobLootTrackerDB.global.MobLootDB = MobLootTrackerDB.global.MobLootDB or {}

MobLootTrackerDB.profile    = MobLootTrackerDB.profile    or {}
MobLootTrackerDB.minimap    = MobLootTrackerDB.minimap    or { hide = false, minimapPos = 220 }

---------------------------------------------------------
-- ACEDB DEFAULTS
---------------------------------------------------------
local defaults = {
    profile = {
        debugMode      = false,
        enableSkinning = true,
    },
    global = {
        MobLootDB = MobLootTrackerDB.global.MobLootDB,
    },
}

---------------------------------------------------------
-- SAFE DB ACCESS
---------------------------------------------------------
local function SafeDB()
    if MobLootTracker.db and MobLootTracker.db.global and MobLootTracker.db.global.MobLootDB then
        return MobLootTracker.db.global.MobLootDB
    end
    return MobLootTrackerDB.global.MobLootDB
end

function MobLootTracker:GetSetting(key)
    if self.db and self.db.profile then
        return self.db.profile[key]
    end
    return MobLootTrackerDB.profile[key]
end

function MobLootTracker:SetSetting(key, val)
    MobLootTrackerDB.profile[key] = val
    if self.db and self.db.profile then
        self.db.profile[key] = val
    end
end

---------------------------------------------------------
-- GUID → NPCID (AzerothCore F1xx format)
---------------------------------------------------------
local function ResolveNPCIDFromGUID(guid)
    if not guid then return nil end
    local entryHex = guid:match("^0xF1%x%x(%x%x%x%x%x%x)")
    return entryHex and tonumber(entryHex, 16) or nil
end

---------------------------------------------------------
-- INITIALIZE
---------------------------------------------------------
function MobLootTracker:OnInitialize()
    -- Opret AceDB med defaults
    self.db = AceDB:New("MobLootTrackerDB", defaults, true)

    -- Registrer events
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:RegisterEvent("LOOT_OPENED")

    -- Hook GameTooltip til mob‑tooltip funktionen
    self:HookScript(GameTooltip, "OnTooltipSetUnit", "OnTooltipSetUnit")

    -- Chat command til GUI
    self:RegisterChatCommand("mlt", "ShowGUI")

    -- Debug besked
    self:Print("MobLootTracker loaded (core + mob‑tooltip aktiv).")
end


---------------------------------------------------------
-- KILL TRACKING
---------------------------------------------------------
local recentKills = {}
local lastGUID    = nil

function MobLootTracker:COMBAT_LOG_EVENT_UNFILTERED(_, ...)
    local _, subEvent, _, _, _, _, dstGUID = ...

    if subEvent == "UNIT_DIED" and dstGUID then
        local npcID = ResolveNPCIDFromGUID(dstGUID)
        if npcID then
            recentKills[npcID] = true
            lastGUID = dstGUID
        end
    end
end

---------------------------------------------------------
-- LOOT TRACKING (Leather → skinning, resten → items)
---------------------------------------------------------
function MobLootTracker:LOOT_OPENED()
    local db    = SafeDB()
    local npcID = nil

    -- brug seneste kill først
    for id in pairs(recentKills) do npcID = id break end

    if not npcID then
        local guid = UnitGUID("target") or UnitGUID("mouseover")
        npcID = guid and ResolveNPCIDFromGUID(guid)
        lastGUID = guid
    end

    if not npcID and lastGUID then
        npcID = ResolveNPCIDFromGUID(lastGUID)
    end

    if not npcID then return end

    db[npcID] = db[npcID] or {
        kills    = 0,
        items    = {},
        skinning = {},
        zones    = {},
    }

    local npcData = db[npcID]

    npcData.name = UnitName("target") or UnitName("mouseover") or ("NPC "..npcID)
    npcData.zones[GetZoneText() or "Unknown Zone"] = true
    npcData.kills = (npcData.kills or 0) + 1
    recentKills[npcID] = nil

    for slot = 1, GetNumLootItems() do
        local link = GetLootSlotLink(slot)
        if link then
            local itemID = tonumber(link:match("item:(%d+)"))
            if itemID then
                -- FIX: leather går altid i skinning
                if LEATHER_ITEMS[itemID] then
                    npcData.skinning[itemID] = npcData.skinning[itemID] or { count = 0 }
                    npcData.skinning[itemID].count = npcData.skinning[itemID].count + 1
                else
                    npcData.items[itemID] = npcData.items[itemID] or { count = 0 }
                    npcData.items[itemID].count = npcData.items[itemID].count + 1
                end
            end
        end
    end
end

---------------------------------------------------------
-- TOOLTIP (Loot + Skinning)
---------------------------------------------------------
function MobLootTracker:OnTooltipSetUnit(tooltip)
    local _, unit = tooltip:GetUnit()
    if not unit then return end

    local guid = UnitGUID(unit)
    if not guid or not guid:match("^0xF1") then return end

    local npcID = ResolveNPCIDFromGUID(guid)
    if not npcID then return end

    local npcName = UnitName(unit) or ("NPC "..npcID)

    local db = SafeDB()
    local npcData = db[npcID]
    if not npcData then return end

    npcData.items    = npcData.items    or {}
    npcData.skinning = npcData.skinning or {}
    npcData.zones    = npcData.zones    or {}
    npcData.kills    = npcData.kills    or 0

    tooltip:AddLine(npcName, 1, 0.9, 0.4)

    if next(npcData.zones) then
        local zones = ""
        for z in pairs(npcData.zones) do zones = zones..z..", " end
        zones = zones:gsub(", $","")
        tooltip:AddLine("Zone: "..zones, 0.7, 0.9, 1)
    end

    if next(npcData.items) then
        tooltip:AddLine("Drops:", 0.8, 0.8, 0.2)
        for itemID, data in pairs(npcData.items) do
            local name   = GetItemInfo(itemID)
            local rarity = select(3, GetItemInfo(itemID)) or 1
            local color  = select(4, GetItemQualityColor(rarity))
            local rate   = npcData.kills > 0 and (data.count / npcData.kills * 100) or 0

            tooltip:AddLine(string.format(
                "  %s%s|r x%d (%.1f%%)",
                color or "|cffffffff",
                name or ("Item "..itemID),
                data.count,
                rate
            ))
        end
    end

    if next(npcData.skinning) then
        tooltip:AddLine("Skinning:", 0.8, 0.6, 0.2)
        for itemID, data in pairs(npcData.skinning) do
            local name   = GetItemInfo(itemID)
            local rarity = select(3, GetItemInfo(itemID)) or 1
            local color  = select(4, GetItemQualityColor(rarity))

            tooltip:AddLine(string.format(
                "  %s%s|r x%d",
                color or "|cffffffff",
                name or ("Item "..itemID),
                data.count
            ))
        end
    end
end

---------------------------------------------------------
-- SIMPLE GUI – /mlt
---------------------------------------------------------
---------------------------------------------------------
-- SIMPLE GUI – /mlt
---------------------------------------------------------
function MobLootTracker:ShowGUI()
    local db = SafeDB()
    local count = 0
    for _ in pairs(db) do count = count + 1 end

    self:Print("MobLootTracker: registrerede mobs: "..count)
    self:Print("Brug tooltip på mobs for at se loot- og skinning-data.")
end
