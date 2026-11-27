--!strict
-- Rosie's 24/7 Diner: the safe stop. No local threat. Rosie stands behind the counter and
-- trades items for transfers. A regular sits in the corner booth. If Rosie has no
-- reflection in the window (an anomaly), don't trade with her.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StopKit = require(script.Parent.Parent:WaitForChild("StopKit"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Build = require(Shared.Util.Build)
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Registry = require(script.Parent.Parent.Parent:WaitForChild("Registry"))

local C = Build.Colors

local CENTRE = Vector3.new(56, 7, 0)
local SIZE = Vector3.new(38, 14, 56)

-- What Rosie sells, and for how many transfers.
local MENU = {
	{ id = "coffee", price = 2 },
	{ id = "food", price = 2 },
	{ id = "battery", price = 3 },
	{ id = "flare", price = 4 },
	{ id = "medkit", price = 5 },
}

local function booth(refs: StopKit.StopRefs, parent: Instance, cf: CFrame): Model
	local m = Build.model(parent, "Booth")
	local red = Color3.fromRGB(170, 30, 40)
	for _, dz in { -3.4, 3.4 } do
		StopKit.part(refs, {
			name = "Bench",
			size = Vector3.new(6, 2, 2.2),
			cf = cf * CFrame.new(0, 1.4, dz),
			color = red,
			material = Enum.Material.Leather,
		}, m)
		StopKit.part(refs, {
			name = "BenchBack",
			size = Vector3.new(6, 3, 0.8),
			cf = cf * CFrame.new(0, 3.4, dz + (if dz < 0 then -1 else 1)),
			color = red,
			material = Enum.Material.Leather,
		}, m)
	end
	StopKit.part(refs, {
		name = "Table",
		size = Vector3.new(5, 0.3, 3.6),
		cf = cf * CFrame.new(0, 2.9, 0),
		color = Color3.fromRGB(230, 225, 210),
		material = Enum.Material.Marble,
	}, m)
	StopKit.part(refs, {
		name = "TableLeg",
		size = Vector3.new(0.5, 2.6, 0.5),
		cf = cf * CFrame.new(0, 1.5, 0),
		color = C.Metal,
		material = Enum.Material.Metal,
	}, m)
	local lamp = StopKit.part(refs, {
		name = "Pendant",
		size = Vector3.new(1.2, 0.8, 1.2),
		cf = cf * CFrame.new(0, 9, 0),
		color = C.Warm,
		material = Enum.Material.Neon,
		collide = false,
	}, m)
	Build.light(lamp, "Point", C.Warm, 0.9, 12, false)
	return m
end

return function(parent: Instance, frame: CFrame, ctx: StopKit.Ctx, title: string): StopKit.StopRefs
	local refs = StopKit.new(ctx.id, parent, frame)
	StopKit.lot(refs, 92, -70, 70, Color3.fromRGB(46, 46, 48), Enum.Material.Asphalt)
	StopKit.sidewalk(refs, -70, 70)
	StopKit.shelter(refs, title)
	StopKit.approachLights(refs)
	refs.passengerSpot = StopKit.marker(refs, "PassengerSpot", CFrame.new(6, 3, -2))

	local front = CENTRE.X - SIZE.X / 2
	local building = StopKit.building(refs, "Diner", CENTRE, SIZE, Color3.fromRGB(205, 205, 200), 7, -16)
	for _, d in building:GetChildren() do
		if d:IsA("BasePart") and (d.Name == "Wall" or d.Name == "Front" or d.Name == "Lintel") then
			d.Material = Enum.Material.Metal
			d.Reflectance = 0.05
		end
	end
	-- Chrome stripe and a red band, the classic diner look.
	for _, y in { 3, 9.5 } do
		StopKit.part(refs, {
			name = "Band",
			size = Vector3.new(0.3, if y < 5 then 0.6 else 1.4, SIZE.Z),
			cf = CFrame.new(front - 0.3, y, CENTRE.Z),
			color = if y < 5 then C.Metal else Color3.fromRGB(170, 30, 40),
			material = if y < 5 then Enum.Material.Metal else Enum.Material.SmoothPlastic,
			collide = false,
		})
	end
	-- Long window along the front, where Rosie's reflection shows.
	local windowPart = StopKit.part(refs, {
		name = "Window",
		size = Vector3.new(0.3, 4.6, 34),
		cf = CFrame.new(front - 0.25, 6.2, 8),
		color = C.Glass,
		material = Enum.Material.Glass,
		transparency = 0.5,
		collide = false,
	})
	local _ = windowPart
	-- The sign.
	local signPart, signLabel = StopKit.sign(refs, {
		name = "Sign",
		size = Vector3.new(0.6, 3.2, 22),
		cf = CFrame.new(front - 0.6, 15.8, 4),
		color = Color3.fromRGB(240, 235, 220),
		collide = false,
	}, "ROSIE'S 24/7", Enum.NormalId.Left, Color3.fromRGB(200, 30, 50))
	signLabel.Font = Enum.Font.Arcade
	Build.light(signPart, "Surface", Color3.fromRGB(255, 90, 110), 1.3, 14, false);
	(signPart:FindFirstChildWhichIsA("SurfaceLight") :: SurfaceLight).Face = Enum.NormalId.Left
	StopKit.slot(refs, "sign", signPart)
	-- Checkerboard floor.
	for ix = 0, 8 do
		for iz = 0, 12 do
			if (ix + iz) % 2 == 0 then
				StopKit.part(refs, {
					name = "Tile",
					size = Vector3.new(4, 0.06, 4),
					cf = CFrame.new(front + 3 + ix * 4, 0.45, -24 + iz * 4),
					color = C.Black,
					collide = false,
					query = false,
				})
			end
		end
	end
	StopKit.part(refs, {
		name = "FloorWhite",
		size = Vector3.new(SIZE.X - 2.2, 0.05, SIZE.Z - 2.2),
		cf = CFrame.new(CENTRE.X, 0.43, CENTRE.Z),
		color = C.White,
		collide = false,
		query = false,
	})
	for _, z in { -18, -4, 10, 22 } do
		StopKit.ceilingLight(refs, Vector3.new(CENTRE.X, 13.3, z), C.Warm, 26)
	end

	-- The counter along the back with stools.
	local counterX = CENTRE.X + 8
	StopKit.box(
		refs,
		"Counter",
		CFrame.new(counterX, 2, -2),
		Vector3.new(3, 4, 34),
		Color3.fromRGB(170, 30, 40),
		Enum.Material.SmoothPlastic
	)
	StopKit.box(
		refs,
		"CounterTop",
		CFrame.new(counterX, 4.1, -2),
		Vector3.new(3.6, 0.3, 34.4),
		C.White,
		Enum.Material.Marble
	)
	for i = 0, 6 do
		local z = -16 + i * 4.6
		StopKit.part(refs, {
			name = "StoolSeat",
			size = Vector3.new(1.6, 0.4, 1.6),
			cf = CFrame.new(counterX - 3.4, 3, z),
			color = Color3.fromRGB(170, 30, 40),
			material = Enum.Material.Leather,
			shape = Enum.PartType.Cylinder,
		})
		StopKit.part(refs, {
			name = "StoolPost",
			size = Vector3.new(0.4, 2.8, 0.4),
			cf = CFrame.new(counterX - 3.4, 1.4, z),
			color = C.Metal,
			material = Enum.Material.Metal,
		})
	end
	-- Pie case and coffee machine.
	local pie = StopKit.part(refs, {
		name = "PieCase",
		size = Vector3.new(2.4, 2, 4),
		cf = CFrame.new(counterX, 5.3, 8),
		color = C.Glass,
		material = Enum.Material.Glass,
		transparency = 0.4,
	})
	Build.light(pie, "Point", C.Warm, 0.5, 6, false)
	StopKit.box(
		refs,
		"CoffeeMachine",
		CFrame.new(CENTRE.X + 16, 5.6, -10),
		Vector3.new(2.6, 3, 4),
		C.DarkMetal,
		Enum.Material.Metal
	)

	-- Rosie, behind the counter.
	local rosieCf = CFrame.new(CENTRE.X + 13, 0.4, -2) * CFrame.Angles(0, math.rad(90), 0)
	local rosie = StopKit.figure(refs, "Rosie", rosieCf, Color3.fromRGB(110, 170, 200), nil, {
		apron = C.White,
		skin = Color3.fromRGB(200, 160, 130),
		pants = Color3.fromRGB(60, 60, 80),
	})
	refs.extras.rosie = rosie
	-- Her reflection in the front window (an anomaly hides it).
	local reflection = StopKit.figure(
		refs,
		"RosieReflection",
		CFrame.new(front - 0.1, 2.4, 6) * CFrame.Angles(0, math.rad(-90), 0),
		Color3.fromRGB(110, 170, 200),
		nil,
		{ apron = C.White, height = 0.6 }
	)
	for _, d in reflection:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = 0.82
			d.CanQuery = false
		end
	end
	StopKit.slot(refs, "rosie_reflection", reflection)

	-- The menu: one prompt per item on the counter.
	local menu = Build.model(refs.model, "Menu")
	local defs = Config.Items.Items
	for i, entry in MENU do
		local def = defs[entry.id]
		local item = StopKit.part(refs, {
			name = "Menu_" .. entry.id,
			size = def.size,
			cf = CFrame.new(counterX + 0.6, 4.3 + def.size.Y / 2, -14 + i * 4),
			color = def.color,
			material = Enum.Material.SmoothPlastic,
			collide = false,
		}, menu)
		local prompt =
			Build.prompt(item, string.format("Buy (%d transfers)", entry.price), def.name, 0.3, 8, "BuyPrompt")
		prompt.Triggered:Connect(function(player: Player)
			local Inventory = Registry.find("InventoryService")
			local PlayerState = Registry.find("PlayerStateService")
			if not Inventory or not PlayerState or not PlayerState.isHealthy(player) then
				return
			end
			if refs.extras.noReflection then
				-- The wrong Rosie takes the money and gives nothing back.
				if Inventory.spendTransfers(player, entry.price) then
					Net.notify(player, "Toast", { text = "She smiles. Your hands are empty." })
					local Dread = Registry.find("DreadService")
					if Dread then
						Dread.add(player, 35)
					end
					local Bus = Registry.find("BusService")
					if Bus then
						task.spawn(function()
							for _ = 1, 4 do
								for _, d in building:GetDescendants() do
									if d:IsA("PointLight") then
										d.Enabled = not d.Enabled
									end
								end
								task.wait(0.15)
							end
						end)
					end
				end
				return
			end
			if not Inventory.hasRoomFor(player, entry.id) then
				Net.notify(player, "Toast", { text = "No room for that." })
				return
			end
			if not Inventory.spendTransfers(player, entry.price) then
				Net.notify(player, "Toast", { text = "Not enough transfers." })
				return
			end
			Inventory.give(player, entry.id)
			Net.notify(player, "Toast", { text = 'Rosie: "Stay warm, hon."' })
		end)
	end
	-- The Return Ticket: once per run, 15 transfers brings one Lost teammate back aboard.
	local returnTicket = StopKit.part(refs, {
		name = "ReturnTicket",
		size = Vector3.new(0.9, 0.1, 1.6),
		cf = CFrame.new(counterX + 0.6, 4.35, -14 + (#MENU + 1) * 4),
		color = Color3.fromRGB(200, 40, 50),
		material = Enum.Material.Neon,
		collide = false,
	}, menu)
	local returnPrompt = Build.prompt(
		returnTicket,
		string.format("Buy (%d transfers)", Config.Tuning.Player.ReturnTicketCost),
		"Return Ticket",
		1,
		8,
		"BuyPrompt"
	)
	returnPrompt.Triggered:Connect(function(player: Player)
		local Inventory = Registry.find("InventoryService")
		local PlayerState = Registry.find("PlayerStateService")
		local Run = Registry.find("RunDirector")
		local World = Registry.find("WorldService")
		if not Inventory or not PlayerState or not Run or not World or not PlayerState.isHealthy(player) then
			return
		end
		local RunState: Folder = World.RunState
		if RunState:GetAttribute("ReturnTicketUsed") == true then
			Net.notify(player, "Toast", { text = 'Rosie: "One per night, hon. That\'s the rule."' })
			return
		end
		local lost: Player? = nil
		for _, other in Run.runPlayers() do
			if PlayerState.state(other) == "Static" then
				lost = other
				break
			end
		end
		if not lost then
			Net.notify(player, "Toast", { text = 'Rosie: "Nobody needs bringing back. Yet."' })
			return
		end
		if not Inventory.spendTransfers(player, Config.Tuning.Player.ReturnTicketCost) then
			Net.notify(player, "Toast", { text = "Not enough transfers." })
			return
		end
		RunState:SetAttribute("ReturnTicketUsed", true)
		local character = lost.Character
		if character then
			Run.placeInBus(character)
		end
		PlayerState.restore(lost)
		Net.notifyAll("Toast", { text = `{player.DisplayName} bought {lost.DisplayName} a Return Ticket.` })
		Net.notifyAll("Sound", { key = "DoorChime" })
	end)
	-- Menu board on the back wall.
	local lines = {}
	for _, entry in MENU do
		table.insert(lines, string.format("%s  .....  %d", string.upper(defs[entry.id].name), entry.price))
	end
	StopKit.sign(refs, {
		name = "MenuBoard",
		size = Vector3.new(0.3, 5, 9),
		cf = CFrame.new(CENTRE.X + SIZE.X / 2 - 1.2, 9, -2),
		color = C.Black,
		collide = false,
	}, "TRANSFERS ACCEPTED\n" .. table.concat(lines, "\n"), Enum.NormalId.Left, C.White)

	-- Booths along the window. The corner one has the regular; another has place settings
	-- (an anomaly sets a place for every rider).
	local booths = Build.model(refs.model, "Booths")
	local boothCfs = {}
	for i = 0, 3 do
		local cf = CFrame.new(front + 5, 0.4, -6 + i * 9)
		table.insert(boothCfs, cf)
		booth(refs, booths, cf)
	end
	local regular = StopKit.figure(
		refs,
		"Regular",
		boothCfs[4] * CFrame.new(0, 0.6, 3.2) * CFrame.Angles(0, math.pi, 0),
		Color3.fromRGB(90, 80, 60),
		nil,
		{ pants = Color3.fromRGB(50, 45, 40) }
	)
	local emptyCup = StopKit.part(refs, {
		name = "ColdCoffee",
		size = Vector3.new(0.5, 0.7, 0.5),
		cf = boothCfs[4] * CFrame.new(0.8, 3.4, 1),
		color = Color3.fromRGB(240, 240, 235),
		collide = false,
	})
	local gone = Build.model(refs.model, "RegularGone")
	emptyCup.Parent = gone
	StopKit.slot(refs, "regular", regular, { diner_regular_gone = gone :: Instance })
	refs.extras.regular = regular
	local settings = Build.model(refs.model, "PlaceSettings")
	for i = 0, 3 do
		StopKit.part(refs, {
			name = "Plate",
			size = Vector3.new(0.1, 1.4, 1.4),
			cf = boothCfs[2]
				* CFrame.new(-1.2 + (i % 2) * 2.4, 3.1, -1 + (i // 2) * 2)
				* CFrame.Angles(0, 0, math.rad(90)),
			color = C.White,
			shape = Enum.PartType.Cylinder,
			collide = false,
		}, settings)
	end
	local napkin = StopKit.marker(refs, "BoothSlot", boothCfs[2] * CFrame.new(0, 3.1, 0))
	StopKit.slot(refs, "booth", napkin, { diner_place_settings = settings :: Instance })

	-- The jukebox (an anomaly plays it by itself).
	local jukebox = StopKit.box(
		refs,
		"Jukebox",
		CFrame.new(front + 3, 3, -24),
		Vector3.new(2.6, 6, 4),
		Color3.fromRGB(150, 60, 30),
		Enum.Material.Wood
	)
	local glow = StopKit.part(refs, {
		name = "JukeboxGlow",
		size = Vector3.new(0.2, 3, 3),
		cf = CFrame.new(front + 4.35, 4, -24),
		color = Color3.fromRGB(255, 160, 60),
		material = Enum.Material.Neon,
		collide = false,
	})
	Build.light(glow, "Point", Color3.fromRGB(255, 160, 60), 0.7, 8, false)
	StopKit.slot(refs, "jukebox", jukebox)

	-- A few things lying around, and the kitchen pass-through.
	StopKit.lootPoint(refs, Vector3.new(counterX, 4.6, -18))
	StopKit.lootPoint(refs, Vector3.new(front + 5, 3.4, 12))
	StopKit.lootPoint(refs, Vector3.new(front + 5, 3.4, -6))
	StopKit.lootPoint(refs, Vector3.new(CENTRE.X + 15, 1.5, 20))
	StopKit.lootPoint(refs, Vector3.new(CENTRE.X + 15, 1.5, -22))
	StopKit.lootPoint(refs, Vector3.new(front + 10, 1.5, 24))

	StopKit.trailhead(refs, CFrame.new(96, 0, 56))
	StopKit.backEntrance(refs, CFrame.new(96, 3, -56))

	refs.extras.custom = {
		rosie_no_reflection = function()
			refs.extras.noReflection = true
			StopKit.setShown(reflection, false)
		end,
	}
	return refs
end
