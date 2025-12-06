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

local LookupActionBySlot = {}
local LookupButtonByAction = {}

local DefaultActionSlotMap = {
    --Default UI Slot mapping https://warcraft.wiki.gg/wiki/Action_slot
    --Eventually will look at making sure other addons work...
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

local function IsRelevantAction(actionType, subType)
    return (actionType == "spell" and subType ~= "assistedcombat")
end

local function GetBindingForAction(action)
    if not action then return nil end

    local key = GetBindingKey(action)
    if not key then return nil end

    local text = GetBindingText(key, "KEY_")
    if not text or text == "" then return nil end

    text = text:gsub("Mouse Button ", "MB", 1)
    text = text:gsub("Middle Mouse", "MMB", 1)

    return text
end

local function GetKeyBindForSpellID(spellID)
    local baseSpellID = FindBaseSpellByID(spellID)

    local slots = C_ActionBar.FindSpellActionButtons(baseSpellID)
    if not slots then return end

    for _, slot in ipairs(slots) do
        local actionType, _, subType = GetActionInfo(slot)
        if IsRelevantAction(actionType, subType) then
            local action = LookupActionBySlot[slot]
            local buttonName = LookupButtonByAction[action]
            local button = _G[buttonName]
            if button and button.action == slot then
                local text = GetBindingForAction(action)
                if text then 
                    return text
                end
            end
        end
    end
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
    for _, info in ipairs(DefaultActionSlotMap) do
        for id = info.start, info.last do
            local index = id - info.start + 1
            LookupActionBySlot[id] = info.actionPrefix .. index
            LookupButtonByAction[LookupActionBySlot[id]] = info.buttonPrefix .. index
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

    self:RegisterForDrag("LeftButton")

    self.spellID = 61304
    self.combatUpdateInterval = tonumber(C_CVar.GetCVar("assistedCombatIconUpdateRate")) or 0.3
    self.lastUpdateTime = 0
    self.updateInterval = 1

    self.Keybind:SetParent(self.Overlay)
    self:SetAttribute("ignoreFramePositionManager", true)

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
    self.db = addon.db.profile
    self:ApplyOptions()
end

function AssistedCombatIconMixin:OnEvent(event, ...)
    if event == "SPELL_UPDATE_COOLDOWN" then
        self:UpdateCooldown()
    elseif event == "SPELL_RANGE_CHECK_UPDATE" then
        local spellID, inRange, checksRange = ...
        if spellID ~= self.spellID then return end
        self.spellOutOfRange = checksRange == true and inRange == false
        self:Update()
    elseif event == "PLAYER_REGEN_ENABLED" and self.db.displayMode == "IN_COMBAT" then
        self:SetShown(false)
    elseif event == "PLAYER_REGEN_DISABLED" and self.db.displayMode == "IN_COMBAT" then
        self:SetShown(true)
    elseif event == "PLAYER_TARGET_CHANGED" and self.db.displayMode == "HOSTILE_TARGET" then
        self:SetShown(UnitExists("target") and UnitCanAttack("player", "target"))
    elseif event == "PLAYER_LOGIN" then
        LoadActionSlotMap()
    elseif event == "CVAR_UPDATE" then 
        local arg1, arg2 = ...
        if arg1 =="assistedCombatIconUpdateRate" then
            self.combatUpdateInterval = tonumber(arg2) or self.combatUpdateInterval
        end
    end
end

function AssistedCombatIconMixin:OnUpdate(elapsed)
    local interval = InCombatLockdown() and self.combatUpdateInterval or self.updateInterval
    local timeLeft = self.lastUpdateTime - elapsed
    if timeLeft > 0 then 
        self.lastUpdateTime = timeLeft
        return
    end
    self.lastUpdateTime = interval

    local nextSpell = C_AssistedCombat.GetNextCastSpell()
    if nextSpell ~= self.spellID and nextSpell ~= 0 and nextSpell ~= nil then
        C_Spell.EnableSpellRangeCheck(self.spellID, false)
        self.spellID = nextSpell
        self:Update()
        self:UpdateCooldown()
    end
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
    
    local show =
        not db.locked or
        db.displayMode == "ALWAYS" or
        (db.displayMode == "HOSTILE_TARGET" and UnitCanAttack("player", "target")) or
        (db.displayMode == "IN_COMBAT" and InCombatLockdown())
    self:SetShown(show)

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
        parent = relativeTo,
        relativePoint = relativePoint,
        X = math.floor(xOfs+0.5),
        Y = math.floor(yOfs+0.5),
    }

    ACR:NotifyChange(addonName)
end