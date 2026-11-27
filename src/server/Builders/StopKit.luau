--!strict
-- Shared pieces every stop prefab uses: the lot, the curb zone with its shelter and
-- timetable clock, streetlights the Latecomer puts out, loot points, the fragment site,
-- anomaly slots and the trailhead.
--
-- Stop frame: origin is the curb point (where the bus's middle door lines up), +X points
-- into the lot, -Z is road-forward, +Y is up. The road is at x in [-40, 0], the sidewalk
-- at x in [0, 10]. The Latecomer walks in along the sidewalk from +Z.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Build = require(Shared.Util.Build)
local Seed = require(Shared.Util.Seed)

local C = Build.Colors

local StopKit = {}

export type StopRefs = {
	id: string,
	model: Model,
	frame: CFrame, -- the stop frame (curb point)
	lootPoints: { BasePart },
	fragmentSites: { BasePart },
	slots: { [string]: Instance }, -- anomaly slot name -> object
	streetlights: { BasePart }, -- in order from the far end (+Z) to the curb
	trailhead: BasePart,
	backEntrance: BasePart,
	shelter: Model,
	timetable: TextLabel?,
	entitySpawns: { BasePart },
	hidingSpots: { BasePart },
	passengerSpot: BasePart,
	interior: { BasePart }, -- zone parts for "indoors" (sound, Dread)
	extras: { [string]: any },
}

export type Ctx = {
	rng: Seed.Rng,
	tier: number,
	loopCheck: number?,
	stopIndex: number,
	id: string,
}

function StopKit.new(id: string, parent: Instance, frame: CFrame): StopRefs
	local model = Build.model(parent, "Stop_" .. id)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("StopId", id)
	local marker = Build.part(model, {
		name = "CurbMarker",
		size = Vector3.new(1, 1, 1),
		cf = frame,
		transparency = 1,
		collide = false,
		query = false,
	})
	model.PrimaryPart = marker
	return {
		id = id,
		model = model,
		frame = frame,
		lootPoints = {},
		fragmentSites = {},
		slots = {},
		streetlights = {},
		trailhead = marker,
		backEntrance = marker,
		shelter = model,
		timetable = nil,
		entitySpawns = {},
		hidingSpots = {},
		passengerSpot = marker,
		interior = {},
		extras = {},
	}
end

-- A part in stop-frame coordinates.
function StopKit.part(refs: StopRefs, props: Build.PartProps, parent: Instance?): Part
	local p = table.clone(props)
	p.cf = refs.frame * (props.cf or CFrame.identity)
	if p.group == nil then
		p.group = "World"
	end
	return Build.part(parent or refs.model, p)
end

function StopKit.wedge(refs: StopRefs, props: Build.PartProps, parent: Instance?): WedgePart
	local p = table.clone(props)
	p.cf = refs.frame * (props.cf or CFrame.identity)
	if p.group == nil then
		p.group = "World"
	end
	return Build.wedge(parent or refs.model, p)
end

function StopKit.sign(
	refs: StopRefs,
	props: Build.PartProps,
	text: string,
	face: Enum.NormalId?,
	textColor: Color3?,
	parent: Instance?
): (Part, TextLabel)
	local p = table.clone(props)
	p.cf = refs.frame * (props.cf or CFrame.identity)
	if p.group == nil then
		p.group = "World"
	end
	return Build.sign(parent or refs.model, p, text, face, textColor)
end

-- Flat lot ground from the sidewalk back to `depth`, spanning z in [z0, z1].
function StopKit.lot(refs: StopRefs, depth: number, z0: number, z1: number, color: Color3?, material: Enum.Material?)
	local len = z1 - z0
	StopKit.part(refs, {
		name = "Lot",
		size = Vector3.new(depth, 1, len),
		cf = CFrame.new(10 + depth / 2, -0.5, (z0 + z1) / 2),
		color = color or Color3.fromRGB(48, 48, 50),
		material = material or Enum.Material.Asphalt,
	})
	-- Grass around the lot so the world never ends at the lot edge. The stop chunk's road
	-- runs from z = -220 to z = +300 in the stop frame.
	local far0, far1 = -230, 310
	StopKit.part(refs, {
		name = "Ground",
		size = Vector3.new(200, 1, far1 - far0),
		cf = CFrame.new(10 + depth + 100, -0.8, (far0 + far1) / 2),
		color = C.Grass,
		material = Enum.Material.Grass,
	})
	for _, span in { { far0, z0 }, { z1, far1 } } do
		local a, b = span[1], span[2]
		if b - a > 1 then
			StopKit.part(refs, {
				name = "Ground",
				size = Vector3.new(depth + 0.2, 1, b - a),
				cf = CFrame.new(10 + depth / 2, -0.8, (a + b) / 2),
				color = C.Grass,
				material = Enum.Material.Grass,
			})
		end
	end
end

-- The sidewalk along the curb from z0 to z1 (on top of the road builder's sidewalk, wider
-- at the stop).
function StopKit.sidewalk(refs: StopRefs, z0: number, z1: number)
	StopKit.part(refs, {
		name = "StopSidewalk",
		size = Vector3.new(10, 0.2, z1 - z0),
		cf = CFrame.new(5, 0.62, (z0 + z1) / 2),
		color = Color3.fromRGB(120, 120, 122),
		material = Enum.Material.Concrete,
	})
end

-- The bus shelter at the curb, with a timetable that shows the departure clock.
function StopKit.shelter(refs: StopRefs, title: string, z: number?): Model
	local zc = z or -8
	local shelter = Build.model(refs.model, "Shelter")
	local roof = StopKit.part(refs, {
		name = "Roof",
		size = Vector3.new(6, 0.4, 12),
		cf = CFrame.new(6.5, 9.2, zc),
		color = C.DarkMetal,
		material = Enum.Material.Metal,
	}, shelter)
	roof.CastShadow = true
	for _, dz in { -5.6, 5.6 } do
		StopKit.part(refs, {
			name = "Post",
			size = Vector3.new(0.4, 8.6, 0.4),
			cf = CFrame.new(9, 4.9, zc + dz),
			color = C.DarkMetal,
		}, shelter)
	end
	StopKit.part(refs, {
		name = "BackPanel",
		size = Vector3.new(0.2, 7, 11.6),
		cf = CFrame.new(9.2, 4.6, zc),
		color = C.Glass,
		material = Enum.Material.Glass,
		transparency = 0.6,
	}, shelter)
	StopKit.part(refs, {
		name = "Bench",
		size = Vector3.new(1.6, 0.4, 7),
		cf = CFrame.new(8.2, 2.3, zc),
		color = C.Wood,
		material = Enum.Material.Wood,
	}, shelter)
	local tt, label = StopKit.sign(refs, {
		name = "Timetable",
		size = Vector3.new(0.2, 2.8, 2.4),
		cf = CFrame.new(9.05, 4.8, zc + 4),
		color = Color3.fromRGB(235, 232, 220),
		collide = false,
	}, "9N NIGHT OWL\n--:--", Enum.NormalId.Left, Color3.fromRGB(20, 20, 30), shelter)
	tt:SetAttribute("Timetable", true)
	label.Font = Enum.Font.Code
	refs.timetable = label
	-- The stop sign pole at the curb.
	StopKit.part(refs, {
		name = "SignPole",
		size = Vector3.new(0.4, 11, 0.4),
		cf = CFrame.new(1.6, 5.8, zc - 9),
		color = C.Metal,
		material = Enum.Material.Metal,
	}, shelter)
	StopKit.sign(refs, {
		name = "StopSign",
		size = Vector3.new(0.2, 3.4, 3.4),
		cf = CFrame.new(1.6, 10, zc - 9),
		color = Color3.fromRGB(30, 70, 120),
		collide = false,
	}, "HCTA\n9N\n" .. title, Enum.NormalId.Left, Color3.new(1, 1, 1), shelter)
	refs.shelter = shelter
	return shelter
end

-- A streetlight on the sidewalk. Lights are ordered far (+Z) to near, so the Latecomer can
-- put them out one by one as it walks in.
function StopKit.streetlight(refs: StopRefs, z: number, x: number?): BasePart
	local px = x or 8.8
	local model = Build.model(refs.model, "Streetlight")
	StopKit.part(refs, {
		name = "Pole",
		size = Vector3.new(0.7, 22, 0.7),
		cf = CFrame.new(px, 11, z),
		color = C.DarkMetal,
		material = Enum.Material.Metal,
	}, model)
	StopKit.part(refs, {
		name = "Arm",
		size = Vector3.new(7, 0.4, 0.4),
		cf = CFrame.new(px - 3.3, 21.8, z),
		color = C.DarkMetal,
		collide = false,
	}, model)
	local lamp = StopKit.part(refs, {
		name = "Lamp",
		size = Vector3.new(2.2, 0.5, 1.2),
		cf = CFrame.new(px - 6.4, 21.4, z),
		color = C.Sodium,
		material = Enum.Material.Neon,
		collide = false,
		tag = "StopLight",
	}, model)
	local light = Build.light(lamp, "Spot", C.Sodium, 3, 46, false);
	(light :: SpotLight).Angle = 110
	table.insert(refs.streetlights, lamp)
	return lamp
end

-- The usual row of streetlights the Latecomer walks under: from 230 studs back to the curb.
function StopKit.approachLights(refs: StopRefs, count: number?)
	local n = count or 5
	local far = 230
	for i = 0, n - 1 do
		StopKit.streetlight(refs, far - i * (far / n))
	end
	table.sort(refs.streetlights, function(a, b)
		return refs.frame:PointToObjectSpace(a.Position).Z > refs.frame:PointToObjectSpace(b.Position).Z
	end)
end

function StopKit.lootPoint(refs: StopRefs, pos: Vector3, tag: string?): BasePart
	local p = StopKit.part(refs, {
		name = "LootPoint",
		size = Vector3.new(1, 1, 1),
		cf = CFrame.new(pos),
		transparency = 1,
		collide = false,
		query = false,
		attrs = { Loot = tag or "" },
	})
	table.insert(refs.lootPoints, p)
	return p
end

function StopKit.fragmentSite(refs: StopRefs, pos: Vector3): BasePart
	local p = StopKit.part(refs, {
		name = "FragmentSite",
		size = Vector3.new(1, 1, 1),
		cf = CFrame.new(pos),
		transparency = 1,
		collide = false,
		query = false,
	})
	table.insert(refs.fragmentSites, p)
	return p
end

function StopKit.marker(refs: StopRefs, name: string, cf: CFrame): BasePart
	return StopKit.part(refs, {
		name = name,
		size = Vector3.new(2, 1, 2),
		cf = cf,
		transparency = 1,
		collide = false,
		query = false,
	})
end

function StopKit.entitySpawn(refs: StopRefs, cf: CFrame): BasePart
	local p = StopKit.marker(refs, "EntitySpawn", cf)
	table.insert(refs.entitySpawns, p)
	return p
end

function StopKit.hidingSpot(refs: StopRefs, cf: CFrame): BasePart
	local p = StopKit.marker(refs, "HidingSpot", cf)
	table.insert(refs.hidingSpots, p)
	return p
end

-- An anomaly slot. `normal` is visible by default; variants are pre-built and hidden, each
-- tagged with the anomaly id that shows it.
function StopKit.slot(refs: StopRefs, name: string, normal: Instance, variants: { [string]: Instance }?)
	normal:SetAttribute("AnomalySlot", name)
	refs.slots[name] = normal
	if variants then
		for anomalyId, variant in variants do
			variant:SetAttribute("AnomalyVariant", anomalyId)
			variant:SetAttribute("AnomalySlotOf", name)
			StopKit.setShown(variant, false)
		end
	end
end

-- Show or hide a part or model (transparency, collisions, lights, guis).
function StopKit.setShown(inst: Instance, shown: boolean)
	local function apply(d: Instance)
		if d:IsA("BasePart") then
			if shown then
				d.Transparency = (d:GetAttribute("ShownTransparency") :: number?) or d.Transparency
				d.CanCollide = (d:GetAttribute("ShownCollide") :: boolean?) ~= false
			else
				if d:GetAttribute("ShownTransparency") == nil then
					d:SetAttribute("ShownTransparency", d.Transparency)
					d:SetAttribute("ShownCollide", d.CanCollide)
				end
				d.Transparency = 1
				d.CanCollide = false
			end
			d.CanQuery = shown
		elseif d:IsA("Light") then
			if not shown then
				if d:GetAttribute("ShownEnabled") == nil then
					d:SetAttribute("ShownEnabled", d.Enabled)
				end
				d.Enabled = false
			else
				d.Enabled = (d:GetAttribute("ShownEnabled") :: boolean?) ~= false
			end
		elseif d:IsA("SurfaceGui") or d:IsA("BillboardGui") or d:IsA("ProximityPrompt") then
			(d :: any).Enabled = shown
		elseif d:IsA("Decal") then
			if not shown then
				if d:GetAttribute("ShownTransparency") == nil then
					d:SetAttribute("ShownTransparency", d.Transparency)
				end
				d.Transparency = 1
			else
				d.Transparency = (d:GetAttribute("ShownTransparency") :: number?) or 0
			end
		end
	end
	apply(inst)
	for _, d in inst:GetDescendants() do
		apply(d)
	end
	inst:SetAttribute("Shown", shown)
end

-- The trailhead: a marked footpath entrance behind the stop.
function StopKit.trailhead(refs: StopRefs, cf: CFrame): BasePart
	local post = StopKit.part(refs, {
		name = "TrailheadPost",
		size = Vector3.new(0.8, 5, 0.8),
		cf = cf * CFrame.new(-2, 2, 0),
		color = C.Wood,
		material = Enum.Material.Wood,
	})
	StopKit.sign(refs, {
		name = "TrailheadSign",
		size = Vector3.new(0.2, 1.6, 3.2),
		cf = cf * CFrame.new(-2, 4.6, 0),
		color = Color3.fromRGB(60, 50, 40),
		collide = false,
	}, "FOOTPATH", Enum.NormalId.Left, Color3.fromRGB(230, 220, 190))
	local glow = StopKit.part(refs, {
		name = "TrailMarker",
		size = Vector3.new(0.6, 0.6, 0.6),
		cf = cf * CFrame.new(-2, 5.8, 0),
		color = Color3.fromRGB(180, 220, 255),
		material = Enum.Material.Neon,
		collide = false,
		shape = Enum.PartType.Ball,
	})
	Build.light(glow, "Point", Color3.fromRGB(180, 220, 255), 0.8, 10, false)
	local zone = StopKit.part(refs, {
		name = "Trailhead",
		size = Vector3.new(8, 8, 8),
		cf = cf * CFrame.new(0, 4, 0),
		transparency = 1,
		collide = false,
		touch = true,
		query = false,
	})
	refs.trailhead = zone
	local _ = post
	return zone
end

function StopKit.backEntrance(refs: StopRefs, cf: CFrame): BasePart
	local p = StopKit.marker(refs, "BackEntrance", cf)
	refs.backEntrance = p
	return p
end

-- A simple box building with a door gap facing the curb (-X side). Returns the model.
function StopKit.building(
	refs: StopRefs,
	name: string,
	centre: Vector3,
	size: Vector3,
	color: Color3,
	doorWidth: number?,
	doorZ: number?
): Model
	local m = Build.model(refs.model, name)
	local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
	local dw = doorWidth or 6
	local dz = doorZ or 0
	local wall = 1
	local mat = Enum.Material.Brick
	-- back and sides
	StopKit.part(refs, {
		name = "Wall",
		size = Vector3.new(wall, size.Y, size.Z),
		cf = CFrame.new(centre + Vector3.new(hx - wall / 2, 0, 0)),
		color = color,
		material = mat,
	}, m)
	for _, s in { -1, 1 } do
		StopKit.part(refs, {
			name = "Wall",
			size = Vector3.new(size.X, size.Y, wall),
			cf = CFrame.new(centre + Vector3.new(0, 0, s * (hz - wall / 2))),
			color = color,
			material = mat,
		}, m)
	end
	-- front with a door gap
	local frontX = centre.X - hx + wall / 2
	local left = (dz - dw / 2) - (centre.Z - hz)
	local right = (centre.Z + hz) - (dz + dw / 2)
	if left > 0.1 then
		StopKit.part(refs, {
			name = "Front",
			size = Vector3.new(wall, size.Y, left),
			cf = CFrame.new(frontX, centre.Y, centre.Z - hz + left / 2),
			color = color,
			material = mat,
		}, m)
	end
	if right > 0.1 then
		StopKit.part(refs, {
			name = "Front",
			size = Vector3.new(wall, size.Y, right),
			cf = CFrame.new(frontX, centre.Y, centre.Z + hz - right / 2),
			color = color,
			material = mat,
		}, m)
	end
	local doorTop = 9
	if size.Y - doorTop > 0.1 then
		StopKit.part(refs, {
			name = "Lintel",
			size = Vector3.new(wall, size.Y - doorTop, dw),
			cf = CFrame.new(frontX, centre.Y - hy + doorTop + (size.Y - doorTop) / 2, dz),
			color = color,
			material = mat,
		}, m)
	end
	StopKit.part(refs, {
		name = "Roof",
		size = Vector3.new(size.X + 1, 1, size.Z + 1),
		cf = CFrame.new(centre + Vector3.new(0, hy + 0.5, 0)),
		color = Color3.fromRGB(40, 40, 42),
	}, m)
	StopKit.part(refs, {
		name = "Floor",
		size = Vector3.new(size.X - 0.2, 0.4, size.Z - 0.2),
		cf = CFrame.new(centre + Vector3.new(0, -hy + 0.2, 0)),
		color = Color3.fromRGB(120, 118, 110),
		material = Enum.Material.SmoothPlastic,
	}, m)
	local zone = StopKit.part(refs, {
		name = "IndoorZone",
		size = size - Vector3.new(1, 0, 1),
		cf = CFrame.new(centre),
		transparency = 1,
		collide = false,
		query = false,
	}, m)
	zone:SetAttribute("Indoor", name)
	table.insert(refs.interior, zone)
	return m
end

-- A ceiling light with a switchable bulb (for blink and off anomalies).
function StopKit.ceilingLight(refs: StopRefs, pos: Vector3, color: Color3?, range: number?, parent: Instance?): BasePart
	local bulb = StopKit.part(refs, {
		name = "CeilingLight",
		size = Vector3.new(4, 0.3, 1),
		cf = CFrame.new(pos),
		color = color or C.Fluor,
		material = Enum.Material.Neon,
		collide = false,
	}, parent)
	Build.light(bulb, "Point", color or C.Fluor, 1.2, range or 20, false)
	return bulb
end

-- A simple waist-height box (counter, shelf, crate). Optional loot point on top.
function StopKit.box(
	refs: StopRefs,
	name: string,
	cf: CFrame,
	size: Vector3,
	color: Color3,
	material: Enum.Material?,
	parent: Instance?
): Part
	return StopKit.part(refs, {
		name = name,
		size = size,
		cf = cf,
		color = color,
		material = material or Enum.Material.Wood,
	}, parent)
end

-- The default pieces almost every stop wants.
function StopKit.basics(refs: StopRefs, title: string, lotDepth: number, z0: number, z1: number)
	StopKit.lot(refs, lotDepth, z0, z1)
	StopKit.sidewalk(refs, -60, 60)
	StopKit.shelter(refs, title)
	StopKit.approachLights(refs)
	refs.passengerSpot = StopKit.marker(refs, "PassengerSpot", CFrame.new(6, 3, -2))
end

return StopKit
