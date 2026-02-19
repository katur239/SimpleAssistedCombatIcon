local addonName, addon = ...

local addonTitle = C_AddOns.GetAddOnMetadata(addonName, "Title")

local LSM = LibStub("LibSharedMedia-3.0")
local LDS = LibStub("LibDualSpec-1.0")

local Masque = LibStub("Masque",true)
local AceAddon = LibStub("AceAddon-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")
local AceDB = LibStub("AceDB-3.0")

local DB_VERSION = 4

addon = AceAddon:NewAddon(addon, addonName, "AceConsole-3.0", "AceEvent-3.0")

local defaults = {
    profile = {
        enabled = true,
        locked = false,
        checkForVisibleButton = false,
        display = {
            HideInVehicle = false,
            HideInHealerRole = false,
            HideOnMount = false,
            HOSTILE_TARGET = false,
            IN_COMBAT = false,
            ALWAYS = true,
            ONLY_ALL_CONDITIONS = false,
        },
        cooldown = {
            edge = true,
            bling = true,
            HideNumbers = false,
            showSwipe = true,
            chargeCooldown = {
                showCount = false,
                showSwipe = false,
                edge = true,
                text = {
                    font = "Friz Quadrata TT",
                    fontSize = 14,
                    fontOutline = true,
                    fontColor = { r = 1, g = 1, b = 1, a = 1 },
                    point = "BOTTOMRIGHT",
                    X = -5,
                    Y = 5,
                },
            },
        },
        iconSize = 48,
        alpha = 1, 
        fadeOutAlpha = 0.25,
        fadeOutHide = false,
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
            ConsolePort = false,
            overrides = {},
        }
    }
}

function addon:OnInitialize()
    self.db = AceDB:New("SCAIDB", defaults, true)
    LDS:EnhanceDatabase(self.db, addonName)
    AssistedCombatIconFrame:OnAddonLoaded()

    self.db.RegisterCallback(self, "OnNewProfile", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged")
    self.db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged")

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
        profile.DBVERSION = 2
    end

    if profile.DBVERSION < 3 then
        local oldMode = profile.showCooldownSwipe
        if oldMode ~= nil then
            profile.cooldown.showSwipe = oldMode
            profile.showCooldownSwipe = nil
        end

        profile.DBVERSION = 3
    end

    if profile.DBVERSION < 4 then
        local points = {
            ["TOPLEFT"] =       "TOPLEFT",
            ["TOP"] =           "TOP",
            ["TOPRIGHT"] =      "TOPRIGHT",
            ["LEFT"] =          "LEFT",
            ["CENTER"] =        "CENTER",
            ["RIGHT"] =         "RIGHT",
            ["BOTTOMLEFT"] =    "BOTTOMLEFT",
            ["BOTTOM"] =        "BOTTOM",
            ["BOTTOMRIGHT"] =   "BOTTOMRIGHT",
        }
        if not points[profile.position.point] then
            profile.position.point = "CENTER"
        end
        if not points[profile.position.relativePoint] then
            profile.position.relativePoint = "CENTER"
        end
        profile.DBVERSION = 4
    end

    profile.DBVERSION = DB_VERSION
end

function addon:NormalizeDisplayOptions(key, val)
    local display = self.db.profile.display
    if not display then return end

    if key == "ALWAYS" and val then
        for k in pairs(display) do
            if k ~= "ALWAYS" and k ~= "ONLY_ALL_CONDITIONS" then
                display[k] = false
            end
        end
        return
    end

    if key ~= "ALWAYS" and k ~= "ONLY_ALL_CONDITIONS" and val then
        display.ALWAYS = false
        return
    end

    if not val then
        for k, v in pairs(display) do
            if v and k ~= "ONLY_ALL_CONDITIONS" then
                return
            end
        end

        display.ALWAYS = true
    end
end

function addon:SetupOptions()
    local profileOptions = LibStub("AceDBOptions-3.0"):GetOptionsTable(addon.db)
    LDS:EnhanceOptions(profileOptions, self.db)

    profileOptions.inline = false
    profileOptions.order = 9

    local generalOptions = {
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
                desc = "Lock or unlock the frame for movement.\n\n|cffffa000TIP: Press and Hold the CONTROL key while hovering over the icon to show a Lock/Unlock toggle button!|r",
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
                desc = "Enable or disable the cooldown and charge swipe animations.",
                get = function() return addon.db.profile.cooldown.showSwipe end,
                set = function(_, val)
                    addon.db.profile.cooldown.showSwipe = val
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
    }

    local displayOptions = {
        type = "group",
        name = "Display",
        inline = false,
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
                                width = 1,
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
                                width = 1.2,
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
                                name = "Show with target",
                                order = 1,
                                width = 1,
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
                                name = "Hide in a Vehicle / Pet Battle",
                                order = 2,
                                width = 1.2,
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
                            IN_COMBAT = {
                                type = "toggle",
                                name = "Show in combat",
                                order = 1,
                                width = 1,
                                get = function(info)
                                    return addon.db.profile.display.IN_COMBAT
                                end,
                                set = function(info, val)
                                    addon.db.profile.display.IN_COMBAT = val
                                    addon:NormalizeDisplayOptions("IN_COMBAT", val)
                                    AssistedCombatIconFrame:UpdateVisibility()
                                end,
                            },
                            HideAsHealer = {
                                type = "toggle",
                                name = "Hide in Healer Role",
                                desc = "Hide the icon while in group content as a healer role.\n\n|cffffa000Icon still displays while solo.|r\n\n|cffffa000TIP: You can use Spec Profiles in the profiles options to hide based on Specs.|r",
                                order = 2,
                                width = 1.2,
                                get = function(info)
                                    return addon.db.profile.display.HideAsHealer
                                end,
                                set = function(info, val)
                                    addon.db.profile.display.HideAsHealer = val
                                    addon:NormalizeDisplayOptions("HideAsHealer", val)
                                    AssistedCombatIconFrame:UpdateVisibility()
                                end,
                            },
                        },
                    },
                    r4 = {
                        type = "group",
                        name = "",
                        order = 8,
                        args = {
                            IN_COMBAT = {
                                type = "toggle",
                                name = "All Conditions Only",
                                desc = "Only show when all of the selected conditions are met instead of any condition.",
                                order = 1,
                                width = 1.5,
                                get = function(info)
                                    return addon.db.profile.display.ONLY_ALL_CONDITIONS
                                end,
                                set = function(info, val)
                                    addon.db.profile.display.ONLY_ALL_CONDITIONS = val
                                    addon:NormalizeDisplayOptions("ONLY_ALL_CONDITIONS", val)
                                    AssistedCombatIconFrame:UpdateVisibility()
                                end,
                                disabled = function() return addon.db.profile.display.ALWAYS end,
                            },
                        },
                    },
                    grp2 = {
                        type = "group",
                        name = "",
                        inline = true,
                        order = 9,
                        args = {
                            iconSize = {
                                type = "toggle",
                                name = "Fade instead of Hiding",
                                desc = "Set the icon Alpha level instead of hiding.",
                                get = function() return addon.db.profile.fadeOutHide end,
                                set = function(_, val)
                                    addon.db.profile.fadeOutHide = val
                                    AssistedCombatIconFrame:ApplyOptions()
                                end,
                                disabled = function() return addon.db.profile.display.ALWAYS end,
                                order = 1,
                                width = "normal",
                            },
                            alpha = {
                                type = "range",
                                name = "Fade out Alpha",
                                desc = "Set the alpha to fade to when 'hidden'.",
                                min = 0, max = 1, step = 0.01,
                                get = function() return addon.db.profile.fadeOutAlpha end,
                                set = function(_, val)
                                    addon.db.profile.fadeOutAlpha = val
                                    AssistedCombatIconFrame:ApplyOptions()
                                end,
                                disabled = function() return addon.db.profile.display.ALWAYS or not addon.db.profile.fadeOutHide end,
                                order = 2,
                                width = "normal",
                                
                            },
                        },
                    },
                },
            },
            grp3 = {
                type = "group",
                name = "Icon",
                inline = true,
                order = 3,
                args = {
                    iconSize = {
                        type = "range",
                        name = "Size",
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
                    alpha = {
                        type = "range",
                        name = " Alpha",
                        desc = "Change the alpha of the icon",
                        min = 0, max = 1, step = 0.01,
                        get = function() return addon.db.profile.alpha end,
                        set = function(_, val)
                            addon.db.profile.alpha = val
                            AssistedCombatIconFrame:ApplyOptions()
                        end,
                        order = 3,
                        width = "normal",
                    },
                    grp5 = {
                        type = "group",
                        name = "",
                        inline = true,
                        order = 5,
                        args = {
                            checkVisible = {
                                type = "toggle",
                                name = "Visible Abilities Only",
                                desc = "Set if the icon should only show the abilities that are currently visible on the action bars.\n\nUses Blizzards own functions to determine if it is visible. Results may vary.\nOnly works on Default UI.",
                                disabled = function() return not AssistedCombatIconFrame.isDefaultUI end,
                                hidden = function() return not AssistedCombatIconFrame.isDefaultUI end,
                                get = function() return addon.db.profile.checkForVisibleButton end,
                                set = function(_, val)
                                    addon.db.profile.checkForVisibleButton = val
                                    AssistedCombatIconFrame:ApplyOptions()
                                end,
                                order = 1,
                                width = 1.5,
                            },
                        },
                    },
                },
            },
            grp4 = {
                type = "group",
                name = "Border",
                inline = true,
                order = 4,
                args = {
                    masqueWarning = {
                        type = "description",
                        name = "|cffffa000Border is currently overridden by Masque.|r",
                        hidden = function() return not (Masque and AssistedCombatIconFrame.MSQGroup and not AssistedCombatIconFrame.MSQGroup.db.Disabled) end,
                        order = 9.1,
                    },
                    borderColor = {
                        type = "color",
                        name = "Color",
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
                        hidden = function() return (Masque and AssistedCombatIconFrame.MSQGroup and not AssistedCombatIconFrame.MSQGroup.db.Disabled) end,
                        order = 2,
                    },
                    borderThickness = {
                        type = "range",
                        name = " Thickness",
                        desc = "Change the thickness of the icon border",
                        min = 0, max = 10, step = 1,
                        get = function() return addon.db.profile.border.thickness end,
                        set = function(_, val)
                            addon.db.profile.border.thickness = val
                            AssistedCombatIconFrame:ApplyOptions()
                        end,
                        hidden = function() return (Masque and AssistedCombatIconFrame.MSQGroup and not AssistedCombatIconFrame.MSQGroup.db.Disabled) end,
                        order = 1,
                    },
                },
            }, 
        },
    }

    local cooldownOptions = {
        type = "group",
        name = "Cooldown & Charges",
        inline = false,
        order = 3,
        args = {
            subgroup1 = {
                type = "group",
                name = "Cooldown",
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
                        width = 0.6,
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
                        width = 0.6,
                    },
                    hideNum = {
                        type = "toggle",
                        name = "Hide Cooldown Numbers",
                        desc = "Hide cooldown number text",
                        get = function() return addon.db.profile.cooldown.HideNumbers end,
                        set = function(_, val)
                            addon.db.profile.cooldown.HideNumbers = val
                            AssistedCombatIconFrame:ApplyOptions()
                        end,
                        order = 3,
                        width = 1.1,
                    },
                },
            },
            subgroup2 = {
                type = "group",
                name = "Spell Charges",
                inline = true,
                args = {
                    subgroup = {
                        type = "group",
                        name = "",
                        inline = true,
                        order = 1,
                        args = {
                            swipe = {
                                type = "toggle",
                                name = "Show Swipe",
                                desc = "Sets whether a bright line should be drawn on the moving edge of the cooldown animation.",
                                get = function() return addon.db.profile.cooldown.chargeCooldown.showSwipe end, 
                                set = function(_, val)
                                    addon.db.profile.cooldown.chargeCooldown.showSwipe = val
                                    AssistedCombatIconFrame:ApplyOptions()
                                end,
                                order = 1,
                                width = 0.8,
                            },
                            bling = {
                                type = "toggle",
                                name = "Show Count",
                                desc = "Show the number of current charges for the ability.",
                                get = function() return addon.db.profile.cooldown.chargeCooldown.showCount end,
                                set = function(_, val)
                                    addon.db.profile.cooldown.chargeCooldown.showCount = val
                                    AssistedCombatIconFrame:ApplyOptions()
                                end,
                                order = 2,
                                width = 0.8,
                            },
                            edge = {
                                type = "toggle",
                                name = "Draw Edge",
                                desc = "Sets whether a bright line should be drawn on the moving edge of the cooldown animation.",
                                get = function() return addon.db.profile.cooldown.chargeCooldown.edge end,
                                set = function(_, val)
                                    addon.db.profile.cooldown.chargeCooldown.edge = val
                                    AssistedCombatIconFrame:ApplyOptions()
                                end,
                                order = 3,
                                width = 0.6,
                            },
                        },
                    },
                    subgroup1 = {
                        type = "group",
                        name = "Display",
                        inline = true,
                        order = 2,
                        args = {
                            font = {
                                type = "select",
                                name = "Font",
                                desc = "Choose the font for the Charge Count text",
                                dialogControl = "LSM30_Font", 
                                values = LSM:HashTable(LSM.MediaType.FONT),
                                get = function() return addon.db.profile.cooldown.chargeCooldown.text.font end,
                                set = function(_, val)
                                    addon.db.profile.cooldown.chargeCooldown.text.font = val
                                    AssistedCombatIconFrame:ApplyOptions()
                                end,
                                order = 1,
                                width = 0.8,
                            },
                            fontSize = {
                                type = "range",
                                name = "Font Size",
                                desc = "Set the Charge Count font size",
                                min = 8, max = 100, step = 1,
                                get = function() return addon.db.profile.cooldown.chargeCooldown.text.fontSize end,
                                set = function(_, val)
                                    addon.db.profile.cooldown.chargeCooldown.text.fontSize = val
                                    AssistedCombatIconFrame:ApplyOptions()
                                end,
                                order = 2,
                                width = 0.7,
                            },
                            fontOutline = {
                                type = "toggle",
                                name = "Outline",
                                desc = "Set the Charge Count font outline option",
                                get = function() return addon.db.profile.cooldown.chargeCooldown.text.fontOutline end,
                                set = function(_, val)
                                    addon.db.profile.cooldown.chargeCooldown.text.fontOutline = val
                                    AssistedCombatIconFrame:ApplyOptions()
                                end,
                                order = 3,
                                width = 0.5,
                            },
                            fontColor = {
                                type = "color",
                                name = "Color",
                                desc = "Change the text color of the Charge Count text.",
                                hasAlpha = true,
                                get = function()
                                    local c = addon.db.profile.cooldown.chargeCooldown.text.fontColor
                                    return c.r, c.g, c.b, c.a
                                end,
                                set = function(_, r, g, b, a)
                                    addon.db.profile.cooldown.chargeCooldown.text.fontColor = { r = r, g = g, b = b, a = a }
                                    AssistedCombatIconFrame:ApplyOptions()
                                end,
                                order = 4,
                                width = 0.33,
                            },
                        },
                    },
                    subgroup2 = {
                        type = "group",
                        name = "Position",
                        inline = true,
                        order = 3,
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
                                get = function() return addon.db.profile.cooldown.chargeCooldown.text.point end,
                                set = function(_, val)
                                    addon.db.profile.cooldown.chargeCooldown.text.point = val
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
                                get = function() return addon.db.profile.cooldown.chargeCooldown.text.X end,
                                set = function(_, val)
                                    addon.db.profile.cooldown.chargeCooldown.text.X = val
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
                                get = function() return addon.db.profile.cooldown.chargeCooldown.text.Y end,
                                set = function(_, val)
                                    addon.db.profile.cooldown.chargeCooldown.text.Y = val
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

    local keybindOptions = {
        type = "group",
        name = "Keybind",
        inline = false,
        order = 4,
        args = {
            subgroup1 = {
                type = "group",
                name = "Display",
                inline = true,
                order = 1,
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
                name = "Position",
                inline = true,
                order = 2,
                args = {
                    point = {
                        type = "select",
                        name = "Anchor",
                        desc = "Choose the anchor point of the text",
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
            subgroup3 = {
                type = "group",
                name = "Advanced",
                inline = true,
                order = 3,
                args = {
                    OverrideGrp = {
                        type = "group",
                        name = "Override Text",
                        inline = true,
                        order = 1,
                        args = {
                            spell = {
                                type = "select",
                                name = "Spell",
                                desc = "Select the spell to override.",
                                values = function()
                                    local val = {}
                                    local spells = C_AssistedCombat.GetRotationSpells()
                                    for _, spellID in ipairs(spells) do
                                        local spellInfo = C_Spell.GetSpellInfo(spellID)
                                        local icon = ""
                                        if spellInfo and spellInfo.iconID then
                                             icon = ("|T%d:16:16:0:0|t "):format(spellInfo.iconID)
                                        end
                                        val[spellID] = icon ..spellInfo.name
                                    end
                                    return val
                                 end,
                                get = function() return addon.overrideSpellSelected end,
                                set = function(_, val) 
                                    addon.overrideSpellSelected = val 
                                    AceConfigRegistry:NotifyChange(addonName)
                                end,
                                order = 1,
                                width = 1.2,
                            },
                            text = {
                                type = "input",
                                name = "Override text",
                                desc = "Enter the text you wish to be shown for the Keybind for this spell.",
                                get = function() return addon.db.profile.Keybind.overrides[addon.overrideSpellSelected] end,
                                set = function(_, val) addon.db.profile.Keybind.overrides[addon.overrideSpellSelected] = val ~= "" and val or nil end,
                                disabled = function() return not addon.overrideSpellSelected end,
                                order = 2,
                                width = 1.2,
                            },
                        },
                    },
                    ConsolePort = {
                        type = "toggle",
                        name = "Use ConsolePort GamePad Icons",
                        desc = "Set if GamePad icons should be shown instead of Keyboard bindings.\n\nRequires the ConsolePort addon.",
                        get = function() return addon.db.profile.Keybind.ConsolePort end,
                        set = function(_, val)
                            addon.db.profile.Keybind.ConsolePort = val
                        end,
                        disabled = function() return not ConsolePort end,
                        order = 2,
                        width = 1.2,
                    },
                },
            },
        },
    }

    local positionOptions = {
        type = "group",
        name = "Position",
        inline = false,
        order = 2,
        args = {
            positionGroup = {
                type = "group",
                name = "Position",
                inline = true,
                order = 2,
                args = {
                    point = {
                        type = "select",
                        name = "Relative Anchor Point",
                        desc = "What point on the Screen or parent frame to anchor to.",
                        values = function()
                            local points = {
                                ["TOPLEFT"] =       "TOPLEFT",
                                ["TOP"] =           "TOP",
                                ["TOPRIGHT"] =      "TOPRIGHT",
                                ["LEFT"] =          "LEFT",
                                ["CENTER"] =        "CENTER",
                                ["RIGHT"] =         "RIGHT",
                                ["BOTTOMLEFT"] =    "BOTTOMLEFT",
                                ["BOTTOM"] =        "BOTTOM",
                                ["BOTTOMRIGHT"] =   "BOTTOMRIGHT",
                            }
                            return points
                        end,
                        get = function() return addon.db.profile.position.relativePoint end,
                        set = function(_, val)
                            addon.db.profile.position.relativePoint = val
                            AssistedCombatIconFrame:ApplyOptions()
                        end,
                        order = 1,
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
                name = "Display",
                inline = true,
                order = 1,
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
                        order = 1,
                        width = 0.8,
                    },
                }
            },
            subgroup2 = {
                type = "group",
                name = "Advanced",
                inline = true,
                args = {
                    parent = {
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
                    point = {
                        type = "select",
                        name = "Icon Anchor Point",
                        desc = "What point on the Icon should it be anchored by",
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
                            AssistedCombatIconFrame:ApplyOptions()
                        end,
                        order = 2,
                        width = 0.8,
                    },
                    warning = {
                        type = "group",
                        name = "",
                        inline = true,
                        order = 3,
                        args = {
                            parentWarning = {
                                type = "description",
                                name = "|cffffa000Dragging the icon will reset the Frame Parent back to the UIParent.|r\n|cffffa000Setting this option will also disable the lock/unlock button on mouseover with the Control key.|r",
                            },
                        },
                    },
                },
            },
        },
    }

    local options = {
        type = "group",
        name = addonTitle,
        args = {
            general = generalOptions,
            display = displayOptions,
            position = positionOptions,
            cooldown = cooldownOptions,
            keybind = keybindOptions,
            profiles = profileOptions
        },
    }

    AceConfig:RegisterOptionsTable(addonName, options)
    AceConfigDialog:AddToBlizOptions(addonName, addonTitle)

    self:RegisterChatCommand("saci", "SlashCommand")

    AddonCompartmentFrame:RegisterAddon({
        text = addonTitle,
        icon = C_AddOns.GetAddOnMetadata(addonName, "IconTexture"),
        func = function() AceConfigDialog:Open(addonName) end
    })
end

function addon:OnProfileChanged()
    self:UpdateDB()
    AssistedCombatIconFrame:Reload()
end

function addon:SlashCommand(input)
    input = input:lower():trim()
    local PREFIX = "|cff4cc9f0SACI|r: "

    if input == "" then
        AceConfigDialog:Open(addonName)
    elseif input =="lock" then
        self.db.profile.locked = not self.db.profile.locked
        AssistedCombatIconFrame:Lock(self.db.profile.locked)
        DEFAULT_CHAT_FRAME:AddMessage(
            PREFIX .. (self.db.profile.locked and "Locked" or "Unlocked")
        )
    elseif input =="unlock" then
        self.db.profile.locked = false
        AssistedCombatIconFrame:Lock(false)
        DEFAULT_CHAT_FRAME:AddMessage(
            PREFIX .. "Unlocked"
        )
    elseif input =="toggle" then
        self.db.profile.enabled = not self.db.profile.enabled
        DEFAULT_CHAT_FRAME:AddMessage(
            PREFIX .. (self.db.profile.enabled and "Enabled" or "Disabled")
        )
    elseif input =="reload" then
        AssistedCombatIconFrame:Reload()
        DEFAULT_CHAT_FRAME:AddMessage(PREFIX.."Reloaded!")
    elseif input =="debug" then
        AssistedCombatIconFrame:Debug()
    else
        DEFAULT_CHAT_FRAME:AddMessage( PREFIX .. 
            "Usage:\n" ..
            "/saci          -Open Config Menu\n" ..
            "/saci lock     -Toggle Locking the Icon \n" ..
            "/saci unlock   -Unlock the Icon \n" ..
            "/saci reload   -Restart the addon \n" ..
            "/saci toggle   -Toggle the addon On or Off"
        )
    end
    
end