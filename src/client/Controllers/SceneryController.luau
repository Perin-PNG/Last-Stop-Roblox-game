--!strict
-- Stationary-mode fallback only: scrolls a loop of road, streetlights and trees past the
-- parked bus so the ride still looks like a ride. In Physics mode this does nothing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Client = script.Parent.Parent
local State = require(Client:WaitForChild("State"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Build = require(Shared:WaitForChild("Util"):WaitForChild("Build"))
local Config = require(Shared:WaitForChild("Config"))

local C = Build.Colors
local Tuning = Config.Tuning

local SceneryController = {}

local TILE = 60
local COUNT = 16
local tiles: { Model } = {}
local folder: Folder?
local offset = 0

local function buildTile(index: number, parent: Instance): Model
	local m = Instance.new("Model")
	m.Name = "Tile" .. index
	local root = Build.part(m, {
		name = "Road",
		size = Vector3.new(40, 1, TILE + 0.2),
		cf = CFrame.new(0, -0.5, 0),
		color = C.Asphalt,
		material = Enum.Material.Asphalt,
		collide = false,
		query = false,
	})
	m.PrimaryPart = root
	Build.part(m, {
		name = "Dash",
		size = Vector3.new(0.5, 0.05, 8),
		cf = CFrame.new(0, 0.03, 0),
		color = C.Lane,
		collide = false,
		query = false,
	})
	Build.part(m, {
		name = "Sidewalk",
		size = Vector3.new(10, 1.2, TILE + 0.2),
		cf = CFrame.new(25, 0, 0),
		color = C.Concrete,
		material = Enum.Material.Concrete,
		collide = false,
		query = false,
	})
	for _, side in { -1, 1 } do
		Build.part(m, {
			name = "Ground",
			size = Vector3.new(170, 1, TILE + 0.2),
			cf = CFrame.new(side * (20 + 8 + 85), -0.8, 0),
			color = C.Grass,
			material = Enum.Material.Grass,
			collide = false,
			query = false,
		})
		local rng = Random.new(index * 7 + side)
		if rng:NextNumber() < 0.7 then
			local x = side * (36 + rng:NextNumber() * 50)
			local h = 16 + rng:NextNumber() * 10
			Build.part(m, {
				name = "Trunk",
				size = Vector3.new(1.3, h, 1.3),
				cf = CFrame.new(x, h / 2, rng:NextNumber() * 40 - 20),
				color = Color3.fromRGB(40, 32, 26),
				collide = false,
				query = false,
			})
			Build.part(m, {
				name = "Leaves",
				size = Vector3.new(10, 12, 10),
				cf = CFrame.new(x, h + 3, 0),
				color = Color3.fromRGB(18, 32, 22),
				material = Enum.Material.Grass,
				collide = false,
				query = false,
			})
		end
	end
	if index % 2 == 0 then
		Build.part(m, {
			name = "Pole",
			size = Vector3.new(0.7, 22, 0.7),
			cf = CFrame.new(21.6, 11, 0),
			color = C.DarkMetal,
			collide = false,
			query = false,
		})
		local lamp = Build.part(m, {
			name = "Lamp",
			size = Vector3.new(2.2, 0.5, 1.2),
			cf = CFrame.new(15.2, 21.4, 0),
			color = C.Sodium,
			material = Enum.Material.Neon,
			collide = false,
			query = false,
		})
		Build.light(lamp, "Spot", C.Sodium, 2.4, 40, false)
	end
	m.Parent = parent
	return m
end

local function clear()
	for _, t in tiles do
		t:Destroy()
	end
	table.clear(tiles)
	if folder then
		folder:Destroy()
		folder = nil
	end
end

local function ensure()
	if folder then
		return
	end
	local f = Instance.new("Folder")
	f.Name = "LocalScenery"
	f.Parent = workspace
	folder = f
	for i = 1, COUNT do
		table.insert(tiles, buildTile(i, f))
	end
end

local function active(): boolean
	if State.get("BusMode") ~= "Stationary" then
		return false
	end
	local phase = State.get("Phase")
	return phase == "Ride" or phase == "Arriving" or phase == "Boarding"
end

function SceneryController:Start()
	RunService.RenderStepped:Connect(function(dt: number)
		if not active() then
			if folder then
				clear()
			end
			return
		end
		local floor = State.busPart("Floor")
		if not floor then
			return
		end
		-- Only scroll while the bus is at the ride spot (stops are real places).
		ensure()
		local speed = (State.get("BusSpeed") :: number?) or 0
		offset = (offset + speed * dt) % (TILE * COUNT)
		local road = floor.CFrame * CFrame.new(-Tuning.Bus.LaneOffset, -(Tuning.Bus.HoverHeight - 0.5), 0)
		for i, tile in tiles do
			local z = ((i - 1) * TILE + offset) % (TILE * COUNT) - TILE * COUNT / 2
			tile:PivotTo(road * CFrame.new(0, 0, z))
		end
	end)
end

return SceneryController
