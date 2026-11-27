--!strict
-- The Station With No Name. A long, bare platform, a waiting room with its windows shut
-- and a sign with nothing on it. The bus is not supposed to stop here. Stepping off
-- breaks the posted Rule (if it is on the plaque) and costs Patience the first time
-- anyone does it, but the station holds two fragments.
-- The Attendant walks the platform in a pressed uniform, announces something nobody
-- understands and politely beckons riders toward the end of the platform. Past the end
-- is nothing at all: whoever walks into it is Down.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StopKit = require(script.Parent.Parent:WaitForChild("StopKit"))
local Props = require(script.Parent.Parent:WaitForChild("Props"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Build = require(Shared.Util.Build)
local Net = require(Shared.Net)
local Registry = require(script.Parent.Parent.Parent:WaitForChild("Registry"))

local C = Build.Colors

local END_Z = -62 -- past this, the platform simply stops
local CONCRETE = Color3.fromRGB(110, 110, 106)
local UNIFORM = Color3.fromRGB(30, 40, 70)
local OFF_COST = 12 -- Patience lost when someone steps off and the Rule isn't posted

return function(parent: Instance, frame: CFrame, ctx: StopKit.Ctx, title: string): StopKit.StopRefs
	local refs = StopKit.new(ctx.id, parent, frame)
	local _ = title
	StopKit.lot(refs, 80, END_Z + 2, 66, CONCRETE, Enum.Material.Concrete)
	StopKit.sidewalk(refs, END_Z + 2, 60)
	StopKit.shelter(refs, "")
	StopKit.approachLights(refs, 2)
	refs.passengerSpot = StopKit.marker(refs, "PassengerSpot", CFrame.new(6, 3, -2))

	-- The platform edge and its tactile strip, running on into the dark.
	StopKit.part(refs, {
		name = "TactileStrip",
		size = Vector3.new(1.6, 0.05, 66 - END_Z),
		cf = CFrame.new(1.4, 0.52, (66 + END_Z) / 2),
		color = Color3.fromRGB(200, 180, 60),
		collide = false,
	})
	-- Where the platform ends: a lip, then black. No railing, no sign, no light.
	StopKit.part(refs, {
		name = "PlatformLip",
		size = Vector3.new(90, 1.2, 0.6),
		cf = CFrame.new(35, -0.2, END_Z + 1.8),
		color = Color3.fromRGB(80, 80, 76),
		material = Enum.Material.Concrete,
	})
	StopKit.part(refs, {
		name = "TheDark",
		size = Vector3.new(120, 60, 2),
		cf = CFrame.new(40, 10, END_Z - 14),
		color = C.Black,
		material = Enum.Material.SmoothPlastic,
		transparency = 0.05,
		collide = false,
		query = false,
		cast = false,
	})
	StopKit.part(refs, {
		name = "DarkFloor",
		size = Vector3.new(120, 0.2, 16),
		cf = CFrame.new(40, -0.6, END_Z - 6),
		color = C.Black,
		material = Enum.Material.SmoothPlastic,
	})
	-- The zone past the end. Not visible, not marked.
	local pastEnd = StopKit.part(refs, {
		name = "PastTheEnd",
		size = Vector3.new(130, 30, 14),
		cf = CFrame.new(40, 10, END_Z - 7),
		transparency = 1,
		collide = false,
		query = false,
	})

	-- The station sign: a blue board with nothing on it.
	local signPart, signLabel = StopKit.sign(refs, {
		name = "StationSign",
		size = Vector3.new(0.4, 2.4, 14),
		cf = CFrame.new(14, 9, 10),
		color = Color3.fromRGB(30, 60, 110),
		collide = false,
	}, "", Enum.NormalId.Left, C.White)
	signLabel.Font = Enum.Font.GothamBlack
	for _, z in { 4, 16 } do
		StopKit.part(refs, {
			name = "SignPost",
			size = Vector3.new(0.4, 9, 0.4),
			cf = CFrame.new(14.2, 4.5, z),
			color = C.DarkMetal,
			material = Enum.Material.Metal,
		})
	end
	StopKit.slot(refs, "sign", signPart)

	-- Lamps along the platform, fewer and dimmer toward the end. The last one is dark.
	local lastLamp: BasePart? = nil
	for i, z in { 40, 18, -4, -26, -48 } do
		local post = StopKit.part(refs, {
			name = "LampPost",
			size = Vector3.new(0.5, 12, 0.5),
			cf = CFrame.new(22, 6, z),
			color = C.DarkMetal,
			material = Enum.Material.Metal,
		})
		local _p = post
		local bulb = StopKit.part(refs, {
			name = "Lamp",
			size = Vector3.new(1.4, 0.5, 1.4),
			cf = CFrame.new(22, 12, z),
			color = if i < 5 then Color3.fromRGB(240, 230, 200) else Color3.fromRGB(40, 40, 40),
			material = if i < 5 then Enum.Material.Neon else Enum.Material.SmoothPlastic,
			collide = false,
		})
		local light = Build.light(bulb, "Point", Color3.fromRGB(240, 225, 190), 1.2 - i * 0.18, 26, false)
		light.Enabled = i < 5
		if i == 5 then
			lastLamp = bulb
		end
	end
	if lastLamp then
		StopKit.slot(refs, "end_lamp", lastLamp)
	end

	-- The waiting room: blinds down, a ticket window with nobody behind it.
	local room = StopKit.building(refs, "WaitingRoom", Vector3.new(50, 6, 30), Vector3.new(26, 12, 30), C.Siding, 6, 30)
	StopKit.ceilingLight(refs, Vector3.new(50, 11.4, 30), C.Fluor, 18, room)
	for i = 0, 2 do
		local b = StopKit.part(refs, {
			name = "WaitingBench",
			size = Vector3.new(6, 0.4, 1.6),
			cf = CFrame.new(48 + (i % 2) * 6, 2.3, 22 + i * 6),
			color = C.Wood,
			material = Enum.Material.Wood,
		}, room)
		local _b = b
		StopKit.lootPoint(refs, Vector3.new(48 + (i % 2) * 6, 3, 22 + i * 6))
	end
	-- The riders who wait here. Normally there aren't any.
	local riders = Build.model(room, "Riders")
	for i = 0, 2 do
		StopKit.figure(
			refs,
			"Rider",
			CFrame.new(48 + (i % 2) * 6, 0.4, 22.6 + i * 6) * CFrame.Angles(0, math.rad(180), 0),
			Color3.fromRGB(50 + i * 20, 50, 60),
			riders,
			{ height = 0.92 }
		)
	end
	StopKit.slot(refs, "riders", Build.model(room, "NoRiders"), { noname_riders = riders :: Instance })
	Props.counter(refs, CFrame.new(60, 0.4, 30), Vector3.new(3, 3.6, 10), nil, nil, room)
	local ticketWindow, windowLabel = StopKit.sign(refs, {
		name = "TicketWindow",
		size = Vector3.new(0.2, 1.4, 4),
		cf = CFrame.new(58.4, 6.6, 30),
		color = Color3.fromRGB(20, 20, 22),
		collide = false,
	}, "CLOSED", Enum.NormalId.Left, Color3.fromRGB(220, 220, 220), room)
	windowLabel.Font = Enum.Font.Code
	StopKit.slot(refs, "ticket_window", ticketWindow)
	StopKit.lootPoint(refs, Vector3.new(60, 4.4, 27))
	StopKit.lootPoint(refs, Vector3.new(60, 4.4, 34))
	StopKit.hidingSpot(refs, CFrame.new(42, 2, 42))
	StopKit.lore(refs, "no_name_ticket", CFrame.new(62.4, 6, 24), true)

	-- Lost luggage stacked by the far wall, bags with no tags.
	for i = 0, 4 do
		StopKit.box(
			refs,
			"Suitcase",
			CFrame.new(70 + (i % 3) * 2.6, 1.4 + (i // 3) * 2, -30 + (i % 2) * 1.2)
				* CFrame.Angles(0, math.rad(i * 17), 0),
			Vector3.new(2.4, 2, 1),
			Color3.fromRGB(70 + i * 15, 50, 40),
			Enum.Material.Leather
		)
	end
	StopKit.lootPoint(refs, Vector3.new(68, 1.4, -26))
	StopKit.lootPoint(refs, Vector3.new(36, 1.4, -40))
	StopKit.lootPoint(refs, Vector3.new(14, 1.4, -54))
	StopKit.lootPoint(refs, Vector3.new(70, 1.4, 52))

	-- Two fragments: one in the waiting room, one far down the platform, near the end.
	StopKit.fragmentSite(refs, Vector3.new(44, 1.5, 40))
	StopKit.fragmentSite(refs, Vector3.new(30, 1.5, -54))

	-- The departure board in the shelter: one line, one destination, written over twice.
	local depart, departLabel = StopKit.sign(refs, {
		name = "DepartureBoard",
		size = Vector3.new(0.3, 2.4, 6),
		cf = CFrame.new(9, 8.4, 2),
		color = C.Black,
		collide = false,
	}, "NEXT: 9N\nNOT IN SERVICE", Enum.NormalId.Left, Color3.fromRGB(255, 180, 60))
	departLabel.Font = Enum.Font.Code
	StopKit.slot(refs, "board", depart)

	-- The lure: a fresh ticket lying just past the end of the platform.
	refs.extras.custom = {
		noname_lure_ticket = function(built: any)
			local ticket = Build.part(refs.model, {
				name = "FreshTicket",
				size = Vector3.new(0.9, 0.05, 0.5),
				cf = refs.frame * CFrame.new(34, -0.45, END_Z - 2.4) * CFrame.Angles(0, math.rad(20), 0),
				color = Color3.fromRGB(240, 220, 150),
				collide = false,
				group = "World",
			})
			Build.light(ticket, "Point", Color3.fromRGB(255, 240, 200), 0.6, 6, false)
			local prompt = Build.prompt(ticket, "Take", "Ticket", 0, 4, "TicketPrompt")
			prompt.Triggered:Connect(function(player: Player)
				local PlayerState = Registry.find("PlayerStateService")
				if not PlayerState or not PlayerState.isHealthy(player) or built.active == false then
					return
				end
				prompt.Enabled = false
				ticket:Destroy()
				Net.notify(player, "Toast", { text = "It wasn't a ticket. It was a receipt, with your name." })
				PlayerState.down(player, "attendant")
			end)
		end,
	}

	-- The Attendant: polite, slow, always walking you toward the end.
	local attendant = StopKit.figure(
		refs,
		"Attendant",
		CFrame.new(30, 0.4, 20),
		UNIFORM,
		nil,
		{ height = 1.15, skin = Color3.fromRGB(205, 200, 190), pants = UNIFORM }
	)
	local head = attendant:FindFirstChild("Head") :: BasePart?
	if head then
		local face = head:FindFirstChildWhichIsA("Decal")
		if face then
			face:Destroy()
		end
		StopKit.part(refs, {
			name = "Cap",
			size = Vector3.new(1.7, 0.45, 1.8),
			cf = CFrame.new(30, 0.4 + 7.75 * 1.15, 20),
			color = UNIFORM,
			collide = false,
		}, attendant)
		StopKit.part(refs, {
			name = "CapBadge",
			size = Vector3.new(0.5, 0.3, 0.05),
			cf = CFrame.new(30, 0.4 + 7.75 * 1.15, 20 - 0.92),
			color = Color3.fromRGB(220, 190, 80),
			material = Enum.Material.Metal,
			collide = false,
		}, attendant)
	end
	local rightArm: BasePart? = nil
	for _, child in attendant:GetChildren() do
		if child.Name == "Arm" and child:IsA("BasePart") then
			rightArm = child
		end
	end
	local armRest = if rightArm then attendant:GetPivot():ToObjectSpace(rightArm.CFrame) else CFrame.identity
	attendant:SetAttribute("Entity", "attendant")
	local home = attendant:GetPivot()

	local token = 0
	refs.extras.activate = function(built: any)
		token += 1
		local mine = token
		local PlayerState = Registry.find("PlayerStateService")
		local Bus = Registry.find("BusService")
		local Driver = Registry.find("DriverService")
		local Rules = Registry.find("RulesService")
		local Dread = Registry.find("DreadService")
		local charged = false
		local fakeTrap = Rules ~= nil and Rules.has("fake_get_off")
		-- Its walk: from the waiting room down the platform to the end, and back.
		local route = {
			Vector3.new(30, 0.4, 20),
			Vector3.new(26, 0.4, -10),
			Vector3.new(24, 0.4, -40),
			Vector3.new(24, 0.4, END_Z + 4),
		}
		local leg = 1
		local dir = 1
		local nextAnnounce = os.clock() + 4
		local speed = if fakeTrap then 7 else 4
		local pos = refs.frame:PointToObjectSpace(home.Position)
		if fakeTrap then
			-- Following the sticker brings it straight to the doors.
			pos = Vector3.new(10, pos.Y, 0)
		end
		task.spawn(function()
			local last = os.clock()
			while mine == token and built.active ~= false and attendant.Parent do
				local t = os.clock()
				local dt = t - last
				last = t
				-- Riders off the bus, and the one who stepped off first.
				local nearest: BasePart? = nil
				local nearestDist = 16
				for _, player in Players:GetPlayers() do
					local root = PlayerState and PlayerState.rootOf(player)
					if root and PlayerState.isHealthy(player) then
						local local_ = refs.frame:PointToObjectSpace(root.Position)
						local onStop = local_.X > -2 and local_.X < 90 and local_.Z > END_Z - 20 and local_.Z < 70
						if onStop and Bus and not Bus.isAboard(player) then
							if not charged then
								charged = true
								if Rules and Rules.has("no_name_stay") and Driver then
									Driver.ruleBroken(player, "no_name_stay")
								elseif Driver then
									Driver.change(-OFF_COST, "no_name", player)
								end
								Net.notifyAll("Toast", { text = "The Driver's hands tighten on the wheel." })
							end
							local d = (Vector3.new(local_.X, 0, local_.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
							if d < nearestDist then
								nearestDist = d
								nearest = root
							end
						end
						-- Past the end: gone.
						if local_.Z < END_Z - 0.5 and local_.X > -2 and local_.X < 110 then
							Net.notify(player, "Toast", { text = "The platform keeps going. You don't." })
							if Dread then
								Dread.add(player, 15)
							end
							PlayerState.down(player, "attendant")
						end
					end
				end
				-- Walk the route. When someone is close it stops, faces them and beckons,
				-- then carries on toward the end so they'll follow.
				local target = route[leg]
				local flat = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
				local beckon = nearest ~= nil and nearestDist < 9
				if flat.Magnitude < 0.5 then
					if leg == #route then
						dir = -1
					elseif leg == 1 then
						dir = 1
					end
					leg = math.clamp(leg + dir, 1, #route)
				elseif not beckon then
					local step = math.min(flat.Magnitude, speed * dt)
					pos += flat.Unit * step
				end
				local face = if beckon and nearest
					then refs.frame:PointToObjectSpace(nearest.Position)
					else Vector3.new(target.X, pos.Y, target.Z)
				local lookAt = Vector3.new(face.X, pos.Y, face.Z)
				local cf = if (lookAt - pos).Magnitude > 0.1 then CFrame.lookAt(pos, lookAt) else CFrame.new(pos)
				attendant:PivotTo(refs.frame * cf)
				if rightArm then
					local wave = if beckon
						then CFrame.Angles(math.rad(-70 + math.sin(t * 5) * 25), 0, 0)
						else CFrame.identity
					rightArm.CFrame = attendant:GetPivot()
						* armRest
						* CFrame.new(0, 1.2, 0)
						* wave
						* CFrame.new(0, -1.2, 0)
				end
				if t >= nextAnnounce then
					nextAnnounce = t + 12
					Net.notifyAll("Sound", { key = "UnknownAnnouncement", part = attendant.PrimaryPart })
				end
				task.wait(0.1)
			end
		end)
	end
	refs.extras.deactivate = function()
		token += 1
		if attendant.Parent then
			attendant:PivotTo(home)
		end
	end
	local _pe = pastEnd

	StopKit.trailhead(refs, CFrame.new(84, 0, 64))
	StopKit.backEntrance(refs, CFrame.new(84, 3, 40))
	return refs
end
