--!strict
-- The run's main loop: ride, arrive, scavenge against the departure timer, close the
-- doors and leave. Everything else (route, anomalies, threats, the Latecomer, The
-- Between) hangs off the signals and calls here.
--
-- Deadlines replicate as one GetServerTimeNow() value; every client counts down locally.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Seed = require(Shared.Util.Seed)
local Signal = require(Shared.Util.Signal)
local Net = require(Shared.Net)
local Place = require(Shared.Place)
local Log = require(Shared.Log)

local Registry = require(script.Parent.Parent:WaitForChild("Registry"))

local Tuning = Config.Tuning
local PA = Config.Text.PA

local RunDirector = {}

RunDirector.running = false
RunDirector.seed = 0
RunDirector.mode = "Standard"
RunDirector.party = false
RunDirector.stopIndex = 0
RunDirector.skipRequested = false
RunDirector.players = {} :: { [Player]: boolean }
RunDirector.token = 0
RunDirector.stopsSurvived = 0
RunDirector.current = nil :: any -- BuiltStop

RunDirector.RunStarted = Signal.new() -- (players)
RunDirector.RunEnded = Signal.new() -- (ending, summary)
RunDirector.StopOpened = Signal.new() -- (built, deadline)
RunDirector.StopClosed = Signal.new() -- (built)
RunDirector.RideStarted = Signal.new() -- (index)

local Bus: any
local Chunks: any
local Stops: any
local Route: any
local Driver: any
local Cabin: any
local Rules: any
local PlayerState: any
local Inventory: any
local RunState: Folder

local function now(): number
	return workspace:GetServerTimeNow()
end

local function find(name: string): any?
	return Registry.find(name)
end

function RunDirector.isParty(): boolean
	return RunDirector.party
end

function RunDirector.inRun(player: Player): boolean
	return RunDirector.players[player] == true
end

function RunDirector.runPlayers(): { Player }
	local out = {}
	for player in RunDirector.players do
		if player.Parent then
			table.insert(out, player)
		end
	end
	return out
end

-- Put a character inside the bus: in a free seat if there is one, else the aisle.
function RunDirector.placeInBus(character: Model)
	local refs = Bus.refs
	if not refs then
		return
	end
	local cf: CFrame
	local free: { Seat } = {}
	local back: { [Seat]: boolean } = {}
	for _, seat in refs.backRowSeats do
		back[seat] = true
	end
	for _, seat in refs.seats do
		if not seat.Occupant and not back[seat] then
			table.insert(free, seat)
		end
	end
	if #free > 0 then
		local seat = free[math.random(1, #free)]
		cf = seat.CFrame * CFrame.new(0, 3, 0)
	else
		cf = refs.root.CFrame * CFrame.new(0, 3.5, math.random(-12, 18))
	end
	character:PivotTo(cf)
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.AssemblyLinearVelocity = Bus.velocity()
	end
end

local function waitFor(seconds: number, token: number, skippable: boolean?, until_: (() -> boolean)?): boolean
	local t = 0
	while t < seconds do
		if token ~= RunDirector.token then
			return false
		end
		if skippable and RunDirector.skipRequested then
			RunDirector.skipRequested = false
			return true
		end
		if until_ and until_() then
			return true
		end
		t += task.wait(0.1)
	end
	return true
end

local function alive(token: number): boolean
	return RunDirector.running and token == RunDirector.token
end

local function clockText(index: number): string
	local minutes = 118 + index * 4 -- 1:58 AM plus four minutes a stop
	local h = math.floor(minutes / 60) % 12
	if h == 0 then
		h = 12
	end
	return string.format("%d:%02d AM", h, minutes % 60)
end

local function playerCount(): number
	local n = 0
	for _, player in RunDirector.runPlayers() do
		if PlayerState.state(player) ~= "Static" then
			n += 1
		end
	end
	return math.max(1, n)
end

local function timerFor(tier: number, overtime: number): number
	local base: number
	if overtime > 0 then
		base = Tuning.Stop.OvertimeTimer
	else
		base = Tuning.Stop.DepartureTimer[math.clamp(tier, 1, 3)]
	end
	local n = #RunDirector.runPlayers()
	if n <= 1 then
		base *= 1.15
	elseif n == 2 then
		base *= 1.05
	end
	if RunDirector.mode == "Tutorial" then
		base = math.max(base, 120)
	end
	return math.floor(base)
end

local function stationaryYard(index: number): CFrame
	return CFrame.new((index % 3) * 3000 - 3000, 0, -6000)
end

-- Ride ----------------------------------------------------------------------------------

local function burnFuel(tier: number)
	local burn = Tuning.Bus.FuelPerRide[math.clamp(tier, 1, 3)] or 1
	if (RunState:GetAttribute("Overtime") :: number? or 0) > 0 then
		burn = 2
	end
	Cabin.setFuel(Cabin.fuel() - burn)
end

-- Drive to the next stop and build it. Returns the built stop, or nil if the run ended.
local function ride(index: number, token: number, first: boolean): any?
	local entry = Route.prepare(index)
	if not entry then
		return nil
	end
	RunDirector.stopIndex = index
	RunState:SetAttribute("Phase", if first then "Boarding" else "Ride")
	RunState:SetAttribute("Clock", clockText(index))
	RunDirector.RideStarted:Fire(index)
	if not first then
		Bus.depart()
		burnFuel(entry.tier)
		Driver.say(string.format(PA.nextStop, RunState:GetAttribute("NextStopName") or "unknown"))
		if Driver.forceTunnel and Bus.mode == "Physics" then
			Driver.forceTunnel = false
			Chunks.appendFiller("tunnel")
			Driver.say(PA.blackout)
		end
	end
	local rng = Seed.new(RunDirector.seed):child("ride" .. index)
	local rideSeconds = rng:float(Tuning.Ride.MinRideSeconds, Tuning.Ride.MaxRideSeconds)
	if Route.ballot then
		Route.openVote(Tuning.Ride.VoteWindow)
		waitFor(Tuning.Ride.VoteWindow, token, true)
		if not alive(token) then
			return nil
		end
	elseif not first then
		waitFor(math.max(4, rideSeconds * 0.4), token, true)
		if not alive(token) then
			return nil
		end
	end
	local nextStop = Route.closeVote()
	if not nextStop then
		return nil
	end
	local id = nextStop.id
	local tier = math.clamp(nextStop.tier, 1, 4)
	RunState:SetAttribute("Tier", tier)
	if Rules then
		Rules.maybeAddFake(RunDirector.seed, tier)
	end
	local built: any
	if Bus.mode == "Physics" then
		local chunk = if nextStop.terminal then Chunks.appendTerminal() else Chunks.appendStop(id)
		built = Stops.build(id, chunk.curbCf, index, tier, RunDirector.seed, nextStop.loopCheck)
		built.chunk = chunk
		Route.commit(id)
		Bus.driveTo(chunk.curbS)
		RunState:SetAttribute("Phase", "Arriving")
		local arrived = false
		local conn = Bus.Arrived:Connect(function()
			arrived = true
		end)
		waitFor(240, token, false, function()
			return arrived
		end)
		conn:Disconnect()
	else
		Bus.placeAt(Bus.RideSpot, Tuning.Bus.LaneOffset)
		if not first then
			waitFor(math.max(6, Tuning.Ride.StationaryRideSeconds - Tuning.Ride.VoteWindow), token, true)
		end
		Bus.driveTo(Bus.s + 150)
		RunState:SetAttribute("Phase", "Arriving")
		local arrived = false
		local conn = Bus.Arrived:Connect(function()
			arrived = true
		end)
		waitFor(30, token, false, function()
			return arrived
		end)
		conn:Disconnect()
		Net.notifyAll("Fade", { seconds = 0.6 })
		task.wait(0.6)
		local yard = stationaryYard(index)
		Chunks.newPath(RunDirector.seed + index, yard)
		Chunks.appendLeadIn(200)
		local chunk = if nextStop.terminal then Chunks.appendTerminal() else Chunks.appendStop(id)
		built = Stops.build(id, chunk.curbCf, index, tier, RunDirector.seed, nextStop.loopCheck)
		built.chunk = chunk
		Route.commit(id)
		Bus.placeAt(chunk.curbCf, Bus.PullInOffset)
	end
	if not alive(token) then
		return nil
	end
	built.terminal = nextStop.terminal
	built.overtime = nextStop.overtime
	return built
end

-- Stop ----------------------------------------------------------------------------------

local function someoneOutside(): boolean
	for _, player in RunDirector.runPlayers() do
		local s = PlayerState.state(player)
		if s == "Outside" then
			return true
		end
	end
	return false
end

-- Push the Patience-zero offender out of the doors.
local function eject(player: Player, built: any)
	local character = player.Character
	if not character then
		return
	end
	local cf = built.refs.frame * CFrame.new(6, 3, 0)
	character:PivotTo(cf * CFrame.Angles(0, math.rad(90), 0))
	Net.notify(player, "Toast", { text = "The Driver has put you off the bus." })
end

local function runStop(built: any, token: number)
	local index = RunDirector.stopIndex
	local tier = built.tier
	local def = Config.Stops.Stops[built.id]
	RunDirector.current = built
	RunState:SetAttribute("StopId", built.id)
	RunState:SetAttribute("StopName", if def then def.name else built.id)
	RunState:SetAttribute("StopIndex", index)
	local count = playerCount()
	local stalled = Cabin.fuel() <= 0
	Stops.stock(built, count, stalled)
	local anomalies = find("AnomalyService")
	if anomalies then
		anomalies.apply(built, Route.gasVisits)
	end
	local entities = find("EntityService")
	if entities then
		entities.setupStop(built)
	end
	-- Arrive.
	RunState:SetAttribute("Phase", "Stop")
	Driver.say(if def and def.announce then def.announce else string.format(PA.arriving, def and def.name or "Stop"))
	local loopCheck = built.loopCheck ~= nil
	if loopCheck then
		Net.notifyAll("Hint", { id = "loop_check" })
	end
	local timer = timerFor(tier, built.overtime or 0)
	local ejected: Player? = nil
	if Driver.ejectNext then
		ejected = Driver.ejectNext
		timer = 12
	end
	local deadline = now() + timer
	RunState:SetAttribute("Timer", timer)
	RunState:SetAttribute("Deadline", deadline)
	Cabin.resetCord()
	Bus.setDoors(true)
	Cabin.cordEnabled = true
	if ejected and ejected.Parent then
		eject(ejected, built)
		Driver.afterEject()
	end
	Stops.activate(built, deadline)
	RunDirector.StopOpened:Fire(built, deadline)
	local latecomer = find("LatecomerService")
	if latecomer and not built.terminal then
		latecomer.schedule(built, deadline, tier, timer, built.overtime or 0)
	end
	-- The departure timer.
	local departByCord = false
	local cordConn = Cabin.CordDepart:Connect(function()
		departByCord = true
	end)
	local gotOff = false
	local bellsRung: { [number]: boolean } = {}
	local clerkLoosed = false
	waitFor(timer + 1, token, true, function()
		if someoneOutside() then
			gotOff = true
			if loopCheck and anomalies and anomalies.loopAnomalous(built) and not clerkLoosed then
				clerkLoosed = true
				Driver.change(-Tuning.Patience.GasAndGoWrongCall, "wrong call")
				if entities then
					entities.activate(built, "clerk")
				end
			end
		end
		local left = deadline - now()
		for _, mark in Tuning.Stop.BellsAt do
			if left <= mark and not bellsRung[mark] then
				bellsRung[mark] = true
				Net.notifyAll("Sound", { key = "DepartureBell" })
				Driver.say(string.format(PA.departingSoon, mark))
			end
		end
		return departByCord or now() >= deadline
	end)
	cordConn:Disconnect()
	if not alive(token) then
		return
	end
	-- Hold: after the timer, the Hold button keeps the doors open.
	if not departByCord and RunDirector.mode ~= "Graveyard" then
		Cabin.holdEnabled = true
		waitFor(120, token, false, function()
			return not Cabin.isHeld() or departByCord
		end)
		Cabin.holdEnabled = false
	end
	-- Stalled: no fuel, no departure. The Latecomer still comes.
	if Cabin.fuel() <= 0 then
		RunState:SetAttribute("Phase", "Stalled")
		Driver.say(PA.stalled)
		Net.notifyAll("Hint", { id = "stalled" })
		waitFor(600, token, false, function()
			return Cabin.fuel() > 0 or PlayerState.allLost()
		end)
		if not alive(token) then
			return
		end
		task.wait(2)
	end
	-- Close the doors and go.
	RunState:SetAttribute("Phase", "Departing")
	Cabin.cordEnabled = false
	Cabin.holdEnabled = false
	Bus.setDoors(false)
	if latecomer then
		latecomer.doorsClosed()
	end
	task.wait(Tuning.Bus.DoorOpenTime + 0.3)
	-- Anyone still outside is left behind (Downed and outside: Lost).
	local between = find("BetweenService")
	for _, player in RunDirector.runPlayers() do
		local s = PlayerState.state(player)
		if s == "Outside" or (s == "Downed" and not Bus.isAboard(player)) then
			PlayerState.leaveBehind(player)
			if PlayerState.state(player) == "LeftBehind" and between then
				between.send(player, built)
			end
		end
	end
	-- Loop check: the right call is staying aboard and pulling the cord.
	if loopCheck and anomalies then
		local anomalous = anomalies.loopAnomalous(built)
		if anomalous and not gotOff and departByCord then
			Driver.radio(PA.goodCall)
			table.insert(Cabin.bin, "fragment")
			Net.notifyAll("Toast", { text = "Something was left in the Lost & Found." })
		end
		Log.info("Run", "Loop check", built.loopCheck, "anomalous", anomalous, "got off", gotOff)
	end
	Driver.endStop()
	RunDirector.stopsSurvived += 1
	RunDirector.StopClosed:Fire(built)
	Stops.deactivate(built)
	if entities then
		entities.clearStop(built)
	end
	if Bus.mode ~= "Physics" then
		for _, player in Players:GetPlayers() do
			if Bus.isAboard(player) then
				Net.notify(player, "Fade", { seconds = 0.6 })
			else
				Net.notify(player, "BusLeaving", { cf = Bus.busCFrame() })
			end
		end
		task.wait(0.6)
	end
end

-- Ending ----------------------------------------------------------------------------------

function RunDirector.endRun(ending: string)
	if not RunDirector.running then
		return
	end
	RunDirector.running = false
	RunDirector.token += 1
	local lost = 0
	for _, player in RunDirector.runPlayers() do
		if PlayerState.state(player) == "Static" then
			lost += 1
		end
	end
	local summary = {
		ending = ending,
		stops = RunDirector.stopsSurvived,
		fragments = RunState:GetAttribute("Fragments") or 0,
		lost = lost,
		seed = RunDirector.seed,
		mode = RunDirector.mode,
	}
	RunState:SetAttribute("Phase", "Ending")
	Log.info("Run", "Ended:", ending, "after", RunDirector.stopsSurvived, "stops")
	for _, player in RunDirector.runPlayers() do
		Net.notify(player, "RunEnded", summary)
	end
	RunDirector.RunEnded:Fire(ending, summary)
	local players = RunDirector.runPlayers()
	task.delay(Tuning.Run.EndScreenSeconds, function()
		if RunDirector.running then
			return
		end
		local latecomer = find("LatecomerService")
		if latecomer then
			latecomer.reset()
		end
		local entities = find("EntityService")
		if entities then
			entities.clearAll()
		end
		local between = find("BetweenService")
		if between then
			between.clearAll()
		end
		table.clear(RunDirector.players)
		local lobby = find("LobbyService")
		if lobby then
			lobby.returnPlayers(players)
		else
			for _, player in players do
				PlayerState.toLobby(player)
			end
		end
		RunState:SetAttribute("Phase", "Idle")
	end)
end

local function finale(built: any, token: number)
	-- The M1 stub Terminal: the bus pulls in, the doors open, the Driver's seat is empty.
	RunState:SetAttribute("Phase", "Finale")
	Driver.say(PA.terminal)
	Bus.setDoors(true)
	waitFor(6, token, true)
	if not alive(token) then
		return
	end
	local fragments = (RunState:GetAttribute("Fragments") :: number?) or 0
	local lost = 0
	for _, player in RunDirector.runPlayers() do
		if PlayerState.state(player) == "Static" then
			lost += 1
		end
	end
	local ending: string
	if fragments < Route.fragmentsNeeded() then
		ending = "LastStop"
	elseif lost > 0 then
		ending = "Transfer"
	else
		ending = "Home"
	end
	if RunDirector.mode == "Tutorial" then
		ending = "Tutorial"
		Driver.say(PA.tutorialEnd)
	end
	RunDirector.stopsSurvived += 1
	RunDirector.endRun(ending)
	local _ = built
end

-- The loop ----------------------------------------------------------------------------------

local function loop(token: number)
	local index = 0
	while alive(token) do
		index += 1
		local built = ride(index, token, index == 1)
		if not alive(token) then
			return
		end
		if not built then
			-- Past the end of the plan.
			finale(nil, token)
			return
		end
		if built.terminal then
			finale(built, token)
			return
		end
		runStop(built, token)
		if not alive(token) then
			return
		end
		if PlayerState.allLost() then
			RunDirector.endRun("LastStop")
			return
		end
		-- The run's end rule for overtime: three laps, or the fuel or Patience is gone.
		local lap = (RunState:GetAttribute("Overtime") :: number?) or 0
		if lap > Tuning.Run.MaxOvertimeLaps then
			RunDirector.endRun("LastStop")
			return
		end
	end
end

function RunDirector.startRun(players: { Player }, opts: { seed: number?, mode: string?, party: boolean? }?)
	local o: { seed: number?, mode: string?, party: boolean? } = opts or {}
	RunDirector.token += 1
	local token = RunDirector.token
	RunDirector.running = true
	RunDirector.seed = o.seed or Seed.fresh()
	RunDirector.mode = o.mode or "Standard"
	RunDirector.party = o.party == true
	RunDirector.stopIndex = 0
	RunDirector.stopsSurvived = 0
	RunDirector.skipRequested = false
	table.clear(RunDirector.players)
	for _, player in players do
		RunDirector.players[player] = true
	end
	RunState:SetAttribute("Seed", RunDirector.seed)
	RunState:SetAttribute("Mode", RunDirector.mode)
	RunState:SetAttribute("Tier", 1)
	RunState:SetAttribute("StopIndex", 0)
	RunState:SetAttribute("Overtime", 0)
	RunState:SetAttribute("Clock", Tuning.Run.StartClockText)
	Stops.clearAll()
	for _, name in { "EntityService", "BetweenService", "LatecomerService" } do
		local service = find(name)
		if service then
			if service.clearAll then
				service.clearAll()
			elseif service.reset then
				service.reset()
			end
		end
	end
	Route.build(RunDirector.seed, RunDirector.mode)
	Driver.resetForRun()
	Cabin.resetForRun()
	if Tuning.Bus.Mode == "Physics" then
		Chunks.reset(RunDirector.seed, CFrame.new(0, 0, 0))
		Chunks.appendLeadIn(240)
	end
	Bus.spawn(60)
	if Tuning.Bus.Mode == "Physics" then
		Chunks.ensureAhead(60)
	end
	Bus.setLights(true)
	Rules.post(RunDirector.seed, 1)
	for _, player in players do
		PlayerState.beginRun(player)
		Inventory.startKit(player)
		if player.Character then
			RunDirector.placeInBus(player.Character)
		end
	end
	Net.notifyList(players, "RunStarted", { seed = RunDirector.seed, mode = RunDirector.mode })
	task.delay(4, function()
		if alive(token) then
			Driver.radio(PA.confirmCount)
			Net.notifyList(players, "Hint", { id = "read_rules" })
		end
	end)
	RunDirector.RunStarted:Fire(players)
	Log.info("Run", "Started, seed", RunDirector.seed, "mode", RunDirector.mode, "players", #players)
	task.spawn(loop, token)
end

function RunDirector.requestSkip()
	RunDirector.skipRequested = true
end

function RunDirector.restartWithSeed(seed: number)
	local players = RunDirector.runPlayers()
	if #players == 0 then
		players = Players:GetPlayers()
	end
	RunDirector.running = false
	RunDirector.startRun(players, { seed = seed, mode = RunDirector.mode, party = RunDirector.party })
end

function RunDirector:Init()
	Bus = Registry.get("BusService")
	Chunks = Registry.get("ChunkService")
	Stops = Registry.get("StopService")
	Route = Registry.get("RouteService")
	Driver = Registry.get("DriverService")
	Cabin = Registry.get("CabinService")
	Rules = Registry.get("RulesService")
	PlayerState = Registry.get("PlayerStateService")
	Inventory = Registry.get("InventoryService")
	RunState = Registry.get("WorldService").RunState
	RunState:SetAttribute("Phase", "Idle")
end

function RunDirector:Start()
	-- Keep the road ahead of the bus, clean up behind it, and darken tunnels.
	local inTunnel = false
	Bus.Stepped:Connect(function()
		if Bus.mode == "Physics" and RunDirector.running then
			Chunks.ensureAhead(Bus.s)
			local tunnel = Chunks.inTunnel(Bus.s)
			if tunnel ~= inTunnel then
				inTunnel = tunnel
				Bus.setLights(not tunnel)
				RunState:SetAttribute("Blackout", tunnel)
			end
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
	local function onCharacter(player: Player, character: Model)
		if not RunDirector.running or not RunDirector.players[player] then
			return
		end
		task.wait(0.2)
		if PlayerState.state(player) == "Static" then
			PlayerState.setState(player, "Outside")
			PlayerState.lose(player, "respawn")
			return
		end
		RunDirector.placeInBus(character)
		PlayerState.restore(player)
	end
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacter(player, character)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		RunDirector.players[player] = nil
		if RunDirector.running then
			task.defer(function()
				if #RunDirector.runPlayers() == 0 then
					RunDirector.endRun("Abandoned")
				elseif PlayerState.allLost() then
					RunDirector.endRun("LastStop")
				end
			end)
		end
	end)
	-- Everyone Lost at once ends the run, even mid-stop.
	PlayerState.Lost:Connect(function()
		task.defer(function()
			if RunDirector.running and PlayerState.allLost() then
				RunDirector.endRun("LastStop")
			end
		end)
	end)
	-- With neither a lobby nor matchmaking, start as soon as someone is here.
	if Place.hasRun() and not find("LobbyService") and not find("MatchmakingService") then
		task.spawn(function()
			while #Players:GetPlayers() == 0 do
				task.wait(0.5)
			end
			task.wait(Tuning.Run.SoloMinStartDelay)
			RunDirector.startRun(Players:GetPlayers(), {})
		end)
	end
	local debug = find("DebugService")
	if debug then
		debug.register("fuel", function()
			Cabin.setFuel(Tuning.Bus.TankBars)
		end)
		debug.register("fragment", function()
			RunState:SetAttribute("Fragments", ((RunState:GetAttribute("Fragments") :: number?) or 0) + 1)
		end)
		debug.register("start", function(player: Player)
			if not RunDirector.running then
				RunDirector.startRun({ player }, {})
			end
		end)
		debug.register("end", function()
			RunDirector.endRun("Debug")
		end)
	end
end

return RunDirector
