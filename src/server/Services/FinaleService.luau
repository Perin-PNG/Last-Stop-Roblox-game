--!strict
-- The Terminal finale (plan: 3 to 4 minutes).
--   1. The Driver gets up, walks off the bus and doesn't come back. The doors stay open.
--   2. Restore power: three breakers spread across the depot while threats met this run
--      roam the bays. More come the longer it takes.
--   3. The gate opens. The first rider to take the Driver's seat drives the bus out; the
--      doors close a few seconds later and anyone outside is Lost.
--   4. The drive: a long exit road with wrecks in the way. The tank leaks (pour from the
--      feed inside the bus), things pry at the doors (hold them shut) and the Latecomer
--      runs the bus down (flares stall it).
--   5. Dawn at Elm & 3rd. Home if nobody is Lost, Transfer if somebody is. A rider with
--      all three Driver clues who holds the mirror's gaze for three seconds during the
--      drive turns it into the Driver's Seat.
-- RunDirector calls FinaleService.run and ends the run with the ending it returns.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Build = require(Shared.Util.Build)
local Net = require(Shared.Net)
local Log = require(Shared.Log)

local Registry = require(script.Parent.Parent:WaitForChild("Registry"))

local Tuning = Config.Tuning.Finale
local BusTuning = Config.Tuning.Bus

local FinaleService = {}

FinaleService.step = "Idle"
FinaleService.secret = {} :: { [Player]: boolean }
FinaleService.wheelPrompt = nil :: ProximityPrompt?
FinaleService.wheelConns = {} :: { RBXScriptConnection }

local Bus: any
local Cabin: any
local Driver: any
local PlayerState: any
local Stops: any
local Route: any
local World: any
local RunState: Folder

local token = 0
local driveRun: any = nil -- the drive's live state, for remotes and flares

local ROAMERS = { Hunter = true, Listener = true, Watcher = true, Sentry = true }
local ESCALATE_EVERY = 45 -- seconds of power hunt before another threat joins
local MAX_ROAMERS = Config.Tuning.Budget.PathfindingEntities
local BOARD_SECONDS = 8 -- after someone takes the wheel, the doors close
local PRY_GRACE = 7 -- seconds to hold a pried door shut
local CHASER_SPEED = 40
local CHASER_SURGE = 62
local CHASER_START_GAP = 90
local OBSTACLE_EVERY = 80
local BUS_LENGTH = 56

local function setStep(step: string)
	FinaleService.step = step
	RunState:SetAttribute("FinaleStep", step)
end

local function healthyAboard(): { Player }
	local out = {}
	for _, player in Players:GetPlayers() do
		if PlayerState.isHealthy(player) and Bus.isAboard(player) then
			table.insert(out, player)
		end
	end
	return out
end

local function runPlayers(): { Player }
	local director = Registry.find("RunDirector")
	return if director then director.runPlayers() else Players:GetPlayers()
end

-- 1. The Driver gets up -------------------------------------------------------------------

local function driverLeaves(refs: any, built: any)
	local original: Model = refs.driverModel
	if not original or not original.Parent then
		return
	end
	local walker = original:Clone()
	for _, d in walker:GetDescendants() do
		if d:IsA("JointInstance") or d:IsA("WeldConstraint") or d:IsA("Constraint") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	for _, d in original:GetDescendants() do
		if d:IsA("BasePart") then
			d:SetAttribute("WasTransparency", d.Transparency)
			d.Transparency = 1
		end
	end
	walker.Name = "DriverLeaving"
	walker.Parent = World.Folders.Effects
	-- Stand, step into the aisle, out of the front door, across to the depot.
	local busCf: CFrame = Bus.busCFrame()
	local frame: CFrame = built.refs.frame
	local seat = walker:GetPivot()
	local points = {
		seat * CFrame.new(0, 1.2, 0),
		busCf * CFrame.new(1.5, 4.2, -24),
		busCf * CFrame.new(5, 4.2, -21.5),
		frame * CFrame.new(4, 4.2, -14),
		frame * CFrame.new(30, 4.2, -30),
		frame * CFrame.new(70, 4.2, -40),
	}
	Net.notifyAll("Sound", { key = "DoorCreak", part = refs.driverSeat })
	task.spawn(function()
		for i = 2, #points do
			local from = walker:GetPivot().Position
			local to = points[i].Position
			local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
			local seconds = math.max(0.6, (to - from).Magnitude / 6)
			local value = Instance.new("CFrameValue")
			value.Value = walker:GetPivot()
			local face = if flat.Magnitude > 0.1 then CFrame.lookAt(to, to + flat.Unit) else CFrame.new(to)
			local conn = value.Changed:Connect(function(cf: CFrame)
				if walker.Parent then
					walker:PivotTo(cf)
				end
			end)
			local tween = TweenService:Create(value, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { Value = face })
			tween:Play()
			tween.Completed:Wait()
			conn:Disconnect()
			value:Destroy()
		end
		task.wait(1)
		walker:Destroy()
	end)
end

-- 2. Restore power ------------------------------------------------------------------------

local function threatsMet(): { string }
	local out: { string } = {}
	for id in Route.used do
		local def = Config.Stops.Stops[id]
		local threat = def and def.threat
		if threat then
			local edef = Config.Entities[threat]
			if edef and ROAMERS[edef.behavior] and threat ~= "clerk" and not table.find(out, threat) then
				table.insert(out, threat)
			end
		end
	end
	if #out == 0 then
		table.insert(out, "resident")
	end
	return out
end

local function restorePower(built: any, alive: () -> boolean): boolean
	setStep("Power")
	local refs = built.refs
	local breakers: { BasePart } = refs.extras.breakers or {}
	local needed = math.min(Tuning.Breakers, #breakers)
	local flipped = 0
	RunState:SetAttribute("Breakers", 0)
	RunState:SetAttribute("BreakersNeeded", needed)
	local prompts: { ProximityPrompt } = {}
	for i, box in breakers do
		local prompt = Build.prompt(box, "Flip breaker", "Main " .. i, 2, 7, "BreakerPrompt")
		prompt.RequiresLineOfSight = false
		table.insert(prompts, prompt)
		prompt.Triggered:Connect(function(player: Player)
			if not PlayerState.isHealthy(player) or box:GetAttribute("Flipped") then
				return
			end
			local root = PlayerState.rootOf(player)
			if not root or (root.Position - box.Position).Magnitude > 12 then
				return
			end
			box:SetAttribute("Flipped", true)
			prompt.Enabled = false
			local lamp = box.Parent and box.Parent:FindFirstChild("Lamp" .. i)
			if lamp and lamp:IsA("BasePart") then
				lamp.Color = Color3.fromRGB(60, 255, 90)
			end
			flipped += 1
			RunState:SetAttribute("Breakers", flipped)
			Net.notifyAll("Sound", { key = "Breaker", part = box })
			Net.notifyAll("Toast", { text = string.format("Breaker %d of %d.", flipped, needed) })
		end)
	end
	Net.notifyAll("Toast", { text = string.format("The power's out. Find %d breakers in the depot.", needed) })
	-- Threats from this run roam the bays, and more come the longer it takes.
	local Entities = Registry.find("EntityService")
	local pool = threatsMet()
	local spawns = refs.entitySpawns
	local roamers = 0
	local function loose()
		if not Entities or roamers >= MAX_ROAMERS or #spawns == 0 then
			return
		end
		roamers += 1
		local id = pool[((roamers - 1) % #pool) + 1]
		Entities.spawnAt(built, id, spawns[((roamers - 1) % #spawns) + 1].CFrame)
		Log.info("Finale", "Loosed", id)
	end
	local started = os.clock()
	local nextLoose = started + 8
	local firstWave = math.min(Tuning.RoamingEntities, MAX_ROAMERS)
	while alive() and flipped < needed do
		local t = os.clock()
		if t >= nextLoose then
			loose()
			nextLoose = if roamers < firstWave then t + 4 else t + ESCALATE_EVERY
		end
		if PlayerState.allLost() then
			return false
		end
		task.wait(0.25)
	end
	for _, p in prompts do
		p:Destroy()
	end
	if not alive() then
		return false
	end
	-- The power comes back.
	for _, l in refs.extras.hallLights or {} do
		l.Enabled = true
	end
	for _, l in refs.extras.emergency or {} do
		l.Enabled = false
		local lamp = l.Parent
		if lamp and lamp:IsA("BasePart") then
			lamp.Color = Color3.fromRGB(40, 20, 20)
		end
	end
	Net.notifyAll("Sound", { key = "PowerHum", part = breakers[1] })
	local gate: BasePart? = refs.extras.gate
	if gate then
		Net.notifyAll("Sound", { key = "GateOpen", part = gate })
		gate.CanCollide = false
		TweenService
			:Create(gate, TweenInfo.new(5, Enum.EasingStyle.Quad), { CFrame = gate.CFrame * CFrame.new(0, 17, 0) })
			:Play()
	end
	Net.notifyAll("Toast", { text = "Power's back. The gate is opening. Someone has to drive." })
	return true
end

-- 3. Take the wheel ----------------------------------------------------------------------

local function seatedPlayer(seat: VehicleSeat): Player?
	local humanoid = seat.Occupant
	if not humanoid then
		return nil
	end
	return Players:GetPlayerFromCharacter(humanoid.Parent)
end

local function takeTheWheel(alive: () -> boolean): boolean
	setStep("Board")
	local refs = Bus.refs
	local seat: VehicleSeat = refs.driverSeat
	seat.Disabled = false
	local prompt = Build.prompt(seat, "Take the wheel", "Driver's seat", 1, 6, "WheelPrompt")
	prompt.RequiresLineOfSight = false
	local conn = prompt.Triggered:Connect(function(player: Player)
		if seat.Occupant or not PlayerState.isHealthy(player) or not Bus.isAboard(player) then
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			seat:Sit(humanoid)
		end
	end)
	local occupied = seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		prompt.Enabled = seat.Occupant == nil
	end)
	FinaleService.wheelPrompt = prompt
	FinaleService.wheelConns = { conn, occupied }
	-- Wait for a driver, then a short count before the doors close.
	while alive() and not seatedPlayer(seat) do
		if PlayerState.allLost() then
			return false
		end
		task.wait(0.25)
	end
	if not alive() then
		return false
	end
	local driver = seatedPlayer(seat)
	Net.notifyAll("Toast", {
		text = string.format(
			"%s is at the wheel. Doors close in %d seconds.",
			if driver then driver.DisplayName else "Someone",
			BOARD_SECONDS
		),
	})
	Driver.say(string.format(Config.Text.PA.departingSoon, BOARD_SECONDS))
	task.wait(BOARD_SECONDS)
	Bus.setDoors(false)
	task.wait(BusTuning.DoorOpenTime + 0.2)
	-- Anyone not aboard now stays at the Terminal.
	for _, player in runPlayers() do
		local state = PlayerState.state(player)
		if state ~= "Static" and state ~= "Lobby" and not Bus.isAboard(player) then
			PlayerState.lose(player, "terminal")
			Net.notify(player, "Toast", { text = "The bus leaves the Terminal without you." })
		end
	end
	return true
end

-- 4. The drive ----------------------------------------------------------------------------

local function obstacleModel(cf: CFrame, kind: number): Model
	local m = Build.model(World.Folders.Effects, "Obstacle")
	if kind == 1 then
		-- A burnt-out car across the lane.
		Build.part(m, {
			name = "Wreck",
			size = Vector3.new(9, 3.6, 5),
			cf = cf * CFrame.new(0, 1.8, 0) * CFrame.Angles(0, math.rad(80), math.rad(8)),
			color = Color3.fromRGB(50, 44, 40),
			material = Enum.Material.CorrodedMetal,
			collide = false,
		})
		Build.part(m, {
			name = "Cab",
			size = Vector3.new(5, 2, 4.4),
			cf = cf * CFrame.new(0, 4.4, 0) * CFrame.Angles(0, math.rad(80), 0),
			color = Color3.fromRGB(36, 32, 30),
			material = Enum.Material.CorrodedMetal,
			collide = false,
		})
	elseif kind == 2 then
		-- Barrels and a sawhorse.
		for i = -1, 1 do
			Build.part(m, {
				name = "Barrel",
				size = Vector3.new(2.4, 3.4, 2.4),
				cf = cf * CFrame.new(i * 2.8, 1.7, 0),
				color = Color3.fromRGB(220, 110, 30),
				material = Enum.Material.Plastic,
				shape = Enum.PartType.Cylinder,
				collide = false,
			}).CFrame = cf
				* CFrame.new(i * 2.8, 1.7, 0)
				* CFrame.Angles(0, 0, math.rad(90))
		end
		Build.part(m, {
			name = "Sawhorse",
			size = Vector3.new(8, 0.6, 0.4),
			cf = cf * CFrame.new(0, 3, -1.6),
			color = Color3.fromRGB(230, 230, 230),
			collide = false,
		})
	else
		-- A fallen route sign on its pole.
		Build.part(m, {
			name = "Pole",
			size = Vector3.new(0.6, 0.6, 12),
			cf = cf * CFrame.new(0, 0.8, 0) * CFrame.Angles(0, math.rad(90), 0),
			color = Color3.fromRGB(80, 80, 84),
			material = Enum.Material.Metal,
			collide = false,
		})
		Build.part(m, {
			name = "Sign",
			size = Vector3.new(4, 0.3, 3),
			cf = cf * CFrame.new(5, 1, 0),
			color = Color3.fromRGB(30, 80, 160),
			collide = false,
		})
	end
	return m
end

local function chaserModel(): Model
	local m = Build.model(World.Folders.Effects, "Latecomer")
	local coat = Color3.fromRGB(22, 22, 26)
	local torso = Build.part(m, {
		name = "Torso",
		size = Vector3.new(2.4, 3.4, 1.2),
		cf = CFrame.new(0, 5, 0),
		color = coat,
		material = Enum.Material.Fabric,
		collide = false,
	})
	for _, side in { -1, 1 } do
		Build.part(m, {
			name = "Leg",
			size = Vector3.new(1, 3.4, 1),
			cf = CFrame.new(side * 0.6, 1.7, 0),
			color = coat,
			material = Enum.Material.Fabric,
			collide = false,
		})
		Build.part(m, {
			name = "Arm",
			size = Vector3.new(0.8, 3.6, 0.8),
			cf = CFrame.new(side * 1.7, 4.8, -0.6) * CFrame.Angles(math.rad(-60), 0, 0),
			color = coat,
			material = Enum.Material.Fabric,
			collide = false,
		})
	end
	Build.part(m, {
		name = "Head",
		size = Vector3.new(1.4, 1.6, 1.4),
		cf = CFrame.new(0, 7.6, 0),
		color = Color3.fromRGB(200, 196, 190),
		collide = false,
	})
	m.PrimaryPart = torso
	return m
end

-- A part welded inside the moving bus, at a bus-local offset.
local function busPart(name: string, size: Vector3, offset: CFrame, color: Color3): BasePart
	local refs = Bus.refs
	local p = Build.part(refs.model, {
		name = name,
		size = size,
		cf = refs.root.CFrame * CFrame.new(0, 0.5, 0) * offset,
		color = color,
		collide = false,
		anchored = refs.root.Anchored,
		group = "Bus",
	})
	p.Massless = true
	if not refs.root.Anchored then
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = refs.root
		weld.Part1 = p
		weld.Parent = p
	end
	return p
end

local function drive(built: any, alive: () -> boolean)
	setStep("Drive")
	local refs = Bus.refs
	local seat: VehicleSeat = refs.driverSeat
	local Chunks = Registry.get("ChunkService")
	local path = Chunks.path
	local startS: number = Bus.s
	local length = Tuning.DriveSpeed * Tuning.DriveSeconds * 0.85
	local goalS = startS + length
	Bus.beginManual()
	Bus.setLights(true)
	Bus.setHeadlights(true)
	Net.notifyAll("Sound", { key = "EngineStart", part = refs.root })
	Net.notifyAll("Hint", { id = "drive" })
	local rng = Random.new(built.index * 977 + 13)

	-- Obstacles along the exit road.
	local obstacles: { { s: number, lat: number, half: number, model: Model, hit: boolean } } = {}
	local nextObstacleS = startS + 140
	local function placeObstacles()
		-- Only on road that exists: fillers are added ahead of the bus as it goes.
		local limit = math.min(goalS - 40, path:length() - 20)
		while nextObstacleS < limit do
			local lat = rng:NextNumber(-Tuning.DriveLaneHalfWidth + 2, Tuning.DriveLaneHalfWidth - 2)
			local kind = rng:NextInteger(1, 3)
			local cf = path:sample(nextObstacleS) * CFrame.new(lat, 0, 0)
			table.insert(obstacles, {
				s = nextObstacleS,
				lat = lat,
				half = if kind == 3 then 6 else 4.5,
				model = obstacleModel(cf, kind),
				hit = false,
			})
			nextObstacleS += OBSTACLE_EVERY + rng:NextNumber(-20, 25)
		end
	end
	placeObstacles()

	-- The fuel feed inside the bus, by the back door.
	local feed = busPart("TankFeed", Vector3.new(0.6, 1.2, 1.2), CFrame.new(-5.4, 3, 20), Color3.fromRGB(170, 30, 30))
	local pour = Build.prompt(feed, "Pour fuel", "Tank feed", BusTuning.FuelPourSeconds, 6, "FeedPrompt")
	pour.RequiresLineOfSight = false
	local pourConn = pour.Triggered:Connect(function(player: Player)
		if not PlayerState.isHealthy(player) or not Bus.isAboard(player) then
			return
		end
		local Inventory = Registry.find("InventoryService")
		if Inventory and Inventory.take(player, "fuel") then
			Cabin.addFuel(BusTuning.FuelPerCan)
			Net.notify(player, "Toast", { text = `+{BusTuning.FuelPerCan} fuel` })
			Net.notifyAll("Sound", { key = "PourFuel", part = feed })
		else
			Net.notify(player, "Toast", { text = "You need a fuel can." })
		end
	end)

	local chaser = chaserModel()
	local chase = { s = startS - CHASER_START_GAP, stallUntil = 0, surgeUntil = 0, nextSurge = os.clock() + 15 }
	local state = { obstacles = obstacles, chase = chase }
	driveRun = state

	local secretHeld: { [Player]: number } = {}
	local Journal = Registry.find("JournalService")
	local Gaze = Registry.find("GazeService")
	local Dread = Registry.find("DreadService")
	local pries: { { part: BasePart, prompt: ProximityPrompt, deadline: number, held: boolean } } = {}
	local nextPry = os.clock() + Tuning.PryEvery
	local started = os.clock()
	local lastTick = os.clock()
	local warnedEmpty = false
	while alive() and Bus.s < goalS and os.clock() - started < Tuning.DriveSeconds * 2.5 do
		local t = os.clock()
		local dt = t - lastTick
		lastTick = t
		if PlayerState.allLost() then
			break
		end
		-- No one (or no one able) at the wheel: no throttle.
		local wheel = seatedPlayer(seat)
		if not wheel or not PlayerState.isHealthy(wheel) then
			Bus.setInput(0, 0)
		end
		RunState:SetAttribute("DriveProgress", math.clamp((Bus.s - startS) / length, 0, 1))
		-- The leak.
		Cabin.addFuel(-Tuning.LeakPerSecond * dt)
		if Cabin.fuel() <= 0 then
			if not warnedEmpty then
				warnedEmpty = true
				Net.notifyAll("Toast", { text = "The engine dies. Pour fuel at the feed by the back door!" })
			end
		else
			warnedEmpty = false
		end
		-- Obstacles, on road kept ahead of the bus.
		Chunks.ensureAhead(Bus.s)
		placeObstacles()
		for _, o in obstacles do
			if not o.hit and math.abs(o.s - Bus.s) < BUS_LENGTH / 2 and math.abs(o.lat - Bus.lateral) < 6 + o.half then
				o.hit = true
				Bus.jolt(Tuning.ObstacleSlowSeconds)
				Net.notifyAll("Sound", { key = "Crash", part = refs.root })
				Net.notifyAll("Shake", { strength = 0.8, seconds = 0.6 })
				for _, player in healthyAboard() do
					if Dread then
						Dread.add(player, 4)
					end
				end
				local fling = o.model
				for _, part in fling:GetDescendants() do
					if part:IsA("BasePart") then
						TweenService
							:Create(part, TweenInfo.new(0.8), {
								CFrame = part.CFrame * CFrame.new(rng:NextNumber(-8, 8), 6, rng:NextNumber(-12, -4)),
								Transparency = 1,
							})
							:Play()
					end
				end
				task.delay(1, function()
					fling:Destroy()
				end)
			end
		end
		-- The doors are pried at.
		if t >= nextPry then
			nextPry = t + Tuning.PryEvery
			local doorZ = if rng:NextNumber() < 0.5 then -21.5 else 1.5
			local hands =
				busPart("PryHands", Vector3.new(0.6, 6, 1.4), CFrame.new(5.6, 4, doorZ), Color3.fromRGB(140, 150, 145))
			local prompt = Build.prompt(hands, "Hold shut", "Door", Tuning.PryHoldSeconds, 7, "PryPrompt")
			prompt.RequiresLineOfSight = false
			local entry =
				{ part = hands, prompt = prompt, deadline = t + PRY_GRACE + Tuning.PryHoldSeconds, held = false }
			prompt.Triggered:Connect(function(player: Player)
				if PlayerState.isHealthy(player) and Bus.isAboard(player) then
					entry.held = true
				end
			end)
			table.insert(pries, entry)
			Net.notifyAll("Sound", { key = "Pry", part = hands })
			Net.notifyAll("Toast", { text = "Something is prying the doors open!" })
		end
		for i = #pries, 1, -1 do
			local p = pries[i]
			if p.held then
				p.part:Destroy()
				table.remove(pries, i)
				Net.notifyAll("Toast", { text = "The door holds." })
			elseif t >= p.deadline then
				-- It got the door open long enough to take someone.
				local best: Player? = nil
				local bestD = 16
				for _, player in healthyAboard() do
					local root = PlayerState.rootOf(player)
					if root and seatedPlayer(seat) ~= player then
						local d = (root.Position - p.part.Position).Magnitude
						if d < bestD then
							bestD = d
							best = player
						end
					end
				end
				if best then
					PlayerState.down(best, "pried")
					Net.notify(best, "Toast", { text = "Hands through the door, then dark." })
				end
				Net.notifyAll("Sound", { key = "DoorHiss", part = p.part })
				p.part:Destroy()
				table.remove(pries, i)
			end
		end
		-- The Latecomer runs the bus down. Flares stall it; a slow bus feeds it.
		if t >= chase.nextSurge then
			chase.nextSurge = t + 15
			chase.surgeUntil = t + 4
		end
		local cs = if t < chase.stallUntil then 0 elseif t < chase.surgeUntil then CHASER_SURGE else CHASER_SPEED
		chase.s = math.max(chase.s + cs * dt, Bus.s - 130)
		local gap = Bus.s - BUS_LENGTH / 2 - chase.s
		RunState:SetAttribute("LatecomerDistance", math.floor(math.max(0, gap)))
		local ccf = path:sample(chase.s) * CFrame.new(Bus.lateral, 0.4, 0)
		chaser:PivotTo(ccf * CFrame.new(0, 5, 0) * CFrame.Angles(0, 0, math.rad(math.sin(t * 9) * 4)))
		if gap <= 2 then
			-- It catches the back of the bus and drags someone out through the rear window.
			local back: Player? = nil
			for _, player in healthyAboard() do
				if seatedPlayer(seat) ~= player then
					back = player
					break
				end
			end
			if back then
				PlayerState.down(back, "latecomer")
				Net.notify(back, "Toast", { text = "It caught the bus." })
			end
			Net.notifyAll("Sound", { key = "LatecomerHiss", part = refs.root })
			chase.s = Bus.s - 80
		end
		-- The secret: the mirror's gaze, held, by a rider who knows.
		if Gaze and Journal then
			for _, player in healthyAboard() do
				if not FinaleService.secret[player] and Journal.allClues(player) then
					local looking = Gaze.isLookingAt(
						player,
						refs.mirror.Position,
						Config.Tuning.Mirror.ConeDegrees,
						Config.Tuning.Mirror.Range
					)
					secretHeld[player] = if looking then (secretHeld[player] or 0) + dt else 0
					if secretHeld[player] >= Tuning.SecretGazeSeconds then
						FinaleService.secret[player] = true
						Net.notify(player, "MirrorSelf", {})
						Net.notify(player, "Toast", { text = "The face in the mirror is yours." })
						Log.info("Finale", player.Name, "held the mirror's gaze")
					end
				end
			end
		end
		task.wait(0.1)
	end
	driveRun = nil
	pourConn:Disconnect()
	feed:Destroy()
	chaser:Destroy()
	for _, p in pries do
		p.part:Destroy()
	end
	for _, o in obstacles do
		if o.model.Parent then
			o.model:Destroy()
		end
	end
	RunState:SetAttribute("LatecomerDistance", nil)
	RunState:SetAttribute("DriveProgress", 1)
	Bus.setInput(0, 0)
end

-- 5. Dawn ---------------------------------------------------------------------------------

local function dawn()
	setStep("Dawn")
	Net.notifyAll("Sound", { key = "Dawn" })
	Net.notifyAll("Dawn", {})
	TweenService:Create(Lighting, TweenInfo.new(6), {
		ClockTime = 6.4,
		Brightness = 2,
		Ambient = Color3.fromRGB(120, 110, 100),
		OutdoorAmbient = Color3.fromRGB(150, 140, 130),
		FogColor = Color3.fromRGB(230, 200, 170),
		FogEnd = 1400,
	}):Play()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		TweenService:Create(atmosphere, TweenInfo.new(6), {
			Color = Color3.fromRGB(230, 200, 170),
			Decay = Color3.fromRGB(200, 150, 120),
			Density = 0.3,
		}):Play()
	end
	-- Coast to a stop.
	Bus.setInput(0, 0)
	task.wait(6)
	Bus.endManual()
end

-- The run -------------------------------------------------------------------------------

-- Run the whole finale at the built Terminal. Returns the ending, or nil if the run was
-- cut short (everyone left, a restart).
function FinaleService.run(built: any, alive: () -> boolean): string?
	token += 1
	local mine = token
	local function live(): boolean
		return mine == token and alive()
	end
	table.clear(FinaleService.secret)
	RunState:SetAttribute("Phase", "Finale")
	Cabin.cordEnabled = false
	Cabin.holdEnabled = false
	Driver.mirrorEnabled = false
	Stops.stock(built, #runPlayers(), false)
	Stops.activate(built, workspace:GetServerTimeNow() + 600)

	-- 1. The Driver gets up.
	setStep("Arrive")
	Driver.say(Config.Text.PA.terminal)
	Bus.setDoors(true)
	task.wait(2)
	driverLeaves(Bus.refs, built)
	Net.notifyAll("Toast", { text = "The Driver gets up. He walks off the bus and doesn't look back." })
	task.wait(6)
	if not live() then
		return nil
	end

	-- 2. Power.
	if not restorePower(built, live) then
		return if live() then "LastStop" else nil
	end
	-- 3. The wheel.
	if not takeTheWheel(live) then
		return if live() then "LastStop" else nil
	end
	if PlayerState.allLost() then
		return "LastStop"
	end
	-- 4. The drive. What roamed the depot stays in the depot.
	local Entities = Registry.find("EntityService")
	if Entities then
		Entities.clearStop(built)
	end
	drive(built, live)
	if not live() then
		return nil
	end
	if PlayerState.allLost() then
		return "LastStop"
	end
	-- 5. Dawn.
	dawn()
	local lost = 0
	for _, player in runPlayers() do
		if PlayerState.state(player) == "Static" then
			lost += 1
		end
	end
	if next(FinaleService.secret) then
		return "DriversSeat"
	end
	return if lost > 0 then "Transfer" else "Home"
end

-- Clean up after the run (the bus and stop are torn down by their own services).
function FinaleService.reset()
	token += 1
	driveRun = nil
	setStep("Idle")
	if FinaleService.wheelPrompt then
		FinaleService.wheelPrompt:Destroy()
		FinaleService.wheelPrompt = nil
	end
	for _, c in FinaleService.wheelConns do
		c:Disconnect()
	end
	table.clear(FinaleService.wheelConns)
	if Driver then
		Driver.mirrorEnabled = true
	end
	if Bus and Bus.state == "Manual" then
		Bus.endManual()
	end
	-- If the same bus carries on, put the Driver back in his seat and lock the wheel.
	local refs = Bus and Bus.refs
	if refs and refs.model and refs.model.Parent then
		refs.driverSeat.Disabled = true
		for _, d in refs.driverModel:GetDescendants() do
			local was = d:GetAttribute("WasTransparency")
			if d:IsA("BasePart") and type(was) == "number" then
				d.Transparency = was
				d:SetAttribute("WasTransparency", nil)
			end
		end
	end
	World.resetLighting()
	for _, name in { "DriverLeaving", "Latecomer", "Obstacle" } do
		for _, child in World.Folders.Effects:GetChildren() do
			if child.Name == name then
				child:Destroy()
			end
		end
	end
end

-- A flare landed somewhere: during the drive, one thrown in the back half of the bus
-- (or behind it) stalls the Latecomer.
function FinaleService.flare(at: Vector3)
	local run = driveRun
	if not run or not Bus.refs then
		return
	end
	local rel = Bus.refs.root.CFrame:PointToObjectSpace(at)
	if rel.Z > 0 then
		run.chase.stallUntil = math.max(run.chase.stallUntil, os.clock()) + Config.Tuning.Items.FlareStunSeconds + 1
		Net.notifyAll("Sound", { key = "LatecomerHiss", part = Bus.refs.root })
		Net.notifyAll("Toast", { text = "The flare holds it back." })
	end
end

function FinaleService:Init()
	Bus = Registry.get("BusService")
	Cabin = Registry.get("CabinService")
	Driver = Registry.get("DriverService")
	PlayerState = Registry.get("PlayerStateService")
	Stops = Registry.get("StopService")
	Route = Registry.get("RouteService")
	World = Registry.get("WorldService")
	RunState = World.RunState
	RunState:SetAttribute("FinaleStep", "Idle")
end

function FinaleService:Start()
	-- The wheel: only the rider in the Driver's seat, during the drive.
	Net.on("Drive", function(player: Player, throttle: any, steer: any)
		if FinaleService.step ~= "Drive" or not Bus.refs then
			return
		end
		if not Net.isFiniteNumber(throttle) or not Net.isFiniteNumber(steer) then
			return
		end
		local seat: VehicleSeat = Bus.refs.driverSeat
		if seatedPlayer(seat) ~= player or not PlayerState.isHealthy(player) then
			return
		end
		Bus.setInput(math.clamp(throttle, 0, 1), math.clamp(steer, -1, 1))
	end)
	local director = Registry.find("RunDirector")
	if director then
		director.RunStarted:Connect(function()
			FinaleService.reset()
		end)
		director.RunEnded:Connect(function()
			task.delay(Config.Tuning.Run.EndScreenSeconds, function()
				if not director.running then
					FinaleService.reset()
				end
			end)
		end)
	end
end

return FinaleService
