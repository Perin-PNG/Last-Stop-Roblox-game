--!strict
-- Northgate Mall, closed for the night. One concourse runs from the doors to the back,
-- shops on both sides, a dry fountain in the middle. The mannequins only move while
-- nobody is looking at them; keep someone watching, and back away together.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StopKit = require(script.Parent.Parent:WaitForChild("StopKit"))
local Props = require(script.Parent.Parent:WaitForChild("Props"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Build = require(Shared.Util.Build)
local Net = require(Shared.Net)
local Registry = require(script.Parent.Parent.Parent:WaitForChild("Registry"))

local C = Build.Colors

local CENTRE = Vector3.new(70, 9, 0)
local SIZE = Vector3.new(64, 18, 108)
local HALL = 8 -- half-width of the concourse (z in [-HALL, HALL])
local UNIT_X = { 40, 56, 72, 88 } -- each shop spans x in [UNIT_X[i], UNIT_X[i] + 16]
local TILE = Color3.fromRGB(205, 200, 190)
local PLASTIC = Color3.fromRGB(225, 215, 200)

type Shop = { name: string, color: Color3, gate: boolean? }

local NORTH: { Shop } = {
	{ name = "QUIK PHOTO", color = Color3.fromRGB(230, 180, 40) },
	{ name = "BOOK NOOK", color = Color3.fromRGB(110, 70, 50) },
	{ name = "SIGNAL ELECTRONICS", color = Color3.fromRGB(40, 90, 170) },
	{ name = "COMING SOON", color = Color3.fromRGB(90, 90, 90), gate = true },
}
local SOUTH: { Shop } = {
	{ name = "LACE & CO", color = Color3.fromRGB(170, 70, 110) },
	{ name = "TOY ATTIC", color = Color3.fromRGB(200, 60, 50) },
	{ name = "SHOE BARN", color = Color3.fromRGB(120, 90, 60) },
	{ name = "PRETZEL HUT", color = Color3.fromRGB(210, 140, 50) },
}

return function(parent: Instance, frame: CFrame, ctx: StopKit.Ctx, title: string): StopKit.StopRefs
	local refs = StopKit.new(ctx.id, parent, frame)
	StopKit.basics(refs, title, 112, -72, 72)
	local front = CENTRE.X - SIZE.X / 2
	local back = CENTRE.X + SIZE.X / 2
	local zMin = CENTRE.Z - SIZE.Z / 2
	local zMax = CENTRE.Z + SIZE.Z / 2
	local building = StopKit.building(refs, "Mall", CENTRE, SIZE, Color3.fromRGB(175, 165, 150), 10, 0)
	for _, d in building:GetChildren() do
		if d:IsA("BasePart") and (d.Name == "Wall" or d.Name == "Front" or d.Name == "Lintel") then
			d.Material = Enum.Material.Concrete
		end
	end
	-- Entrance canopy and the big sign.
	StopKit.part(refs, {
		name = "Canopy",
		size = Vector3.new(8, 1, 22),
		cf = CFrame.new(front - 4, 12, 0),
		color = Color3.fromRGB(60, 60, 64),
		material = Enum.Material.Metal,
	})
	local _, mallLabel = StopKit.sign(refs, {
		name = "MallSign",
		size = Vector3.new(0.5, 4, 34),
		cf = CFrame.new(front - 0.5, 15.5, 0),
		color = Color3.fromRGB(30, 30, 34),
		collide = false,
	}, "NORTHGATE MALL", Enum.NormalId.Left, Color3.fromRGB(120, 200, 255))
	mallLabel.Font = Enum.Font.GothamBlack
	for _, z in { -30, -20, 20, 30 } do
		Props.window(refs, CFrame.new(front - 0.6, 6, z), Vector2.new(6, 5), false)
	end
	StopKit.part(refs, {
		name = "Floor",
		size = Vector3.new(SIZE.X - 2, 0.05, SIZE.Z - 2),
		cf = CFrame.new(CENTRE.X, 0.45, CENTRE.Z),
		color = TILE,
		material = Enum.Material.Marble,
		collide = false,
	})
	-- Skylights down the concourse, a strip of dim emergency lights.
	for x = front + 6, back - 6, 10 do
		StopKit.part(refs, {
			name = "Skylight",
			size = Vector3.new(6, 0.2, 10),
			cf = CFrame.new(x, 17.7, 0),
			color = Color3.fromRGB(40, 50, 70),
			material = Enum.Material.Glass,
			transparency = 0.3,
			collide = false,
		})
		StopKit.ceilingLight(refs, Vector3.new(x, 17.2, HALL - 1), Color3.fromRGB(190, 200, 220), 14)
	end

	-- Shops.
	local displaySlot: Instance? = nil
	local extraMannequin: Model? = nil
	local lureHand: BasePart? = nil
	local function shopRow(list: { Shop }, side: number)
		local zFront = side * HALL
		local zBack = if side > 0 then zMax - 1 else zMin + 1
		local depth = math.abs(zBack - zFront)
		local zMid = (zFront + zBack) / 2
		for i, shop in list do
			local x0 = UNIT_X[i]
			local x1 = x0 + 16
			if i < #list then
				StopKit.part(refs, {
					name = "Divider",
					size = Vector3.new(0.6, 17, depth),
					cf = CFrame.new(x1, 9, zMid),
					color = Color3.fromRGB(190, 185, 175),
					material = Enum.Material.Concrete,
				})
			end
			-- Front: pillars at the ends, glass to one side of a 7-wide opening.
			for _, px in { x0 + 0.5, x1 - 0.5 } do
				StopKit.part(refs, {
					name = "Pillar",
					size = Vector3.new(1, 17, 1),
					cf = CFrame.new(px, 9, zFront),
					color = Color3.fromRGB(150, 145, 140),
					material = Enum.Material.Concrete,
				})
			end
			StopKit.part(refs, {
				name = "Fascia",
				size = Vector3.new(16, 6, 0.6),
				cf = CFrame.new(x0 + 8, 14.5, zFront),
				color = Color3.fromRGB(150, 145, 140),
				material = Enum.Material.Concrete,
			})
			local _, label = StopKit.sign(refs, {
				name = "ShopSign",
				size = Vector3.new(12, 1.8, 0.3),
				cf = CFrame.new(x0 + 8, 13.6, zFront - side * 0.45),
				color = shop.color,
				collide = false,
			}, shop.name, if side > 0 then Enum.NormalId.Front else Enum.NormalId.Back, C.White)
			label.Font = Enum.Font.GothamBold
			StopKit.part(refs, {
				name = "ShopGlass",
				size = Vector3.new(7, 11, 0.2),
				cf = CFrame.new(x0 + 4.5, 6, zFront),
				color = Color3.fromRGB(170, 200, 210),
				material = Enum.Material.Glass,
				transparency = 0.65,
			})
			if shop.gate then
				StopKit.part(refs, {
					name = "Gate",
					size = Vector3.new(8, 11, 0.2),
					cf = CFrame.new(x0 + 12, 6, zFront),
					color = C.Metal,
					material = Enum.Material.DiamondPlate,
					transparency = 0.3,
				})
			end
			StopKit.part(refs, {
				name = "OpeningHeader",
				size = Vector3.new(8, 0.2, 0.6),
				cf = CFrame.new(x0 + 12, 11.6, zFront),
				color = Color3.fromRGB(150, 145, 140),
			})
			-- Fittings inside, by shop.
			local inner = zFront + side * 6
			if shop.name == "LACE & CO" then
				-- The display: four figures on a plinth behind the glass, and a placard.
				local plinth = StopKit.part(refs, {
					name = "Plinth",
					size = Vector3.new(6.6, 1, 4),
					cf = CFrame.new(x0 + 4.5, 0.9, zFront + side * 2.6),
					color = C.White,
					material = Enum.Material.SmoothPlastic,
				})
				local display = Build.model(refs.model, "Display")
				for k = 0, 3 do
					StopKit.figure(
						refs,
						"DisplayFigure",
						CFrame.new(x0 + 2 + k * 1.7, 1.4, zFront + side * 3)
							* CFrame.Angles(0, if side < 0 then math.rad(180) else 0, 0),
						Color3.fromRGB(150 + k * 20, 90, 120),
						display,
						{ height = 0.55, skin = PLASTIC, pants = PLASTIC }
					)
				end
				local extra = StopKit.figure(
					refs,
					"ExtraFigure",
					CFrame.new(x0 + 5, 1.4, zFront + side * 4.6)
						* CFrame.Angles(0, if side < 0 then math.rad(180) else 0, 0),
					PLASTIC,
					display,
					{ height = 0.55, skin = PLASTIC, pants = PLASTIC }
				)
				StopKit.setShown(extra, false)
				extraMannequin = extra
				local _ = plinth
				StopKit.sign(refs, {
					name = "Placard",
					size = Vector3.new(2, 0.8, 0.1),
					cf = CFrame.new(x0 + 7.6, 1.8, zFront - side * 0.3),
					color = C.White,
					collide = false,
				}, "FALL LOOK: 4 FIGURES", if side > 0 then Enum.NormalId.Front else Enum.NormalId.Back, C.Black)
				displaySlot = display
				for k = 0, 2 do
					StopKit.part(refs, {
						name = "Rack",
						size = Vector3.new(4, 0.2, 0.2),
						cf = CFrame.new(x0 + 8, 5.5, inner + side * k * 4),
						color = C.Metal,
						material = Enum.Material.Metal,
					})
					StopKit.lootPoint(refs, Vector3.new(x0 + 8, 1.4, inner + side * (k * 4 + 1)))
				end
			elseif shop.name == "QUIK PHOTO" then
				Props.counter(refs, CFrame.new(x0 + 8, 0.4, inner + side * 6), Vector3.new(10, 3.6, 2.4), shop.color)
				StopKit.hidingSpot(refs, CFrame.new(x0 + 8, 2, inner + side * 8))
				StopKit.lootPoint(refs, Vector3.new(x0 + 6, 4.4, inner + side * 6), "film")
				-- The lure: a store figure holding out its palm by the counter.
				local holder = StopKit.figure(
					refs,
					"PhotoFigure",
					CFrame.new(x0 + 13.5, 0.4, inner + side * 3) * CFrame.Angles(0, math.rad(90), 0),
					shop.color,
					nil,
					{ skin = PLASTIC, pants = PLASTIC }
				)
				lureHand = holder:FindFirstChild("Hand") :: BasePart?
			elseif shop.name == "BOOK NOOK" then
				for k = 0, 2 do
					Props.shelf(
						refs,
						CFrame.new(x0 + 4 + k * 4, 0.4, inner + side * 12) * CFrame.Angles(0, math.rad(90), 0),
						8,
						8,
						nil,
						60 + k
					)
				end
				StopKit.lootPoint(refs, Vector3.new(x0 + 8, 1.4, inner + side * 9), "book")
			elseif shop.name == "SIGNAL ELECTRONICS" then
				Props.counter(refs, CFrame.new(x0 + 8, 0.4, inner + side * 4), Vector3.new(12, 3.6, 2.4), C.Black)
				for k = 0, 3 do
					local tv, tvLabel = StopKit.sign(refs, {
						name = "WallTV",
						size = Vector3.new(3, 2, 0.3),
						cf = CFrame.new(x0 + 2.5 + k * 3.6, 8, zBack - side * 0.5),
						color = C.Black,
						collide = false,
					}, "", if side > 0 then Enum.NormalId.Front else Enum.NormalId.Back, C.White)
					tvLabel.BackgroundTransparency = 0
					tvLabel.BackgroundColor3 = Color3.fromRGB(20, 26, 40)
					local _ = tv
				end
				StopKit.lootPoint(refs, Vector3.new(x0 + 8, 4.4, inner + side * 4), "battery")
				StopKit.lootPoint(refs, Vector3.new(x0 + 4, 1.4, inner + side * 12), "radio")
				StopKit.hidingSpot(refs, CFrame.new(x0 + 8, 2, inner + side * 6))
			elseif shop.name == "TOY ATTIC" then
				for k = 0, 1 do
					Props.shelf(
						refs,
						CFrame.new(x0 + 5 + k * 6, 0.4, inner + side * 10) * CFrame.Angles(0, math.rad(90), 0),
						10,
						6,
						nil,
						70 + k
					)
				end
				StopKit.lootPoint(refs, Vector3.new(x0 + 8, 1.4, inner + side * 6))
			elseif shop.name == "SHOE BARN" then
				for k = 0, 2 do
					StopKit.part(refs, {
						name = "Bench",
						size = Vector3.new(4, 1.6, 1.6),
						cf = CFrame.new(x0 + 4 + k * 4.5, 1.2, inner + side * 8),
						color = Color3.fromRGB(90, 60, 40),
						material = Enum.Material.Leather,
					})
				end
				StopKit.lootPoint(refs, Vector3.new(x0 + 8, 2.4, inner + side * 8))
				StopKit.hidingSpot(refs, CFrame.new(x0 + 12, 2, zBack - side * 3))
			elseif shop.name == "PRETZEL HUT" then
				Props.counter(refs, CFrame.new(x0 + 8, 0.4, inner), Vector3.new(12, 3.8, 2.4), shop.color)
				StopKit.lootPoint(refs, Vector3.new(x0 + 6, 4.6, inner), "food")
				StopKit.lootPoint(refs, Vector3.new(x0 + 10, 4.6, inner), "coffee")
				StopKit.hidingSpot(refs, CFrame.new(x0 + 8, 2, inner + side * 2.5))
			elseif shop.name == "COMING SOON" then
				StopKit.fragmentSite(refs, Vector3.new(x0 + 8, 1.5, zBack - side * 4))
				for k = 0, 2 do
					StopKit.box(
						refs,
						"Crate",
						CFrame.new(x0 + 3 + k * 4, 1.9, inner + side * 8),
						Vector3.new(3, 3, 3),
						C.Wood
					)
				end
			end
		end
	end
	shopRow(NORTH, 1)
	shopRow(SOUTH, -1)
	if displaySlot and extraMannequin then
		StopKit.slot(refs, "display", displaySlot, { mannequin_extra = extraMannequin :: Instance })
	end

	-- The fountain.
	local fx = 80
	local basin = StopKit.part(refs, {
		name = "Fountain",
		size = Vector3.new(1.2, 10, 10),
		cf = CFrame.new(fx, 1, 0) * CFrame.Angles(0, 0, math.rad(90)),
		color = Color3.fromRGB(190, 185, 175),
		material = Enum.Material.Marble,
		shape = Enum.PartType.Cylinder,
	})
	StopKit.part(refs, {
		name = "FountainBed",
		size = Vector3.new(0.2, 8.6, 8.6),
		cf = CFrame.new(fx, 1.55, 0) * CFrame.Angles(0, 0, math.rad(90)),
		color = Color3.fromRGB(70, 90, 100),
		material = Enum.Material.Slate,
		shape = Enum.PartType.Cylinder,
	})
	StopKit.part(refs, {
		name = "Spout",
		size = Vector3.new(1, 4, 1),
		cf = CFrame.new(fx, 3.6, 0),
		color = Color3.fromRGB(190, 185, 175),
		material = Enum.Material.Marble,
	})
	local scattered = Build.model(refs.model, "Coins")
	local arranged = Build.model(refs.model, "Coins9N")
	local rng = ctx.rng:child("coins")
	for _ = 1, 14 do
		local a = rng:float(0, math.pi * 2)
		local r = rng:float(1, 3.8)
		StopKit.part(refs, {
			name = "Coin",
			size = Vector3.new(0.05, 0.35, 0.35),
			cf = CFrame.new(fx + math.cos(a) * r, 1.67, math.sin(a) * r) * CFrame.Angles(0, 0, math.rad(90)),
			color = Color3.fromRGB(200, 170, 80),
			material = Enum.Material.Metal,
			shape = Enum.PartType.Cylinder,
			collide = false,
		}, scattered)
	end
	-- "9N" in coins: a 3x5 dot pattern for each glyph.
	local glyphs = {
		{ "###", "#.#", "###", "..#", "###" },
		{ "#.#", "###", "###", "#.#", "#.#" },
	}
	for g, rows in glyphs do
		for r, row in rows do
			for c = 1, 3 do
				if string.sub(row, c, c) == "#" then
					StopKit.part(refs, {
						name = "Coin",
						size = Vector3.new(0.05, 0.35, 0.35),
						cf = CFrame.new(fx - 1.2 + r * 0.45, 1.67, -2.6 + (g - 1) * 2 + c * 0.45)
							* CFrame.Angles(0, 0, math.rad(90)),
						color = Color3.fromRGB(220, 190, 90),
						material = Enum.Material.Metal,
						shape = Enum.PartType.Cylinder,
						collide = false,
					}, arranged)
				end
			end
		end
	end
	StopKit.setShown(arranged, false)
	StopKit.slot(refs, "fountain", basin, { mall_fountain = arranged :: Instance })
	for _, z in { -5.5, 5.5 } do
		StopKit.part(refs, {
			name = "Planter",
			size = Vector3.new(6, 2.4, 2.4),
			cf = CFrame.new(fx - 14, 1.6, z),
			color = Color3.fromRGB(120, 110, 100),
			material = Enum.Material.Concrete,
		})
		StopKit.hidingSpot(refs, CFrame.new(fx - 14, 2, z - (if z > 0 then 2 else -2)))
	end
	StopKit.lootPoint(refs, Vector3.new(fx - 14, 3.2, 5.5))

	-- The directory by the doors.
	StopKit.part(refs, {
		name = "DirectoryStand",
		size = Vector3.new(1.2, 8, 4),
		cf = CFrame.new(front + 6, 4.4, -5),
		color = Color3.fromRGB(40, 40, 44),
		material = Enum.Material.Metal,
	})
	local dir, dirLabel = StopKit.sign(
		refs,
		{
			name = "Directory",
			size = Vector3.new(0.2, 5, 3.4),
			cf = CFrame.new(front + 5.3, 5, -5),
			color = Color3.fromRGB(230, 235, 240),
			collide = false,
		},
		"QUIK PHOTO  N1\nBOOK NOOK  N2\nSIGNAL  N3\nLACE & CO  S1\nTOY ATTIC  S2\nSHOE BARN  S3",
		Enum.NormalId.Left,
		C.Black
	)
	dirLabel.TextScaled = true
	StopKit.slot(refs, "directory", dir)

	-- Ceiling speakers.
	local speakers = Build.model(refs.model, "Speakers")
	for x = front + 12, back - 8, 16 do
		StopKit.part(refs, {
			name = "Speaker",
			size = Vector3.new(1.6, 0.3, 1.6),
			cf = CFrame.new(x, 17.6, -HALL + 1),
			color = C.White,
			collide = false,
		}, speakers)
	end
	StopKit.slot(refs, "speakers", speakers)

	-- Benches down the concourse, a kiosk cart.
	for _, x in { front + 16, back - 10 } do
		for _, z in { -5, 5 } do
			StopKit.part(refs, {
				name = "Bench",
				size = Vector3.new(6, 1.6, 1.6),
				cf = CFrame.new(x, 1.2, z),
				color = Color3.fromRGB(90, 60, 40),
				material = Enum.Material.Wood,
			})
		end
	end
	Props.counter(refs, CFrame.new(64, 0.4, 0), Vector3.new(5, 3.6, 3), Color3.fromRGB(80, 140, 120))
	StopKit.hidingSpot(refs, CFrame.new(64, 2, 2.5))
	StopKit.lootPoint(refs, Vector3.new(64, 4.4, 0))

	-- Mannequins start scattered: one in each far shop and two on the concourse.
	StopKit.entitySpawn(refs, CFrame.new(back - 6, 3, 0) * CFrame.Angles(0, math.rad(90), 0))
	StopKit.entitySpawn(refs, CFrame.new(UNIT_X[3] + 8, 3, HALL + 14))
	StopKit.entitySpawn(refs, CFrame.new(UNIT_X[2] + 8, 3, -HALL - 14))
	StopKit.entitySpawn(refs, CFrame.new(UNIT_X[4] + 6, 3, -HALL - 10))
	StopKit.entitySpawn(refs, CFrame.new(fx + 8, 3, 4))
	StopKit.entitySpawn(refs, CFrame.new(UNIT_X[1] + 10, 3, HALL + 16))
	StopKit.trailhead(refs, CFrame.new(106, 0, 64))
	StopKit.backEntrance(refs, CFrame.new(106, 3, -64))

	-- The lure: film on a figure's palm. Taking it shakes its hand.
	local filmPart: BasePart? = nil
	refs.extras.custom = {
		mall_lure_film = function(built: any)
			if not lureHand then
				return
			end
			local hand = lureHand
			local film = Build.part(refs.model, {
				name = "FreeFilm",
				size = Vector3.new(0.6, 0.3, 0.8),
				cf = hand.CFrame * CFrame.new(0, -0.45, 0),
				color = Color3.fromRGB(240, 200, 40),
				collide = false,
				group = "World",
			})
			filmPart = film
			local prompt = Build.prompt(film, "Take", "Film", 0, 6, "FilmPrompt")
			prompt.Triggered:Connect(function(player: Player)
				local PlayerState = Registry.find("PlayerStateService")
				if not PlayerState or not PlayerState.isHealthy(player) or built.active == false then
					return
				end
				prompt.Enabled = false
				film:Destroy()
				-- The hand closes on theirs.
				Net.notifyAll("Sound", { key = "PlasticCreak", part = hand })
				PlayerState.down(player, "mannequin")
				Net.notify(player, "Toast", { text = "The hand closes around yours." })
			end)
		end,
	}
	refs.extras.deactivate = function()
		if filmPart and filmPart.Parent then
			filmPart:Destroy()
		end
		filmPart = nil
	end
	local _ = Players
	return refs
end
