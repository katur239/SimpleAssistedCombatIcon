local addonName, addon = ...

local addonTitle = C_AddOns.GetAddOnMetadata(addonName, "Title")

local LSM = LibStub("LibSharedMedia-3.0")

local AceAddon = LibStub("AceAddon-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDB = LibStub("AceDB-3.0")
local DB_VERSION = 2

addon = AceAddon:NewAddon(addon, addonName, "AceConsole-3.0", "AceEvent-3.0")

local defaults = {
    profile = {
        enabled = true,
        locked = false,
        showCooldownSwipe = true,
        display = {
            HideInVehicle = false,
            HideInHealerRole = false,
            HideOnMount = false,
            HOSTILE_TARGET = false,
            IN_COMBAT = false,
            ALWAYS = true,
        },
        cooldown = {
            edge = true,
            bling = true,
        },
        iconSize = 48,
        border = {
            show = true,
            thickness = 2,
            color = { r = 0, g = 0, b = 0},
        },
        position = {
            strata = 3,
            parent = "UIParent",
            point = "CENTER",
            relativePoint = "CENTER",
            X = 0,
            Y = 0
        },
        Keybind = {
            show = true,
            font = "Friz Quadrata TT",
            fontSize = 14,
            fontOutline = true,
            fontColor = { r = 1, g = 1, b = 1, a = 1 },
            point = "TOPRIGHT",
            X = -4,
            Y = -4,
        }
    }
}

function addon:OnInitialize()
    self.db = AceDB:New("SCAIDB", defaults, true)
    AssistedCombatIconFrame:OnAddonLoaded();

    self:SetupOptions()

    self:UpdateDB()
end

function addon:UpdateDB()
    local profile = self.db.profile
    profile.DBVERSION = profile.DBVERSION or 1

    if profile.DBVERSION < 2 then
        local oldMode = profile.displayMode
        if oldMode then
            profile.display[oldMode] = true
            profile.displayMode = nil
        end

        if profile.display.ALWAYS then
            -- Clear everything except ALWAYS
            for k, v in pairs(profile.display) do
                if k ~= "ALWAYS" and v then
                    profile.display[k] = false
                end
            end
        end

        profile.DBVERSION = DB_VERSION
    end
end

function addon:NormalizeDisplayOptions(key, val)
    local display = self.db.profile.display
    if not display then return end

    if key == "ALWAYS" and val then
        for k in pairs(display) do
            if k ~= "ALWAYS" then
                display[k] = false
            end
        end
        return
    end

    if key ~= "ALWAYS" and val then
        display.ALWAYS = false
        return
    end

    if not val then
        for _, v in pairs(display) do
            if v then
                return
            end
        end

        display.ALWAYS = true
    end
end

function addon:SetupOptions()
    local profileOptions = LibStub("AceDBOptions-3.0"):GetOptionsTable(addon.db)
    profileOptions.inline = false

    local options = {
        type = "group",
        name = addonTitle,
        args = {
            general = {
                type = "group",
                name = "General Settings",
                inline = true,
                args = {
                    enabled = {
                        type = "toggle",
                        name = "Enabled",
                        desc = "Enable / Disable the Icon",
                        get = function() return addon.db.profile.enabled end,
                        set = function(_, val)
                            addon.db.profile.enabled = val
                            if val then
                                AssistedCombatIconFrame:Start()
                            else
                                AssistedCombatIconFrame:Stop()
                            end
                        end,
                        order = 1,
                        width = 0.6,
                    },
                    locked = {
                        type = "toggle",
                        name = "Lock Frame",
                        desc = "Lock or unlock the frame for movement.",
                        get = function() return addon.db.profile.locked end,
                        set = function(_, val)
                            addon.db.profile.locked = val
                            AssistedCombatIconFrame:ApplyOptions()
                        end,
                        order = 1,
                        width = 0.6,
                    },
                    showCooldownSwipe = {
                        type = "toggle",
                        name = "Enable Cooldown",
                        desc = "Enable or disable the cooldown swipe overlay",
                        get = function() return addon.db.profile.showCooldownSwipe end,
                        set = function(_, val)
                            addon.db.profile.showCooldownSwipe = val
                            AssistedCombatIconFrame:ApplyOptions()
                        end,
                        order = 2,
                        width = 0.8,
                    },
                    showKeybindText = {
                        type = "toggle",
                        name = "Enable Keybind",
                        desc = "Show or hide keybinding text",
                        get = function() return addon.db.profile.Keybind.show end,
                        set = function(_, val)
                            addon.db.profile.Keybind.show = val
                            AssistedCombatIconFrame:ApplyOptions()
                        end,
                        order = 3,
                        width = 0.8,
                    },
                },
            },
            display = {
                type = "group",
                name = "Display",
                inline = false,
                order = 1,
                args = {
                    displayGroup = {
                        type = "group",
                        name = "",
                        inline = true,
                        order = 1,
                        args = {
                            grp = {
                                type = "group",
                                name = "",
                                inline = true,
                                order = 1,
                                args = {
                                    displayOptions = {
                                        type = "group",
                                        name = "Display Options",
                                        desc = "When to show or hide the icon.",
                                        inline = true,
                                        order = 2,
                                        args = {
                                            r1 = {
                                                type = "group",
                                                name = "",
                                                order = 1,
                                                args = {
                                                    ALWAYS = {
                                                        type = "toggle",
                                                        name = "Always Show",
                                                        order = 1,
                                                        width = 1.1,
                                                        get = function(info)
                                                            return addon.db.profile.display.ALWAYS
                                                        end,
                                                        set = function(info, val)
                                                            if not val then
                                                                return
                                                            end

                                                            addon.db.profile.display.ALWAYS = val
                                                            addon:NormalizeDisplayOptions("ALWAYS",val)
                                                            AssistedCombatIconFrame:UpdateVisibility()
                                                        end,
                                                    },
                                                    HideOnMount = {
                                                        type = "toggle",
                                                        name = "Hide while mounted",
                                                        order = 2,
                                                        width = 1.1,
                                                        get = function(info)
                                                            return addon.db.profile.display.HideOnMount
                                                        end,
                                                        set = function(info, val)
                                                            addon.db.profile.display.HideOnMount = val
                                                            addon:NormalizeDisplayOptions("HideOnMount", val)
                                                            AssistedCombatIconFrame:UpdateVisibility()
                                                        end,
                                                    },
                                                },
                                            },
                                            r2 = {
                                                type = "group",
                                                name = "",
                                                order = 2,
                                                args = {
                                                    HOSTILE_TARGET = {
                                                        type = "toggle",
                                                        name = "Show only with target",
                                                        order = 1,
                                                        width = 1.1,
                                                        get = function(info)
                                                            return addon.db.profile.display.HOSTILE_TARGET
                                                        end,
                                                        set = function(info, val)
                                                            addon.db.profile.display.HOSTILE_TARGET = val
                                                            addon:NormalizeDisplayOptions("HOSTILE_TARGET", val)
                                                            AssistedCombatIconFrame:UpdateVisibility()
                                                        end,
                                                    },
                                                    HideInVehicle = {
                                                        type = "toggle",
                                                        name = "Hide while in a Vehicle",
                                                        order = 2,
                                                        width = 1.1,
                                                        get = function(info)
                                                            return addon.db.profile.display.HideInVehicle
                                                        end,
                                                        set = function(info, val)
                                                            addon.db.profile.display.HideInVehicle = val
                                                            addon:NormalizeDisplayOptions("HideInVehicle", val)
                                                            AssistedCombatIconFrame:UpdateVisibility()
                                                        end,
                                                    },
                                                },
                                            },
                                            r3 = {
                                                type = "group",
                                                name = "",
                                                order = 3,
                                                args = {
                                                    HideAsHealer = {
                                                        type = "toggle",
                                                        name = "Hide while in Healing Role",
                                                        order = 2,
                                                        width = 1.1,
                                                        get = function(info)
                                                            return addon.db.profile.display.HideAsHealer
                                                        end,
                                                        set = function(info, val)
                                                            addon.db.profile.display.HideAsHealer = val
                                                            addon:NormalizeDisplayOptions("HideAsHealer", val)
                                                            AssistedCombatIconFrame:UpdateVisibility()
                                                        end,
                                                    },
                                                    HideAsTank = {
                                                        type = "toggle",
                                                        name = "Hide while in Tanking Role",
                                                        order = 2,
                                                        width = 1.1,
                                                        get = function(info)
                                                            return addon.db.profile.display.HideAsTank
                                                        end,
                                                        set = function(info, val)
                                                            addon.db.profile.display.HideAsTank = val
                                                            addon:NormalizeDisplayOptions("HideAsTank", val)
                                                            AssistedCombatIconFrame:UpdateVisibility()
                                                        end,
                                                    },
                                                },
                                            },
                                            r4 = {
                                                type = "group",
                                                name = "",
                                                order = 4,
                                                args = {
                                                    IN_COMBAT = {
                                                        type = "toggle",
                                                        name = "Show only in combat",
                                                        order = 1,
                                                        width = 1.1,
                                                        get = function(info)
                                                            return addon.db.profile.display.IN_COMBAT
                                                        end,
                                                        set = function(info, val)
                                                            addon.db.profile.display.IN_COMBAT = val
                                                            addon:NormalizeDisplayOptions("IN_COMBAT", val)
                                                            AssistedCombatIconFrame:UpdateVisibility()
                                                        end,
                                                    },
                                                },
                                            },
                                        },
                                    }
                                },
                            },
                            grp2 = {
                                type = "group",
                                name = "",
                                inline = true,
                                order = 2,
                                args = {
                                    iconSize = {
                                        type = "range",
                                        name = "Icon Size",
                                        desc = "Set the size of the icon",
                                        min = 20, max = 300, step = 1,
                                        get = function() return addon.db.profile.iconSize end,
                                        set = function(_, val)
                                            addon.db.profile.iconSize = val
                                            AssistedCombatIconFrame:ApplyOptions()
                                        end,
                                        order = 2,
                                        width = "normal",
                                    },
                                    borderColor = {
                                        type = "color",
                                        name = " Border Color",
                                        desc = "Change the text color of the border",
                                        hasAlpha = false,
                                        get = function()
                                            local c = addon.db.profile.border.color
                                            return c.r, c.g, c.b
                                        end,
                                        set = function(_, r, g, b, a)
                                            addon.db.profile.border.color = { r = r, g = g, b = b }
                                            AssistedCombatIconFrame:ApplyOptions()
                                        end,
                                        order = 4,
                                        width = 0.66,
                                    },
                                    borderThickness = {
                                        type = "range",
                                        name = " Border Thickness",
                                        desc = "Change the thickness of the icon border",
                                        min = 0, max = 10, step = 1,
                                        get = function() return addon.db.profile.border.thickness end,
                                        set = function(_, val)
                                            addon.db.profile.border.thickness = val
                                            AssistedCombatIconFrame:ApplyOptions()
                                        end,
                                        order = 5,
                                        width = 0.66,
                                    },
                                },
                            },
                        },
                    },
                    positionGroup = {
                        type = "group",
                        name = "",
                        inline = true,
                        order = 2,
                        args = {
                            point = {
                                type = "select",
                                name = "Anchor",
                                desc = "Choose the side of the screen to anchor the icon to",
                                values = function()
                                    local points = {
                                        ["TOPLEFT"] = "TOPLEFT",
                                        ["TOP"] = "TOP",
                                        ["TOPRIGHT"] = "TOPRIGHT",
                                        ["LEFT"] = "LEFT",
                                        ["CENTER"] = "CENTER",
                                        ["RIGHT"] = "RIGHT",
                                        ["BOTTOMLEFT"] = "BOTTOMLEFT",
                                        ["BOTTOM"] = "BOTTOM",
                                        ["BOTTOMRIGHT"] = "BOTTOMRIGHT",
                                    }
                                    return points
                                end,
                                get = function() return addon.db.profile.position.point end,
                                set = function(_, val)
                                    addon.db.profile.position.point = val
                                    addon.db.profile.position.relativePoint = val
                                    AssistedCombatIconFrame:ApplyOptions()
                                end,
                                order = 5,
                                width = 0.8,
                            },
                            fontX = {
                                type = "range",
                                name = "X",
                                desc = "Set the X offset from the selected Anchor",
                                min = -500, max = 500, step = 1,
                                get = function() return math.floor(addon.db.profile.position.X+0.5) end,
                                set = function(_, val)
                                    addon.db.profile.position.X = math.floor(val+0.5)
                                    AssistedCombatIconFrame:ApplyOptions()
                                end,
                                order = 6,
                                width = 0.8,
                            },
                            fontY = {
                                type = "range",
                                name = "Y",
                                desc = "Set the Y offset from the selected Anchor",
                                min = -500, max = 500, step = 1,
                                get = function() return math.floor(addon.db.profile.position.Y+0.5) end,
                                set = function(_, val)
                                    addon.db.profile.position.Y = math.floor(val+0.5)
                                    AssistedCombatIconFrame:ApplyOptions()
                                end,
                                order = 7,
                                width = 0.8,
                            },
                        }
                    },
                    group1 = {
                        type = "group",
                        name = "",
                        inline = true,
                        order = 3,
                        args = {
                            strata = {
                                type = "select",
                                name = "Frame Strata",
                                desc = "Choose the Strata level to render on",
                                values = function()
                                    local orderedStrata = {
                                        "BACKGROUND",
                                        "LOW",
                                        "MEDIUM",
                                        "HIGH",
                                        "DIALOG",
                                        "TOOLTIP",
                                    }
                                    return orderedStrata
                                end,
                                get = function() return addon.db.profile.position.strata end,
                                set = function(_, val)
                                    addon.db.profile.position.strata = val
                                    AssistedCombatIconFrame:ApplyOptions()
                                end,
                                order = 5,
                                width = 0.8,
                            },
                        }
                    },
                },
            },
            cooldown = {
                type = "group",
                name = "Cooldown",
                inline = false,
                order = 2,
                args = {
                    subgroup1 = {
                        type = "group",
                        name = "Animation",
                        inline = true,
                        args = {
                            edge = {
                                type = "toggle",
                                name = "Draw Edge",
                                desc = "Sets whether a bright line should be drawn on the moving edge of the cooldown animation.",
                                get = function() return addon.db.profile.cooldown.edge end,
                                set = function(_, val)
                                    addon.db.profile.cooldown.edge = val
                                    AssistedCombatIconFrame:ApplyOptions()
                                end,
                                order = 1,
                                width = 0.8,
                            },
                            bling = {
                                type = "toggle",
                                name = "Draw Bling",
                                desc = "Set whether a 'bling' animation plays at the end of a cooldown.",
                                get = function() return addon.db.profile.cooldown.bling end,
                                set = function(_, val)
                                    addon.db.profile.cooldown.bling = val
                                    AssistedCombatIconFrame:ApplyOptions()
                                end,
                                order = 2,
                                width = 0.8,
                            },
                        },
                    },
                },
            },
            keybind = {
                type = "group",
                name = "Keybind",
                inline = false,
                order = 3,
                args = {
                    subgroup1 = {
                        type = "group",
                        name = "",
                        inline = true,
                        args = {
                            font = {
                                type = "select",
                                name = "Font",
                                desc = "Choose the font used for the keybind text",
                                dialogControl = "LSM30_Font",
                                values = LSM:HashTable(LSM.MediaType.FONT),
                                get = function() return addon.db.profile.Keybind.font end,
                                set = function(_, val)
                                    addon.db.profile.Keybind.font = val
                                    AssistedCombatIconFrame:ApplyOptions()
                                end,
                                order = 1,
                                width = 0.8,
                            },
                            fontSize = {
                                type = "range",
                                name = "Font Size",
                                desc = "Set the Keybind font size",
                                min = 8, max = 100, step = 1,
                                get = function() return addon.db.profile.Keybind.fontSize end,
                                set = function(_, val)
                                    addon.db.profile.Keybind.fontSize = val
                                    AssistedCombatIconFrame:ApplyOptions()
                                end,
                                order = 2,
                                width = 0.8,
                            },
                            fontOutline = {
                                type = "toggle",
                                name = "Outline",
                                desc = "Set the Keybind font outline",
                                get = function() return addon.db.profile.Keybind.fontOutline end,
                                set = function(_, val)
                                    addon.db.profile.Keybind.fontOutline = val
                                    AssistedCombatIconFrame:ApplyOptions()
                                end,
                                order = 3,
                                width = 0.5,
                            },
                            fontColor = {
                                type = "color",
                                name = "Color",
                                desc = "Change the text color of the keybind text.",
                                hasAlpha = true,
                                get = function()
                                    local c = addon.db.profile.Keybind.fontColor
                                    return c.r, c.g, c.b, c.a
                                end,
                                set = function(_, r, g, b, a)
                                    addon.db.profile.Keybind.fontColor = { r = r, g = g, b = b, a = a }
                                    AssistedCombatIconFrame:ApplyOptions()
                                end,
                                order = 4,
                                width = 0.33,
                            },
                        },
                    },
                    subgroup2 = {
                        type = "group",
                        name = "",
                        inline = true,
                        args = {
                            point = {
                                type = "select",
                                name = "Anchor",
                                desc = "Choose the anchor point of the Text",
                                values = function()
                                    local points = {
                                        ["TOPLEFT"] = "TOPLEFT",
                                        ["TOP"] = "TOP",
                                        ["TOPRIGHT"] = "TOPRIGHT",
                                        ["LEFT"] = "LEFT",
                                        ["CENTER"] = "CENTER",
                                        ["RIGHT"] = "RIGHT",
                                        ["BOTTOMLEFT"] = "BOTTOMLEFT",
                                        ["BOTTOM"] = "BOTTOM",
                                        ["BOTTOMRIGHT"] = "BOTTOMRIGHT",
                                    }
                                    return points
                                end,
                                get = function() return addon.db.profile.Keybind.point end,
                                set = function(_, val)
                                    addon.db.profile.Keybind.point = val
                                    AssistedCombatIconFrame:ApplyOptions()
                                end,
                                order = 5,
                                width = 0.8,
                            },
                            fontX = {
                                type = "range",
                                name = "X Offset",
                                desc = "Set the X offset from the selected Anchor",
                                min = -64, max = 64, step = 1,
                                get = function() return addon.db.profile.Keybind.X end,
                                set = function(_, val)
                                    addon.db.profile.Keybind.X = val
                                    AssistedCombatIconFrame:ApplyOptions()
                                end,
                                order = 6,
                                width = 0.8,
                            },
                            fontY = {
                                type = "range",
                                name = "Y Offset",
                                desc = "Set the Y offset from the selected Anchor",
                                min = -64, max = 64, step = 1,
                                get = function() return addon.db.profile.Keybind.Y end,
                                set = function(_, val)
                                    addon.db.profile.Keybind.Y = val
                                    AssistedCombatIconFrame:ApplyOptions()
                                end,
                                order = 7,
                                width = 0.8,
                            },
                        },
                    },
                },
            },
            advanced = {
                type = "group",
                name = "Advanced",
                inline = false,
                order = 9,
                args = {
                    subgroup2 = {
                        type = "group",
                        name = "Advanced Options",
                        inline = true,
                        args = {
                            point = {
                                type = "input",
                                name = " Frame Parent",
                                desc = "Enter a frame name to anchor the icon to.",
                                get = function() return addon.db.profile.position.parent or "UIParent" end,
                                set = function(_, val)
                                    if val == "" then val = "UIParent" end
                                    addon.db.profile.position.parent = val
                                    AssistedCombatIconFrame:ApplyOptions()
                                end,
                                validate = function(info, value)
                                    if value == "" then return true end
                                    if not _G[value] then
                                        return "That frame doesn't exist."
                                    end
                                    return true
                                end,
                                order = 1,
                            },
                        },
                    },
                },
            },
            profiles = profileOptions
        },
    }

    AceConfig:RegisterOptionsTable(addonName, options)
    AceConfigDialog:AddToBlizOptions(addonName, addonTitle)

    self:RegisterChatCommand("saci", "OpenConfig")

    AddonCompartmentFrame:RegisterAddon({
        text = addonTitle,
        icon = C_AddOns.GetAddOnMetadata(addonName, "IconTexture"),
        func = function() AceConfigDialog:Open(addonName) end
    })
end

function addon:OpenConfig()
    AceConfigDialog:Open(addonName)
end