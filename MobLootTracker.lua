-- MobLootTracker.lua v2.1
local MobLootTracker = LibStub("AceAddon-3.0"):NewAddon("MobLootTracker", "AceEvent-3.0")

---------------------------------------------------------
-- DB INIT – DIN STRUKTUR
---------------------------------------------------------
function MobLootTracker:OnInitialize()
    if not MobLootTrackerDB then
        MobLootTrackerDB = {
            profileKeys = {},
            profiles = {},
        }
    end

    local char = UnitName("player") .. " - " .. GetRealmName()

    MobLootTrackerDB.profileKeys[char] = char
    MobLootTrackerDB.profiles[char] = MobLootTrackerDB.profiles[char] or {
        mobs = {},
    }

    self.db = MobLootTrackerDB.profiles[char]
    self.lastMobHit = nil
    self.isNonMobLoot = false
    self.currentMob = nil
end

---------------------------------------------------------
-- ENABLE EVENTS
---------------------------------------------------------
function MobLootTracker:OnEnable()
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    self:RegisterEvent("LOOT_OPENED")
    self:RegisterEvent("LOOT_CLOSED")
    self:RegisterEvent("CHAT_MSG_SPELL_SELF_BUFF") -- non‑mob loot detection
end

---------------------------------------------------------
-- DB HELPERS
---------------------------------------------------------
local function EnsureMob(self, key)
    self.db.mobs[key] = self.db.mobs[key] or {
        name = key,
        kills = 0,
        loots = 0,
        items = {},
    }
    return self.db.mobs[key]
end

---------------------------------------------------------
-- GUID PARSER (WotLK / AzerothCore)
---------------------------------------------------------
local function GetNPCID(guid)
    if not guid then return nil end
    local type, _, _, _, _, npc_id = strsplit("-", guid)
    if type == "Creature" or type == "Vehicle" then
        return tostring(npc_id)
    end
    return nil
end

---------------------------------------------------------
-- TARGET HANDLING
---------------------------------------------------------
function MobLootTracker:PLAYER_TARGET_CHANGED()
    local name = UnitName("target")
    local level = UnitLevel("target")

    self.isNonMobLoot = false

    if name and level and UnitCanAttack("player", "target") then
        self.currentMob = name .. ":" .. level
    else
        self.currentMob = nil
    end
end

---------------------------------------------------------
-- DAMAGE TRACKING (WotLK COMBAT LOG)
---------------------------------------------------------
function MobLootTracker:COMBAT_LOG_EVENT_UNFILTERED()
    local eventType = arg2
    local dstGUID   = arg8

    if eventType == "SWING_DAMAGE" or eventType == "SPELL_DAMAGE" then
        local npc_id = GetNPCID(dstGUID)
        if npc_id then
            self.lastMobHit = npc_id
        end
    end
end

---------------------------------------------------------
-- NON‑MOB LOOT DETECTION
---------------------------------------------------------
function MobLootTracker:CHAT_MSG_SPELL_SELF_BUFF()
    self.isNonMobLoot = true
end

---------------------------------------------------------
-- LOOT TRACKING
---------------------------------------------------------
function MobLootTracker:LOOT_OPENED()
    local numItems = GetNumLootItems()

    if self.isNonMobLoot then
        self.isNonMobLoot = false
        return
    end

    local mobKey = self.currentMob or self.lastMobHit or "loot"
    local mob = EnsureMob(self, mobKey)

    for slot = 1, numItems do
        local icon = GetLootSlotInfo(slot)
        if icon then
            mob.loots = mob.loots + 1
            mob.items[icon] = (mob.items[icon] or 0) + 1
        end
    end

    mob.kills = mob.kills + 1
    self.lastMobHit = nil
end

function MobLootTracker:LOOT_CLOSED()
    -- intet nødvendigt her endnu
end

---------------------------------------------------------
-- TOOLTIP INTEGRATION
---------------------------------------------------------
local function MLT_AddTooltip(mobKey)
    local mob = MobLootTracker.db.mobs[mobKey]
    if not mob then return end

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cffffcc00MobLootTracker|r")

    GameTooltip:AddDoubleLine("Kills", mob.kills, 1,1,1, 1,1,1)
    GameTooltip:AddDoubleLine("Loots", mob.loots, 1,1,1, 1,1,1)

    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("|cffffff00Items & Drop Rates:|r")

    for icon, count in pairs(mob.items) do
        local dropRateKills = mob.kills > 0 and (count / mob.kills * 100) or 0
        local dropRateLoots = mob.loots > 0 and (count / mob.loots * 100) or 0

        GameTooltip:AddDoubleLine(
            "|T" .. icon .. ":16|t",
            string.format("%d  (%.1f%% / %.1f%%)", count, dropRateKills, dropRateLoots),
            1,1,1,
            1,1,1
        )
    end
end


-- WORLD TOOLTIP HOOK
GameTooltip:HookScript("OnTooltipSetUnit", function(self)
    local name, unit = GameTooltip:GetUnit()
    if not unit then return end
    if not UnitCanAttack("player", unit) then return end

    local level = UnitLevel(unit)
    local mobKey = name .. ":" .. level

    MLT_AddTooltip(mobKey)
end)

---------------------------------------------------------
-- SIMPLE UI
---------------------------------------------------------
local UI = CreateFrame("Frame", "MobLootTrackerUI", UIParent)
UI:SetSize(300, 400)
UI:SetPoint("CENTER")
UI:Hide()

UI.bg = UI:CreateTexture(nil, "BACKGROUND")
UI.bg:SetAllPoints()
UI.bg:SetTexture(0, 0, 0, 0.5)

UI.title = UI:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
UI.title:SetPoint("TOP", 0, -10)
UI.title:SetText("MobLootTracker v2.1")

UI.scroll = CreateFrame("ScrollFrame", "MobLootTrackerScrollFrame", UI, "UIPanelScrollFrameTemplate")
UI.scroll:SetPoint("TOPLEFT", 10, -40)
UI.scroll:SetPoint("BOTTOMRIGHT", -30, 10)

UI.content = CreateFrame("Frame", "MobLootTrackerScrollChild", UI.scroll)
UI.content:SetSize(1, 1)
UI.scroll:SetScrollChild(UI.content)

function MobLootTracker:RenderUI()
    local mobs = self.db.mobs
    local y = -10

    for key, mob in pairs(mobs) do
        local row = CreateFrame("Frame", nil, UI.content)
        row:SetSize(260, 20)
        row:SetPoint("TOPLEFT", 0, y)

        local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("LEFT")
        text:SetText(key .. " - Kills: " .. mob.kills .. " Loots: " .. mob.loots)

        row:SetScript("OnEnter", function()
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            MLT_AddTooltip(key)
            GameTooltip:Show()
        end)

        row:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        y = y - 22
    end
end

SLASH_MLT2_1 = "/mlt"
SlashCmdList["MLT2"] = function()
    if UI:IsShown() then
        UI:Hide()
    else
        UI:Show()
        MobLootTracker:RenderUI()
    end
end
