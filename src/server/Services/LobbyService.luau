--!strict
-- The lobby: the Hollow County Transit depot platform at night. Stand in the boarding bay
-- to queue. A countdown starts as soon as one rider is in the bay; it drops to 3 seconds
-- when everyone in the lobby is in it or the bus is full.
--
-- In "Combined" servers (Studio, or before the real PlaceIds are set) the run starts right
-- here. In a Lobby place, MatchmakingService teleports the group to a Route server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Build = require(Shared.Util.Build)
local Net = require(Shared.Net)
local Place = require(Shared.Place)
local Log = require(Shared.Log)

local Registry = require(script.Parent.Parent:WaitForChild("Registry"))

local Tuning = Config.Tuning.Lobby
local C = Build.Colors

local LobbyService = {}

LobbyService.spawn = nil :: SpawnLocation?
LobbyService.zone = nil :: BasePart?

local PlayerState: any
local Director: any
local World: any
local RunState: Folder

local countdownEnds: number? = nil

local function origin(): CFrame
	return CFrame.new(Tuning.Origin)
end

local function P(model: Instance, props: Build.PartProps): Part
	local p = table.clone(props)
	p.cf = origin() * (props.cf or CFrame.identity)
	if p.group == nil then
		p.group = "World"
	end
	return Build.part(model, p)
end

local function buildLobby()
	local model = Build.model(World.Folders.Lobby, "Depot")
	-- Platform and the bay.
	P(model, {
		name = "Platform",
		size = Vector3.new(80, 2, 120),
		cf = CFrame.new(0, -1, 0),
		color = Color3.fromRGB(96, 96, 98),
		material = Enum.Material.Concrete,
	})
	P(model, {
		name = "Road",
		size = Vector3.new(40, 1.6, 200),
		cf = CFrame.new(-60, -1.4, 0),
		color = C.Asphalt,
		material = Enum.Material.Asphalt,
	})
	P(model, {
		name = "CurbEdge",
		size = Vector3.new(1, 0.3, 120),
		cf = CFrame.new(-39.5, 0.15, 0),
		color = Color3.fromRGB(230, 200, 40),
		material = Enum.Material.SmoothPlastic,
	})
	P(model, {
		name = "Ground",
		size = Vector3.new(400, 1, 400),
		cf = CFrame.new(0, -2.6, 0),
		color = C.Grass,
		material = Enum.Material.Grass,
	})
	-- Canopy with fluorescent tubes.
	P(model, {
		name = "Canopy",
		size = Vector3.new(30, 1.2, 90),
		cf = CFrame.new(-24, 16, 0),
		color = C.DarkMetal,
		material = Enum.Material.Metal,
		cast = true,
	})
	for z = -40, 40, 20 do
		P(model, {
			name = "Column",
			size = Vector3.new(1.2, 16, 1.2),
			cf = CFrame.new(-12, 8, z),
			color = C.DarkMetal,
			material = Enum.Material.Metal,
		})
		local tube = P(model, {
			name = "Tube",
			size = Vector3.new(1, 0.3, 8),
			cf = CFrame.new(-24, 15.3, z),
			color = C.Fluor,
			material = Enum.Material.Neon,
			collide = false,
		})
		Build.light(tube, "Point", C.Fluor, 1.1, 26, false)
	end
	-- The boarding bay: painted box at the curb.
	local zone = P(model, {
		name = "BoardingBay",
		size = Vector3.new(14, 0.1, 26),
		cf = CFrame.new(-31, 0.05, 0),
		color = Color3.fromRGB(230, 200, 40),
		material = Enum.Material.Neon,
		transparency = 0.75,
		collide = false,
		query = false,
	})
	LobbyService.zone = zone
	local _, bayLabel = Build.sign(model, {
		name = "BaySign",
		size = Vector3.new(0.4, 4, 12),
		cf = origin() * CFrame.new(-31, 11, -16) * CFrame.Angles(0, math.rad(90), 0),
		color = C.Black,
		collide = false,
		group = "World",
	}, "BAY 9N\nNIGHT OWL\nSTAND HERE TO BOARD", Enum.NormalId.Front, Color3.fromRGB(255, 190, 80))
	bayLabel.Font = Enum.Font.Code
	-- The departures board.
	local board, label = Build.sign(model, {
		name = "Departures",
		size = Vector3.new(0.6, 7, 16),
		cf = origin() * CFrame.new(10, 8, 0) * CFrame.Angles(0, math.rad(-90), 0),
		color = Color3.fromRGB(14, 14, 16),
		group = "World",
	}, "", Enum.NormalId.Front, Color3.fromRGB(255, 190, 80))
	label.Font = Enum.Font.Code
	LobbyService.board = label
	local _ = board
	-- Title sign.
	local _, title = Build.sign(model, {
		name = "Title",
		size = Vector3.new(0.6, 6, 40),
		cf = origin() * CFrame.new(30, 14, 0) * CFrame.Angles(0, math.rad(-90), 0),
		color = Color3.fromRGB(30, 70, 120),
		group = "World",
	}, string.upper(Config.GameName) .. "\nHOLLOW COUNTY TRANSIT", Enum.NormalId.Front, C.White)
	title.Font = Enum.Font.GothamBlack
	-- The Route Map wall: each player sees their own stamps (RouteMapController).
	local mapCf = CFrame.new(24, 0, -34) * CFrame.Angles(0, math.rad(-90), 0)
	for _, side in { -9.6, 9.6 } do
		P(model, {
			name = "RouteMapPost",
			size = Vector3.new(0.6, 12, 0.6),
			cf = mapCf * CFrame.new(side, 6, 0),
			color = Color3.fromRGB(60, 62, 66),
			material = Enum.Material.Metal,
			group = "World",
		})
	end
	local mapBoard = P(model, {
		name = "RouteMap",
		size = Vector3.new(18.6, 9, 0.5),
		cf = mapCf * CFrame.new(0, 7, 0),
		color = Color3.fromRGB(226, 222, 206),
		material = Enum.Material.SmoothPlastic,
		group = "World",
	})
	local mapLight = Build.light(mapBoard, "Surface", Color3.fromRGB(255, 236, 200), 0.6, 10, false) :: SurfaceLight
	mapLight.Face = Enum.NormalId.Front
	-- Benches.
	for _, z in { -30, 30 } do
		P(model, {
			name = "Bench",
			size = Vector3.new(2, 0.6, 10),
			cf = CFrame.new(-8, 2, z),
			color = C.Wood,
			material = Enum.Material.Wood,
		})
	end
	-- Spawn.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = origin() * CFrame.new(10, 0.1, 20)
	spawn.Anchored = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = model
	LobbyService.spawn = spawn
end

LobbyService.board = nil :: TextLabel?

local function inBay(player: Player): boolean
	local zone = LobbyService.zone
	local root = PlayerState.rootOf(player)
	if not zone or not root then
		return false
	end
	local rel = zone.CFrame:PointToObjectSpace(root.Position)
	return math.abs(rel.X) <= zone.Size.X / 2 and math.abs(rel.Z) <= zone.Size.Z / 2 and rel.Y < 10
end

local function lobbyPlayers(): { Player }
	local out = {}
	for _, player in Players:GetPlayers() do
		if PlayerState.state(player) == "Lobby" and not Director.inRun(player) then
			table.insert(out, player)
		end
	end
	return out
end

function LobbyService.sendToLobby(player: Player)
	local character = player.Character
	local spawn = LobbyService.spawn
	if character and spawn then
		character:PivotTo(spawn.CFrame * CFrame.new(math.random(-4, 4), 3, math.random(-4, 4)))
	end
end

function LobbyService.returnPlayers(players: { Player })
	for _, player in players do
		if player.Parent then
			PlayerState.toLobby(player)
			LobbyService.sendToLobby(player)
			Net.notify(player, "Fade", { seconds = 1 })
		end
	end
end

local function lobbyTick()
	local board = LobbyService.board
	local lobby = lobbyPlayers()
	local queued = {}
	for _, player in lobby do
		if inBay(player) then
			table.insert(queued, player)
		end
	end
	RunState:SetAttribute("QueueCount", #queued)
	local t = workspace:GetServerTimeNow()
	if Director.running then
		countdownEnds = nil
		RunState:SetAttribute("LobbyCountdown", nil)
		if board then
			board.Text = "9N NIGHT OWL\nON ROUTE\nNEXT BUS SOON"
		end
		return
	end
	if #queued == 0 then
		countdownEnds = nil
		RunState:SetAttribute("LobbyCountdown", nil)
		if board then
			board.Text = "9N NIGHT OWL\nBAY 9\nBOARDING"
		end
		return
	end
	local everyone = #queued >= #lobby or #queued >= Config.Tuning.Run.MaxPlayers
	local wanted = t + (if everyone then 3 else Tuning.QueueCountdown)
	if not countdownEnds or wanted < countdownEnds then
		countdownEnds = wanted
	end
	local left = math.max(0, (countdownEnds :: number) - t)
	RunState:SetAttribute("LobbyCountdown", countdownEnds)
	if board then
		board.Text = string.format(
			"9N NIGHT OWL\nDEPARTS IN %d\n%d/%d ABOARD",
			math.ceil(left),
			#queued,
			Config.Tuning.Run.MaxPlayers
		)
	end
	if left <= 0 then
		countdownEnds = nil
		local group = {}
		for i = 1, math.min(#queued, Config.Tuning.Run.MaxPlayers) do
			table.insert(group, queued[i])
		end
		local matchmaking = Registry.find("MatchmakingService")
		if Place.role() == "Lobby" and matchmaking then
			-- From a paid private server, the run is a private run.
			local shop = Registry.find("MonetizationService")
			matchmaking.send(group, { mode = "Standard", party = shop ~= nil and shop.isPrivate() })
		else
			Log.info("Lobby", "Starting a run for", #group)
			Net.notifyList(group, "Fade", { seconds = 1 })
			task.wait(0.4)
			Director.startRun(group, { party = false })
		end
	end
end

function LobbyService:Init()
	PlayerState = Registry.get("PlayerStateService")
	World = Registry.get("WorldService")
	RunState = World.RunState
end

function LobbyService:Start()
	Director = Registry.get("RunDirector")
	if not Place.hasLobby() then
		return
	end
	buildLobby()
	local function onCharacter(player: Player)
		task.wait(0.25)
		if not Director.inRun(player) then
			PlayerState.toLobby(player)
			LobbyService.sendToLobby(player)
		end
	end
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function()
			onCharacter(player)
		end)
		if player.Character then
			task.spawn(onCharacter, player)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	task.spawn(function()
		while true do
			task.wait(0.5)
			local result = table.pack(pcall(lobbyTick))
			if not result[1] then
				Log.warn("Lobby", result[2])
			end
		end
	end)
end

return LobbyService
