--!strict
-- The Bus Graveyard. A fenced lot of retired buses parked nose to tail in rows, windows
-- out, route signs still lit on a few. The fuel is in the wrecks' tanks and the
-- maintenance shed.
-- The Other Bus: an identical bus parked inside the lot with its doors open and its
-- engine idling in time with yours. One thing about it is wrong (the route board reads
-- N9, or the Driver isn't wearing his cap). Step aboard it and the doors close behind
-- you. Check the route number and the cap before you board.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local StopKit = require(script.Parent.Parent:WaitForChild("StopKit"))
local Props = require(script.Parent.Parent:WaitForChild("Props"))
local BusBuilder = require(script.Parent.Parent:WaitForChild("BusBuilder"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Build = require(Shared.Util.Build)
local Net = require(Shared.Net)
local Registry = require(script.Parent.Parent.Parent:WaitForChild("Registry"))

local C = Build.Colors

local LOT_X0, LOT_X1 = 12, 118
local LOT_Z0, LOT_Z1 = -68, 68
local OTHER_AT = Vector3.new(28, 0, 6) -- the Other Bus, parallel to the road, doors facing the lot
local REOPEN_AFTER = 8
local ROUTES = { "14", "22", "7X", "31", "3", "48", "12A", "60", "9", "27" }
local RUST = {
	Color3.fromRGB(150, 110, 60),
	Color3.fromRGB(120, 80, 50),
	Color3.fromRGB(170, 160, 130),
	Color3.fromRGB(110, 120, 100),
	Color3.fromRGB(160, 90, 70),
}

-- A gutted bus: a long box with its windows out and a route sign on the front.
local function wreck(
	refs: StopKit.StopRefs,
	parent: Instance,
	cf: CFrame,
	route: string,
	color: Color3
): (Model, BasePart)
	local m = Build.model(parent, "Wreck")
	local function piece(
		name: string,
		size: Vector3,
		offset: CFrame,
		col: Color3,
		mat: Enum.Material?,
		collide: boolean?
	): Part
		return StopKit.part(refs, {
			name = name,
			size = size,
			cf = cf * offset,
			color = col,
			material = mat or Enum.Material.CorrodedMetal,
			collide = if collide == nil then true else collide,
		}, m)
	end
	piece("Body", Vector3.new(9.6, 4, 40), CFrame.new(0, 2.6, 0), color)
	piece("Roof", Vector3.new(9.6, 0.8, 40), CFrame.new(0, 9.6, 0), color)
	for _, side in { -1, 1 } do
		-- Pillars between the empty window holes.
		for z = -18, 18, 6 do
			piece("Pillar", Vector3.new(0.4, 4.6, 0.8), CFrame.new(side * 4.6, 6.9, z), color)
		end
	end
	piece("Front", Vector3.new(9.6, 4.6, 0.4), CFrame.new(0, 6.9, -19.8), color)
	piece("Back", Vector3.new(9.6, 4.6, 0.4), CFrame.new(0, 6.9, 19.8), color)
	piece("Interior", Vector3.new(9, 0.2, 39), CFrame.new(0, 4.7, 0), Color3.fromRGB(50, 46, 40), Enum.Material.Wood)
	for _, side in { -1, 1 } do
		for z = -14, 14, 28 do
			piece("Rim", Vector3.new(0.8, 2.4, 2.4), CFrame.new(side * 4.4, 0.6, z), C.DarkMetal, Enum.Material.Metal)
		end
	end
	local signPart, label = StopKit.sign(refs, {
		name = "RouteSign",
		size = Vector3.new(6, 1, 0.3),
		cf = cf * CFrame.new(0, 8.6, -20.05),
		color = C.Black,
		collide = false,
	}, route, Enum.NormalId.Front, Color3.fromRGB(255, 170, 40), m)
	label.Font = Enum.Font.Code
	return m, signPart
end

return function(parent: Instance, frame: CFrame, ctx: StopKit.Ctx, title: string): StopKit.StopRefs
	local refs = StopKit.new(ctx.id, parent, frame)
	StopKit.lot(refs, LOT_X1, LOT_Z0, LOT_Z1, Color3.fromRGB(70, 64, 56), Enum.Material.Ground)
	StopKit.sidewalk(refs, -60, 60)
	StopKit.shelter(refs, title)
	StopKit.approachLights(refs)
	refs.passengerSpot = StopKit.marker(refs, "PassengerSpot", CFrame.new(6, 3, -2))

	-- The fence, with the gate open by the shelter.
	Props.fence(refs, Vector3.new(LOT_X0, 0.4, LOT_Z0), Vector3.new(LOT_X1, 0.4, LOT_Z0))
	Props.fence(refs, Vector3.new(LOT_X0, 0.4, LOT_Z1), Vector3.new(LOT_X1, 0.4, LOT_Z1))
	Props.fence(refs, Vector3.new(LOT_X1, 0.4, LOT_Z0), Vector3.new(LOT_X1, 0.4, LOT_Z1))
	Props.fence(refs, Vector3.new(LOT_X0, 0.4, LOT_Z0), Vector3.new(LOT_X0, 0.4, -24))
	Props.fence(refs, Vector3.new(LOT_X0, 0.4, 24), Vector3.new(LOT_X0, 0.4, LOT_Z1))
	local _, gateLabel = StopKit.sign(refs, {
		name = "YardSign",
		size = Vector3.new(0.3, 2.4, 10),
		cf = CFrame.new(LOT_X0, 7, -30),
		color = Color3.fromRGB(240, 236, 220),
		collide = false,
	}, "HCTA FLEET DISPOSAL\nNO RIDERS", Enum.NormalId.Left, Color3.fromRGB(160, 30, 30))
	gateLabel.Font = Enum.Font.GothamBlack

	-- Rows of wrecks. All their route signs together are one anomaly slot.
	local wrecks = Build.model(refs.model, "Wrecks")
	local signs = Build.model(refs.model, "RouteSigns")
	local k = 0
	local firstWreck: Model? = nil
	for _, x in { 58, 76, 94, 110 } do
		for _, z in { -44, 0, 44 } do
			k += 1
			if not (x == 58 and z == 0) then
				local tilt = CFrame.Angles(
					math.rad(ctx.rng:float(-3, 3)),
					math.rad(ctx.rng:float(-6, 6)),
					math.rad(ctx.rng:float(-4, 4))
				)
				local m, signPart = wreck(
					refs,
					wrecks,
					CFrame.new(x, 0.4, z) * tilt,
					ROUTES[((k + ctx.stopIndex) % #ROUTES) + 1],
					RUST[(k % #RUST) + 1]
				)
				signPart.Parent = signs
				if not firstWreck then
					firstWreck = m
				end
				if k % 3 == 0 then
					StopKit.lootPoint(refs, Vector3.new(x, 5.4, z + ctx.rng:float(-14, 14)), "fuel")
				else
					StopKit.lootPoint(refs, Vector3.new(x, 5.4, z + ctx.rng:float(-14, 14)))
				end
				StopKit.hidingSpot(refs, CFrame.new(x + 3, 6, z + 10))
			end
		end
	end
	StopKit.slot(refs, "bus_signs", signs)
	-- The brass fleet plate screwed to the first wreck.
	StopKit.lore(refs, "graveyard_plate", CFrame.new(53.1, 4.2, -40) * CFrame.Angles(0, math.rad(-90), 0), true)

	-- A wreck with its interior lights on (normally dark).
	local glow = Build.model(refs.model, "WreckGlow")
	for z = -16, 16, 8 do
		local tube = StopKit.part(refs, {
			name = "Tube",
			size = Vector3.new(0.3, 0.2, 5),
			cf = CFrame.new(76, 9, 44 + z),
			color = Color3.fromRGB(230, 240, 220),
			material = Enum.Material.SmoothPlastic,
			collide = false,
		}, glow)
		local l = Build.light(tube, "Point", Color3.fromRGB(220, 240, 210), 1.4, 14, false)
		l.Enabled = false
	end
	StopKit.slot(refs, "wreck_lights", glow)
	-- A driver at the wheel of a wreck (normally the seat is empty).
	local ghost = Build.model(refs.model, "WreckDriver")
	StopKit.figure(refs, "Driver", CFrame.new(93, 4.8, -62), Color3.fromRGB(32, 48, 72), ghost, { height = 0.9 })
	StopKit.slot(
		refs,
		"wreck_driver",
		StopKit.marker(refs, "WreckSeat", CFrame.new(93, 6, -62)),
		{ graveyard_driver = ghost :: Instance }
	)

	-- The maintenance shed: tools, a fuel bay, the fragment in the pit.
	local shed = StopKit.building(refs, "Shed", Vector3.new(36, 7, -50), Vector3.new(30, 14, 26), C.Siding, 8, -50)
	StopKit.ceilingLight(refs, Vector3.new(36, 13, -50), C.Fluor, 18, shed)
	Props.shelf(refs, CFrame.new(48, 0.4, -50) * CFrame.Angles(0, math.rad(90), 0), 14, 7, shed, ctx.stopIndex)
	Props.counter(refs, CFrame.new(30, 0.4, -61), Vector3.new(12, 3.4, 2.4), nil, nil, shed)
	StopKit.lootPoint(refs, Vector3.new(30, 4.2, -61), "fuel")
	StopKit.lootPoint(refs, Vector3.new(46, 3.4, -46))
	StopKit.lootPoint(refs, Vector3.new(26, 1.4, -42), "battery")
	StopKit.part(refs, {
		name = "Pit",
		size = Vector3.new(4, 0.1, 12),
		cf = CFrame.new(36, 0.45, -50),
		color = Color3.fromRGB(20, 18, 16),
		collide = false,
	}, shed)
	StopKit.fragmentSite(refs, Vector3.new(36, 1.5, -46))
	StopKit.hidingSpot(refs, CFrame.new(44, 2, -58))
	StopKit.lootPoint(refs, Vector3.new(112, 1.4, -62))
	StopKit.lootPoint(refs, Vector3.new(112, 1.4, 62), "fuel")
	StopKit.lootPoint(refs, Vector3.new(40, 1.4, 60))

	-- Floodlights on poles at the corners, two of them dead.
	for i, p in { Vector3.new(20, 0, -64), Vector3.new(114, 0, -64), Vector3.new(114, 0, 64), Vector3.new(20, 0, 64) } do
		StopKit.part(refs, {
			name = "FloodPole",
			size = Vector3.new(0.6, 18, 0.6),
			cf = CFrame.new(p + Vector3.new(0, 9, 0)),
			color = C.DarkMetal,
			material = Enum.Material.Metal,
		})
		local head = StopKit.part(refs, {
			name = "Flood",
			size = Vector3.new(2, 1, 1.4),
			cf = CFrame.new(p + Vector3.new(0, 18, 0)),
			color = if i % 2 == 1 then Color3.fromRGB(255, 230, 180) else Color3.fromRGB(40, 40, 40),
			material = if i % 2 == 1 then Enum.Material.Neon else Enum.Material.Metal,
			collide = false,
		})
		if i % 2 == 1 then
			local spot = Build.light(head, "Spot", Color3.fromRGB(255, 225, 170), 1.6, 60, true)
			if spot:IsA("SpotLight") then
				spot.Face = Enum.NormalId.Bottom
				spot.Angle = 80
			end
		end
	end

	-- The Other Bus. Built from the same plans as yours, then made still.
	local tell = if ctx.rng:chance(0.5) then "board" else "cap"
	local hover = Config.Tuning.Bus.HoverHeight
	local other = BusBuilder.build(refs.model, refs.frame * CFrame.new(OTHER_AT + Vector3.new(0, 0.4 + hover, 0)))
	other.model.Name = "OtherBus"
	other.model:SetAttribute("HCTA", nil)
	other.model:SetAttribute("Entity", "other_bus")
	local leaves: { [BasePart]: boolean } = {}
	for _, weld in other.doorWelds do
		leaves[weld.Part1 :: BasePart] = true
	end
	for _, d in other.model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = not leaves[d]
		end
		if d:IsA("Seat") then
			(d :: Seat).Disabled = true
		end
	end
	other.driverSeat.Disabled = true
	for _, bank in other.lightBanks do
		for _, l in bank do
			l.Enabled = true
		end
	end
	for _, h in other.headlights do
		h.Enabled = true
	end
	if tell == "cap" then
		for _, name in { "Cap", "CapBrim" } do
			local part = other.driverModel:FindFirstChild(name)
			if part then
				part:Destroy()
			end
		end
	end
	-- Its route board copies yours, nearly.
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Display"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Brightness = 1.4
	gui.Parent = other.routeBoard
	local bg = Instance.new("Frame")
	bg.Size = UDim2.fromScale(1, 1)
	bg.BackgroundColor3 = Color3.fromRGB(10, 8, 4)
	bg.BorderSizePixel = 0
	bg.Parent = gui
	local function boardLabel(name: string, y: number, h: number, color: Color3): TextLabel
		local l = Instance.new("TextLabel")
		l.Name = name
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.Code
		l.TextScaled = true
		l.TextColor3 = color
		l.Size = UDim2.fromScale(1, h)
		l.Position = UDim2.fromScale(0, y)
		l.Text = ""
		l.Parent = gui
		return l
	end
	local main = boardLabel("Main", 0.02, 0.56, Color3.fromRGB(255, 170, 40))
	local sub = boardLabel("Sub", 0.6, 0.38, Color3.fromRGB(255, 120, 30))

	local doorBase: { [Weld]: CFrame } = {}
	for _, weld in other.doorWelds do
		doorBase[weld] = weld.C0
	end
	local doorsOpen = false
	local function setDoors(open: boolean)
		doorsOpen = open
		local slide = BusBuilder.DoorWidth / 2 - 0.15
		for _, weld in other.doorWelds do
			local leaf = weld.Part1 :: BasePart
			local dir = if leaf:GetAttribute("DoorLeaf") == 1 then -1 else 1
			local base = doorBase[weld]
			local goal = if open then CFrame.new(0.45, 0, dir * slide) * base else base
			TweenService:Create(weld, TweenInfo.new(0.8, Enum.EasingStyle.Quad), { C0 = goal }):Play()
			leaf.CanCollide = not open
		end
		Net.notifyAll("Sound", { key = "DoorHiss", part = other.root })
	end

	local function insideOther(pos: Vector3): boolean
		local rel = other.interior.CFrame:PointToObjectSpace(pos)
		local size = other.interior.Size
		return math.abs(rel.X) <= size.X / 2 + 0.3
			and rel.Y >= -size.Y / 2 - 1.5
			and rel.Y <= size.Y / 2 + 1
			and math.abs(rel.Z) <= size.Z / 2 + 0.3
	end

	-- The lure: a fuel can on the Other Bus's steps.
	refs.extras.custom = {
		graveyard_lure_can = function(built: any)
			local can = Build.part(refs.model, {
				name = "StepCan",
				size = Vector3.new(1.4, 1.8, 1),
				cf = refs.frame
					* CFrame.new(OTHER_AT + Vector3.new(BusBuilder.Width / 2 + 1.2, 1.4, BusBuilder.FrontDoorZ)),
				color = Color3.fromRGB(200, 40, 30),
				material = Enum.Material.Metal,
				collide = false,
				group = "World",
			})
			local prompt = Build.prompt(can, "Take", "Fuel Can", 0, 6, "CanPrompt")
			prompt.Triggered:Connect(function(player: Player)
				local PlayerState = Registry.find("PlayerStateService")
				if not PlayerState or not PlayerState.isHealthy(player) or built.active == false then
					return
				end
				prompt.Enabled = false
				can:Destroy()
				Net.notify(player, "Toast", { text = "Empty. Something on the steps took hold of your ankle." })
				PlayerState.down(player, "other_bus")
			end)
		end,
	}

	local token = 0
	refs.extras.activate = function(built: any)
		token += 1
		local mine = token
		local PlayerState = Registry.find("PlayerStateService")
		local Bus = Registry.find("BusService")
		local Dread = Registry.find("DreadService")
		task.delay(2, function()
			if mine == token and built.active ~= false then
				setDoors(true)
				Net.notifyAll("Sound", { key = "EngineIdle", part = other.root, loop = true })
			end
		end)
		task.spawn(function()
			local copyAt = 0
			while mine == token and built.active ~= false and other.model.Parent do
				local t = os.clock()
				-- The board copies yours, with the route number turned around if that's its tell.
				if t >= copyAt and Bus and Bus.refs then
					copyAt = t + 0.5
					local real = Bus.refs.routeBoard:FindFirstChild("Display")
					local rm = real and real:FindFirstChild("Main") :: TextLabel?
					local rs = real and real:FindFirstChild("Sub") :: TextLabel?
					local text = if rm then rm.Text else "9N  NIGHT OWL"
					main.Text = if tell == "board" then (string.gsub(text, "^9N", "N9")) else text
					sub.Text = if rs then rs.Text else ""
				end
				if doorsOpen and PlayerState then
					for _, player in Players:GetPlayers() do
						local root = PlayerState.rootOf(player)
						if root and PlayerState.isHealthy(player) and insideOther(root.Position) then
							-- Aboard the wrong bus.
							setDoors(false)
							Net.notifyAll("Toast", { text = "The other bus's doors close." })
							if Dread then
								Dread.add(player, 20)
							end
							task.delay(0.8, function()
								if PlayerState.isHealthy(player) then
									PlayerState.down(player, "other_bus")
								end
							end)
							task.delay(REOPEN_AFTER, function()
								if mine == token and built.active ~= false then
									setDoors(true)
								end
							end)
							break
						end
					end
				end
				task.wait(0.2)
			end
		end)
	end
	refs.extras.deactivate = function()
		token += 1
		if doorsOpen then
			setDoors(false)
		end
	end

	local _ = firstWreck
	StopKit.entitySpawn(refs, CFrame.new(60, 3, 0))
	StopKit.trailhead(refs, CFrame.new(LOT_X1 - 4, 0, LOT_Z1 - 4))
	StopKit.backEntrance(refs, CFrame.new(LOT_X1 - 4, 3, LOT_Z0 + 4))
	return refs
end
