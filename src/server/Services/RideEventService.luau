--!strict
-- Ride events and the bus Rules. Each ride after the first may roll one event:
--   Blackout    the lights die for 12 seconds (a forced Tunnel in Physics mode). Mimics act.
--   Inspection  a Fare Inspector walks the aisle. Anyone without a ticket is put off at the
--               next stop, unless a teammate hands theirs over first.
--   Knocking    something knocks on the rear window. The test is whether anyone looks.
-- It also enforces the posted Rules that are about the bus: stay seated in the dark, don't
-- look back at knocking, don't sit in the back row, keep your ticket, and never ride with
-- someone who has none. Fake Rules are never enforced (following them is the trap).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Log = require(Shared.Log)
local Seed = require(Shared.Util.Seed)
local Signal = require(Shared.Util.Signal)
local Build = require(Shared.Util.Build)

local Server = script.Parent.Parent
local Registry = require(Server:WaitForChild("Registry"))
local PassengerRig = require(Server:WaitForChild("Builders"):WaitForChild("PassengerRig"))

local Tuning = Config.Tuning.Ride
local PA = Config.Text.PA

local RideEventService = {}

RideEventService.EventStarted = Signal.new() :: Signal.Signal<string> -- (kind)

local Bus: any
local Driver: any
local Rules: any
local PlayerState: any
local Inventory: any
local Gaze: any
local Run: any
local Dread: any
local RunState: Folder

local rng = Seed.new(1)
local token = 0 -- bumps each ride, so a late event from an old ride never starts
local knocking = false
local knockLooked: { [Player]: number } = {}
local knockBroke: { [Player]: boolean } = {}
local blackoutBroke: { [Player]: boolean } = {}
local blackoutSince = 0
local backRow: { [Player]: number } = {}
local backRowBroke: { [Player]: boolean } = {}
local flagged: { [Player]: boolean } = {} -- no ticket at the inspection
local inspector: Model? = nil
local ticketPrompts: { [Player]: ProximityPrompt } = {}

local function aboard(): { Player }
	local out = {}
	for _, player in Players:GetPlayers() do
		if PlayerState.isHealthy(player) and Bus.isAboard(player) then
			table.insert(out, player)
		end
	end
	return out
end

local function phase(): string
	return (RunState:GetAttribute("Phase") :: string?) or "Idle"
end

local function riding(): boolean
	local ph = phase()
	return ph == "Ride" or ph == "Arriving" or ph == "Departing"
end

local function posted(id: string): boolean
	return Rules ~= nil and Rules.has(id)
end

local function seated(player: Player): boolean
	local hum = PlayerState.humanoidOf(player)
	return hum ~= nil and hum.Sit
end

-- Blackout -----------------------------------------------------------------------------

local function stationaryBlackout(my: number)
	if my ~= token or not riding() then
		return
	end
	RideEventService.EventStarted:Fire("blackout")
	Net.notifyAll("Sound", { key = "LightPop" })
	Bus.setLights(false)
	RunState:SetAttribute("Blackout", true)
	task.delay(Tuning.BlackoutSeconds, function()
		if RunState:GetAttribute("Blackout") == true then
			RunState:SetAttribute("Blackout", false)
			if Run.running then
				Bus.setLights(true)
			end
		end
	end)
end

local function startBlackout(my: number)
	if Bus.mode == "Physics" then
		-- The ride goes through a Tunnel; RunDirector darkens the cabin inside it.
		RideEventService.EventStarted:Fire("blackout")
		Driver.forceTunnel = true
	else
		task.delay(rng:float(8, 18), stationaryBlackout, my)
	end
end

-- Knocking -----------------------------------------------------------------------------

local function knockFace(window: BasePart): Model
	-- A pale face pressed to the outside of the rear window, riding along with the bus.
	local m = Build.model(window.Parent, "KnockFace")
	local out = window.CFrame * CFrame.new(0, -0.4, 0)
	local normal = window.CFrame.LookVector
	-- Put it on whichever side of the glass is farther from the bus's middle.
	local root: BasePart = Bus.refs.root
	if (window.Position + normal - root.Position).Magnitude < (window.Position - normal - root.Position).Magnitude then
		normal = -normal
	end
	local at = out.Position + normal * 0.5
	local faceCf = CFrame.lookAt(at, at - normal)
	local head = Build.part(m, {
		name = "Head",
		size = Vector3.new(1.4, 1.8, 0.6),
		cf = faceCf,
		color = Color3.fromRGB(205, 200, 190),
		collide = false,
		query = false,
	})
	for _, side in { -0.3, 0.3 } do
		Build.part(m, {
			name = "Eye",
			size = Vector3.new(0.28, 0.2, 0.05),
			cf = faceCf * CFrame.new(side, 0.2, -0.31),
			color = Color3.fromRGB(8, 8, 8),
			collide = false,
			query = false,
		})
	end
	for _, side in { -1.2, 1.2 } do
		Build.part(m, {
			name = "Hand",
			size = Vector3.new(0.8, 1, 0.2),
			cf = faceCf * CFrame.new(side, 0.6, -0.2),
			color = Color3.fromRGB(205, 200, 190),
			collide = false,
			query = false,
		})
	end
	m.PrimaryPart = head
	PassengerRig.attach(m, window)
	return m
end

local function startKnocking(my: number)
	task.delay(rng:float(8, 20), function()
		if my ~= token or not riding() or knocking then
			return
		end
		local refs = Bus.refs
		local window: BasePart? = refs and refs.rearWindow
		if not window then
			return
		end
		RideEventService.EventStarted:Fire("knocking")
		knocking = true
		table.clear(knockLooked)
		table.clear(knockBroke)
		local face = knockFace(window)
		local started = os.clock()
		while os.clock() - started < Tuning.KnockSeconds and Run.running and window.Parent do
			Net.notifyAll("Sound", { key = if rng:chance(0.2) then "GlassSlap" else "Knock", part = window })
			task.wait(rng:float(1.2, 2))
		end
		knocking = false
		face:Destroy()
	end)
end

-- Inspection ---------------------------------------------------------------------------

local function aisleEnds(): (CFrame?, CFrame?)
	local refs = Bus.refs
	if not refs then
		return nil, nil
	end
	local interior: BasePart = refs.interior
	local cf = interior.CFrame
	local driverZ = cf:PointToObjectSpace(refs.driverSeat.Position).Z
	local front = if driverZ < 0 then -1 else 1
	local floorY = -interior.Size.Y / 2
	local half = interior.Size.Z / 2 - 4
	-- Face from front to back (rigs face -Z of their CFrame).
	local a = cf * CFrame.new(0, floorY, front * (half - 2))
	local b = cf * CFrame.new(0, floorY, -front * half)
	local look = (b.Position - a.Position).Unit
	return CFrame.lookAt(a.Position, a.Position + look), CFrame.lookAt(b.Position, b.Position + look)
end

local function checkTicket(player: Player)
	if Inventory.has(player, "ticket") then
		return
	end
	if flagged[player] then
		return
	end
	flagged[player] = true
	Net.notify(
		player,
		"Toast",
		{ text = "No ticket. You'll be put off at the next stop unless someone gives you one." }
	)
	Net.notifyAll("Toast", { text = `{player.DisplayName} has no ticket.` })
	if posted("ticket") then
		Driver.ruleBroken(player, "ticket")
	end
end

local function startInspection(my: number)
	task.delay(rng:float(6, 14), function()
		if my ~= token or not riding() or inspector then
			return
		end
		local refs = Bus.refs
		local a, b = aisleEnds()
		if not refs or not a or not b then
			return
		end
		RideEventService.EventStarted:Fire("inspection")
		Driver.say(PA.inspection)
		local m = PassengerRig.standing(refs.model, "FareInspector", a, {
			skin = Color3.fromRGB(190, 170, 150),
			shirt = Color3.fromRGB(46, 50, 62),
			pants = Color3.fromRGB(30, 32, 40),
			hat = Color3.fromRGB(46, 50, 62),
			prop = "badge",
		})
		inspector = m
		local root = m.PrimaryPart :: BasePart
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.Massless = true
				if d ~= root then
					Build.weld(root, d)
				end
			end
		end
		-- A Weld (not a WeldConstraint) to the bus, so it can walk by moving C0.
		local busRoot: BasePart = refs.root
		local weld = Instance.new("Weld")
		weld.Part0 = busRoot
		weld.Part1 = root
		local startRel = busRoot.CFrame:ToObjectSpace(root.CFrame)
		local endRel = busRoot.CFrame:ToObjectSpace(b * a:ToObjectSpace(root.CFrame))
		weld.C0 = startRel
		weld.Parent = root
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = false
			end
		end
		local checked: { [Player]: boolean } = {}
		local started = os.clock()
		while os.clock() - started < Tuning.InspectionWalkSeconds and m.Parent do
			local t = (os.clock() - started) / Tuning.InspectionWalkSeconds
			weld.C0 = startRel:Lerp(endRel, t)
			for _, player in aboard() do
				local r = PlayerState.rootOf(player)
				if r and not checked[player] and (r.Position - root.Position).Magnitude < 7 then
					checked[player] = true
					checkTicket(player)
				end
			end
			task.wait(0.1)
		end
		-- Anyone it didn't pass close to still gets checked.
		for _, player in aboard() do
			if not checked[player] then
				checkTicket(player)
			end
		end
		Log.info("RideEvents", "inspection done")
	end)
end

-- At the next stop, the Inspector puts ticketless riders off and gets off itself.
local function onStopOpened(built: any)
	if inspector then
		inspector:Destroy()
		inspector = nil
	end
	for player in table.clone(flagged) do
		flagged[player] = nil
		if player.Parent and Bus.isAboard(player) and not Inventory.has(player, "ticket") and built and built.refs then
			local root = PlayerState.rootOf(player)
			local spot: BasePart = built.refs.passengerSpot
			if root then
				root.CFrame = CFrame.new(spot.Position + Vector3.new(0, 1, 0))
				Net.notify(
					player,
					"Toast",
					{ text = "The Inspector put you off the bus. Find a ticket, or ask for one." }
				)
				Log.info("RideEvents", player.Name, "was put off for no ticket")
			end
		end
	end
end

-- Handing a ticket over: a prompt on any rider who has none.
local refreshTicketPrompt: (player: Player) -> ()
refreshTicketPrompt = function(player: Player)
	local has = player:GetAttribute("Ticket") == true
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local existing = ticketPrompts[player]
	if has or not root or not Run.running then
		if existing then
			existing:Destroy()
			ticketPrompts[player] = nil
		end
		return
	end
	if existing and existing.Parent == root then
		return
	end
	if existing then
		existing:Destroy()
	end
	local prompt = Build.prompt(root, "Give your ticket", player.DisplayName, 1, 7, "GiveTicket")
	prompt.KeyboardKeyCode = Enum.KeyCode.G
	prompt.Triggered:Connect(function(giver: Player)
		if giver == player or not PlayerState.isHealthy(giver) or not PlayerState.isHealthy(player) then
			return
		end
		if not Inventory.has(giver, "ticket") or Inventory.has(player, "ticket") then
			return
		end
		if Inventory.take(giver, "ticket") and Inventory.give(player, "ticket") then
			Net.notifyAll("Toast", { text = `{giver.DisplayName} gave {player.DisplayName} their ticket.` })
			flagged[player] = nil
			refreshTicketPrompt(player)
		end
	end)
	ticketPrompts[player] = prompt
end

-- Rules on the bus -----------------------------------------------------------------------

local function rulesTick(dt: number)
	local riders = aboard()
	-- If the lights go out, stay seated.
	if RunState:GetAttribute("Blackout") == true and posted("lights_seated") then
		if os.clock() - blackoutSince > 1.5 then
			for _, player in riders do
				if not seated(player) and not blackoutBroke[player] then
					blackoutBroke[player] = true
					Driver.ruleBroken(player, "lights_seated")
				end
			end
		end
	end
	-- If you hear knocking on the rear window, do not look back.
	if knocking then
		local window: BasePart? = Bus.refs and Bus.refs.rearWindow
		for _, player in riders do
			if window and Gaze.isLookingAt(player, window.Position, 22, 90) then
				knockLooked[player] = (knockLooked[player] or 0) + dt
				if knockLooked[player] > 0.6 and not knockBroke[player] then
					knockBroke[player] = true
					if Dread then
						Dread.add(player, 12)
					end
					if posted("knock_no_look") then
						Driver.ruleBroken(player, "knock_no_look")
					end
				end
			end
		end
	end
	-- Do not sit in the back row after midnight (the run starts at 1:58 AM).
	if posted("no_back_row") and Bus.refs then
		for _, seat in Bus.refs.backRowSeats :: { Seat } do
			local hum = seat.Occupant
			local player = hum and Players:GetPlayerFromCharacter(hum.Parent)
			if player then
				backRow[player] = (backRow[player] or 0) + dt
				if backRow[player] > 2 and not backRowBroke[player] then
					backRowBroke[player] = true
					Driver.ruleBroken(player, "no_back_row")
				end
			end
		end
		for player in table.clone(backRow) do
			local hum = PlayerState.humanoidOf(player)
			local seat = hum and hum.SeatPart
			if not seat or not table.find(Bus.refs.backRowSeats, seat) then
				backRow[player] = nil
			end
		end
	end
end

-- Never board with someone who has no ticket: checked when the doors close.
local function onStopClosed()
	if not posted("no_ticketless") then
		return
	end
	for _, player in aboard() do
		if not Inventory.has(player, "ticket") then
			Driver.ruleBroken(player, "no_ticketless")
		end
	end
end

local function onRideStarted(index: number)
	token += 1
	table.clear(backRowBroke)
	if index <= 1 then
		return
	end
	local tier = math.clamp((RunState:GetAttribute("Tier") :: number?) or 1, 1, 3)
	if not rng:chance(Tuning.EventChance[tier]) then
		return
	end
	local kind = rng:pick({ "blackout", "inspection", "knocking" })
	Log.info("RideEvents", "ride", index, "rolls", kind)
	if kind == "blackout" then
		startBlackout(token)
	elseif kind == "inspection" then
		startInspection(token)
	else
		startKnocking(token)
	end
end

function RideEventService:Init()
	Bus = Registry.get("BusService")
	Driver = Registry.get("DriverService")
	Rules = Registry.find("RulesService")
	PlayerState = Registry.get("PlayerStateService")
	Inventory = Registry.get("InventoryService")
	Gaze = Registry.get("GazeService")
	Run = Registry.get("RunDirector")
	Dread = Registry.find("DreadService")
	RunState = Registry.get("WorldService").RunState
end

function RideEventService:Start()
	Run.RunStarted:Connect(function()
		rng = Seed.new(Run.seed):child("rideEvents")
		token += 1
		table.clear(flagged)
		table.clear(backRow)
		table.clear(backRowBroke)
		if inspector then
			inspector:Destroy()
			inspector = nil
		end
	end)
	Run.RunEnded:Connect(function()
		token += 1
		knocking = false
		if inspector then
			inspector:Destroy()
			inspector = nil
		end
		for player in ticketPrompts do
			refreshTicketPrompt(player)
		end
	end)
	Run.RideStarted:Connect(onRideStarted)
	Run.StopOpened:Connect(onStopOpened)
	Run.StopClosed:Connect(onStopClosed)
	RunState:GetAttributeChangedSignal("Blackout"):Connect(function()
		if RunState:GetAttribute("Blackout") == true then
			blackoutSince = os.clock()
			table.clear(blackoutBroke)
		end
	end)
	local function watchPlayer(player: Player)
		player:GetAttributeChangedSignal("Ticket"):Connect(function()
			refreshTicketPrompt(player)
		end)
		player.CharacterAdded:Connect(function()
			task.defer(refreshTicketPrompt, player)
		end)
	end
	for _, player in Players:GetPlayers() do
		watchPlayer(player)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(player: Player)
		flagged[player] = nil
		backRow[player] = nil
		knockLooked[player] = nil
		if ticketPrompts[player] then
			ticketPrompts[player]:Destroy()
			ticketPrompts[player] = nil
		end
	end)
	task.spawn(function()
		while true do
			local dt = task.wait(0.25)
			local ok, err = pcall(function()
				rulesTick(dt)
			end)
			if not ok then
				Log.warn("RideEvents", "rules tick failed", err)
			end
		end
	end)
end

return RideEventService
