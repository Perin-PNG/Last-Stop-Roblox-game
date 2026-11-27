--!strict
-- Riverside Motel. One long row of eight rooms behind a walkway, an office by the road and
-- a drained pool in the courtyard. Rooms hold supplies. The Guest in Room 6 moves through
-- the walls: every so often three knocks come from inside one of the doors. Open a door
-- while it's knocking, or just after, and the Guest is waiting behind it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StopKit = require(script.Parent.Parent:WaitForChild("StopKit"))
local Props = require(script.Parent.Parent:WaitForChild("Props"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Build = require(Shared.Util.Build)
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Registry = require(script.Parent.Parent.Parent:WaitForChild("Registry"))

local C = Build.Colors

local ROW_X0, ROW_X1 = 80, 94 -- the room block, front face at ROW_X0
local ROOM_W = 12
local ROW_Z0 = -48
local ROOMS = 8
local H = 10
local STUCCO = Color3.fromRGB(200, 170, 140)
local TRIM = Color3.fromRGB(60, 110, 120)
local KNOCK_WINDOW = 4 -- seconds after the third knock that a door is still unsafe

type Room = {
	number: number,
	door: Props.Door?, -- nil for Room 6, which never opens
	doorPart: BasePart,
	z: number,
	knockingUntil: number,
	zone: BasePart,
}

return function(parent: Instance, frame: CFrame, ctx: StopKit.Ctx, title: string): StopKit.StopRefs
	local refs = StopKit.new(ctx.id, parent, frame)
	StopKit.basics(refs, title, 112, -70, 70)
	local block = Build.model(refs.model, "Rooms")
	local depth = ROW_X1 - ROW_X0
	local zEnd = ROW_Z0 + ROOMS * ROOM_W
	local midX = (ROW_X0 + ROW_X1) / 2
	local midZ = (ROW_Z0 + zEnd) / 2

	-- The block: back wall, end walls, roof with an overhang over the walkway.
	StopKit.part(refs, {
		name = "Wall",
		size = Vector3.new(1, H, zEnd - ROW_Z0),
		cf = CFrame.new(ROW_X1 - 0.5, H / 2 + 0.4, midZ),
		color = STUCCO,
		material = Enum.Material.Plaster,
	}, block)
	for _, z in { ROW_Z0, zEnd } do
		StopKit.part(refs, {
			name = "EndWall",
			size = Vector3.new(depth, H, 1),
			cf = CFrame.new(midX, H / 2 + 0.4, z),
			color = STUCCO,
			material = Enum.Material.Plaster,
		}, block)
	end
	StopKit.part(refs, {
		name = "Roof",
		size = Vector3.new(depth + 8, 1, zEnd - ROW_Z0 + 4),
		cf = CFrame.new(midX - 4, H + 0.9, midZ),
		color = Color3.fromRGB(90, 70, 60),
		material = Enum.Material.Slate,
	}, block)
	StopKit.part(refs, {
		name = "Fascia",
		size = Vector3.new(0.6, 1.6, zEnd - ROW_Z0 + 4),
		cf = CFrame.new(ROW_X0 - 8, H + 0.6, midZ),
		color = TRIM,
	}, block)
	StopKit.part(refs, {
		name = "Walkway",
		size = Vector3.new(8, 0.4, zEnd - ROW_Z0 + 8),
		cf = CFrame.new(ROW_X0 - 4, 0.6, midZ),
		color = Color3.fromRGB(150, 145, 135),
		material = Enum.Material.Concrete,
	}, block)
	for z = ROW_Z0, zEnd, ROOM_W * 2 do
		StopKit.part(refs, {
			name = "Post",
			size = Vector3.new(0.6, H, 0.6),
			cf = CFrame.new(ROW_X0 - 7.6, H / 2 + 0.6, z),
			color = TRIM,
			material = Enum.Material.Metal,
		}, block)
	end

	-- Rooms.
	local rooms: { Room } = {}
	local room6Door: BasePart? = nil
	local room6Glow: Model? = nil
	for i = 1, ROOMS do
		local z0 = ROW_Z0 + (i - 1) * ROOM_W
		local doorZ = z0 + 3.5
		local room = Build.model(block, "Room" .. i)
		if i > 1 then
			StopKit.part(refs, {
				name = "Divider",
				size = Vector3.new(depth - 1, H, 0.6),
				cf = CFrame.new(midX - 0.5, H / 2 + 0.4, z0),
				color = Color3.fromRGB(180, 160, 135),
				material = Enum.Material.Plaster,
			}, room)
		end
		-- Front wall: a strip each side of the 4-wide door, a window, and the header.
		local function front(zA: number, zB: number)
			if zB - zA > 0.1 then
				StopKit.part(refs, {
					name = "Front",
					size = Vector3.new(1, H, zB - zA),
					cf = CFrame.new(ROW_X0 + 0.5, H / 2 + 0.4, (zA + zB) / 2),
					color = STUCCO,
					material = Enum.Material.Plaster,
				}, room)
			end
		end
		front(z0, doorZ - 2)
		front(doorZ + 2, z0 + ROOM_W)
		StopKit.part(refs, {
			name = "Header",
			size = Vector3.new(1, H - 8, 4),
			cf = CFrame.new(ROW_X0 + 0.5, 8.4 + (H - 8) / 2, doorZ),
			color = STUCCO,
			material = Enum.Material.Plaster,
		}, room)
		Props.window(refs, CFrame.new(ROW_X0 - 0.1, 5, z0 + 8.5), Vector2.new(4, 3.5), i == 2 or i == 7, room)
		local _, numLabel = StopKit.sign(refs, {
			name = "Number",
			size = Vector3.new(0.2, 1, 1),
			cf = CFrame.new(ROW_X0 - 0.15, 9, doorZ + 3),
			color = Color3.fromRGB(190, 160, 70),
			material = Enum.Material.Metal,
			collide = false,
		}, tostring(i), Enum.NormalId.Left, C.Black, room)
		numLabel.Font = Enum.Font.Arcade
		-- Inside: bed, nightstand, TV, and supplies.
		Props.bed(refs, CFrame.new(midX + 2.5, 0.4, z0 + 8) * CFrame.Angles(0, math.rad(-90), 0), nil, room)
		StopKit.lootPoint(refs, Vector3.new(midX + 4, 2.8, z0 + 2.5))
		StopKit.lootPoint(refs, Vector3.new(midX - 3, 1.4, z0 + 10.5), if i % 3 == 0 then "keys" else nil)
		StopKit.hidingSpot(refs, CFrame.new(midX + 5.5, 2, z0 + 11))
		local zone = StopKit.part(refs, {
			name = "IndoorZone",
			size = Vector3.new(depth - 1, H, ROOM_W - 0.8),
			cf = CFrame.new(midX, H / 2 + 0.4, z0 + ROOM_W / 2),
			transparency = 1,
			collide = false,
			query = false,
		}, room)
		table.insert(refs.interior, zone)
		local doorCf = CFrame.new(ROW_X0 + 0.5, 0.4, doorZ)
		if i == 6 then
			-- Room 6: a door that is never opened from outside.
			local d = StopKit.part(refs, {
				name = "Door6",
				size = Vector3.new(0.35, 8, 4),
				cf = doorCf * CFrame.new(0, 4, 0),
				color = TRIM,
				material = Enum.Material.Wood,
			}, room)
			StopKit.part(refs, {
				name = "DoNotDisturb",
				size = Vector3.new(0.05, 1.2, 0.5),
				cf = doorCf * CFrame.new(-0.25, 4, 1.5),
				color = Color3.fromRGB(200, 40, 40),
				collide = false,
			}, d)
			room6Door = d
			-- The ajar variant: a bright crack down the hinge side and a TV glowing inside.
			local glow = Build.model(room, "Ajar")
			StopKit.part(refs, {
				name = "Crack",
				size = Vector3.new(0.4, 7.6, 0.25),
				cf = doorCf * CFrame.new(-0.05, 4, -1.9),
				color = Color3.fromRGB(170, 200, 255),
				material = Enum.Material.Neon,
				collide = false,
			}, glow)
			local tv = StopKit.part(refs, {
				name = "TV",
				size = Vector3.new(1.6, 1.4, 2),
				cf = CFrame.new(ROW_X1 - 2, 3.6, z0 + 3),
				color = Color3.fromRGB(150, 180, 255),
				material = Enum.Material.Neon,
				collide = false,
			}, glow)
			Build.light(tv, "Point", Color3.fromRGB(150, 180, 255), 2, 14, true)
			StopKit.setShown(glow, false)
			room6Glow = glow
			local entry: Room = {
				number = i,
				door = nil,
				doorPart = d,
				z = doorZ,
				knockingUntil = 0,
				zone = zone,
			}
			table.insert(rooms, entry)
		else
			local door = Props.door(refs, doorCf, 4, 8, TRIM, room, "Room " .. i)
			local entry: Room = {
				number = i,
				door = door,
				doorPart = door.part,
				z = doorZ,
				knockingUntil = 0,
				zone = zone,
			}
			table.insert(rooms, entry)
		end
		-- A light over each door, one of them out.
		if i ~= 4 then
			local lamp = StopKit.part(refs, {
				name = "DoorLamp",
				size = Vector3.new(0.6, 0.8, 0.6),
				cf = CFrame.new(ROW_X0 - 0.4, 9.2, doorZ - 3),
				color = Color3.fromRGB(255, 220, 160),
				material = Enum.Material.Neon,
				collide = false,
			}, room)
			Build.light(lamp, "Point", C.Warm, 0.8, 10, false)
		end
	end
	if room6Door and room6Glow then
		StopKit.slot(refs, "room6", room6Door, { motel_door_ajar = room6Glow :: Instance })
	end

	-- The office by the road: counter, the key board.
	local office = StopKit.building(refs, "Office", Vector3.new(30, 5.4, -40), Vector3.new(16, 10, 18), STUCCO, 5, -40)
	for _, d in office:GetChildren() do
		if d:IsA("BasePart") and (d.Name == "Wall" or d.Name == "Front" or d.Name == "Lintel") then
			d.Material = Enum.Material.Plaster
		end
	end
	StopKit.sign(refs, {
		name = "OfficeSign",
		size = Vector3.new(0.3, 1.4, 6),
		cf = CFrame.new(21.6, 9, -40),
		color = TRIM,
		collide = false,
	}, "OFFICE", Enum.NormalId.Left, C.White)
	Props.counter(refs, CFrame.new(32, 0.4, -40), Vector3.new(3, 3.6, 10), C.Wood)
	StopKit.hidingSpot(refs, CFrame.new(34.5, 2, -40))
	StopKit.lootPoint(refs, Vector3.new(32, 4.4, -43))
	local board = StopKit.part(refs, {
		name = "KeyBoard",
		size = Vector3.new(0.3, 3, 5),
		cf = CFrame.new(37.3, 5.5, -40),
		color = C.Wood,
		material = Enum.Material.Wood,
	})
	local sixes = Build.model(refs.model, "AllSixes")
	for k = 1, 8 do
		local row, col = (k - 1) // 4, (k - 1) % 4
		local hookCf = CFrame.new(37.05, 6.3 - row * 1.4, -41.8 + col * 1.2)
		local _, tag = StopKit.sign(refs, {
			name = "Tag",
			size = Vector3.new(0.05, 0.6, 0.5),
			cf = hookCf,
			color = Color3.fromRGB(200, 60, 40),
			collide = false,
		}, tostring(k), Enum.NormalId.Left, C.White, board)
		tag.Font = Enum.Font.Arcade
		local _, six = StopKit.sign(refs, {
			name = "Tag6",
			size = Vector3.new(0.05, 0.6, 0.5),
			cf = hookCf * CFrame.new(-0.06, 0, 0),
			color = Color3.fromRGB(200, 60, 40),
			collide = false,
		}, "6", Enum.NormalId.Left, C.White, sixes)
		six.Font = Enum.Font.Arcade
	end
	StopKit.setShown(sixes, false)
	StopKit.slot(refs, "key_board", board, { motel_all_sixes = sixes :: Instance })

	-- The road sign, with its own vacancy panel.
	StopKit.part(refs, {
		name = "SignPole",
		size = Vector3.new(1, 20, 1),
		cf = CFrame.new(14, 10.4, 34),
		color = C.Metal,
		material = Enum.Material.Metal,
	})
	local _, nameLabel = StopKit.sign(refs, {
		name = "MotelSign",
		size = Vector3.new(0.6, 5, 14),
		cf = CFrame.new(14, 21, 34),
		color = TRIM,
		collide = false,
	}, "RIVERSIDE\nMOTEL", Enum.NormalId.Left, Color3.fromRGB(255, 200, 120))
	nameLabel.Font = Enum.Font.Bangers
	local vacancy, vacancyLabel = StopKit.sign(refs, {
		name = "Vacancy",
		size = Vector3.new(0.5, 1.6, 10),
		cf = CFrame.new(14, 17, 34),
		color = C.Black,
		collide = false,
	}, "VACANCY", Enum.NormalId.Left, Color3.fromRGB(255, 60, 90))
	vacancyLabel.Font = Enum.Font.Arcade
	local vglow = Build.light(vacancy, "Surface", Color3.fromRGB(255, 60, 90), 1, 12, true) :: SurfaceLight
	vglow.Face = Enum.NormalId.Left
	StopKit.slot(refs, "sign", vacancy)

	-- The drained pool, its fence, and the light at the bottom.
	local pool = Build.model(refs.model, "Pool")
	local px, pz, pw, pl = 52, 6, 18, 26
	StopKit.part(refs, {
		name = "PoolFloor",
		size = Vector3.new(pw, 0.2, pl),
		cf = CFrame.new(px, 0.45, pz),
		color = Color3.fromRGB(80, 120, 130),
		material = Enum.Material.Marble,
	}, pool)
	for _, e in
		{
			{ Vector3.new(pw + 2, 1, 1), Vector3.new(0, 0, -pl / 2 - 0.5) },
			{ Vector3.new(pw + 2, 1, 1), Vector3.new(0, 0, pl / 2 + 0.5) },
			{ Vector3.new(1, 1, pl), Vector3.new(-pw / 2 - 0.5, 0, 0) },
			{ Vector3.new(1, 1, pl), Vector3.new(pw / 2 + 0.5, 0, 0) },
		}
	do
		StopKit.part(refs, {
			name = "Coping",
			size = e[1],
			cf = CFrame.new(px, 0.9, pz) + e[2],
			color = Color3.fromRGB(215, 210, 200),
			material = Enum.Material.Concrete,
		}, pool)
	end
	StopKit.part(refs, {
		name = "Leaves",
		size = Vector3.new(6, 0.1, 5),
		cf = CFrame.new(px + 4, 0.6, pz + 8),
		color = Color3.fromRGB(90, 70, 40),
		material = Enum.Material.Grass,
		collide = false,
	}, pool)
	local poolLight = StopKit.part(refs, {
		name = "PoolLight",
		size = Vector3.new(0.2, 1.2, 1.2),
		cf = CFrame.new(px + pw / 2 - 0.1, 1, pz),
		color = Color3.fromRGB(120, 200, 255),
		material = Enum.Material.Glass,
		collide = false,
	}, pool)
	Build.light(poolLight, "Point", Color3.fromRGB(80, 200, 255), 3, 22, false).Enabled = false
	StopKit.slot(refs, "pool", poolLight)
	Props.fence(
		refs,
		Vector3.new(px - pw / 2 - 4, 0, pz - pl / 2 - 4),
		Vector3.new(px + pw / 2 + 4, 0, pz - pl / 2 - 4)
	)
	Props.fence(
		refs,
		Vector3.new(px - pw / 2 - 4, 0, pz + pl / 2 + 4),
		Vector3.new(px + pw / 2 + 4, 0, pz + pl / 2 + 4)
	)
	for k = 0, 2 do
		Props.chair(
			refs,
			CFrame.new(px - pw / 2 - 2.5, 0.4, pz - 6 + k * 6) * CFrame.Angles(0, math.rad(90), 0),
			C.White
		)
	end
	StopKit.lootPoint(refs, Vector3.new(px - pw / 2 - 2.5, 1.4, pz + 8))

	-- The ice machine at the end of the walkway.
	local ice = StopKit.part(refs, {
		name = "IceMachine",
		size = Vector3.new(3, 6, 3.5),
		cf = CFrame.new(ROW_X0 - 2, 3.6, ROW_Z0 - 3),
		color = Color3.fromRGB(200, 205, 210),
		material = Enum.Material.Metal,
	})
	StopKit.sign(refs, {
		name = "IceLabel",
		size = Vector3.new(0.1, 1, 2.6),
		cf = CFrame.new(ROW_X0 - 3.55, 5.6, ROW_Z0 - 3),
		color = Color3.fromRGB(40, 100, 180),
		collide = false,
	}, "ICE", Enum.NormalId.Left, C.White)
	local fingers = Build.model(refs.model, "IceHand")
	for k = 0, 3 do
		StopKit.part(refs, {
			name = "Finger",
			size = Vector3.new(0.8, 0.25, 0.25),
			cf = CFrame.new(ROW_X0 - 3.7, 3.2, ROW_Z0 - 3.6 + k * 0.4),
			color = Color3.fromRGB(205, 195, 180),
			collide = false,
		}, fingers)
	end
	StopKit.setShown(fingers, false)
	StopKit.slot(refs, "ice_machine", ice, { motel_ice_hand = fingers :: Instance })

	-- The lure: a spare key on the walkway, tagged 6. Hidden unless the anomaly rolls.
	local key = StopKit.part(refs, {
		name = "SpareKey",
		size = Vector3.new(0.6, 0.15, 1),
		cf = CFrame.new(ROW_X0 - 3, 0.9, 30),
		color = Color3.fromRGB(210, 180, 80),
		material = Enum.Material.Metal,
		collide = false,
	})
	local keyPrompt = Build.prompt(key, "Pick up", "Key (Room 6)", 0, 6, "KeyPrompt")
	keyPrompt.Enabled = false
	StopKit.setShown(key, false)
	StopKit.slot(refs, "lure_key", key)

	-- Parking spaces with a few cars in front of the rooms.
	Props.parkedCars(refs, 62, -44, 40, 12, ctx.stopIndex * 7 + 3)
	Props.tree(refs, Vector3.new(20, 0.4, 12), 14)
	Props.tree(refs, Vector3.new(102, 0.4, -60), 18)
	Props.tree(refs, Vector3.new(104, 0.4, 58), 16)

	StopKit.fragmentSite(refs, Vector3.new(midX + 4, 2.8, ROW_Z0 + 7 * ROOM_W + 9))
	StopKit.entitySpawn(refs, CFrame.new(midX, 3, ROW_Z0 + 5 * ROOM_W + 6))
	StopKit.trailhead(refs, CFrame.new(106, 0, 64))
	StopKit.backEntrance(refs, CFrame.new(106, 3, -64))

	-- The Guest.
	local token = 0
	local def = Config.Entities.guest
	local function guestOut(room: Room, opener: Player?)
		room.knockingUntil = 0
		local at = room.doorPart.Position - refs.frame.RightVector * 2
		local body = StopKit.part(refs, {
			name = "Guest",
			size = Vector3.new(2, 7.5, 1.2),
			cf = CFrame.new(ROW_X0 - 1.5, 4.2, room.z),
			color = def.color,
			material = Enum.Material.Fabric,
			collide = false,
		})
		StopKit.part(refs, {
			name = "Head",
			size = Vector3.new(1.3, 1.5, 1.3),
			cf = CFrame.new(ROW_X0 - 1.5, 8.8, room.z),
			color = Color3.fromRGB(215, 205, 190),
			collide = false,
		}, body)
		Net.notifyAll("Sound", { key = "Sting", part = body })
		local PlayerState = Registry.find("PlayerStateService")
		if opener and PlayerState and PlayerState.isHealthy(opener) then
			PlayerState.down(opener, "guest")
		end
		Props.downNear(at, Config.Tuning.Entities.AmbusherRange, "guest")
		task.delay(1.6, function()
			body:Destroy()
			if room.door then
				room.door.set(false)
			end
		end)
	end

	local knockConns: { RBXScriptConnection } = {}
	for _, room in rooms do
		local door = room.door
		if door then
			table.insert(
				knockConns,
				door.changed.Event:Connect(function(isOpen: boolean)
					if isOpen and token > 0 and workspace:GetServerTimeNow() < room.knockingUntil then
						-- Whoever is closest to the door opened it.
						local opener: Player? = nil
						local best = 10
						for _, player in Players:GetPlayers() do
							local character = player.Character
							local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
							if root then
								local d = (root.Position - room.doorPart.Position).Magnitude
								if d < best then
									opener, best = player, d
								end
							end
						end
						guestOut(room, opener)
					end
				end)
			)
		end
	end
	local _ = knockConns

	local function knock(room: Room)
		Net.notifyAll("Sound", { key = def.telegraphSound or "ThreeKnocks", part = room.doorPart })
		room.knockingUntil = workspace:GetServerTimeNow() + 2.4 + KNOCK_WINDOW
		local Noise = Registry.find("NoiseService")
		if Noise then
			Noise.post(room.doorPart.Position, 30, "knock")
		end
	end

	refs.extras.custom = {
		motel_lure_key = function(built: any)
			StopKit.setShown(key, true)
			keyPrompt.Enabled = true
			local conn: RBXScriptConnection? = nil
			conn = keyPrompt.Triggered:Connect(function(player: Player)
				local PlayerState = Registry.find("PlayerStateService")
				if PlayerState and not PlayerState.isHealthy(player) then
					return
				end
				keyPrompt.Enabled = false
				StopKit.setShown(key, false)
				Net.notify(player, "Toast", { text = "The tag says 6. Something inside Room 6 heard you." })
				if conn then
					conn:Disconnect()
				end
				-- The Guest follows the key: the nearest door to whoever took it starts knocking.
				task.spawn(function()
					for _ = 1, 3 do
						task.wait(6)
						if built.active == false then
							return
						end
						local character = player.Character
						local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
						if not root then
							return
						end
						local nearest: Room? = nil
						local best = math.huge
						for _, room in rooms do
							local d = (room.doorPart.Position - root.Position).Magnitude
							if d < best then
								nearest, best = room, d
							end
						end
						if nearest and best < 30 then
							knock(nearest)
						end
					end
				end)
			end)
		end,
	}

	refs.extras.activate = function(built: any, deadline: number)
		token += 1
		local mine = token
		local rng = ctx.rng:child("guest")
		for _, room in rooms do
			room.knockingUntil = 0
			if room.door then
				room.door.set(false)
			end
		end
		task.spawn(function()
			task.wait(rng:float(8, 14))
			while mine == token and built.active ~= false and workspace:GetServerTimeNow() < deadline do
				-- Room 6 knocks more often than the rest.
				local room = if rng:float(0, 1) < 0.3 then rooms[6] else rooms[rng:int(1, #rooms)]
				knock(room)
				task.wait(rng:float(9, 16) / (if ctx.tier >= 3 then 1.5 elseif ctx.tier == 2 then 1.2 else 1))
			end
		end)
	end
	refs.extras.deactivate = function()
		token += 1
	end
	return refs
end
