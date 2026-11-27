--!strict
-- Low Water Station. A sunken commuter platform beside a flooded track bed. The water comes
-- up a little more every minute the doors are open: first puddles, then ankles, then the
-- knees, and wading slows you down. The Drowned live in it. Stand still in the water and
-- bubbles rise at your feet; stay still and hands pull you Down. Keep moving.
-- The ticket office is raised and stays dry. The fragment is on the roof of the sunken
-- train car, out over the water.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local StopKit = require(script.Parent.Parent:WaitForChild("StopKit"))
local Props = require(script.Parent.Parent:WaitForChild("Props"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Build = require(Shared.Util.Build)
local Net = require(Shared.Net)
local Registry = require(script.Parent.Parent.Parent:WaitForChild("Registry"))

local C = Build.Colors

local PLAT_X0, PLAT_X1 = 12, 74
local PLAT_Z0, PLAT_Z1 = -58, 58
local TRACK_X0, TRACK_X1 = 74, 100
local TILE = Color3.fromRGB(150, 155, 150)
local WATER = Color3.fromRGB(28, 52, 58)

-- Water top height (stop frame Y) over the time the doors have been open.
local START_Y = 0.15
local RISE_PER_MINUTE = 1.5
local MAX_Y = 3.4
local STILL_WARN = 2.5 -- seconds standing still in water before bubbles
local STILL_DOWN = 5 -- seconds before the hands take you

return function(parent: Instance, frame: CFrame, ctx: StopKit.Ctx, title: string): StopKit.StopRefs
	local refs = StopKit.new(ctx.id, parent, frame)
	StopKit.lot(refs, 110, -70, 70, Color3.fromRGB(60, 62, 60), Enum.Material.Concrete)
	StopKit.sidewalk(refs, -60, 60)
	StopKit.shelter(refs, title)
	StopKit.approachLights(refs)
	refs.passengerSpot = StopKit.marker(refs, "PassengerSpot", CFrame.new(6, 3, -2))

	-- Stairs down from the street to the platform level, which sits just below the curb.
	StopKit.part(refs, {
		name = "Platform",
		size = Vector3.new(PLAT_X1 - PLAT_X0, 0.4, PLAT_Z1 - PLAT_Z0),
		cf = CFrame.new((PLAT_X0 + PLAT_X1) / 2, 0.2, 0),
		color = TILE,
		material = Enum.Material.Slate,
	})
	-- The yellow edge line and the drop into the track bed.
	StopKit.part(refs, {
		name = "EdgeLine",
		size = Vector3.new(1.2, 0.05, PLAT_Z1 - PLAT_Z0),
		cf = CFrame.new(PLAT_X1 - 1.4, 0.42, 0),
		color = Color3.fromRGB(230, 200, 40),
		collide = false,
	})
	StopKit.part(refs, {
		name = "TrackBed",
		size = Vector3.new(TRACK_X1 - TRACK_X0, 1, 150),
		cf = CFrame.new((TRACK_X0 + TRACK_X1) / 2, -5, 0),
		color = Color3.fromRGB(40, 36, 32),
		material = Enum.Material.Pebble,
	})
	StopKit.part(refs, {
		name = "TrackWall",
		size = Vector3.new(2, 14, 150),
		cf = CFrame.new(TRACK_X1 + 1, 2, 0),
		color = Color3.fromRGB(90, 90, 86),
		material = Enum.Material.Concrete,
	})
	StopKit.part(refs, {
		name = "PlatformFace",
		size = Vector3.new(0.6, 5, PLAT_Z1 - PLAT_Z0),
		cf = CFrame.new(TRACK_X0 - 0.3, -2.3, 0),
		color = Color3.fromRGB(100, 100, 96),
		material = Enum.Material.Concrete,
	})
	for _, rx in { 84, 90 } do
		StopKit.part(refs, {
			name = "Rail",
			size = Vector3.new(0.4, 0.4, 150),
			cf = CFrame.new(rx, -4.3, 0),
			color = Color3.fromRGB(80, 60, 50),
			material = Enum.Material.CorrodedMetal,
		})
	end

	-- Service steps at the far end, so anyone who falls into the track bed can climb out.
	for i = 0, 3 do
		StopKit.part(refs, {
			name = "ServiceStep",
			size = Vector3.new(3, 1.2 * (i + 1), 4),
			cf = CFrame.new(TRACK_X0 + 7.5 - i * 3, -4.5 + 0.6 * (i + 1), 56),
			color = Color3.fromRGB(90, 90, 86),
			material = Enum.Material.Concrete,
		})
	end

	-- The canopy over the platform, with strip lights and the departures board.
	StopKit.part(refs, {
		name = "Canopy",
		size = Vector3.new(PLAT_X1 - PLAT_X0 - 10, 0.6, PLAT_Z1 - PLAT_Z0),
		cf = CFrame.new((PLAT_X0 + PLAT_X1) / 2 + 5, 14, 0),
		color = Color3.fromRGB(50, 56, 58),
		material = Enum.Material.Metal,
	})
	for z = -50, 50, 20 do
		StopKit.part(refs, {
			name = "CanopyPost",
			size = Vector3.new(0.6, 14, 0.6),
			cf = CFrame.new(60, 7, z),
			color = Color3.fromRGB(50, 56, 58),
			material = Enum.Material.Metal,
		})
		StopKit.ceilingLight(refs, Vector3.new(52, 13.5, z + 10), C.Fluor, 22)
	end
	local board, boardLabel = StopKit.sign(refs, {
		name = "Departures",
		size = Vector3.new(0.4, 3, 9),
		cf = CFrame.new(60, 10.5, -8),
		color = C.Black,
		collide = false,
	}, "DEPARTURES\n9N  2:16  PLATFORM 1\n9N  2:16  PLATFORM 1", Enum.NormalId.Left, Color3.fromRGB(255, 180, 60))
	boardLabel.Font = Enum.Font.Code
	StopKit.slot(refs, "departures", board)
	StopKit.sign(refs, {
		name = "StationName",
		size = Vector3.new(0.4, 2, 16),
		cf = CFrame.new(60, 10.5, 24),
		color = Color3.fromRGB(30, 60, 110),
		collide = false,
	}, "LOW WATER", Enum.NormalId.Left, C.White)

	-- Benches along the platform, one of them the wet-bench slot.
	local benchSlot: Part? = nil
	for i, z in { -40, -20, 4, 30 } do
		local b = StopKit.part(refs, {
			name = "Bench",
			size = Vector3.new(1.6, 0.4, 6),
			cf = CFrame.new(64, 2, z),
			color = C.Wood,
			material = Enum.Material.Wood,
		})
		StopKit.part(refs, {
			name = "BenchLegs",
			size = Vector3.new(1.2, 1.6, 5),
			cf = CFrame.new(64, 1, z),
			color = C.DarkMetal,
			material = Enum.Material.Metal,
		})
		StopKit.lootPoint(refs, Vector3.new(64, 2.8, z + 1.5))
		if i == 3 then
			benchSlot = b
		end
	end
	if benchSlot then
		local wet = Build.model(refs.model, "WetBench")
		StopKit.part(refs, {
			name = "Drip",
			size = Vector3.new(1.62, 0.05, 6.02),
			cf = CFrame.new(64, 2.22, 4),
			color = Color3.fromRGB(30, 45, 55),
			material = Enum.Material.Glass,
			transparency = 0.2,
			reflectance = 0.3,
			collide = false,
		}, wet)
		StopKit.part(refs, {
			name = "Puddle",
			size = Vector3.new(4, 0.05, 6),
			cf = CFrame.new(62, 0.43, 4),
			color = Color3.fromRGB(20, 30, 36),
			material = Enum.Material.Glass,
			transparency = 0.15,
			reflectance = 0.3,
			collide = false,
		}, wet)
		StopKit.slot(refs, "bench", benchSlot, { lowwater_bench = wet :: Instance })
	end

	-- Wet footprints that walk off the platform edge into the water.
	local prints = Build.model(refs.model, "Footprints")
	for i = 0, 7 do
		StopKit.part(refs, {
			name = "Print",
			size = Vector3.new(1.2, 0.03, 0.6),
			cf = CFrame.new(46 + i * 3.4, 0.43, -28 + (i % 2) * 1.4),
			color = Color3.fromRGB(26, 34, 38),
			material = Enum.Material.Glass,
			transparency = 0.2,
			collide = false,
		}, prints)
	end
	local printsSlot = StopKit.marker(refs, "PrintsSlot", CFrame.new(60, 1, -28))
	StopKit.slot(refs, "footprints", printsSlot, { lowwater_prints = prints :: Instance })

	-- A hand gripping the platform edge (a Hazard).
	local edgeHand = Build.model(refs.model, "EdgeHand")
	StopKit.part(refs, {
		name = "Fingers",
		size = Vector3.new(1, 0.4, 1.2),
		cf = CFrame.new(TRACK_X0 - 0.4, 0.55, 18),
		color = Color3.fromRGB(150, 170, 165),
		collide = false,
	}, edgeHand)
	local edgeSlot = StopKit.marker(refs, "EdgeSlot", CFrame.new(TRACK_X0 - 1, 1, 18))
	StopKit.slot(refs, "edge", edgeSlot, { lowwater_hand = edgeHand :: Instance })

	-- The tunnel mouth at the far end and its signal (red; an anomaly turns it green).
	StopKit.part(refs, {
		name = "TunnelMouth",
		size = Vector3.new(28, 16, 2),
		cf = CFrame.new(88, 3, -70),
		color = Color3.fromRGB(60, 60, 58),
		material = Enum.Material.Concrete,
	})
	StopKit.part(refs, {
		name = "TunnelDark",
		size = Vector3.new(20, 10, 1),
		cf = CFrame.new(88, 0, -69),
		color = C.Black,
		material = Enum.Material.SmoothPlastic,
		collide = false,
	})
	local signal = Build.model(refs.model, "Signal")
	local lamp = StopKit.part(refs, {
		name = "SignalLamp",
		size = Vector3.new(0.8, 0.8, 0.8),
		cf = CFrame.new(76, 6, -60),
		color = Color3.fromRGB(255, 40, 30),
		material = Enum.Material.Neon,
		shape = Enum.PartType.Ball,
		collide = false,
	}, signal)
	Build.light(lamp, "Point", Color3.fromRGB(255, 40, 30), 1, 12, false)
	local green = Build.model(refs.model, "SignalGreen")
	local gl = StopKit.part(refs, {
		name = "SignalLampGreen",
		size = Vector3.new(0.85, 0.85, 0.85),
		cf = CFrame.new(76, 6, -60),
		color = Color3.fromRGB(60, 255, 90),
		material = Enum.Material.Neon,
		shape = Enum.PartType.Ball,
		collide = false,
	}, green)
	Build.light(gl, "Point", Color3.fromRGB(60, 255, 90), 1.4, 16, false)
	StopKit.slot(refs, "signal", signal, { lowwater_green = green :: Instance })

	-- The ticket office: raised two steps, dry. Shelter from the water, not from the dark.
	local office =
		StopKit.building(refs, "TicketOffice", Vector3.new(30, 7.5, 40), Vector3.new(22, 11, 24), C.Siding, 6, 40)
	local floor = office:FindFirstChild("Floor") :: BasePart?
	if floor then
		floor.CFrame = refs.frame * CFrame.new(30, 3, 40)
		floor.Size = Vector3.new(21.8, 1.2, 23.8)
	end
	for i, h in { 1.2, 2.4 } do
		StopKit.part(refs, {
			name = "OfficeStep",
			size = Vector3.new(2, h, 6),
			cf = CFrame.new(19 - i * 2, 0.4 + h / 2, 40),
			color = Color3.fromRGB(120, 118, 110),
			material = Enum.Material.Concrete,
		})
	end
	Props.counter(refs, CFrame.new(32, 3.6, 40), Vector3.new(3, 3.4, 12), nil, nil, office)
	StopKit.ceilingLight(refs, Vector3.new(30, 12.6, 40), C.Warm, 16, office)
	StopKit.lootPoint(refs, Vector3.new(32, 7.4, 37))
	StopKit.lootPoint(refs, Vector3.new(38, 4.4, 46))
	StopKit.hidingSpot(refs, CFrame.new(36, 5, 34))
	-- The tide table on the office wall.
	StopKit.lore(refs, "low_water_tide", CFrame.new(40.4, 8, 44), true)

	-- The sunken carriage in the track bed. Its roof is the only high ground over water.
	local car = Build.model(refs.model, "Carriage")
	StopKit.part(refs, {
		name = "CarBody",
		size = Vector3.new(10, 9, 44),
		cf = CFrame.new(87, -0.5, 26) * CFrame.Angles(0, 0, math.rad(6)),
		color = Color3.fromRGB(150, 150, 140),
		material = Enum.Material.CorrodedMetal,
	}, car)
	for z = 8, 44, 6 do
		StopKit.part(refs, {
			name = "CarWindow",
			size = Vector3.new(10.1, 2.4, 3.6),
			cf = CFrame.new(87, 1.6, z) * CFrame.Angles(0, 0, math.rad(6)),
			color = Color3.fromRGB(16, 24, 26),
			material = Enum.Material.Glass,
			transparency = 0.3,
			collide = false,
		}, car)
	end
	-- A plank from the platform edge to the roof.
	StopKit.part(refs, {
		name = "Plank",
		size = Vector3.new(12, 0.4, 2.4),
		cf = CFrame.new(77.5, 2.6, 10) * CFrame.Angles(0, 0, math.rad(18)),
		color = C.Wood,
		material = Enum.Material.WoodPlanks,
	})
	StopKit.fragmentSite(refs, Vector3.new(87, 5, 30))
	StopKit.lootPoint(refs, Vector3.new(87.5, 4.8, 40))

	-- Vending and lockers by the stairs, a lost umbrella, trash.
	StopKit.box(
		refs,
		"Vending",
		CFrame.new(16, 3.9, -30),
		Vector3.new(3, 7, 4),
		Color3.fromRGB(30, 70, 150),
		Enum.Material.SmoothPlastic
	)
	StopKit.lootPoint(refs, Vector3.new(18.6, 1.4, -30))
	for n = 0, 3 do
		Props.locker(refs, CFrame.new(16, 0.4, -44 + n * 2.7), Color3.fromRGB(90, 110, 100))
	end
	StopKit.hidingSpot(refs, CFrame.new(19, 2, -40))
	StopKit.lootPoint(refs, Vector3.new(19, 1.4, -48))
	StopKit.lootPoint(refs, Vector3.new(44, 1.4, 52))
	StopKit.lootPoint(refs, Vector3.new(30, 1.4, -54))

	-- The water itself: one sheet over the whole station that rises while the doors are open.
	local water = StopKit.part(refs, {
		name = "FloodWater",
		size = Vector3.new(TRACK_X1 - PLAT_X0, 10, 140),
		cf = CFrame.new((PLAT_X0 + TRACK_X1) / 2, START_Y - 5, 0),
		color = WATER,
		material = Enum.Material.Glass,
		transparency = 0.35,
		reflectance = 0.2,
		collide = false,
		query = false,
	})
	water.CastShadow = false
	water:SetAttribute("Emit", "WaterLap")
	local base = water.CFrame
	local function setLevel(y: number)
		water.CFrame = base * CFrame.new(0, y - START_Y, 0)
	end

	-- The lure: a lit flashlight floating just past the edge. Reaching for it is the mistake.
	local floatPart: BasePart? = nil
	refs.extras.custom = {
		lowwater_lure_float = function(built: any)
			local light = Build.part(refs.model, {
				name = "FloatingLight",
				size = Vector3.new(0.5, 0.5, 1.6),
				cf = refs.frame * CFrame.new(77.2, START_Y + 0.1, -14) * CFrame.Angles(0, math.rad(30), 0),
				color = Color3.fromRGB(200, 40, 40),
				collide = false,
				group = "World",
			})
			Build.light(light, "Spot", Color3.fromRGB(255, 240, 200), 2, 18, false)
			floatPart = light
			local prompt = Build.prompt(light, "Take", "Flashlight", 0, 7, "FloatPrompt")
			prompt.Triggered:Connect(function(player: Player)
				local PlayerState = Registry.find("PlayerStateService")
				if not PlayerState or not PlayerState.isHealthy(player) or built.active == false then
					return
				end
				prompt.Enabled = false
				Net.notifyAll("Sound", { key = "Splash", part = light })
				Net.notify(player, "Toast", { text = "Something takes your wrist instead." })
				PlayerState.down(player, "drowned")
				light:Destroy()
				floatPart = nil
			end)
		end,
	}

	-- The Drowned and the flood run while the doors are open.
	local token = 0
	local still: { [Player]: { at: Vector3, since: number, warned: boolean } } = {}
	refs.extras.activate = function(built: any)
		token += 1
		local mine = token
		local opened = os.clock()
		local PlayerState = Registry.find("PlayerStateService")
		local Dread = Registry.find("DreadService")
		task.spawn(function()
			while mine == token and built.active ~= false and water.Parent do
				local minutes = (os.clock() - opened) / 60
				local level = math.min(MAX_Y, START_Y + minutes * RISE_PER_MINUTE)
				TweenService:Create(water, TweenInfo.new(0.5), {
					CFrame = base * CFrame.new(0, level - START_Y, 0),
				}):Play()
				local surfaceY = (refs.frame * CFrame.new(0, level, 0)).Position.Y
				local fp = floatPart
				if fp and fp.Parent then
					fp.CFrame = refs.frame
						* CFrame.new(77.2, level + 0.1, -14)
						* CFrame.Angles(0, math.rad(30 + math.sin(os.clock()) * 8), 0)
				end
				for _, player in Players:GetPlayers() do
					local root = PlayerState and PlayerState.rootOf(player)
					local inside = false
					if root then
						local p = refs.frame:PointToObjectSpace(root.Position)
						inside = p.X > PLAT_X0 and p.X < TRACK_X1 and p.Z > -70 and p.Z < 70
					end
					local feetY = if root then root.Position.Y - 3 else math.huge
					local depth = surfaceY - feetY
					if root and inside and depth > 0.2 then
						local wade = math.clamp(1 - depth * 0.16, 0.5, 1)
						if player:GetAttribute("Wading") ~= wade then
							player:SetAttribute("Wading", wade)
							PlayerState.applySpeed(player)
						end
						-- Standing still: the Drowned come up.
						local s = still[player]
						if not s or (root.Position - s.at).Magnitude > 1.2 then
							still[player] = { at = root.Position, since = os.clock(), warned = false }
						elseif PlayerState.isHealthy(player) then
							local held = os.clock() - s.since
							if held >= STILL_WARN and not s.warned then
								s.warned = true
								Net.notifyAll("Sound", { key = "Bubbles", at = root.Position })
								Net.notify(player, "Toast", { text = "Bubbles rise at your feet." })
								if Dread then
									Dread.add(player, 8)
								end
							elseif held >= STILL_DOWN then
								still[player] = nil
								Net.notifyAll("Sound", { key = "Splash", at = root.Position })
								for _, side in { -1, 1 } do
									local h = Build.part(refs.model, {
										name = "DrownedHand",
										size = Vector3.new(0.6, 2.4, 0.6),
										cf = CFrame.new(root.Position + Vector3.new(side * 0.9, -2.2, 0.4)),
										color = Color3.fromRGB(120, 150, 145),
										collide = false,
										query = false,
										group = "Entities",
									})
									task.delay(2.5, function()
										h:Destroy()
									end)
								end
								PlayerState.down(player, "drowned")
							end
						end
					else
						still[player] = nil
						if player:GetAttribute("Wading") ~= nil then
							player:SetAttribute("Wading", nil)
							if PlayerState then
								PlayerState.applySpeed(player)
							end
						end
					end
				end
				task.wait(0.5)
			end
		end)
	end
	refs.extras.deactivate = function()
		token += 1
		table.clear(still)
		for _, player in Players:GetPlayers() do
			if player:GetAttribute("Wading") ~= nil then
				player:SetAttribute("Wading", nil)
				local PlayerState = Registry.find("PlayerStateService")
				if PlayerState then
					PlayerState.applySpeed(player)
				end
			end
		end
		setLevel(START_Y)
	end

	StopKit.entitySpawn(refs, CFrame.new(60, 3, 0))
	StopKit.trailhead(refs, CFrame.new(106, 0, 66))
	StopKit.backEntrance(refs, CFrame.new(60, 3, -64))
	return refs
end
