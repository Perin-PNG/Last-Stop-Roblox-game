--!strict
-- Mercy General ER. A waiting room by the ambulance bay, then a long corridor of
-- treatment bays to the pharmacy at the back. The pharmacy wing has no power: someone has
-- to hold the breaker in the back room, which is loud, and the Patient (a Listener that
-- can't see) comes to the noise. Medkits are behind the pharmacy shutter.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StopKit = require(script.Parent.Parent:WaitForChild("StopKit"))
local Props = require(script.Parent.Parent:WaitForChild("Props"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Build = require(Shared.Util.Build)
local Net = require(Shared.Net)
local Registry = require(script.Parent.Parent.Parent:WaitForChild("Registry"))

local C = Build.Colors

local CENTRE = Vector3.new(66, 8, 4)
local SIZE = Vector3.new(60, 16, 104)
local WALL = Color3.fromRGB(205, 210, 205)
local MINT = Color3.fromRGB(150, 190, 175)

return function(parent: Instance, frame: CFrame, ctx: StopKit.Ctx, title: string): StopKit.StopRefs
	local refs = StopKit.new(ctx.id, parent, frame)
	StopKit.basics(refs, title, 110, -72, 72)
	local front = CENTRE.X - SIZE.X / 2
	local back = CENTRE.X + SIZE.X / 2
	local zMin = CENTRE.Z - SIZE.Z / 2
	local zMax = CENTRE.Z + SIZE.Z / 2
	local building = StopKit.building(refs, "Hospital", CENTRE, SIZE, WALL, 8, -34)
	for _, d in building:GetChildren() do
		if d:IsA("BasePart") and (d.Name == "Wall" or d.Name == "Front" or d.Name == "Lintel") then
			d.Material = Enum.Material.Concrete
		end
	end
	-- Ambulance bay canopy and the red EMERGENCY sign.
	StopKit.part(refs, {
		name = "Canopy",
		size = Vector3.new(16, 1, 20),
		cf = CFrame.new(front - 8, 12, -34),
		color = WALL,
		material = Enum.Material.Concrete,
	})
	for _, z in { -42, -26 } do
		StopKit.part(refs, {
			name = "CanopyPost",
			size = Vector3.new(1, 12, 1),
			cf = CFrame.new(front - 15, 6, z),
			color = C.Metal,
			material = Enum.Material.Metal,
		})
	end
	local sign, signLabel = StopKit.sign(refs, {
		name = "Emergency",
		size = Vector3.new(0.6, 2.4, 18),
		cf = CFrame.new(front - 8, 13.8, -34),
		color = Color3.fromRGB(240, 240, 240),
		collide = false,
	}, "EMERGENCY", Enum.NormalId.Left, Color3.fromRGB(210, 20, 20))
	signLabel.Font = Enum.Font.GothamBlack
	local glow = Build.light(sign, "Surface", Color3.fromRGB(255, 60, 60), 1.5, 16, false) :: SurfaceLight
	glow.Face = Enum.NormalId.Left
	StopKit.sign(refs, {
		name = "HospitalName",
		size = Vector3.new(0.4, 2, 30),
		cf = CFrame.new(front - 0.4, 14, 14),
		color = MINT,
		collide = false,
	}, "MERCY GENERAL HOSPITAL", Enum.NormalId.Left, C.White)
	for z = -18, 44, 8 do
		Props.window(refs, CFrame.new(front - 0.6, 7.5, z), Vector2.new(4, 4), false)
	end
	StopKit.part(refs, {
		name = "Floor",
		size = Vector3.new(SIZE.X - 2, 0.05, SIZE.Z - 2),
		cf = CFrame.new(CENTRE.X, 0.45, CENTRE.Z),
		color = Color3.fromRGB(196, 196, 186),
		material = Enum.Material.Marble,
		collide = false,
	})

	-- Waiting room: rows of chairs, reception, the TV, the elevator.
	for row = 0, 2 do
		for k = 0, 4 do
			Props.chair(
				refs,
				CFrame.new(front + 10 + row * 5, 0.4, -46 + k * 2.6) * CFrame.Angles(0, math.rad(90), 0),
				Color3.fromRGB(70, 110, 130)
			)
		end
	end
	StopKit.lootPoint(refs, Vector3.new(front + 15, 2.6, -40))
	Props.counter(refs, CFrame.new(front + 30, 0.4, -40), Vector3.new(12, 3.8, 3), MINT)
	StopKit.hidingSpot(refs, CFrame.new(front + 30, 3, -37.5))
	StopKit.lootPoint(refs, Vector3.new(front + 28, 4.6, -40))
	local tv, tvLabel = StopKit.sign(refs, {
		name = "TV",
		size = Vector3.new(5, 3, 0.3),
		cf = CFrame.new(front + 14, 10, zMin + 0.8),
		color = C.Black,
		collide = false,
	}, "CHANNEL 9\nNO SIGNAL", Enum.NormalId.Back, Color3.fromRGB(180, 200, 255))
	tvLabel.Font = Enum.Font.Code
	StopKit.slot(refs, "tv", tv)
	local elevator = Build.model(refs.model, "Elevator")
	StopKit.part(refs, {
		name = "ElevatorDoors",
		size = Vector3.new(0.3, 8, 6),
		cf = CFrame.new(back - 0.8, 4.4, -44),
		color = C.Metal,
		material = Enum.Material.Metal,
	}, elevator)
	StopKit.sign(refs, {
		name = "Floor",
		size = Vector3.new(0.2, 1, 2),
		cf = CFrame.new(back - 1, 9.3, -44),
		color = C.Black,
		collide = false,
	}, "1", Enum.NormalId.Left, Color3.fromRGB(255, 160, 60), elevator)
	StopKit.slot(refs, "elevator", elevator)
	-- The empty wheelchair by the doors.
	local chair = Build.model(refs.model, "Wheelchair")
	local seat = StopKit.part(refs, {
		name = "Seat",
		size = Vector3.new(2.2, 0.4, 2.2),
		cf = CFrame.new(front + 6, 2.2, -28),
		color = C.Black,
		material = Enum.Material.Fabric,
	}, chair)
	for _, side in { -1, 1 } do
		StopKit.part(refs, {
			name = "Wheel",
			size = Vector3.new(0.3, 3, 3),
			cf = CFrame.new(front + 6 + side * 1.3, 1.9, -28),
			color = C.Metal,
			material = Enum.Material.Metal,
			shape = Enum.PartType.Cylinder,
			collide = false,
		}, chair)
	end
	StopKit.part(refs, {
		name = "Back",
		size = Vector3.new(2.2, 2.4, 0.3),
		cf = CFrame.new(front + 6, 3.6, -27),
		color = C.Black,
		material = Enum.Material.Fabric,
		collide = false,
	}, chair)
	chair.PrimaryPart = seat
	StopKit.slot(refs, "wheelchair", chair)

	-- The corridor: two long walls with bay openings, room numbers, and lights.
	local cx0, cx1 = CENTRE.X - 6, CENTRE.X + 6
	local corridorFrom, corridorTo = -26, 34
	local numbers: { TextLabel } = {}
	for _, x in { cx0, cx1 } do
		local z = corridorFrom
		while z < corridorTo do
			StopKit.part(refs, {
				name = "CorridorWall",
				size = Vector3.new(0.6, 15, 6),
				cf = CFrame.new(x, 7.9, z + 3),
				color = WALL,
				material = Enum.Material.Concrete,
			})
			z += 12 -- 6 of wall, a 6-stud bay opening
		end
	end
	for i = 1, 5 do
		local z = corridorFrom + 9 + (i - 1) * 12
		for side, x in { cx0, cx1 } do
			local _, label = StopKit.sign(refs, {
				name = "RoomNumber",
				size = Vector3.new(0.2, 1, 1.8),
				cf = CFrame.new(x + (if side == 1 then 0.4 else -0.4), 10, z - 4),
				color = MINT,
				collide = false,
			}, "E" .. (i * 2 - 2 + side), if side == 1 then Enum.NormalId.Right else Enum.NormalId.Left, C.Black)
			table.insert(numbers, label)
		end
		StopKit.ceilingLight(refs, Vector3.new(CENTRE.X, 15.2, z), C.Fluor, 18)
	end
	local corridorMarker = StopKit.marker(refs, "Corridor", CFrame.new(CENTRE.X, 3, 4))
	StopKit.slot(refs, "corridor", corridorMarker)

	-- Treatment bays on both sides: beds, curtains, a monitor.
	local monitorSlot: Instance? = nil
	for i = 1, 5 do
		local z = corridorFrom + 9 + (i - 1) * 12
		for side = -1, 1, 2 do
			local x = CENTRE.X + side * 16
			Props.bed(refs, CFrame.new(x + side * 4, 0.4, z) * CFrame.Angles(0, math.rad(90 * side), 0), MINT)
			local curtain = StopKit.part(refs, {
				name = "Curtain",
				size = Vector3.new(0.15, 10, 9),
				cf = CFrame.new(x - side * 3.5, 6, z),
				color = Color3.fromRGB(130, 170, 170),
				material = Enum.Material.Fabric,
				transparency = 0.1,
				collide = false,
			})
			if i == 3 and side == -1 then
				local feet = Build.model(refs.model, "Feet")
				for _, dz in { -0.5, 0.5 } do
					StopKit.part(refs, {
						name = "Foot",
						size = Vector3.new(1.2, 0.5, 0.6),
						cf = CFrame.new(x - side * 3.5 + 0.8, 0.7, z + dz),
						color = Color3.fromRGB(205, 190, 170),
						collide = false,
					}, feet)
				end
				StopKit.slot(refs, "curtain", curtain, { mercy_curtain_feet = feet :: Instance })
			end
			if i == 2 and side == 1 then
				local monitor, monitorLabel = StopKit.sign(refs, {
					name = "Monitor",
					size = Vector3.new(0.4, 2, 2.6),
					cf = CFrame.new(x + 8, 6, z + 3),
					color = C.Black,
					collide = false,
				}, "--", Enum.NormalId.Left, Color3.fromRGB(90, 255, 120))
				monitorLabel.Font = Enum.Font.Code
				monitorSlot = monitor
			end
			StopKit.lootPoint(refs, Vector3.new(x + side * 4, 3.2, z - 2))
			if i % 2 == 1 then
				StopKit.hidingSpot(refs, CFrame.new(x + side * 4, 2, z + 4.5))
			end
		end
	end
	if monitorSlot then
		StopKit.slot(refs, "monitor", monitorSlot)
	end

	-- The pharmacy at the end of the corridor, behind a shutter, dark until the breaker.
	local pz = corridorTo + 4
	StopKit.part(refs, {
		name = "PharmacyWall",
		size = Vector3.new(SIZE.X - 2, 15, 0.6),
		cf = CFrame.new(CENTRE.X, 7.9, pz),
		color = WALL,
		material = Enum.Material.Concrete,
	})
	local shutter = StopKit.part(refs, {
		name = "Shutter",
		size = Vector3.new(10, 8, 0.4),
		cf = CFrame.new(CENTRE.X, 4.4, pz - 0.6),
		color = C.Metal,
		material = Enum.Material.DiamondPlate,
	})
	local shutterOpen = shutter.CFrame * CFrame.new(0, 7, 0)
	StopKit.sign(refs, {
		name = "PharmacySign",
		size = Vector3.new(10, 1.4, 0.2),
		cf = CFrame.new(CENTRE.X, 10, pz - 0.7),
		color = MINT,
		collide = false,
	}, "PHARMACY", Enum.NormalId.Front, C.White)
	local pharmacyLights: { Light } = {}
	for _, x in { CENTRE.X - 14, CENTRE.X, CENTRE.X + 14 } do
		local bulb = StopKit.ceilingLight(refs, Vector3.new(x, 15.2, pz + 7), C.Fluor, 20)
		local l = bulb:FindFirstChildWhichIsA("Light")
		if l then
			l.Enabled = false
			table.insert(pharmacyLights, l)
		end
		bulb.Material = Enum.Material.Glass
	end
	for k, x in { CENTRE.X - 18, CENTRE.X - 6, CENTRE.X + 6, CENTRE.X + 18 } do
		Props.shelf(refs, CFrame.new(x, 0.4, zMax - 3) * CFrame.Angles(0, math.rad(90), 0), 9, 7, nil, 40 + k)
		StopKit.lootPoint(refs, Vector3.new(x, 1.4, zMax - 5), "medkit")
	end
	StopKit.lootPoint(refs, Vector3.new(CENTRE.X, 1.4, pz + 6), "medkit")
	StopKit.fragmentSite(refs, Vector3.new(CENTRE.X + 22, 1.5, pz + 8))

	-- The breaker in a back room off the waiting area.
	StopKit.part(refs, {
		name = "BreakerWall",
		size = Vector3.new(0.6, 15, 16),
		cf = CFrame.new(back - 12, 7.9, -36),
		color = WALL,
		material = Enum.Material.Concrete,
	})
	local breaker = StopKit.part(refs, {
		name = "Breaker",
		size = Vector3.new(0.6, 3.6, 2.6),
		cf = CFrame.new(back - 0.9, 5, -30),
		color = Color3.fromRGB(110, 115, 110),
		material = Enum.Material.Metal,
	})
	local breakerLight = StopKit.part(refs, {
		name = "BreakerLamp",
		size = Vector3.new(0.3, 0.4, 0.4),
		cf = CFrame.new(back - 1.3, 7.2, -30),
		color = Color3.fromRGB(200, 30, 30),
		material = Enum.Material.Neon,
		collide = false,
	})
	local breakerPrompt = Build.prompt(breaker, "Restore power", "Breaker", 3, 7, "BreakerPrompt")
	StopKit.lootPoint(refs, Vector3.new(back - 4, 1.4, -42))

	StopKit.entitySpawn(refs, CFrame.new(CENTRE.X, 3, 26))
	StopKit.trailhead(refs, CFrame.new(104, 0, 64))
	StopKit.backEntrance(refs, CFrame.new(104, 3, -64))

	-- Anomaly customs and the stop's runtime.
	local token = 0
	local function nearestPlayer(pos: Vector3): BasePart?
		local PlayerState = Registry.find("PlayerStateService")
		local best: BasePart? = nil
		local bestD = 60
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and (not PlayerState or PlayerState.isHealthy(player)) then
				local d = (root.Position - pos).Magnitude
				if d < bestD then
					best, bestD = root, d
				end
			end
		end
		return best
	end
	refs.extras.custom = {
		mercy_wheelchair = function(built: any)
			task.spawn(function()
				while built.active ~= false and chair.Parent do
					local pivot = chair:GetPivot()
					local root = nearestPlayer(pivot.Position)
					if root then
						local to = Vector3.new(root.Position.X, pivot.Position.Y, root.Position.Z)
						local d = to - pivot.Position
						if d.Magnitude > 5 then
							local nextPos = pivot.Position + d.Unit * 0.25
							chair:PivotTo(CFrame.lookAt(nextPos, to))
						end
					end
					task.wait(0.1)
				end
			end)
		end,
		mercy_monitor = function(built: any)
			if not monitorSlot then
				return
			end
			local label = monitorSlot:FindFirstChildWhichIsA("TextLabel", true)
			task.spawn(function()
				while built.active ~= false and label and label.Parent do
					label.Text = tostring(math.random(58, 64))
					task.wait(0.9)
				end
			end)
		end,
		hallway_longer = function(built: any)
			task.spawn(function()
				local changed = false
				while built.active ~= false and not changed do
					for _, player in Players:GetPlayers() do
						local character = player.Character
						local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
						if root and refs.frame:PointToObjectSpace(root.Position).Z > pz then
							changed = true
						end
					end
					task.wait(0.5)
				end
				if changed then
					-- On the way back the room numbers keep counting up.
					for i, label in numbers do
						label.Text = "E" .. (#numbers + i)
					end
				end
			end)
		end,
	}

	refs.extras.activate = function(built: any)
		token += 1
		local mine = token
		local powered = false
		shutter.CFrame = refs.frame * CFrame.new(CENTRE.X, 4.4, pz - 0.6)
		shutter.CanCollide = true
		for _, l in pharmacyLights do
			l.Enabled = false
		end
		breakerPrompt.Enabled = true
		breakerLight.Color = Color3.fromRGB(200, 30, 30)
		local conn: RBXScriptConnection? = nil
		conn = breakerPrompt.Triggered:Connect(function(player: Player)
			if mine ~= token or powered then
				return
			end
			local PlayerState = Registry.find("PlayerStateService")
			if PlayerState and not PlayerState.isHealthy(player) then
				return
			end
			powered = true
			breakerPrompt.Enabled = false
			breakerLight.Color = Color3.fromRGB(40, 220, 80)
			for _, l in pharmacyLights do
				l.Enabled = true
			end
			for _, d in refs.model:GetDescendants() do
				if d.Name == "CeilingLight" and d:IsA("BasePart") and d.Material == Enum.Material.Glass then
					d.Material = Enum.Material.Neon
				end
			end
			shutter.CFrame = shutterOpen
			shutter.CanCollide = false
			Net.notifyAll("Sound", { key = "DoorHiss", part = shutter })
			Net.notifyAll("Toast", { text = "The pharmacy shutter rattles open." })
			-- The breaker is loud: everything that listens hears it.
			local Noise = Registry.find("NoiseService")
			if Noise then
				Noise.post(breaker.Position, 70, "breaker", player)
				Noise.post(shutter.Position, 50, "shutter")
			end
			if conn then
				conn:Disconnect()
			end
		end)
		local _ = built
	end
	refs.extras.deactivate = function()
		token += 1
	end
	return refs
end
