-- MobLootTrackerOptions.lua – AceConfig + AceGUI options panel

local MobLootTracker = LibStub("AceAddon-3.0"):GetAddon("MobLootTracker")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

---------------------------------------------------------
-- Options table (AceConfig)
---------------------------------------------------------
local options = {
    type = "group",
    name = "MobLootTracker",
    args = {

        general = {
            type = "group",
            name = "Generelt",
            order = 1,
            args = {

                showNPCID = {
                    type = "toggle",
                    name = "Vis NPCID i tooltip",
                    desc = "Vis NPCID når du mouseover en NPC",
                    get = function() return MobLootTracker:GetSetting("showNPCID") end,
                    set = function(_, val) MobLootTracker:SetSetting("showNPCID", val) end,
                },

                showItemColors = {
                    type = "toggle",
                    name = "Item-farver",
                    desc = "Vis item quality farver i tooltip",
                    get = function() return MobLootTracker:GetSetting("showItemColors") end,
                    set = function(_, val) MobLootTracker:SetSetting("showItemColors", val) end,
                },

                showDropRates = {
                    type = "toggle",
                    name = "Droprates",
                    desc = "Vis droprates i tooltip",
                    get = function() return MobLootTracker:GetSetting("showDropRates") end,
                    set = function(_, val) MobLootTracker:SetSetting("showDropRates", val) end,
                },

                debugMode = {
                    type = "toggle",
                    name = "Debug mode",
                    desc = "Vis debug beskeder i chat",
                    get = function() return MobLootTracker:GetSetting("debugMode") end,
                    set = function(_, val) MobLootTracker:SetSetting("debugMode", val) end,
                },
            },
        },

        skinning = {
            type = "group",
            name = "Skinning",
            order = 2,
            args = {

                enableSkinning = {
                    type = "toggle",
                    name = "Aktiver skinning-tracking",
                    desc = "Track skinning drops separat fra loot",
                    get = function() return MobLootTracker:GetSetting("enableSkinning") end,
                    set = function(_, val) MobLootTracker:SetSetting("enableSkinning", val) end,
                },

                skinningInfo = {
                    type = "description",
                    name = "Skinning droprate er baseret på total antal skinning-drops, ikke kills.",
                },
            },
        },

        minimap = {
            type = "group",
            name = "Minimap",
            order = 3,
            args = {

                enableMinimap = {
                    type = "toggle",
                    name = "Minimap-knap",
                    desc = "Vis MobLootTracker-knap på minimap",
                    get = function() return MobLootTracker:GetSetting("enableMinimap") end,
                    set = function(_, val) MobLootTracker:SetSetting("enableMinimap", val) end,
                },
            },
        },

        database = {
            type = "group",
            name = "Database",
            order = 4,
            args = {

                clearDB = {
                    type = "execute",
                    name = "Ryd database",
                    desc = "Slet alle loot- og skinning-data",
                    func = function()
                        MobLootTracker.db.global.MobLootDB = {}
                        print("MobLootTracker: Database ryddet.")
                    end,
                },

                statsHeader = {
                    type = "header",
                    name = "Database statistik",
                },

                stats = {
                    type = "description",
                    name = function()
                        local db = MobLootTracker:GetDB()
                        local mobs = 0
                        local items = 0
                        local skins = 0

                        for npcID, data in pairs(db) do
                            mobs = mobs + 1
                            for _, d in pairs(data.items) do items = items + d.count end
                            for _, d in pairs(data.skinning) do skins = skins + d.count end
                        end

                        return string.format(
                            "Mobs: %d\nLoot-items: %d\nSkinning-items: %d",
                            mobs, items, skins
                        )
                    end,
                },
            },
        },
    },
}

---------------------------------------------------------
-- Register options panel
---------------------------------------------------------
AceConfig:RegisterOptionsTable("MobLootTracker", options)
AceConfigDialog:AddToBlizOptions("MobLootTracker", "MobLootTracker")
