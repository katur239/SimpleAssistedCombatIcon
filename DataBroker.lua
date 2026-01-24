local addonName, addon = ...
local LibDataBroker = LibStub("LibDataBroker-1.1")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")

DataBroker = {}

function DataBroker:GenerateLDBLabel()
    if addon.db.profile.enabled then
        return "SimpleCombat (|c0000ff00Enabled|r)"
    else
        return "SimpleCombat (|c00ff0000Disabled|r)"
    end
end

function DataBroker:Initialize()
    addon.ldb = LibDataBroker:NewDataObject("Broken_SimpleAssistedCombat",
    {
        type = "launcher",
        text = nil,
        label = DataBroker:GenerateLDBLabel(),
        icon = [[Interface\ICONS\INV_Gizmo_GoblinBoomBox_01]],
        OnClick = function(self, ...)
            local b = ...
            if b and b == "RightButton" then
                addon.db.profile.enabled = not  addon.db.profile.enabled
                AssistedCombatIconFrame:UpdateVisibility()
                addon.ldb.label = DataBroker:GenerateLDBLabel()
                if AceConfigDialog.OpenFrames.SimpleAssistedCombatIcon then
                    local grp = AceConfigDialog:SelectGroup(addonName)
                    if grp then
                        grp.enabled = addon.db.profile.enabled
                    end
                end
            else
                if AceConfigDialog.OpenFrames.SimpleAssistedCombatIcon then
                    AceConfigDialog:Close(addonName)
                else
                    AceConfigDialog:Open(addonName)
                end
            end
        end
    })
end
