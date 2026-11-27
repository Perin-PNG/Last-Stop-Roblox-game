--!strict
-- Locked first person during runs (for scares and the mirror rule), third person in the
-- lobby. Spectating (Static players) hands the camera to SpectateController. Also adds a
-- gentle head bob (a setting) and lowers the view when crouched, and applies the field of
-- view, camera sensitivity and brightness settings.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Client = script.Parent.Parent
local State = require(Client:WaitForChild("State"))
local Registry = require(Client:WaitForChild("Registry"))

local CameraController = {}

local player = Players.LocalPlayer
CameraController.spectating = false

local function wantFirstPerson(): boolean
	local state = State.mine("State")
	if CameraController.spectating or state == "Static" or state == "Lobby" or state == nil then
		return false
	end
	return true
end

local function apply()
	if wantFirstPerson() then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		player.CameraMinZoomDistance = 0.5
	else
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMaxZoomDistance = 14
		player.CameraMinZoomDistance = if CameraController.spectating then 6 else 4
	end
end

function CameraController.refresh()
	apply()
end

local bob = 0
local offset = Vector3.zero
local wantBob = true
local fov = 70
-- Another controller (the camera viewfinder) can take over the field of view.
CameraController.fovOverride = nil :: number?
local calibration: ColorCorrectionEffect

local function step(dt: number)
	local character = State.character()
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local target = Vector3.zero
	if wantFirstPerson() then
		local stance = State.mine("Stance")
		local moving = humanoid.MoveDirection.Magnitude > 0.1 and humanoid.FloorMaterial ~= Enum.Material.Air
		if stance == "Crouch" then
			target += Vector3.new(0, -1.6, 0)
		end
		if moving and wantBob then
			local rate = if stance == "Sprint" then 13 else 8
			local amount = if stance == "Sprint" then 0.14 else 0.07
			bob += dt * rate
			target += Vector3.new(math.cos(bob * 0.5) * amount, math.abs(math.sin(bob)) * amount, 0)
		end
	end
	offset = offset:Lerp(target, math.min(1, dt * 10))
	humanoid.CameraOffset = offset
	local camera = workspace.CurrentCamera
	local want = CameraController.fovOverride or fov
	if camera and math.abs(camera.FieldOfView - want) > 0.05 then
		camera.FieldOfView = want
	end
end

local function applySetting(key: string, value: any)
	if key == "headBob" then
		wantBob = value ~= false
	elseif key == "fov" and type(value) == "number" then
		fov = math.clamp(value, 70, 90)
	elseif key == "sensitivity" and type(value) == "number" then
		UserInputService.MouseDeltaSensitivity = math.clamp(value, 0.2, 3)
	elseif key == "brightness" and type(value) == "number" then
		calibration.Brightness = math.clamp(value, -0.2, 0.2)
	end
end

function CameraController:Start()
	calibration = Instance.new("ColorCorrectionEffect")
	calibration.Name = "Calibration"
	calibration.Parent = Lighting
	local settings = Registry.get("SettingsController")
	for _, key in { "headBob", "fov", "sensitivity", "brightness" } do
		applySetting(key, settings.get(key))
	end
	settings.changed:Connect(applySetting)
	State.watchMine("State", function()
		apply()
	end)
	player.CharacterAdded:Connect(function()
		task.defer(apply)
	end)
	RunService.RenderStepped:Connect(step)
end

return CameraController
