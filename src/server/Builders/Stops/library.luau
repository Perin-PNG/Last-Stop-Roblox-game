--!strict
-- Westbrook Public Library. A long reading room with tall stacks at the back. The
-- Librarian (a Listener) walks the aisles toward any noise: running, dropped items,
-- doors and voice. Crouch-walk, and throw a book to send her somewhere else.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StopKit = require(script.Parent.Parent:WaitForChild("StopKit"))
local Props = require(script.Parent.Parent:WaitForChild("Props"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Build = require(Shared.Util.Build)

local C = Build.Colors

local CENTRE = Vector3.new(64, 8, 4)
local SIZE = Vector3.new(56, 16, 84)

return function(parent: Instance, frame: CFrame, ctx: StopKit.Ctx, title: string): StopKit.StopRefs
	local refs = StopKit.new(ctx.id, parent, frame)
	StopKit.basics(refs, title, 104, -70, 70)
	local front = CENTRE.X - SIZE.X / 2
	local back = CENTRE.X + SIZE.X / 2
	local stone = Color3.fromRGB(150, 140, 120)
	local building = StopKit.building(refs, "Library", CENTRE, SIZE, stone, 8, -22)
	for _, d in building:GetChildren() do
		if d:IsA("BasePart") and (d.Name == "Wall" or d.Name == "Front" or d.Name == "Lintel") then
			d.Material = Enum.Material.Limestone
		end
	end
	-- Steps, columns and a pediment over the doors.
	for i = 0, 2 do
		StopKit.part(refs, {
			name = "Step",
			size = Vector3.new(2, 0.5, 18 - i * 2),
			cf = CFrame.new(front - 5 + i * 2, 0.25 + i * 0.5, -22),
			color = stone,
			material = Enum.Material.Limestone,
		})
	end
	for _, z in { -30, -14 } do
		local col = StopKit.part(refs, {
			name = "Column",
			size = Vector3.new(15, 1.8, 1.8),
			cf = CFrame.new(front - 2.5, 8, z) * CFrame.Angles(0, 0, math.rad(90)),
			color = Color3.fromRGB(200, 195, 180),
			material = Enum.Material.Limestone,
		})
		col.Shape = Enum.PartType.Cylinder
	end
	StopKit.wedge(refs, {
		name = "Pediment",
		size = Vector3.new(20, 4, 4),
		cf = CFrame.new(front - 2.5, 17.5, -22) * CFrame.Angles(0, math.rad(-90), 0),
		color = stone,
		material = Enum.Material.Limestone,
	})
	local signPart, signLabel = StopKit.sign(refs, {
		name = "Sign",
		size = Vector3.new(0.4, 2, 24),
		cf = CFrame.new(front - 0.4, 13.5, 6),
		color = Color3.fromRGB(60, 55, 50),
		collide = false,
	}, "WESTBROOK PUBLIC LIBRARY", Enum.NormalId.Left, Color3.fromRGB(230, 210, 160))
	signLabel.Font = Enum.Font.Garamond
	local _ = signPart
	-- Tall front windows, a few lit.
	for i, z in { -2, 8, 18, 28, 38 } do
		Props.window(refs, CFrame.new(front - 0.6, 7, z), Vector2.new(5, 7), i % 2 == 1)
	end
	-- Carpet.
	StopKit.part(refs, {
		name = "Carpet",
		size = Vector3.new(SIZE.X - 2, 0.05, SIZE.Z - 2),
		cf = CFrame.new(CENTRE.X, 0.45, CENTRE.Z),
		color = Color3.fromRGB(70, 34, 36),
		material = Enum.Material.Carpet,
		collide = false,
	})
	-- Ceiling lights, one already dead.
	for x = front + 8, back - 6, 12 do
		for z = CENTRE.Z - 34, CENTRE.Z + 34, 14 do
			if not (x > back - 16 and z > 30) then
				StopKit.ceilingLight(refs, Vector3.new(x, 15.2, z), C.Warm, 18)
			end
		end
	end

	-- The circulation desk by the doors, with the catalog terminal.
	local desk = Props.counter(refs, CFrame.new(front + 9, 0.4, -30), Vector3.new(4, 3.6, 14), C.Wood)
	local _deskTop = desk
	StopKit.hidingSpot(refs, CFrame.new(front + 11.5, 3, -30))
	local terminal, terminalLabel = StopKit.sign(refs, {
		name = "Terminal",
		size = Vector3.new(0.3, 1.6, 2.2),
		cf = CFrame.new(front + 8.6, 5.1, -26) * CFrame.Angles(0, 0, math.rad(-8)),
		color = Color3.fromRGB(20, 26, 22),
		collide = false,
	}, "CATALOG\nREADY", Enum.NormalId.Left, Color3.fromRGB(140, 255, 160))
	terminalLabel.Font = Enum.Font.Code
	StopKit.slot(refs, "terminal", terminal)
	StopKit.lootPoint(refs, Vector3.new(front + 9, 5, -34))

	-- The outdoor book return next to the doors; one variant has a hand resting inside.
	local returnBox = StopKit.part(refs, {
		name = "BookReturn",
		size = Vector3.new(3, 4.2, 3),
		cf = CFrame.new(front - 3, 2.5, -38),
		color = Color3.fromRGB(40, 70, 110),
		material = Enum.Material.Metal,
	})
	StopKit.sign(refs, {
		name = "ReturnSign",
		size = Vector3.new(0.1, 0.8, 2.6),
		cf = CFrame.new(front - 4.55, 3.6, -38),
		color = Color3.fromRGB(40, 70, 110),
		collide = false,
	}, "BOOK RETURN", Enum.NormalId.Left, C.White)
	local hand = StopKit.part(refs, {
		name = "Hand",
		size = Vector3.new(0.6, 0.35, 1.4),
		cf = CFrame.new(front - 4.6, 4.05, -38),
		color = Color3.fromRGB(220, 214, 200),
		collide = false,
	})
	StopKit.slot(refs, "book_return", returnBox, { book_return_hand = hand :: Instance })

	-- Quiet signs.
	local quiet = Build.model(refs.model, "QuietSigns")
	for _, cf in
		{
			CFrame.new(front + 0.6, 10, 8),
			CFrame.new(back - 0.6, 10, -10),
			CFrame.new(CENTRE.X, 10, CENTRE.Z + SIZE.Z / 2 - 0.6),
		}
	do
		local face = if cf.Position.X < CENTRE.X - 10
			then Enum.NormalId.Right
			elseif cf.Position.X > CENTRE.X + 10 then Enum.NormalId.Left
			else Enum.NormalId.Front
		local size = if face == Enum.NormalId.Front then Vector3.new(8, 1.6, 0.2) else Vector3.new(0.2, 1.6, 8)
		StopKit.sign(refs, {
			name = "Quiet",
			size = size,
			cf = cf,
			color = Color3.fromRGB(235, 230, 215),
			collide = false,
		}, "QUIET PLEASE", face, Color3.fromRGB(40, 40, 40), quiet)
	end
	StopKit.slot(refs, "quiet_signs", quiet)

	-- The reading room: tables, chairs, lamps, a globe.
	local lampSlot: Instance? = nil
	for i, z in { -16, -6, 4 } do
		for j, x in { front + 14, front + 24 } do
			local cf = CFrame.new(x, 0.4, z)
			Props.table(refs, cf, Vector3.new(4, 3, 7))
			for _, dz in { -2.2, 2.2 } do
				Props.chair(refs, cf * CFrame.new(-3, 0, dz) * CFrame.Angles(0, math.rad(90), 0))
			end
			local lamp = StopKit.part(refs, {
				name = "Lamp",
				size = Vector3.new(1.2, 0.6, 1.2),
				cf = cf * CFrame.new(0, 4.4, 0),
				color = Color3.fromRGB(40, 90, 60),
				material = Enum.Material.Glass,
				collide = false,
			})
			local light = Build.light(lamp, "Point", C.Warm, 0.7, 9, false)
			if i == 2 and j == 2 then
				-- This one is off; the anomaly lights it over an empty table, chair pulled out.
				light.Enabled = false
				lampSlot = lamp
			end
			StopKit.lootPoint(refs, cf.Position + Vector3.new(0.5, 3.8, 2))
		end
	end
	if lampSlot then
		StopKit.slot(refs, "reading_lamp", lampSlot)
	end
	local stand = StopKit.part(refs, {
		name = "GlobeStand",
		size = Vector3.new(0.4, 3.4, 0.4),
		cf = CFrame.new(front + 34, 2.1, -24),
		color = C.Wood,
		material = Enum.Material.Wood,
	})
	local _ = stand
	local globe = Build.model(refs.model, "Globe")
	local ball = StopKit.part(refs, {
		name = "Ball",
		size = Vector3.new(2.6, 2.6, 2.6),
		cf = CFrame.new(front + 34, 5, -24),
		color = Color3.fromRGB(60, 100, 130),
		material = Enum.Material.SmoothPlastic,
		shape = Enum.PartType.Ball,
	}, globe)
	StopKit.part(refs, {
		name = "Land",
		size = Vector3.new(1.4, 1.2, 0.2),
		cf = CFrame.new(front + 34, 5.3, -25.25),
		color = Color3.fromRGB(150, 130, 80),
		collide = false,
	}, globe)
	globe.PrimaryPart = ball
	StopKit.slot(refs, "globe", globe)

	-- The stacks: tall shelves in rows across the back half, with narrow aisles.
	local stacks = Build.model(refs.model, "Stacks")
	local rowZ = { 14, 21, 28, 35, 42 }
	for r, z in rowZ do
		for k, x0 in { front + 8, front + 30 } do
			local len = 18
			Props.shelf(
				refs,
				CFrame.new(x0 + len / 2, 0.4, z) * CFrame.Angles(0, math.rad(90), 0),
				len,
				11,
				stacks,
				r * 10 + k
			)
			StopKit.lootPoint(refs, Vector3.new(x0 + 4 + r, 1.4, z - 2.2))
			if r % 2 == 0 then
				StopKit.hidingSpot(refs, CFrame.new(x0 + len + 1.5, 3, z - 1.5))
			end
		end
	end
	-- A study carrel at the very back holds the fragment.
	Props.table(refs, CFrame.new(back - 5, 0.4, 42), Vector3.new(3, 3, 5), C.Wood)
	StopKit.fragmentSite(refs, Vector3.new(back - 5, 4.2, 42))
	StopKit.lootPoint(refs, Vector3.new(back - 5, 4.2, 38))
	-- Periodicals rack by the windows.
	Props.shelf(refs, CFrame.new(front + 2, 0.4, 24) * CFrame.Angles(0, math.rad(180), 0), 12, 5, nil, 99)
	StopKit.lootPoint(refs, Vector3.new(front + 2.5, 3.2, 22))

	-- The Librarian starts in the stacks.
	StopKit.entitySpawn(refs, CFrame.new(back - 8, 3, 30) * CFrame.Angles(0, math.rad(90), 0))
	StopKit.trailhead(refs, CFrame.new(100, 0, 62))
	StopKit.backEntrance(refs, CFrame.new(100, 3, -62))
	refs.extras.indoor = building
	return refs
end
