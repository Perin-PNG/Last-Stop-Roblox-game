--!strict
-- First Ride: the solo tutorial (plan, "First Ride"). RunDirector plays Config.Stops
-- TutorialPlan (Gas & Go, the Laundromat, Gas & Go again with the clerk facing the wall);
-- this service offers it, starts it, and walks the rider through it with one objective
-- at a time on RunState.Objective. Every step logs an onboarding funnel step.
--
-- It also keeps one-time hints: the client reports a hint it showed, the server saves it
-- with the player's data and sends the list back on join, so a hint shows once per player.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Build = require(Shared.Util.Build)
local Net = require(Shared.Net)
local Place = require(Shared.Place)
local Log = require(Shared.Log)

local Registry = require(script.Parent.Parent:WaitForChild("Registry"))

local TutorialService = {}

local Data: any
local Director: any
local PlayerState: any
local Bus: any
local Cabin: any
local Inventory: any
local Analytics: any
local RunState: Folder

local token = 0
local conns: { RBXScriptConnection } = {}

local function setObjective(text: string?)
	RunState:SetAttribute("Objective", text)
end

local function funnel(player: Player, step: string)
	if Analytics then
		Analytics.funnel(player, step)
	end
end

local function clear()
	token += 1
	for _, c in conns do
		c:Disconnect()
	end
	table.clear(conns)
	setObjective(nil)
end

-- Start a First Ride for `player` (from the lobby).
function TutorialService.start(player: Player): boolean
	if PlayerState.state(player) ~= "Lobby" or Director.inRun(player) then
		return false
	end
	local matchmaking = Registry.find("MatchmakingService")
	if Place.role() == "Lobby" and matchmaking then
		matchmaking.send({ player }, { mode = "Tutorial" })
		return true
	end
	if Director.running then
		Net.notify(player, "Toast", { text = "The bus is out on the route. Try again when it's back." })
		return false
	end
	Net.notify(player, "Fade", { seconds = 1 })
	task.wait(0.4)
	Director.startRun({ player }, { mode = "Tutorial", party = false })
	return true
end

-- The script ------------------------------------------------------------------------------

local function waitUntil(mine: number, check: () -> boolean, timeout: number): boolean
	local ends = os.clock() + timeout
	while mine == token and os.clock() < ends do
		if check() then
			return true
		end
		task.wait(0.25)
	end
	return mine == token and check()
end

local function rider(): Player?
	local list = Director.runPlayers()
	return list[1]
end

local function looking(player: Player, part: BasePart, seconds: number, mine: number): boolean
	local Gaze = Registry.find("GazeService")
	if not Gaze then
		return true
	end
	local held = 0
	local last = os.clock()
	return waitUntil(mine, function()
		local t = os.clock()
		if Gaze.isLookingAt(player, part.Position, 28, 16) then
			held += t - last
		else
			held = math.max(0, held - (t - last))
		end
		last = t
		return held >= seconds
	end, 45)
end

local function onRideStart(players: { Player })
	clear()
	if Director.mode ~= "Tutorial" then
		return
	end
	local mine = token
	for _, player in players do
		funnel(player, "Started")
	end
	task.spawn(function()
		task.wait(3)
		local player = rider()
		if not player or mine ~= token then
			return
		end
		-- 1. Read the Rules.
		setObjective("Read the glowing Rules plaque by the front door.")
		local plaque: BasePart? = Bus.refs and Bus.refs.rulesPlaque
		local glow: PointLight? = nil
		if plaque then
			glow = Build.light(plaque, "Point", Color3.fromRGB(255, 230, 160), 2, 10, false) :: any
			looking(player, plaque, 2.5, mine)
		end
		if glow then
			glow:Destroy()
		end
		if mine ~= token then
			return
		end
		funnel(player, "ReadRules")
		-- 2. Meet the Driver: the face starts to turn as you look.
		setObjective("Take a seat. The Driver is in the mirror above the windshield.")
		local mirror: BasePart? = Bus.refs and Bus.refs.mirror
		if mirror then
			looking(player, mirror, 1, mine)
		end
		if mine ~= token then
			return
		end
		Net.notify(player, "MirrorTurn", {})
		Net.notify(player, "Hint", { id = "dont_watch" })
		setObjective("Don't watch the Driver. Look away and ride to the first stop.")
		funnel(player, "MetTheDriver")
	end)
end

local function onStopOpened(built: any)
	if Director.mode ~= "Tutorial" then
		return
	end
	local mine = token
	local player = rider()
	if not player then
		return
	end
	task.spawn(function()
		if built.id == "gas_and_go" and not built.loopCheck then
			funnel(player, "GasAndGo")
			-- 3. Gas & Go: battery, fuel, pour, back aboard.
			setObjective("Get off. Grab a battery and a fuel can from the shelves.")
			waitUntil(mine, function()
				return Inventory.has(player, "fuel")
			end, 90)
			setObjective("Pour the fuel at the cap on the bus's rear left corner.")
			Net.notify(player, "Hint", { id = "fuel" })
			local poured = false
			local c = Cabin.Poured:Connect(function(who: Player)
				if who == player then
					poured = true
				end
			end)
			table.insert(conns, c)
			waitUntil(mine, function()
				return poured
			end, 90)
			c:Disconnect()
			if poured then
				funnel(player, "PouredFuel")
			end
			setObjective("Get back aboard before the bell. The bus won't wait.")
		elseif built.id == "laundromat" then
			funnel(player, "Laundromat")
			-- 4. The Laundromat: the first Latecomer.
			setObjective("Look around. When the streetlights go out, get aboard and pull the cord twice.")
			Net.notify(player, "Hint", { id = "cord" })
		elseif built.id == "gas_and_go" and built.loopCheck then
			funnel(player, "LoopCheck")
			-- 5. Gas & Go again, with one change.
			setObjective(
				"Gas & Go again. Look through the window. Something changed: stay aboard and pull the cord twice."
			)
			Net.notify(player, "Hint", { id = "loop_check" })
		end
	end)
end

local function onRunEnded(ending: string)
	local players = Director.runPlayers()
	clear()
	if ending ~= "Tutorial" then
		return
	end
	for _, player in players do
		funnel(player, "Finished")
		Data.update(player, function(d: any)
			d.tutorialDone = true
		end)
		Net.notify(player, "Toast", { text = "First Ride complete. Board the 9N for real when you're ready." })
	end
end

-- The lobby stop -------------------------------------------------------------------------

local function buildSign()
	local World = Registry.get("WorldService")
	local model = Build.model(World.Folders.Lobby, "FirstRide")
	local at = CFrame.new(Config.Tuning.Lobby.Origin) * CFrame.new(4, 0, 34) * CFrame.Angles(0, math.rad(-90), 0)
	Build.part(model, {
		name = "Pole",
		size = Vector3.new(0.5, 9, 0.5),
		cf = at * CFrame.new(0, 4.5, 0),
		color = Color3.fromRGB(70, 72, 76),
		material = Enum.Material.Metal,
		group = "World",
	})
	local plate, label = Build.sign(model, {
		name = "Sign",
		size = Vector3.new(5, 3.4, 0.3),
		cf = at * CFrame.new(0, 7.6, -0.4),
		color = Color3.fromRGB(30, 110, 60),
		group = "World",
	}, "FIRST RIDE\nSolo, about 6 min\nLearn the Rules", Enum.NormalId.Front, Color3.fromRGB(240, 240, 230))
	label.Font = Enum.Font.GothamBold
	local post = Build.part(model, {
		name = "Button",
		size = Vector3.new(1.4, 1.4, 0.4),
		cf = at * CFrame.new(0, 4, -0.45),
		color = Color3.fromRGB(80, 200, 110),
		material = Enum.Material.Neon,
		group = "World",
	})
	local prompt = Build.prompt(post, "Ride", "First Ride", 0.5, 8, "FirstRidePrompt")
	prompt.Triggered:Connect(function(player: Player)
		TutorialService.start(player)
	end)
	local _ = plate
end

-- Lifecycle -------------------------------------------------------------------------------

local function onLoaded(player: Player, d: any)
	local seen = {}
	if type(d.hints) == "table" then
		for id, v in d.hints do
			if v == true then
				table.insert(seen, id)
			end
		end
	end
	Net.notify(player, "HintsSeen", { ids = seen })
	if not d.tutorialDone and Place.role() ~= "Route" then
		funnel(player, "Offered")
		Net.notify(player, "OfferFirstRide", {})
	end
end

function TutorialService:Init()
	Data = Registry.get("DataService")
	Director = Registry.get("RunDirector")
	PlayerState = Registry.get("PlayerStateService")
	Bus = Registry.get("BusService")
	Cabin = Registry.get("CabinService")
	Inventory = Registry.get("InventoryService")
	Analytics = Registry.find("AnalyticsHooks")
	RunState = Registry.get("WorldService").RunState
end

function TutorialService:Start()
	if Place.role() ~= "Route" then
		buildSign()
	end
	Director.RunStarted:Connect(onRideStart)
	Director.StopOpened:Connect(onStopOpened)
	Director.RunEnded:Connect(onRunEnded)
	Data.Loaded:Connect(onLoaded)
	for _, player in Players:GetPlayers() do
		local d = Data.get(player)
		if d then
			onLoaded(player, d)
		end
	end
	Net.on("Tutorial", function(player: Player, action: any, arg: any)
		if action == "start" then
			TutorialService.start(player)
		elseif action == "hint" and type(arg) == "string" and (Config.Text.Hints :: any)[arg] then
			Data.update(player, function(d: any)
				if type(d.hints) ~= "table" then
					d.hints = {}
				end
				d.hints[arg] = true
			end)
		elseif action == "decline" then
			Log.info("Tutorial", player.Name, "declined the First Ride")
		end
	end)
end

return TutorialService
