--!strict
-- Tri-County Bus Depot. A waiting hall by the road and a long garage behind it with four
-- buses parked in their bays. The Mechanic works the garage: he patrols, listens, and
-- chases what he sees. Crouch beside a parked bus to hide. The diesel pump in the yard
-- gives fuel, but it's loud. The Driver's locker, number 9, is in the garage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StopKit = require(script.Parent.Parent:WaitForChild("StopKit"))
local Props = require(script.Parent.Parent:WaitForChild("Props"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Build = require(Shared.Util.Build)
local Net = require(Shared.Net)
local Registry = require(script.Parent.Parent.Parent:WaitForChild("Registry"))

local C = Build.Colors

local HALL_C = Vector3.new(30, 7, -34)
local HALL_S = Vector3.new(28, 14, 34)
local GARAGE_C = Vector3.new(80, 10, 12)
local GARAGE_S = Vector3.new(48, 20, 100)
local BAYS = { -22, -4, 14, 32 } -- z of each parked bus
local BRICK = Color3.fromRGB(150, 110, 90)

-- A parked transit bus, nose toward -X. `cf` is the floor point under its middle.
local function bus(refs: StopKit.StopRefs, name: string, cf: CFrame, color: Color3, dest: string): (Model, TextLabel)
	local m = Build.model(refs.model, name)
	local function piece(
		pname: string,
		size: Vector3,
		offset: Vector3,
		c: Color3,
		mat: Enum.Material?,
		collide: boolean?
	)
		return StopKit.part(refs, {
			name = pname,
			size = size,
			cf = cf * CFrame.new(offset),
			color = c,
			material = mat or Enum.Material.SmoothPlastic,
			collide = collide,
		}, m)
	end
	piece("Body", Vector3.new(30, 8, 8.4), Vector3.new(0, 5.4, 0), color, Enum.Material.SmoothPlastic)
	piece("Roof", Vector3.new(29, 0.6, 8), Vector3.new(0.5, 9.7, 0), Color3.fromRGB(200, 200, 200), nil, false)
	for _, side in { -1, 1 } do
		piece(
			"Windows",
			Vector3.new(24, 2.6, 0.1),
			Vector3.new(1.5, 7, side * 4.25),
			C.Glass,
			Enum.Material.Glass,
			false
		)
		piece(
			"Stripe",
			Vector3.new(30, 0.5, 0.1),
			Vector3.new(0, 4.4, side * 4.25),
			Color3.fromRGB(220, 200, 60),
			nil,
			false
		)
		for _, dx in { -10, 10 } do
			local w = piece(
				"Wheel",
				Vector3.new(1, 3.4, 3.4),
				Vector3.new(dx, 1.7, side * 3.9),
				C.Black,
				Enum.Material.Rubber,
				false
			)
			w.Shape = Enum.PartType.Cylinder
			w.CFrame = w.CFrame * CFrame.Angles(0, math.rad(90), 0)
		end
	end
	piece("Windshield", Vector3.new(0.1, 3.6, 7.6), Vector3.new(-15.05, 6.6, 0), C.Glass, Enum.Material.Glass, false)
	local head = piece("DestSign", Vector3.new(0.2, 1.2, 6), Vector3.new(-15.1, 8.9, 0), C.Black, nil, false)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Left
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = head
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Arcade
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 170, 40)
	label.Text = dest
	label.Parent = gui
	m.PrimaryPart = m:FindFirstChild("Body") :: BasePart?
	return m, label
end

return function(parent: Instance, frame: CFrame, ctx: StopKit.Ctx, title: string): StopKit.StopRefs
	local refs = StopKit.new(ctx.id, parent, frame)
	StopKit.basics(refs, title, 112, -70, 70)
	local gFront = GARAGE_C.X - GARAGE_S.X / 2
	local gBack = GARAGE_C.X + GARAGE_S.X / 2
	local gzMin = GARAGE_C.Z - GARAGE_S.Z / 2

	-- The waiting hall.
	local hall = StopKit.building(refs, "WaitingHall", HALL_C, HALL_S, BRICK, 7, -34)
	local hFront = HALL_C.X - HALL_S.X / 2
	local hBack = HALL_C.X + HALL_S.X / 2
	StopKit.sign(refs, {
		name = "DepotSign",
		size = Vector3.new(0.4, 2, 22),
		cf = CFrame.new(hFront - 0.4, 12, -34),
		color = Color3.fromRGB(30, 50, 90),
		collide = false,
	}, "TRI-COUNTY TRANSIT", Enum.NormalId.Left, C.White, hall)
	for _, z in { -46, -22 } do
		Props.window(refs, CFrame.new(hFront - 0.6, 6, z), Vector2.new(6, 4), z == -22)
	end
	StopKit.part(refs, {
		name = "Floor",
		size = Vector3.new(HALL_S.X - 2, 0.05, HALL_S.Z - 2),
		cf = CFrame.new(HALL_C.X, 0.45, HALL_C.Z),
		color = Color3.fromRGB(160, 150, 130),
		material = Enum.Material.Marble,
		collide = false,
	})
	for row = 0, 2 do
		StopKit.part(refs, {
			name = "Bench",
			size = Vector3.new(1.8, 1.8, 12),
			cf = CFrame.new(hFront + 8 + row * 5, 1.3, -38),
			color = C.Wood,
			material = Enum.Material.Wood,
		})
		StopKit.lootPoint(refs, Vector3.new(hFront + 8 + row * 5, 2.6, -42 + row * 3))
	end
	Props.counter(refs, CFrame.new(hBack - 4, 0.4, -40), Vector3.new(3, 3.8, 10), Color3.fromRGB(60, 70, 90))
	StopKit.hidingSpot(refs, CFrame.new(hBack - 2, 2, -40))
	StopKit.lootPoint(refs, Vector3.new(hBack - 4, 4.6, -43), "transfers")
	local board, boardLabel = StopKit.sign(
		refs,
		{
			name = "Departures",
			size = Vector3.new(0.4, 4, 12),
			cf = CFrame.new(hBack - 1.2, 9.5, -26),
			color = C.Black,
			collide = false,
		},
		"DEPARTURES\n14  RIVERSIDE  CANCELLED\n22  NORTHGATE  CANCELLED\n31  HOLLIS  CANCELLED",
		Enum.NormalId.Left,
		Color3.fromRGB(255, 170, 40),
		hall
	)
	boardLabel.Font = Enum.Font.Arcade
	StopKit.slot(refs, "departures", board)
	StopKit.ceilingLight(refs, Vector3.new(HALL_C.X, 13.2, -40), C.Fluor, 18, hall)
	StopKit.ceilingLight(refs, Vector3.new(HALL_C.X, 13.2, -26), C.Fluor, 18, hall)
	-- A corridor from the hall's back wall into the garage: the hall's back gets a doorway.
	for _, d in hall:GetChildren() do
		if d:IsA("BasePart") and d.Name == "Wall" and d.Size.Z > 30 then
			-- Split the back wall around a 5-wide doorway at z -24.
			local cf = d.CFrame
			local sz = d.Size
			local localCf = refs.frame:ToObjectSpace(cf)
			local z0, z1 = localCf.Position.Z - sz.Z / 2, localCf.Position.Z + sz.Z / 2
			d:Destroy()
			for _, span in { { z0, -26.5 }, { -21.5, z1 } } do
				StopKit.part(refs, {
					name = "Wall",
					size = Vector3.new(sz.X, sz.Y, span[2] - span[1]),
					cf = CFrame.new(localCf.Position.X, localCf.Position.Y, (span[1] + span[2]) / 2),
					color = BRICK,
					material = Enum.Material.Brick,
				}, hall)
			end
			StopKit.part(refs, {
				name = "Lintel",
				size = Vector3.new(sz.X, sz.Y - 9, 5),
				cf = CFrame.new(localCf.Position.X, 9 + (sz.Y - 9) / 2, -24),
				color = BRICK,
				material = Enum.Material.Brick,
			}, hall)
			break
		end
	end
	StopKit.part(refs, {
		name = "Passage",
		size = Vector3.new(gFront - hBack + 1, 0.4, 6),
		cf = CFrame.new((hBack + gFront) / 2, 0.6, -24),
		color = Color3.fromRGB(150, 145, 135),
		material = Enum.Material.Concrete,
	})

	-- The garage: tall corrugated walls, the big bay door left open, skylights, the buses.
	local garage = StopKit.building(refs, "Garage", GARAGE_C, GARAGE_S, Color3.fromRGB(120, 125, 130), 18, 30)
	for _, d in garage:GetChildren() do
		if d:IsA("BasePart") and (d.Name == "Wall" or d.Name == "Front" or d.Name == "Lintel") then
			d.Material = Enum.Material.CorrodedMetal
		end
	end
	-- Cut a doorway in the garage front wall for the passage.
	for _, d in garage:GetChildren() do
		if d:IsA("BasePart") and d.Name == "Front" then
			local localCf = refs.frame:ToObjectSpace(d.CFrame)
			local z0, z1 = localCf.Position.Z - d.Size.Z / 2, localCf.Position.Z + d.Size.Z / 2
			if z0 < -24 and z1 > -24 then
				local sz = d.Size
				d:Destroy()
				for _, span in { { z0, -26.5 }, { -21.5, z1 } } do
					StopKit.part(refs, {
						name = "Front",
						size = Vector3.new(sz.X, sz.Y, span[2] - span[1]),
						cf = CFrame.new(localCf.Position.X, localCf.Position.Y, (span[1] + span[2]) / 2),
						color = Color3.fromRGB(120, 125, 130),
						material = Enum.Material.CorrodedMetal,
					}, garage)
				end
				StopKit.part(refs, {
					name = "Lintel",
					size = Vector3.new(sz.X, sz.Y - 9, 5),
					cf = CFrame.new(localCf.Position.X, 9 + (sz.Y - 9) / 2, -24),
					color = Color3.fromRGB(120, 125, 130),
					material = Enum.Material.CorrodedMetal,
				}, garage)
				break
			end
		end
	end
	StopKit.part(refs, {
		name = "GarageFloor",
		size = Vector3.new(GARAGE_S.X - 2, 0.05, GARAGE_S.Z - 2),
		cf = CFrame.new(GARAGE_C.X, 0.45, GARAGE_C.Z),
		color = Color3.fromRGB(110, 110, 105),
		material = Enum.Material.Concrete,
		collide = false,
	})
	for z = gzMin + 10, gzMin + GARAGE_S.Z - 10, 16 do
		StopKit.ceilingLight(refs, Vector3.new(GARAGE_C.X, 19.2, z), Color3.fromRGB(210, 220, 200), 22, garage)
	end
	local colors = {
		Color3.fromRGB(230, 230, 225),
		Color3.fromRGB(200, 205, 210),
		Color3.fromRGB(225, 220, 200),
		Color3.fromRGB(210, 215, 215),
	}
	local dests = { "NOT IN SERVICE", "14 RIVERSIDE", "DEPOT", "22 NORTHGATE" }
	local bay4Sign: BasePart? = nil
	for i, z in BAYS do
		local m, label = bus(refs, "Bus" .. i, CFrame.new(GARAGE_C.X + 2, 0.45, z), colors[i], dests[i])
		StopKit.sign(refs, {
			name = "BayNumber",
			size = Vector3.new(0.2, 2.4, 2.4),
			cf = CFrame.new(gBack - 0.8, 12, z),
			color = Color3.fromRGB(220, 200, 60),
			collide = false,
		}, tostring(i), Enum.NormalId.Left, C.Black, garage)
		for _, side in { -1, 1 } do
			StopKit.hidingSpot(refs, CFrame.new(GARAGE_C.X - 6, 2, z + side * 5.4))
			StopKit.hidingSpot(refs, CFrame.new(GARAGE_C.X + 10, 2, z + side * 5.4))
		end
		StopKit.lootPoint(refs, Vector3.new(GARAGE_C.X - 8, 1.4, z + 6))
		if i == 4 then
			bay4Sign = label.Parent and (label.Parent :: Instance).Parent :: BasePart?
		end
		local _ = m
	end
	if bay4Sign then
		StopKit.slot(refs, "bay_bus", bay4Sign)
	end

	-- Workbenches and tool chests along the back wall.
	for k, z in { 40, 46, 52, 58 } do
		Props.counter(refs, CFrame.new(gBack - 3, 0.4, z), Vector3.new(3, 3.8, 5), Color3.fromRGB(150, 40, 30), nil)
		StopKit.lootPoint(refs, Vector3.new(gBack - 3, 4.6, z), if k == 1 then "flare" else nil)
	end
	StopKit.box(refs, "Tires", CFrame.new(gFront + 4, 2, 50), Vector3.new(3, 3.4, 3), C.Black, Enum.Material.Rubber)
	StopKit.box(
		refs,
		"Drums",
		CFrame.new(gFront + 4, 2.4, 44),
		Vector3.new(3, 4, 3),
		Color3.fromRGB(40, 90, 50),
		Enum.Material.Metal
	)
	StopKit.hidingSpot(refs, CFrame.new(gFront + 7, 2, 47))

	-- The lockers, and the Driver's locker: number 9.
	local lockers = Build.model(refs.model, "Lockers")
	local driverDoor: Model? = nil
	for n = 1, 10 do
		local z = gzMin + 4 + n * 2.7
		local cf = CFrame.new(gBack - 2.4, 0.4, z) * CFrame.Angles(0, 0, 0)
		local body = Props.locker(refs, cf, Color3.fromRGB(70, 90, 100), lockers)
		StopKit.sign(refs, {
			name = "LockerNo",
			size = Vector3.new(0.05, 0.4, 0.6),
			cf = cf * CFrame.new(-1.33, 7, 0),
			color = Color3.fromRGB(210, 210, 200),
			collide = false,
		}, tostring(n), Enum.NormalId.Left, C.Black, lockers)
		if n == 9 then
			local door = Build.model(lockers, "DriverLockerDoor")
			StopKit.part(refs, {
				name = "LockerDoor",
				size = Vector3.new(0.15, 7.2, 2.5),
				cf = cf * CFrame.new(-1.38, 3.75, 0),
				color = Color3.fromRGB(80, 100, 110),
				material = Enum.Material.Metal,
			}, door)
			door.WorldPivot = refs.frame * cf * CFrame.new(-1.38, 3.75, 1.25)
			StopKit.part(refs, {
				name = "Cap",
				size = Vector3.new(1.4, 0.5, 1.4),
				cf = cf * CFrame.new(0, 5.8, 0),
				color = Color3.fromRGB(30, 40, 70),
				collide = false,
			}, lockers)
			StopKit.lootPoint(refs, Vector3.new(gBack - 2.4, 1.6, z))
			driverDoor = door
		end
		local _ = body
	end
	if driverDoor then
		StopKit.slot(refs, "locker", driverDoor)
	end

	-- The diesel pump in the yard: hold to fill a can, and it's loud.
	local pumpCf = CFrame.new(gFront - 10, 0.4, 44)
	StopKit.part(refs, {
		name = "PumpPad",
		size = Vector3.new(6, 0.4, 6),
		cf = pumpCf * CFrame.new(0, 0.2, 0),
		color = Color3.fromRGB(150, 145, 135),
		material = Enum.Material.Concrete,
	})
	local pump = StopKit.part(refs, {
		name = "DieselPump",
		size = Vector3.new(2, 6, 2.6),
		cf = pumpCf * CFrame.new(0, 3.4, 0),
		color = Color3.fromRGB(40, 90, 50),
		material = Enum.Material.Metal,
	})
	StopKit.sign(refs, {
		name = "DieselLabel",
		size = Vector3.new(0.1, 1, 2.2),
		cf = pumpCf * CFrame.new(-1.05, 5, 0),
		color = Color3.fromRGB(230, 200, 40),
		collide = false,
	}, "DIESEL", Enum.NormalId.Left, C.Black)
	local pumpPrompt = Build.prompt(pump, "Fill a can", "Diesel pump", 4, 7, "PumpPrompt")

	-- The yard: fence, lamp, a broken-down bus outside.
	Props.fence(refs, Vector3.new(12, 0, 64), Vector3.new(104, 0, 64))
	Props.tree(refs, Vector3.new(16, 0.4, 10), 16)
	Props.tree(refs, Vector3.new(20, 0.4, 30), 20)
	StopKit.fragmentSite(refs, Vector3.new(gBack - 3, 4.6, 52))
	StopKit.entitySpawn(refs, CFrame.new(gBack - 8, 3, 6) * CFrame.Angles(0, math.rad(90), 0))
	StopKit.trailhead(refs, CFrame.new(108, 0, 66))
	StopKit.backEntrance(refs, CFrame.new(108, 3, -66))

	local token = 0
	refs.extras.activate = function(built: any)
		token += 1
		local mine = token
		local fills = 2 + (if ctx.tier >= 2 then 0 else 1)
		pumpPrompt.Enabled = true
		local conn: RBXScriptConnection? = nil
		conn = pumpPrompt.Triggered:Connect(function(player: Player)
			if mine ~= token then
				if conn then
					conn:Disconnect()
				end
				return
			end
			local PlayerState = Registry.find("PlayerStateService")
			if PlayerState and not PlayerState.isHealthy(player) then
				return
			end
			fills -= 1
			local Inventory = Registry.find("InventoryService")
			if Inventory then
				Inventory.spawnItem("fuel", refs.frame * pumpCf * CFrame.new(-2.4, 1.2, 0), built.refs.model)
			end
			Net.notifyAll("Sound", { key = "EngineRev", part = pump })
			local Noise = Registry.find("NoiseService")
			if Noise then
				Noise.post(pump.Position, 80, "pump", player)
			end
			if fills <= 0 then
				pumpPrompt.Enabled = false
				Net.notify(player, "Toast", { text = "The pump coughs and runs dry." })
				if conn then
					conn:Disconnect()
				end
			end
		end)
	end
	refs.extras.deactivate = function()
		token += 1
		pumpPrompt.Enabled = false
	end
	return refs
end
