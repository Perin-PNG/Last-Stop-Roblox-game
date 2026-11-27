--!strict
-- Builds HCTA Unit 9, the 9N Night Owl, out of parts at 1.3x scale (56 x 12 x 13 studs).
-- Local frame: origin is the centre of the floor's top surface, -Z is forward, +X is the
-- curb side (doors), -X is the street side (driver, fuel cap).
--
-- If ServerStorage.Assets.Bus exists it is used instead (same part names required).

local ServerStorage = game:GetService("ServerStorage")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Build = require(Shared.Util.Build)

local C = Build.Colors

local BusBuilder = {}

BusBuilder.Length = 56
BusBuilder.Width = 12
BusBuilder.Height = 11 -- interior floor to ceiling
BusBuilder.FrontZ = -28
BusBuilder.RearZ = 28
BusBuilder.FrontDoorZ = -21.5 -- centre of the front door opening
BusBuilder.MiddleDoorZ = 1.5
BusBuilder.DoorWidth = 4.6
BusBuilder.SeatRows = { -15, -10.5, -6, 6, 10.5, 15, 19.5 }
BusBuilder.ExtraRowZ = 1.5 -- the bus_extra_row anomaly puts a row here (street side)

export type BusRefs = {
	model: Model,
	root: BasePart,
	interior: BasePart,
	mirror: BasePart,
	routeBoard: BasePart,
	rulesPlaque: BasePart,
	dashboard: BasePart,
	patienceLight: BasePart,
	frontDoor: { BasePart },
	middleDoor: { BasePart },
	doorWelds: { Weld },
	seats: { Seat },
	backRowSeats: { Seat },
	driverSeat: VehicleSeat,
	lightBanks: { { Light } },
	lightTubes: { BasePart },
	adPanels: { BasePart },
	cords: { BasePart },
	fuelCap: BasePart,
	lostAndFound: BasePart,
	holdButton: BasePart,
	recoveryBay: BasePart,
	fragmentSlots: { BasePart },
	voteButtons: { BasePart },
	rearWindow: BasePart,
	paSpeaker: BasePart,
	extraRow: Model,
	driverModel: Model,
	headlights: { Light },
	fareBox: BasePart,
}

local function makeDriver(parent: Instance, at: CFrame): Model
	-- Only ever seen from behind: uniform, cap, hunched shoulders. No face on the model;
	-- the face exists only in the mirror (MirrorController draws it).
	local m = Build.model(parent, "Driver")
	local uniform = Color3.fromRGB(32, 48, 72)
	local seatCf = at
	local torso = Build.part(m, {
		name = "Torso",
		size = Vector3.new(2.6, 3, 1.4),
		cf = seatCf * CFrame.new(0, 3.9, 0.2) * CFrame.Angles(math.rad(-14), 0, 0),
		color = uniform,
		material = Enum.Material.Fabric,
		collide = false,
		group = "Bus",
	})
	Build.part(m, {
		name = "Shoulders",
		size = Vector3.new(3.2, 0.9, 1.5),
		cf = torso.CFrame * CFrame.new(0, 1.3, 0.1),
		color = uniform,
		material = Enum.Material.Fabric,
		collide = false,
		group = "Bus",
	})
	local head = Build.part(m, {
		name = "Head",
		size = Vector3.new(1.3, 1.4, 1.3),
		cf = torso.CFrame * CFrame.new(0, 2.15, -0.25),
		color = Color3.fromRGB(150, 140, 130),
		material = Enum.Material.SmoothPlastic,
		collide = false,
		group = "Bus",
	})
	Build.part(m, {
		name = "Cap",
		size = Vector3.new(1.45, 0.45, 1.45),
		cf = head.CFrame * CFrame.new(0, 0.8, 0),
		color = uniform,
		material = Enum.Material.Fabric,
		collide = false,
		group = "Bus",
	})
	Build.part(m, {
		name = "CapBrim",
		size = Vector3.new(1.3, 0.12, 0.7),
		cf = head.CFrame * CFrame.new(0, 0.62, -0.9),
		color = Color3.fromRGB(15, 15, 18),
		collide = false,
		group = "Bus",
	})
	for side = -1, 1, 2 do
		Build.part(m, {
			name = "Arm",
			size = Vector3.new(0.8, 2.6, 0.8),
			cf = torso.CFrame * CFrame.new(side * 1.6, -0.2, -0.9) * CFrame.Angles(math.rad(-60), 0, 0),
			color = uniform,
			material = Enum.Material.Fabric,
			collide = false,
			group = "Bus",
		})
	end
	m.PrimaryPart = torso
	return m
end

local function adText(i: number): string
	local ads = {
		"HOLLOW COUNTY TRANSIT\nWe'll get you there.",
		"ROSIE'S 24/7 DINER\nPie all night.",
		"SUDS LAUNDROMAT\nOpen 24 hours.",
		"WESTBROOK LIBRARY\nQuiet please.",
		"MERCY GENERAL\nWe never close.",
		"RIVERSIDE MOTEL\nVacancy.",
		"GAS & GO\nFill up. Stop again.",
		"NORTHGATE MALL\nEverything must go.",
		"HCTA REMINDER\nKeep your ticket on you.",
		"HOLLIS FARM\nPick your own.",
		"SEE SOMETHING?\nSay nothing. Stay seated.",
		"TRI-COUNTY DEPOT\nNow hiring drivers.",
	}
	return ads[((i - 1) % #ads) + 1]
end

function BusBuilder.build(parent: Instance, at: CFrame, livery: Color3?): BusRefs
	local assets = ServerStorage:FindFirstChild("Assets")
	local custom = assets and assets:FindFirstChild("Bus")
	if custom and custom:IsA("Model") then
		warn("[BusBuilder] ServerStorage.Assets.Bus found; custom bus models need the same part names")
	end

	local model = Build.model(parent, "Bus")
	local function L(x: number, y: number, z: number): CFrame
		return at * CFrame.new(x, y, z)
	end
	local function P(name: string, size: Vector3, cf: CFrame, color: Color3, props: { [string]: any }?): Part
		local opts: Build.PartProps = {
			name = name,
			size = size,
			cf = cf,
			color = color,
			group = "Bus",
		}
		if props then
			for k, v in props do
				(opts :: any)[k] = v
			end
		end
		return Build.part(model, opts)
	end

	local body = livery or C.BusBody
	local W, LEN = BusBuilder.Width, BusBuilder.Length
	local halfW, halfL = W / 2, LEN / 2

	-- Floor (the root part)
	local root = P("Floor", Vector3.new(W, 1, LEN), L(0, -0.5, 0), Color3.fromRGB(60, 62, 58), {
		material = Enum.Material.DiamondPlate,
	})
	root.CustomPhysicalProperties = PhysicalProperties.new(4, 0.6, 0, 1, 1)
	root.RootPriority = 127
	model.PrimaryPart = root
	P("Underbody", Vector3.new(W - 0.4, 1.4, LEN - 1), L(0, -1.7, 0), C.DarkMetal, { collide = false })

	-- Interior bounds (used for "aboard" checks and streaming), invisible, no collisions.
	local interior = P("Interior", Vector3.new(W, BusBuilder.Height, LEN), L(0, BusBuilder.Height / 2, 0), C.Black, {
		transparency = 1,
		collide = false,
		query = false,
	})

	-- Roof and ceiling
	P("Roof", Vector3.new(W + 0.4, 1, LEN + 0.4), L(0, BusBuilder.Height + 0.5, 0), body, {
		material = Enum.Material.Metal,
	})
	P(
		"Ceiling",
		Vector3.new(W - 0.2, 0.2, LEN - 0.4),
		L(0, BusBuilder.Height - 0.1, 0),
		Color3.fromRGB(200, 200, 190),
		{
			collide = false,
		}
	)

	-- Walls. Each side: lower panel (0-4), window band (4-9), upper panel (9-11).
	local function wallSegment(side: number, z0: number, z1: number, withWindow: boolean)
		local len = z1 - z0
		if len <= 0.05 then
			return
		end
		local zc = (z0 + z1) / 2
		local x = side * (halfW - 0.25)
		P("WallLow", Vector3.new(0.5, 4, len), L(x, 2, zc), body, { material = Enum.Material.Metal })
		P("WallHigh", Vector3.new(0.5, 2, len), L(x, 10, zc), body, { material = Enum.Material.Metal })
		if withWindow then
			P("Window", Vector3.new(0.3, 5, len), L(x, 6.5, zc), C.Glass, {
				transparency = 0.72,
				material = Enum.Material.Glass,
				attrs = { Window = true },
			})
		else
			P("WallMid", Vector3.new(0.5, 5, len), L(x, 6.5, zc), body, { material = Enum.Material.Metal })
		end
		-- Stripe on the outside
		P("Stripe", Vector3.new(0.1, 0.6, len), L(side * (halfW + 0.02), 3.4, zc), C.BusStripe, { collide = false })
	end

	local fd0, fd1 = BusBuilder.FrontDoorZ - BusBuilder.DoorWidth / 2, BusBuilder.FrontDoorZ + BusBuilder.DoorWidth / 2
	local md0, md1 =
		BusBuilder.MiddleDoorZ - BusBuilder.DoorWidth / 2, BusBuilder.MiddleDoorZ + BusBuilder.DoorWidth / 2
	-- Street side (-X): continuous, windows from the cab back.
	wallSegment(-1, -halfL, -23.5, false)
	wallSegment(-1, -23.5, halfL - 0.5, true)
	-- Curb side (+X): openings for the two doors.
	wallSegment(1, -halfL, fd0, false)
	wallSegment(1, fd1, md0, true)
	wallSegment(1, md1, halfL - 0.5, true)
	-- Door headers over the openings
	P("FrontDoorHeader", Vector3.new(0.5, 2, BusBuilder.DoorWidth), L(halfW - 0.25, 10, BusBuilder.FrontDoorZ), body)
	P("MiddleDoorHeader", Vector3.new(0.5, 2, BusBuilder.DoorWidth), L(halfW - 0.25, 10, BusBuilder.MiddleDoorZ), body)

	-- Doors: two leaves per door, welded to the floor with a Weld whose C0 slides them open.
	local doorWelds: { Weld } = {}
	local function makeDoor(name: string, zc: number): { BasePart }
		local leaves: { BasePart } = {}
		for i, offset in { -BusBuilder.DoorWidth / 4, BusBuilder.DoorWidth / 4 } do
			local leaf = P(
				name,
				Vector3.new(0.3, 9, BusBuilder.DoorWidth / 2 - 0.05),
				L(halfW - 0.2, 4.5, zc + offset),
				C.Glass,
				{
					transparency = 0.45,
					material = Enum.Material.Glass,
					attrs = { DoorLeaf = i, ClosedZ = zc + offset },
				}
			)
			Build.part(model, {
				name = name .. "Frame",
				size = Vector3.new(0.35, 9, 0.25),
				cf = leaf.CFrame * CFrame.new(0, 0, (if i == 1 then -1 else 1) * (BusBuilder.DoorWidth / 4 - 0.12)),
				color = C.DarkMetal,
				collide = false,
				group = "Bus",
			})
			table.insert(leaves, leaf)
		end
		-- A step outside the doorway, halfway between the curb and the floor.
		P(name .. "Step", Vector3.new(1.4, 0.4, BusBuilder.DoorWidth), L(halfW + 0.7, -1.3, zc), C.DarkMetal, {
			material = Enum.Material.DiamondPlate,
		})
		return leaves
	end
	local frontDoor = makeDoor("FrontDoor", BusBuilder.FrontDoorZ)
	local middleDoor = makeDoor("MiddleDoor", BusBuilder.MiddleDoorZ)

	-- Front and back
	P("FrontLow", Vector3.new(W, 4, 0.5), L(0, 2, -halfL + 0.25), body, { material = Enum.Material.Metal })
	P("Windshield", Vector3.new(W - 0.6, 5.5, 0.3), L(0, 6.75, -halfL + 0.2), C.Glass, {
		transparency = 0.6,
		material = Enum.Material.Glass,
	})
	P("FrontHigh", Vector3.new(W, 1.5, 0.5), L(0, 10.25, -halfL + 0.25), body)
	P("RearLow", Vector3.new(W, 5, 0.5), L(0, 2.5, halfL - 0.25), body, { material = Enum.Material.Metal })
	local rearWindow = P("RearWindow", Vector3.new(W - 3, 4, 0.3), L(0, 7, halfL - 0.2), C.Glass, {
		transparency = 0.55,
		material = Enum.Material.Glass,
		attrs = { Window = true },
	})
	P("RearHigh", Vector3.new(W, 2, 0.5), L(0, 10, halfL - 0.25), body)
	P("RearPillarL", Vector3.new(1.5, 4, 0.5), L(-halfW + 0.75, 7, halfL - 0.25), body)
	P("RearPillarR", Vector3.new(1.5, 4, 0.5), L(halfW - 0.75, 7, halfL - 0.25), body)
	local exitSign, _ = Build.sign(model, {
		name = "EmergencyExit",
		size = Vector3.new(4, 0.6, 0.1),
		cf = L(0, 9.2, halfL - 0.55) * CFrame.Angles(0, math.pi, 0),
		color = C.Red,
		collide = false,
		group = "Bus",
	}, "EMERGENCY EXIT - LOCKED", Enum.NormalId.Front)
	exitSign.Material = Enum.Material.Neon

	-- Exterior route sign
	local destSign, _ = Build.sign(model, {
		name = "DestinationSign",
		size = Vector3.new(8, 1, 0.1),
		cf = L(0, 10.4, -halfL - 0.05),
		color = C.Black,
		collide = false,
		group = "Bus",
	}, "9N  NIGHT OWL", Enum.NormalId.Front, Color3.fromRGB(255, 170, 60))
	destSign.Material = Enum.Material.Neon

	-- Wheels (decoration only)
	for _, z in { -18, 18 } do
		for side = -1, 1, 2 do
			P(
				"Wheel",
				Vector3.new(1.6, 3.6, 3.6),
				L(side * (halfW - 0.4), -2.2, z) * CFrame.Angles(0, 0, math.pi / 2),
				C.Black,
				{
					shape = Enum.PartType.Cylinder,
					collide = false,
					query = false,
				}
			)
		end
	end
	-- Headlights and taillights
	local headlights: { Light } = {}
	for side = -1, 1, 2 do
		local lamp = P("Headlamp", Vector3.new(1.4, 0.8, 0.2), L(side * 4.4, 1.6, -halfL - 0.1), C.White, {
			material = Enum.Material.Neon,
			collide = false,
		})
		local beam = Build.light(lamp, "Spot", Color3.fromRGB(255, 240, 210), 3, 90, true);
		(beam :: SpotLight).Face = Enum.NormalId.Front;
		(beam :: SpotLight).Angle = 55
		table.insert(headlights, beam)
		P("Taillamp", Vector3.new(1.2, 1, 0.2), L(side * 4.6, 2, halfL + 0.1), C.Red, {
			material = Enum.Material.Neon,
			collide = false,
		})
	end

	-- Driver's cab
	local driverSeat = Instance.new("VehicleSeat")
	driverSeat.Name = "DriverSeat"
	driverSeat.Size = Vector3.new(2.4, 1, 2.4)
	driverSeat.CFrame = L(-3.4, 1.2, -25.2)
	driverSeat.Color = C.Seat
	driverSeat.Anchored = true
	driverSeat.CollisionGroup = "Bus"
	driverSeat.MaxSpeed = 0
	driverSeat.Torque = 0
	driverSeat.HeadsUpDisplay = false
	driverSeat.Disabled = true -- the Driver's seat opens only in the finale
	driverSeat.Parent = model
	P("Partition", Vector3.new(5.4, 8, 0.2), L(-3.3, 4.6, -23.4), C.Glass, {
		transparency = 0.7,
		material = Enum.Material.Glass,
	})
	P("PartitionScratches", Vector3.new(5.2, 7.6, 0.05), L(-3.3, 4.6, -23.28), Color3.fromRGB(200, 200, 200), {
		transparency = 0.93,
		collide = false,
	})
	local patienceLight =
		P("PatienceLight", Vector3.new(0.8, 0.8, 0.2), L(-1.2, 8.2, -23.25), Color3.fromRGB(40, 220, 80), {
			material = Enum.Material.Neon,
			collide = false,
		})
	local dashboard =
		P("Dashboard", Vector3.new(W - 1, 1.6, 2), L(0, 3.4, -26.6) * CFrame.Angles(math.rad(-25), 0, 0), C.DarkMetal)
	local steering = P(
		"SteeringWheel",
		Vector3.new(1.8, 0.2, 1.8),
		L(-3.4, 4.2, -26.1) * CFrame.Angles(math.rad(60), 0, 0),
		C.Black,
		{
			shape = Enum.PartType.Cylinder,
			collide = false,
		}
	)
	steering.Size = Vector3.new(0.2, 1.9, 1.9)
	local driverModel = makeDriver(model, L(-3.4, 0, -25.2))

	-- Mirror: the wide interior mirror above the windshield, facing the riders.
	local mirror = P(
		"Mirror",
		Vector3.new(5.5, 1.4, 0.2),
		L(0, 9.4, -26.4) * CFrame.Angles(math.rad(8), math.pi, 0),
		Color3.fromRGB(180, 190, 195),
		{
			material = Enum.Material.Glass,
			reflectance = 0.35,
			collide = false,
		}
	)
	P("MirrorFrame", Vector3.new(5.8, 1.7, 0.15), mirror.CFrame * CFrame.new(0, 0, 0.12), C.Black, { collide = false })

	-- LED route board above the windshield, facing back.
	local routeBoard =
		P("RouteBoard", Vector3.new(9, 1.4, 0.3), L(0, 10.3, -26.9) * CFrame.Angles(0, math.pi, 0), C.Black, {
			collide = false,
		})
	local voteButtons: { BasePart } = {}
	for i, x in { -2.2, 2.2 } do
		local button = P(
			"Vote" .. (if i == 1 then "A" else "B"),
			Vector3.new(1.4, 1, 0.4),
			L(x + 1.4, 6.2, -23.1),
			if i == 1 then Color3.fromRGB(60, 140, 220) else Color3.fromRGB(230, 150, 40),
			{
				material = Enum.Material.Neon,
				collide = false,
				attrs = { Option = i },
			}
		)
		table.insert(voteButtons, button)
	end
	-- Fragment slots: five on a panel by the front door.
	local slotPanel =
		P("FragmentPanel", Vector3.new(0.2, 2.2, 5.5), L(halfW - 0.55, 6.8, -15.5), C.DarkMetal, { collide = false })
	local fragmentSlots: { BasePart } = {}
	for i = 1, 5 do
		local slot = P(
			"FragmentSlot",
			Vector3.new(0.15, 1.2, 0.9),
			slotPanel.CFrame * CFrame.new(-0.12, 0, (i - 3) * 1.05),
			Color3.fromRGB(40, 40, 40),
			{
				collide = false,
				material = Enum.Material.Neon,
				attrs = { Slot = i },
			}
		)
		table.insert(fragmentSlots, slot)
	end
	Build.sign(model, {
		name = "FragmentLabel",
		size = Vector3.new(0.1, 0.5, 5.5),
		cf = slotPanel.CFrame * CFrame.new(-0.12, 1.4, 0),
		color = C.DarkMetal,
		collide = false,
		group = "Bus",
	}, "ROUTE FRAGMENTS", Enum.NormalId.Left)

	-- Rules plaque by the front door (on the curb-side wall behind the door).
	local rulesPlaque =
		P("RulesPlaque", Vector3.new(0.15, 4.2, 3.4), L(halfW - 0.55, 6.2, -11.2), Color3.fromRGB(235, 230, 210), {
			collide = false,
		})
	-- Fare box
	local fareBox =
		P("FareBox", Vector3.new(1.2, 3.4, 1.2), L(2.4, 1.7, -23.4), C.Metal, { material = Enum.Material.Metal })

	-- Seats: forward-facing pairs. Street side runs the full length; curb side skips the doors.
	local seats: { Seat } = {}
	local backRowSeats: { Seat } = {}
	local function seat(cf: CFrame, name: string?): Seat
		local s = Instance.new("Seat")
		s.Name = name or "Seat"
		s.Size = Vector3.new(1.6, 0.6, 1.8)
		s.CFrame = cf
		s.Color = C.Seat
		s.Material = Enum.Material.Fabric
		s.Anchored = true
		s.CollisionGroup = "Bus"
		s.TopSurface = Enum.SurfaceType.Smooth
		s.Parent = model
		local back = P("SeatBack", Vector3.new(1.6, 2.4, 0.3), cf * CFrame.new(0, 1.3, 0.85), C.Seat, {
			material = Enum.Material.Fabric,
		})
		back.Name = "SeatBack"
		table.insert(seats, s)
		return s
	end
	for _, z in BusBuilder.SeatRows do
		for _, x in { -4.9, -3.2 } do
			seat(L(x, 1.4, z))
		end
		local nearDoor = (z > md0 - 1.5 and z < md1 + 1.5) or (z > fd0 - 1.5 and z < fd1 + 1.5)
		if not nearDoor then
			for _, x in { 3.2, 4.9 } do
				seat(L(x, 1.4, z))
			end
		end
	end
	-- The five-seat back bench on a raised step.
	P("RearStep", Vector3.new(W - 1, 1, 4), L(0, 0.5, halfL - 2.5), Color3.fromRGB(60, 62, 58), {
		material = Enum.Material.DiamondPlate,
	})
	for i = 1, 5 do
		local s = seat(L(-4.4 + (i - 1) * 2.2, 2.4, halfL - 2.2), "BackSeat")
		table.insert(backRowSeats, s)
	end

	-- Extra row (hidden unless the bus_extra_row anomaly is active)
	local extraRow = Build.model(model, "ExtraRow")
	for _, x in { -4.9, -3.2 } do
		local s = Instance.new("Seat")
		s.Name = "ExtraSeat"
		s.Size = Vector3.new(1.6, 0.6, 1.8)
		s.CFrame = L(x, 1.4, BusBuilder.ExtraRowZ)
		s.Color = C.Seat
		s.Anchored = true
		s.CollisionGroup = "Bus"
		s.Disabled = true
		s.Transparency = 1
		s.CanCollide = false
		s.Parent = extraRow
		local back = Build.part(extraRow, {
			name = "SeatBack",
			size = Vector3.new(1.6, 2.4, 0.3),
			cf = s.CFrame * CFrame.new(0, 1.3, 0.85),
			color = C.Seat,
			transparency = 1,
			collide = false,
			group = "Bus",
		})
		back.Material = Enum.Material.Fabric
	end

	-- Recovery bay (wheelchair bay opposite the middle door)
	local recoveryBay =
		P("RecoveryBay", Vector3.new(4, 0.1, 5), L(-3.8, 0.05, BusBuilder.MiddleDoorZ), Color3.fromRGB(40, 90, 160), {
			collide = false,
			material = Enum.Material.Neon,
			transparency = 0.6,
		})
	Build.sign(model, {
		name = "BaySign",
		size = Vector3.new(0.1, 1, 3),
		cf = L(-halfW + 0.55, 4.6, BusBuilder.MiddleDoorZ),
		color = Color3.fromRGB(40, 90, 160),
		collide = false,
		group = "Bus",
	}, "PRIORITY / RECOVERY", Enum.NormalId.Right)

	-- Hold button by the middle door
	local holdButton =
		P("HoldButton", Vector3.new(0.4, 1, 1), L(halfW - 0.6, 4.4, md1 + 0.9), Color3.fromRGB(250, 210, 30), {
			material = Enum.Material.Neon,
			collide = false,
		})
	Build.sign(model, {
		name = "HoldLabel",
		size = Vector3.new(0.1, 0.5, 1.6),
		cf = L(halfW - 0.55, 5.3, md1 + 0.9),
		color = C.Black,
		collide = false,
		group = "Bus",
	}, "HOLD", Enum.NormalId.Left, Color3.fromRGB(250, 210, 30))

	-- Lost & Found bin behind the front door
	local lostAndFound =
		P("LostAndFound", Vector3.new(2, 2.4, 2), L(halfW - 1.4, 1.2, -13.6), Color3.fromRGB(90, 70, 40), {
			material = Enum.Material.Wood,
		})
	Build.sign(model, {
		name = "LostAndFoundLabel",
		size = Vector3.new(1.8, 0.5, 0.1),
		cf = lostAndFound.CFrame * CFrame.new(0, 0.6, 1.02) * CFrame.Angles(0, math.pi, 0),
		color = Color3.fromRGB(90, 70, 40),
		collide = false,
		group = "Bus",
	}, "LOST & FOUND", Enum.NormalId.Back)

	-- Stop-request cords along both window lines, in segments (each has a prompt).
	local cords: { BasePart } = {}
	for side = -1, 1, 2 do
		for i = 0, 4 do
			local z = -18 + i * 10
			local cord =
				P("Cord", Vector3.new(0.15, 0.15, 9), L(side * (halfW - 0.7), 9.1, z), Color3.fromRGB(220, 200, 60), {
					collide = false,
					material = Enum.Material.Fabric,
				})
			table.insert(cords, cord)
		end
	end

	-- Lights: three banks of fluorescent tubes, front, middle and rear.
	local lightBanks: { { Light } } = { {}, {}, {} }
	local lightTubes: { BasePart } = {}
	local bankZ = { { -20, -14, -8 }, { -2, 4, 10 }, { 16, 22 } }
	for bank, zs in bankZ do
		for _, z in zs do
			for side = -1, 1, 2 do
				local tube =
					P("LightTube", Vector3.new(0.6, 0.25, 4.5), L(side * 2.4, BusBuilder.Height - 0.35, z), C.Fluor, {
						material = Enum.Material.Neon,
						collide = false,
						attrs = { Bank = bank },
					})
				table.insert(lightTubes, tube)
			end
			local holder = P("LightHolder", Vector3.new(0.2, 0.2, 0.2), L(0, BusBuilder.Height - 0.6, z), C.Fluor, {
				transparency = 1,
				collide = false,
				attrs = { Bank = bank },
			})
			local light = Build.light(holder, "Point", C.Fluor, 1.1, 18, false)
			light:SetAttribute("Bank", bank)
			table.insert(lightBanks[bank], light)
		end
	end

	-- Ad panels: twelve along the top of the walls, six per side.
	local adPanels: { BasePart } = {}
	for i = 1, 12 do
		local side = if i <= 6 then -1 else 1
		local idx = ((i - 1) % 6)
		local z = -16 + idx * 7.4
		local panel, _ = Build.sign(model, {
			name = "AdPanel",
			size = Vector3.new(0.1, 1.5, 5.4),
			cf = L(side * (halfW - 0.55), 9.9, z) * CFrame.Angles(0, 0, side * math.rad(-20)),
			color = Color3.fromRGB(240, 238, 230),
			collide = false,
			group = "Bus",
			attrs = { AdIndex = i },
		}, adText(i), if side == -1 then Enum.NormalId.Right else Enum.NormalId.Left, Color3.fromRGB(30, 40, 60))
		table.insert(adPanels, panel)
	end

	local paSpeaker = P("PASpeaker", Vector3.new(1.2, 0.3, 1.2), L(0, BusBuilder.Height - 0.25, -12), C.DarkMetal, {
		collide = false,
		shape = Enum.PartType.Cylinder,
	})
	paSpeaker.Size = Vector3.new(0.3, 1.2, 1.2)
	paSpeaker.CFrame = L(0, BusBuilder.Height - 0.25, -12) * CFrame.Angles(0, 0, math.pi / 2)

	-- Exterior fuel cap on the left rear corner (street side).
	local fuelCap = P("FuelCap", Vector3.new(0.4, 1.2, 1.2), L(-halfW - 0.15, 2.6, halfL - 4), C.DarkMetal, {
		material = Enum.Material.Metal,
	})
	Build.sign(model, {
		name = "FuelLabel",
		size = Vector3.new(0.1, 0.5, 1.6),
		cf = L(-halfW - 0.05, 3.8, halfL - 4),
		color = body,
		collide = false,
		group = "Bus",
	}, "DIESEL", Enum.NormalId.Left, C.Black)

	-- Handrails (poles), so the cabin reads as a bus.
	for _, z in { -17, -8, 5, 13, 21 } do
		for _, x in { -2.3, 2.3 } do
			P(
				"Pole",
				Vector3.new(0.25, BusBuilder.Height, 0.25),
				L(x, BusBuilder.Height / 2, z),
				Color3.fromRGB(220, 200, 60),
				{
					collide = false,
					material = Enum.Material.Metal,
					shape = Enum.PartType.Cylinder,
				}
			).CFrame = L(
				x,
				BusBuilder.Height / 2,
				z
			) * CFrame.Angles(0, 0, math.pi / 2)
		end
	end

	-- Weld everything to the floor. Doors use Weld (C0 animates them); the rest uses
	-- WeldConstraint.
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			if d:GetAttribute("DoorLeaf") then
				local weld = Instance.new("Weld")
				weld.Name = "DoorWeld"
				weld.Part0 = root
				weld.Part1 = d
				weld.C0 = root.CFrame:ToObjectSpace(d.CFrame)
				weld.C1 = CFrame.identity
				weld.Parent = d
				table.insert(doorWelds, weld)
			else
				Build.weld(root, d)
			end
		end
	end

	model:SetAttribute("HCTA", "Unit 9")

	return {
		model = model,
		root = root,
		interior = interior,
		mirror = mirror,
		routeBoard = routeBoard,
		rulesPlaque = rulesPlaque,
		dashboard = dashboard,
		patienceLight = patienceLight,
		frontDoor = frontDoor,
		middleDoor = middleDoor,
		doorWelds = doorWelds,
		seats = seats,
		backRowSeats = backRowSeats,
		driverSeat = driverSeat,
		lightBanks = lightBanks,
		lightTubes = lightTubes,
		adPanels = adPanels,
		cords = cords,
		fuelCap = fuelCap,
		lostAndFound = lostAndFound,
		holdButton = holdButton,
		recoveryBay = recoveryBay,
		fragmentSlots = fragmentSlots,
		voteButtons = voteButtons,
		rearWindow = rearWindow,
		paSpeaker = paSpeaker,
		extraRow = extraRow,
		driverModel = driverModel,
		headlights = headlights,
		fareBox = fareBox,
	}
end

return BusBuilder
