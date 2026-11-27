--!strict
-- Hollis Farm Stand. A roadside produce stand, a hay wagon, and behind it a corn maze cut
-- fresh every night. The scarecrows in the corn only move while nobody's looking at them,
-- and the corn keeps sightlines short. Walk in pairs and look back often. The fragment is
-- somewhere in the maze.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StopKit = require(script.Parent.Parent:WaitForChild("StopKit"))
local Props = require(script.Parent.Parent:WaitForChild("Props"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Build = require(Shared.Util.Build)

local C = Build.Colors

local MAZE_X0, MAZE_Z0 = 40, -40
local CELL = 10
local COLS, ROWS = 6, 8 -- along X, along Z
local CORN = Color3.fromRGB(150, 150, 70)
local WOOD = Color3.fromRGB(130, 95, 60)
local ORANGE = Color3.fromRGB(220, 120, 30)

return function(parent: Instance, frame: CFrame, ctx: StopKit.Ctx, title: string): StopKit.StopRefs
	local refs = StopKit.new(ctx.id, parent, frame)
	StopKit.lot(refs, 112, -70, 70, Color3.fromRGB(90, 80, 55), Enum.Material.Ground)
	StopKit.sidewalk(refs, -60, 60)
	StopKit.shelter(refs, title)
	StopKit.approachLights(refs)
	refs.passengerSpot = StopKit.marker(refs, "PassengerSpot", CFrame.new(6, 3, -2))

	-- The stand: an open-fronted shed with a tin roof, crates, the scale and the pumpkins.
	local stand = Build.model(refs.model, "Stand")
	local sx, sz = 20, -30
	StopKit.part(refs, {
		name = "StandBack",
		size = Vector3.new(0.6, 9, 18),
		cf = CFrame.new(sx + 5, 4.9, sz),
		color = WOOD,
		material = Enum.Material.WoodPlanks,
	}, stand)
	for _, dz in { -9, 9 } do
		StopKit.part(refs, {
			name = "StandSide",
			size = Vector3.new(10, 9, 0.6),
			cf = CFrame.new(sx, 4.9, sz + dz),
			color = WOOD,
			material = Enum.Material.WoodPlanks,
		}, stand)
	end
	StopKit.part(refs, {
		name = "StandRoof",
		size = Vector3.new(13, 0.4, 20),
		cf = CFrame.new(sx - 1, 9.6, sz) * CFrame.Angles(0, 0, math.rad(-8)),
		color = Color3.fromRGB(140, 140, 135),
		material = Enum.Material.CorrodedMetal,
	}, stand)
	local _, standLabel = StopKit.sign(refs, {
		name = "StandSign",
		size = Vector3.new(0.4, 2, 12),
		cf = CFrame.new(sx - 5.4, 11, sz),
		color = Color3.fromRGB(235, 225, 200),
		collide = false,
	}, "HOLLIS FARM\nFRESH PRODUCE", Enum.NormalId.Left, Color3.fromRGB(160, 40, 30), stand)
	standLabel.Font = Enum.Font.Fondamento
	Props.counter(refs, CFrame.new(sx - 2, 0.4, sz), Vector3.new(3, 3.4, 14), WOOD, nil, stand)
	StopKit.hidingSpot(refs, CFrame.new(sx + 1, 2, sz + 5))
	for k = 0, 2 do
		StopKit.box(
			refs,
			"Crate",
			CFrame.new(sx - 2, 4.6, sz - 5 + k * 4),
			Vector3.new(2.6, 1.4, 3),
			WOOD,
			Enum.Material.WoodPlanks,
			stand
		)
		StopKit.lootPoint(refs, Vector3.new(sx - 2, 5.6, sz - 5 + k * 4))
	end
	-- The scale on the counter.
	local scale, scaleLabel = StopKit.sign(refs, {
		name = "Scale",
		size = Vector3.new(1.6, 1.2, 1.6),
		cf = CFrame.new(sx - 2, 4.5, sz + 6),
		color = Color3.fromRGB(200, 200, 195),
		material = Enum.Material.Metal,
		collide = false,
	}, "0.0 LB", Enum.NormalId.Left, C.Black, stand)
	scaleLabel.Font = Enum.Font.Code
	StopKit.slot(refs, "scale", scale)
	-- The pumpkins, carved faces turned away from the road.
	local pumpkins = Build.model(refs.model, "Pumpkins")
	local pile = { Vector3.new(-1, 0, -1.5), Vector3.new(1, 0, 0), Vector3.new(-1, 0, 1.5), Vector3.new(0, 1.6, 0) }
	local pcx, pcz = sx - 7, sz + 12
	for k, off in pile do
		for j = 0, 1 do
			local pos = Vector3.new(pcx + off.X, 1.4 + off.Y, pcz + off.Z + j * 5)
			local pumpkin = StopKit.part(refs, {
				name = "Pumpkin",
				size = Vector3.new(2.2, 2, 2.2),
				cf = CFrame.new(pos),
				color = ORANGE,
				material = Enum.Material.SmoothPlastic,
				shape = Enum.PartType.Ball,
			}, pumpkins)
			StopKit.part(refs, {
				name = "Face",
				size = Vector3.new(0.1, 0.6, 1),
				cf = CFrame.new(pos + Vector3.new(1.05, 0.1, 0)),
				color = C.Black,
				collide = false,
			}, pumpkin)
			StopKit.part(refs, {
				name = "Stem",
				size = Vector3.new(0.3, 0.5, 0.3),
				cf = CFrame.new(pos + Vector3.new(0, 1.1, 0)),
				color = Color3.fromRGB(80, 90, 40),
				collide = false,
			}, pumpkin)
			local _ = k
		end
	end
	pumpkins.WorldPivot = refs.frame * CFrame.new(pcx, 1.4, pcz + 2.5)
	StopKit.slot(refs, "pumpkins", pumpkins)

	-- The hay wagon.
	StopKit.part(refs, {
		name = "Wagon",
		size = Vector3.new(8, 1, 14),
		cf = CFrame.new(26, 2.4, 8),
		color = WOOD,
		material = Enum.Material.WoodPlanks,
	})
	for _, dz in { -5, 5 } do
		for _, dx in { -3.6, 3.6 } do
			local w = StopKit.part(refs, {
				name = "WagonWheel",
				size = Vector3.new(0.5, 3, 3),
				cf = CFrame.new(26 + dx, 1.9, 8 + dz),
				color = C.Black,
				material = Enum.Material.Wood,
				shape = Enum.PartType.Cylinder,
				collide = false,
			})
			local _ = w
		end
	end
	for k = 0, 2 do
		StopKit.box(
			refs,
			"HayBale",
			CFrame.new(26, 4, 3.5 + k * 4.5),
			Vector3.new(4, 2.2, 3.6),
			Color3.fromRGB(200, 170, 90),
			Enum.Material.Grass
		)
	end
	StopKit.hidingSpot(refs, CFrame.new(31.5, 2, 8))
	StopKit.lootPoint(refs, Vector3.new(26, 5.6, 12))

	-- The maze: a recursive backtracker on a 6x8 grid, a new layout each night.
	local maze = Build.model(refs.model, "CornMaze")
	local rng = ctx.rng:child("maze")
	local visited: { [number]: boolean } = {}
	-- walls[cell][dir]: true while the wall stands. dir 1 = +X, 2 = +Z.
	local wallX: { [number]: boolean } = {} -- wall between (c, r) and (c+1, r)
	local wallZ: { [number]: boolean } = {} -- wall between (c, r) and (c, r+1)
	local function key(c: number, r: number): number
		return r * 100 + c
	end
	for c = 0, COLS - 1 do
		for r = 0, ROWS - 1 do
			wallX[key(c, r)] = c < COLS - 1
			wallZ[key(c, r)] = r < ROWS - 1
		end
	end
	local stack: { { number } } = { { 0, ROWS // 2 } }
	visited[key(0, ROWS // 2)] = true
	local deadEnds: { Vector3 } = {}
	while #stack > 0 do
		local top = stack[#stack]
		local c, r = top[1], top[2]
		local options: { { number } } = {}
		for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
			local nc, nr = c + d[1], r + d[2]
			if nc >= 0 and nc < COLS and nr >= 0 and nr < ROWS and not visited[key(nc, nr)] then
				table.insert(options, { nc, nr })
			end
		end
		if #options == 0 then
			table.remove(stack)
			local moves = 0
			if c < COLS - 1 and not wallX[key(c, r)] then
				moves += 1
			end
			if c > 0 and not wallX[key(c - 1, r)] then
				moves += 1
			end
			if r < ROWS - 1 and not wallZ[key(c, r)] then
				moves += 1
			end
			if r > 0 and not wallZ[key(c, r - 1)] then
				moves += 1
			end
			if moves == 1 then
				table.insert(deadEnds, Vector3.new(MAZE_X0 + (c + 0.5) * CELL, 0, MAZE_Z0 + (r + 0.5) * CELL))
			end
		else
			local pick = options[rng:int(1, #options)]
			local nc, nr = pick[1], pick[2]
			if nc ~= c then
				wallX[key(math.min(c, nc), r)] = false
			else
				wallZ[key(c, math.min(r, nr))] = false
			end
			visited[key(nc, nr)] = true
			table.insert(stack, { nc, nr })
		end
	end
	-- Knock out a few extra walls so the maze has loops (and two ways to run).
	for _ = 1, 6 do
		local c, r = rng:int(0, COLS - 2), rng:int(0, ROWS - 2)
		if rng:float(0, 1) < 0.5 then
			wallX[key(c, r)] = false
		else
			wallZ[key(c, r)] = false
		end
	end
	local height = 9
	local function cornWall(cx: number, cz: number, sizeX: number, sizeZ: number)
		StopKit.part(refs, {
			name = "Corn",
			size = Vector3.new(sizeX, height, sizeZ),
			cf = CFrame.new(cx, height / 2 + 0.4, cz),
			color = CORN,
			material = Enum.Material.Grass,
		}, maze)
		-- Tassels along the top so the wall reads as corn, not a hedge.
		StopKit.part(refs, {
			name = "Tassels",
			size = Vector3.new(sizeX, 0.8, sizeZ) - Vector3.new(0.4, 0, 0.4),
			cf = CFrame.new(cx, height + 0.8, cz),
			color = Color3.fromRGB(200, 180, 100),
			material = Enum.Material.Grass,
			collide = false,
		}, maze)
	end
	local t = 2 -- corn rows are thick
	for c = 0, COLS - 1 do
		for r = 0, ROWS - 1 do
			local x0 = MAZE_X0 + c * CELL
			local z0 = MAZE_Z0 + r * CELL
			if wallX[key(c, r)] then
				cornWall(x0 + CELL, z0 + CELL / 2, t, CELL + t)
			end
			if wallZ[key(c, r)] then
				cornWall(x0 + CELL / 2, z0 + CELL, CELL + t, t)
			end
		end
	end
	-- Outer walls, with the entrance at the front middle and an exit at the back corner.
	local mazeX1 = MAZE_X0 + COLS * CELL
	local mazeZ1 = MAZE_Z0 + ROWS * CELL
	local entryR = ROWS // 2
	for r = 0, ROWS - 1 do
		local z = MAZE_Z0 + (r + 0.5) * CELL
		if r ~= entryR then
			cornWall(MAZE_X0, z, t, CELL + t)
		end
		if r ~= ROWS - 1 then
			cornWall(mazeX1, z, t, CELL + t)
		end
	end
	for c = 0, COLS - 1 do
		local x = MAZE_X0 + (c + 0.5) * CELL
		cornWall(x, MAZE_Z0, CELL + t, t)
		cornWall(x, mazeZ1, CELL + t, t)
	end
	StopKit.sign(refs, {
		name = "MazeSign",
		size = Vector3.new(0.3, 2, 6),
		cf = CFrame.new(MAZE_X0 - 2, 5, MAZE_Z0 + (entryR + 0.5) * CELL - 6),
		color = Color3.fromRGB(235, 225, 200),
		collide = false,
	}, "CORN MAZE\nENTER", Enum.NormalId.Left, Color3.fromRGB(160, 40, 30))

	-- What's in the maze: loot and hiding spots in the dead ends, the fragment in the
	-- farthest one, scarecrow spawns across the middle.
	table.sort(deadEnds, function(a: Vector3, b: Vector3): boolean
		return a.X + math.abs(a.Z) * 0.5 > b.X + math.abs(b.Z) * 0.5
	end)
	for i, p in deadEnds do
		if i == 1 then
			StopKit.fragmentSite(refs, p + Vector3.new(0, 1.5, 0))
		elseif i <= 8 then
			StopKit.lootPoint(refs, p + Vector3.new(1, 1.4, 1))
		end
		if i <= 6 then
			StopKit.hidingSpot(refs, CFrame.new(p + Vector3.new(-2, 2, -2)))
		end
	end
	if #deadEnds == 0 then
		StopKit.fragmentSite(refs, Vector3.new(mazeX1 - CELL / 2, 1.5, mazeZ1 - CELL / 2))
	end
	for _, cell in { { 2, 1 }, { 3, 6 }, { 4, 3 }, { 1, 5 }, { 5, 0 }, { 5, 7 } } do
		StopKit.entitySpawn(
			refs,
			CFrame.new(MAZE_X0 + (cell[1] + 0.5) * CELL, 3, MAZE_Z0 + (cell[2] + 0.5) * CELL)
				* CFrame.Angles(0, math.rad(90), 0)
		)
	end

	-- Three scarecrow posts out front of the maze. The third one's scarecrow may be gone.
	local postSlot: Instance? = nil
	local emptyPost: Instance? = nil
	for k, z in { -52, -46, 52 } do
		local px = 36 + k * 2
		StopKit.part(refs, {
			name = "Post",
			size = Vector3.new(0.8, 10, 0.8),
			cf = CFrame.new(px, 5.4, z),
			color = WOOD,
			material = Enum.Material.Wood,
		})
		StopKit.part(refs, {
			name = "CrossBar",
			size = Vector3.new(0.6, 0.6, 6),
			cf = CFrame.new(px, 8, z),
			color = WOOD,
			material = Enum.Material.Wood,
		})
		local crow = StopKit.figure(
			refs,
			"PostScarecrow",
			CFrame.new(px - 0.7, 2.2, z) * CFrame.Angles(0, math.rad(90), 0),
			Color3.fromRGB(110, 80, 50),
			nil,
			{ skin = Color3.fromRGB(190, 160, 100), pants = Color3.fromRGB(60, 70, 90) }
		)
		if k == 3 then
			postSlot = crow
			local rope = StopKit.part(refs, {
				name = "CutRope",
				size = Vector3.new(0.15, 1.6, 0.15),
				cf = CFrame.new(px - 0.5, 7, z),
				color = Color3.fromRGB(180, 160, 110),
				collide = false,
			})
			StopKit.setShown(rope, false)
			emptyPost = rope
		end
	end
	if postSlot and emptyPost then
		StopKit.slot(refs, "post", postSlot, { farm_empty_post = emptyPost })
	end

	-- A string of bulbs over the stand, the farmhouse light far off, fences.
	for k = 0, 5 do
		local bulb = StopKit.part(refs, {
			name = "Bulb",
			size = Vector3.new(0.4, 0.5, 0.4),
			cf = CFrame.new(sx - 6.5, 9.5 - (k % 2) * 0.3, sz - 8 + k * 3.2),
			color = Color3.fromRGB(255, 210, 140),
			material = Enum.Material.Neon,
			collide = false,
		})
		if k % 2 == 0 then
			Build.light(bulb, "Point", C.Warm, 0.8, 12, false)
		end
	end
	Props.fence(refs, Vector3.new(12, 0, -64), Vector3.new(108, 0, -64), WOOD)
	Props.fence(refs, Vector3.new(12, 0, 64), Vector3.new(108, 0, 64), WOOD)
	Props.tree(refs, Vector3.new(106, 0.4, -50), 22)
	Props.tree(refs, Vector3.new(14, 0.4, 40), 16)
	StopKit.trailhead(refs, CFrame.new(108, 0, 58))
	StopKit.backEntrance(refs, CFrame.new(108, 3, -58))
	return refs
end
