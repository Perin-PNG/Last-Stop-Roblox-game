--!strict
-- Gas & Go: the stop that recurs. A canopy over two pump islands, a small store with a
-- clerk behind the counter, a payphone and an ice chest. On loop-check visits one thing
-- may have changed (AnomalyService swaps a slot); the right call is to stay aboard.
--
-- Stop frame: +X into the lot, -Z road-forward. The bus's middle door is at the origin.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StopKit = require(script.Parent.Parent:WaitForChild("StopKit"))
local Build = require(ReplicatedStorage:WaitForChild("Shared").Util.Build)

local C = Build.Colors

local STORE = Vector3.new(84, 7, -14) -- store centre
local STORE_SIZE = Vector3.new(30, 14, 42)

local function priceBoard(refs: StopKit.StopRefs, parent: Instance, cf: CFrame)
	local board = Build.model(parent, "Prices")
	local grades = { { "REG", "3.49" }, { "PLUS", "3.79" }, { "DIESEL", "4.19" } }
	for i, g in grades do
		local y = -(i - 1) * 1.7
		StopKit.sign(refs, {
			name = "Grade",
			size = Vector3.new(0.3, 1.4, 3.2),
			cf = cf * CFrame.new(0, y, 2),
			color = Color3.fromRGB(240, 240, 235),
			collide = false,
		}, g[1], Enum.NormalId.Left, C.Black, board)
		local _, price = StopKit.sign(refs, {
			name = "Price",
			size = Vector3.new(0.3, 1.4, 3.6),
			cf = cf * CFrame.new(0, y, -1.6),
			color = C.Black,
			collide = false,
		}, g[2], Enum.NormalId.Left, Color3.fromRGB(255, 90, 60), board)
		price.Font = Enum.Font.Code
	end
	return board
end

local function pump(refs: StopKit.StopRefs, parent: Instance, cf: CFrame, number: number): (Model, Part, TextLabel)
	local m = Build.model(parent, "Pump" .. number)
	StopKit.part(refs, {
		name = "Base",
		size = Vector3.new(4, 1, 7),
		cf = cf * CFrame.new(0, 0.5, 0),
		color = Color3.fromRGB(170, 170, 160),
		material = Enum.Material.Concrete,
	}, m)
	StopKit.part(refs, {
		name = "Body",
		size = Vector3.new(2.6, 6.4, 3.4),
		cf = cf * CFrame.new(0, 4.2, 0),
		color = Color3.fromRGB(200, 40, 36),
		material = Enum.Material.Metal,
		cast = true,
	}, m)
	StopKit.part(refs, {
		name = "Top",
		size = Vector3.new(2.8, 0.8, 3.6),
		cf = cf * CFrame.new(0, 7.8, 0),
		color = C.White,
		material = Enum.Material.SmoothPlastic,
	}, m)
	local displayPart, display = StopKit.sign(refs, {
		name = "Display",
		size = Vector3.new(0.2, 1.4, 2.4),
		cf = cf * CFrame.new(-1.4, 5.6, 0),
		color = Color3.fromRGB(16, 22, 16),
		collide = false,
	}, "0.00", Enum.NormalId.Left, Color3.fromRGB(120, 255, 140), m)
	display.Font = Enum.Font.Code
	for _, side in { -1, 1 } do
		StopKit.part(refs, {
			name = "Nozzle",
			size = Vector3.new(0.5, 1.2, 0.5),
			cf = cf * CFrame.new(side * 1.45, 3.8, 1.2),
			color = C.Black,
			collide = false,
		}, m)
		StopKit.part(refs, {
			name = "Hose",
			size = Vector3.new(0.25, 3.4, 0.25),
			cf = cf * CFrame.new(side * 1.45, 2.4, 1.2),
			color = C.Black,
			material = Enum.Material.Rubber,
			collide = false,
		}, m)
	end
	return m, displayPart, display
end

return function(parent: Instance, frame: CFrame, ctx: StopKit.Ctx, title: string): StopKit.StopRefs
	local refs = StopKit.new(ctx.id, parent, frame)
	StopKit.lot(refs, 110, -70, 70, Color3.fromRGB(44, 44, 47), Enum.Material.Asphalt)
	StopKit.sidewalk(refs, -70, 70)
	StopKit.shelter(refs, title)
	StopKit.approachLights(refs)
	refs.passengerSpot = StopKit.marker(refs, "PassengerSpot", CFrame.new(6, 3, -2))

	-- Parking lines and a painted lane through the forecourt.
	for i = 0, 5 do
		StopKit.part(refs, {
			name = "Stripe",
			size = Vector3.new(0.4, 0.05, 9),
			cf = CFrame.new(100 - i * 7, 0.03, 30),
			color = C.Lane,
			collide = false,
			query = false,
		})
	end

	-- Canopy over the pumps.
	local canopy = Build.model(refs.model, "Canopy")
	StopKit.part(refs, {
		name = "CanopyRoof",
		size = Vector3.new(30, 2, 52),
		cf = CFrame.new(40, 17, 0),
		color = C.White,
		material = Enum.Material.SmoothPlastic,
		cast = true,
	}, canopy)
	StopKit.part(refs, {
		name = "CanopyBand",
		size = Vector3.new(30.4, 1.2, 52.4),
		cf = CFrame.new(40, 16.6, 0),
		color = Color3.fromRGB(200, 40, 36),
		material = Enum.Material.SmoothPlastic,
	}, canopy)
	for _, z in { -20, 20 } do
		StopKit.part(refs, {
			name = "Column",
			size = Vector3.new(1.4, 16, 1.4),
			cf = CFrame.new(40, 8, z),
			color = C.White,
			material = Enum.Material.Metal,
		}, canopy)
	end
	for _, x in { 32, 48 } do
		for _, z in { -16, 0, 16 } do
			local tube = StopKit.part(refs, {
				name = "CanopyLight",
				size = Vector3.new(5, 0.3, 2),
				cf = CFrame.new(x, 15.85, z),
				color = C.Fluor,
				material = Enum.Material.Neon,
				collide = false,
			}, canopy)
			Build.light(tube, "Spot", C.Fluor, 2.2, 30, false);
			(tube:FindFirstChildWhichIsA("SpotLight") :: SpotLight).Angle = 120
		end
	end

	-- Pump islands. Pump 1's display is an anomaly slot (it counts up on its own).
	local pumps = Build.model(refs.model, "Pumps")
	local _, displayPart1, display1 = pump(refs, pumps, CFrame.new(40, 0, -12), 1)
	pump(refs, pumps, CFrame.new(40, 0, 12), 2)
	StopKit.slot(refs, "pump_display", displayPart1)
	refs.extras.pumpDisplay = display1
	StopKit.hidingSpot(refs, CFrame.new(43, 3, -12))
	StopKit.hidingSpot(refs, CFrame.new(43, 3, 12))
	-- Fuel cans by the pumps, always.
	StopKit.lootPoint(refs, Vector3.new(37, 1.5, -6), "fuel")
	StopKit.lootPoint(refs, Vector3.new(37, 1.5, 6), "fuel")

	-- The sedan at pump 1, and its double at pump 2 (hidden).
	local sedan = StopKit.car(refs, "Sedan", CFrame.new(31, 0, -12), Color3.fromRGB(70, 82, 96))
	local double = StopKit.car(refs, "SedanDouble", CFrame.new(31, 0, 12), Color3.fromRGB(70, 82, 96))
	StopKit.slot(refs, "lot", sedan, { extra_sedan = double :: Instance })

	-- The store.
	local store = StopKit.building(refs, "Store", STORE, STORE_SIZE, Color3.fromRGB(176, 170, 156), 7, -20)
	for _, d in store:GetDescendants() do
		if d:IsA("BasePart") and (d.Name == "Wall" or d.Name == "Front" or d.Name == "Lintel") then
			d.Material = Enum.Material.Concrete
		end
	end
	-- Big shop window beside the door.
	local window = StopKit.part(refs, {
		name = "Window",
		size = Vector3.new(0.3, 6, 16),
		cf = CFrame.new(STORE.X - STORE_SIZE.X / 2 - 0.2, 5, -2),
		color = C.Glass,
		material = Enum.Material.Glass,
		transparency = 0.55,
		collide = false,
	})
	local windowFrame = StopKit.part(refs, {
		name = "WindowSill",
		size = Vector3.new(0.6, 0.4, 16.4),
		cf = CFrame.new(STORE.X - STORE_SIZE.X / 2 - 0.3, 1.9, -2),
		color = C.DarkMetal,
	})
	local _ = windowFrame
	local watcher = StopKit.figure(
		refs,
		"WindowClerk",
		CFrame.new(STORE.X - STORE_SIZE.X / 2 - 3, 0, 2) * CFrame.Angles(0, math.rad(-90), 0),
		Color3.fromRGB(150, 30, 30),
		nil,
		{ apron = Color3.fromRGB(40, 40, 40) }
	)
	StopKit.slot(refs, "window", window, { gas_window_clerk = watcher :: Instance })
	-- OPEN sign.
	local open = StopKit.part(refs, {
		name = "OpenSign",
		size = Vector3.new(0.2, 1.2, 3.4),
		cf = CFrame.new(STORE.X - STORE_SIZE.X / 2 + 0.6, 6.6, 2),
		color = Color3.fromRGB(255, 60, 80),
		material = Enum.Material.Neon,
		collide = false,
	})
	Build.light(open, "Point", Color3.fromRGB(255, 60, 80), 0.8, 8, false)
	-- The store sign above the door.
	local _, storeName = StopKit.sign(refs, {
		name = "StoreSign",
		size = Vector3.new(0.4, 2.6, 18),
		cf = CFrame.new(STORE.X - STORE_SIZE.X / 2 - 0.4, 12.4, -14),
		color = Color3.fromRGB(200, 40, 36),
		collide = false,
	}, "GAS & GO  MART", Enum.NormalId.Left, C.White)
	local _ = storeName

	-- Inside: ceiling lights (one slot), counter, the clerk, shelves.
	local lights = Build.model(refs.model, "StoreLights")
	for _, z in { -28, -14, 0 } do
		for _, x in { 76, 92 } do
			StopKit.ceilingLight(refs, Vector3.new(x, 13.3, z), C.Fluor, 26, lights)
		end
	end
	StopKit.slot(refs, "store_lights", lights)
	StopKit.box(refs, "Counter", CFrame.new(76, 2, -30), Vector3.new(4, 4, 12), Color3.fromRGB(120, 90, 60))
	StopKit.box(
		refs,
		"CounterTop",
		CFrame.new(76, 4.1, -30),
		Vector3.new(4.4, 0.3, 12.4),
		Color3.fromRGB(60, 60, 64),
		Enum.Material.Granite
	)
	local register = StopKit.box(
		refs,
		"Register",
		CFrame.new(76, 4.9, -28),
		Vector3.new(1.6, 1.3, 1.6),
		C.DarkMetal,
		Enum.Material.Metal
	)
	local _ = register
	local clerk = StopKit.figure(
		refs,
		"Clerk",
		CFrame.new(80, 0.4, -30) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(150, 30, 30),
		nil,
		{ apron = Color3.fromRGB(40, 40, 40) }
	)
	StopKit.slot(refs, "clerk", clerk)
	refs.extras.clerk = clerk
	StopKit.entitySpawn(refs, CFrame.new(82, 3.5, -30))
	-- Back shelf of cigarettes behind the clerk.
	StopKit.box(refs, "BackShelf", CFrame.new(98, 5, -30), Vector3.new(1.5, 9, 14), Color3.fromRGB(90, 70, 50))
	-- Aisles.
	for _, z in { -10, 2 } do
		local shelf = StopKit.box(
			refs,
			"Shelf",
			CFrame.new(86, 2.8, z),
			Vector3.new(14, 5.6, 2.4),
			Color3.fromRGB(200, 200, 196),
			Enum.Material.Metal
		)
		local _ = shelf
		for j = 0, 2 do
			for _, side in { -1.7, 1.7 } do
				StopKit.lootPoint(refs, Vector3.new(81 + j * 5, 1.6, z + side))
			end
		end
	end
	-- Drinks cooler along the back wall.
	local cooler = StopKit.box(
		refs,
		"Cooler",
		CFrame.new(98, 5, 0),
		Vector3.new(2, 9, 18),
		Color3.fromRGB(40, 50, 60),
		Enum.Material.Metal
	)
	local _ = cooler
	local coolerGlow = StopKit.part(refs, {
		name = "CoolerGlass",
		size = Vector3.new(0.2, 8, 17),
		cf = CFrame.new(96.9, 5, 0),
		color = Color3.fromRGB(180, 230, 255),
		material = Enum.Material.Neon,
		transparency = 0.6,
		collide = false,
	})
	Build.light(coolerGlow, "Surface", Color3.fromRGB(180, 230, 255), 0.6, 10, false);
	(coolerGlow:FindFirstChildWhichIsA("SurfaceLight") :: SurfaceLight).Face = Enum.NormalId.Left
	-- Restroom: a locked door at the back corner with a light strip under it.
	local restroom = Build.model(refs.model, "Restroom")
	StopKit.sign(refs, {
		name = "RestroomDoor",
		size = Vector3.new(0.4, 8, 4),
		cf = CFrame.new(96, 4.4, 28),
		color = Color3.fromRGB(110, 120, 130),
		material = Enum.Material.Metal,
	}, "OUT OF\nORDER", Enum.NormalId.Left, C.Black, restroom)
	local strip = StopKit.part(refs, {
		name = "UnderDoor",
		size = Vector3.new(0.3, 0.12, 3.6),
		cf = CFrame.new(95.6, 0.46, 28),
		color = C.Warm,
		material = Enum.Material.Neon,
		collide = false,
	}, restroom)
	Build.light(strip, "Point", C.Warm, 0.6, 4, false)
	StopKit.slot(refs, "restroom", restroom)

	-- Outside: ice chest, payphone, the pole sign with prices.
	local chest = StopKit.box(
		refs,
		"IceChest",
		CFrame.new(STORE.X - STORE_SIZE.X / 2 - 2.6, 2, 10),
		Vector3.new(3, 4, 7),
		C.White,
		Enum.Material.SmoothPlastic
	)
	StopKit.sign(refs, {
		name = "IceLabel",
		size = Vector3.new(0.1, 1.2, 4),
		cf = CFrame.new(STORE.X - STORE_SIZE.X / 2 - 4.15, 2.6, 10),
		color = Color3.fromRGB(40, 120, 200),
		collide = false,
	}, "ICE", Enum.NormalId.Left, C.White)
	local lid = StopKit.box(
		refs,
		"Lid",
		CFrame.new(STORE.X - STORE_SIZE.X / 2 - 2.6, 4.15, 10),
		Vector3.new(3.2, 0.3, 7.2),
		Color3.fromRGB(40, 120, 200),
		Enum.Material.SmoothPlastic
	)
	local chestModel = Build.model(refs.model, "IceChestSlot")
	chest.Parent = chestModel
	lid.Parent = chestModel
	chestModel.PrimaryPart = lid
	StopKit.slot(refs, "ice_chest", chestModel)

	local payphone = Build.model(refs.model, "Payphone")
	StopKit.part(refs, {
		name = "Post",
		size = Vector3.new(0.6, 5, 0.6),
		cf = CFrame.new(64, 2.5, -48),
		color = C.DarkMetal,
	}, payphone)
	local box = StopKit.part(refs, {
		name = "Box",
		size = Vector3.new(1.4, 3, 2.2),
		cf = CFrame.new(63.4, 5.5, -48),
		color = Color3.fromRGB(150, 150, 160),
		material = Enum.Material.Metal,
	}, payphone)
	StopKit.part(refs, {
		name = "Handset",
		size = Vector3.new(0.5, 2, 0.6),
		cf = CFrame.new(62.5, 5.6, -47.4),
		color = C.Black,
		collide = false,
	}, payphone)
	refs.extras.payphoneBox = box
	StopKit.slot(refs, "payphone", payphone)

	local signModel = Build.model(refs.model, "PoleSign")
	StopKit.part(refs, {
		name = "Pole",
		size = Vector3.new(1.2, 26, 1.2),
		cf = CFrame.new(18, 13, -54),
		color = C.DarkMetal,
		material = Enum.Material.Metal,
	}, signModel)
	local signPart, signLabel = StopKit.sign(refs, {
		name = "Sign",
		size = Vector3.new(1, 5, 12),
		cf = CFrame.new(18, 26, -54),
		color = Color3.fromRGB(200, 40, 36),
		collide = false,
	}, "GAS & GO", Enum.NormalId.Left, C.White)
	signPart.Parent = signModel
	signLabel.Font = Enum.Font.GothamBlack
	Build.light(signPart, "Surface", Color3.fromRGB(255, 120, 100), 1.2, 14, false);
	(signPart:FindFirstChildWhichIsA("SurfaceLight") :: SurfaceLight).Face = Enum.NormalId.Left
	StopKit.slot(refs, "sign", signPart)
	local prices = priceBoard(refs, signModel, CFrame.new(18, 21, -54))
	StopKit.slot(refs, "prices", prices)

	-- Air pump and trash can for silhouette.
	StopKit.box(
		refs,
		"AirPump",
		CFrame.new(62, 2.5, 40),
		Vector3.new(1.6, 5, 1.6),
		Color3.fromRGB(230, 200, 40),
		Enum.Material.Metal
	)
	StopKit.box(refs, "TrashCan", CFrame.new(46, 1.6, 0), Vector3.new(1.8, 3.2, 1.8), C.DarkMetal, Enum.Material.Metal)
	StopKit.box(
		refs,
		"Dumpster",
		CFrame.new(104, 3, 40),
		Vector3.new(6, 6, 10),
		Color3.fromRGB(40, 70, 50),
		Enum.Material.Metal
	)
	StopKit.hidingSpot(refs, CFrame.new(98, 3, 40))

	StopKit.trailhead(refs, CFrame.new(116, 0, 56))
	StopKit.backEntrance(refs, CFrame.new(108, 3, -60))
	return refs
end
