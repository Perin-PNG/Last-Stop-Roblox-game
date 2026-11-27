--!strict
-- Studio-only debug panel (F8 or the DBG button). Buttons send Debug commands; the
-- server ignores them outside Studio. Other controllers can add buttons with
-- DebugController.addButton.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Client = script.Parent.Parent
local Gui = require(Client:WaitForChild("Gui"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local DebugController = {}

local panel: Frame?
local list: ScrollingFrame?
local seedBox: TextBox?

function DebugController.send(action: string, arg: any?)
	Net.event("Debug"):FireServer(action, arg)
end

function DebugController.addButton(label: string, action: string, arg: (() -> any)?)
	if not list then
		return
	end
	Gui.button(list, label, function()
		DebugController.send(action, if arg then arg() else nil)
	end, { Size = UDim2.new(1, -8, 0, 30) })
end

local function build()
	local sg = Gui.screen("DebugPanel", 40)
	local toggle = Gui.button(sg, "DBG", function()
		if panel then
			panel.Visible = not panel.Visible
		end
	end, {
		Size = UDim2.fromOffset(48, 28),
		Position = UDim2.new(0, 8, 0.5, -14),
		BackgroundColor3 = Color3.fromRGB(80, 30, 30),
	})
	local _ = toggle
	local p = Gui.frame(sg, {
		Name = "Panel",
		Size = UDim2.fromOffset(210, 360),
		Position = UDim2.new(0, 60, 0.5, -180),
		Visible = false,
	})
	Gui.corner(p)
	Gui.pad(p, 6)
	panel = p
	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, 0, 0, 28)
	box.PlaceholderText = "seed"
	box.Text = ""
	box.TextScaled = true
	box.Font = Gui.FontMono
	box.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
	box.TextColor3 = Gui.Colors.Text
	box.ClearTextOnFocus = false
	box.Parent = p
	seedBox = box
	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, 0, 1, -34)
	scroll.Position = UDim2.fromOffset(0, 34)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 4
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = p
	Gui.list(scroll, 4)
	list = scroll
end

function DebugController:Init()
	if not RunService:IsStudio() then
		return
	end
	build()
	DebugController.addButton("Set seed + restart", "seed", function()
		return if seedBox then tonumber(seedBox.Text) else nil
	end)
	DebugController.addButton("Skip stop / ride", "skip")
	DebugController.addButton("God mode", "god")
	DebugController.addButton("Teleport into bus", "tobus")
	DebugController.addButton("Start a run", "start")
	DebugController.addButton("End the run", "end")
	DebugController.addButton("Fill fuel", "fuel")
	DebugController.addButton("Bank a fragment", "fragment")
	DebugController.addButton("+500 Tokens (and XP)", "tokens")
	DebugController.addButton("Reset First Ride and hints", "firstride")
	DebugController.addButton("Force anomaly (id in seed box)", "anomaly", function()
		return if seedBox and seedBox.Text ~= "" then seedBox.Text else nil
	end)
	DebugController.addButton("Spawn entity (id in seed box)", "entity", function()
		return if seedBox and seedBox.Text ~= "" then seedBox.Text else "clerk"
	end)
end

function DebugController:Start()
	if not RunService:IsStudio() then
		return
	end
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.F8 and panel then
			panel.Visible = not panel.Visible
		end
	end)
end

return DebugController
