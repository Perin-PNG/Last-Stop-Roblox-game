--!strict
-- Voice as noise: reads this player's own microphone level (AudioAnalyzer works only on the
-- client) and reports it about 10 times a second. The server turns it into noise events.
-- Players without voice chat send nothing and lose nothing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local VoiceReporter = {}

local analyzer: AudioAnalyzer? = nil

local function hook(input: Instance)
	if not input:IsA("AudioDeviceInput") or analyzer then
		return
	end
	local a = Instance.new("AudioAnalyzer")
	a.Name = "NoiseAnalyzer"
	a.Parent = input
	local wire = Instance.new("Wire")
	wire.SourceInstance = input
	wire.TargetInstance = a
	wire.Parent = a
	analyzer = a
end

function VoiceReporter:Start()
	local player = Players.LocalPlayer
	for _, child in player:GetChildren() do
		hook(child)
	end
	player.ChildAdded:Connect(hook)
	local remote = Net.unreliable("VoiceLevel")
	local acc = 0
	local lastSent = -1
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc < 0.1 or not analyzer then
			return
		end
		acc = 0
		local level = math.clamp((analyzer :: AudioAnalyzer).RmsLevel, 0, 1)
		local rounded = math.floor(level * 20 + 0.5) / 20
		if rounded == lastSent and rounded == 0 then
			return
		end
		lastSent = rounded
		remote:FireServer(rounded)
	end)
end

return VoiceReporter
