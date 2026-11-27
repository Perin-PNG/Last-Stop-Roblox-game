--!strict
-- Sends the camera's look direction about 10 times a second. The server checks it against
-- the head and works out who is looking at what (the mirror rule, Watchers).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Config = require(Shared:WaitForChild("Config"))

local GazeReporter = {}

function GazeReporter:Start()
	local remote = Net.unreliable("Gaze")
	local interval = 1 / Config.Tuning.Gaze.ReportHz
	local acc = 0
	local last = Vector3.zero
	local sinceSend = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		sinceSend += dt
		if acc < interval then
			return
		end
		acc = 0
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local dir = camera.CFrame.LookVector
		-- Skip near-identical reports, but never go quiet long enough to look stale.
		if dir:Dot(last) > 0.9995 and sinceSend < 0.4 then
			return
		end
		last = dir
		sinceSend = 0
		remote:FireServer(dir)
	end)
end

return GazeReporter
