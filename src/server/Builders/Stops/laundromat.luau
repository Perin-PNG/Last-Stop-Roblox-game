--!strict
-- Suds 24-Hour Laundromat. A row of dryers along the back wall: some are running and count
-- down; when one finishes its door can be opened for loot. One running dryer thumps out of
-- rhythm. That one is the Dryer (an Ambusher): open it and you're Down, and when its own
-- count hits zero it bursts open and downs anyone close.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StopKit = require(script.Parent.Parent:WaitForChild("StopKit"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Build = require(Shared.Util.Build)
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Registry = require(script.Parent.Parent.Parent:WaitForChild("Registry"))

local C = Build.Colors

local CENTRE = Vector3.new(60, 7, 0)
local SIZE = Vector3.new(44, 14, 62)

type Dryer = {
	model: Model,
	door: BasePart,
	doorClosed: CFrame,
	label: TextLabel,
	cord: BasePart,
	cordPlugged: CFrame,
	prompt: ProximityPrompt,
	finishAt: number?,
	thumper: boolean,
	opened: boolean,
	loot: string?,
}

local function dryer(refs: StopKit.StopRefs, parent: Instance, cf: CFrame, i: number): Dryer
	local m = Build.model(parent, "Dryer" .. i)
	StopKit.part(refs, {
		name = "Cabinet",
		size = Vector3.new(4, 4.6, 4.8),
		cf = cf * CFrame.new(0, 2.3, 0),
		color = C.White,
		material = Enum.Material.Metal,
	}, m)
	StopKit.part(refs, {
		name = "Panel",
		size = Vector3.new(4.2, 1.4, 4.8),
		cf = cf * CFrame.new(0.1, 5.3, 0),
		color = Color3.fromRGB(190, 192, 196),
		material = Enum.Material.Metal,
	}, m)
	local _, label = StopKit.sign(refs, {
		name = "Timer",
		size = Vector3.new(0.2, 0.9, 1.8),
		cf = cf * CFrame.new(-2.05, 5.3, 1.2),
		color = Color3.fromRGB(12, 16, 14),
		collide = false,
	}, "--", Enum.NormalId.Left, Color3.fromRGB(110, 255, 150), m)
	label.Font = Enum.Font.Code
	local door = StopKit.part(refs, {
		name = "Door",
		size = Vector3.new(0.4, 3, 3),
		cf = cf * CFrame.new(-2.15, 2.6, 0) * CFrame.Angles(0, 0, math.rad(90)),
		color = Color3.fromRGB(140, 150, 160),
		material = Enum.Material.Glass,
		transparency = 0.25,
		shape = Enum.PartType.Cylinder,
	}, m)
	StopKit.part(refs, {
		name = "Drum",
		size = Vector3.new(0.2, 2.6, 2.6),
		cf = cf * CFrame.new(-1.9, 2.6, 0) * CFrame.Angles(0, 0, math.rad(90)),
		color = Color3.fromRGB(30, 30, 34),
		material = Enum.Material.DiamondPlate,
		shape = Enum.PartType.Cylinder,
		collide = false,
	}, m)
	local cord = StopKit.part(refs, {
		name = "Cord",
		size = Vector3.new(0.25, 0.25, 2.4),
		cf = cf * CFrame.new(2.2, 0.8, 1.8),
		color = C.Black,
		material = Enum.Material.Rubber,
		collide = false,
	}, m)
	StopKit.part(refs, {
		name = "Outlet",
		size = Vector3.new(0.1, 0.6, 0.4),
		cf = cf * CFrame.new(2.45, 0.8, 3.0),
		color = C.White,
		collide = false,
	}, m)
	local prompt = StopKit.openable(door, "Open", "Dryer")
	m.PrimaryPart = door
	return {
		model = m,
		door = door,
		doorClosed = door.CFrame,
		label = label,
		cord = cord,
		cordPlugged = cord.CFrame,
		prompt = prompt,
		finishAt = nil,
		thumper = false,
		opened = false,
		loot = nil,
	}
end

local function fmt(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

return function(parent: Instance, frame: CFrame, ctx: StopKit.Ctx, title: string): StopKit.StopRefs
	local refs = StopKit.new(ctx.id, parent, frame)
	StopKit.lot(refs, 96, -70, 70, Color3.fromRGB(46, 46, 48), Enum.Material.Asphalt)
	StopKit.sidewalk(refs, -70, 70)
	StopKit.shelter(refs, title)
	StopKit.approachLights(refs)
	refs.passengerSpot = StopKit.marker(refs, "PassengerSpot", CFrame.new(6, 3, -2))

	StopKit.building(refs, "Laundromat", CENTRE, SIZE, Color3.fromRGB(196, 190, 170), 7, -20)
	local front = CENTRE.X - SIZE.X / 2
	local glass = StopKit.part(refs, {
		name = "Storefront",
		size = Vector3.new(0.3, 7, 36),
		cf = CFrame.new(front - 0.25, 5, 10),
		color = C.Glass,
		material = Enum.Material.Glass,
		transparency = 0.5,
		collide = false,
	})
	local _ = glass
	-- Sign (an anomaly slot: SUDS 25-HOUR).
	local signPart, signLabel = StopKit.sign(refs, {
		name = "Sign",
		size = Vector3.new(0.6, 3, 30),
		cf = CFrame.new(front - 0.5, 15.6, 0),
		color = Color3.fromRGB(30, 90, 160),
		collide = false,
	}, "SUDS 24-HOUR LAUNDROMAT", Enum.NormalId.Left, Color3.fromRGB(230, 250, 255))
	signLabel.Font = Enum.Font.GothamBlack
	Build.light(signPart, "Surface", Color3.fromRGB(120, 200, 255), 1, 12, false);
	(signPart:FindFirstChildWhichIsA("SurfaceLight") :: SurfaceLight).Face = Enum.NormalId.Left
	StopKit.slot(refs, "sign", signPart)
	-- Tiled floor over the plain one.
	StopKit.part(refs, {
		name = "Tiles",
		size = Vector3.new(SIZE.X - 2.2, 0.1, SIZE.Z - 2.2),
		cf = CFrame.new(CENTRE.X, 0.47, CENTRE.Z),
		color = Color3.fromRGB(200, 205, 196),
		material = Enum.Material.Marble,
	})
	-- Fluorescent tubes, one buzzing slightly green.
	for _, z in { -22, -8, 6, 20 } do
		for _, x in { 50, 70 } do
			StopKit.ceilingLight(refs, Vector3.new(x, 13.3, z), C.Fluor, 24)
		end
	end

	-- The dryers.
	local row = Build.model(refs.model, "Dryers")
	local dryers: { Dryer } = {}
	for i = 0, 7 do
		local cf = CFrame.new(CENTRE.X + SIZE.X / 2 - 3.2, 0.4, -24 + i * 6.2)
		table.insert(dryers, dryer(refs, row, cf, i + 1))
	end
	refs.extras.dryers = dryers
	-- Washers: an island of front-loaders back to back. One is an anomaly slot.
	local washers = Build.model(refs.model, "Washers")
	local washerSlot: BasePart? = nil
	local hand: BasePart? = nil
	for side = -1, 1, 2 do
		for i = 0, 4 do
			local cf = CFrame.new(CENTRE.X - 2 + side * 2.3, 0.4, -14 + i * 6)
				* CFrame.Angles(0, if side < 0 then 0 else math.pi, 0)
			StopKit.part(refs, {
				name = "Washer",
				size = Vector3.new(4.2, 4.6, 5),
				cf = cf * CFrame.new(0, 2.3, 0),
				color = C.White,
				material = Enum.Material.Metal,
			}, washers)
			local port = StopKit.part(refs, {
				name = "Porthole",
				size = Vector3.new(0.3, 2.8, 2.8),
				cf = cf * CFrame.new(-2.15, 2.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
				color = Color3.fromRGB(90, 120, 150),
				material = Enum.Material.Glass,
				transparency = 0.2,
				shape = Enum.PartType.Cylinder,
				collide = false,
			}, washers)
			if side < 0 and i == 2 then
				washerSlot = port
				hand = StopKit.part(refs, {
					name = "Hand",
					size = Vector3.new(0.2, 1.4, 1),
					cf = cf * CFrame.new(-2.35, 2.5, 0.1),
					color = Color3.fromRGB(230, 226, 216),
					material = Enum.Material.SmoothPlastic,
					collide = false,
				}, washers)
			end
		end
	end
	if washerSlot and hand then
		StopKit.slot(refs, "washer", washerSlot, { suds_washer_hand = hand :: Instance })
	end
	StopKit.hidingSpot(refs, CFrame.new(CENTRE.X - 2, 3, 20))

	-- Plastic chairs along the window (a slot: they all turn to face the wall).
	local chairs = Build.model(refs.model, "Chairs")
	for i = 0, 4 do
		local cf = CFrame.new(front + 3, 0.4, 2 + i * 4)
		StopKit.part(refs, {
			name = "Seat",
			size = Vector3.new(2.6, 0.3, 2.6),
			cf = cf * CFrame.new(0, 2.1, 0),
			color = Color3.fromRGB(230, 140, 40),
		}, chairs)
		StopKit.part(refs, {
			name = "Back",
			size = Vector3.new(0.3, 2.4, 2.6),
			cf = cf * CFrame.new(-1.3, 3.4, 0),
			color = Color3.fromRGB(230, 140, 40),
		}, chairs)
		StopKit.part(refs, {
			name = "Legs",
			size = Vector3.new(2, 2, 2),
			cf = cf * CFrame.new(0, 1, 0),
			color = C.DarkMetal,
			transparency = 0.5,
		}, chairs)
	end
	chairs.PrimaryPart = chairs:FindFirstChild("Seat") :: BasePart
	StopKit.slot(refs, "chairs", chairs)

	-- Folding table with loot, a change machine, a vending machine.
	StopKit.box(
		refs,
		"FoldingTable",
		CFrame.new(48, 2.6, -24),
		Vector3.new(6, 0.4, 12),
		Color3.fromRGB(220, 220, 214),
		Enum.Material.SmoothPlastic
	)
	StopKit.lootPoint(refs, Vector3.new(48, 3.4, -28))
	StopKit.lootPoint(refs, Vector3.new(48, 3.4, -20))
	StopKit.fragmentSite(refs, Vector3.new(48, 3.4, -24))
	StopKit.box(
		refs,
		"ChangeMachine",
		CFrame.new(front + 2.2, 3.4, -28),
		Vector3.new(2.4, 6.8, 3),
		Color3.fromRGB(80, 90, 110),
		Enum.Material.Metal
	)
	local vending = StopKit.box(
		refs,
		"Vending",
		CFrame.new(CENTRE.X + SIZE.X / 2 - 3, 4, 26),
		Vector3.new(3, 8, 5),
		Color3.fromRGB(150, 30, 40),
		Enum.Material.Metal
	)
	local _ = vending
	StopKit.lootPoint(refs, Vector3.new(76, 1.5, 26))
	StopKit.lootPoint(refs, Vector3.new(40, 1.5, 26))
	StopKit.lootPoint(refs, Vector3.new(56, 1.5, -28))
	StopKit.lootPoint(refs, Vector3.new(66, 1.5, 28))
	-- Laundry baskets on the floor.
	for _, z in { -6, 12 } do
		StopKit.box(
			refs,
			"Basket",
			CFrame.new(48, 1.2, z),
			Vector3.new(2.4, 1.6, 3),
			Color3.fromRGB(80, 140, 200),
			Enum.Material.Plastic
		)
		StopKit.lootPoint(refs, Vector3.new(48, 2.3, z))
	end

	-- Wall clock above the dryers (slot: runs backward).
	local clockFace = StopKit.part(refs, {
		name = "ClockFace",
		size = Vector3.new(0.3, 3, 3),
		cf = CFrame.new(CENTRE.X + SIZE.X / 2 - 1.3, 10.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
		color = C.White,
		shape = Enum.PartType.Cylinder,
		collide = false,
	})
	local _ = clockFace
	local clockHand = StopKit.part(refs, {
		name = "ClockHand",
		size = Vector3.new(0.1, 1.2, 0.15),
		cf = CFrame.new(CENTRE.X + SIZE.X / 2 - 1.5, 10.95, 0),
		color = C.Black,
		collide = false,
	})
	StopKit.slot(refs, "clock", clockHand)

	-- Coat hooks by the door. Normally one coat; the variant has a coat on every hook.
	local hooks = Build.model(refs.model, "Hooks")
	local allCoats = Build.model(refs.model, "AllCoats")
	for i = 0, 4 do
		local z = -30 + i * 1.6
		StopKit.part(refs, {
			name = "Hook",
			size = Vector3.new(0.6, 0.2, 0.2),
			cf = CFrame.new(front + 1.4, 7.4, z),
			color = C.DarkMetal,
			collide = false,
		}, hooks)
		local coat = StopKit.part(refs, {
			name = "Coat",
			size = Vector3.new(0.6, 3.6, 1.4),
			cf = CFrame.new(front + 1.6, 5.6, z),
			color = Color3.fromRGB(40 + i * 6, 34, 30),
			material = Enum.Material.Fabric,
			collide = false,
		}, if i == 2 then hooks else allCoats)
		local _ = coat
	end
	StopKit.slot(refs, "hooks", hooks, { coat_every_hook = allCoats :: Instance })

	-- Floor slot: wet footprints from the door to a dryer.
	local floorMarker = StopKit.marker(refs, "FloorSlot", CFrame.new(CENTRE.X, 0.5, 0))
	local prints = Build.model(refs.model, "Footprints")
	for i = 0, 11 do
		StopKit.part(refs, {
			name = "Print",
			size = Vector3.new(1, 0.05, 0.5),
			cf = CFrame.new(front + 2 + i * 3, 0.53, -18 + i * 1.2 + (i % 2) * 0.8),
			color = Color3.fromRGB(60, 70, 80),
			material = Enum.Material.Glass,
			transparency = 0.2,
			collide = false,
			query = false,
		}, prints)
	end
	StopKit.slot(refs, "floor", floorMarker, { wet_footprints = prints :: Instance })
	-- The unplugged cord anomaly is custom: it unplugs the thumping dryer.
	StopKit.slot(refs, "dryer_cord", dryers[1].cord)

	StopKit.trailhead(refs, CFrame.new(100, 0, 56))
	StopKit.backEntrance(refs, CFrame.new(100, 3, -56))
	StopKit.entitySpawn(refs, CFrame.new(CENTRE.X + 10, 3, 0))

	-- Runtime: dryers count down while the stop is open.
	local token = 0
	local function thumperOf(): Dryer?
		for _, d in dryers do
			if d.thumper then
				return d
			end
		end
		return nil
	end

	refs.extras.custom = {
		dryer_unplugged = function()
			local d = thumperOf()
			if d then
				d.cord.CFrame = d.cordPlugged * CFrame.new(-0.6, -0.5, -1) * CFrame.Angles(0, math.rad(40), 0)
			end
		end,
	}

	local function downNear(d: Dryer, radius: number)
		local PlayerState = Registry.find("PlayerStateService")
		if not PlayerState then
			return
		end
		for _, player in game:GetService("Players"):GetPlayers() do
			local root = PlayerState.rootOf(player)
			if root and (root.Position - d.door.Position).Magnitude <= radius and PlayerState.isHealthy(player) then
				PlayerState.down(player, "dryer")
			end
		end
	end

	local function burst(d: Dryer)
		d.opened = true
		d.prompt.Enabled = false
		d.door.CFrame = d.doorClosed * CFrame.new(0, 0, -1.6) * CFrame.Angles(math.rad(70), 0, 0)
		d.label.Text = "ERR"
		d.label.TextColor3 = Color3.fromRGB(255, 60, 60)
		Net.notifyAll("Sound", { key = "DryerBurst", part = d.door })
		local arm = StopKit.part(refs, {
			name = "Arm",
			size = Vector3.new(4, 0.7, 0.7),
			cf = d.doorClosed * CFrame.new(0, -2.6, 0) * CFrame.Angles(0, 0, math.rad(-90)) * CFrame.new(0, 0, 0),
			color = Color3.fromRGB(226, 222, 212),
			collide = false,
		}, d.model)
		local _ = arm
		downNear(d, Config.Tuning.Entities.AmbusherRange)
	end

	refs.extras.activate = function(built: any, deadline: number)
		token += 1
		local mine = token
		local rng = ctx.rng:child("dryers")
		local now = workspace:GetServerTimeNow()
		local span = math.max(30, deadline - now)
		local order = rng:shuffle({ 1, 2, 3, 4, 5, 6, 7, 8 })
		local running = rng:int(4, 5)
		local lootTable = Config.Items.LootTables.batteries
		for k, index in order do
			local d = dryers[index]
			d.opened = false
			d.thumper = false
			d.door.CFrame = d.doorClosed
			d.cord.CFrame = d.cordPlugged
			if k <= running then
				d.finishAt = now + rng:float(span * 0.15, span * 0.75)
				d.loot = rng:weighted(lootTable)
			else
				d.finishAt = nil
				d.loot = nil
				d.label.Text = "--"
			end
		end
		-- The thumper is one of the running dryers; its count ends late, near the bell.
		local thump = dryers[order[1]]
		thump.thumper = true
		thump.loot = nil
		thump.finishAt = now + rng:float(span * 0.5, span * 0.85)
		for _, d in dryers do
			d.prompt.Triggered:Connect(function(player: Player)
				if mine ~= token or d.opened then
					return
				end
				local PlayerState = Registry.find("PlayerStateService")
				if not PlayerState or not PlayerState.isHealthy(player) then
					return
				end
				local t = workspace:GetServerTimeNow()
				if d.thumper then
					burst(d)
					PlayerState.down(player, "dryer")
					return
				end
				if d.finishAt and t < d.finishAt then
					Net.notify(player, "Toast", { text = "It's still running." })
					return
				end
				d.opened = true
				d.prompt.Enabled = false
				d.door.CFrame = d.doorClosed * CFrame.new(0, 0, -1.6) * CFrame.Angles(math.rad(70), 0, 0)
				local Inventory = Registry.find("InventoryService")
				if d.loot and Inventory then
					Inventory.spawnItem(d.loot, d.doorClosed * CFrame.new(-1.5, 0, 0), built.refs.model)
				else
					Net.notify(player, "Toast", { text = "Empty." })
				end
			end)
		end
		task.spawn(function()
			local beat = 0
			while mine == token do
				local t = workspace:GetServerTimeNow()
				beat += 1
				for _, d in dryers do
					if d.finishAt and not d.opened then
						local left = d.finishAt - t
						if left > 0 then
							d.label.Text = fmt(left)
							if d.thumper and beat % 3 == 0 then
								-- Out of rhythm: a lurch, a thump, a noise event.
								d.door.CFrame = d.doorClosed * CFrame.new(-0.12, 0, 0)
								task.delay(0.15, function()
									if not d.opened then
										d.door.CFrame = d.doorClosed
									end
								end)
								Net.notifyAll("Sound", { key = "DryerThump", part = d.door })
								local Noise = Registry.find("NoiseService")
								if Noise then
									Noise.post(d.door.Position, 18, "dryer")
								end
							end
						elseif d.thumper then
							burst(d)
						else
							d.label.Text = "DONE"
						end
					end
				end
				task.wait(0.5)
			end
		end)
	end

	refs.extras.deactivate = function()
		token += 1
	end
	return refs
end
