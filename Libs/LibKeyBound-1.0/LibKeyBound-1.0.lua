--[[
Name: LibKeyBound-1.0
Revision: $Rev: 124 $
Author(s): Gello, Maul, Toadkiller, Tuller
Website: http://www.wowace.com/wiki/LibKeyBound-1.0
Documentation: http://www.wowace.com/wiki/LibKeyBound-1.0
SVN: http://svn.wowace.com/wowace/trunk/LibKeyBound-1.0
Description: An intuitive keybindings system: mouseover frame, click keys or buttons.
Dependencies: CallbackHandler-1.0

##Heavily customized for saci just for the ToShortKey function.
--]]

local MAJOR = 'LibKeyBound-CUSTOM'
local MINOR = 100000

--[[
	LibKeyBound-1.0
		ClickBinder by Gello and TrinityBinder by Maul -> keyBound by Tuller -> LibKeyBound library by Toadkiller

		Functions needed to implement
			button:GetHotkey() - returns the current hotkey assigned to the given button

		Functions to implement if using a custom keybindings system:
			button:SetKey(key) - binds the given key to the given button
			button:FreeKey(key) - unbinds the given key from all other buttons
			button:ClearBindings() - removes all keys bound to the given button
			button:GetBindings() - returns a string listing all bindings of the given button
			button:GetActionName() - what we're binding to, used for printing
--]]

local LibKeyBound, oldminor = LibStub:NewLibrary(MAJOR, MINOR)

if not LibKeyBound then return end -- no upgrade needed

local NUM_MOUSE_BUTTONS = 31

local L = {

	-- This is the short display version you see on the Button
	["Alt"] = "A",
	["Ctrl"] = "C",
	["Shift"] = "S",
	["Command"] = "M", -- Blizzard uses 'm' for the command key (META key)
	["NumPad"] = "N",

	["Backspace"] = "BS",
	["Button1"] = "B1",
	["Button2"] = "B2",
	["Button3"] = "B3",
	["Button4"] = "B4",
	["Button5"] = "B5",
	["Button6"] = "B6",
	["Button7"] = "B7",
	["Button8"] = "B8",
	["Button9"] = "B9",
	["Button10"] = "B10",
	["Button11"] = "B11",
	["Button12"] = "B12",
	["Button13"] = "B13",
	["Button14"] = "B14",
	["Button15"] = "B15",
	["Button16"] = "B16",
	["Button17"] = "B17",
	["Button18"] = "B18",
	["Button19"] = "B19",
	["Button20"] = "B20",
	["Button21"] = "B21",
	["Button22"] = "B22",
	["Button23"] = "B23",
	["Button24"] = "B24",
	["Button25"] = "B25",
	["Button26"] = "B26",
	["Button27"] = "B27",
	["Button28"] = "B28",
	["Button29"] = "B29",
	["Button30"] = "B30",
	["Button31"] = "B31",
	["Capslock"] = "Cp",
	["Clear"] = "Cl",
	["Delete"] = "Del",
	["End"] = "En",
	["Home"] = "HM",
	["Insert"] = "Ins",
	["Mouse Wheel Down"] = "WD",
	["Mouse Wheel Up"] = "WU",
	["Num Lock"] = "NL",
	["Page Down"] = "PD",
	["Page Up"] = "PU",
	["Scroll Lock"] = "SL",
	["Spacebar"] = "Sp",
	["Tab"] = "Tb",

	["Down Arrow"] = "Dn",
	["Left Arrow"] = "Lf",
	["Right Arrow"] = "Rt",
	["Up Arrow"] = "Up",
}

--[[
Arguments:
	string - the keyString to shorten

Returns:
	string - the shortened displayString

Example:
	local key1 = GetBindingKey(button:GetName())
	local displayKey = LibKeyBound:ToShortKey(key1)
	return displayKey

Notes:
	* Shortens the key text (returned from GetBindingKey etc.)
	* Result is suitable for display on a button
	* Can be used for your button:GetHotkey() return value
--]]
function LibKeyBound:ToShortKey(key)
	if key then
		key = key:upper()
		key = key:gsub(' ', '')
		key = key:gsub('ALT%-', L['Alt'])
		key = key:gsub('CTRL%-', L['Ctrl'])
		key = key:gsub('SHIFT%-', L['Shift'])
		key = key:gsub('META%-', L['Command'])
		key = key:gsub('NUMPAD', L['NumPad'])

		key = key:gsub('PLUS', '%+')
		key = key:gsub('MINUS', '%-')
		key = key:gsub('MULTIPLY', '%*')
		key = key:gsub('DIVIDE', '%/')
		key = key:gsub('DECIMAL', '%.')

		key = key:gsub('BACKSPACE', L['Backspace'])

		for i = 1, NUM_MOUSE_BUTTONS do
			key = key:gsub('BUTTON' .. i, L['Button' .. i])
		end

		key = key:gsub('CAPSLOCK', L['Capslock'])
		key = key:gsub('CLEAR', L['Clear'])
		key = key:gsub('DELETE', L['Delete'])
		key = key:gsub('END', L['End'])
		key = key:gsub('HOME', L['Home'])
		key = key:gsub('INSERT', L['Insert'])
		key = key:gsub('MOUSEWHEELDOWN', L['Mouse Wheel Down'])
		key = key:gsub('MOUSEWHEELUP', L['Mouse Wheel Up'])
		key = key:gsub('NUMLOCK', L['Num Lock'])
		key = key:gsub('PAGEDOWN', L['Page Down'])
		key = key:gsub('PAGEUP', L['Page Up'])
		key = key:gsub('SCROLLLOCK', L['Scroll Lock'])
		key = key:gsub('SPACEBAR', L['Spacebar'])
		key = key:gsub('SPACE', L['Spacebar'])
		key = key:gsub('TAB', L['Tab'])

		key = key:gsub('DOWNARROW', L['Down Arrow'])
		key = key:gsub('LEFTARROW', L['Left Arrow'])
		key = key:gsub('RIGHTARROW', L['Right Arrow'])
		key = key:gsub('UPARROW', L['Up Arrow'])

		key = key:gsub('DOWN', L['Down Arrow'])
		key = key:gsub('LEFT', L['Left Arrow'])
		key = key:gsub('RIGHT', L['Right Arrow'])
		key = key:gsub('UP', L['Up Arrow'])
		
		return key
	end
end