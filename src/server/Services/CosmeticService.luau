--!strict
-- What equipped cosmetics look like in the world. DataService mirrors each slot onto a
-- "Wear_<slot>" Player attribute; this builds from those.
--   jacket   a jacket shell over the torso and upper arms, worn over the player's avatar
--   hat      a cap on the head
--   charm    a small charm hanging from the back of whatever bus seat you sit in
--   flashlight  the beam's tint (warm or cool white only)
-- Liveries are read by RunDirector when it spawns the bus; ticket designs and emotes are
-- client side.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local CosmeticService = {}

local byId: { [string]: any } = {}
for _, def in Config.Meta.Cosmetics do
	byId[def.id] = def
end

local DEFAULT_BEAM = Color3.fromRGB(255, 244, 220)

local function worn(player: Player, slot: string): any?
	local id = player:GetAttribute("Wear_" .. slot)
	return if type(id) == "string" then byId[id] else nil
end

function CosmeticService.def(id: string): any?
	return byId[id]
end

function CosmeticService.beamColor(player: Player): Color3
	local def = worn(player, "flashlight")
	return if def and def.color then def.color else DEFAULT_BEAM
end

-- The livery colour for a run: the first rider (the party leader) who has one equipped.
function CosmeticService.liveryFor(players: { Player }): Color3?
	for _, player in players do
		local def = worn(player, "livery")
		if def and def.color then
			return def.color
		end
	end
	return nil
end

local function shell(
	folder: Instance,
	name: string,
	part: BasePart,
	scale: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = part.Size * scale
	p.CFrame = part.CFrame * offset
	p.Color = color
	p.Material = material or Enum.Material.Fabric
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = true
	p.Anchored = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part
	weld.Part1 = p
	weld.Parent = p
	p.Parent = folder
	return p
end

local function clothes(character: Model, folderName: string): Folder
	local old = character:FindFirstChild(folderName)
	if old then
		old:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = folderName
	f.Parent = character
	return f
end

local function dressJacket(player: Player, character: Model)
	local folder = clothes(character, "CosmeticJacket")
	local def = worn(player, "jacket")
	if not def then
		return
	end
	local color: Color3 = def.color or Color3.fromRGB(70, 70, 75)
	local torso = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
	if not torso then
		return
	end
	shell(folder, "Jacket", torso, Vector3.new(1.08, 1.03, 1.18), CFrame.identity, color)
	shell(
		folder,
		"Collar",
		torso,
		Vector3.new(0.7, 0.14, 1.24),
		CFrame.new(0, torso.Size.Y * 0.47, 0),
		color:Lerp(Color3.new(0, 0, 0), 0.3)
	)
	for _, name in { "LeftUpperArm", "RightUpperArm", "Left Arm", "Right Arm" } do
		local arm = character:FindFirstChild(name) :: BasePart?
		if arm then
			local r6 = name:find(" ") ~= nil
			shell(
				folder,
				"Sleeve",
				arm,
				Vector3.new(1.12, if r6 then 0.6 else 1.04, 1.12),
				CFrame.new(0, if r6 then arm.Size.Y * 0.2 else 0, 0),
				color
			)
		end
	end
	-- The HCTA patch, and a badge on the driver's uniform.
	local patchColor = if def.id == "uniform_driver" then Color3.fromRGB(220, 190, 90) else Color3.fromRGB(255, 190, 80)
	local patch = shell(
		folder,
		"Patch",
		torso,
		Vector3.new(0.18, 0.18, 0.04),
		CFrame.new(-torso.Size.X * 0.24, torso.Size.Y * 0.22, -torso.Size.Z * 0.6),
		patchColor,
		Enum.Material.SmoothPlastic
	)
	patch.CastShadow = false
end

local function dressHat(player: Player, character: Model)
	local folder = clothes(character, "CosmeticHat")
	local def = worn(player, "hat")
	local head = character:FindFirstChild("Head") :: BasePart?
	-- Show any avatar hats a cap hid earlier.
	for _, acc in character:GetChildren() do
		local handle = if acc:IsA("Accessory") then acc:FindFirstChild("Handle") :: BasePart? else nil
		if handle and handle:GetAttribute("CapHidden") then
			handle:SetAttribute("CapHidden", nil)
			handle.Transparency = 0
		end
	end
	if not def or not head then
		return
	end
	local color: Color3 = def.color or Color3.fromRGB(25, 25, 30)
	local h = head.Size.Y
	if def.id == "weekly_badge_pin" then
		-- A small enamel pin rather than a hat.
		local torso = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: BasePart?
		if torso then
			shell(
				folder,
				"Pin",
				torso,
				Vector3.new(0.12, 0.12, 0.05),
				CFrame.new(torso.Size.X * 0.25, torso.Size.Y * 0.25, -torso.Size.Z * 0.62),
				color,
				Enum.Material.Metal
			)
		end
		return
	end
	-- Hide the avatar's own hats so the cap doesn't clip through them.
	for _, acc in character:GetChildren() do
		if acc:IsA("Accessory") and acc.AccessoryType == Enum.AccessoryType.Hat then
			local handle = acc:FindFirstChild("Handle") :: BasePart?
			if handle and handle.Transparency < 1 then
				handle:SetAttribute("CapHidden", true)
				handle.Transparency = 1
			end
		end
	end
	local crown = shell(
		folder,
		"Crown",
		head,
		Vector3.new(1.08, 0.5, 1.08),
		CFrame.new(0, h * 0.42, 0.02),
		color,
		Enum.Material.Fabric
	)
	crown.Size = Vector3.new(h * 1.25, h * 0.45, h * 1.25)
	local brim = shell(
		folder,
		"Brim",
		head,
		Vector3.new(1, 0.08, 0.6),
		CFrame.new(0, h * 0.24, -h * 0.62),
		color:Lerp(Color3.new(0, 0, 0), 0.25),
		Enum.Material.Fabric
	)
	brim.Size = Vector3.new(h * 1.1, h * 0.08, h * 0.6)
	if def.id == "hat_night_owl" then
		local badge = shell(
			folder,
			"Owl",
			head,
			Vector3.new(0.2, 0.2, 0.05),
			CFrame.new(0, h * 0.48, -h * 0.64),
			Color3.fromRGB(255, 190, 80),
			Enum.Material.Neon
		)
		badge.Size = Vector3.new(h * 0.24, h * 0.18, 0.05)
	end
end

local function applyBeam(player: Player, character: Model)
	local head = character:FindFirstChild("Head")
	local light = head and head:FindFirstChild("Flashlight")
	if light and light:IsA("SpotLight") then
		light.Color = CosmeticService.beamColor(player)
	end
end

-- Seat charm --------------------------------------------------------------------------

local charms: { [Player]: Model } = {}

local function clearCharm(player: Player)
	local m = charms[player]
	if m then
		m:Destroy()
		charms[player] = nil
	end
end

local function hangCharm(player: Player, seat: BasePart)
	clearCharm(player)
	local def = worn(player, "charm")
	if not def then
		return
	end
	local bus = workspace:FindFirstChild("Bus")
	if not bus or not seat:IsDescendantOf(bus) then
		return
	end
	local m = Instance.new("Model")
	m.Name = "SeatCharm"
	local top = seat.CFrame * CFrame.new(0.5, 2.5, 1.05)
	local function piece(name: string, size: Vector3, cf: CFrame, color: Color3, shape: Enum.PartType?, neon: boolean?)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Shape = shape or Enum.PartType.Block
		p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CastShadow = false
		local w = Instance.new("WeldConstraint")
		w.Part0 = seat
		w.Part1 = p
		w.Parent = p
		p.Parent = m
		return p
	end
	local color: Color3 = def.color or Color3.fromRGB(170, 130, 80)
	piece("String", Vector3.new(0.05, 0.6, 0.05), top * CFrame.new(0, -0.3, 0), Color3.fromRGB(40, 30, 20))
	piece("Body", Vector3.new(0.34, 0.34, 0.34), top * CFrame.new(0, -0.75, 0), color, Enum.PartType.Ball)
	piece(
		"EyeL",
		Vector3.new(0.08, 0.08, 0.08),
		top * CFrame.new(-0.07, -0.68, 0.16),
		Color3.fromRGB(255, 220, 140),
		Enum.PartType.Ball,
		true
	)
	piece(
		"EyeR",
		Vector3.new(0.08, 0.08, 0.08),
		top * CFrame.new(0.07, -0.68, 0.16),
		Color3.fromRGB(255, 220, 140),
		Enum.PartType.Ball,
		true
	)
	m.Parent = bus
	charms[player] = m
end

-- Wiring ------------------------------------------------------------------------------

local function watchCharacter(player: Player, character: Model)
	task.defer(function()
		if not character.Parent then
			return
		end
		dressJacket(player, character)
		dressHat(player, character)
		applyBeam(player, character)
	end)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if humanoid then
		humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
			local seat = humanoid.SeatPart
			if seat then
				hangCharm(player, seat)
			else
				clearCharm(player)
			end
		end)
	end
end

local function watch(player: Player)
	player.CharacterAdded:Connect(function(character: Model)
		watchCharacter(player, character)
	end)
	if player.Character then
		task.spawn(watchCharacter, player, player.Character)
	end
	player.AttributeChanged:Connect(function(name: string)
		local character = player.Character
		if not character then
			return
		end
		if name == "Wear_jacket" then
			dressJacket(player, character)
		elseif name == "Wear_hat" then
			dressHat(player, character)
		elseif name == "Wear_flashlight" then
			applyBeam(player, character)
		elseif name == "Wear_charm" then
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.SeatPart then
				hangCharm(player, humanoid.SeatPart)
			else
				clearCharm(player)
			end
		end
	end)
end

function CosmeticService:Init() end

function CosmeticService:Start()
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(clearCharm)
end

return CosmeticService
