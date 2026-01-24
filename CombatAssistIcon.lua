local addonName, addon = ...
local addonTitle = C_AddOns.GetAddOnMetadata(addonName, "Title")

local GetTime           = GetTime
local GetActionInfo     = GetActionInfo
local GetBindingKey     = GetBindingKey
local GetBindingText    = GetBindingText
local InCombatLockdown  = InCombatLockdown
local FindBaseSpellByID = FindBaseSpellByID
local C_CVar            = C_CVar
local C_Spell           = C_Spell
local C_SpellBook       = C_SpellBook
local C_ActionBar       = C_ActionBar
local C_AssistedCombat  = C_AssistedCombat

local LSM = LibStub("LibSharedMedia-3.0")
local ACR = LibStub("AceConfigRegistry-3.0")
local Masque = LibStub("Masque",true)

local HasBartender = false
local HasDominos = false
local BarAddonLoaded = false

local AddonOverrideActionBySlot 
local AddonOverrideButtonByAction
local AddonLookupActionBySlot = {}
local AddonLookupButtonByAction = {}

local LookupActionBySlot = {}
local LookupButtonByAction = {}

local DefaultActionSlotMap = {
    --Default UI Slot mapping https://warcraft.wiki.gg/wiki/Action_slot
    { actionPrefix = "ACTIONBUTTON",          buttonPrefix ="ActionButton",             start = 1,  last = 12},--Action Bar 1 (Main Bar)
    { actionPrefix = "ACTIONBUTTON",          buttonPrefix ="ActionButton",             start = 13, last = 24},--Action Bar 1 (Page 2)
    { actionPrefix = "MULTIACTIONBAR3BUTTON", buttonPrefix ="MultiBarRightButton",      start = 25, last = 36},--Action Bar 4 (Right)
    { actionPrefix = "MULTIACTIONBAR4BUTTON", buttonPrefix ="MultiBarLeftButton",       start = 37, last = 48},--Action Bar 5 (Left)
    { actionPrefix = "MULTIACTIONBAR2BUTTON", buttonPrefix ="MultiBarBottomRightButton",start = 49, last = 60},--Action Bar 3 (Bottom Right)
    { actionPrefix = "MULTIACTIONBAR1BUTTON", buttonPrefix ="MultiBarBottomLeftButton", start = 61, last = 72},--Action Bar 2 (Bottom Left)
    { actionPrefix = "ACTIONBUTTON",          buttonPrefix ="ActionButton",             start = 73, last = 84},--Class Bar 1
    { actionPrefix = "ACTIONBUTTON",          buttonPrefix ="ActionButton",             start = 85, last = 96},--Class Bar 2
    { actionPrefix = "ACTIONBUTTON",          buttonPrefix ="ActionButton",             start = 97, last = 108},--Class Bar 3
    { actionPrefix = "ACTIONBUTTON",          buttonPrefix ="ActionButton",             start = 109,last = 120},--Class Bar 4
    { actionPrefix = "ACTIONBUTTON",          buttonPrefix ="ActionButton",             start = 121,last = 132},--Action Bar 1 (Skyriding)
  --{ actionPrefix = "UNKNOWN",               buttonPrefix ="",                         start = 133,last = 144},--Unknown
    { actionPrefix = "MULTIACTIONBAR5BUTTON", buttonPrefix ="MultiBar5Button",          start = 145,last = 156},--Action Bar 6
    { actionPrefix = "MULTIACTIONBAR6BUTTON", buttonPrefix ="MultiBar6Button",          start = 157,last = 168},--Action Bar 7
    { actionPrefix = "MULTIACTIONBAR7BUTTON", buttonPrefix ="MultiBar7Button",          start = 169,last = 180},--Action Bar 8
    { actionPrefix = "SHAPESHIFTBUTTON",      buttonPrefix ="StanceButton",             start = 901,last = 907},--Stance Bar. Dummy slots
}

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

local bindingOverrides = {
    ["Mouse Button "]     = "MB",
    ["Num Pad "]          = "NP",
    ["Middle Mouse"]      = "MMB",
    ["Mouse Wheel Up"]    = "MWU",
    ["Mouse Wheel Down"]  = "MWD",
    ["Capslock"]          = "Caps",
    ["Backspace"]         = "BkSp",
    ["Spacebar"]          = "Spbar",
    ["Delete"]            = "Del",
    ["Page Up"]           = "PgUp",
    ["Page Down"]         = "PgDn",
    ["Insert"]            = "Ins",
    ["Num Lock"]          = "NmLk",
    ["Left Arrow"]        = "Left",
    ["Right Arrow"]       = "Right",
    ["Up Arrow"]          = "Up",
    ["Down Arrow"]        = "Down",
}


local function IsRelevantAction(actionType, subType, slot)
    return (actionType == "macro" and subType == "spell")
        or (actionType == "spell" and subType ~= "assistedcombat")
        or (slot > 900)
end

local function GetBindingForAction(action)
    if not action then return nil end

    local key = GetBindingKey(action)
    if not key then return nil end

    local text = GetBindingText(key,"KEY_")
    if not text or text == "" then return nil end

    local count = 0
    for binding, abbrv in pairs(bindingOverrides) do
        text, count = text:gsub(binding, abbrv, 1)
        if count > 0 then return text end
    end

    return text
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

local function GetBindingForSlots(slots, spellID)
    if not slots then return end

    for _, slot in ipairs(slots) do
        local actionType, _, subType = GetActionInfo(slot)
        if IsRelevantAction(actionType, subType, slot) then
            local defaultAction = LookupActionBySlot[slot]
            local addonAction = BarAddonLoaded and AddonLookupActionBySlot[slot]

            local buttonName = BarAddonLoaded and AddonLookupButtonByAction[addonAction] or LookupButtonByAction[defaultAction]
            local buttonFrame = _G[buttonName]
            
            local text = BarAddonLoaded and GetBindingForAction(addonAction)

            if buttonFrame and buttonFrame.action ~= slot and AddonOverrideActionBySlot and AddonOverrideButtonByAction then
                local ovrAction = AddonOverrideActionBySlot[slot]
                local ovrButtonName = AddonOverrideButtonByAction[ovrAction]
                local ovrText = GetBindingForAction(ovrAction)

                if ovrText then
                    buttonFrame = _G[ovrButtonName]
                    text = ovrText
                end
            end

            if not text then
                text = GetBindingForAction(defaultAction)
            end 

            if buttonFrame and (slot > 900 or
               buttonFrame.action == slot) and text then
                return text
            end
        end
    end
end

local function GetKeyBindForSpellID(spellID)
    local baseSpellID = FindBaseSpellByID(spellID)

    local slots = C_ActionBar.FindSpellActionButtons(baseSpellID)
    
    local text = GetBindingForSlots(slots, spellID)
    if text then return text end
    
    slots = GetStanceSlotBySpellID(spellID)

    text = GetBindingForSlots(slots, spellID)
    if text then return text end
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
    if C_AddOns.IsAddOnLoaded("Dominos") then
        local AddonActionSlotMap = {
            { actionPrefix = "ACTIONBUTTON",          buttonPrefix ="DominosActionButton",        start = 1,  last = 12}, --Bar 1 
            { actionPrefix = "ACTIONBUTTON",           buttonPrefix ="DominosActionButton",       start = 13, last = 24}, --Bar 2
            { actionPrefix = "MULTIACTIONBAR3BUTTON",   buttonPrefix ="MultiBarRightButton",      start = 25, last = 36}, --Bar 3
            { actionPrefix = "MULTIACTIONBAR4BUTTON",   buttonPrefix ="MultiBarLeftButton",       start = 37, last = 48}, --Bar 4 
            { actionPrefix = "MULTIACTIONBAR2BUTTON",   buttonPrefix ="MultiBarBottomRightButton",start = 49, last = 60}, --Bar 5 
            { actionPrefix = "MULTIACTIONBAR1BUTTON",   buttonPrefix ="MultiBarBottomLeftButton", start = 61, last = 72}, --Bar 6
            { actionPrefix = "ACTIONBUTTON",           buttonPrefix ="DominosActionButton",       start = 73, last = 84}, --Bar 7
            { actionPrefix = "ACTIONBUTTON",           buttonPrefix ="DominosActionButton",       start = 85, last = 96}, --Bar 8
            { actionPrefix = "ACTIONBUTTON",           buttonPrefix ="DominosActionButton",       start = 97, last = 108},--Bar 9
            { actionPrefix = "ACTIONBUTTON",           buttonPrefix ="DominosActionButton",       start = 109,last = 120},--Bar 10
            { actionPrefix = "ACTIONBUTTON",           buttonPrefix ="DominosActionButton",       start = 121,last = 132},--Bar 11
            { actionPrefix = "MULTIACTIONBAR5BUTTON",   buttonPrefix ="MultiBar5Button",          start = 145,last = 156},--Bar 12
            { actionPrefix = "MULTIACTIONBAR6BUTTON",   buttonPrefix ="MultiBar6Button",          start = 157,last = 168},--Bar 13
            { actionPrefix = "MULTIACTIONBAR7BUTTON",   buttonPrefix ="MultiBar7Button",          start = 169,last = 180},--Bar 14
            { actionPrefix = "SHAPESHIFTBUTTON",        buttonPrefix ="DominosStanceButton",      start = 901,last = 907},--Stance Bar. Dummy slots
        }

        local OverrideActionPattern = "CLICK %s%s:HOTKEY"
        local OverrideButtonPrefix = "DominosActionButton"
        local OverrideSlotMap = {
            { start = 13, last = 24}, --Bar 2
            { start = 73, last = 84}, --Bar 7
            { start = 85, last = 96}, --Bar 8
            { start = 97, last = 108},--Bar 9
            { start = 109,last = 120},--Bar 10
            { start = 121,last = 132},--Bar 11
        }

        for _, info in ipairs(AddonActionSlotMap) do
            for slot = info.start, info.last do
                local id = slot - info.start + 1
                AddonLookupActionBySlot[slot] = info.actionPrefix..id
                AddonLookupButtonByAction[AddonLookupActionBySlot[slot]] = info.buttonPrefix..id
            end
        end

        AddonOverrideActionBySlot = {}
        AddonOverrideButtonByAction = {}
        for _, info in ipairs(OverrideSlotMap) do
            for slot = info.start, info.last do
                AddonOverrideActionBySlot[slot] = OverrideActionPattern:format(OverrideButtonPrefix,slot)
                AddonOverrideButtonByAction[AddonOverrideActionBySlot[slot]] = OverrideButtonPrefix..slot
            end
        end

        HasDominos  = true
    elseif C_AddOns.IsAddOnLoaded("Bartender4") then
        local AddonActionSlotMap = {
            { actionPattern = "CLICK %s%s:Keybind", buttonPrefix ="BT4Button", id_start =  1,  start = 1,  last = 72}, --Action Bars
            { actionPattern = "CLICK %s%s:Keybind", buttonPrefix ="BT4Button", id_start =  1,  start = 73, last = 84}, --Class Bar 1
            { actionPattern = "CLICK %s%s:Keybind", buttonPrefix ="BT4Button", id_start =  1,  start = 85, last = 96}, --Class Bar 2
            { actionPattern = "CLICK %s%s:Keybind", buttonPrefix ="BT4Button", id_start =  1,  start = 97, last = 108},--Class Bar 3
            { actionPattern = "CLICK %s%s:Keybind", buttonPrefix ="BT4Button", id_start =  1,  start = 109,last = 120},--Class Bar 4
            { actionPattern = "CLICK %s%s:Keybind", buttonPrefix ="BT4Button", id_start =  1,  start = 121,last = 132},--(Skyriding)
            { actionPattern = "CLICK %s%s:Keybind", buttonPrefix ="BT4Button", id_start = 145, start = 145,last = 180},
            { actionPattern = "CLICK %s%s:LeftButton", buttonPrefix ="BT4StanceButton", id_start = 1, start = 901,last = 907}, --Stance Bar. Dummy slots
        }

        for _, info in ipairs(AddonActionSlotMap) do
            local id = info.id_start
            for slot = info.start, info.last do
                local t = id
                if _G[info.buttonPrefix..slot] then 
                    t = slot
                end
                AddonLookupActionBySlot[slot] = info.actionPattern:format(info.buttonPrefix,t)
                AddonLookupButtonByAction[AddonLookupActionBySlot[slot]] = info.buttonPrefix..t
                id = id + 1
            end
        end

        HasBartender = true
    end

    BarAddonLoaded = HasBartender or HasDominos

    for _, info in ipairs(DefaultActionSlotMap) do
        for slot = info.start, info.last do
            local index = slot - info.start + 1
            LookupActionBySlot[slot] = info.actionPrefix .. index
            LookupButtonByAction[LookupActionBySlot[slot]] = info.buttonPrefix .. index
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

    self:RegisterForDrag("LeftButton")

    self.spellID = 61304
    self.combatUpdateInterval = tonumber(C_CVar.GetCVar("assistedCombatIconUpdateRate")) or 0.3
    self.lastUpdateTime = 0
    self.updateInterval = 1

    self.Keybind:SetParent(self.Overlay)

    if Masque then
        self:SetBackdrop({
            edgeFile = "Interface\\Buttons\\WHITE8x8",
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
    if self.isTicking then return end

    self.isTicking = true
    self.spellID = C_AssistedCombat.GetNextCastSpell()
    self:Tick()
end

function AssistedCombatIconMixin:Stop()
    self.isTicking = false
    self:SetShown(false) 
end

function AssistedCombatIconMixin:Tick()
    if not self.isTicking then return end
    local interval = InCombatLockdown() and self.combatUpdateInterval or self.updateInterval

    self:UpdateVisibility()

    if self:IsShown() then 
        local nextSpell = C_AssistedCombat.GetNextCastSpell()
        if nextSpell and nextSpell ~= 0 and nextSpell ~= self.spellID then
            C_Spell.EnableSpellRangeCheck(self.spellID, false)
            self.spellID = nextSpell
            self:UpdateCooldown()
        end
    end
    
    self:Update()

    C_Timer.After(interval, function()
        self:Tick()
    end)
end

function AssistedCombatIconMixin:UpdateVisibility()
    local db = self.db
    local display = db.display

    if not self.isTicking then self:SetShown(false) end

    if display.ALWAYS or not db.locked then
        self:SetShown(true)
        return
    end

    if     (display.HOSTILE_TARGET and not UnitCanAttack("player", "target"))
        or (display.IN_COMBAT and not InCombatLockdown())
        or (display.HideInVehicle and UnitInVehicle("player"))
        or (display.HideAsHealer and UnitGroupRolesAssigned("player") == "HEALER")
        or (display.HideOnMount and IsMounted())
    then
        self:SetShown(false)
        return
    end

    self:SetShown(true)
end

function AssistedCombatIconMixin:Update()
    if not self.spellID or not self:IsShown() then return end

    local db = self.db
    local spellID = self.spellID

    local text = db.Keybind.show and GetKeyBindForSpellID(spellID) or ""
    self.Keybind:SetText(text)

    self.Icon:SetTexture(C_Spell.GetSpellTexture(spellID))

    if not db.locked then
        self:SetBackdropBorderColor(Colors.UNLOCKED:GetRGBA())
    else
        local bc = db.border.color
        self:SetBackdropBorderColor(bc.r, bc.g, bc.b, db.border.show and 1 or 0)
    end

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
    self:ClearAllPoints()
    self:Lock(db.locked)
    self:SetSize(db.iconSize, db.iconSize)

    local parent = _G[db.position.parent] or UIParent
    self:SetParent(parent)
    self:SetScale(UIParent:GetEffectiveScale()/parent:GetEffectiveScale())
    self:SetPoint(db.position.point, db.position.parent, db.position.point, db.position.X, db.position.Y)

    self:SetFrameStrata(frameStrata[db.position.strata])
    self:Raise()

    local kb = db.Keybind

    self.Keybind:ClearAllPoints()
    self.Keybind:SetPoint(kb.point, self, kb.point, kb.X, kb.Y)
    self.Keybind:SetTextColor(kb.fontColor.r, kb.fontColor.g, kb.fontColor.b, kb.fontColor.a)
    self.Keybind:SetFont(LSM:Fetch(LSM.MediaType.FONT, kb.font), kb.fontSize, kb.fontOutline and "OUTLINE" or "")

    if (not Masque) or (self.MSQGroup and self.MSQGroup.db.Disabled) then
        local border = db.border
        self.Icon:SetPoint("TOPLEFT", border.thickness, -border.thickness)
        self.Icon:SetPoint("BOTTOMRIGHT", -border.thickness, border.thickness)
        self.Icon:SetTexCoord(0.06,0.94,0.06,0.94)

        self.Cooldown:SetPoint("TOPLEFT", border.thickness, -border.thickness)
        self.Cooldown:SetPoint("BOTTOMRIGHT", -border.thickness, border.thickness)

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
    
    self:SetAlpha(db.alpha)
    self:UpdateVisibility()
    self:Update()
end

function AssistedCombatIconMixin:UpdateCooldown()
    local spellID = self.spellID
    if not self.db.showCooldownSwipe or not spellID or spellID == 0 then return end

    if spellID == 375982 then --Temporary workaround for Primoridal Storm
        spellID = FindSpellOverrideByID(spellID)
    end

    local cdInfo = C_Spell.GetSpellCooldown(spellID)

    if cdInfo then
        self.Cooldown.currentCooldownType = COOLDOWN_TYPE_NORMAL
        self.Cooldown:SetDrawEdge(self.db.cooldown.edge)
        self.Cooldown:SetDrawBling(self.db.cooldown.bling)
        self.Cooldown:SetEdgeTexture("Interface\\Cooldown\\UI-HUD-ActionBar-SecondaryCooldown")
        self.Cooldown:SetSwipeColor(0, 0, 0)
        self.Cooldown:SetCooldown(cdInfo.startTime, cdInfo.duration, cdInfo.modRate)
    else
        self.Cooldown:Clear()
    end
end

function AssistedCombatIconMixin:Lock(lock)
    self:EnableMouse(not lock)
end

function AssistedCombatIconMixin:OnDragStart()
    if self.db.locked then return end
    self:StartMoving()
end

function AssistedCombatIconMixin:OnDragStop()
    self:StopMovingOrSizing()

    local point, relativeTo, relativePoint, xOfs, yOfs = self:GetPoint()
    local strata = self.db.position.strata
    self.db.position = {
        strata = strata,
        point = point,
        parent = self:GetParent() and self:GetParent():GetName() or relativeTo,
        relativePoint = relativePoint,
        X = math.floor(xOfs+0.5),
        Y = math.floor(yOfs+0.5),
    }

    ACR:NotifyChange(addonName)
end