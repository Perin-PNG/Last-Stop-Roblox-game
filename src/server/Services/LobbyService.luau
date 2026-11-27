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

-- Set dressing so the depot reads as a real place: the depot office behind the
-- platform, sodium streetlights along the road, bins, a vending machine, bollards at
-- the bay, puddles, posters and a line of trees.
local function dressDepot(model: Model)
	local rng = Random.new(9)
	-- The office: a brick block across the back of the platform.
	P(model, {
		name = "OfficeWall",
		size = Vector3.new(14, 16.5, 64),
		cf = CFrame.new(47, 5.75, 0),
		color = C.Brick,
		material = Enum.Material.Brick,
		cast = true,
	})
	P(model, {
		name = "OfficeRoof",
		size = Vector3.new(16, 1, 66),
		cf = CFrame.new(47, 14.5, 0),
		color = C.DarkMetal,
		material = Enum.Material.Metal,
	})
	for _, z in { -24, -12, 12, 24 } do
		local pane = P(model, {
			name = "OfficeWindow",
			size = Vector3.new(0.2, 4, 6),
			cf = CFrame.new(39.95, 6.5, z),
			color = Color3.fromRGB(255, 214, 150),
			material = Enum.Material.Neon,
			transparency = 0.25,
			collide = false,
		})
		Build.light(pane, "Point", C.Warm, 0.6, 14, false)
		P(model, {
			name = "OfficeSill",
			size = Vector3.new(0.6, 0.3, 6.6),
			cf = CFrame.new(39.7, 4.35, z),
			color = C.Concrete,
			material = Enum.Material.Concrete,
		})
	end
	P(model, {
		name = "OfficeDoor",
		size = Vector3.new(0.3, 8, 4.5),
		cf = CFrame.new(39.9, 4, 0),
		color = Color3.fromRGB(40, 70, 110),
		material = Enum.Material.Metal,
	})
	local _, officeSign = Build.sign(model, {
		name = "OfficeSign",
		size = Vector3.new(14, 1.6, 0.3),
		cf = origin() * CFrame.new(39.8, 9.6, 0) * CFrame.Angles(0, math.rad(90), 0),
		color = C.Black,
		group = "World",
	}, "HCTA  ·  DEPOT OFFICE  ·  NO ENTRY", Enum.NormalId.Front, Color3.fromRGB(255, 190, 80))
	officeSign.Font = Enum.Font.Code
	-- Posters on the office wall: house rules and a little lore.
	local posters = {
		{ z = -6, text = "RIDER NOTICE\n\nThe 9N departs\nwhen the bell rings.\nIt does not wait.", color = C.White },
		{
			z = 6,
			text = "MISSING\n\nUnit 6 and all\npassengers.\nLast seen on\nRoute 9N.",
			color = Color3.fromRGB(230, 220, 190),
		},
		{ z = 18, text = "PLEASE\n\nDo not speak to\nthe operator\nwhile the bus\nis in motion.", color = C.White },
		{
			z = -18,
			text = "NIGHT OWL\nSERVICE\n\nEvery stop.\nEvery night.\nUntil dawn.",
			color = Color3.fromRGB(210, 225, 240),
		},
	}
	for _, poster in posters do
		local _, label = Build.sign(model, {
			name = "Poster",
			size = Vector3.new(3, 4, 0.1),
			cf = origin() * CFrame.new(39.85, 5.5, poster.z) * CFrame.Angles(0, math.rad(90), 0),
			color = poster.color,
			material = Enum.Material.Fabric,
			collide = false,
			group = "World",
		}, poster.text, Enum.NormalId.Front, Color3.fromRGB(30, 28, 26))
		label.Font = Enum.Font.SpecialElite
	end
	-- Sodium streetlights along the road edge.
	for z = -90, 90, 45 do
		P(model, {
			name = "StreetPole",
			size = Vector3.new(0.6, 18, 0.6),
			cf = CFrame.new(-42, 9, z),
			color = C.DarkMetal,
			material = Enum.Material.Metal,
		})
		P(model, {
			name = "StreetArm",
			size = Vector3.new(6, 0.4, 0.4),
			cf = CFrame.new(-45, 17.8, z),
			color = C.DarkMetal,
			material = Enum.Material.Metal,
		})
		local head = P(model, {
			name = "StreetHead",
			size = Vector3.new(2.2, 0.5, 1.2),
			cf = CFrame.new(-47.6, 17.4, z),
			color = C.Sodium,
			material = Enum.Material.Neon,
			collide = false,
		})
		Build.light(head, "Spot", C.Sodium, 2.2, 40, false)
	end
	-- Bollards along the curb either side of the bay, and bins and a vending machine.
	for _, z in { -34, -27, -20, 20, 27, 34 } do
		P(model, {
			name = "Bollard",
			size = Vector3.new(2.6, 0.8, 0.8),
			cf = CFrame.new(-37, 1.3, z),
			color = Color3.fromRGB(230, 200, 40),
			material = Enum.Material.SmoothPlastic,
			shape = Enum.PartType.Cylinder,
		})
	end
	for _, bollard in model:GetChildren() do
		if bollard.Name == "Bollard" and bollard:IsA("BasePart") then
			-- A cylinder's axis is X; stand it up.
			bollard.CFrame = bollard.CFrame * CFrame.Angles(0, 0, math.rad(90))
		end
	end
	for _, z in { -36, 36 } do
		P(model, {
			name = "Bin",
			size = Vector3.new(2, 3, 2),
			cf = CFrame.new(-8, 1.5, z),
			color = Color3.fromRGB(40, 70, 50),
			material = Enum.Material.Metal,
		})
	end
	local vending = P(model, {
		name = "Vending",
		size = Vector3.new(3, 7, 3.5),
		cf = CFrame.new(37.5, 3.5, 8),
		color = Color3.fromRGB(150, 30, 30),
		material = Enum.Material.SmoothPlastic,
	})
	local glow = P(model, {
		name = "VendingGlass",
		size = Vector3.new(0.1, 4.6, 2.6),
		cf = CFrame.new(35.95, 4.2, 8),
		color = Color3.fromRGB(220, 240, 255),
		material = Enum.Material.Neon,
		transparency = 0.35,
		collide = false,
	})
	Build.light(glow, "Point", Color3.fromRGB(200, 225, 255), 0.8, 12, false)
	local _ = vending
	-- Puddles that catch the light.
	for _ = 1, 7 do
		local x = rng:NextNumber(-30, 30)
		local z = rng:NextNumber(-50, 50)
		P(model, {
			name = "Puddle",
			size = Vector3.new(rng:NextNumber(3, 7), 0.05, rng:NextNumber(2, 5)),
			cf = CFrame.new(x, 0.03, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
			color = Color3.fromRGB(20, 26, 30),
			material = Enum.Material.Glass,
			transparency = 0.3,
			reflectance = 0.35,
			collide = false,
			query = false,
		})
	end
	-- A line of dark trees behind the office.
	for i = 1, 14 do
		local x = 62 + rng:NextNumber(0, 40)
		local z = -90 + i * 12 + rng:NextNumber(-4, 4)
		local h = rng:NextNumber(14, 24)
		P(model, {
			name = "Trunk",
			size = Vector3.new(1.2, h, 1.2),
			cf = CFrame.new(x, h / 2 - 2, z),
			color = Color3.fromRGB(40, 32, 26),
			material = Enum.Material.Wood,
		})
		P(model, {
			name = "Crown",
			size = Vector3.one * (h * 0.6),
			cf = CFrame.new(x, h - 2, z),
			color = Color3.fromRGB(22, 34, 24),
			material = Enum.Material.Grass,
			shape = Enum.PartType.Ball,
			cast = false,
		})
	end
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
		size = Vector3.new(12, 4, 0.4),
		cf = origin() * CFrame.new(-31, 11, -16) * CFrame.Angles(0, math.rad(-90), 0),
		color = C.Black,
		collide = false,
		group = "World",
	}, "BAY 9N\nNIGHT OWL\nSTAND HERE TO BOARD", Enum.NormalId.Front, Color3.fromRGB(255, 190, 80))
	bayLabel.Font = Enum.Font.Code
	-- The departures board.
	local board, label = Build.sign(model, {
		name = "Departures",
		size = Vector3.new(16, 7, 0.6),
		cf = origin() * CFrame.new(10, 8, 0) * CFrame.Angles(0, math.rad(90), 0),
		color = Color3.fromRGB(14, 14, 16),
		group = "World",
	}, "", Enum.NormalId.Front, Color3.fromRGB(255, 190, 80))
	label.Font = Enum.Font.Code
	LobbyService.board = label
	for _, z in { -8.4, 8.4 } do
		P(model, {
			name = "DeparturesPost",
			size = Vector3.new(0.5, 12, 0.5),
			cf = CFrame.new(10, 6, z),
			color = C.DarkMetal,
			material = Enum.Material.Metal,
		})
	end
	local _ = board
	-- Title sign.
	local _, title = Build.sign(model, {
		name = "Title",
		size = Vector3.new(40, 6, 0.6),
		cf = origin() * CFrame.new(30, 14, 0) * CFrame.Angles(0, math.rad(90), 0),
		color = Color3.fromRGB(30, 70, 120),
		group = "World",
	}, string.upper(Config.GameName) .. "\nHOLLOW COUNTY TRANSIT", Enum.NormalId.Front, C.White)
	title.Font = Enum.Font.GothamBlack
	-- The Route Map wall: each player sees their own stamps (RouteMapController).
	local mapCf = CFrame.new(24, 0, -34) * CFrame.Angles(0, math.rad(90), 0)
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
	dressDepot(model)
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
