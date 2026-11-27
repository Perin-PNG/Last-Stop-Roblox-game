--!strict
-- World setup: collision groups, night lighting, the folders everything is built into,
-- and the replicated RunState folder.

local Lighting = game:GetService("Lighting")
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared.Log)

local WorldService = {}

WorldService.Folders = {} :: { [string]: Folder }
WorldService.RunState = (nil :: any) :: Folder

local GROUPS = { "Bus", "World", "Players", "Ghosts", "Entities", "Items", "Passengers" }

local function folder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function setupCollisionGroups()
	for _, name in GROUPS do
		if not PhysicsService:IsCollisionGroupRegistered(name) then
			PhysicsService:RegisterCollisionGroup(name)
		end
	end
	-- The bus floats along the road on AlignPosition, so it must never touch the road.
	PhysicsService:CollisionGroupSetCollidable("Bus", "World", false)
	PhysicsService:CollisionGroupSetCollidable("Bus", "Entities", true)
	-- Ghosts (Static players) pass through everything but the world.
	for _, name in { "Bus", "Players", "Entities", "Items", "Passengers", "Default" } do
		PhysicsService:CollisionGroupSetCollidable("Ghosts", name, false)
	end
	PhysicsService:CollisionGroupSetCollidable("Ghosts", "Ghosts", false)
	-- Players don't block each other (narrow bus aisle) or passengers.
	PhysicsService:CollisionGroupSetCollidable("Players", "Players", false)
	PhysicsService:CollisionGroupSetCollidable("Players", "Passengers", false)
	PhysicsService:CollisionGroupSetCollidable("Items", "Players", false)
	PhysicsService:CollisionGroupSetCollidable("Items", "Passengers", false)
	PhysicsService:CollisionGroupSetCollidable("Items", "Entities", false)
	PhysicsService:CollisionGroupSetCollidable("Entities", "Passengers", false)
end

local function setupLighting()
	Lighting.ClockTime = 1.9
	Lighting.Brightness = 0.6
	Lighting.Ambient = Color3.fromRGB(18, 20, 28)
	Lighting.OutdoorAmbient = Color3.fromRGB(28, 32, 44)
	Lighting.EnvironmentDiffuseScale = 0.2
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.GlobalShadows = true
	Lighting.ExposureCompensation = 0.1
	Lighting.FogColor = Color3.fromRGB(14, 16, 22)
	Lighting.FogStart = 60
	Lighting.FogEnd = 520

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.42
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(40, 44, 56)
	atmosphere.Decay = Color3.fromRGB(16, 18, 26)
	atmosphere.Glare = 0
	atmosphere.Haze = 2.2
	atmosphere.Parent = Lighting

	local grade = Lighting:FindFirstChild("Grade") :: ColorCorrectionEffect?
	if not grade then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "Grade"
		cc.Parent = Lighting
		grade = cc
	end
	assert(grade, "Grade effect missing")
	grade.Saturation = -0.25
	grade.Contrast = 0.12
	grade.TintColor = Color3.fromRGB(235, 240, 255)

	-- A soft bloom so neon tubes, lamps and signs glow in the fog, and a starless night sky.
	if not Lighting:FindFirstChild("Glow") then
		local bloom = Instance.new("BloomEffect")
		bloom.Name = "Glow"
		bloom.Intensity = 0.6
		bloom.Size = 30
		bloom.Threshold = 1.6
		bloom.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("Sky") then
		local sky = Instance.new("Sky")
		sky.Name = "NightSky"
		sky.StarCount = 400
		sky.CelestialBodiesShown = false
		sky.MoonAngularSize = 0
		sky.Parent = Lighting
	end
	Lighting.EnvironmentDiffuseScale = 0.25
end

local function setupCharacter(character: Model)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = "Players"
		end
	end
	character.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			d.CollisionGroup = if character:GetAttribute("Ghost") then "Ghosts" else "Players"
		end
	end)
end

function WorldService.setGhost(character: Model, ghost: boolean)
	character:SetAttribute("Ghost", ghost)
	for _, d in character:GetDescendants() do
		if d:IsA("BasePart") then
			d.CollisionGroup = if ghost then "Ghosts" else "Players"
		end
	end
end

function WorldService:Init()
	setupCollisionGroups()
	setupLighting()
	for _, name in { "Road", "Bus", "Stops", "Between", "Lobby", "Entities", "Passengers", "Items", "Effects" } do
		WorldService.Folders[name] = folder(workspace, name)
	end
	folder(ServerStorage, "Assets")
	local runState = folder(ReplicatedStorage, "RunState")
	WorldService.RunState = runState
	Players.CharacterAutoLoads = true
end

function WorldService:Start()
	local function onPlayer(player: Player)
		if player.Character then
			setupCharacter(player.Character)
		end
		player.CharacterAdded:Connect(setupCharacter)
	end
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	Log.info("World", "Ready")
end

return WorldService
