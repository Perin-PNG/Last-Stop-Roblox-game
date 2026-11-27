--!strict
-- The run's main loop. M0 version: the drive test. The bus drives a generated road, pulls
-- in at a plain stop every ride, opens its doors for a while and leaves. This is what the
-- M0 gate tests: four players walking around inside the moving bus.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Seed = require(Shared.Util.Seed)
local Net = require(Shared.Net)
local Place = require(Shared.Place)
local Log = require(Shared.Log)

local Registry = require(script.Parent.Parent:WaitForChild("Registry"))

local RunDirector = {}

RunDirector.seed = 0
RunDirector.stopIndex = 0
RunDirector.skipRequested = false

local Bus: any
local Chunks: any
local Stops: any
local RunState: Folder

local function now(): number
	return workspace:GetServerTimeNow()
end

-- Put a character inside the bus aisle.
function RunDirector.placeInBus(character: Model)
	local refs = Bus.refs
	if not refs then
		return
	end
	local z = math.random(-12, 18)
	local cf = refs.root.CFrame * CFrame.new(0, 3.5, z)
	character:PivotTo(cf)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.AssemblyLinearVelocity = Bus.velocity()
	end
end

local function waitFor(seconds: number, skippable: boolean?)
	local t = 0
	while t < seconds do
		if skippable and RunDirector.skipRequested then
			RunDirector.skipRequested = false
			return
		end
		t += task.wait(0.2)
	end
end

local function stationaryYard(index: number): CFrame
	return CFrame.new((index % 3) * 3000 - 3000, 0, -6000)
end

-- One ride and one stop.
local function rideAndStop()
	RunDirector.stopIndex += 1
	local index = RunDirector.stopIndex
	RunState:SetAttribute("Phase", "Ride")
	RunState:SetAttribute("StopIndex", index)
	Bus.depart()
	if Bus.mode == "Physics" then
		waitFor(Config.Tuning.Ride.MinRideSeconds * 0.4, true)
		local chunk = Chunks.appendStop("generic")
		local built = Stops.build("generic", chunk.curbCf, index, 1, RunDirector.seed)
		built.chunk = chunk
		Bus.driveTo(chunk.curbS)
		RunState:SetAttribute("Phase", "Arriving")
		Bus.Arrived:Wait()
	else
		Bus.placeAt(Bus.RideSpot, Config.Tuning.Bus.LaneOffset)
		waitFor(Config.Tuning.Ride.StationaryRideSeconds, true)
		Bus.driveTo(Bus.s + 150)
		RunState:SetAttribute("Phase", "Arriving")
		Bus.Arrived:Wait()
		Net.notifyAll("Fade", { seconds = 0.6 })
		task.wait(0.6)
		local yard = stationaryYard(index)
		Chunks.newPath(RunDirector.seed + index, yard)
		Chunks.appendLeadIn(200)
		local chunk = Chunks.appendStop("generic")
		local built = Stops.build("generic", chunk.curbCf, index, 1, RunDirector.seed)
		built.chunk = chunk
		Bus.placeAt(chunk.curbCf, Bus.PullInOffset)
	end
	RunState:SetAttribute("Phase", "Stop")
	Bus.setDoors(true)
	RunState:SetAttribute("Deadline", now() + 40)
	waitFor(40, true)
	RunState:SetAttribute("Phase", "Departing")
	Bus.setDoors(false)
	task.wait(Config.Tuning.Bus.DoorOpenTime + 0.5)
	if Stops.current then
		Stops.deactivate(Stops.current)
	end
	if Bus.mode ~= "Physics" then
		-- Riders see a fade; anyone outside sees the bus pull away (client side).
		for _, player in Players:GetPlayers() do
			if not Bus.isAboard(player) then
				Net.notify(player, "BusLeaving", { cf = Bus.busCFrame() })
			else
				Net.notify(player, "Fade", { seconds = 0.6 })
			end
		end
		task.wait(0.6)
	end
end

function RunDirector.requestSkip()
	RunDirector.skipRequested = true
end

function RunDirector.startDriveTest(seed: number?)
	RunDirector.seed = seed or Seed.fresh()
	RunState:SetAttribute("Seed", RunDirector.seed)
	RunDirector.stopIndex = 0
	Stops.clearAll()
	if Config.Tuning.Bus.Mode == "Physics" then
		Chunks.reset(RunDirector.seed, CFrame.new(0, 0, 0))
		Chunks.appendLeadIn(240)
		Chunks.ensureAhead(60)
	end
	Bus.spawn(60)
	for _, player in Players:GetPlayers() do
		if player.Character then
			RunDirector.placeInBus(player.Character)
		end
	end
end

function RunDirector:Init()
	Bus = Registry.get("BusService")
	Chunks = Registry.get("ChunkService")
	Stops = Registry.get("StopService")
	RunState = Registry.get("WorldService").RunState
end

function RunDirector:Start()
	if not Place.hasRun() then
		return
	end
	RunDirector.startDriveTest()
	-- Keep the road ahead of the bus and clean up behind it.
	Bus.Stepped:Connect(function()
		if Bus.mode == "Physics" then
			Chunks.ensureAhead(Bus.s)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(2)
			if Bus.mode == "Physics" then
				Chunks.cleanup(Bus.s)
			else
				Chunks.cleanup(math.huge)
			end
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			task.wait(0.2)
			RunDirector.placeInBus(character)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function(character)
			task.wait(0.2)
			RunDirector.placeInBus(character)
		end)
	end
	task.spawn(function()
		while true do
			rideAndStop()
		end
	end)
	Log.info("Run", "Drive test running, seed", RunDirector.seed)
end

return RunDirector
