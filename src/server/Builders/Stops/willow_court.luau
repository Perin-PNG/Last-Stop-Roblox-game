--!strict
-- Willow Court: a small cul-de-sac of four houses around a dead lawn. The Neighbor (a
-- Sentry) watches the court from one lit window; its cone shows as light on the grass.
-- Stand in it for two seconds and it comes out after you, until you get inside a house
-- and shut the door. The one house with a light on inside holds the fragment.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StopKit = require(script.Parent.Parent:WaitForChild("StopKit"))
local Props = require(script.Parent.Parent:WaitForChild("Props"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Build = require(Shared.Util.Build)

local C = Build.Colors

type House = {
	centre: Vector3,
	size: Vector3,
	color: Color3,
	number: string,
	surname: string,
}

local HOUSES: { House } = {
	{
		centre = Vector3.new(52, 6, -46),
		size = Vector3.new(24, 12, 20),
		color = Color3.fromRGB(140, 150, 140),
		number = "12",
		surname = "HALE",
	},
	{
		centre = Vector3.new(88, 6, -20),
		size = Vector3.new(24, 12, 22),
		color = Color3.fromRGB(150, 130, 110),
		number = "14",
		surname = "ORTIZ",
	},
	{
		centre = Vector3.new(88, 6, 22),
		size = Vector3.new(24, 12, 22),
		color = Color3.fromRGB(120, 130, 150),
		number = "16",
		surname = "BRANNIGAN",
	},
	{
		centre = Vector3.new(52, 6, 48),
		size = Vector3.new(24, 12, 20),
		color = Color3.fromRGB(160, 150, 120),
		number = "18",
		surname = "WU",
	},
}

local function gable(refs: StopKit.StopRefs, h: House, parent: Instance)
	local c, s = h.centre, h.size
	for _, side in { -1, 1 } do
		StopKit.wedge(refs, {
			name = "RoofSlope",
			size = Vector3.new(s.X + 2, 5, s.Z / 2 + 1),
			cf = CFrame.new(c.X, c.Y + s.Y / 2 + 3.5, c.Z + side * (s.Z / 4 + 0.5))
				* CFrame.Angles(0, if side > 0 then 0 else math.rad(180), 0),
			color = Color3.fromRGB(56, 44, 40),
			material = Enum.Material.Slate,
		}, parent)
	end
end

return function(parent: Instance, frame: CFrame, ctx: StopKit.Ctx, title: string): StopKit.StopRefs
	local refs = StopKit.new(ctx.id, parent, frame)
	StopKit.lot(refs, 112, -72, 72, C.Grass, Enum.Material.Grass)
	StopKit.sidewalk(refs, -72, 72)
	StopKit.shelter(refs, title)
	StopKit.approachLights(refs)
	refs.passengerSpot = StopKit.marker(refs, "PassengerSpot", CFrame.new(6, 3, -2))
	-- The court's own street: a loop of asphalt in front of the houses.
	StopKit.part(refs, {
		name = "CourtRoad",
		size = Vector3.new(30, 0.2, 18),
		cf = CFrame.new(25, 0.55, 0),
		color = C.Asphalt,
		material = Enum.Material.Asphalt,
	})
	local circle = StopKit.part(refs, {
		name = "Turnaround",
		size = Vector3.new(0.2, 52, 52),
		cf = CFrame.new(62, 0.55, 0) * CFrame.Angles(0, 0, math.rad(90)),
		color = C.Asphalt,
		material = Enum.Material.Asphalt,
	})
	circle.Shape = Enum.PartType.Cylinder
	StopKit.part(refs, {
		name = "Lawn",
		size = Vector3.new(0.2, 24, 24),
		cf = CFrame.new(62, 0.6, 0) * CFrame.Angles(0, 0, math.rad(90)),
		color = Color3.fromRGB(44, 52, 34),
		material = Enum.Material.Grass,
		shape = Enum.PartType.Cylinder,
	})

	local rng = ctx.rng:child("willow")
	local order = rng:shuffle({ 1, 2, 3, 4 })
	local neighborHouse = order[1]
	local fragmentHouse = order[2]
	local numbers = Build.model(refs.model, "HouseNumbers")
	local mailboxes = Build.model(refs.model, "Mailboxes")
	local porchSlot: Instance? = nil
	local sentrySpawns: { CFrame } = {}

	for i, h in HOUSES do
		local hm = StopKit.building(refs, "House" .. i, h.centre, h.size, h.color, 5, h.centre.Z)
		for _, d in hm:GetChildren() do
			if d:IsA("BasePart") and (d.Name == "Wall" or d.Name == "Front" or d.Name == "Lintel") then
				d.Material = Enum.Material.WoodPlanks
			end
		end
		gable(refs, h, hm)
		local zone = refs.interior[#refs.interior]
		local front = h.centre.X - h.size.X / 2
		local floorY = h.centre.Y - h.size.Y / 2 + 0.4
		-- Door: inside with it shut, the Neighbor loses you.
		local door = Props.door(refs, CFrame.new(front, floorY - 0.4, h.centre.Z), 5, 9, Color3.fromRGB(90, 40, 36), hm)
		zone:SetAttribute("Shelter", true)
		door.changed.Event:Connect(function(open: boolean)
			zone:SetAttribute("Shelter", not open)
		end)
		-- Porch, light and number.
		StopKit.part(refs, {
			name = "Porch",
			size = Vector3.new(5, 0.6, 10),
			cf = CFrame.new(front - 2.5, 0.8, h.centre.Z),
			color = C.Wood,
			material = Enum.Material.WoodPlanks,
		}, hm)
		local porch = StopKit.part(refs, {
			name = "PorchLight",
			size = Vector3.new(0.6, 0.8, 0.6),
			cf = CFrame.new(front - 0.5, 10, h.centre.Z + 3.6),
			color = C.Warm,
			material = Enum.Material.Neon,
			collide = false,
		}, hm)
		Build.light(porch, "Point", C.Warm, 0.9, 14, false)
		if i == neighborHouse then
			porchSlot = porch
		end
		StopKit.sign(refs, {
			name = "Number",
			size = Vector3.new(0.2, 1.2, 1.8),
			cf = CFrame.new(front - 0.6, 10, h.centre.Z - 3.6),
			color = C.Black,
			collide = false,
		}, h.number, Enum.NormalId.Left, Color3.fromRGB(230, 220, 190), numbers)
		-- Front windows. The Neighbor's house has one lit, with its cone on the lawn.
		for k, dz in { -6.5, 6.5 } do
			local lit = (i == neighborHouse and k == 1) or (i == fragmentHouse and k == 2)
			local pane = Props.window(refs, CFrame.new(front - 0.6, 6.5, h.centre.Z + dz), Vector2.new(4, 4), lit, hm)
			if i == neighborHouse and k == 1 then
				local beam = Instance.new("SpotLight")
				beam.Face = Enum.NormalId.Left
				beam.Angle = 60
				beam.Range = 40
				beam.Brightness = 2.2
				beam.Color = Color3.fromRGB(255, 225, 170)
				beam.Shadows = true
				beam.Parent = pane
				table.insert(
					sentrySpawns,
					1,
					CFrame.new(front + 2, floorY + 3, h.centre.Z + dz) * CFrame.Angles(0, math.rad(90), 0)
				)
			end
		end
		-- Inside: a bed, a table, a fridge, and loot.
		local back = h.centre.X + h.size.X / 2
		Props.bed(refs, CFrame.new(back - 4, floorY, h.centre.Z - h.size.Z / 2 + 5.5), nil, hm)
		Props.table(refs, CFrame.new(h.centre.X, floorY, h.centre.Z + h.size.Z / 2 - 5), Vector3.new(4, 3, 4), nil, hm)
		local fridge = StopKit.part(refs, {
			name = "Fridge",
			size = Vector3.new(3, 7, 3),
			cf = CFrame.new(back - 2.5, floorY + 3.5, h.centre.Z + h.size.Z / 2 - 3),
			color = Color3.fromRGB(220, 220, 214),
			material = Enum.Material.Metal,
		}, hm)
		if i == fragmentHouse then
			StopKit.ceilingLight(
				refs,
				Vector3.new(h.centre.X, h.centre.Y + h.size.Y / 2 - 0.8, h.centre.Z),
				C.Warm,
				22,
				hm
			)
			StopKit.fragmentSite(refs, Vector3.new(h.centre.X, floorY + 3.6, h.centre.Z + h.size.Z / 2 - 5))
		else
			StopKit.lootPoint(refs, Vector3.new(h.centre.X, floorY + 3.6, h.centre.Z + h.size.Z / 2 - 5))
		end
		if i == order[3] then
			local glow = Build.light(fridge, "Surface", Color3.fromRGB(220, 240, 255), 1.4, 10, false) :: SurfaceLight
			glow.Face = Enum.NormalId.Left
			glow.Enabled = false
			StopKit.slot(refs, "fridge", fridge)
		end
		StopKit.lootPoint(refs, Vector3.new(back - 4, floorY + 3, h.centre.Z - h.size.Z / 2 + 5.5))
		StopKit.lootPoint(refs, Vector3.new(back - 2.5, floorY + 1, h.centre.Z + h.size.Z / 2 - 6))
		StopKit.hidingSpot(refs, CFrame.new(back - 4, floorY + 2, h.centre.Z - h.size.Z / 2 + 10))
		-- Mailbox at the sidewalk.
		local mz = -24 + i * 10
		StopKit.part(refs, {
			name = "MailPost",
			size = Vector3.new(0.4, 3.6, 0.4),
			cf = CFrame.new(12, 2.2, mz),
			color = C.Wood,
			material = Enum.Material.Wood,
		}, mailboxes)
		StopKit.sign(refs, {
			name = "Mailbox",
			size = Vector3.new(1.8, 1.2, 1.2),
			cf = CFrame.new(12, 4.4, mz),
			color = Color3.fromRGB(40, 40, 44),
			material = Enum.Material.Metal,
		}, h.surname, Enum.NormalId.Left, C.White, mailboxes)
	end
	if porchSlot then
		StopKit.slot(refs, "porch", porchSlot)
	end
	StopKit.slot(refs, "house_numbers", numbers)
	StopKit.slot(refs, "mailboxes", mailboxes)
	for _, cf in sentrySpawns do
		StopKit.entitySpawn(refs, cf)
	end

	-- The lawn: a dead tree with a tire swing, a parked car that may idle by itself.
	Props.tree(refs, Vector3.new(62, 0.5, -6), 26)
	local swing = Build.model(refs.model, "Swing")
	local rope = StopKit.part(refs, {
		name = "Rope",
		size = Vector3.new(0.2, 9, 0.2),
		cf = CFrame.new(62, 13.5, -1),
		color = Color3.fromRGB(140, 120, 90),
		material = Enum.Material.Fabric,
		collide = false,
	}, swing)
	local tire = StopKit.part(refs, {
		name = "Tire",
		size = Vector3.new(1, 3.6, 3.6),
		cf = CFrame.new(62, 8.5, -1) * CFrame.Angles(0, math.rad(90), 0),
		color = C.Black,
		material = Enum.Material.Rubber,
		shape = Enum.PartType.Cylinder,
	}, swing)
	local _ = tire
	swing.PrimaryPart = rope
	StopKit.slot(refs, "swing", swing)
	local swingPivot = swing:GetPivot() * CFrame.new(0, 4.5, 0)

	local car = StopKit.car(refs, "DrivewayCar", CFrame.new(70, 0.5, -36), Color3.fromRGB(90, 30, 30))
	for _, part in car:GetChildren() do
		if part:IsA("BasePart") and part.Name == "Headlight" then
			local beam = Instance.new("SpotLight")
			beam.Face = Enum.NormalId.Front
			beam.Angle = 45
			beam.Range = 50
			beam.Brightness = 4
			beam.Enabled = false
			beam.Parent = part
		end
	end
	StopKit.slot(refs, "car", car)
	StopKit.hidingSpot(refs, CFrame.new(63, 3, -36))

	-- Hedges and fences close the court in.
	Props.fence(refs, Vector3.new(104, 0.5, -70), Vector3.new(104, 0.5, 70))
	for _, z in { -64, 64 } do
		StopKit.part(refs, {
			name = "Hedge",
			size = Vector3.new(36, 5, 4),
			cf = CFrame.new(80, 3, z),
			color = Color3.fromRGB(30, 46, 30),
			material = Enum.Material.Grass,
		})
	end
	StopKit.lootPoint(refs, Vector3.new(66, 1.5, -40))
	StopKit.lootPoint(refs, Vector3.new(30, 1.5, 30))

	refs.extras.custom = {
		willow_swing = function(built: any)
			task.spawn(function()
				local t = 0
				while built.active ~= false and swing.Parent do
					t += 0.05
					swing:PivotTo(swingPivot * CFrame.Angles(0, 0, math.sin(t * 2.2) * 0.35) * CFrame.new(0, -4.5, 0))
					task.wait(0.05)
				end
			end)
		end,
	}

	StopKit.trailhead(refs, CFrame.new(108, 0, 56))
	StopKit.backEntrance(refs, CFrame.new(108, 3, -56))
	return refs
end
