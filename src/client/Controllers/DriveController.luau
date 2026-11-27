--!strict
-- The Terminal finale on the client: the wheel (send the Driver's seat's throttle and
-- steer to the server while you sit in it), a small objective readout (breakers, the road
-- left, how close the Latecomer is), the crash shake, the mirror moment and the dawn.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = script.Parent.Parent
local Registry = require(Client:WaitForChild("Registry"))
local State = require(Client:WaitForChild("State"))
local Notify = require(Client:WaitForChild("Notify"))
local Gui = require(Client:WaitForChild("Gui"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local DriveController = {}

local player = Players.LocalPlayer
local SEND_EVERY = 0.1

local screen: ScreenGui
local panel: Frame
local line: TextLabel
local overlay: Frame
local shakeUntil = 0
local shakeStrength = 0

local function reducedMotion(): boolean
	local settings = Registry.find("SettingsController")
	return settings ~= nil and (settings.get("reduceFlashing") == true or settings.get("reduceScares") == true)
end

-- The seat this player is sitting in, if it's the bus's Driver's seat.
local function driverSeat(): VehicleSeat?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if seat and seat:IsA("VehicleSeat") and seat.Name == "DriverSeat" then
		return seat
	end
	return nil
end

local function refreshPanel()
	local step = State.get("FinaleStep")
	local text: string? = nil
	if step == "Power" then
		text = string.format("Breakers %d / %d", State.get("Breakers") or 0, State.get("BreakersNeeded") or 3)
	elseif step == "Board" then
		text = "Take the wheel"
	elseif step == "Drive" then
		local progress = State.get("DriveProgress") or 0
		local gap = State.get("LatecomerDistance")
		local road = string.format("Exit road %d%%", math.floor(progress * 100))
		text = road
		if type(gap) == "number" then
			text = road .. if gap < 30 then "   It's right behind you" else string.format("   Behind: %d", gap)
		end
	end
	panel.Visible = text ~= nil
	if text then
		line.Text = text
	end
end

local function fadeOverlay(color: Color3, holdSeconds: number, inSeconds: number, outSeconds: number)
	overlay.BackgroundColor3 = color
	overlay.BackgroundTransparency = 1
	overlay.Visible = true
	local peak = if reducedMotion() then 0.75 else 0.35
	TweenService:Create(overlay, TweenInfo.new(inSeconds), { BackgroundTransparency = peak }):Play()
	task.delay(inSeconds + holdSeconds, function()
		local out = TweenService:Create(overlay, TweenInfo.new(outSeconds), { BackgroundTransparency = 1 })
		out:Play()
		out.Completed:Wait()
		overlay.Visible = false
	end)
end

function DriveController:Init()
	screen = Gui.screen("Finale", 6)
	panel = Gui.frame(screen, {
		Name = "Objective",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 52),
		Size = UDim2.fromOffset(340, 34),
		Visible = false,
	})
	Gui.corner(panel, 8)
	line = Gui.label(panel, "", { Size = UDim2.new(1, -16, 1, -8), Position = UDim2.fromOffset(8, 4), MaxText = 20 })
	overlay = Gui.frame(screen, {
		Name = "Overlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 0,
	})
end

function DriveController:Start()
	for _, name in { "FinaleStep", "Breakers", "BreakersNeeded", "DriveProgress", "LatecomerDistance" } do
		State.on(name, refreshPanel)
	end
	refreshPanel()

	-- The wheel. A VehicleSeat reads W/S and A/D, the gamepad triggers and stick, and the
	-- touch thumbstick into ThrottleFloat and SteerFloat for whoever sits in it.
	local remote = Net.unreliable("Drive")
	local lastSend = 0
	local sentZero = true
	RunService.Heartbeat:Connect(function()
		if State.get("FinaleStep") ~= "Drive" then
			return
		end
		local seat = driverSeat()
		local t = os.clock()
		if not seat or t - lastSend < SEND_EVERY then
			return
		end
		lastSend = t
		local throttle = math.max(0, seat.ThrottleFloat)
		local steer = seat.SteerFloat
		if throttle == 0 and steer == 0 and sentZero then
			return
		end
		sentZero = throttle == 0 and steer == 0
		remote:FireServer(throttle, steer)
	end)

	-- A crash shakes the camera (not with reduced flashing and motion).
	RunService:BindToRenderStep("FinaleShake", Enum.RenderPriority.Camera.Value + 1, function()
		local t = os.clock()
		if t >= shakeUntil or reducedMotion() then
			return
		end
		local camera = workspace.CurrentCamera
		local k = shakeStrength * (shakeUntil - t)
		camera.CFrame *= CFrame.Angles(
			math.rad(math.noise(t * 30, 1) * k * 2),
			math.rad(math.noise(t * 30, 2) * k * 2),
			math.rad(math.noise(t * 30, 3) * k)
		)
	end)
	Notify.on("Shake", function(p: any)
		if type(p) == "table" and type(p.strength) == "number" and type(p.seconds) == "number" then
			shakeStrength = math.clamp(p.strength, 0, 2)
			shakeUntil = os.clock() + math.clamp(p.seconds, 0, 3)
		end
	end)

	-- The face in the mirror is yours: a pale wash.
	Notify.on("MirrorSelf", function()
		fadeOverlay(Color3.fromRGB(220, 225, 235), 1.5, 0.4, 2.5)
	end)
	-- Dawn: warm light floods the screen, then settles.
	Notify.on("Dawn", function()
		fadeOverlay(Color3.fromRGB(255, 200, 150), 2, 3, 4)
	end)
end

return DriveController
