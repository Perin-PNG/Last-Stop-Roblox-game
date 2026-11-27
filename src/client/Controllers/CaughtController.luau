--!strict
-- Being caught (plan: "Being caught is static and a fade"). When this player goes Down,
-- the screen breaks into TV static for a moment and fades to dark, then clears to the
-- Downed view. Reduce flashing (or Reduced jumpscares) swaps the static for a plain fade.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Client = script.Parent.Parent
local Gui = require(Client:WaitForChild("Gui"))
local Notify = require(Client:WaitForChild("Notify"))
local Registry = require(Client:WaitForChild("Registry"))

local CaughtController = {}

local ROWS = 18 -- static bands
local STATIC_SECONDS = 0.7

local screen: ScreenGui
local veil: Frame
local bands: { Frame } = {}
local playing = false

local function gentle(): boolean
	local settings = Registry.find("SettingsController")
	return settings ~= nil and (settings.get("reduceFlashing") == true or settings.get("reduceScares") == true)
end

local function play()
	if playing then
		return
	end
	playing = true
	veil.Visible = true
	veil.BackgroundTransparency = 1
	if gentle() then
		TweenService:Create(veil, TweenInfo.new(0.5), { BackgroundTransparency = 0.15 }):Play()
		task.wait(0.9)
	else
		veil.BackgroundTransparency = 0.35
		for _, band in bands do
			band.Visible = true
		end
		local ends = os.clock() + STATIC_SECONDS
		local conn = RunService.RenderStepped:Connect(function()
			for _, band in bands do
				local v = math.random(40, 230)
				band.BackgroundColor3 = Color3.fromRGB(v, v, v)
				band.BackgroundTransparency = math.random() * 0.5
				band.Position = UDim2.fromScale(math.random(-6, 6) / 100, band.Position.Y.Scale)
			end
		end)
		task.wait(math.max(0, ends - os.clock()))
		conn:Disconnect()
		for _, band in bands do
			band.Visible = false
		end
		veil.BackgroundTransparency = 0.1
		task.wait(0.3)
	end
	local fade = TweenService:Create(veil, TweenInfo.new(1.2), { BackgroundTransparency = 1 })
	fade:Play()
	fade.Completed:Wait()
	veil.Visible = false
	playing = false
end

function CaughtController:Init()
	screen = Gui.screen("Caught", 30, true)
	veil = Gui.frame(screen, {
		Name = "Veil",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(8, 8, 10),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 1,
	})
	for i = 1, ROWS do
		local band = Gui.frame(screen, {
			Name = "Band",
			Size = UDim2.fromScale(1.12, 1 / ROWS + 0.002),
			Position = UDim2.fromScale(0, (i - 1) / ROWS),
			BackgroundColor3 = Color3.fromRGB(128, 128, 128),
			Visible = false,
			ZIndex = 2,
		})
		table.insert(bands, band)
	end
end

function CaughtController:Start()
	Notify.on("Caught", function()
		task.spawn(play)
	end)
end

return CaughtController
