--!strict
-- Locked first person during runs (for scares and the mirror rule), third person in the
-- lobby. Spectating (Static players) hands the camera to SpectateController. Also adds a
-- gentle head bob and lowers the view when crouched.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Client = script.Parent.Parent
local State = require(Client:WaitForChild("State"))

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
		if moving then
			local rate = if stance == "Sprint" then 13 else 8
			local amount = if stance == "Sprint" then 0.14 else 0.07
			bob += dt * rate
			target += Vector3.new(math.cos(bob * 0.5) * amount, math.abs(math.sin(bob)) * amount, 0)
		end
	end
	offset = offset:Lerp(target, math.min(1, dt * 10))
	humanoid.CameraOffset = offset
end

function CameraController:Start()
	State.watchMine("State", function()
		apply()
	end)
	player.CharacterAdded:Connect(function()
		task.defer(apply)
	end)
	RunService.RenderStepped:Connect(step)
end

return CameraController
