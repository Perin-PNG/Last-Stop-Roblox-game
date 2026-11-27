--!strict
-- Builds road geometry along a list of path points (the road centreline). The road frame
-- is the path CFrame: -Z is forward, +X is the curb side (bus lane and sidewalk), -X is the
-- far side (shoulder). The road surface is at y = 0 of the frame.
--
-- Every chunk kind is built here: straight, curve, hill, bridge, tunnel, overpass. Stops
-- use a straight with no right-hand ground; the stop builder adds its own lot.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Build = require(Shared.Util.Build)
local Seed = require(Shared.Util.Seed)
local Config = require(Shared.Config)

local C = Build.Colors
local Tuning = Config.Tuning.Chunks

local RoadBuilder = {}

local W = Tuning.RoadWidth
local HALF = W / 2
local SIDEWALK = Tuning.SidewalkWidth
local SHOULDER = 6
local GRASS = 170
local SEG_POINTS = 4 -- path points per road segment (points are 6 studs apart)

RoadBuilder.Width = W
RoadBuilder.Half = HALF
RoadBuilder.Sidewalk = SIDEWALK

export type SurfaceOptions = {
	groundLeft: boolean?,
	groundRight: boolean?,
	sidewalk: boolean?,
	shoulder: boolean?,
	thick: number?, -- slab thickness (bridges are thicker)
	railings: boolean?,
	lines: boolean?,
}

local function segmentFrame(a: CFrame, b: CFrame): (CFrame, number)
	local mid = (a.Position + b.Position) / 2
	local delta = b.Position - a.Position
	local len = delta.Magnitude
	if len < 0.01 then
		return a, 0
	end
	local up = (a.UpVector + b.UpVector).Unit
	return CFrame.lookAt(mid, b.Position, up), len
end

-- The segments along the points: list of (frame at segment middle, length).
function RoadBuilder.segments(points: { CFrame }, every: number?): { { cf: CFrame, len: number } }
	local out = {}
	local step = every or SEG_POINTS
	local n = #points
	local i = 1
	while i < n do
		local j = math.min(i + step, n)
		local cf, len = segmentFrame(points[i], points[j])
		if len > 0 then
			table.insert(out, { cf = cf, len = len })
		end
		i = j
	end
	return out
end

local function isFlatStraight(points: { CFrame }): boolean
	local n = #points
	if n < 2 then
		return false
	end
	local first, last = points[1], points[n]
	local dir = (last.Position - first.Position).Unit
	if math.abs(dir.Y) > 0.001 then
		return false
	end
	for i = 2, n - 1 do
		local p = points[i].Position - first.Position
		local along = p:Dot(dir)
		local off = (p - dir * along).Magnitude
		if off > 0.05 then
			return false
		end
	end
	return true
end

local function slab(parent: Instance, cf: CFrame, len: number, opts: SurfaceOptions)
	local thick = opts.thick or 1
	local extra = 0.6
	Build.part(parent, {
		name = "Road",
		size = Vector3.new(W, thick, len + extra),
		cf = cf * CFrame.new(0, -thick / 2, 0),
		color = C.Asphalt,
		material = Enum.Material.Asphalt,
		group = "World",
	})
	if opts.lines ~= false then
		for _, x in { -HALF + 1.2, HALF - 1.2 } do
			Build.part(parent, {
				name = "EdgeLine",
				size = Vector3.new(0.5, 0.05, len + extra),
				cf = cf * CFrame.new(x, 0.02, 0),
				color = C.Lane,
				collide = false,
				query = false,
				group = "World",
			})
		end
	end
	if opts.shoulder ~= false then
		Build.part(parent, {
			name = "Shoulder",
			size = Vector3.new(SHOULDER, 1, len + extra),
			cf = cf * CFrame.new(-HALF - SHOULDER / 2, -0.62, 0),
			color = Color3.fromRGB(70, 64, 58),
			material = Enum.Material.Ground,
			group = "World",
		})
	end
	if opts.sidewalk ~= false then
		Build.part(parent, {
			name = "Sidewalk",
			size = Vector3.new(SIDEWALK, 1.2, len + extra),
			cf = cf * CFrame.new(HALF + SIDEWALK / 2, 0.6 - 0.6, 0),
			color = C.Concrete,
			material = Enum.Material.Concrete,
			group = "World",
		})
		Build.part(parent, {
			name = "Curb",
			size = Vector3.new(0.6, 1.25, len + extra),
			cf = cf * CFrame.new(HALF + 0.3, 0.02, 0),
			color = C.Curb,
			material = Enum.Material.Concrete,
			group = "World",
		})
	end
	if opts.groundLeft ~= false then
		Build.part(parent, {
			name = "Ground",
			size = Vector3.new(GRASS, 1, len + 2),
			cf = cf * CFrame.new(-HALF - SHOULDER - GRASS / 2, -0.8, 0),
			color = C.Grass,
			material = Enum.Material.Grass,
			group = "World",
		})
	end
	if opts.groundRight ~= false then
		Build.part(parent, {
			name = "Ground",
			size = Vector3.new(GRASS, 1, len + 2),
			cf = cf * CFrame.new(HALF + SIDEWALK + GRASS / 2, -0.8, 0),
			color = C.Grass,
			material = Enum.Material.Grass,
			group = "World",
		})
	end
	if opts.railings then
		for _, x in { -HALF - 0.6, HALF + 0.6 } do
			Build.part(parent, {
				name = "Railing",
				size = Vector3.new(0.6, 3, len + extra),
				cf = cf * CFrame.new(x, 1.5, 0),
				color = C.Concrete,
				material = Enum.Material.Concrete,
				group = "World",
			})
		end
	end
end

-- Dashed centre line, one dash per segment.
local function dashes(parent: Instance, points: { CFrame })
	for _, seg in RoadBuilder.segments(points, 4) do
		Build.part(parent, {
			name = "Dash",
			size = Vector3.new(0.5, 0.05, 8),
			cf = seg.cf * CFrame.new(0, 0.02, 0),
			color = C.Lane,
			collide = false,
			query = false,
			group = "World",
		})
	end
end

-- Small things that make a night road read as real: cat's eyes on the centre line,
-- reflector posts on the far shoulder, and darker patched asphalt. All decoration.
local function details(parent: Instance, points: { CFrame }, o: SurfaceOptions)
	local n = 0
	for _, seg in RoadBuilder.segments(points, 4) do
		n += 1
		local pos = seg.cf.Position
		local hash = math.floor(math.abs(pos.X * 0.37 + pos.Z * 0.61)) % 7
		if n % 2 == 0 then
			Build.part(parent, {
				name = "CatsEye",
				size = Vector3.new(0.35, 0.08, 0.35),
				cf = seg.cf * CFrame.new(0.6, 0.05, 4),
				color = Color3.fromRGB(255, 196, 90),
				material = Enum.Material.Neon,
				transparency = 0.35,
				collide = false,
				query = false,
				group = "World",
			})
		end
		if o.shoulder ~= false and n % 3 == 0 then
			local post = seg.cf * CFrame.new(-HALF - SHOULDER + 1, 1.6, 0)
			Build.part(parent, {
				name = "ReflectorPost",
				size = Vector3.new(0.35, 3.2, 0.35),
				cf = post,
				color = Color3.fromRGB(225, 225, 220),
				collide = false,
				group = "World",
			})
			Build.part(parent, {
				name = "Reflector",
				size = Vector3.new(0.38, 0.5, 0.2),
				cf = post * CFrame.new(0, 1.1, 0),
				color = Color3.fromRGB(255, 150, 40),
				material = Enum.Material.Neon,
				transparency = 0.2,
				collide = false,
				query = false,
				group = "World",
			})
		end
		if hash == 3 then
			Build.part(parent, {
				name = "Patch",
				size = Vector3.new(4 + hash, 0.04, 3 + hash * 0.5),
				cf = seg.cf * CFrame.new(-HALF * 0.45, 0.01, 0) * CFrame.Angles(0, math.rad(hash * 11), 0),
				color = Color3.fromRGB(30, 30, 33),
				material = Enum.Material.Asphalt,
				collide = false,
				query = false,
				group = "World",
			})
		end
	end
end

-- Road surface along any points.
function RoadBuilder.surface(parent: Instance, points: { CFrame }, opts: SurfaceOptions?)
	local o: SurfaceOptions = opts or {}
	if #points < 2 then
		return
	end
	if isFlatStraight(points) then
		local cf, len = segmentFrame(points[1], points[#points])
		slab(parent, cf, len, o)
	else
		for _, seg in RoadBuilder.segments(points) do
			slab(parent, seg.cf, seg.len, o)
		end
	end
	if o.lines ~= false then
		dashes(parent, points)
		details(parent, points, o)
	end
end

-- A sodium streetlight on the curb side. Returns the lamp part (tagged Streetlight).
function RoadBuilder.streetlight(parent: Instance, at: CFrame, side: number?): BasePart
	local s = side or 1
	local base = at * CFrame.new(s * (HALF + 1.6), 0, 0)
	local model = Build.model(parent, "Streetlight")
	Build.part(model, {
		name = "Pole",
		size = Vector3.new(0.7, 22, 0.7),
		cf = base * CFrame.new(0, 11, 0),
		color = C.DarkMetal,
		material = Enum.Material.Metal,
		group = "World",
	})
	Build.part(model, {
		name = "Arm",
		size = Vector3.new(7, 0.4, 0.4),
		cf = base * CFrame.new(-s * 3.3, 21.8, 0),
		color = C.DarkMetal,
		material = Enum.Material.Metal,
		collide = false,
		group = "World",
	})
	local lamp = Build.part(model, {
		name = "Lamp",
		size = Vector3.new(2.2, 0.5, 1.2),
		cf = base * CFrame.new(-s * 6.4, 21.4, 0),
		color = C.Sodium,
		material = Enum.Material.Neon,
		collide = false,
		group = "World",
		tag = "Streetlight",
	})
	local light = Build.light(lamp, "Spot", C.Sodium, 2.4, 42, false);
	(light :: SpotLight).Angle = 100
	-- Cobra-head housing over the lamp, and a concrete footing.
	Build.part(model, {
		name = "Hood",
		size = Vector3.new(2.8, 0.6, 1.5),
		cf = base * CFrame.new(-s * 6.4, 21.95, 0),
		color = Color3.fromRGB(70, 72, 76),
		material = Enum.Material.Metal,
		collide = false,
		group = "World",
	})
	Build.part(model, {
		name = "Footing",
		size = Vector3.new(1.4, 0.8, 1.4),
		cf = base * CFrame.new(0, 0.4, 0),
		color = C.Concrete,
		material = Enum.Material.Concrete,
		group = "World",
	})
	return lamp
end

local function tree(parent: Instance, at: Vector3, rng: Seed.Rng)
	local h = rng:float(14, 26)
	local trunk = Build.part(parent, {
		name = "Trunk",
		size = Vector3.new(1.4, h, 1.4),
		cf = CFrame.new(at + Vector3.new(0, h / 2 - 0.5, 0)),
		color = Color3.fromRGB(46, 36, 28),
		material = Enum.Material.Wood,
		group = "World",
		query = false,
	})
	local crown = rng:float(9, 15)
	Build.part(parent, {
		name = "Leaves",
		size = Vector3.new(crown, crown * 1.1, crown),
		cf = trunk.CFrame * CFrame.new(0, h / 2 + crown * 0.3, 0) * CFrame.Angles(0, rng:float(0, math.pi), 0),
		color = Color3.fromRGB(20, rng:int(30, 40), 22),
		material = Enum.Material.Grass,
		collide = false,
		query = false,
		group = "World",
	})
end

local function pine(parent: Instance, at: Vector3, rng: Seed.Rng)
	local h = rng:float(20, 34)
	Build.part(parent, {
		name = "Trunk",
		size = Vector3.new(1.2, h * 0.4, 1.2),
		cf = CFrame.new(at + Vector3.new(0, h * 0.2 - 0.5, 0)),
		color = Color3.fromRGB(40, 32, 26),
		material = Enum.Material.Wood,
		query = false,
		group = "World",
	})
	for k = 0, 2 do
		local size = (3 - k) * rng:float(3.4, 4.2)
		Build.part(parent, {
			name = "Needles",
			size = Vector3.new(size, h * 0.3, size),
			cf = CFrame.new(at + Vector3.new(0, h * 0.35 + k * h * 0.22, 0)) * CFrame.Angles(0, rng:float(0, 1.5), 0),
			color = Color3.fromRGB(16, 30, 22),
			material = Enum.Material.Grass,
			collide = false,
			query = false,
			group = "World",
		})
	end
end

local function house(parent: Instance, cf: CFrame, rng: Seed.Rng)
	local w, d, h = rng:float(22, 34), rng:float(18, 26), rng:float(11, 15)
	local body = Build.part(parent, {
		name = "House",
		size = Vector3.new(w, h, d),
		cf = cf * CFrame.new(0, h / 2 - 0.5, 0),
		color = rng:pick({ C.Siding, Color3.fromRGB(110, 100, 90), Color3.fromRGB(80, 90, 100), C.Brick }),
		material = Enum.Material.WoodPlanks,
		group = "World",
	})
	Build.wedge(parent, {
		name = "Roof",
		size = Vector3.new(w + 1, 6, d / 2 + 0.5),
		cf = body.CFrame * CFrame.new(0, h / 2 + 3, -d / 4),
		color = Color3.fromRGB(40, 34, 32),
		group = "World",
	})
	Build.wedge(parent, {
		name = "Roof",
		size = Vector3.new(w + 1, 6, d / 2 + 0.5),
		cf = body.CFrame * CFrame.new(0, h / 2 + 3, d / 4) * CFrame.Angles(0, math.pi, 0),
		color = Color3.fromRGB(40, 34, 32),
		group = "World",
	})
	if rng:chance(0.55) then
		local window = Build.part(parent, {
			name = "LitWindow",
			size = Vector3.new(3, 3.2, 0.2),
			cf = body.CFrame * CFrame.new(rng:float(-w / 3, w / 3), 1, -d / 2 - 0.05),
			color = C.Warm,
			material = Enum.Material.Neon,
			collide = false,
			group = "World",
		})
		if rng:chance(0.4) then
			Build.light(window, "Point", C.Warm, 0.6, 12, false)
		end
	end
end

local function fence(parent: Instance, a: CFrame, len: number, x: number)
	Build.part(parent, {
		name = "Fence",
		size = Vector3.new(0.3, 3.4, len),
		cf = a * CFrame.new(x, 1.2, 0),
		color = Color3.fromRGB(70, 60, 50),
		material = Enum.Material.Wood,
		transparency = 0.3,
		group = "World",
	})
end

local function powerPole(parent: Instance, cf: CFrame, x: number)
	local pole = Build.part(parent, {
		name = "PowerPole",
		size = Vector3.new(1, 28, 1),
		cf = cf * CFrame.new(x, 13.5, 0),
		color = Color3.fromRGB(56, 44, 34),
		material = Enum.Material.Wood,
		group = "World",
	})
	Build.part(parent, {
		name = "CrossArm",
		size = Vector3.new(8, 0.6, 0.6),
		cf = pole.CFrame * CFrame.new(0, 12, 0),
		color = Color3.fromRGB(56, 44, 34),
		material = Enum.Material.Wood,
		collide = false,
		group = "World",
	})
end

-- Scenery beside the road: trees, houses, fences, power poles. Themes follow the tier.
function RoadBuilder.scenery(parent: Instance, points: { CFrame }, rng: Seed.Rng, theme: string, sides: { number }?)
	local useSides: { number } = sides or { -1, 1 }
	local segs = RoadBuilder.segments(points, 8)
	for index, seg in segs do
		for _, side in useSides do
			local edge = if side > 0 then HALF + SIDEWALK else HALF + SHOULDER
			if theme == "farm" then
				if rng:chance(0.5) then
					-- corn rows
					local row = Build.part(parent, {
						name = "Corn",
						size = Vector3.new(36, rng:float(7, 9), seg.len),
						cf = seg.cf * CFrame.new(side * (edge + 30), 3.5, 0),
						color = C.Corn,
						material = Enum.Material.Grass,
						transparency = 0.15,
						collide = false,
						group = "World",
					})
					row.CanQuery = false
				end
				if index % 2 == 0 then
					fence(parent, seg.cf, seg.len, side * (edge + 8))
				end
			elseif theme == "town" then
				if rng:chance(0.45) then
					house(
						parent,
						seg.cf
							* CFrame.new(side * (edge + rng:float(30, 55)), -0.3, 0)
							* CFrame.Angles(0, if side > 0 then -math.pi / 2 else math.pi / 2, 0),
						rng
					)
				elseif rng:chance(0.5) then
					tree(
						parent,
						(seg.cf * CFrame.new(side * (edge + rng:float(12, 40)), -0.3, rng:float(-10, 10))).Position,
						rng
					)
				end
			else -- woods
				local count = rng:int(1, 3)
				for _ = 1, count do
					local pos = (seg.cf * CFrame.new(side * (edge + rng:float(10, 90)), -0.3, rng:float(-20, 20))).Position
					if rng:chance(0.6) then
						pine(parent, pos, rng)
					else
						tree(parent, pos, rng)
					end
				end
			end
			if side < 0 and index % 3 == 0 then
				powerPole(parent, seg.cf, -(HALF + SHOULDER + 3))
			end
		end
	end
end

-- Streetlights every `spacing` studs on the curb side.
function RoadBuilder.streetlights(parent: Instance, points: { CFrame }, spacing: number, offset: number?)
	local n = #points
	if n < 2 then
		return
	end
	local travelled = offset or 0
	local nextAt = 0
	for i = 2, n do
		travelled += (points[i].Position - points[i - 1].Position).Magnitude
		if travelled >= nextAt then
			RoadBuilder.streetlight(parent, points[i])
			nextAt = travelled + spacing
		end
	end
end

function RoadBuilder.tunnel(parent: Instance, points: { CFrame })
	local height = 22
	local wallX = HALF + 8
	for _, seg in RoadBuilder.segments(points) do
		for _, side in { -1, 1 } do
			Build.part(parent, {
				name = "TunnelWall",
				size = Vector3.new(3, height, seg.len + 0.6),
				cf = seg.cf * CFrame.new(side * (wallX + 1.5), height / 2 - 1, 0),
				color = Color3.fromRGB(70, 70, 66),
				material = Enum.Material.Concrete,
				group = "World",
			})
		end
		Build.part(parent, {
			name = "TunnelCeiling",
			size = Vector3.new(wallX * 2 + 6, 3, seg.len + 0.6),
			cf = seg.cf * CFrame.new(0, height + 0.5, 0),
			color = Color3.fromRGB(60, 60, 58),
			material = Enum.Material.Concrete,
			group = "World",
		})
		Build.part(parent, {
			name = "Hillside",
			size = Vector3.new(wallX * 2 + 120, 30, seg.len + 0.6),
			cf = seg.cf * CFrame.new(0, height + 17, 0),
			color = C.Grass,
			material = Enum.Material.Grass,
			group = "World",
			query = false,
		})
	end
	-- Tunnel lights every 40 studs on the ceiling
	local travelled, nextAt = 0, 20
	for i = 2, #points do
		travelled += (points[i].Position - points[i - 1].Position).Magnitude
		if travelled >= nextAt then
			nextAt += 40
			local lamp = Build.part(parent, {
				name = "TunnelLight",
				size = Vector3.new(6, 0.4, 1),
				cf = points[i] * CFrame.new(0, height - 1.2, 0),
				color = C.Sodium,
				material = Enum.Material.Neon,
				collide = false,
				group = "World",
				tag = "TunnelLight",
			})
			Build.light(lamp, "Point", C.Sodium, 1.2, 26, false)
		end
	end
	-- Portals
	for _, index in { 1, #points } do
		local cf = points[index]
		Build.part(parent, {
			name = "Portal",
			size = Vector3.new(wallX * 2 + 14, 10, 4),
			cf = cf * CFrame.new(0, height + 5, 0),
			color = Color3.fromRGB(80, 80, 76),
			material = Enum.Material.Concrete,
			group = "World",
		})
	end
end

function RoadBuilder.bridge(parent: Instance, points: { CFrame })
	local drop = 46
	local segs = RoadBuilder.segments(points)
	for i, seg in segs do
		if i % 3 == 0 then
			for _, x in { -HALF + 4, HALF - 4 } do
				Build.part(parent, {
					name = "Pillar",
					size = Vector3.new(4, drop, 4),
					cf = seg.cf * CFrame.new(x, -drop / 2 - 1.5, 0),
					color = C.Concrete,
					material = Enum.Material.Concrete,
					group = "World",
				})
			end
		end
		Build.part(parent, {
			name = "Water",
			size = Vector3.new(420, 1, seg.len + 1),
			cf = seg.cf * CFrame.new(0, -drop, 0),
			color = C.Water,
			material = Enum.Material.Glass,
			transparency = 0.1,
			reflectance = 0.15,
			group = "World",
		})
	end
end

function RoadBuilder.overpass(parent: Instance, at: CFrame, label: string)
	local h = 24
	local deck = Build.part(parent, {
		name = "OverpassDeck",
		size = Vector3.new(W + 160, 2.5, 26),
		cf = at * CFrame.new(0, h, 0),
		color = C.Concrete,
		material = Enum.Material.Concrete,
		group = "World",
	})
	for _, z in { -12.5, 12.5 } do
		Build.part(parent, {
			name = "OverpassRail",
			size = Vector3.new(W + 160, 3, 1),
			cf = deck.CFrame * CFrame.new(0, 2.6, z),
			color = C.Concrete,
			material = Enum.Material.Concrete,
			group = "World",
		})
	end
	for _, x in { -HALF - 9, HALF + SIDEWALK + 4 } do
		Build.part(parent, {
			name = "OverpassPier",
			size = Vector3.new(4, h, 18),
			cf = at * CFrame.new(x, h / 2 - 0.5, 0),
			color = C.Concrete,
			material = Enum.Material.Concrete,
			group = "World",
		})
	end
	local sign, _ = Build.sign(parent, {
		name = "OverpassSign",
		size = Vector3.new(26, 5, 0.4),
		cf = deck.CFrame * CFrame.new(6, 4.5, 13.4) * CFrame.Angles(0, math.pi, 0),
		color = Color3.fromRGB(20, 80, 50),
		group = "World",
		collide = false,
	}, label, Enum.NormalId.Front)
	sign.Material = Enum.Material.SmoothPlastic
end

return RoadBuilder
