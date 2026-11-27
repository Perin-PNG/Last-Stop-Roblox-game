--!strict
-- The Terminal. The end of Route 9N: a vast bus depot with its power out, bays of
-- sleeping buses, and the exit gate across the road ahead, shut. FinaleService runs it;
-- this builder only lays it out and hands over the pieces in refs.extras:
--   breakers   { BasePart }   the three breaker boxes (prompts are added by the finale)
--   hallLights { Light }      the depot lights, off until the power is back
--   emergency  { Light }      red emergency lights, on until the power is back
--   gate       BasePart       the exit gate across the road (slides up when it opens)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StopKit = require(script.Parent.Parent:WaitForChild("StopKit"))
local Props = require(script.Parent.Parent:WaitForChild("Props"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Build = require(Shared.Util.Build)

local C = Build.Colors

local HALL_X0, HALL_X1 = 18, 150
local HALL_Z0, HALL_Z1 = -84, 84
local HALL_H = 28
local GATE_Z = -128
local WALL = Color3.fromRGB(86, 88, 92)

return function(parent: Instance, frame: CFrame, ctx: StopKit.Ctx, title: string): StopKit.StopRefs
	local refs = StopKit.new(ctx.id, parent, frame)
	StopKit.lot(refs, HALL_X1 + 6, -150, 100, Color3.fromRGB(52, 52, 54), Enum.Material.Concrete)
	StopKit.sidewalk(refs, -150, 100)
	StopKit.shelter(refs, title)
	refs.passengerSpot = StopKit.marker(refs, "PassengerSpot", CFrame.new(6, 3, -2))

	local hallLights: { Light } = {}
	local emergency: { Light } = {}
	local hall = Build.model(refs.model, "Depot")
	local cx, cz = (HALL_X0 + HALL_X1) / 2, (HALL_Z0 + HALL_Z1) / 2
	local w, d = HALL_X1 - HALL_X0, HALL_Z1 - HALL_Z0

	-- The shell: back wall, two side walls, a roof, and a front of tall open bay doors.
	StopKit.part(refs, {
		name = "BackWall",
		size = Vector3.new(1.5, HALL_H, d),
		cf = CFrame.new(HALL_X1, HALL_H / 2, cz),
		color = WALL,
		material = Enum.Material.Concrete,
	}, hall)
	for _, z in { HALL_Z0, HALL_Z1 } do
		StopKit.part(refs, {
			name = "SideWall",
			size = Vector3.new(w, HALL_H, 1.5),
			cf = CFrame.new(cx, HALL_H / 2, z),
			color = WALL,
			material = Enum.Material.Concrete,
		}, hall)
	end
	StopKit.part(refs, {
		name = "Roof",
		size = Vector3.new(w + 2, 1.5, d + 2),
		cf = CFrame.new(cx, HALL_H + 0.75, cz),
		color = Color3.fromRGB(40, 40, 44),
		material = Enum.Material.Metal,
	}, hall)
	-- Front: piers between six bay doors, the doors rolled up, a header over them all.
	for z = HALL_Z0, HALL_Z1, 28 do
		StopKit.part(refs, {
			name = "Pier",
			size = Vector3.new(2, HALL_H, 4),
			cf = CFrame.new(HALL_X0, HALL_H / 2, z),
			color = WALL,
			material = Enum.Material.Concrete,
		}, hall)
	end
	StopKit.part(refs, {
		name = "Header",
		size = Vector3.new(2, HALL_H - 16, d),
		cf = CFrame.new(HALL_X0, 16 + (HALL_H - 16) / 2, cz),
		color = WALL,
		material = Enum.Material.Concrete,
	}, hall)
	local _, nameLabel = StopKit.sign(refs, {
		name = "DepotName",
		size = Vector3.new(0.4, 4, 50),
		cf = CFrame.new(HALL_X0 - 1.2, HALL_H - 4, 0),
		color = Color3.fromRGB(20, 22, 30),
		collide = false,
	}, "HCTA CENTRAL TERMINAL", Enum.NormalId.Left, Color3.fromRGB(230, 200, 120), hall)
	nameLabel.Font = Enum.Font.GothamBlack
	local indoor = StopKit.part(refs, {
		name = "IndoorZone",
		size = Vector3.new(w, HALL_H, d),
		cf = CFrame.new(cx, HALL_H / 2, cz),
		transparency = 1,
		collide = false,
		query = false,
	}, hall)
	indoor:SetAttribute("Indoor", "Depot")
	table.insert(refs.interior, indoor)

	-- Lights: tall sodium bays (off) and red emergency lamps on the piers (on).
	for x = 36, 136, 25 do
		for z = -66, 66, 33 do
			local fixture = StopKit.part(refs, {
				name = "BayLight",
				size = Vector3.new(3, 0.6, 3),
				cf = CFrame.new(x, HALL_H - 1, z),
				color = Color3.fromRGB(60, 60, 60),
				material = Enum.Material.Metal,
				collide = false,
			}, hall)
			local l = Build.light(fixture, "Point", Color3.fromRGB(255, 210, 150), 1.6, 40, false)
			l.Enabled = false
			table.insert(hallLights, l)
		end
	end
	for _, p in
		{
			Vector3.new(HALL_X0 + 2, 12, -56),
			Vector3.new(HALL_X0 + 2, 12, 56),
			Vector3.new(HALL_X1 - 2, 12, 0),
			Vector3.new(84, 12, HALL_Z0 + 2),
			Vector3.new(84, 12, HALL_Z1 - 2),
		}
	do
		local lamp = StopKit.part(refs, {
			name = "EmergencyLamp",
			size = Vector3.new(1, 1, 1),
			cf = CFrame.new(p),
			color = Color3.fromRGB(255, 40, 30),
			material = Enum.Material.Neon,
			collide = false,
		}, hall)
		table.insert(emergency, Build.light(lamp, "Point", Color3.fromRGB(255, 40, 30), 1.2, 30, false))
	end

	-- Bays: painted lanes and the sleeping fleet, lights off, nobody at the wheel.
	local fleet = Build.model(hall, "Fleet")
	for i, z in { -56, -28, 0, 28, 56 } do
		StopKit.part(refs, {
			name = "BayLine",
			size = Vector3.new(110, 0.05, 0.4),
			cf = CFrame.new(84, 0.42, z + 14),
			color = Color3.fromRGB(220, 200, 90),
			collide = false,
		}, hall)
		local _, num = StopKit.sign(refs, {
			name = "BayNumber",
			size = Vector3.new(0.3, 3, 4),
			cf = CFrame.new(HALL_X1 - 1, 10, z),
			color = C.Black,
			collide = false,
		}, "BAY " .. i, Enum.NormalId.Left, C.White, hall)
		num.Font = Enum.Font.GothamBlack
		if i ~= 3 then
			-- A parked bus, nose to the back wall.
			local bus = Build.model(fleet, "ParkedBus")
			StopKit.part(refs, {
				name = "Body",
				size = Vector3.new(9.6, 9.4, 40),
				cf = CFrame.new(120, 5.2, z) * CFrame.Angles(0, math.rad(90), 0),
				color = Color3.fromRGB(210, 200, 170),
				material = Enum.Material.SmoothPlastic,
			}, bus)
			StopKit.part(refs, {
				name = "Stripe",
				size = Vector3.new(9.7, 1, 40.1),
				cf = CFrame.new(120, 4.6, z) * CFrame.Angles(0, math.rad(90), 0),
				color = Color3.fromRGB(140, 30, 30),
				collide = false,
			}, bus)
			StopKit.part(refs, {
				name = "Windows",
				size = Vector3.new(9.8, 3, 34),
				cf = CFrame.new(120, 7.6, z) * CFrame.Angles(0, math.rad(90), 0),
				color = Color3.fromRGB(14, 16, 20),
				material = Enum.Material.Glass,
				collide = false,
			}, bus)
			StopKit.lootPoint(refs, Vector3.new(96, 1.4, z + 6), if i % 2 == 0 then "fuel" else nil)
			StopKit.hidingSpot(refs, CFrame.new(96, 2, z - 6))
		end
	end
	StopKit.slot(refs, "fleet", fleet)

	-- Three breaker boxes, far apart: by the north wall, the back wall, the south wall.
	local breakers: { BasePart } = {}
	for i, p in
		{
			Vector3.new(40, 4.5, HALL_Z0 + 1.6),
			Vector3.new(HALL_X1 - 1.6, 4.5, 30),
			Vector3.new(70, 4.5, HALL_Z1 - 1.6),
		}
	do
		local box = StopKit.part(refs, {
			name = "Breaker" .. i,
			size = Vector3.new(3, 4, 3),
			cf = CFrame.new(p),
			color = Color3.fromRGB(70, 80, 70),
			material = Enum.Material.Metal,
		}, hall)
		box:SetAttribute("Breaker", i)
		local _, lab = StopKit.sign(refs, {
			name = "BreakerLabel",
			size = Vector3.new(3.1, 0.8, 3.1),
			cf = CFrame.new(p + Vector3.new(0, 2.6, 0)),
			color = Color3.fromRGB(230, 200, 40),
			collide = false,
		}, "MAIN " .. i, Enum.NormalId.Top, C.Black, hall)
		lab.Font = Enum.Font.GothamBlack
		local lamp = StopKit.part(refs, {
			name = "BreakerLamp",
			size = Vector3.new(0.5, 0.5, 0.5),
			cf = CFrame.new(p + Vector3.new(0, 1.4, 0)),
			color = Color3.fromRGB(255, 40, 30),
			material = Enum.Material.Neon,
			collide = false,
			shape = Enum.PartType.Ball,
		}, hall)
		lamp.Name = "Lamp" .. i
		table.insert(breakers, box)
	end

	-- The dispatch office in the corner, with the timetable that has no last bus.
	local office = StopKit.building(refs, "Dispatch", Vector3.new(34, 6, 66), Vector3.new(20, 12, 24), C.Siding, 6, 66)
	Props.counter(refs, CFrame.new(40, 0.4, 66), Vector3.new(3, 3.6, 10), nil, nil, office)
	Props.locker(refs, CFrame.new(42, 0.4, 74), Color3.fromRGB(90, 100, 120), office)
	StopKit.lootPoint(refs, Vector3.new(40, 4.2, 63), "flare")
	StopKit.lootPoint(refs, Vector3.new(30, 1.4, 58), "fuel")
	StopKit.lore(refs, "terminal_schedule", CFrame.new(43.4, 6, 60), true)
	StopKit.lootPoint(refs, Vector3.new(26, 1.4, -70), "fuel")
	StopKit.lootPoint(refs, Vector3.new(140, 1.4, -70), "flare")
	StopKit.lootPoint(refs, Vector3.new(140, 1.4, 74), "fuel")
	StopKit.lootPoint(refs, Vector3.new(84, 1.4, 0), "flare")

	-- The exit gate across the road ahead, on tall posts, with floodlights.
	local gateModel = Build.model(refs.model, "ExitGate")
	for _, x in { -42, 2 } do
		StopKit.part(refs, {
			name = "GatePost",
			size = Vector3.new(2, 22, 2),
			cf = CFrame.new(x, 11, GATE_Z),
			color = Color3.fromRGB(60, 60, 64),
			material = Enum.Material.Metal,
		}, gateModel)
	end
	StopKit.part(refs, {
		name = "GateBeam",
		size = Vector3.new(46, 2, 2),
		cf = CFrame.new(-20, 22, GATE_Z),
		color = Color3.fromRGB(60, 60, 64),
		material = Enum.Material.Metal,
	}, gateModel)
	local gate = StopKit.part(refs, {
		name = "Gate",
		size = Vector3.new(42, 18, 0.6),
		cf = CFrame.new(-20, 9.2, GATE_Z),
		color = Color3.fromRGB(150, 140, 90),
		material = Enum.Material.DiamondPlate,
	}, gateModel)
	local _, exitLabel = StopKit.sign(refs, {
		name = "ExitSign",
		size = Vector3.new(16, 2.4, 0.3),
		cf = CFrame.new(-20, 19.5, GATE_Z + 0.5),
		color = Color3.fromRGB(10, 10, 12),
		collide = false,
	}, "EXIT", Enum.NormalId.Back, Color3.fromRGB(255, 60, 40), gateModel)
	exitLabel.Font = Enum.Font.GothamBlack

	refs.extras.breakers = breakers
	refs.extras.hallLights = hallLights
	refs.extras.emergency = emergency
	refs.extras.gate = gate

	-- Spawns for the roaming threats: deep in the hall, away from the bus.
	StopKit.entitySpawn(refs, CFrame.new(130, 3, -60))
	StopKit.entitySpawn(refs, CFrame.new(130, 3, 60))
	StopKit.entitySpawn(refs, CFrame.new(100, 3, 0))
	StopKit.trailhead(refs, CFrame.new(HALL_X1 + 3, 0, 90))
	StopKit.backEntrance(refs, CFrame.new(HALL_X1 + 3, 3, -90))
	return refs
end
