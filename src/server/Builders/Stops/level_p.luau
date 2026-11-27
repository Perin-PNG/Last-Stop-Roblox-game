--!strict
-- Level P∞. A parking garage that only goes down. P1 opens onto the street; the ramps at
-- the back lead to P2 and then P3, where the good loot is (fuel, batteries, the
-- fragment). Each level has two ramp mouths that look the same. One of them is wrong in
-- a small way (its arrow points up, its sign repeats this level, or its exit lamp is
-- red), and taking it puts you back at the top of the level you were on. The stairwell
-- on the lower levels comes straight back up to P1.
-- Headlights patrol P1 and P3. Get behind a pillar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StopKit = require(script.Parent.Parent:WaitForChild("StopKit"))
local Props = require(script.Parent.Parent:WaitForChild("Props"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Build = require(Shared.Util.Build)
local Net = require(Shared.Net)
local Registry = require(script.Parent.Parent.Parent:WaitForChild("Registry"))

local C = Build.Colors

-- Each level's origin in the stop frame. The lower levels are built well away from the
-- street, under the city, so nothing on one level can see or reach another.
local ORIGINS = { Vector3.new(0, 0, 0), Vector3.new(200, -44, 0), Vector3.new(400, -88, 0) }
local X0, X1 = 14, 100
local Z0, Z1 = -56, 56
local CEIL = 11
local RAMP_Z = { -34, 34 }
local CONCRETE = Color3.fromRGB(128, 126, 120)
local PAINT = Color3.fromRGB(220, 210, 120)
local LEVEL_COLORS = { Color3.fromRGB(40, 110, 200), Color3.fromRGB(200, 120, 40), Color3.fromRGB(170, 40, 40) }
local TELLS = { "arrow", "same", "lamp" }
local COOLDOWN = 1.5

type Zone = { level: number, kind: string, ramp: number?, min: Vector3, max: Vector3 }

return function(parent: Instance, frame: CFrame, ctx: StopKit.Ctx, title: string): StopKit.StopRefs
	local refs = StopKit.new(ctx.id, parent, frame)
	StopKit.lot(refs, 14, -60, 60)
	StopKit.sidewalk(refs, -60, 60)
	StopKit.shelter(refs, title)
	StopKit.approachLights(refs)
	refs.passengerSpot = StopKit.marker(refs, "PassengerSpot", CFrame.new(6, 3, -2))

	-- Which ramp is right on P1 and P2, and what's off about the other one.
	local correct = { ctx.rng:int(1, 2), ctx.rng:int(1, 2) }
	local tells = { TELLS[ctx.rng:int(1, #TELLS)], TELLS[ctx.rng:int(1, #TELLS)] }
	local zones: { Zone } = {}

	local function at(level: number, x: number, y: number, z: number): CFrame
		return CFrame.new(ORIGINS[level] + Vector3.new(x, y, z))
	end
	local function zone(level: number, kind: string, ramp: number?, a: Vector3, b: Vector3)
		local o = ORIGINS[level]
		table.insert(zones, { level = level, kind = kind, ramp = ramp, min = o + a, max = o + b })
	end

	local function buildLevel(level: number)
		local m = Build.model(refs.model, "P" .. level)
		local w = X1 - X0
		local d = Z1 - Z0
		local cx, cz = (X0 + X1) / 2, (Z0 + Z1) / 2
		StopKit.part(refs, {
			name = "Deck",
			size = Vector3.new(w, 1, d),
			cf = at(level, cx, -0.1, cz),
			color = CONCRETE,
			material = Enum.Material.Concrete,
		}, m)
		StopKit.part(refs, {
			name = "Ceiling",
			size = Vector3.new(w, 1.2, d),
			cf = at(level, cx, CEIL + 0.6, cz),
			color = Color3.fromRGB(100, 98, 94),
			material = Enum.Material.Concrete,
		}, m)
		-- Walls: the back, both sides, and on the lower levels the front too.
		StopKit.part(refs, {
			name = "BackWall",
			size = Vector3.new(1, CEIL, d),
			cf = at(level, X1 + 0.5, CEIL / 2, cz),
			color = CONCRETE,
			material = Enum.Material.Concrete,
		}, m)
		for _, z in { Z0 - 0.5, Z1 + 0.5 } do
			StopKit.part(refs, {
				name = "SideWall",
				size = Vector3.new(w, CEIL, 1),
				cf = at(level, cx, CEIL / 2, z),
				color = CONCRETE,
				material = Enum.Material.Concrete,
			}, m)
		end
		if level > 1 then
			StopKit.part(refs, {
				name = "FrontWall",
				size = Vector3.new(1, CEIL, d),
				cf = at(level, X0 - 0.5, CEIL / 2, cz),
				color = CONCRETE,
				material = Enum.Material.Concrete,
			}, m)
		else
			-- The street face: a low wall with the entrance gap and a barrier arm.
			for _, seg in { { Z0, -10 }, { 10, Z1 } } do
				StopKit.part(refs, {
					name = "Parapet",
					size = Vector3.new(1, 3.4, seg[2] - seg[1]),
					cf = at(level, X0 - 0.5, 1.7, (seg[1] + seg[2]) / 2),
					color = CONCRETE,
					material = Enum.Material.Concrete,
				}, m)
			end
			StopKit.part(refs, {
				name = "Barrier",
				size = Vector3.new(0.3, 0.3, 9),
				cf = at(level, X0 - 0.5, 3.4, -4) * CFrame.Angles(math.rad(70), 0, 0),
				color = Color3.fromRGB(230, 200, 40),
				collide = false,
			}, m)
			local _, sign = StopKit.sign(refs, {
				name = "GarageSign",
				size = Vector3.new(0.4, 2.6, 20),
				cf = at(level, X0 - 1, CEIL + 2.6, 0),
				color = Color3.fromRGB(20, 30, 50),
				collide = false,
			}, "PUBLIC PARKING  \u{25BC}", Enum.NormalId.Left, C.White, m)
			sign.Font = Enum.Font.GothamBlack
		end
		-- Pillars on a grid, the cover that matters.
		for x = 30, 86, 18 do
			for _, z in { -40, -14, 14, 40 } do
				StopKit.part(refs, {
					name = "Pillar",
					size = Vector3.new(2.4, CEIL, 2.4),
					cf = at(level, x, CEIL / 2, z),
					color = Color3.fromRGB(150, 148, 140),
					material = Enum.Material.Concrete,
				}, m)
				StopKit.part(refs, {
					name = "PillarBand",
					size = Vector3.new(2.5, 1.2, 2.5),
					cf = at(level, x, 4, z),
					color = LEVEL_COLORS[level],
					collide = false,
				}, m)
			end
		end
		-- Bay lines along both sides of the drive aisle.
		for x = 22, 94, 9 do
			for _, z in { -26, 26 } do
				StopKit.part(refs, {
					name = "BayLine",
					size = Vector3.new(0.3, 0.05, 14),
					cf = at(level, x, 0.42, z),
					color = PAINT,
					collide = false,
				}, m)
			end
		end
		-- Lights: P1 is bright, the deeper you go the fewer work.
		local i = 0
		for x = 22, 92, 14 do
			for _, z in { -24, 0, 24 } do
				i += 1
				if level == 1 or (i % (level + 1)) ~= 0 then
					StopKit.ceilingLight(
						refs,
						ORIGINS[level] + Vector3.new(x, CEIL - 0.3, z),
						if level == 3 then Color3.fromRGB(220, 240, 200) else C.Fluor,
						20,
						m
					)
				end
			end
		end
		-- The big level marker painted on the back wall.
		local levelPart, levelLabel = StopKit.sign(refs, {
			name = "LevelSign",
			size = Vector3.new(0.3, 4, 6),
			cf = at(level, X1 - 0.2, 6, 0),
			color = LEVEL_COLORS[level],
			collide = false,
		}, "P" .. level, Enum.NormalId.Left, C.White, m)
		levelLabel.Font = Enum.Font.GothamBlack
		if level == 2 then
			StopKit.slot(refs, "level_sign", levelPart)
		end
		-- An indoor zone, for the echo.
		local indoor = StopKit.part(refs, {
			name = "IndoorZone",
			size = Vector3.new(w, CEIL, d),
			cf = at(level, cx, CEIL / 2, cz),
			transparency = 1,
			collide = false,
			query = false,
		}, m)
		indoor:SetAttribute("Indoor", "Garage")
		table.insert(refs.interior, indoor)

		-- Ramps down (not on the bottom level).
		if level < #ORIGINS then
			for r, z in RAMP_Z do
				local right = correct[level] == r
				local tell = if right then nil else tells[level]
				StopKit.part(refs, {
					name = "RampMouth",
					size = Vector3.new(10, CEIL - 2, 10),
					cf = at(level, X1 - 5, (CEIL - 2) / 2 + 2, z),
					color = Color3.fromRGB(8, 8, 10),
					material = Enum.Material.SmoothPlastic,
					collide = false,
					query = false,
					transparency = 0.15,
					cast = false,
				}, m)
				StopKit.wedge(refs, {
					name = "RampSlope",
					size = Vector3.new(10, 2, 10),
					cf = at(level, X1 - 5, 1, z) * CFrame.Angles(0, math.rad(90), 0),
					color = Color3.fromRGB(110, 108, 100),
					material = Enum.Material.Concrete,
					collide = false,
				}, m)
				local arrow = if tell == "arrow" then "\u{25B2}" else "\u{25BC}"
				local nextLevel = if tell == "same" then level else level + 1
				local _, rampLabel = StopKit.sign(refs, {
					name = "RampSign",
					size = Vector3.new(0.3, 1.6, 6),
					cf = at(level, X1 - 10.4, CEIL - 1.4, z),
					color = Color3.fromRGB(20, 20, 24),
					collide = false,
				}, arrow .. " P" .. nextLevel, Enum.NormalId.Left, Color3.fromRGB(255, 220, 80), m)
				rampLabel.Font = Enum.Font.GothamBlack
				local lampColor = if tell == "lamp" then Color3.fromRGB(255, 40, 30) else Color3.fromRGB(60, 255, 90)
				local lamp = StopKit.part(refs, {
					name = "RampLamp",
					size = Vector3.new(0.4, 0.6, 1.4),
					cf = at(level, X1 - 10.4, CEIL - 3, z + 4),
					color = lampColor,
					material = Enum.Material.Neon,
					collide = false,
				}, m)
				Build.light(lamp, "Point", lampColor, 0.8, 10, false)
				zone(level, "ramp", r, Vector3.new(X1 - 7, -1, z - 4.5), Vector3.new(X1, 8, z + 4.5))
			end
		end
		-- The stairwell back up to P1 (lower levels).
		if level > 1 then
			StopKit.part(refs, {
				name = "StairDoor",
				size = Vector3.new(4, 7.5, 0.4),
				cf = at(level, 22, 3.75, Z1 - 0.2),
				color = Color3.fromRGB(60, 120, 80),
				material = Enum.Material.Metal,
				collide = false,
			}, m)
			local _, exitLabel = StopKit.sign(refs, {
				name = "ExitSign",
				size = Vector3.new(3, 0.8, 0.3),
				cf = at(level, 22, 8.2, Z1 - 0.4),
				color = Color3.fromRGB(10, 40, 10),
				material = Enum.Material.Neon,
				collide = false,
			}, "STAIRS \u{25B2} P1", Enum.NormalId.Front, Color3.fromRGB(120, 255, 140), m)
			exitLabel.Font = Enum.Font.GothamBold
			zone(level, "stairs", nil, Vector3.new(19.5, -1, Z1 - 3), Vector3.new(24.5, 8, Z1 + 1))
			StopKit.hidingSpot(refs, at(level, 30, 2, Z1 - 4))
		end
	end

	for level = 1, #ORIGINS do
		buildLevel(level)
	end

	-- Cars. P1 is mostly full, the levels below thin out. One on P3 still has its
	-- headlights on and the engine warm.
	local carColors = {
		Color3.fromRGB(150, 30, 30),
		Color3.fromRGB(40, 60, 110),
		Color3.fromRGB(180, 180, 175),
		Color3.fromRGB(30, 30, 32),
		Color3.fromRGB(90, 110, 70),
	}
	local n = 0
	for level = 1, #ORIGINS do
		for x = 26.5, 91, 9 do
			for _, z in { -33, 33 } do
				n += 1
				if ctx.rng:chance(if level == 1 then 0.6 else 0.35) then
					local flip = if z < 0 then 0 else 180
					StopKit.car(
						refs,
						"Car",
						at(level, x, 0.4, z) * CFrame.Angles(0, math.rad(flip), 0),
						carColors[(n % #carColors) + 1]
					)
				end
			end
		end
	end

	-- The pay station on P1 with the stub stuck in it, and loot on every level.
	StopKit.box(
		refs,
		"PayStation",
		at(1, 18, 3.2, 12),
		Vector3.new(2, 5.6, 2.4),
		Color3.fromRGB(40, 90, 150),
		Enum.Material.Metal
	)
	StopKit.lore(refs, "levelp_stub", at(1, 19.1, 4.6, 12) * CFrame.Angles(0, math.rad(90), 0), true)
	StopKit.lootPoint(refs, ORIGINS[1] + Vector3.new(20, 1.4, -50))
	StopKit.lootPoint(refs, ORIGINS[1] + Vector3.new(60, 1.4, 52))
	StopKit.lootPoint(refs, ORIGINS[1] + Vector3.new(84, 1.4, -2))
	StopKit.lootPoint(refs, ORIGINS[2] + Vector3.new(30, 1.4, -52), "fuel")
	StopKit.lootPoint(refs, ORIGINS[2] + Vector3.new(66, 1.4, 4))
	StopKit.lootPoint(refs, ORIGINS[2] + Vector3.new(90, 1.4, 52), "battery")
	StopKit.lootPoint(refs, ORIGINS[2] + Vector3.new(48, 1.4, -2))
	StopKit.lootPoint(refs, ORIGINS[3] + Vector3.new(96, 1.4, -52), "fuel")
	StopKit.lootPoint(refs, ORIGINS[3] + Vector3.new(96, 1.4, 52), "fuel")
	StopKit.lootPoint(refs, ORIGINS[3] + Vector3.new(60, 1.4, 0), "battery")
	StopKit.lootPoint(refs, ORIGINS[3] + Vector3.new(30, 1.4, -20))
	StopKit.lootPoint(refs, ORIGINS[3] + Vector3.new(76, 1.4, 22))
	StopKit.fragmentSite(refs, ORIGINS[3] + Vector3.new(97, 1.5, 0))
	StopKit.hidingSpot(refs, at(1, 96, 2, -50))
	StopKit.hidingSpot(refs, at(3, 96, 2, 20))

	-- A dropped glove on P1's floor. Normally it isn't there; see the anomaly list.
	local glove = Build.model(refs.model, "Glove")
	StopKit.part(refs, {
		name = "Glove",
		size = Vector3.new(0.8, 0.2, 1.1),
		cf = at(1, 44, 0.5, -6),
		color = Color3.fromRGB(240, 240, 235),
		collide = false,
	}, glove)
	StopKit.slot(
		refs,
		"floor",
		StopKit.marker(refs, "FloorSlot", at(1, 44, 0.5, -6)),
		{ levelp_glove = glove :: Instance }
	)
	-- P1's ticket barrier arm: up when normal, down (and red) on the anomaly.
	local arm = refs.model:FindFirstChild("P1")
		and (refs.model:FindFirstChild("P1") :: Instance):FindFirstChild("Barrier")
	if arm then
		local dropped = Build.model(refs.model, "BarrierDown")
		StopKit.part(refs, {
			name = "Barrier",
			size = Vector3.new(0.3, 0.3, 9),
			cf = at(1, X0 - 0.5, 3.4, -4 + 4.5) * CFrame.new(0, 0, 0),
			color = Color3.fromRGB(200, 40, 30),
			collide = false,
		}, dropped)
		StopKit.slot(refs, "barrier", arm, { levelp_barrier = dropped :: Instance })
	end

	-- A car on P2 with its engine running and nobody in it.
	StopKit.slot(refs, "warm_car", StopKit.marker(refs, "WarmCar", at(2, 62, 2, 33)))

	-- Headlights: one car circles P1, one circles P3.
	local function lane(level: number): any
		local o = ORIGINS[level]
		return {
			route = {
				o + Vector3.new(22, 1, -20),
				o + Vector3.new(92, 1, -20),
				o + Vector3.new(92, 1, 20),
				o + Vector3.new(22, 1, 20),
			},
			bounds = { min = o + Vector3.new(X0 + 2, 0, Z0 + 2), max = o + Vector3.new(X1 - 2, 0, Z1 - 2) },
		}
	end
	refs.extras.headlightLanes = { lane(1), lane(3) }
	refs.extras.entityCount = if ctx.tier >= 3 then 2 else 1
	StopKit.entitySpawn(refs, at(1, 92, 3, -20) * CFrame.Angles(0, math.rad(90), 0))
	StopKit.entitySpawn(refs, at(3, 22, 3, 20) * CFrame.Angles(0, math.rad(-90), 0))

	-- Ramps and stairs: polled while the doors are open.
	local token = 0
	local last: { [Player]: number } = {}
	local function send(player: Player, level: number, x: number, z: number, facing: number)
		local character = player.Character
		if not character then
			return
		end
		last[player] = os.clock()
		character:PivotTo(refs.frame * at(level, x, 3.2, z) * CFrame.Angles(0, math.rad(facing), 0))
	end
	refs.extras.activate = function(built: any)
		token += 1
		local mine = token
		local PlayerState = Registry.find("PlayerStateService")
		local Dread = Registry.find("DreadService")
		task.spawn(function()
			while mine == token and built.active ~= false do
				for _, player in Players:GetPlayers() do
					local root = PlayerState and PlayerState.rootOf(player)
					if root and PlayerState.isActive(player) and os.clock() - (last[player] or 0) > COOLDOWN then
						local p = refs.frame:PointToObjectSpace(root.Position)
						for _, z in zones do
							if
								p.X >= z.min.X
								and p.X <= z.max.X
								and p.Y >= z.min.Y
								and p.Y <= z.max.Y
								and p.Z >= z.min.Z
								and p.Z <= z.max.Z
							then
								if z.kind == "stairs" then
									send(player, 1, 24, 46, 180)
									Net.notify(player, "Toast", { text = "P1. The street is right there." })
								elseif z.ramp == correct[z.level] then
									send(player, z.level + 1, 24, 0, -90)
									Net.notify(player, "Toast", { text = "P" .. (z.level + 1) .. "." })
									Net.notifyAll("Sound", { key = "Sting", part = root })
								else
									-- The wrong ramp comes out at the top of the same level.
									send(player, z.level, 24, 0, -90)
									Net.notify(player, "Toast", { text = "P" .. z.level .. ". Again." })
									if Dread then
										Dread.add(player, 10)
									end
								end
								break
							end
						end
					end
				end
				task.wait(0.25)
			end
		end)
	end
	refs.extras.deactivate = function()
		token += 1
		table.clear(last)
	end

	local _ = Props
	StopKit.trailhead(refs, CFrame.new(10, 0, 64))
	StopKit.backEntrance(refs, CFrame.new(10, 3, -62))
	return refs
end
