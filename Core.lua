local addonName, addon = ...

local addonTitle = C_AddOns.GetAddOnMetadata(addonName, "Title")

local LSM = LibStub("LibSharedMedia-3.0")

local AceAddon = LibStub("AceAddon-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDB = LibStub("AceDB-3.0")

addon = AceAddon:NewAddon(addon, addonName, "AceConsole-3.0", "AceEvent-3.0")

local defaults = {
    profile = {
        locked = false,
        showCooldownSwipe = true,
        displayMode = "ALWAYS",
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
end

function addon:SetupOptions()
    local options = {
        type = "group",
        name = addonTitle,
        args = {
            general = {
                type = "group",
                name = "General Settings",
                inline = true,
                args = {
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
                    reset = {
                        type = "execute",
                        name = "Reset to Defaults",
                        confirm = true,
                        confirmText = "Are you sure you want to reset all settings to defaults?",
                        func = function()
                            addon.db:ResetProfile()
                            AssistedCombatIconFrame:ApplyOptions()
                        end,
                        order = 6,
                        width = "normal",
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
                            displayMode = {
                                name = "Display Mode",
                                desc = "Choose when the icon should be shown",
                                type = "select",
                                style = "dropdown",
                                values = {
                                    ALWAYS = "Always",
                                    IN_COMBAT = "In Combat",
                                    HOSTILE_TARGET = "Enemy Target",
                                },
                                get = function(info) return addon.db.profile.displayMode end,
                                set = function(_, val)
                                    addon.db.profile.displayMode = val
                                    AssistedCombatIconFrame:ApplyOptions()
                                end,
                                order = 1,
                                width = 0.66,
                            },
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
                        }
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
            keybind = {
                type = "group",
                name = "Keybind",
                inline = false,
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
        },
    }

    LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, options)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName, addonTitle)    
    
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