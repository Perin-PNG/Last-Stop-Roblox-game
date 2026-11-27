--!strict
-- Everything riders touch inside (and on) the bus: the stop-request cord, the Hold
-- button, the fuel tank and its cap, the route-board fragment slots, the Lost & Found
-- bin, and the dashboard, route board and plaque displays.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Signal = require(Shared.Util.Signal)
local Build = require(Shared.Util.Build)
local Net = require(Shared.Net)
local Log = require(Shared.Log)

local Registry = require(script.Parent.Parent:WaitForChild("Registry"))

local BusTuning = Config.Tuning.Bus
local Stops = Config.Stops

local CabinService = {}

CabinService.CordDepart = Signal.new() -- the cord was pulled twice and the doors closed
CabinService.FragmentBanked = Signal.new() -- (player, total)
CabinService.Poured = Signal.new() -- (player, bars)

CabinService.cordEnabled = false
CabinService.holdEnabled = false
CabinService.holding = {} :: { [Player]: boolean }
CabinService.cordArmed = false -- the doors are closing because of the cord
CabinService.bin = {} :: { string } -- items waiting in the Lost & Found (rewards)
CabinService.binUsed = {} :: { [Player]: boolean }

local Bus: any
local Inventory: any
local PlayerState: any
local Driver: any
local RunState: Folder

type Pull = { player: Player, at: number }
local pulls: { Pull } = {}
local lastPull: { [Player]: number } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function rootOf(player: Player): BasePart?
	return PlayerState and PlayerState.rootOf(player)
end

-- Fuel ------------------------------------------------------------------------------------

function CabinService.fuel(): number
	return (RunState:GetAttribute("Fuel") :: number?) or BusTuning.TankBars
end

function CabinService.setFuel(bars: number)
	RunState:SetAttribute("Fuel", math.clamp(bars, 0, BusTuning.TankBars))
end

function CabinService.addFuel(bars: number)
	CabinService.setFuel(CabinService.fuel() + bars)
end

-- Displays --------------------------------------------------------------------------------

local function surface(part: BasePart, face: Enum.NormalId, ppu: number?): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Display"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = ppu or 50
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.Parent = part
	return gui
end

local function label(parent: Instance, name: string, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.Code
	l.TextScaled = true
	l.TextColor3 = Color3.fromRGB(255, 170, 40)
	for k, v in props do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

local ICON_TEXT = { fuel = "FUEL", fragment = "MAP", medical = "MED", shop = "SHOP", unknown = "???" }

local function refreshRouteBoard()
	local refs = Bus.refs
	if not refs then
		return
	end
	local gui = refs.routeBoard:FindFirstChild("Display")
	if not gui then
		return
	end
	local main = gui:FindFirstChild("Main") :: TextLabel?
	local sub = gui:FindFirstChild("Sub") :: TextLabel?
	if not main or not sub then
		return
	end
	local fragments = (RunState:GetAttribute("Fragments") :: number?) or 0
	local need = (RunState:GetAttribute("FragmentsNeeded") :: number?) or Config.Tuning.Run.FragmentsToWin
	if RunState:GetAttribute("VoteOpen") then
		local a = RunState:GetAttribute("VoteA") :: string?
		local b = RunState:GetAttribute("VoteB") :: string?
		local function opt(id: string?, count: any): string
			local def = id and Stops[id]
			if not def then
				return "?"
			end
			local icon = (RunState:GetAttribute("VoteIcon" .. (if id == a then "A" else "B")) :: string?) or def.icon
			return `{def.name} [{ICON_TEXT[icon] or "???"}] {count or 0}`
		end
		main.Text = `◄ {opt(a, RunState:GetAttribute("VoteCountA"))}`
		sub.Text = `{opt(b, RunState:GetAttribute("VoteCountB"))} ►`
	else
		local nextName = (RunState:GetAttribute("NextStopName") :: string?) or "NOT IN SERVICE"
		main.Text = `9N  {string.upper(nextName)}`
		sub.Text = `ROUTE FRAGMENTS {fragments}/{need}`
	end
end

CabinService.refreshRouteBoard = refreshRouteBoard

local function refreshDashboard()
	local refs = Bus.refs
	if not refs then
		return
	end
	local gui = refs.dashboard:FindFirstChild("Display")
	if not gui then
		return
	end
	local fuelLabel = gui:FindFirstChild("Fuel") :: TextLabel?
	local clock = gui:FindFirstChild("Clock") :: TextLabel?
	if fuelLabel then
		local bars = CabinService.fuel()
		fuelLabel.Text = "E " .. string.rep("█", bars) .. string.rep("·", BusTuning.TankBars - bars) .. " F"
		fuelLabel.TextColor3 = if bars <= 1 then Color3.fromRGB(255, 60, 40) else Color3.fromRGB(120, 230, 140)
	end
	if clock then
		clock.Text = (RunState:GetAttribute("Clock") :: string?) or Config.Tuning.Run.StartClockText
	end
end

local function refreshFragmentSlots()
	local refs = Bus.refs
	if not refs then
		return
	end
	local fragments = (RunState:GetAttribute("Fragments") :: number?) or 0
	for i, slot in refs.fragmentSlots do
		slot.Color = if i <= fragments then Color3.fromRGB(255, 236, 180) else Color3.fromRGB(40, 40, 40)
	end
end

function CabinService.refreshPlaque(rules: { string })
	local refs = Bus.refs
	if not refs then
		return
	end
	local old = refs.rulesPlaque:FindFirstChild("Display")
	if old then
		old:Destroy()
	end
	local gui = surface(refs.rulesPlaque, Enum.NormalId.Left, 60)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(235, 230, 210)
	frame.BorderSizePixel = 0
	frame.Parent = gui
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.PaddingTop = UDim.new(0, 8)
	pad.Parent = frame
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = frame
	label(frame, "Title", {
		Size = UDim2.new(1, 0, 0, 30),
		Text = "HCTA RIDER RULES",
		Font = Enum.Font.GothamBlack,
		TextColor3 = Color3.fromRGB(20, 30, 50),
		LayoutOrder = 0,
	})
	for i, id in rules do
		local rule = Config.Rules.ById[id]
		if rule then
			local fake = rule.fake
			local l = label(frame, "Rule" .. i, {
				Size = UDim2.new(1, 0, 0, 34),
				Text = `{i}. {rule.text}`,
				Font = if fake then Enum.Font.PermanentMarker else Enum.Font.Gotham,
				TextColor3 = if fake then Color3.fromRGB(150, 20, 20) else Color3.fromRGB(25, 25, 30),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = true,
				LayoutOrder = i,
			})
			if fake then
				l.BackgroundTransparency = 0.2
				l.BackgroundColor3 = Color3.fromRGB(250, 240, 140)
				l.Rotation = -2
			end
		end
	end
end

local function buildDisplays(refs: any)
	local board = surface(refs.routeBoard, Enum.NormalId.Front, 40)
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(10, 8, 4)
	bg.BorderSizePixel = 0
	bg.ZIndex = 0
	bg.Parent = board
	label(board, "Main", { Size = UDim2.fromScale(1, 0.56), Position = UDim2.fromScale(0, 0.02), Text = "" })
	label(board, "Sub", {
		Size = UDim2.fromScale(1, 0.38),
		Position = UDim2.fromScale(0, 0.6),
		Text = "",
		TextColor3 = Color3.fromRGB(255, 120, 30),
	})
	local dash = surface(refs.dashboard, Enum.NormalId.Back, 40)
	label(dash, "Fuel", { Size = UDim2.fromScale(0.5, 0.6), Position = UDim2.fromScale(0.05, 0.2) })
	label(dash, "Clock", {
		Size = UDim2.fromScale(0.35, 0.6),
		Position = UDim2.fromScale(0.6, 0.2),
		TextColor3 = Color3.fromRGB(120, 220, 255),
	})
	refreshRouteBoard()
	refreshDashboard()
	refreshFragmentSlots()
end

-- Cord ------------------------------------------------------------------------------------

-- In public servers, while anyone is outside during the first half of the timer, the cord
-- needs pulls from two different players.
local function needsTwoPlayers(): boolean
	local runDirector = Registry.find("RunDirector")
	if runDirector and runDirector.isParty and runDirector.isParty() then
		return false
	end
	local living = PlayerState.living()
	if #living < 2 then
		return false
	end
	local deadline = (RunState:GetAttribute("Deadline") :: number?) or 0
	local timer = (RunState:GetAttribute("Timer") :: number?) or 120
	if now() > deadline - timer / 2 then
		return false
	end
	for _, player in living do
		if PlayerState.state(player) == "Outside" then
			return true
		end
	end
	return false
end

local function closeByCord()
	if CabinService.cordArmed then
		return
	end
	CabinService.cordArmed = true
	table.clear(pulls)
	Net.notifyAll("CordClosing", { seconds = BusTuning.CordCloseDelay })
	Driver.say(Config.Text.PA.doorsClosing)
	task.delay(BusTuning.CordCloseDelay, function()
		if CabinService.cordArmed then
			CabinService.CordDepart:Fire()
		end
	end)
end

function CabinService.pullCord(player: Player): boolean
	if not CabinService.cordEnabled or CabinService.cordArmed then
		return false
	end
	if PlayerState.state(player) ~= "Aboard" then
		return false
	end
	local t = os.clock()
	if t - (lastPull[player] or 0) < BusTuning.CordPerPlayerCooldown then
		return false
	end
	lastPull[player] = t
	-- Forget old pulls.
	local keep = {}
	for _, p in pulls do
		if t - p.at <= BusTuning.CordPullWindow then
			table.insert(keep, p)
		end
	end
	pulls = keep
	table.insert(pulls, { player = player, at = t })
	RunState:SetAttribute("CordPulls", #pulls)
	Net.notifyAll("Sound", { key = "CordDing", part = "PASpeaker" })
	local two = needsTwoPlayers()
	local count = #pulls
	if two then
		local distinct: { [Player]: boolean } = {}
		count = 0
		for _, p in pulls do
			if not distinct[p.player] then
				distinct[p.player] = true
				count += 1
			end
		end
		if count < 2 and #pulls >= 2 then
			Net.notify(player, "Toast", { text = "Someone is outside. A second rider has to pull too." })
		end
	end
	if count >= 2 then
		closeByCord()
	end
	return true
end

function CabinService.resetCord()
	CabinService.cordArmed = false
	table.clear(pulls)
	RunState:SetAttribute("CordPulls", 0)
end

-- Hold ------------------------------------------------------------------------------------

function CabinService.isHeld(): boolean
	for player, on in CabinService.holding do
		if on and player.Parent and PlayerState.state(player) == "Aboard" then
			return true
		end
	end
	return false
end

-- Hooks -----------------------------------------------------------------------------------

local function hookBus(refs: any)
	buildDisplays(refs)
	-- Cords: a prompt every other cord section, both window lines.
	for i, cord in refs.cords do
		if i % 2 == 1 then
			local prompt = Build.prompt(cord, "Pull cord", "Stop request", 0, 8, "CordPrompt")
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.Triggered:Connect(function(player: Player)
				local root = rootOf(player)
				if root and (root.Position - cord.Position).Magnitude <= 12 then
					CabinService.pullCord(player)
				end
			end)
		end
	end
	-- Hold button: hold to keep the doors open.
	local hold = Build.prompt(refs.holdButton, "Hold doors", "Hold", 1e6, 6, "HoldPrompt")
	hold.PromptButtonHoldBegan:Connect(function(player: Player)
		if CabinService.holdEnabled and PlayerState.state(player) == "Aboard" then
			CabinService.holding[player] = true
			RunState:SetAttribute("Holding", CabinService.isHeld())
		end
	end)
	hold.PromptButtonHoldEnded:Connect(function(player: Player)
		CabinService.holding[player] = nil
		RunState:SetAttribute("Holding", CabinService.isHeld())
	end)
	-- Fuel cap (outside, rear left corner).
	local pour = Build.prompt(refs.fuelCap, "Pour fuel", "Fuel cap", BusTuning.FuelPourSeconds, 5, "PourPrompt")
	local pourStarted: { [Player]: number } = {}
	pour.PromptButtonHoldBegan:Connect(function(player: Player)
		local root = rootOf(player)
		if root and (root.Position - refs.fuelCap.Position).Magnitude <= BusTuning.FuelCapRange + 2 then
			pourStarted[player] = os.clock()
			Net.notifyAll("Sound", { key = "PourFuel", part = "FuelCap" })
		end
	end)
	pour.PromptButtonHoldEnded:Connect(function(player: Player)
		task.defer(function()
			pourStarted[player] = nil
		end)
	end)
	pour.Triggered:Connect(function(player: Player)
		local started = pourStarted[player]
		pourStarted[player] = nil
		local root = rootOf(player)
		if not started or not root or not PlayerState.isHealthy(player) then
			return
		end
		if os.clock() - started < BusTuning.FuelPourSeconds - 0.3 then
			return
		end
		if (root.Position - refs.fuelCap.Position).Magnitude > BusTuning.FuelCapRange + 2 then
			return
		end
		if Inventory.take(player, "fuel") then
			CabinService.addFuel(BusTuning.FuelPerCan)
			CabinService.Poured:Fire(player, BusTuning.FuelPerCan)
			Net.notify(player, "Toast", { text = `+{BusTuning.FuelPerCan} fuel` })
		elseif Inventory.take(player, "water_can") then
			-- The Lure: it was water.
			CabinService.addFuel(-BusTuning.FuelPerCan)
			Net.notifyAll("Toast", { text = "That wasn't fuel. The engine sputters." })
			CabinService.Poured:Fire(player, -BusTuning.FuelPerCan)
		else
			Net.notify(player, "Toast", { text = "You need a fuel can." })
		end
	end)
	-- Fragment slots: bank fragments on the route board panel.
	local slotPart = refs.fragmentSlots[3]
	local bank = Build.prompt(slotPart, "Bank fragment", "Route board", 0.6, 7, "BankPrompt")
	bank.Triggered:Connect(function(player: Player)
		if PlayerState.state(player) ~= "Aboard" then
			return
		end
		if Inventory.take(player, "fragment") then
			local total = ((RunState:GetAttribute("Fragments") :: number?) or 0) + 1
			RunState:SetAttribute("Fragments", total)
			CabinService.FragmentBanked:Fire(player, total)
			Net.notifyAll("FragmentBanked", { total = total, by = player.UserId })
			Log.info("Cabin", player.Name, "banked a fragment:", total)
		else
			Net.notify(player, "Toast", { text = "Map fragments go here." })
		end
	end)
	-- Lost & Found: one free random item per player per run, plus any reward left in it.
	local binPrompt = Build.prompt(refs.lostAndFound, "Search", "Lost & Found", 0.8, 7, "BinPrompt")
	binPrompt.Triggered:Connect(function(player: Player)
		if PlayerState.state(player) ~= "Aboard" then
			return
		end
		local reward = CabinService.bin[1]
		if reward then
			if Inventory.give(player, reward) then
				table.remove(CabinService.bin, 1)
				Net.notify(player, "Toast", { text = `Found: {Config.Items.Items[reward].name}` })
			else
				Net.notify(player, "Toast", { text = "No room." })
			end
			return
		end
		if CabinService.binUsed[player] then
			Net.notify(player, "Toast", { text = "Nothing else in here for you." })
			return
		end
		local pool = { "battery", "bottle", "flare", "coffee", "transfers" }
		local pick = pool[math.random(1, #pool)]
		if Inventory.give(player, pick, if pick == "transfers" then 2 else nil) then
			CabinService.binUsed[player] = true
			Net.notify(player, "Toast", { text = `Found: {Config.Items.Items[pick].name}` })
		else
			Net.notify(player, "Toast", { text = "No room." })
		end
	end)
	-- Route vote buttons.
	for _, button in refs.voteButtons do
		local option = button:GetAttribute("Option") :: number
		local prompt = Build.prompt(button, "Vote", if option == 1 then "Left option" else "Right option", 0, 7)
		prompt.Triggered:Connect(function(player: Player)
			local route = Registry.find("RouteService")
			if route and PlayerState.state(player) == "Aboard" then
				route.vote(player, option)
			end
		end)
	end
end

function CabinService.resetForRun()
	CabinService.setFuel(BusTuning.TankBars)
	table.clear(CabinService.bin)
	table.clear(CabinService.binUsed)
	table.clear(CabinService.holding)
	CabinService.resetCord()
	RunState:SetAttribute("Fragments", 0)
end

function CabinService:Init()
	Bus = Registry.get("BusService")
	Inventory = Registry.get("InventoryService")
	PlayerState = Registry.get("PlayerStateService")
	Driver = Registry.get("DriverService")
	RunState = Registry.get("WorldService").RunState
	RunState:SetAttribute("Fuel", BusTuning.TankBars)
	RunState:SetAttribute("Fragments", 0)
end

function CabinService:Start()
	Bus.Spawned:Connect(hookBus)
	if Bus.refs then
		hookBus(Bus.refs)
	end
	for _, name in
		{
			"Fragments",
			"VoteOpen",
			"VoteA",
			"VoteB",
			"VoteCountA",
			"VoteCountB",
			"NextStopName",
			"FragmentsNeeded",
		}
	do
		RunState:GetAttributeChangedSignal(name):Connect(refreshRouteBoard)
	end
	RunState:GetAttributeChangedSignal("Fragments"):Connect(refreshFragmentSlots)
	RunState:GetAttributeChangedSignal("Fuel"):Connect(refreshDashboard)
	RunState:GetAttributeChangedSignal("Clock"):Connect(refreshDashboard)
	Players.PlayerRemoving:Connect(function(player)
		CabinService.holding[player] = nil
		lastPull[player] = nil
	end)
	-- Holding costs Patience every second.
	task.spawn(function()
		while true do
			local dt = task.wait(0.25)
			local held = CabinService.holdEnabled and CabinService.isHeld()
			if RunState:GetAttribute("Holding") ~= held then
				RunState:SetAttribute("Holding", held)
			end
			if held then
				Driver.change(-BusTuning.HoldPatiencePerSecond * dt, "hold")
			end
		end
	end)
end

return CabinService
