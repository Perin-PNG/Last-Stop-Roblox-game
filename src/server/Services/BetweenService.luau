--!strict
-- The Between: where you go when the bus leaves without you. A fogged footpath through dark
-- woods, sized so a walker reaches the far end a little before the next stop's departure.
-- The far end lets out at the next stop's back entrance once that stop is open. Headlights
-- sweep the path now and then: step off it. Miss the next departure and you're Lost.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Build = require(Shared.Util.Build)
local Seed = require(Shared.Util.Seed)
local Net = require(Shared.Net)
local Log = require(Shared.Log)
local Signal = require(Shared.Util.Signal)

local Registry = require(script.Parent.Parent:WaitForChild("Registry"))

local Tuning = Config.Tuning.Between
local C = Build.Colors

local BetweenService = {}

BetweenService.Returned = Signal.new() -- (player) made it out of the Between

type Trail = {
	fromStop: any,
	model: Model,
	points: { CFrame }, -- centreline, start to end
	length: number,
	exitZone: BasePart,
	sweepAt: number,
	sweep: { model: Model, s: number }?,
	phones: { BasePart },
}

type Walker = {
	trail: Trail,
	sentAt: number,
	entered: boolean,
	enterAt: number,
}

local trails: { [any]: Trail } = {}
local walkers: { [Player]: Walker } = {}
local nextOrigin = 0

local PlayerState: any
local World: any
local RunState: Folder
local Director: any

local function now(): number
	return workspace:GetServerTimeNow()
end

local function lengthFor(players: number): number
	local tier = (RunState:GetAttribute("Tier") :: number?) or 1
	local timer = Config.Tuning.Stop.DepartureTimer[math.clamp(tier, 1, 3)]
	local ride = (Config.Tuning.Ride.MinRideSeconds + Config.Tuning.Ride.MaxRideSeconds) / 2
	local seconds = ride + timer - Tuning.TargetSpareSeconds
	local length = math.clamp(seconds * Tuning.WalkSpeedForLength * 0.5, Tuning.MinLength, Tuning.MaxLength)
	if players <= 1 then
		length *= Tuning.SoloShorten
	end
	return length
end

local function buildTrail(fromStop: any): Trail
	nextOrigin += 1
	local origin = CFrame.new(Tuning.Origin + Vector3.new(0, 0, nextOrigin * 2600))
	local model = Build.model(World.Folders.Between, "Between" .. nextOrigin)
	local rng = Seed.new(nextOrigin * 131 + (fromStop.index or 0)):child("between")
	local length = lengthFor(#PlayerState.living() + 1)
	local points: { CFrame } = { origin }
	local seg = 40
	local cf = origin
	local yaw = 0
	local total = 0
	while total < length do
		yaw = math.clamp(yaw + rng:float(-0.35, 0.35), -0.9, 0.9)
		cf = CFrame.new(cf.Position) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, -seg)
		table.insert(points, cf)
		total += seg
	end
	-- Ground: one big dark field under the whole trail.
	local min, max = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, p in points do
		min = min:Min(p.Position)
		max = max:Max(p.Position)
	end
	local centre = (min + max) / 2
	local size = (max - min) + Vector3.new(160, 0, 160)
	Build.part(model, {
		name = "Ground",
		size = Vector3.new(size.X, 2, size.Z),
		cf = CFrame.new(centre.X, -1, centre.Z),
		color = Color3.fromRGB(22, 28, 22),
		material = Enum.Material.Grass,
		group = "World",
	})
	for i = 1, #points - 1 do
		local a, b = points[i].Position, points[i + 1].Position
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		Build.part(model, {
			name = "Path",
			size = Vector3.new(7, 0.3, len + 3),
			cf = CFrame.lookAt(mid, b) * CFrame.new(0, 0.05, 0),
			color = C.Dirt,
			material = Enum.Material.Mud,
			group = "World",
		})
		-- Trees close on both sides, so stepping off the path means into the dark.
		for _ = 1, 4 do
			local side = if rng:chance(0.5) then 1 else -1
			local off = CFrame.lookAt(mid, b) * CFrame.new(side * rng:float(9, 40), 0, rng:float(-len / 2, len / 2))
			local height = rng:float(30, 60)
			Build.part(model, {
				name = "Trunk",
				size = Vector3.new(height, rng:float(1.6, 3), rng:float(1.6, 3)),
				cf = off * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
				color = Color3.fromRGB(34, 28, 24),
				material = Enum.Material.Wood,
				shape = Enum.PartType.Cylinder,
				group = "World",
			})
		end
		-- Trail markers: a small cold light every other segment.
		if i % 2 == 0 then
			local post = Build.part(model, {
				name = "Marker",
				size = Vector3.new(0.6, 3.4, 0.6),
				cf = CFrame.lookAt(a, b) * CFrame.new(4.6, 1.7, 0),
				color = C.Wood,
				material = Enum.Material.Wood,
				group = "World",
			})
			local glow = Build.part(model, {
				name = "MarkerLight",
				size = Vector3.new(0.5, 0.5, 0.5),
				cf = post.CFrame * CFrame.new(0, 1.9, 0),
				color = Color3.fromRGB(170, 210, 255),
				material = Enum.Material.Neon,
				shape = Enum.PartType.Ball,
				collide = false,
				group = "World",
			})
			Build.light(glow, "Point", Color3.fromRGB(170, 210, 255), 0.7, 12, false)
		end
	end
	-- Payphones along the way. They ring. Answering one gives a line of the true channel.
	local phones: { BasePart } = {}
	local every = math.max(4, math.floor(Tuning.PayphoneEvery / seg))
	for i = every, #points - 2, every do
		local at = points[i] * CFrame.new(-6, 0, 0)
		local booth = Build.part(model, {
			name = "Payphone",
			size = Vector3.new(1.4, 6, 1.4),
			cf = at * CFrame.new(0, 3, 0),
			color = Color3.fromRGB(120, 120, 130),
			material = Enum.Material.Metal,
			group = "World",
		})
		local prompt = Build.prompt(booth, "Answer", "Payphone", Tuning.PayphoneTalkSeconds, 7)
		prompt.Triggered:Connect(function(player: Player)
			prompt.Enabled = false
			local lines = Config.Text.TrueChannel
			Net.notify(player, "Radio", { text = lines[math.random(1, #lines)], channel = "true" })
		end)
		table.insert(phones, booth)
	end
	-- The far end: a gap in the trees with a streetlight beyond it.
	local last = points[#points]
	local exitZone = Build.part(model, {
		name = "Exit",
		size = Vector3.new(14, 10, 10),
		cf = last * CFrame.new(0, 5, -4),
		transparency = 1,
		collide = false,
		touch = false,
		query = false,
		group = "World",
	})
	local lamp = Build.part(model, {
		name = "ExitLamp",
		size = Vector3.new(1, 14, 1),
		cf = last * CFrame.new(5, 7, -6),
		color = C.DarkMetal,
		group = "World",
	})
	local bulb = Build.part(model, {
		name = "ExitBulb",
		size = Vector3.new(1.6, 0.6, 1.6),
		cf = lamp.CFrame * CFrame.new(0, 7.3, 0),
		color = C.Sodium,
		material = Enum.Material.Neon,
		collide = false,
		group = "World",
	})
	Build.light(bulb, "Point", C.Sodium, 1.5, 30, false)
	local trail: Trail = {
		fromStop = fromStop,
		model = model,
		points = points,
		length = total,
		exitZone = exitZone,
		sweepAt = now() + 30,
		sweep = nil,
		phones = phones,
	}
	Log.info("Between", "Built a trail of", math.floor(total), "studs")
	return trail
end

local function trailFor(fromStop: any): Trail
	local t = trails[fromStop]
	if not t then
		t = buildTrail(fromStop)
		trails[fromStop] = t
	end
	return t
end

local function enter(player: Player, w: Walker)
	if w.entered then
		return
	end
	w.entered = true
	local character = player.Character
	if character then
		character:PivotTo(w.trail.points[1] * CFrame.new(0, 3.5, 0))
	end
	player:SetAttribute("InBetween", true)
	Net.notify(player, "Fade", { seconds = 1.2 })
	Net.notify(player, "Hint", { id = "left_behind" })
end

-- A player was left behind at `fromStop`.
function BetweenService.send(player: Player, fromStop: any)
	if not fromStop then
		return
	end
	local trail = trailFor(fromStop)
	walkers[player] =
		{ trail = trail, sentAt = now(), entered = false, enterAt = now() + Config.Tuning.Stop.LeftBehindAutoEnter }
	Net.notify(player, "Toast", { text = "The bus left without you. Find the footpath." })
	-- The trailhead pulls them in too.
	local zone: BasePart? = fromStop.refs.trailhead
	if zone then
		zone.CanTouch = true
		zone.Touched:Connect(function(hit: BasePart)
			local character = hit.Parent
			local who = character and Players:GetPlayerFromCharacter(character :: any)
			local walker = who and walkers[who]
			if who and walker and not walker.entered then
				enter(who, walker)
			end
		end)
	end
end

local function emerge(player: Player, built: any)
	walkers[player] = nil
	player:SetAttribute("InBetween", nil)
	local character = player.Character
	local back: BasePart? = built.refs.backEntrance
	if character and back then
		character:PivotTo(back.CFrame * CFrame.new(0, 3, 0))
	end
	PlayerState.restore(player)
	Net.notify(player, "Fade", { seconds = 0.8 })
	Net.notify(player, "Toast", { text = "You made it. Get to the bus." })
	BetweenService.Returned:Fire(player)
end

local function lose(player: Player)
	walkers[player] = nil
	player:SetAttribute("InBetween", nil)
	PlayerState.lose(player, "between")
end

local function inZone(player: Player, zone: BasePart): boolean
	local root = PlayerState.rootOf(player)
	if not root then
		return false
	end
	local rel = zone.CFrame:PointToObjectSpace(root.Position)
	local half = zone.Size / 2
	return math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y + 4 and math.abs(rel.Z) <= half.Z
end

-- Headlights coming down the path from the far end. Anyone still on the path is hit.
local function sweepStep(trail: Trail, dt: number)
	local t = now()
	if not trail.sweep and t >= trail.sweepAt then
		local m = Build.model(trail.model, "Headlights")
		for _, side in { -1.6, 1.6 } do
			local lamp = Build.part(m, {
				name = "Lamp",
				size = Vector3.new(1, 1, 0.4),
				cf = trail.points[#trail.points] * CFrame.new(side, 2.6, 0),
				color = C.White,
				material = Enum.Material.Neon,
				collide = false,
				group = "World",
			})
			local spot = Build.light(lamp, "Spot", Color3.fromRGB(255, 250, 230), 6, 60, false);
			(spot :: SpotLight).Face = Enum.NormalId.Back;
			(spot :: SpotLight).Angle = 50
		end
		trail.sweep = { model = m, s = trail.length }
		for player, w in walkers do
			if w.trail == trail and w.entered then
				Net.notify(player, "Sound", { key = "EngineFar" })
				Net.notify(player, "Toast", { text = "Headlights. Get off the path." })
			end
		end
	end
	local sweep = trail.sweep
	if not sweep then
		return
	end
	sweep.s -= 42 * dt
	if sweep.s <= 0 then
		sweep.model:Destroy()
		trail.sweep = nil
		trail.sweepAt = t + Config.Tuning.Between.HeadlightsEvery + math.random() * 14
		return
	end
	-- Position along the centreline.
	local seg = 40
	local i = math.clamp(math.floor(sweep.s / seg) + 1, 1, #trail.points - 1)
	local a, b = trail.points[i], trail.points[i + 1]
	local alpha = (sweep.s - (i - 1) * seg) / seg
	local pos = a.Position:Lerp(b.Position, alpha)
	local facing = CFrame.lookAt(pos, a.Position)
	sweep.model:PivotTo(facing * CFrame.new(0, 2.6, 0))
	for player, w in walkers do
		if w.trail == trail and w.entered then
			local root = PlayerState.rootOf(player)
			if root then
				local rel = facing:PointToObjectSpace(root.Position)
				if math.abs(rel.Z) < 3 and math.abs(rel.X) < 4.2 then
					lose(player)
				end
			end
		end
	end
end

function BetweenService.clearAll()
	for _, trail in trails do
		trail.model:Destroy()
	end
	table.clear(trails)
	for player in walkers do
		player:SetAttribute("InBetween", nil)
	end
	table.clear(walkers)
end

-- Take a walker out of the Between without an outcome (the First Ride's second chance).
function BetweenService.cancel(player: Player)
	walkers[player] = nil
	player:SetAttribute("InBetween", nil)
end

function BetweenService.isWalking(player: Player): boolean
	return walkers[player] ~= nil
end

function BetweenService:Init()
	PlayerState = Registry.get("PlayerStateService")
	World = Registry.get("WorldService")
	RunState = World.RunState
end

function BetweenService:Start()
	Director = Registry.find("RunDirector")
	RunService.Heartbeat:Connect(function(dt)
		local t = now()
		for player, w in walkers do
			if not player.Parent or PlayerState.state(player) ~= "LeftBehind" then
				walkers[player] = nil
				player:SetAttribute("InBetween", nil)
			elseif not w.entered and t >= w.enterAt then
				enter(player, w)
			elseif w.entered and Director then
				local current = Director.current
				local phase = RunState:GetAttribute("Phase")
				if
					current
					and current ~= w.trail.fromStop
					and (phase == "Stop" or phase == "Stalled")
					and inZone(player, w.trail.exitZone)
				then
					emerge(player, current)
				end
			end
		end
		for _, trail in trails do
			sweepStep(trail, dt)
		end
	end)
	if Director then
		-- A stop after the one they missed closed with them still walking: Lost.
		Director.StopClosed:Connect(function(built: any)
			for player, w in walkers do
				if w.trail.fromStop ~= built and w.trail.fromStop.index < built.index then
					lose(player)
				end
			end
			-- Old trails nobody walks are torn down.
			for from, trail in trails do
				local used = false
				for _, w in walkers do
					if w.trail == trail then
						used = true
					end
				end
				if not used and from ~= built then
					trail.model:Destroy()
					trails[from] = nil
				end
			end
		end)
	end
end

return BetweenService
