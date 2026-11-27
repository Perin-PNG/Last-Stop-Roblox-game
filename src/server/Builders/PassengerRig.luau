--!strict
-- Passenger bodies. A rig is a handful of plain parts, built either standing at a floor
-- point or sitting on a seat, facing -Z of the CFrame it's given. It has eyelids the
-- client blinks (unless the rig carries NeverBlinks), a fake shadow blob on the floor, and
-- an optional prop. `trueShape` builds the thing a mimic really is.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Build = require(Shared.Util.Build)

local PassengerRig = {}

export type Look = {
	skin: Color3,
	shirt: Color3,
	pants: Color3,
	hat: Color3?,
	prop: string?,
}

-- Slightly under the stop figures' size, so a rig fits a bus seat next to players.
local SCALE = 0.78

local HAIR = Color3.fromRGB(40, 30, 24)
local DARK = Color3.fromRGB(12, 12, 14)

local function piece(
	m: Model,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	transparency: number?
): Part
	return Build.part(m, {
		name = name,
		size = size,
		cf = cf,
		color = color,
		material = material or Enum.Material.SmoothPlastic,
		transparency = transparency,
		collide = false,
		query = true,
		touch = false,
		cast = false, -- the shadow blob stands in for a shadow (see the wrong_shadow tell)
	})
end

local function headMesh(head: Part)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Head
	mesh.Scale = Vector3.new(1.05, 1, 1.05)
	mesh.Parent = head
end

-- The face: eyes, the lids the client closes for a blink, and a mouth.
local function face(m: Model, head: CFrame, look: Look, s: number)
	for i, side in { -1, 1 } do
		local eyeCf = head * CFrame.new(side * 0.26 * s, 0.1 * s, -0.66 * s)
		local suffix = if i == 1 then "L" else "R"
		piece(m, "Eye" .. suffix, Vector3.new(0.2, 0.16, 0.05) * s, eyeCf, Color3.fromRGB(18, 16, 14))
		local lid = piece(
			m,
			"Lid" .. suffix,
			Vector3.new(0.26, 0.22, 0.05) * s,
			eyeCf * CFrame.new(0, 0, -0.02 * s),
			look.skin,
			nil,
			1
		)
		lid:SetAttribute("Lid", true)
	end
	piece(
		m,
		"Mouth",
		Vector3.new(0.4, 0.06, 0.05) * s,
		head * CFrame.new(0, -0.32 * s, -0.66 * s),
		Color3.fromRGB(90, 50, 46)
	)
end

local function hat(m: Model, head: CFrame, look: Look, s: number)
	if look.hat then
		piece(
			m,
			"Hat",
			Vector3.new(1.45, 0.45, 1.45) * s,
			head * CFrame.new(0, 0.85 * s, 0),
			look.hat,
			Enum.Material.Fabric
		)
		piece(
			m,
			"Brim",
			Vector3.new(1.5, 0.1, 0.6) * s,
			head * CFrame.new(0, 0.66 * s, -0.85 * s),
			look.hat,
			Enum.Material.Fabric
		)
	else
		piece(m, "Hair", Vector3.new(1.4, 0.5, 1.4) * s, head * CFrame.new(0, 0.7 * s, 0.05 * s), HAIR)
	end
end

local function propOn(m: Model, kind: string?, torso: CFrame, head: CFrame, lap: CFrame, s: number)
	if kind == "birdcage" then
		local cage = piece(
			m,
			"Birdcage",
			Vector3.new(1.4, 1.6, 1.4) * s,
			lap * CFrame.new(0, 0.8 * s, 0),
			DARK,
			Enum.Material.Metal
		)
		cage.Transparency = 0.2
		piece(
			m,
			"CageCover",
			Vector3.new(1.55, 1.3, 1.55) * s,
			lap * CFrame.new(0, 0.95 * s, 0),
			Color3.fromRGB(110, 30, 34),
			Enum.Material.Fabric
		)
	elseif kind == "box" then
		local box = piece(
			m,
			"Parcel",
			Vector3.new(1.8, 1.2, 1.4) * s,
			lap * CFrame.new(0, 0.6 * s, 0),
			Color3.fromRGB(170, 130, 80),
			Enum.Material.Cardboard
		)
		piece(
			m,
			"Tape",
			Vector3.new(1.82, 0.1, 0.3) * s,
			box.CFrame * CFrame.new(0, 0.61 * s, 0),
			Color3.fromRGB(200, 190, 160)
		)
	elseif kind == "headphones" then
		piece(m, "Band", Vector3.new(1.5, 0.15, 0.2) * s, head * CFrame.new(0, 0.82 * s, 0), DARK)
		for _, side in { -1, 1 } do
			piece(m, "Cup", Vector3.new(0.25, 0.55, 0.55) * s, head * CFrame.new(side * 0.72 * s, 0, 0), DARK)
		end
	elseif kind == "badge" then
		piece(
			m,
			"Badge",
			Vector3.new(0.35, 0.45, 0.05) * s,
			torso * CFrame.new(0.55 * s, 0.6 * s, -0.58 * s),
			Color3.fromRGB(230, 230, 230)
		)
	elseif kind == "uniform" then
		piece(
			m,
			"Patch",
			Vector3.new(0.5, 0.3, 0.05) * s,
			torso * CFrame.new(-0.6 * s, 0.7 * s, -0.58 * s),
			Color3.fromRGB(200, 160, 40)
		)
	end
end

local function shadow(m: Model, floor: CFrame, s: number)
	local blob = piece(
		m,
		"ShadowBlob",
		Vector3.new(0.05, 2.6, 2.6) * s,
		floor * CFrame.new(0, 0.03, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(0, 0, 0),
		nil,
		0.55
	)
	blob.Shape = Enum.PartType.Cylinder
	blob.CanQuery = false
end

-- Standing at `floor` (the ground point), facing -Z.
function PassengerRig.standing(parent: Instance, name: string, floor: CFrame, look: Look): Model
	local m = Build.model(parent, name)
	local s = SCALE
	for _, side in { -0.5, 0.5 } do
		piece(
			m,
			"Leg",
			Vector3.new(0.9, 2.6, 0.9) * s,
			floor * CFrame.new(side * s, 1.3 * s, 0),
			look.pants,
			Enum.Material.Fabric
		)
		piece(
			m,
			"Arm",
			Vector3.new(0.8, 2.4, 0.8) * s,
			floor * CFrame.new(side * 3.4 * s, 3.9 * s, 0),
			look.shirt,
			Enum.Material.Fabric
		)
		piece(m, "Hand", Vector3.new(0.7, 0.6, 0.7) * s, floor * CFrame.new(side * 3.4 * s, 2.5 * s, 0), look.skin)
	end
	local torsoCf = floor * CFrame.new(0, 3.9 * s, 0)
	local torso = piece(m, "Torso", Vector3.new(2.2, 2.6, 1.1) * s, torsoCf, look.shirt, Enum.Material.Fabric)
	piece(m, "Neck", Vector3.new(0.6, 0.4, 0.6) * s, floor * CFrame.new(0, 5.35 * s, 0), look.skin)
	local headCf = floor * CFrame.new(0, 6.3 * s, 0)
	local head = piece(m, "Head", Vector3.new(1.3, 1.5, 1.3) * s, headCf, look.skin)
	headMesh(head)
	face(m, headCf, look, s)
	hat(m, headCf, look, s)
	propOn(m, look.prop, torsoCf, headCf, floor * CFrame.new(1.6 * s, 0, -0.4 * s), s)
	shadow(m, floor * CFrame.new(0.6, 0, 0.9), s)
	m.PrimaryPart = torso
	return m
end

-- Sitting on `seat`, facing the way the seat faces.
function PassengerRig.seated(parent: Instance, name: string, seat: BasePart, look: Look): Model
	local m = Build.model(parent, name)
	local s = SCALE
	local top = seat.CFrame * CFrame.new(0, seat.Size.Y / 2, 0)
	for _, side in { -0.5, 0.5 } do
		piece(
			m,
			"Thigh",
			Vector3.new(0.9, 0.9, 2.2) * s,
			top * CFrame.new(side * s, 0.45 * s, -0.7 * s),
			look.pants,
			Enum.Material.Fabric
		)
		piece(
			m,
			"Shin",
			Vector3.new(0.9, 2.2, 0.9) * s,
			top * CFrame.new(side * s, -0.65 * s, -1.65 * s),
			look.pants,
			Enum.Material.Fabric
		)
		piece(
			m,
			"Arm",
			Vector3.new(0.8, 2.2, 0.8) * s,
			top * CFrame.new(side * 3.3 * s, 2.0 * s, 0.1 * s) * CFrame.Angles(math.rad(25), 0, 0),
			look.shirt,
			Enum.Material.Fabric
		)
		piece(m, "Hand", Vector3.new(0.7, 0.6, 0.7) * s, top * CFrame.new(side * 1.1 * s, 1.1 * s, -1.1 * s), look.skin)
	end
	local torsoCf = top * CFrame.new(0, 2.2 * s, 0.35 * s)
	local torso = piece(m, "Torso", Vector3.new(2.2, 2.6, 1.1) * s, torsoCf, look.shirt, Enum.Material.Fabric)
	piece(m, "Neck", Vector3.new(0.6, 0.4, 0.6) * s, top * CFrame.new(0, 3.65 * s, 0.35 * s), look.skin)
	local headCf = top * CFrame.new(0, 4.6 * s, 0.35 * s)
	local head = piece(m, "Head", Vector3.new(1.3, 1.5, 1.3) * s, headCf, look.skin)
	headMesh(head)
	face(m, headCf, look, s)
	hat(m, headCf, look, s)
	propOn(m, look.prop, torsoCf, headCf, top * CFrame.new(0, 0.9 * s, -1.3 * s), s)
	-- The shadow blob sits on the floor below the knees.
	shadow(m, top * CFrame.new(0, -1.75 * s, -1.2 * s), s)
	m.PrimaryPart = torso
	return m
end

-- What a mimic really is: too tall, too thin, arms to the floor, a long neck, a face
-- that is only two red points. Built standing at `floor`, facing -Z.
function PassengerRig.trueShape(parent: Instance, name: string, floor: CFrame): Model
	local m = Build.model(parent, name)
	local skin = Color3.fromRGB(70, 66, 64)
	local s = SCALE
	for _, side in { -0.4, 0.4 } do
		piece(
			m,
			"Leg",
			Vector3.new(0.6, 3.8, 0.6) * s,
			floor * CFrame.new(side * s, 1.9 * s, 0),
			DARK,
			Enum.Material.Fabric
		)
		piece(
			m,
			"Arm",
			Vector3.new(0.45, 5.6, 0.45) * s,
			floor * CFrame.new(side * 4 * s, 3.4 * s, -0.4 * s) * CFrame.Angles(math.rad(-12), 0, 0),
			skin,
			Enum.Material.Slate
		)
	end
	local torso =
		piece(m, "Torso", Vector3.new(1.6, 3.4, 0.8) * s, floor * CFrame.new(0, 5.5 * s, 0), DARK, Enum.Material.Fabric)
	piece(
		m,
		"Neck",
		Vector3.new(0.4, 1.6, 0.4) * s,
		floor * CFrame.new(0, 7.9 * s, -0.2 * s),
		skin,
		Enum.Material.Slate
	)
	local headCf = floor * CFrame.new(0, 9.2 * s, -0.4 * s) * CFrame.Angles(0, 0, math.rad(18))
	local head = piece(m, "Head", Vector3.new(1.1, 1.9, 1.1) * s, headCf, skin, Enum.Material.Slate)
	headMesh(head)
	for _, side in { -1, 1 } do
		local eye = piece(
			m,
			"Eye",
			Vector3.new(0.14, 0.14, 0.05) * s,
			headCf * CFrame.new(side * 0.22 * s, 0.2 * s, -0.56 * s),
			Color3.fromRGB(255, 40, 30),
			Enum.Material.Neon
		)
		Build.light(eye, "Point", Color3.fromRGB(255, 40, 30), 0.6, 5)
	end
	m.PrimaryPart = torso
	return m
end

-- Weld every part of a rig to its torso and the torso to `to`, so the rig rides along
-- with whatever `to` is part of (the bus).
function PassengerRig.attach(m: Model, to: BasePart)
	local root = m.PrimaryPart :: BasePart
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Massless = true
			if d ~= root then
				Build.weld(root, d)
			end
		end
	end
	Build.weld(to, root)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
		end
	end
end

return PassengerRig
