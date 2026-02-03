local addonName, addon = ...
local addonTitle = C_AddOns.GetAddOnMetadata(addonName, "Title")

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
local Masque = LibStub("Masque",true)

local HasBartender = false
local HasDominos = false
local HasElvUI = false

local AddonOverrideActionBySlot 
local AddonOverrideButtonByAction

local LookupActionBySlot = {}
local LookupButtonByAction = {}

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

local function IsRelevantAction(actionType, subType, slot)
    return (actionType == "macro" and subType == "spell")
        or (actionType == "spell" and subType ~= "assistedcombat")
        or (slot > 900)
end

local function GetBindingForAction(action)
    if not action then return nil end

    local key = GetBindingKey(action)
    if not key then return nil end

    return LKB:ToShortKey(key)
end

local function GetStanceSlotBySpellID(spellID)
    local numForms = GetNumShapeshiftForms() or 0
    for i = 1, numForms do
        local _, _, _, formID = GetShapeshiftFormInfo(i)
        if formID == spellID then
            return {i + 900}
        end
    end

    return nil
end

local function GetConsolePortBinding(slots)
    if not slots then return end
    
    for _, slot in ipairs(slots) do
        local actionType, _, subType = GetActionInfo(slot)
        if IsRelevantAction(actionType, subType, slot) then
            local bindingID = ConsolePort:GetActionBinding(slot)
            local binding = ConsolePort:GetFormattedBindingOwner(bindingID)
            if binding and binding ~= "" then return binding end
        end
    end
end

local function GetBindingForSlots(slots)
    if not slots then return end

    for _, slot in ipairs(slots) do
        local actionType, _, subType = GetActionInfo(slot)
        if IsRelevantAction(actionType, subType, slot) then
            local action =  LookupActionBySlot[slot]
            local buttonName = LookupButtonByAction[action]

            local buttonFrame = _G[buttonName]            
            local text = GetBindingForAction(action)

            if not text or buttonFrame and buttonFrame.action ~= slot then
                action = AddonOverrideActionBySlot and AddonOverrideActionBySlot[slot]
                buttonName = AddonOverrideButtonByAction and AddonOverrideButtonByAction[action]
                local ovrText = GetBindingForAction(action)

                if ovrText then
                    buttonFrame = _G[buttonName]
                    text = ovrText
                end
            end
            
            if buttonFrame and (slot > 900 or
            buttonFrame.action == slot) and text then
                return text, slot, buttonName, action
            end
        end
    end
end

local function GetKeyBindForSpellID(spellID)
    if not IsValidSpellID(spellID) then return end

    local baseSpellID = C_SpellBook.FindBaseSpellByID(spellID)
    local slots = C_ActionBar.FindSpellActionButtons(baseSpellID)
    local text, slot, buttonName, action

    if ConsolePort and addon.db.profile.Keybind.ConsolePort then 
        text = GetConsolePortBinding(slots)
        if text then return text end
    end

    text, slot, buttonName, action = GetBindingForSlots(slots, spellID)
    if text then return text, slot, buttonName, action end
    
    slots = GetStanceSlotBySpellID(spellID)
    text, slot, buttonName, action = GetBindingForSlots(slots)
    return text, slot, buttonName, action
end

local function HideLikelyMasqueRegions(frame)
    if not Masque then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if not frame.__baselineRegions[region] then
            region:Hide()
        end
    end
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
            { actionPrefix = "SHAPESHIFTBUTTON",      buttonPrefix ="DominosStanceButton",      start = 901,last = 907},--Stance Bar. Dummy slots
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
                local id = slot - info.start + 1
                LookupActionBySlot[slot] = info.actionPrefix..id
                LookupButtonByAction[LookupActionBySlot[slot]] = info.buttonPrefix..id
            end
        end

        AddonOverrideActionBySlot = {}
        AddonOverrideButtonByAction = {}
        for _, info in ipairs(DominosOverrideSlotMap) do
            for slot = info.start, info.last do
                AddonOverrideActionBySlot[slot] = DominosOverrideActionPattern:format(DominosOverrideButtonPrefix,slot)
                AddonOverrideButtonByAction[AddonOverrideActionBySlot[slot]] = DominosOverrideButtonPrefix..slot
            end
        end
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
            { actionPrefix = "SHAPESHIFTBUTTON",      buttonPrefix ="BT4StanceButton",  start = 901,last = 907},--Stance Bar. Dummy slots
        }

        local Bartender4OverrideSlotMap = {
            { actionPattern = "CLICK %s%s:Keybind",     buttonPrefix ="BT4Button",       start = 1,  last = 180}, --Action Bars
            { actionPattern = "CLICK %s%s:LeftButton",  buttonPrefix ="BT4StanceButton", start = 901,last = 907}, --Stance Bar. Dummy slots
        }

        for _, info in ipairs(Bartender4ActionSlotMap) do
            for slot = info.start, info.last do
                local id =slot - info.start + 1
                local button = info.id and id or slot
                
                LookupActionBySlot[slot] = info.actionPrefix..id
                LookupButtonByAction[LookupActionBySlot[slot]] = info.buttonPrefix..button
            end
        end

        AddonOverrideActionBySlot = {}
        AddonOverrideButtonByAction = {}
        for _, info in ipairs(Bartender4OverrideSlotMap) do
            for slot = info.start, info.last do
                AddonOverrideActionBySlot[slot] = info.actionPattern:format(info.buttonPrefix, slot)
                AddonOverrideButtonByAction[AddonOverrideActionBySlot[slot]] = info.buttonPrefix..slot
            end
        end
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
            { actionPrefix = "SHAPESHIFTBUTTON",      buttonPrefix ="ElvUI_StanceBarButton", start = 901,last = 907},--Stance Bar. Dummy slots
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
                LookupActionBySlot[slot] = info.actionPrefix..id
                LookupButtonByAction[LookupActionBySlot[slot]] = info.buttonPrefix..id
            end
        end

        AddonOverrideActionBySlot = {}
        AddonOverrideButtonByAction = {}
        for _, info in ipairs(ElvUIOverrideSlotMap) do
            for slot = info.start, info.last do
                local id = slot - info.start + 1
                AddonOverrideActionBySlot[slot] = info.actionPrefix..id
                AddonOverrideButtonByAction[AddonOverrideActionBySlot[slot]] = info.buttonPrefix..id
            end
        end
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
          --{ actionPrefix = "UNKNOWN",               buttonPrefix ="",                         start = 133,last = 144},--Unknown
            { actionPrefix = "MULTIACTIONBAR5BUTTON", buttonPrefix ="MultiBar5Button",          start = 145,last = 156},--Action Bar 6
            { actionPrefix = "MULTIACTIONBAR6BUTTON", buttonPrefix ="MultiBar6Button",          start = 157,last = 168},--Action Bar 7
            { actionPrefix = "MULTIACTIONBAR7BUTTON", buttonPrefix ="MultiBar7Button",          start = 169,last = 180},--Action Bar 8
            { actionPrefix = "SHAPESHIFTBUTTON",      buttonPrefix ="StanceButton",             start = 901,last = 907},--Stance Bar. Dummy slots
        }

        for _, info in ipairs(DefaultActionSlotMap) do
            for slot = info.start, info.last do
                local index = slot - info.start + 1
                LookupActionBySlot[slot] = info.actionPrefix .. index
                LookupButtonByAction[LookupActionBySlot[slot]] = info.buttonPrefix .. index
            end
        end
    end
end

AssistedCombatIconMixin = {}

function AssistedCombatIconMixin:OnLoad()
    self:RegisterEvent("PLAYER_LOGIN")
    self:RegisterEvent("SPELL_RANGE_CHECK_UPDATE")
    self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    self:RegisterEvent("PLAYER_REGEN_DISABLED")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterEvent("PLAYER_TARGET_CHANGED")
    self:RegisterEvent("CVAR_UPDATE")

    self:RegisterEvent("ROLE_CHANGED_INFORM")
    self:RegisterEvent("GROUP_ROSTER_UPDATE")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")

    self:RegisterEvent("UNIT_ENTERED_VEHICLE")
    self:RegisterEvent("UNIT_EXITED_VEHICLE")

    self:RegisterEvent("MODIFIER_STATE_CHANGED")
    self:RegisterForDrag("LeftButton")

    self.spellID = 61304
    self.updateInterval = tonumber(C_CVar.GetCVar("assistedCombatIconUpdateRate")) or 0.25
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
    --C_CVar.SetCVar("assistedCombatIconUpdateRate",0.25)
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
        local unit = ...
        if unit == "player" then 
            self:UpdateVisibility()
            self:Update()
        end
    elseif event == "PLAYER_LOGIN" then
        LoadActionSlotMap()
        self:ApplyOptions()
        
        if self.db.enabled then 
            self:Start()
        else
            self:Stop()
        end

    elseif event == "CVAR_UPDATE" then 
        local arg1, arg2 = ...
        if arg1 =="assistedCombatIconUpdateRate" then
            self.combatUpdateInterval = tonumber(arg2) or self.combatUpdateInterval
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
        local nextSpell = C_AssistedCombat.GetNextCastSpell()
        if nextSpell and IsValidSpellID(nextSpell) and nextSpell ~= self.spellID then
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
    local chargeInfo = C_Spell.GetSpellCharges(spellID)

    if cdInfo then
        self.Cooldown.currentCooldownType = COOLDOWN_TYPE_NORMAL
        self.Cooldown:SetCooldown(cdInfo.startTime, cdInfo.duration, cdInfo.modRate)
    else
        self.Cooldown:Clear()
    end

    local charges = (chargeInfo and self.db.cooldown.chargeCooldown.showCount) and chargeInfo.currentCharges or 0
    self.Count:SetText(C_StringUtil.TruncateWhenZero(charges))

    if chargeInfo and self.db.cooldown.chargeCooldown.showSwipe then
        self.chargeCooldown:SetCooldown(chargeInfo.cooldownStartTime, chargeInfo.cooldownDuration, chargeInfo.chargeModRate)
    else
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
    for i, spellID in ipairs(C_AssistedCombat.GetRotationSpells()) do
        if C_SpellBook.IsSpellInSpellBook(spellID) then
            local text, slot, buttonName, action = GetKeyBindForSpellID(spellID)
            local spellInfo = C_Spell.GetSpellInfo(spellID)

            print(spellInfo.name, spellID, "\n|cff4cc9f0 | Keybind:|r ", text, "\n|cff4cc9f0 | Action Slot:|r ", slot,"\n|cff4cc9f0 | Binding Action:|r ", action, "\n|cff4cc9f0 | Button Name:|r ", buttonName)
        end
    end

    print("Addon Status", 
        ("\n|cff4cc9f0 | Enabled:|r %s\n|cff4cc9f0 | Health:|r %s\n|cff4cc9f0 | Last Tick:|r %s\n|cff4cc9f0 | Current Time:|r %s"):format(
        self.db.enabled and "Yes" or "No!", 
        self:IsTickerStalled() and "BAD!!" or "Good!", 
        string.format("%d", self.lastTickTime), 
        string.format("%d", GetTime())))
end

function AssistedCombatIconMixin:DebugSlots(start, stop)
    for i=start,stop do
        local action = LookupActionBySlot[i]
        local button = LookupButtonByAction[action]
        print("Slot ", i, "\n|cff4cc9f0 | Action:|r ",action,"\n|cff4cc9f0 | Button:|r ",button)
        if AddonOverrideActionBySlot and AddonOverrideActionBySlot[i] then
            local ovrAction = AddonOverrideActionBySlot[i]
            local ovrButton = AddonOverrideButtonByAction[ovrAction]
            print("  ", " ", "|cff4cc9f0 | Override Action:|r ",ovrAction,"\n|cff4cc9f0 | Override Button:|r ",ovrButton)
        end
    end
end