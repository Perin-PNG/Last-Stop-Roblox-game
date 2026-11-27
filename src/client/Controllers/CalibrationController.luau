--!strict
-- Brightness calibration: on first launch (and from Settings), a dark symbol on a black
-- panel. Adjust until the symbol is barely visible. CameraController applies the result.

local Client = script.Parent.Parent
local Gui = require(Client:WaitForChild("Gui"))
local State = require(Client:WaitForChild("State"))
local Registry = require(Client:WaitForChild("Registry"))

local CalibrationController = {}

local Settings: any
local panel: Frame
local valueLabel: TextLabel

local function refresh()
	local b = (Settings.get("brightness") :: number?) or 0
	valueLabel.Text = string.format("Brightness %+d", math.floor(b * 100 + 0.5))
end

local function nudge(delta: number)
	local b = (Settings.get("brightness") :: number?) or 0
	Settings.set("brightness", math.clamp(math.floor((b + delta) * 100 + 0.5) / 100, -0.2, 0.2))
	refresh()
end

function CalibrationController.show()
	refresh()
	panel.Visible = true
end

function CalibrationController:Init()
	Settings = Registry.get("SettingsController")
	local screen = Gui.screen("Calibration", 20, true)
	panel = Gui.frame(screen, {
		Name = "Panel",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0,
		Visible = false,
	})
	Gui.label(panel, "Adjust until the symbol is barely visible", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.12),
		Size = UDim2.new(0.8, 0, 0, 34),
		Font = Gui.FontBold,
		MaxText = 24,
	})
	-- The symbol: the bus route's 9N mark, a shade above black.
	local symbol = Gui.label(panel, "9N", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(220, 160),
		Font = Gui.FontBold,
		MaxText = 140,
		TextColor3 = Color3.fromRGB(14, 14, 16),
	})
	symbol.Name = "Symbol"
	valueLabel = Gui.label(panel, "", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.62),
		Size = UDim2.fromOffset(240, 28),
		MaxText = 18,
		TextColor3 = Gui.Colors.Dim,
	})
	local row = Gui.frame(panel, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.7),
		Size = UDim2.fromOffset(360, 48),
		BackgroundTransparency = 1,
	})
	Gui.list(row, 12, true).HorizontalAlignment = Enum.HorizontalAlignment.Center
	Gui.button(row, "Darker", function()
		nudge(-0.02)
	end, { Size = UDim2.fromOffset(100, 44) })
	Gui.button(row, "Brighter", function()
		nudge(0.02)
	end, { Size = UDim2.fromOffset(100, 44) })
	Gui.button(row, "Done", function()
		panel.Visible = false
		Settings.set("calibrated", true)
	end, { Size = UDim2.fromOffset(100, 44), BackgroundColor3 = Color3.fromRGB(40, 140, 70) })
end

function CalibrationController:Start()
	local function maybeFirstLaunch()
		if Settings.loaded and Settings.get("calibrated") ~= true and State.mine("State") == "Lobby" then
			CalibrationController.show()
		end
	end
	Settings.changed:Connect(function(key: string)
		if key == "loaded" then
			maybeFirstLaunch()
		end
	end)
	State.watchMine("State", function()
		maybeFirstLaunch()
	end)
end

return CalibrationController
