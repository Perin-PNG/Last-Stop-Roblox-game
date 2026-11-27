--!strict
-- Every player action, on keyboard, gamepad and touch, in one place. Built on the Input
-- Action System (InputContext, InputAction, InputBinding). If that fails to set up for any
-- reason, it falls back to UserInputService so the game still plays.
--
-- Controllers listen with InputController.on(action, pressed, released). Touch buttons are
-- big, sit within thumb reach on the right of the screen, and only show on touch devices.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = script.Parent.Parent
local Gui = require(Client:WaitForChild("Gui"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared:WaitForChild("Log"))

local InputController = {}

type ActionDef = {
	name: string,
	keys: { Enum.KeyCode },
	pad: { Enum.KeyCode },
	touch: string?, -- touch button label
	touchPos: UDim2?,
}

local K = Enum.KeyCode

local ACTIONS: { ActionDef } = {
	{
		name = "Sprint",
		keys = { K.LeftShift },
		pad = { K.ButtonL3 },
		touch = "RUN",
		touchPos = UDim2.new(1, -96, 1, -250),
	},
	{
		name = "Crouch",
		keys = { K.C, K.LeftControl },
		pad = { K.ButtonB },
		touch = "DUCK",
		touchPos = UDim2.new(1, -176, 1, -170),
	},
	{
		name = "Flashlight",
		keys = { K.F },
		pad = { K.ButtonY },
		touch = "LIGHT",
		touchPos = UDim2.new(1, -176, 1, -250),
	},
	{
		name = "Use",
		keys = { K.MouseLeftButton },
		pad = { K.ButtonR2 },
		touch = "USE",
		touchPos = UDim2.new(1, -256, 1, -170),
	},
	{
		name = "Throw",
		keys = { K.MouseRightButton },
		pad = { K.ButtonL2 },
		touch = "THROW",
		touchPos = UDim2.new(1, -256, 1, -250),
	},
	{ name = "Drop", keys = { K.G }, pad = { K.DPadDown } },
	{ name = "Ping", keys = { K.Q }, pad = { K.DPadUp }, touch = "PING", touchPos = UDim2.new(1, -96, 1, -330) },
	{ name = "Slot1", keys = { K.One }, pad = {} },
	{ name = "Slot2", keys = { K.Two }, pad = {} },
	{ name = "Slot3", keys = { K.Three }, pad = {} },
	{ name = "Slot4", keys = { K.Four }, pad = {} },
	{ name = "SlotNext", keys = {}, pad = { K.ButtonR1 } },
	{ name = "SlotPrev", keys = {}, pad = { K.ButtonL1 } },
}

type Listener = { pressed: (() -> ())?, released: (() -> ())? }
local listeners: { [string]: { Listener } } = {}
local down: { [string]: boolean } = {}
local touchButtons: { [string]: TextButton } = {}
local usingFallback = false

local function fire(name: string, isDown: boolean)
	if down[name] == isDown then
		return
	end
	down[name] = isDown
	local list = listeners[name]
	if not list then
		return
	end
	for _, l in list do
		local fn = if isDown then l.pressed else l.released
		if fn then
			task.spawn(fn)
		end
	end
end

function InputController.on(name: string, pressed: (() -> ())?, released: (() -> ())?)
	local list = listeners[name]
	if not list then
		list = {}
		listeners[name] = list
	end
	table.insert(list, { pressed = pressed, released = released })
end

function InputController.isDown(name: string): boolean
	return down[name] == true
end

function InputController.touchButton(name: string): TextButton?
	return touchButtons[name]
end

function InputController.isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- Show or hide one touch button (e.g. hide THROW while holding nothing throwable).
function InputController.setTouchVisible(name: string, visible: boolean)
	local b = touchButtons[name]
	if b then
		b.Visible = visible and InputController.isTouch()
	end
end

local function buildTouch()
	local sg = Gui.screen("TouchControls", 5)
	for _, def in ACTIONS do
		if def.touch then
			local b = Instance.new("TextButton")
			b.Name = def.name
			b.Size = UDim2.fromOffset(72, 72)
			b.Position = def.touchPos or UDim2.new(1, -96, 1, -96)
			b.AnchorPoint = Vector2.new(0, 0)
			b.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
			b.BackgroundTransparency = 0.35
			b.Text = def.touch
			b.TextColor3 = Gui.Colors.Text
			b.Font = Gui.FontBold
			b.TextScaled = true
			b.AutoButtonColor = true
			b.Visible = InputController.isTouch()
			Gui.corner(b, 36)
			Gui.stroke(b, Color3.fromRGB(90, 90, 100), 2)
			local c = Instance.new("UITextSizeConstraint")
			c.MaxTextSize = 16
			c.Parent = b
			b.Parent = sg
			touchButtons[def.name] = b
		end
	end
	UserInputService.LastInputTypeChanged:Connect(function()
		for _, b in touchButtons do
			b.Visible = InputController.isTouch()
		end
	end)
end

local function buildActionSystem(): boolean
	local ok, err = pcall(function()
		local context = Instance.new("InputContext")
		context.Name = "GameInput"
		context.Priority = 100
		for _, def in ACTIONS do
			local action = Instance.new("InputAction")
			action.Name = def.name
			action.Type = Enum.InputActionType.Bool
			for _, key in def.keys do
				local binding = Instance.new("InputBinding")
				binding.KeyCode = key
				binding.Parent = action
			end
			for _, key in def.pad do
				local binding = Instance.new("InputBinding")
				binding.KeyCode = key
				binding.Parent = action
			end
			local button = touchButtons[def.name]
			if button then
				local binding = Instance.new("InputBinding")
				binding.UIButton = button
				binding.Parent = action
			end
			local name = def.name
			action.Pressed:Connect(function()
				fire(name, true)
			end)
			action.Released:Connect(function()
				fire(name, false)
			end)
			action.Parent = context
		end
		context.Parent = Players.LocalPlayer:WaitForChild("PlayerScripts")
	end)
	if not ok then
		Log.warn("Input", "Input Action System unavailable, using fallback", err)
	end
	return ok
end

local function buildFallback()
	usingFallback = true
	local byKey: { [Enum.KeyCode]: string } = {}
	for _, def in ACTIONS do
		for _, key in def.keys do
			byKey[key] = def.name
		end
		for _, key in def.pad do
			byKey[key] = def.name
		end
	end
	local function keyOf(input: InputObject): Enum.KeyCode
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			return K.MouseLeftButton
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			return K.MouseRightButton
		end
		return input.KeyCode
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		local name = byKey[keyOf(input)]
		if name and not processed then
			fire(name, true)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local name = byKey[keyOf(input)]
		if name then
			fire(name, false)
		end
	end)
	for name, button in touchButtons do
		button.MouseButton1Down:Connect(function()
			fire(name, true)
		end)
		button.MouseButton1Up:Connect(function()
			fire(name, false)
		end)
		button.MouseLeave:Connect(function()
			fire(name, false)
		end)
	end
end

function InputController.fallback(): boolean
	return usingFallback
end

function InputController:Init()
	buildTouch()
	if not buildActionSystem() then
		buildFallback()
	end
end

return InputController
