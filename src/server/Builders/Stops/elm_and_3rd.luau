--!strict
-- Elm & 3rd, again. The corner where the run began, but wrong: the same shelter, the same
-- brick walk-up and the corner deli, all a little off. The streetlights are the wrong
-- colour, the deli's OPEN sign is backwards, and someone on the street waves like a
-- teammate. The Resident wears a player's name. Real players can ping; it can't.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StopKit = require(script.Parent.Parent:WaitForChild("StopKit"))
local Props = require(script.Parent.Parent:WaitForChild("Props"))
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Build = require(Shared.Util.Build)

local C = Build.Colors

local BRICK = Color3.fromRGB(86, 46, 40)
local TRIM = Color3.fromRGB(190, 180, 160)
local WRONG_SODIUM = Color3.fromRGB(150, 200, 255) -- the streetlights are the wrong colour

local function clockFace(refs: StopKit.StopRefs, parent: Instance, cf: CFrame, text: string): TextLabel
	local _, label = StopKit.sign(refs, {
		name = "ClockFace",
		size = Vector3.new(0.3, 1.8, 3),
		cf = cf,
		color = Color3.fromRGB(20, 20, 22),
		collide = false,
	}, text, Enum.NormalId.Left, Color3.fromRGB(255, 90, 60), parent)
	label.Font = Enum.Font.Code
	return label
end

return function(parent: Instance, frame: CFrame, ctx: StopKit.Ctx, title: string): StopKit.StopRefs
	local refs = StopKit.new(ctx.id, parent, frame)
	StopKit.basics(refs, title, 104, -66, 66)
	for _, lamp in refs.streetlights do
		lamp.Color = WRONG_SODIUM
		for _, l in lamp:GetChildren() do
			if l:IsA("Light") then
				l.Color = WRONG_SODIUM
			end
		end
	end

	-- The shelter's ad panel is the anomaly slot for the MISSING poster.
	local ad = refs.shelter:FindFirstChild("AdPanel")
	if ad then
		StopKit.slot(refs, "shelter_ad", ad)
	end

	-- 3rd Street crosses the lot: asphalt, a zebra crossing and a signal that only blinks.
	StopKit.part(refs, {
		name = "ThirdStreet",
		size = Vector3.new(94, 0.12, 22),
		cf = CFrame.new(57, 0.06, 30),
		color = C.Asphalt,
		material = Enum.Material.Asphalt,
	})
	for i = 0, 5 do
		StopKit.part(refs, {
			name = "Zebra",
			size = Vector3.new(2, 0.03, 18),
			cf = CFrame.new(14 + i * 3.5, 0.14, 30),
			color = C.White,
			collide = false,
		})
	end
	local signalPost = StopKit.part(refs, {
		name = "SignalPost",
		size = Vector3.new(0.5, 12, 0.5),
		cf = CFrame.new(12, 6, 18),
		color = C.DarkMetal,
		material = Enum.Material.Metal,
	})
	local walk = Build.model(refs.model, "WalkSignal")
	local hand = StopKit.part(refs, {
		name = "WalkHand",
		size = Vector3.new(0.4, 1.4, 1.4),
		cf = CFrame.new(11.6, 9.5, 18),
		color = Color3.fromRGB(255, 120, 40),
		material = Enum.Material.Neon,
		collide = false,
	}, walk)
	Build.light(hand, "Point", Color3.fromRGB(255, 120, 40), 0.6, 8, false)
	StopKit.slot(refs, "walk_signal", walk)
	local _ = signalPost

	-- The walk-up: four storeys of brick with windows, the lobby open, mailboxes inside.
	local apt = StopKit.building(refs, "Apartments", Vector3.new(66, 12, -32), Vector3.new(40, 24, 58), BRICK, 7, -32)
	local windows = Build.model(apt, "Windows")
	local lit = ctx.rng:int(1, 8)
	local waveWindow: Part? = nil
	local k = 0
	for floor = 1, 2 do
		for z = -54, -12, 14 do
			k += 1
			local pane = Props.window(refs, CFrame.new(45.4, 6 + floor * 6, z), Vector2.new(4, 4), k == lit, windows)
			if k == 3 then
				waveWindow = pane
			end
		end
	end
	StopKit.sign(refs, {
		name = "Number",
		size = Vector3.new(0.3, 1.4, 5),
		cf = CFrame.new(45.3, 10.4, -32),
		color = TRIM,
		collide = false,
	}, "1958 ELM", Enum.NormalId.Left, C.Black, apt)
	StopKit.ceilingLight(refs, Vector3.new(54, 11, -32), C.Warm, 18, apt)
	local mailboxes = Build.model(apt, "Mailboxes")
	for row = 0, 2 do
		for col = 0, 3 do
			StopKit.part(refs, {
				name = "Mailbox",
				size = Vector3.new(0.6, 1.2, 1.6),
				cf = CFrame.new(84.5, 3 + row * 1.4, -40 + col * 1.8),
				color = Color3.fromRGB(150, 130, 80),
				material = Enum.Material.Metal,
			}, mailboxes)
		end
	end
	local mailHand = Build.model(apt, "MailboxHand")
	StopKit.part(refs, {
		name = "Fingers",
		size = Vector3.new(0.4, 0.5, 1),
		cf = CFrame.new(84, 4.6, -36.4),
		color = Color3.fromRGB(205, 195, 180),
		collide = false,
	}, mailHand)
	StopKit.slot(refs, "mailboxes", mailboxes, { elm_mailbox_hand = mailHand :: Instance })
	StopKit.lootPoint(refs, Vector3.new(83, 1.4, -44))
	StopKit.lootPoint(refs, Vector3.new(76, 1.4, -18))
	StopKit.lootPoint(refs, Vector3.new(60, 1.4, -50))
	StopKit.hidingSpot(refs, CFrame.new(80, 2, -55))
	StopKit.hidingSpot(refs, CFrame.new(56, 2, -10))
	Props.door(refs, CFrame.new(70, 0.4, -10) * CFrame.Angles(0, math.rad(-90), 0), 4, 8, C.Wood, apt, "Apartment 1")

	-- Someone in a window waves like a teammate. Normally the window is just dark.
	if waveWindow then
		local waver = Build.model(apt, "WindowWaver")
		local fig = StopKit.figure(refs, "Waver", CFrame.new(48, 6.4, -40), Color3.fromRGB(60, 80, 120), waver)
		-- Line it up just behind the pane, facing the street.
		fig:PivotTo(waveWindow.CFrame * CFrame.new(1.4, -1, 0) * CFrame.Angles(0, math.rad(90), 0))
		StopKit.slot(refs, "wave_window", waveWindow, { elm_waver = waver :: Instance })
	end

	-- The corner deli across 3rd: closed, the OPEN sign backwards, shelves of the same can.
	local deli = StopKit.building(refs, "Deli", Vector3.new(56, 7, 56), Vector3.new(36, 14, 20), C.Siding, 6, 56)
	local openSign, openLabel = StopKit.sign(refs, {
		name = "OpenSign",
		size = Vector3.new(0.2, 1.6, 4),
		cf = CFrame.new(37.6, 6, 50),
		color = Color3.fromRGB(20, 10, 10),
		material = Enum.Material.Neon,
		collide = false,
	}, "OPEN", Enum.NormalId.Left, Color3.fromRGB(255, 60, 80), deli)
	openLabel.Font = Enum.Font.GothamBlack
	StopKit.slot(refs, "open_sign", openSign)
	StopKit.sign(refs, {
		name = "DeliSign",
		size = Vector3.new(0.4, 2.4, 16),
		cf = CFrame.new(37.6, 12, 56),
		color = Color3.fromRGB(40, 90, 60),
		collide = false,
	}, "ELM & 3RD DELI", Enum.NormalId.Left, C.White, deli)
	StopKit.ceilingLight(refs, Vector3.new(56, 13, 56), C.Fluor, 16, deli)
	for i = 0, 2 do
		Props.shelf(
			refs,
			CFrame.new(50 + i * 7, 0.4, 56) * CFrame.Angles(0, math.rad(90), 0),
			12,
			6,
			deli,
			ctx.stopIndex + i
		)
		StopKit.lootPoint(refs, Vector3.new(48 + i * 7, 3.4, 52))
	end
	Props.counter(refs, CFrame.new(70, 0.4, 60), Vector3.new(3, 3.6, 8), nil, nil, deli)
	StopKit.lootPoint(refs, Vector3.new(70, 4.2, 60))
	StopKit.hidingSpot(refs, CFrame.new(71, 2, 56))

	-- Clocks: one on a post at the corner, one in the deli window. Normally they disagree.
	local clocks = Build.model(refs.model, "Clocks")
	StopKit.part(refs, {
		name = "ClockPost",
		size = Vector3.new(0.6, 10, 0.6),
		cf = CFrame.new(16, 5, 6),
		color = C.DarkMetal,
		material = Enum.Material.Metal,
	}, clocks)
	clockFace(refs, clocks, CFrame.new(15.6, 10.6, 6), "2:14")
	clockFace(refs, clocks, CFrame.new(37.5, 4, 62), "2:13")
	StopKit.slot(refs, "clock", clocks)

	-- The newsstand, the missing poster on the lamp post, and a fire escape on the deli.
	local stand = StopKit.box(
		refs,
		"Newsstand",
		CFrame.new(18, 2.5, -22),
		Vector3.new(3, 4.2, 5),
		Color3.fromRGB(40, 70, 120),
		Enum.Material.Metal
	)
	local _ = stand
	StopKit.lootPoint(refs, Vector3.new(16.2, 4.9, -22))
	StopKit.lore(refs, "elm_poster", CFrame.new(8.4, 5, 24) * CFrame.Angles(0, 0, 0), true)
	Props.parkedCars(refs, 96, -60, -10, 12, ctx.stopIndex * 31 + 9)
	Props.tree(refs, Vector3.new(26, 0.4, -48), 18)
	Props.tree(refs, Vector3.new(26, 0.4, 46), 16)

	-- The bench in the shelter: normally empty. Sometimes your coat is on it.
	local coat = Build.model(refs.model, "BenchCoat")
	StopKit.part(refs, {
		name = "Coat",
		size = Vector3.new(1.4, 0.5, 3),
		cf = CFrame.new(8.2, 2.75, -9),
		color = Color3.fromRGB(70, 50, 40),
		material = Enum.Material.Fabric,
		collide = false,
	}, coat)
	local bench = refs.shelter:FindFirstChild("Bench")
	if bench then
		StopKit.slot(refs, "bench", bench, { elm_coat = coat :: Instance })
	end

	StopKit.fragmentSite(refs, Vector3.new(84, 1.5, -56))
	StopKit.entitySpawn(refs, CFrame.new(90, 3, 40) * CFrame.Angles(0, math.rad(90), 0))
	StopKit.entitySpawn(refs, CFrame.new(64, 3, 10))
	StopKit.trailhead(refs, CFrame.new(108, 0, 66))
	StopKit.backEntrance(refs, CFrame.new(108, 3, -66))
	return refs
end
