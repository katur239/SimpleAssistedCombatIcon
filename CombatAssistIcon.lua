local addonName, addon = ...
local addonTitle = C_AddOns.GetAddOnMetadata(addonName, "Title")

local _G                = _G
local GetTime           = GetTime
local GetActionInfo     = GetActionInfo
local GetBindingKey     = GetBindingKey
local GetBindingText    = GetBindingText
local InCombatLockdown  = InCombatLockdown
local C_CVar            = C_CVar
local C_Spell           = C_Spell
local C_SpellBook       = C_SpellBook
local C_ActionBar       = C_ActionBar
local C_AssistedCombat  = C_AssistedCombat
local C_StringUtil      = C_StringUtil

local LSM = LibStub("LibSharedMedia-3.0")
local LKB = LibStub("LibKeyBound-CUSTOM")
local ACR = LibStub("AceConfigRegistry-3.0")
local LAB = LibStub("LibActionButton-1.0", true)
local Masque = LibStub("Masque",true)

local HasBartender = false
local HasDominos = false
local HasElvUI = false

local OverrideBindingByButton
local BindingByButton = {}
local SpellIDByButton = {}
local ButtonsBySlot = {}
local SlotByButton = {}

local rotationalSpells = {}

local Colors = {
	UNLOCKED = CreateColor(0, 1, 0, 1.0),
	USABLE = CreateColor(1.0, 1.0, 1.0, 1.0),
	NOT_USABLE = CreateColor(0.4, 0.4, 0.4, 1.0),
	NOT_ENOUGH_MANA = CreateColor(0.5, 0.5, 1.0, 1.0),
	NOT_IN_RANGE = CreateColor(0.64, 0.15, 0.15, 1.0)
}

local frameStrata = {
    "BACKGROUND",
    "LOW",
    "MEDIUM",
    "HIGH",
    "DIALOG",
    "TOOLTIP",
}

local function IsValidSpellID(spellID)
    return  type(spellID) == "number" 
            and spellID > 0 
            and C_Spell.DoesSpellExist(spellID)
end

local function IsRotationalSpell(spellID)
    return rotationalSpells[spellID] or false
end

local function GetSpellIDFromActionID(action)
    if not action then return end

    local actionType, id, subType = GetActionInfo(action)

    if (actionType == "macro" and subType == "spell")
    or (actionType == "spell" and subType ~= "assistedcombat")
    then
        return id
    end

    return nil
end

local function GetBindingForAction(action)
    if not action then return end

    local key = GetBindingKey(action)
    if not key then return end

    local text = LKB:ToShortKey(key)

    if text then return text end
end

local function GetButtonsForSpellID(spellID)
    if not IsValidSpellID(spellID) then return end
    local baseSpellID = C_SpellBook.FindBaseSpellByID(spellID)

    local buttons = {}
    for buttonName, buttonSpellID in pairs(SpellIDByButton) do
        local frame = _G[buttonName]
        if frame and buttonSpellID == baseSpellID then
            table.insert(buttons, buttonName)
        end
    end
    
    return buttons
end

local function GetSpellIDFromButton(buttonName)
    local actionButton = _G[buttonName]
    if not actionButton then return end

    local spellID
    if actionButton.spellID then
        spellID = actionButton.spellID
    elseif actionButton.action then
        spellID = GetSpellIDFromActionID(actionButton.action)
    else
        local num = buttonName:find("Stance", 1, true) and tonumber(buttonName:match("(%d+)$"))
        if num then 
            local _, _, _, formID = GetShapeshiftFormInfo(num)
            spellID = formID
        end
    end

    return spellID
end

local function UpdateButtonSpellID(buttonName)
    if not buttonName then return end

    local spellID = GetSpellIDFromButton(buttonName)

    local baseSpellID = spellID and C_SpellBook.FindBaseSpellByID(spellID)
    local isRotationSpell = IsRotationalSpell(spellID) or IsRotationalSpell(baseSpellID)

    SpellIDByButton[buttonName] = isRotationSpell and baseSpellID or nil
end

local function UpdateAllButtonsSpellID()
    for buttonName, buttonSpellID in pairs(SpellIDByButton) do
        UpdateButtonSpellID(buttonName)
    end
end

local function GetKeyBindForSpellID(spellID)
    if not IsValidSpellID(spellID) then return end

    local override = addon.db.profile.Keybind.overrides[spellID]
    if override then return override end

    local buttons = GetButtonsForSpellID(spellID)
    if not buttons then return end

    for _,buttonName in ipairs(buttons) do
        if ConsolePort and addon.db.profile.Keybind.ConsolePort then 
            local button = _G[buttonName]
            if button and button.action then 
                local bindingID = ConsolePort:GetActionBinding(button.action)
                local binding = ConsolePort:GetFormattedBindingOwner(bindingID)
                if binding and binding ~= "" then return binding end
            end
        end

        local buttonAction = BindingByButton[buttonName]
        local text = GetBindingForAction(buttonAction)
        if not text and OverrideBindingByButton then 
            buttonAction = OverrideBindingByButton[buttonName]
            text = GetBindingForAction(buttonAction)
        end

        if text then return text end
    end
end

local function AddButtonToSlot(buttonName, slot)
    local oldSlot = SlotByButton[buttonName]
    if not slot or oldSlot == slot then return end

    if oldSlot then
        local oldButtons = ButtonsBySlot[oldSlot]
        if oldButtons then
            oldButtons[buttonName] = nil
            if not next(oldButtons) then
                ButtonsBySlot[oldSlot] = nil
            end
        end
    end

    SlotByButton[buttonName] = slot
    ButtonsBySlot[slot] = ButtonsBySlot[slot] or {}
    ButtonsBySlot[slot][buttonName] = true
end

local function OnActionSlotChanged(slot)
    if not slot then return end

    local buttons = ButtonsBySlot[slot]
    if not buttons then return end

    for buttonName in pairs(buttons) do
        UpdateButtonSpellID(buttonName)
    end
end

local function OnActionChanged(self, button, action, ...)
    if not button then return end

    local buttonName = button:GetName()
    if not buttonName then return end

    C_Timer.After(0, function() 
        AddButtonToSlot(buttonName, button.action)
        UpdateButtonSpellID(buttonName)
    end)
end

local function OnSpellsChanged()
    local spells = C_AssistedCombat.GetRotationSpells()
	for _, spellID in ipairs(spells) do
        if C_SpellBook.IsSpellInSpellBook(spellID) then
		    rotationalSpells[spellID] = true
        end
	end

    UpdateAllButtonsSpellID()
end

local function HideLikelyMasqueRegions(frame)
    if not Masque then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if not frame.__baselineRegions[region] then
            region:Hide()
        end
    end
end

local function LoadRotationalSpells()
	wipe(rotationalSpells)

    OnSpellsChanged()
end

local function LoadActionSlotMap()
    if C_AddOns.IsAddOnLoaded("ElvUI") then
        local E = unpack(ElvUI)
        HasElvUI = E and E.private and E.private.actionbar and E.private.actionbar.enable or false
    end
    if C_AddOns.IsAddOnLoaded("Bartender4") then HasBartender = true end
    if C_AddOns.IsAddOnLoaded("Dominos") then HasDominos = true end
    
    if ( (HasElvUI and HasBartender) or (HasElvUI and HasDominos) or (HasBartender and HasDominos) ) and addon.db.profile.Keybind.show then
        DEFAULT_CHAT_FRAME:AddMessage("|cff4cc9f0SACI|r: |cffffa000 Warning! More than 1 Action Bar addon is loaded! Keybinds will be inconsistent!|r")
    end

    local NUM_SHAPESHIFT = GetNumShapeshiftForms()

    if HasDominos then
        local DominosActionSlotMap = {
            { actionPrefix = "ACTIONBUTTON",          buttonPrefix ="DominosActionButton",      start = 1,  last = 12}, --Bar 1
            { actionPrefix = "ACTIONBUTTON",          buttonPrefix ="DominosActionButton",      start = 13, last = 24}, --Bar 2
            { actionPrefix = "MULTIACTIONBAR3BUTTON", buttonPrefix ="MultiBarRightButton",      start = 25, last = 36}, --Bar 3
            { actionPrefix = "MULTIACTIONBAR4BUTTON", buttonPrefix ="MultiBarLeftButton",       start = 37, last = 48}, --Bar 4
            { actionPrefix = "MULTIACTIONBAR2BUTTON", buttonPrefix ="MultiBarBottomRightButton",start = 49, last = 60}, --Bar 5 
            { actionPrefix = "MULTIACTIONBAR1BUTTON", buttonPrefix ="MultiBarBottomLeftButton", start = 61, last = 72}, --Bar 6
            { actionPrefix = "ACTIONBUTTON",          buttonPrefix ="DominosActionButton",      start = 73, last = 84}, --Bar 7
            { actionPrefix = "ACTIONBUTTON",          buttonPrefix ="DominosActionButton",      start = 85, last = 96}, --Bar 8
            { actionPrefix = "ACTIONBUTTON",          buttonPrefix ="DominosActionButton",      start = 97, last = 108},--Bar 9
            { actionPrefix = "ACTIONBUTTON",          buttonPrefix ="DominosActionButton",      start = 109,last = 120},--Bar 10
            { actionPrefix = "ACTIONBUTTON",          buttonPrefix ="DominosActionButton",      start = 121,last = 132},--Bar 11
            { actionPrefix = "MULTIACTIONBAR5BUTTON", buttonPrefix ="MultiBar5Button",          start = 145,last = 156},--Bar 12
            { actionPrefix = "MULTIACTIONBAR6BUTTON", buttonPrefix ="MultiBar6Button",          start = 157,last = 168},--Bar 13
            { actionPrefix = "MULTIACTIONBAR7BUTTON", buttonPrefix ="MultiBar7Button",          start = 169,last = 180},--Bar 14
            { actionPrefix = "SHAPESHIFTBUTTON",      buttonPrefix ="DominosStanceButton",      start = 901,last = NUM_SHAPESHIFT+900},--Stance Bar. Dummy slots
        }

        local DominosOverrideActionPattern = "CLICK %s%s:HOTKEY"
        local DominosOverrideButtonPrefix = "DominosActionButton"
        local DominosOverrideSlotMap = {
            { start = 13, last = 24}, --Bar 2
            { start = 73, last = 84}, --Bar 7
            { start = 85, last = 96}, --Bar 8
            { start = 97, last = 108},--Bar 9
            { start = 109,last = 120},--Bar 10
            { start = 121,last = 132},--Bar 11
        }

        for _, info in ipairs(DominosActionSlotMap) do
            for slot = info.start, info.last do
                local index = slot - info.start + 1
                local buttonName = info.buttonPrefix .. index

                BindingByButton[buttonName] = info.actionPrefix .. index
                
                UpdateButtonSpellID(buttonName)
                local button = _G[buttonName]
                if button and button.action then 
                    AddButtonToSlot(buttonName, button.action)
                end
            end
        end

        OverrideBindingByButton = {}
        for _, info in ipairs(DominosOverrideSlotMap) do
            for slot = info.start, info.last do
                local index = slot - info.start + 1
                local buttonName = DominosOverrideButtonPrefix .. slot

                OverrideBindingByButton[buttonName] = DominosOverrideActionPattern:format(DominosOverrideButtonPrefix,slot)
                UpdateButtonSpellID(buttonName)
                local button = _G[buttonName]
                if button and button.action then 
                    AddButtonToSlot(buttonName, button.action)
                end
            end
        end

        hooksecurefunc(Dominos.ActionButtons, "OnActionChanged", function(self, name, value, prevValue) OnActionChanged(self,_G[name], value) end)

    elseif HasBartender then
        local Bartender4ActionSlotMap = {
            { actionPrefix = "ACTIONBUTTON",id= true, buttonPrefix ="BT4Button",  start = 1,  last = 12}, --Bar 1 
            { actionPrefix = "ACTIONBUTTON",id= true, buttonPrefix ="BT4Button",  start = 13, last = 24}, --Bar 2
            { actionPrefix = "MULTIACTIONBAR3BUTTON", buttonPrefix ="BT4Button",  start = 25, last = 36}, --Bar 3
            { actionPrefix = "MULTIACTIONBAR4BUTTON", buttonPrefix ="BT4Button",  start = 37, last = 48}, --Bar 4 
            { actionPrefix = "MULTIACTIONBAR2BUTTON", buttonPrefix ="BT4Button",  start = 49, last = 60}, --Bar 5 
            { actionPrefix = "MULTIACTIONBAR1BUTTON", buttonPrefix ="BT4Button",  start = 61, last = 72}, --Bar 6
            { actionPrefix = "ACTIONBUTTON",id= true, buttonPrefix ="BT4Button",  start = 73, last = 84}, --Bar 7
            { actionPrefix = "ACTIONBUTTON",id= true, buttonPrefix ="BT4Button",  start = 85, last = 96}, --Bar 8
            { actionPrefix = "ACTIONBUTTON",id= true, buttonPrefix ="BT4Button",  start = 97, last = 108},--Bar 9
            { actionPrefix = "ACTIONBUTTON",id= true, buttonPrefix ="BT4Button",  start = 109,last = 120},--Bar 10
            { actionPrefix = "ACTIONBUTTON",id= true, buttonPrefix ="BT4Button",  start = 121,last = 132},--Bar 11
            { actionPrefix = "MULTIACTIONBAR5BUTTON", buttonPrefix ="BT4Button",  start = 145,last = 156},--Bar 13
            { actionPrefix = "MULTIACTIONBAR6BUTTON", buttonPrefix ="BT4Button",  start = 157,last = 168},--Bar 14
            { actionPrefix = "MULTIACTIONBAR7BUTTON", buttonPrefix ="BT4Button",  start = 169,last = 180},--Bar 15
            { actionPrefix = "SHAPESHIFTBUTTON", id=true, buttonPrefix ="BT4StanceButton",  start = 901,last = NUM_SHAPESHIFT+900},--Stance Bar. Dummy slots
        }

        local Bartender4OverrideSlotMap = {
            { actionPattern = "CLICK %s%s:Keybind",     buttonPrefix ="BT4Button",       start = 1,  last = 180}, --Action Bars
            { actionPattern = "CLICK %s%s:LeftButton",  buttonPrefix ="BT4StanceButton", start = 901,last = NUM_SHAPESHIFT+900}, --Stance Bar. Dummy slots
        }

        for _, info in ipairs(Bartender4ActionSlotMap) do
            for slot = info.start, info.last do
                local id = slot - info.start + 1
                local index = info.id and id or slot
                local buttonName = info.buttonPrefix .. index

                BindingByButton[buttonName] = info.actionPrefix .. id
                UpdateButtonSpellID(buttonName)
                local button = _G[buttonName]
                if button and button.action then 
                    AddButtonToSlot(buttonName, button.action)
                end
            end
        end

        OverrideBindingByButton = {}
        for _, info in ipairs(Bartender4OverrideSlotMap) do
            for slot = info.start, info.last do
                local id = slot - info.start + 1
                local index = slot < 900 and id or slot
                local buttonName = info.buttonPrefix..index
                
                OverrideBindingByButton[buttonName] = info.actionPattern:format(info.buttonPrefix, index)
                UpdateButtonSpellID(buttonName)
                local button = _G[buttonName]
                if button and button.action then 
                    AddButtonToSlot(buttonName, button.action)
                end
            end
        end

        LAB = LibStub("LibActionButton-1.0")
        LAB.RegisterCallback(addon, "OnButtonUpdate", OnActionChanged)

    elseif HasElvUI then     
        local ElvUIActionSlotMap = {
            { actionPrefix = "ACTIONBUTTON",          buttonPrefix ="ElvUI_Bar1Button",    start = 1,  last = 12}, --Bar 1 
            { actionPrefix = "ACTIONBUTTON",          buttonPrefix ="ElvUI_Bar1Button",    start = 13, last = 24}, --Bar 2
            { actionPrefix = "MULTIACTIONBAR3BUTTON", buttonPrefix ="ElvUI_Bar3Button",    start = 25, last = 36}, --Bar 3
            { actionPrefix = "MULTIACTIONBAR4BUTTON", buttonPrefix ="ElvUI_Bar4Button",    start = 37, last = 48}, --Bar 4 
            { actionPrefix = "MULTIACTIONBAR2BUTTON", buttonPrefix ="ElvUI_Bar5Button",    start = 49, last = 60}, --Bar 5 
            { actionPrefix = "MULTIACTIONBAR1BUTTON", buttonPrefix ="ElvUI_Bar6Button",    start = 61, last = 72}, --Bar 6
            { actionPrefix = "ACTIONBUTTON",          buttonPrefix ="ElvUI_Bar1Button",    start = 73, last = 84}, --Bar 7
            { actionPrefix = "ACTIONBUTTON",          buttonPrefix ="ElvUI_Bar1Button",    start = 85, last = 96}, --Bar 8
            { actionPrefix = "ACTIONBUTTON",          buttonPrefix ="ElvUI_Bar1Button",    start = 97, last = 108},--Bar 9
            { actionPrefix = "ACTIONBUTTON",          buttonPrefix ="ElvUI_Bar1Button",    start = 109,last = 120},--Bar 10
            { actionPrefix = "ACTIONBUTTON",          buttonPrefix ="ElvUI_Bar1Button",    start = 121,last = 132},--Bar 11
            { actionPrefix = "MULTIACTIONBAR5BUTTON", buttonPrefix ="ElvUI_Bar13Button",   start = 145,last = 156},--Bar 13
            { actionPrefix = "MULTIACTIONBAR6BUTTON", buttonPrefix ="ElvUI_Bar14Button",   start = 157,last = 168},--Bar 14
            { actionPrefix = "MULTIACTIONBAR7BUTTON", buttonPrefix ="ElvUI_Bar15Button",   start = 169,last = 180},--Bar 15
            { actionPrefix = "SHAPESHIFTBUTTON",      buttonPrefix ="ElvUI_StanceBarButton", start = 901,last = NUM_SHAPESHIFT+900},--Stance Bar. Dummy slots
        }

        local ElvUIOverrideSlotMap = {
            { actionPrefix = "ELVUIBAR2BUTTON",  buttonPrefix ="ElvUI_Bar2Button",  start = 13, last = 24}, --Bar 2
            { actionPrefix = "ELVUIBAR7BUTTON",  buttonPrefix ="ElvUI_Bar7Button",  start = 73, last = 84}, --Bar 7
            { actionPrefix = "ELVUIBAR8BUTTON",  buttonPrefix ="ElvUI_Bar8Button",  start = 85, last = 96}, --Bar 8
            { actionPrefix = "ELVUIBAR9BUTTON",  buttonPrefix ="ElvUI_Bar9Button",  start = 97, last = 108},--Bar 9
            { actionPrefix = "ELVUIBAR10BUTTON", buttonPrefix ="ElvUI_Bar10Button", start = 109,last = 120},--Bar 10
        }

        for _, info in ipairs(ElvUIActionSlotMap) do
            for slot = info.start, info.last do
                local id = slot - info.start + 1
                local buttonName = info.buttonPrefix .. id

                BindingByButton[buttonName] = info.actionPrefix .. id
                UpdateButtonSpellID(buttonName)
                local button = _G[buttonName]
                if button and button.action then 
                    AddButtonToSlot(buttonName, button.action)
                end
            end
        end

        OverrideBindingByButton = {}
        for _, info in ipairs(ElvUIOverrideSlotMap) do
            for slot = info.start, info.last do
                local id = slot - info.start + 1
                local buttonName = info.buttonPrefix..id
                
                OverrideBindingByButton[buttonName] = info.actionPrefix..id
                UpdateButtonSpellID(buttonName)
                local button = _G[buttonName]
                if button and button.action then 
                    AddButtonToSlot(buttonName, button.action)
                end
            end
        end

        LAB = LibStub("LibActionButton-1.0-ElvUI")
        LAB.RegisterCallback(addon, "OnButtonUpdate", OnActionChanged)

    else
        local DefaultActionSlotMap = {
            --Default UI Slot mapping https://warcraft.wiki.gg/wiki/Action_slot
            { actionPrefix = "ACTIONBUTTON",          buttonPrefix ="ActionButton",             start = 1,  last = 12}, --Action Bar 1 (Main Bar)
            { actionPrefix = "ACTIONBUTTON",          buttonPrefix ="ActionButton",             start = 13, last = 24}, --Action Bar 1 (Page 2)
            { actionPrefix = "MULTIACTIONBAR3BUTTON", buttonPrefix ="MultiBarRightButton",      start = 25, last = 36}, --Action Bar 4 (Right)
            { actionPrefix = "MULTIACTIONBAR4BUTTON", buttonPrefix ="MultiBarLeftButton",       start = 37, last = 48}, --Action Bar 5 (Left)
            { actionPrefix = "MULTIACTIONBAR2BUTTON", buttonPrefix ="MultiBarBottomRightButton",start = 49, last = 60}, --Action Bar 3 (Bottom Right)
            { actionPrefix = "MULTIACTIONBAR1BUTTON", buttonPrefix ="MultiBarBottomLeftButton", start = 61, last = 72}, --Action Bar 2 (Bottom Left)
            { actionPrefix = "ACTIONBUTTON",          buttonPrefix ="ActionButton",             start = 73, last = 84}, --Class Bar 1
            { actionPrefix = "ACTIONBUTTON",          buttonPrefix ="ActionButton",             start = 85, last = 96}, --Class Bar 2
            { actionPrefix = "ACTIONBUTTON",          buttonPrefix ="ActionButton",             start = 97, last = 108},--Class Bar 3
            { actionPrefix = "ACTIONBUTTON",          buttonPrefix ="ActionButton",             start = 109,last = 120},--Class Bar 4
            { actionPrefix = "ACTIONBUTTON",          buttonPrefix ="ActionButton",             start = 121,last = 132},--Action Bar 1 (Skyriding)
            { actionPrefix = "MULTIACTIONBAR5BUTTON", buttonPrefix ="MultiBar5Button",          start = 145,last = 156},--Action Bar 6
            { actionPrefix = "MULTIACTIONBAR6BUTTON", buttonPrefix ="MultiBar6Button",          start = 157,last = 168},--Action Bar 7
            { actionPrefix = "MULTIACTIONBAR7BUTTON", buttonPrefix ="MultiBar7Button",          start = 169,last = 180},--Action Bar 8
            { actionPrefix = "SHAPESHIFTBUTTON",      buttonPrefix ="StanceButton",             start = 901,last = NUM_SHAPESHIFT+900},--Stance Bar. Dummy slots
        }

        for _, info in ipairs(DefaultActionSlotMap) do
            for slot = info.start, info.last do
                local index = slot - info.start + 1
                local buttonName = info.buttonPrefix .. index
                
                BindingByButton[buttonName] = info.actionPrefix .. index
                AddButtonToSlot(buttonName, slot)
                UpdateButtonSpellID(buttonName)
            end
        end

        EventRegistry:RegisterCallback("ActionButton.OnActionChanged", OnActionChanged)
    end

    return not HasBartender and not HasDominos and not HasElvUI
end


AssistedCombatIconMixin = {}

function AssistedCombatIconMixin:OnLoad()
    self:RegisterEvent("PLAYER_LOGIN")
    self:RegisterEvent("SPELLS_CHANGED")
    self:RegisterEvent("SPELL_RANGE_CHECK_UPDATE")
    self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    self:RegisterEvent("CVAR_UPDATE")

    self:RegisterEvent("ROLE_CHANGED_INFORM")
    self:RegisterEvent("GROUP_ROSTER_UPDATE")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    self:RegisterEvent("ACTIONBAR_SLOT_CHANGED")

    self:RegisterEvent("UNIT_ENTERED_VEHICLE")
    self:RegisterEvent("UNIT_EXITED_VEHICLE")

    self:RegisterEvent("MODIFIER_STATE_CHANGED")
    self:RegisterForDrag("LeftButton")

    self.spellID = 61304
    self.updateInterval = tonumber(C_CVar.GetCVar("assistedCombatIconUpdateRate")) or 0.25
    self.isDefaultUI = true
    self.lastTickTime = GetTime()

    self.Keybind:SetParent(self.Overlay)
    self.Count:SetParent(self.Overlay)

    self.lockBtn:SetNormalTexture("Interface\\buttons\\lockbutton-unlocked-up")
    self.lockBtn:SetPushedTexture("Interface\\buttons\\lockbutton-unlocked-down")
    self.lockBtn:SetIgnoreParentAlpha(true)
    self.lockBtn:SetScript("OnClick", function()
        self.db.locked = not self.db.locked
        self:Lock(self.db.locked)
        DEFAULT_CHAT_FRAME:AddMessage(("|cff4cc9f0SACI|r: %s!"):format(self.db.locked and "Locked" or "Unlocked"))
    end)

    if Masque then
        self:SetBackdrop({
            edgeSize = 0,
        })

        local set = {}
        for _, r in ipairs({ self:GetRegions() }) do
            set[r] = true
        end
        self.__baselineRegions = set

        self.MSQGroup = Masque:Group(addonTitle)
        Masque:AddType("SACI", {"Icon", "Cooldown","HotKey"})
        self.MSQGroup:AddButton(self,{
            Icon = self.Icon,
            Cooldown = self.Cooldown,
            --HotKey = self.Keybind, --This doesn't work as a Frame. Looking into changing to a Button to make it work..
        }, "SACI")
        
        self.MSQGroup:RegisterCallback(function(Group, Option, Value)
            if Option == "Disabled" and Value == true then
                HideLikelyMasqueRegions(self)
            end
            self:ApplyOptions()
        end)
    end
end

function AssistedCombatIconMixin:OnAddonLoaded()
    self.db = addon.db.profile
end

function AssistedCombatIconMixin:OnEvent(event, ...)
    if event == "SPELL_UPDATE_COOLDOWN" then
        self:UpdateCooldown()
    elseif event == "SPELL_RANGE_CHECK_UPDATE" then
        local spellID, inRange, checksRange = ...
        if spellID ~= self.spellID then return end
        self.spellOutOfRange = checksRange == true and inRange == false
    elseif event == "MODIFIER_STATE_CHANGED" then
        if self:GetParent() ~= UIParent then return end

        local key, down = ...
        if key == "LCTRL" or key == "RCTRL" then
            if down == 1 and self:IsMouseOver() then
                self.lockBtn:SetShown(true)
            elseif down == 0 and self.lockBtn:IsShown() then
                self.lockBtn:SetShown(false)
            end
        end
    elseif event == "ACTIONBAR_SLOT_CHANGED" then
        OnActionSlotChanged(...)
    elseif event == "PLAYER_REGEN_ENABLED" and self.db.display.IN_COMBAT then
        self:UpdateVisibility()
        self:Update()
    elseif event == "PLAYER_REGEN_DISABLED" and self.db.display.IN_COMBAT then
        self:UpdateVisibility()
        self:Update()
    elseif event == "PLAYER_TARGET_CHANGED" and self.db.display.HOSTILE_TARGET then
        self:UpdateVisibility()
        self:Update()
    elseif (event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_SPECIALIZATION_CHANGED" or event == "ROLE_CHANGED_INFORM") and self.db.display.HideAsHealer then
        self:UpdateVisibility()
        self:Update()
    elseif (event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE") and self.db.display.HideInVehicle then
        if ... == "player" then 
            self:UpdateVisibility()
            self:Update()
        end
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        LoadRotationalSpells()        
    elseif event == "SPELLS_CHANGED" then
        OnSpellsChanged()
    elseif event == "PLAYER_LOGIN" then
        LoadRotationalSpells()
        self.isDefaultUI = LoadActionSlotMap()
        self:ApplyOptions()

        if self.db.enabled then 
            self:Start()
        else
            self:Stop()
        end

    elseif event == "CVAR_UPDATE" then 
        local arg1, arg2 = ...
        if arg1 =="assistedCombatIconUpdateRate" then
            self.updateInterval = tonumber(arg2) or self.updateInterval
        end
    end
end

function AssistedCombatIconMixin:Start()
    if self.ticker or not self.db.enabled then return end

    self.ticker = C_Timer.NewTicker(self.updateInterval,function()
        self:Tick()
    end)
end

function AssistedCombatIconMixin:Stop()
    self:SetShown(false)
    if not self.ticker then return end

    self.ticker:Cancel()
    self.ticker = nil
end

function AssistedCombatIconMixin:IsTickerStalled()
    return self.lastTickTime and (GetTime() - self.lastTickTime) > (self.updateInterval * 2)
end

function AssistedCombatIconMixin:Tick()
    if not self.ticker then return end

    self:UpdateVisibility()

    if self:IsShown() then 
        local nextSpell = C_AssistedCombat.GetNextCastSpell(self.db.checkForVisibleButton and self.isDefaultUI)
        if IsValidSpellID(nextSpell) and nextSpell ~= self.spellID then
            C_Spell.EnableSpellRangeCheck(self.spellID, false)
            self.spellID = nextSpell
            self:UpdateCooldown()
        end
    end
    
    self:Update()
    self.lastTickTime = GetTime()
end

function AssistedCombatIconMixin:SetVisible(visibility)
    if self.db.fadeOutHide then 
        self:SetAlpha(visibility and self.db.alpha or self.db.fadeOutAlpha)
        self:SetShown(true)
    else
        self:SetShown(visibility)
    end
end

function AssistedCombatIconMixin:UpdateVisibility()
    local db = self.db
    local display = db.display

    if not db.enabled then 
        self:SetShown(false)
        return 
    end

    if display.ALWAYS or not db.locked then
        self:SetVisible(true)
        return
    end

    if display.ONLY_ALL_CONDITIONS then
        if     (display.HOSTILE_TARGET and not UnitCanAttack("player", "anyenemy"))
            or (display.IN_COMBAT and not InCombatLockdown())
            or (display.HideInVehicle and C_PetBattles.IsInBattle())
            or (display.HideInVehicle and UnitInVehicle("player"))
            or (display.HideAsHealer and UnitGroupRolesAssigned("player") == "HEALER")
            or (display.HideOnMount and IsMounted())
        then
            self:SetVisible(false)
        else
            self:SetVisible(true)
        end
    else
        local show =   (display.HOSTILE_TARGET and UnitCanAttack("player", "anyenemy"))
                    or (display.IN_COMBAT and InCombatLockdown())
                    or (not display.IN_COMBAT and not display.HOSTILE_TARGET)

        local hide =   (display.HideInVehicle and UnitInVehicle("player"))
                    or (display.HideInVehicle and C_PetBattles.IsInBattle())
                    or (display.HideAsHealer and UnitGroupRolesAssigned("player") == "HEALER")
                    or (display.HideOnMount and IsMounted())

        self:SetVisible(show and not hide)
    end
end

function AssistedCombatIconMixin:Update()
    if not IsValidSpellID(self.spellID) or not self:IsShown() then return end

    local db = self.db
    local spellID = self.spellID

    local text = db.Keybind.show and GetKeyBindForSpellID(spellID) or ""
    self.Keybind:SetText(text)

    self.Icon:SetTexture(C_Spell.GetSpellTexture(spellID))

	local isUsable, notEnoughMana = C_Spell.IsSpellUsable(spellID);
    local needsRangeCheck = self.spellID and C_Spell.SpellHasRange(spellID);

	if needsRangeCheck then
		C_Spell.EnableSpellRangeCheck(spellID, true)
		self.spellOutOfRange = C_Spell.IsSpellInRange(spellID) == false
    else
        self.spellOutOfRange = false
	end

	if self.spellOutOfRange then
		self.Icon:SetVertexColor(Colors.NOT_IN_RANGE:GetRGBA());
	elseif isUsable then
		self.Icon:SetVertexColor(Colors.USABLE:GetRGBA());
	elseif notEnoughMana then
		self.Icon:SetVertexColor(Colors.NOT_ENOUGH_MANA:GetRGBA());
	else
		self.Icon:SetVertexColor(Colors.NOT_USABLE:GetRGBA());
	end
end

function AssistedCombatIconMixin:ApplyOptions()
    local db = self.db

    self:Lock(db.locked)
    self:SetSize(db.iconSize, db.iconSize)
    self:SetAlpha(db.alpha)

    local parent = _G[db.position.parent]
    self:SetParent(parent)
    self:ClearAllPoints()
    self:SetScale(UIParent:GetEffectiveScale()/parent:GetEffectiveScale())
    self:SetPoint(db.position.point, db.position.parent, db.position.relativePoint, db.position.X, db.position.Y)

    self:SetFrameStrata(frameStrata[db.position.strata])
    self:Raise()

    local kb = db.Keybind

    self.Keybind:ClearAllPoints()
    self.Keybind:SetPoint(kb.point, self, kb.point, kb.X, kb.Y)
    self.Keybind:SetTextColor(kb.fontColor.r, kb.fontColor.g, kb.fontColor.b, kb.fontColor.a)
    self.Keybind:SetFont(LSM:Fetch(LSM.MediaType.FONT, kb.font), kb.fontSize, kb.fontOutline and "OUTLINE" or "")

    self.Cooldown:SetDrawEdge(self.db.cooldown.edge)
    self.Cooldown:SetDrawBling(self.db.cooldown.bling)
    self.Cooldown:SetHideCountdownNumbers(self.db.cooldown.HideNumbers)
    self.Cooldown:SetEdgeTexture("Interface\\Cooldown\\UI-HUD-ActionBar-SecondaryCooldown")
    self.Cooldown:SetSwipeColor(0, 0, 0)

    local cc = db.cooldown.chargeCooldown.text

    self.Count:ClearAllPoints()
    self.Count:SetPoint(cc.point, self, cc.point, cc.X, cc.Y)
    self.Count:SetTextColor(cc.fontColor.r, cc.fontColor.g, cc.fontColor.b, cc.fontColor.a)
    self.Count:SetFont(LSM:Fetch(LSM.MediaType.FONT, cc.font), cc.fontSize, cc.fontOutline and "OUTLINE" or "")
    
    self.chargeCooldown:SetDrawBling(false)
    self.chargeCooldown:SetDrawEdge(self.db.cooldown.chargeCooldown.edge)
    self.chargeCooldown:SetEdgeTexture("Interface\\Cooldown\\edge")
    self.chargeCooldown:SetSwipeTexture("Interface\\Cooldown\\swipe")

    if (not Masque) or (self.MSQGroup and self.MSQGroup.db.Disabled) then
        local border = db.border
        self.Icon:SetPoint("TOPLEFT", border.thickness, -border.thickness)
        self.Icon:SetPoint("BOTTOMRIGHT", -border.thickness, border.thickness)
        self.Icon:SetTexCoord(0.06,0.94,0.06,0.94)

        self.Cooldown:SetPoint("TOPLEFT", border.thickness, -border.thickness)
        self.Cooldown:SetPoint("BOTTOMRIGHT", -border.thickness, border.thickness)
        self.chargeCooldown:SetPoint("TOPLEFT", border.thickness, -border.thickness)
        self.chargeCooldown:SetPoint("BOTTOMRIGHT", -border.thickness, border.thickness)

        self:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = border.thickness,
        })
        self:SetBackdropBorderColor(border.color.r, border.color.g, border.color.b, border.show and 1 or 0)
    else
        self:ClearBackdrop()
        self.Icon:ClearAllPoints()
        self.Icon:SetAllPoints()
        self.MSQGroup:ReSkin()
    end
    
    self:UpdateVisibility()
    self:Update()
end

function AssistedCombatIconMixin:UpdateCooldown()
    if not IsValidSpellID(self.spellID) or not self:IsShown() then return end
    local spellID = self.spellID

    local cdInfo = self.db.cooldown.showSwipe and C_Spell.GetSpellCooldown(spellID)
    local chargeInfo = self.db.cooldown.chargeCooldown.showSwipe and C_Spell.GetSpellCharges(spellID)

    if cdInfo then
        self.Cooldown.currentCooldownType = COOLDOWN_TYPE_NORMAL
        self.Cooldown:SetCooldown(cdInfo.startTime, cdInfo.duration, cdInfo.modRate)
    else
        self.Cooldown:Clear()
    end

    if chargeInfo then
        local charges = (chargeInfo and self.db.cooldown.chargeCooldown.showCount) and chargeInfo.currentCharges or 0
        self.Count:SetText(C_StringUtil.TruncateWhenZero(charges))
        self.chargeCooldown:SetCooldown(chargeInfo.cooldownStartTime, chargeInfo.cooldownDuration, chargeInfo.chargeModRate)
    else
        self.Count:SetText(nil)
        self.chargeCooldown:Clear()
    end
end

function AssistedCombatIconMixin:Reload()
    self:Stop()
    self.db = addon.db.profile
    self:ApplyOptions()
    self:Start()
end

function AssistedCombatIconMixin:Lock(lock)
    self.lockBtn:SetNormalTexture(lock and "Interface\\buttons\\lockbutton-locked-up" or "Interface\\buttons\\lockbutton-unlocked-up")
    self:EnableMouse(not lock)
end

function AssistedCombatIconMixin:OnDragStart()
    if self.db.locked then return end
    self:StartMoving()
end

function AssistedCombatIconMixin:OnDragStop()
    self:StopMovingOrSizing()

    local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()
    local position = self.db.position
    local strata = position.strata
    local parent = position.parent

    self.db.position = {
        strata = strata,
        point = point,
        parent = "UIParent",
        relativePoint = relativePoint,
        X = math.floor(xOfs+0.5),
        Y = math.floor(yOfs+0.5),
    }

    ACR:NotifyChange(addonName)
end

function AssistedCombatIconMixin:Debug()
    for spellID in pairs(rotationalSpells) do
        local spellInfo = C_Spell.GetSpellInfo(spellID)
        local baseSpellID = C_SpellBook.FindBaseSpellByID(spellID)
        local actions = {}
        local slots = {}
        local names = {}
        local keybinds = {}

        local icon = ""
        if spellInfo and spellInfo.iconID then
            icon = ("|T%d:16:16:0:0|t "):format(spellInfo.iconID)
        end
        local spellName = icon ..spellInfo.name

        for buttonName, buttonSpellID in pairs(SpellIDByButton) do
            if buttonSpellID == baseSpellID then
                local binding = BindingByButton[buttonName] or OverrideBindingByButton[buttonName]
                local button = _G[buttonName]
                if button and button.action then
                    slots[#slots + 1] = tostring(button.action)
                end
                actions[#actions + 1] = tostring(binding)
                keybinds[#keybinds + 1] = GetBindingForAction(binding)
                names[#names + 1] = buttonName
            end
        end

        local slot  = table.concat(slots, ", ")
        local action = table.concat(actions, ", ")
        local name  = table.concat(names, ", ")
        local text = table.concat(keybinds,", ")

        print(spellName, spellID, baseSpellID, "\n|cff4cc9f0 | Keybind:|r ", text, "\n|cff4cc9f0 | Action Slot:|r ", slot,"\n|cff4cc9f0 | Binding Action:|r ", action, "\n|cff4cc9f0 | Button Name:|r ", name)
    end
    
    if DevTool then
        DevTool:ClearAllData()
        DevTool:AddData(rotationalSpells,"SACI-rotationalSpells")
        DevTool:AddData(SpellIDByButton,"SACI-SpellIDByButton")
        DevTool:AddData(BindingByButton,"SACI-BindingByButton")
        DevTool:AddData(OverrideBindingByButton,"SACI-OverrideBindingByButton")
        DevTool:AddData(ButtonsBySlot,"SACI-ButtonsBySlot")
        DevTool:AddData(SlotByButton,"SACI-SlotByButton")
    end

    local nextSpell = C_AssistedCombat.GetNextCastSpell(self.db.checkForVisibleButton and self.isDefaultUI)
    
    print("Addon Status", 
        ("\n|cff4cc9f0 | Enabled:|r %s\n|cff4cc9f0 | Health:|r %s\n|cff4cc9f0 | Current Spell:|r %s\n|cff4cc9f0 | Next Spell:|r %s\n|cff4cc9f0 | Last Tick:|r %s\n|cff4cc9f0 | Current Time:|r %s"):format(
        self.db.enabled and "Yes" or "No!",
        self:IsTickerStalled() and "BAD!!" or "Good!",
        string.format("%d", self.spellID),
        string.format("%d", nextSpell),
        string.format("%d", self.lastTickTime),
        string.format("%d", GetTime())))
end