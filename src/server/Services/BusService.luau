--!strict
-- Unit 9: spawns the bus, drives it along ChunkService.path, pulls in at stops, works the
-- doors and lights, and answers "who is aboard".
--
-- Physics mode (default): the bus is an unanchored, server-owned assembly. Every physics
-- step an AlignPosition and AlignOrientation (OneAttachment mode) pull it to a target
-- CFrame sampled from the path, so riders stand on a floor that really moves.
--
-- Stationary mode (the fallback, Tuning.Bus.Mode = "Stationary"): the bus stays anchored at
-- the ride spot while each client scrolls scenery past the windows. At each stop the bus,
-- and everyone aboard, is moved to the stop's curb behind a short fade.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Signal = require(Shared.Util.Signal)
local Build = require(Shared.Util.Build)
local Net = require(Shared.Net)
local Log = require(Shared.Log)

local Builders = script.Parent.Parent:WaitForChild("Builders")
local BusBuilder = require(Builders:WaitForChild("BusBuilder"))
local Registry = require(script.Parent.Parent:WaitForChild("Registry"))

local Tuning = Config.Tuning.Bus

export type DriveState = "Parked" | "Cruise" | "Approach" | "Docked" | "Stalled"

local BusService = {}

BusService.mode = Tuning.Mode :: string
BusService.refs = (nil :: any) :: BusBuilder.BusRefs
BusService.s = 0
BusService.speed = 0
BusService.maxSpeed = Tuning.CruiseSpeed
BusService.lateral = Tuning.LaneOffset
BusService.state = "Parked" :: DriveState
BusService.stopS = nil :: number?
BusService.departS = nil :: number?
BusService.doorsOpen = false
BusService.lightsOn = true
BusService.Arrived = Signal.new()
BusService.DoorsChanged = Signal.new()
BusService.Stepped = Signal.new()
BusService.Spawned = Signal.new() -- (refs)

-- Pull-in: bus centre distance from the road centre when docked. The curb is at +20, the
-- bus is 12 wide, so this leaves about 1.5 studs between the doors and the curb.
BusService.PullInOffset = 12.5
BusService.PullInDistance = 170 -- studs before the curb the bus starts moving over
BusService.PullOutDistance = 140
BusService.RideSpot = CFrame.new(0, 0, 9000) -- Stationary: road centre frame the bus sits on

local Chunks: any
local World: any
local RunState: Folder
local alignPos: AlignPosition?
local alignOri: AlignOrientation?
local stepConn: RBXScriptConnection?
local seatConns: { RBXScriptConnection } = {}
local doorBase: { [Weld]: CFrame } = {}

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- Bus root CFrame for a road centreline frame and lateral offset.
local function rootCf(road: CFrame, lateral: number): CFrame
	-- The root part is the floor: its top is at local y=0, its centre at y=-0.5.
	return road * CFrame.new(lateral, Tuning.HoverHeight - 0.5, 0)
end

function BusService.busCFrame(): CFrame
	local refs = BusService.refs
	if not refs then
		return CFrame.identity
	end
	return refs.root.CFrame * CFrame.new(0, 0.5, 0)
end

-- Is a world position inside the bus cabin?
function BusService.isInside(pos: Vector3): boolean
	local refs = BusService.refs
	if not refs then
		return false
	end
	local rel = refs.interior.CFrame:PointToObjectSpace(pos)
	local size = refs.interior.Size
	return math.abs(rel.X) <= size.X / 2 + 0.3
		and rel.Y >= -size.Y / 2 - 1.5
		and rel.Y <= size.Y / 2 + 1
		and math.abs(rel.Z) <= size.Z / 2 + 0.3
end

function BusService.isAboard(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and BusService.isInside(root.Position)
end

function BusService.playersAboard(): { Player }
	local out = {}
	for _, player in Players:GetPlayers() do
		if BusService.isAboard(player) then
			table.insert(out, player)
		end
	end
	return out
end

local function reassertOwner()
	local refs = BusService.refs
	if refs and BusService.mode == "Physics" and not refs.root.Anchored then
		pcall(function()
			refs.root:SetNetworkOwner(nil)
		end)
	end
end

local function watchSeats(refs: BusBuilder.BusRefs)
	for _, c in seatConns do
		c:Disconnect()
	end
	table.clear(seatConns)
	local all: { Seat | VehicleSeat } = table.clone(refs.seats) :: any
	table.insert(all, refs.driverSeat)
	for _, seat in all do
		table.insert(
			seatConns,
			seat:GetPropertyChangedSignal("Occupant"):Connect(function()
				task.defer(reassertOwner)
			end)
		)
	end
end

local function setupPhysics(refs: BusBuilder.BusRefs)
	Build.setAnchored(refs.model, false)
	refs.root.Anchored = false
	local a = Instance.new("Attachment")
	a.Name = "DriveAttachment"
	a.Parent = refs.root

	local ap = Instance.new("AlignPosition")
	ap.Name = "Drive"
	ap.Mode = Enum.PositionAlignmentMode.OneAttachment
	ap.Attachment0 = a
	ap.MaxForce = Tuning.AlignMaxForce
	ap.MaxVelocity = math.huge
	ap.Responsiveness = Tuning.AlignResponsiveness
	ap.RigidityEnabled = Tuning.AlignRigid
	ap.Position = refs.root.Position
	ap.Parent = refs.root
	alignPos = ap

	local ao = Instance.new("AlignOrientation")
	ao.Name = "Steer"
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = a
	ao.MaxTorque = Tuning.AlignMaxTorque
	ao.MaxAngularVelocity = math.huge
	ao.Responsiveness = Tuning.AlignResponsiveness
	ao.RigidityEnabled = Tuning.AlignRigid
	ao.CFrame = refs.root.CFrame
	ao.Parent = refs.root
	alignOri = ao

	reassertOwner()
	watchSeats(refs)
end

-- Build the bus at distance s along the current path.
function BusService.spawn(s: number, livery: Color3?)
	BusService.despawn()
	BusService.mode = Tuning.Mode
	RunState:SetAttribute("BusMode", BusService.mode)
	local road: CFrame
	if BusService.mode == "Physics" then
		road = Chunks.path:sample(s)
	else
		road = BusService.RideSpot
	end
	BusService.s = s
	BusService.speed = 0
	BusService.lateral = Tuning.LaneOffset
	BusService.state = "Parked"
	BusService.stopS = nil
	BusService.departS = nil
	local at = rootCf(road, BusService.lateral) * CFrame.new(0, 0.5, 0)
	local refs = BusBuilder.build(World.Folders.Bus, at, livery)
	refs.model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	BusService.refs = refs
	table.clear(doorBase)
	for _, weld in refs.doorWelds do
		doorBase[weld] = weld.C0
	end
	BusService.setDoors(false, true)
	if BusService.mode == "Physics" then
		setupPhysics(refs)
	end
	Log.info("Bus", "Spawned in", BusService.mode, "mode at s =", s)
	BusService.Spawned:Fire(refs)
end

function BusService.despawn()
	if BusService.refs then
		BusService.refs.model:Destroy()
		BusService.refs = nil :: any
	end
	alignPos = nil
	alignOri = nil
end

-- Doors. Leaves slide outward along the side wall, then stop colliding.
function BusService.setDoors(open: boolean, instant: boolean?)
	local refs = BusService.refs
	if not refs then
		return
	end
	BusService.doorsOpen = open
	RunState:SetAttribute("DoorsOpen", open)
	local slide = BusBuilder.DoorWidth / 2 - 0.15
	for _, weld in refs.doorWelds do
		local leaf = weld.Part1 :: BasePart
		local dir = if leaf:GetAttribute("DoorLeaf") == 1 then -1 else 1
		local base = doorBase[weld] or weld.C0
		local goal = if open then CFrame.new(0.45, 0, dir * slide) * base else base
		if instant then
			weld.C0 = goal
		else
			TweenService:Create(weld, TweenInfo.new(Tuning.DoorOpenTime, Enum.EasingStyle.Quad), { C0 = goal }):Play()
		end
		if open then
			leaf.CanCollide = false
		else
			task.delay(if instant then 0 else Tuning.DoorOpenTime, function()
				if not BusService.doorsOpen and leaf.Parent then
					leaf.CanCollide = true
				end
			end)
		end
	end
	BusService.DoorsChanged:Fire(open)
	Net.notifyAll("Doors", { open = open })
end

-- Cabin lights by bank (1 front, 2 middle, 3 rear), or all banks when bank is nil.
function BusService.setLights(on: boolean, bank: number?)
	local refs = BusService.refs
	if not refs then
		return
	end
	for b, lights in refs.lightBanks do
		if bank == nil or bank == b then
			for _, light in lights do
				light.Enabled = on
			end
		end
	end
	for _, tube in refs.lightTubes do
		if bank == nil or tube:GetAttribute("Bank") == bank then
			tube.Material = if on then Enum.Material.Neon else Enum.Material.SmoothPlastic
			tube.Color = if on then Build.Colors.Fluor else Color3.fromRGB(70, 74, 72)
		end
	end
	if bank == nil then
		BusService.lightsOn = on
	end
end

function BusService.setHeadlights(on: boolean)
	local refs = BusService.refs
	if refs then
		for _, light in refs.headlights do
			light.Enabled = on
		end
	end
end

-- Drive to (and stop at) distance stopS along the path.
function BusService.driveTo(stopS: number)
	BusService.stopS = stopS
	BusService.state = "Approach"
end

-- Leave the current stop and cruise.
function BusService.depart()
	BusService.departS = BusService.s
	BusService.stopS = nil
	BusService.state = "Cruise"
end

-- Stalled (no fuel): stay put even if the doors close.
function BusService.stall(on: boolean)
	if on then
		BusService.state = "Stalled"
	elseif BusService.state == "Stalled" then
		BusService.state = "Docked"
	end
end

function BusService.velocity(): Vector3
	local refs = BusService.refs
	if refs and not refs.root.Anchored then
		return refs.root.AssemblyLinearVelocity
	end
	return Vector3.zero
end

-- Move every character and NPC aboard by the same offset as the bus (Stationary mode and
-- the Physics-mode reset only; never during a physics ride).
local function carryAboard(fn: () -> ())
	local refs = BusService.refs
	if not refs then
		fn()
		return
	end
	local before = refs.root.CFrame
	local riders: { Model } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if character and root and BusService.isInside(root.Position) then
			table.insert(riders, character)
		end
	end
	for _, model in World.Folders.Passengers:GetChildren() do
		if model:IsA("Model") and model.PrimaryPart and BusService.isInside(model.PrimaryPart.Position) then
			table.insert(riders, model)
		end
	end
	local offsets: { [Model]: CFrame } = {}
	for _, m in riders do
		offsets[m] = before:ToObjectSpace(m:GetPivot())
	end
	fn()
	local after = refs.root.CFrame
	for m, rel in offsets do
		if m.Parent then
			m:PivotTo(after * rel)
		end
	end
end

-- Stationary mode: put the bus at a road frame (stop curb lane or ride spot).
function BusService.placeAt(road: CFrame, lateral: number)
	local refs = BusService.refs
	if not refs then
		return
	end
	BusService.lateral = lateral
	carryAboard(function()
		refs.model:PivotTo(rootCf(road, lateral) * CFrame.new(0, 0.5, 0))
	end)
end

-- Where the bus will sit at a stop, as a root-frame CFrame (for lining up prefabs).
function BusService.dockedCFrame(curbRoad: CFrame): CFrame
	return rootCf(curbRoad, BusService.PullInOffset) * CFrame.new(0, 0.5, 0)
end

local function physicsStep(dt: number)
	local refs = BusService.refs
	if not refs or not alignPos or not alignOri then
		return
	end
	local path = Chunks.path
	local target = BusService.maxSpeed
	local state = BusService.state
	if state == "Parked" or state == "Docked" or state == "Stalled" then
		target = 0
	end
	local remaining = math.huge
	if BusService.stopS then
		remaining = BusService.stopS - BusService.s
		target = math.min(target, math.sqrt(math.max(0, 2 * Tuning.Brake * remaining)))
	end
	if target > BusService.speed then
		BusService.speed = math.min(target, BusService.speed + Tuning.Accel * dt)
	else
		BusService.speed = target
	end
	BusService.s += BusService.speed * dt
	if BusService.stopS and state == "Approach" then
		if remaining <= 0.4 or (remaining < 3 and BusService.speed < 1) then
			BusService.s = BusService.stopS
			BusService.speed = 0
			BusService.state = "Docked"
			BusService.Arrived:Fire()
		end
	end
	-- Lateral: pull in near the curb, pull out after leaving.
	local lane, curb = Tuning.LaneOffset, BusService.PullInOffset
	if BusService.stopS then
		local t = 1 - math.clamp((BusService.stopS - BusService.s) / BusService.PullInDistance, 0, 1)
		BusService.lateral = lane + (curb - lane) * smooth(t)
	elseif BusService.departS then
		local t = math.clamp((BusService.s - BusService.departS) / BusService.PullOutDistance, 0, 1)
		BusService.lateral = curb + (lane - curb) * smooth(t)
		if t >= 1 then
			BusService.departS = nil
		end
	else
		BusService.lateral = lane
	end
	local road = path:sample(BusService.s)
	local goal = rootCf(road, BusService.lateral)
	alignPos.Position = goal.Position
	alignOri.CFrame = goal
	BusService.Stepped:Fire(dt)
end

local function stationaryStep(dt: number)
	-- The ride is faked on clients; the server only tracks a virtual distance so ride
	-- events and the "approach" timing work the same in both modes.
	local state = BusService.state
	local target = if state == "Cruise" or state == "Approach" then BusService.maxSpeed else 0
	if target > BusService.speed then
		BusService.speed = math.min(target, BusService.speed + Tuning.Accel * dt)
	else
		BusService.speed = math.max(target, BusService.speed - Tuning.Brake * dt)
	end
	BusService.s += BusService.speed * dt
	RunState:SetAttribute("BusSpeed", math.floor(BusService.speed + 0.5))
	if state == "Approach" and BusService.stopS and BusService.s >= BusService.stopS then
		BusService.speed = 0
		BusService.state = "Docked"
		BusService.Arrived:Fire()
	end
	BusService.Stepped:Fire(dt)
end

function BusService:Init()
	Chunks = Registry.get("ChunkService")
	World = Registry.get("WorldService")
	RunState = World.RunState
	RunState:SetAttribute("BusMode", Tuning.Mode)
end

function BusService:Start()
	stepConn = RunService.PreSimulation:Connect(function(dt: number)
		if not BusService.refs then
			return
		end
		if BusService.mode == "Physics" then
			physicsStep(dt)
		else
			stationaryStep(dt)
		end
	end)
	-- Fallback stand-up: a seated rider whose jump didn't free them asks to stand.
	Net.on("Move", function(player: Player, action: any)
		if action ~= "stand" then
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.SeatPart then
			local weld = humanoid.SeatPart:FindFirstChild("SeatWeld")
			if weld then
				weld:Destroy()
			end
			humanoid.Sit = false
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
	-- Riders: reassert ownership when anyone sits or stands.
	Players.PlayerRemoving:Connect(function()
		task.defer(reassertOwner)
	end)
	Log.info("Bus", "Ready, mode", Tuning.Mode)
end

function BusService.stop()
	if stepConn then
		stepConn:Disconnect()
		stepConn = nil
	end
end

return BusService
