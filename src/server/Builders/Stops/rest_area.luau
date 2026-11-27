--!strict
-- Pine Hollow Rest Area. A loop of parking around a wooded island, a restroom block, a
-- picnic pavilion and a single old fuel pump. Headlights is a car with no driver that
-- circles the lot. It runs down anyone caught in its beams, but it can't leave the
-- asphalt: the restrooms, the pavilion and the trees are safe.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StopKit = require(script.Parent.Parent:WaitForChild("StopKit"))
local Props = require(script.Parent.Parent:WaitForChild("Props"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Build = require(Shared.Util.Build)
local Registry = require(script.Parent.Parent.Parent:WaitForChild("Registry"))

local C = Build.Colors

local LOT_X0, LOT_X1 = 12, 70
local LOT_Z0, LOT_Z1 = -56, 56
local ASPHALT = Color3.fromRGB(45, 45, 48)
local CEDAR = Color3.fromRGB(120, 80, 55)

return function(parent: Instance, frame: CFrame, ctx: StopKit.Ctx, title: string): StopKit.StopRefs
	local refs = StopKit.new(ctx.id, parent, frame)
	StopKit.basics(refs, title, 116, -72, 72)

	-- The parking loop, its curbs, stripes and lamp posts.
	StopKit.part(refs, {
		name = "Asphalt",
		size = Vector3.new(LOT_X1 - LOT_X0, 0.1, LOT_Z1 - LOT_Z0),
		cf = CFrame.new((LOT_X0 + LOT_X1) / 2, 0.42, (LOT_Z0 + LOT_Z1) / 2),
		color = ASPHALT,
		material = Enum.Material.Asphalt,
	})
	local island = { x0 = 30, x1 = 52, z0 = -36, z1 = 36 }
	StopKit.part(refs, {
		name = "Island",
		size = Vector3.new(island.x1 - island.x0, 0.6, island.z1 - island.z0),
		cf = CFrame.new((island.x0 + island.x1) / 2, 0.7, 0),
		color = Color3.fromRGB(60, 75, 45),
		material = Enum.Material.Grass,
	})
	for z = -30, 30, 10 do
		Props.tree(refs, Vector3.new(36 + (z % 20) / 4, 1, z), 18 + (z % 3) * 3)
		Props.tree(refs, Vector3.new(46 - (z % 20) / 5, 1, z + 5), 20)
		StopKit.hidingSpot(refs, CFrame.new(41, 2, z + 2))
	end
	for z = LOT_Z0 + 8, LOT_Z1 - 8, 6 do
		for _, x in { LOT_X0 + 1, LOT_X1 - 1 } do
			StopKit.part(refs, {
				name = "Stripe",
				size = Vector3.new(6, 0.02, 0.3),
				cf = CFrame.new(x + (if x < 40 then 3 else -3), 0.48, z),
				color = C.White,
				collide = false,
			})
		end
	end
	for _, pos in { Vector3.new(26, 0, -50), Vector3.new(56, 0, -50), Vector3.new(26, 0, 50), Vector3.new(56, 0, 50) } do
		StopKit.part(refs, {
			name = "LotLampPost",
			size = Vector3.new(0.6, 18, 0.6),
			cf = CFrame.new(pos + Vector3.new(0, 9.4, 0)),
			color = C.Metal,
			material = Enum.Material.Metal,
		})
		local head = StopKit.part(refs, {
			name = "LotLamp",
			size = Vector3.new(2.4, 0.5, 1.2),
			cf = CFrame.new(pos + Vector3.new(0, 18.4, 0)),
			color = Color3.fromRGB(255, 200, 140),
			material = Enum.Material.Neon,
			collide = false,
		})
		local l = Build.light(head, "Spot", Color3.fromRGB(255, 190, 120), 1.6, 30, false) :: SpotLight
		l.Angle = 100
	end

	-- The restrooms: cedar block with a roof, stalls and sinks inside.
	local rr = StopKit.building(refs, "Restrooms", Vector3.new(92, 6, 0), Vector3.new(18, 12, 30), CEDAR, 6, 0)
	for _, d in rr:GetChildren() do
		if d:IsA("BasePart") and (d.Name == "Wall" or d.Name == "Front" or d.Name == "Lintel") then
			d.Material = Enum.Material.WoodPlanks
		end
	end
	for _, side in { -1, 1 } do
		StopKit.wedge(refs, {
			name = "RoofSlope",
			size = Vector3.new(34, 4, 11),
			cf = CFrame.new(92 + side * 5.5, 14, 0) * CFrame.Angles(0, math.rad(if side > 0 then 90 else -90), 0),
			color = Color3.fromRGB(60, 70, 55),
			material = Enum.Material.Slate,
		}, rr)
	end
	StopKit.sign(refs, {
		name = "RestroomSign",
		size = Vector3.new(0.3, 1.4, 8),
		cf = CFrame.new(82.6, 10, 0),
		color = Color3.fromRGB(40, 70, 50),
		collide = false,
	}, "RESTROOMS", Enum.NormalId.Left, C.White, rr)
	StopKit.part(refs, {
		name = "Partition",
		size = Vector3.new(16, 11, 0.4),
		cf = CFrame.new(92, 6, 0),
		color = Color3.fromRGB(170, 160, 140),
	}, rr)
	for _, sz in { -1, 1 } do
		for k = 0, 2 do
			local z = sz * (4 + k * 3.4)
			StopKit.part(refs, {
				name = "Stall",
				size = Vector3.new(5, 7, 0.2),
				cf = CFrame.new(97.5, 4, z + sz * 1.7),
				color = Color3.fromRGB(110, 120, 130),
				material = Enum.Material.Metal,
			}, rr)
			StopKit.hidingSpot(refs, CFrame.new(98.5, 2, z))
		end
		StopKit.part(refs, {
			name = "Sinks",
			size = Vector3.new(2, 3, 8),
			cf = CFrame.new(84.5, 2, sz * 9),
			color = Color3.fromRGB(220, 220, 215),
			material = Enum.Material.Marble,
		}, rr)
		StopKit.ceilingLight(refs, Vector3.new(90, 11.2, sz * 7), C.Fluor, 14, rr)
		StopKit.lootPoint(refs, Vector3.new(84.5, 3.8, sz * 11))
	end

	-- The vending machines under the restroom eave.
	local vend = StopKit.part(refs, {
		name = "Vending",
		size = Vector3.new(3, 7, 4),
		cf = CFrame.new(81, 3.9, -12),
		color = Color3.fromRGB(150, 30, 30),
		material = Enum.Material.SmoothPlastic,
	})
	local panel = StopKit.part(refs, {
		name = "VendGlass",
		size = Vector3.new(0.1, 4.4, 2.6),
		cf = CFrame.new(79.45, 4.8, -12.4),
		color = Color3.fromRGB(230, 240, 255),
		material = Enum.Material.Neon,
		collide = false,
	})
	Build.light(panel, "Point", Color3.fromRGB(220, 235, 255), 1, 10, false)
	StopKit.part(refs, {
		name = "Machine2",
		size = Vector3.new(3, 7, 4),
		cf = CFrame.new(81, 3.9, -17),
		color = Color3.fromRGB(30, 70, 150),
		material = Enum.Material.SmoothPlastic,
	})
	StopKit.lootPoint(refs, Vector3.new(79, 1.4, -14.5))
	local hand = Build.model(refs.model, "VendHand")
	StopKit.part(refs, {
		name = "Hand",
		size = Vector3.new(0.9, 0.4, 1.2),
		cf = CFrame.new(79.3, 1.6, -12),
		color = Color3.fromRGB(205, 195, 180),
		collide = false,
	}, hand)
	StopKit.setShown(hand, false)
	StopKit.slot(refs, "vending", vend, { vending_hand = hand :: Instance })

	-- The trail map board.
	for _, z in { -28.5, -21.5 } do
		StopKit.part(refs, {
			name = "BoardPost",
			size = Vector3.new(0.5, 7, 0.5),
			cf = CFrame.new(78, 3.9, z),
			color = CEDAR,
			material = Enum.Material.Wood,
		})
	end
	StopKit.sign(refs, {
		name = "MapTitle",
		size = Vector3.new(0.3, 1, 7),
		cf = CFrame.new(77.8, 7.6, -25),
		color = Color3.fromRGB(40, 70, 50),
		collide = false,
	}, "PINE HOLLOW TRAILS", Enum.NormalId.Left, C.White)
	local mapPart, mapLabel = StopKit.sign(refs, {
		name = "Map",
		size = Vector3.new(0.3, 3.6, 7),
		cf = CFrame.new(77.8, 5, -25),
		color = Color3.fromRGB(215, 205, 170),
		collide = false,
	}, "YOU ARE HERE", Enum.NormalId.Left, Color3.fromRGB(180, 30, 30))
	mapLabel.Font = Enum.Font.Garamond
	StopKit.slot(refs, "map_board", mapPart)

	-- The picnic pavilion.
	StopKit.part(refs, {
		name = "PavilionRoof",
		size = Vector3.new(22, 0.8, 22),
		cf = CFrame.new(94, 11, 38),
		color = Color3.fromRGB(60, 70, 55),
		material = Enum.Material.Slate,
	})
	for _, dx in { -10, 10 } do
		for _, dz in { -10, 10 } do
			StopKit.part(refs, {
				name = "PavilionPost",
				size = Vector3.new(0.8, 10.6, 0.8),
				cf = CFrame.new(94 + dx, 5.7, 38 + dz),
				color = CEDAR,
				material = Enum.Material.Wood,
			})
		end
	end
	StopKit.part(refs, {
		name = "PavilionSlab",
		size = Vector3.new(22, 0.3, 22),
		cf = CFrame.new(94, 0.55, 38),
		color = Color3.fromRGB(150, 145, 135),
		material = Enum.Material.Concrete,
	})
	local picnicSlot: Instance? = nil
	local food = Build.model(refs.model, "PicnicFood")
	for k, pos in
		{ Vector3.new(89, 0.7, 33), Vector3.new(99, 0.7, 33), Vector3.new(89, 0.7, 43), Vector3.new(99, 0.7, 43) }
	do
		local t = Props.table(refs, CFrame.new(pos), Vector3.new(4, 2.8, 7), CEDAR)
		for _, dx in { -3, 3 } do
			StopKit.part(refs, {
				name = "Bench",
				size = Vector3.new(1.4, 0.4, 7),
				cf = CFrame.new(pos + Vector3.new(dx, 1.6, 0)),
				color = CEDAR,
				material = Enum.Material.Wood,
			})
		end
		StopKit.hidingSpot(refs, CFrame.new(pos + Vector3.new(0, 1.5, 0)))
		if k == 3 then
			picnicSlot = t
			for j, c in { Color3.fromRGB(200, 60, 40), Color3.fromRGB(230, 200, 120), Color3.fromRGB(120, 160, 70) } do
				local plate = StopKit.part(refs, {
					name = "Plate",
					size = Vector3.new(0.15, 1.4, 1.4),
					cf = CFrame.new(pos + Vector3.new(0, 3.3, -2.4 + j * 1.6)),
					color = c,
					shape = Enum.PartType.Cylinder,
					collide = false,
				}, food)
				plate.CFrame = plate.CFrame * CFrame.Angles(0, 0, math.rad(90))
				local steam = Instance.new("ParticleEmitter")
				steam.Rate = 4
				steam.Lifetime = NumberRange.new(1.5, 2.5)
				steam.Speed = NumberRange.new(1, 2)
				steam.Transparency = NumberSequence.new(0.6, 1)
				steam.Size = NumberSequence.new(0.4, 1.2)
				steam.Color = ColorSequence.new(Color3.fromRGB(230, 230, 230))
				steam.Parent = plate
			end
		else
			StopKit.lootPoint(refs, pos + Vector3.new(0.5, 3.4, 1))
		end
	end
	if picnicSlot then
		StopKit.slot(refs, "picnic", picnicSlot, { rest_picnic = food :: Instance })
	end

	-- The fuel pump and the lure's can.
	local pumpCf = CFrame.new(20, 0.4, 52)
	StopKit.part(refs, {
		name = "PumpIsland",
		size = Vector3.new(4, 0.6, 8),
		cf = pumpCf * CFrame.new(0, 0.3, 0),
		color = Color3.fromRGB(170, 165, 150),
		material = Enum.Material.Concrete,
	})
	StopKit.part(refs, {
		name = "Pump",
		size = Vector3.new(2, 5.5, 3),
		cf = pumpCf * CFrame.new(0, 3.4, 0),
		color = Color3.fromRGB(190, 40, 30),
		material = Enum.Material.Metal,
	})
	StopKit.lootPoint(refs, pumpCf.Position + Vector3.new(-2.6, 1.4, 2), "fuel")
	local lureMarker = StopKit.marker(refs, "LureFuel", pumpCf * CFrame.new(-2.6, 1.4, -2.5))
	StopKit.slot(refs, "lure_fuel", lureMarker)

	-- A parked car facing the restrooms, high beams off.
	local car = StopKit.car(
		refs,
		"ParkedCar",
		CFrame.new(64, 0.5, 18) * CFrame.Angles(0, math.rad(-90), 0),
		Color3.fromRGB(70, 80, 70)
	)
	for _, part in car:GetChildren() do
		if part:IsA("BasePart") and part.Name == "Headlight" then
			local beam = Instance.new("SpotLight")
			beam.Face = Enum.NormalId.Front
			beam.Angle = 40
			beam.Range = 50
			beam.Brightness = 5
			beam.Enabled = false
			beam.Parent = part
		end
	end
	StopKit.slot(refs, "parked_car", car)
	StopKit.hidingSpot(refs, CFrame.new(64, 2, 24))
	StopKit.lootPoint(refs, Vector3.new(60, 1.4, 22))

	-- Trash cans, a dog walk sign, the fragment out on the trail edge.
	for _, pos in { Vector3.new(80, 0.4, 22), Vector3.new(80, 0.4, -34), Vector3.new(16, 0.4, -54) } do
		StopKit.part(refs, {
			name = "TrashCan",
			size = Vector3.new(3.2, 2.4, 2.4),
			cf = CFrame.new(pos + Vector3.new(0, 1.6, 0)),
			color = Color3.fromRGB(60, 80, 60),
			material = Enum.Material.Metal,
			shape = Enum.PartType.Cylinder,
		}).CFrame = refs.frame
			* CFrame.new(pos + Vector3.new(0, 1.6, 0))
			* CFrame.Angles(0, 0, math.rad(90))
		StopKit.lootPoint(refs, pos + Vector3.new(0, 3.6, 0))
	end
	StopKit.sign(refs, {
		name = "PetArea",
		size = Vector3.new(0.3, 1.4, 4),
		cf = CFrame.new(104, 4, -40),
		color = Color3.fromRGB(40, 70, 50),
		collide = false,
	}, "PET AREA", Enum.NormalId.Left, C.White)
	Props.fence(refs, Vector3.new(100, 0, -50), Vector3.new(100, 0, -30))
	Props.tree(refs, Vector3.new(108, 0.4, -20), 22)
	Props.tree(refs, Vector3.new(110, 0.4, 14), 20)
	StopKit.fragmentSite(refs, Vector3.new(106, 1.5, -46))
	StopKit.lootPoint(refs, Vector3.new(104, 1.4, -34))

	-- Headlights circles the lot, inside it.
	refs.extras.headlightRoute = {
		Vector3.new(21, 1, -48),
		Vector3.new(62, 1, -48),
		Vector3.new(62, 1, 48),
		Vector3.new(21, 1, 48),
	}
	refs.extras.headlightBounds = {
		min = Vector3.new(LOT_X0, 0, LOT_Z0),
		max = Vector3.new(LOT_X1, 0, LOT_Z1),
	}
	StopKit.entitySpawn(refs, CFrame.new(21, 3, -48) * CFrame.Angles(0, math.rad(-90), 0))
	StopKit.trailhead(refs, CFrame.new(108, 0, 62))
	StopKit.backEntrance(refs, CFrame.new(108, 3, -62))

	refs.extras.custom = {
		rest_lure_fuel = function(built: any)
			local Inventory = Registry.find("InventoryService")
			if Inventory then
				Inventory.spawnItem("water_can", lureMarker.CFrame, built.refs.model)
			end
		end,
	}
	return refs
end
