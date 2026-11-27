--!strict
-- Furniture and fittings the stop builders share: shelves of books, tables and chairs,
-- counters, beds, hinged doors with prompts, lit windows, fences, trees and lockers. All
-- positions are in stop-frame coordinates (see StopKit).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StopKit = require(script.Parent:WaitForChild("StopKit"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Build = require(Shared.Util.Build)
local Config = require(Shared.Config)
local Registry = require(script.Parent.Parent:WaitForChild("Registry"))

local C = Build.Colors

local Props = {}

local BOOK_COLORS = {
	Color3.fromRGB(110, 40, 36),
	Color3.fromRGB(40, 60, 90),
	Color3.fromRGB(60, 80, 50),
	Color3.fromRGB(150, 120, 70),
	Color3.fromRGB(70, 50, 70),
	Color3.fromRGB(180, 170, 150),
	Color3.fromRGB(30, 30, 34),
}

-- A bookcase `length` long along its local Z, facing -X. `cf` is the floor point.
function Props.shelf(
	refs: StopKit.StopRefs,
	cf: CFrame,
	length: number,
	height: number?,
	parent: Instance?,
	seed: number?
): Model
	local h = height or 9
	local m = Build.model(parent or refs.model, "Shelf")
	StopKit.part(refs, {
		name = "Back",
		size = Vector3.new(0.4, h, length),
		cf = cf * CFrame.new(0.9, h / 2, 0),
		color = C.Wood,
		material = Enum.Material.Wood,
	}, m)
	for _, s in { -1, 1 } do
		StopKit.part(refs, {
			name = "Side",
			size = Vector3.new(2.2, h, 0.4),
			cf = cf * CFrame.new(0, h / 2, s * (length / 2 - 0.2)),
			color = C.Wood,
			material = Enum.Material.Wood,
		}, m)
	end
	local rows = math.max(2, math.floor(h / 2.2))
	local rng = Random.new(seed or math.floor(cf.Position.X * 7 + cf.Position.Z * 13))
	for r = 0, rows - 1 do
		local y = 0.3 + r * (h - 0.6) / rows
		StopKit.part(refs, {
			name = "Board",
			size = Vector3.new(2.2, 0.25, length - 0.4),
			cf = cf * CFrame.new(0, y, 0),
			color = C.Wood,
			material = Enum.Material.Wood,
		}, m)
		-- Books in short runs, with gaps, so the stacks read as books from a distance.
		local z = -length / 2 + 0.6
		while z < length / 2 - 0.8 do
			local run = rng:NextNumber(1.2, 3.2)
			local bookH = rng:NextNumber(1.1, 1.7)
			StopKit.part(refs, {
				name = "Books",
				size = Vector3.new(1.6, bookH, math.min(run, length / 2 - 0.6 - z)),
				cf = cf * CFrame.new(-0.1, y + 0.12 + bookH / 2, z + run / 2),
				color = BOOK_COLORS[rng:NextInteger(1, #BOOK_COLORS)],
				material = Enum.Material.SmoothPlastic,
				collide = false,
			}, m)
			z += run + rng:NextNumber(0.1, 0.9)
		end
	end
	return m
end

function Props.table(refs: StopKit.StopRefs, cf: CFrame, size: Vector3?, color: Color3?, parent: Instance?): Model
	local s = size or Vector3.new(4, 3, 6)
	local m = Build.model(parent or refs.model, "Table")
	local top = StopKit.part(refs, {
		name = "Top",
		size = Vector3.new(s.X, 0.3, s.Z),
		cf = cf * CFrame.new(0, s.Y, 0),
		color = color or C.Wood,
		material = Enum.Material.Wood,
	}, m)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			StopKit.part(refs, {
				name = "Leg",
				size = Vector3.new(0.3, s.Y, 0.3),
				cf = cf * CFrame.new(x * (s.X / 2 - 0.3), s.Y / 2, z * (s.Z / 2 - 0.3)),
				color = C.DarkMetal,
				material = Enum.Material.Metal,
			}, m)
		end
	end
	m.PrimaryPart = top
	return m
end

function Props.chair(refs: StopKit.StopRefs, cf: CFrame, color: Color3?, parent: Instance?): Model
	local m = Build.model(parent or refs.model, "Chair")
	local seat = StopKit.part(refs, {
		name = "Seat",
		size = Vector3.new(1.8, 0.3, 1.8),
		cf = cf * CFrame.new(0, 1.8, 0),
		color = color or C.Wood,
		material = Enum.Material.Wood,
	}, m)
	StopKit.part(refs, {
		name = "Back",
		size = Vector3.new(1.8, 2, 0.25),
		cf = cf * CFrame.new(0, 2.9, 0.8),
		color = color or C.Wood,
		material = Enum.Material.Wood,
	}, m)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			StopKit.part(refs, {
				name = "Leg",
				size = Vector3.new(0.2, 1.8, 0.2),
				cf = cf * CFrame.new(x * 0.75, 0.9, z * 0.75),
				color = C.DarkMetal,
				material = Enum.Material.Metal,
			}, m)
		end
	end
	m.PrimaryPart = seat
	return m
end

function Props.counter(
	refs: StopKit.StopRefs,
	cf: CFrame,
	size: Vector3,
	color: Color3?,
	top: Color3?,
	parent: Instance?
): Part
	local body = StopKit.part(refs, {
		name = "Counter",
		size = size,
		cf = cf * CFrame.new(0, size.Y / 2, 0),
		color = color or C.Wood,
		material = Enum.Material.Wood,
	}, parent)
	StopKit.part(refs, {
		name = "CounterTop",
		size = Vector3.new(size.X + 0.4, 0.25, size.Z + 0.4),
		cf = cf * CFrame.new(0, size.Y + 0.12, 0),
		color = top or Color3.fromRGB(190, 185, 170),
		material = Enum.Material.Marble,
	}, parent)
	return body
end

function Props.bed(refs: StopKit.StopRefs, cf: CFrame, sheet: Color3?, parent: Instance?): Model
	local m = Build.model(parent or refs.model, "Bed")
	local frame = StopKit.part(refs, {
		name = "Frame",
		size = Vector3.new(5, 1.6, 8),
		cf = cf * CFrame.new(0, 0.8, 0),
		color = C.Wood,
		material = Enum.Material.Wood,
	}, m)
	StopKit.part(refs, {
		name = "Mattress",
		size = Vector3.new(4.8, 0.9, 7.6),
		cf = cf * CFrame.new(0, 2, 0),
		color = sheet or Color3.fromRGB(200, 195, 185),
		material = Enum.Material.Fabric,
	}, m)
	StopKit.part(refs, {
		name = "Pillow",
		size = Vector3.new(3.6, 0.6, 1.4),
		cf = cf * CFrame.new(0, 2.7, 3.1),
		color = C.White,
		material = Enum.Material.Fabric,
	}, m)
	StopKit.part(refs, {
		name = "Headboard",
		size = Vector3.new(5, 3.5, 0.4),
		cf = cf * CFrame.new(0, 2.4, 4.1),
		color = C.Wood,
		material = Enum.Material.Wood,
	}, m)
	m.PrimaryPart = frame
	return m
end

-- A tall metal locker. Crouching beside it hides you from sight-based threats.
function Props.locker(refs: StopKit.StopRefs, cf: CFrame, color: Color3?, parent: Instance?): Part
	local body = StopKit.part(refs, {
		name = "Locker",
		size = Vector3.new(2.6, 7.5, 2.6),
		cf = cf * CFrame.new(0, 3.75, 0),
		color = color or Color3.fromRGB(70, 90, 100),
		material = Enum.Material.Metal,
	}, parent)
	for i = 0, 3 do
		StopKit.part(refs, {
			name = "Vent",
			size = Vector3.new(0.05, 0.15, 1.4),
			cf = cf * CFrame.new(-1.31, 6.4 - i * 0.35, 0),
			color = C.Black,
			collide = false,
		}, parent)
	end
	return body
end

export type Door = {
	part: BasePart,
	prompt: ProximityPrompt,
	isOpen: () -> boolean,
	set: (open: boolean) -> (),
	changed: BindableEvent,
}

-- A door hinged at its -Z edge, closed across the opening at `cf` (the floor point at its
-- middle, facing -X). Anyone can open or close it; each swing makes noise.
function Props.door(
	refs: StopKit.StopRefs,
	cf: CFrame,
	width: number,
	height: number,
	color: Color3?,
	parent: Instance?,
	label: string?
): Door
	local closed = refs.frame * cf * CFrame.new(0, height / 2, 0)
	local hinge = closed * CFrame.new(0, 0, -width / 2)
	local part = Build.part(parent or refs.model, {
		name = "Door",
		size = Vector3.new(0.35, height, width),
		cf = closed,
		color = color or C.Wood,
		material = Enum.Material.Wood,
		group = "World",
	})
	Build.part(part, {
		name = "Knob",
		size = Vector3.new(0.5, 0.3, 0.3),
		cf = closed * CFrame.new(-0.3, -0.4, width / 2 - 0.5),
		color = C.Metal,
		material = Enum.Material.Metal,
		collide = false,
		group = "World",
	})
	local open = false
	local changed = Instance.new("BindableEvent")
	changed.Parent = part
	local prompt = Build.prompt(part, "Open", label or "Door", 0, 7, "DoorPrompt")
	local function set(value: boolean)
		if open == value then
			return
		end
		open = value
		local swing = hinge * CFrame.Angles(0, if value then math.rad(100) else 0, 0) * CFrame.new(0, 0, width / 2)
		part.CFrame = swing
		for _, d in part:GetChildren() do
			if d:IsA("BasePart") then
				d.CFrame = swing * CFrame.new(-0.3, -0.4, width / 2 - 0.5)
			end
		end
		part.CanCollide = not value
		prompt.ActionText = if value then "Close" else "Open"
		local Noise = Registry.find("NoiseService")
		if Noise then
			Noise.post(part.Position, Config.Tuning.Noise.DoorRadius, "door")
		end
		changed:Fire(value)
	end
	prompt.Triggered:Connect(function(player: Player)
		local PlayerState = Registry.find("PlayerStateService")
		if PlayerState and not PlayerState.isHealthy(player) then
			return
		end
		set(not open)
	end)
	return {
		part = part,
		prompt = prompt,
		isOpen = function()
			return open
		end,
		set = set,
		changed = changed,
	}
end

-- A window pane with warm light behind it (lit) or dark glass.
function Props.window(refs: StopKit.StopRefs, cf: CFrame, size: Vector2, lit: boolean, parent: Instance?): Part
	local pane = StopKit.part(refs, {
		name = "Window",
		size = Vector3.new(0.2, size.Y, size.X),
		cf = cf,
		color = if lit then Color3.fromRGB(255, 214, 150) else Color3.fromRGB(16, 20, 26),
		material = if lit then Enum.Material.Neon else Enum.Material.Glass,
		transparency = if lit then 0.15 else 0.2,
		collide = false,
	}, parent)
	if lit then
		local light = Build.light(pane, "Surface", C.Warm, 0.8, 18, false) :: SurfaceLight
		light.Face = Enum.NormalId.Left
	end
	StopKit.part(refs, {
		name = "Frame",
		size = Vector3.new(0.3, 0.25, size.X + 0.4),
		cf = cf * CFrame.new(0, -size.Y / 2 - 0.1, 0),
		color = C.White,
		collide = false,
	}, parent)
	return pane
end

-- A run of fence posts and rails from `a` to `b` (floor points).
function Props.fence(refs: StopKit.StopRefs, a: Vector3, b: Vector3, color: Color3?, parent: Instance?)
	local m = Build.model(parent or refs.model, "Fence")
	local d = b - a
	local len = d.Magnitude
	if len < 0.5 then
		return
	end
	local cf = CFrame.lookAt(a, b)
	local posts = math.max(1, math.floor(len / 6))
	for i = 0, posts do
		StopKit.part(refs, {
			name = "Post",
			size = Vector3.new(0.4, 4, 0.4),
			cf = cf * CFrame.new(0, 2, -len * i / posts),
			color = color or C.Wood,
			material = Enum.Material.WoodPlanks,
		}, m)
	end
	for _, y in { 1.4, 3.2 } do
		StopKit.part(refs, {
			name = "Rail",
			size = Vector3.new(0.25, 0.4, len),
			cf = cf * CFrame.new(0, y, -len / 2),
			color = color or C.Wood,
			material = Enum.Material.WoodPlanks,
		}, m)
	end
end

-- A bare, crooked tree.
function Props.tree(refs: StopKit.StopRefs, pos: Vector3, height: number?, parent: Instance?)
	local h = height or 22
	local m = Build.model(parent or refs.model, "Tree")
	StopKit.part(refs, {
		name = "Trunk",
		size = Vector3.new(1.6, h, 1.6),
		cf = CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(math.rad(3), 0, math.rad(-4)),
		color = Color3.fromRGB(50, 40, 32),
		material = Enum.Material.Wood,
	}, m)
	for i = 1, 3 do
		local a = i * 2.1
		StopKit.part(refs, {
			name = "Branch",
			size = Vector3.new(0.6, h * 0.35, 0.6),
			cf = CFrame.new(pos + Vector3.new(0, h * (0.55 + i * 0.1), 0))
				* CFrame.Angles(0, a, 0)
				* CFrame.Angles(math.rad(50), 0, 0)
				* CFrame.new(0, h * 0.15, 0),
			color = Color3.fromRGB(46, 36, 30),
			material = Enum.Material.Wood,
			collide = false,
		}, m)
	end
	StopKit.part(refs, {
		name = "Leaves",
		size = Vector3.new(h * 0.6, h * 0.35, h * 0.6),
		cf = CFrame.new(pos + Vector3.new(0, h * 0.92, 0)),
		color = Color3.fromRGB(28, 40, 28),
		material = Enum.Material.Grass,
		shape = Enum.PartType.Ball,
		collide = false,
		transparency = 0.05,
	}, m)
end

-- A row of parked cars between z0 and z1 at depth x, noses toward the curb.
function Props.parkedCars(refs: StopKit.StopRefs, x: number, z0: number, z1: number, every: number, seed: number)
	local rng = Random.new(seed)
	local colors = {
		Color3.fromRGB(80, 30, 30),
		Color3.fromRGB(40, 50, 70),
		Color3.fromRGB(150, 150, 145),
		Color3.fromRGB(30, 30, 32),
		Color3.fromRGB(70, 80, 60),
	}
	local z = z0
	local n = 0
	while z <= z1 do
		if rng:NextNumber() < 0.7 then
			n += 1
			StopKit.car(
				refs,
				"Parked" .. n,
				CFrame.new(x, 0.5, z) * CFrame.Angles(0, math.rad(90), 0),
				colors[rng:NextInteger(1, #colors)]
			)
			StopKit.hidingSpot(refs, CFrame.new(x - 9, 3, z))
		end
		z += every
	end
end

-- Down whoever is within `radius` of `pos` and healthy (Hazards, ambushers).
function Props.downNear(pos: Vector3, radius: number, cause: string): number
	local PlayerState = Registry.find("PlayerStateService")
	if not PlayerState then
		return 0
	end
	local n = 0
	for _, player in Players:GetPlayers() do
		local root = PlayerState.rootOf(player)
		if root and (root.Position - pos).Magnitude <= radius and PlayerState.isHealthy(player) then
			PlayerState.down(player, cause)
			n += 1
		end
	end
	return n
end

return Props
