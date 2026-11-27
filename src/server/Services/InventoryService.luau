--!strict
-- Inventories and world items. Each player has a flashlight and ticket in their own slots,
-- transfers and film in a pocket, and four shared slots (a fuel can takes two). The
-- server holds the truth; the Inventory attribute mirrors it for the HUD.
--
-- World items are parts with a "Pick up" ProximityPrompt. The Lure fuel can (water) shows
-- as a normal fuel can everywhere a client can see.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Signal = require(Shared.Util.Signal)
local Build = require(Shared.Util.Build)
local Net = require(Shared.Net)
local Log = require(Shared.Log)

local Registry = require(script.Parent.Parent:WaitForChild("Registry"))

local ItemDefs = Config.Items.Items
local Tuning = Config.Tuning.Items
local NoiseTuning = Config.Tuning.Noise

local InventoryService = {}

InventoryService.PickedUp = Signal.new() -- (player, id, part)
InventoryService.Used = Signal.new() -- (player, id)
InventoryService.Thrown = Signal.new() -- (player, id, landedAt)

type Inv = {
	slots: { string }, -- item id, "" for empty, "+" for the second half of a 2-slot item
	selected: number,
	battery: number,
	light: boolean,
	ticket: boolean,
	transfers: number,
	film: number,
	lastUse: number,
	radio: boolean,
}

local inventories: { [Player]: Inv } = {}
local worldItems: { [BasePart]: string } = {}

local World: any
local PlayerState: any
local Noise: any

local function newInv(): Inv
	return {
		slots = { "", "", "", "" },
		selected = 1,
		battery = 100,
		light = false,
		ticket = true,
		transfers = 0,
		film = 0,
		lastUse = 0,
		radio = false,
	}
end

local function inv(player: Player): Inv
	local i = inventories[player]
	if not i then
		i = newInv()
		inventories[player] = i
	end
	return i
end

-- What clients are shown for an item id (the Lure looks like the real thing).
local function displayId(id: string): string
	if id == "water_can" then
		return "fuel"
	end
	return id
end

InventoryService.displayId = displayId

local function headOf(player: Player): BasePart?
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head
	end
	return nil
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- Held item visual -------------------------------------------------------------------------

local function updateHeld(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local old = character:FindFirstChild("HeldItem")
	if old then
		old:Destroy()
	end
	local i = inv(player)
	local id = i.slots[i.selected]
	if id == "+" then
		id = i.slots[i.selected - 1] or ""
	end
	if id == "" then
		return
	end
	local def = ItemDefs[id]
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	if not def or not hand or not hand:IsA("BasePart") then
		return
	end
	local part = Build.part(character, {
		name = "HeldItem",
		size = def.size,
		cf = hand.CFrame * CFrame.new(0, -0.6, -0.4),
		color = def.color,
		anchored = false,
		collide = false,
		query = false,
		group = "Players",
	})
	part.Massless = true
	local weld = Instance.new("Weld")
	weld.Part0 = hand
	weld.Part1 = part
	weld.C0 = CFrame.new(0, -0.6, -0.4)
	weld.Parent = part
end

local function mirror(player: Player)
	local i = inv(player)
	local shown = {}
	for n, id in i.slots do
		shown[n] = if id == "+" or id == "" then id else displayId(id)
	end
	player:SetAttribute("Inventory", table.concat(shown, ","))
	player:SetAttribute("Slot", i.selected)
	player:SetAttribute("Battery", math.floor(i.battery + 0.5))
	player:SetAttribute("Ticket", i.ticket)
	player:SetAttribute("Transfers", i.transfers)
	player:SetAttribute("Film", i.film)
	player:SetAttribute("Light", i.light)
	player:SetAttribute("Radio", i.radio)
	updateHeld(player)
	if PlayerState then
		PlayerState.applySpeed(player)
	end
end

InventoryService.refresh = mirror

-- Queries -------------------------------------------------------------------------------

function InventoryService.has(player: Player, id: string): boolean
	if id == "ticket" then
		return inv(player).ticket
	end
	for _, s in inv(player).slots do
		if s == id then
			return true
		end
	end
	return false
end

function InventoryService.count(player: Player, id: string): number
	local n = 0
	for _, s in inv(player).slots do
		if s == id then
			n += 1
		end
	end
	return n
end

function InventoryService.carryingHeavy(player: Player): boolean
	return InventoryService.has(player, "fuel") or InventoryService.has(player, "water_can")
end

function InventoryService.transfers(player: Player): number
	return inv(player).transfers
end

function InventoryService.battery(player: Player): number
	return inv(player).battery
end

function InventoryService.selectedId(player: Player): string?
	local i = inv(player)
	local id = i.slots[i.selected]
	if id == "+" then
		id = i.slots[i.selected - 1]
	end
	if id == nil or id == "" then
		return nil
	end
	return id
end

local function freeRun(i: Inv, width: number): number?
	for n = 1, Tuning.Slots - width + 1 do
		local ok = true
		for k = n, n + width - 1 do
			if i.slots[k] ~= "" then
				ok = false
			end
		end
		if ok then
			return n
		end
	end
	return nil
end

function InventoryService.hasRoomFor(player: Player, id: string): boolean
	local def = ItemDefs[id]
	if not def then
		return false
	end
	if id == "ticket" then
		return not inv(player).ticket
	end
	if def.slots == 0 then
		return true
	end
	return freeRun(inv(player), def.slots) ~= nil
end

-- Changes -------------------------------------------------------------------------------

function InventoryService.give(player: Player, id: string, amount: number?): boolean
	local def = ItemDefs[id]
	if not def then
		return false
	end
	local i = inv(player)
	if id == "transfers" then
		i.transfers += amount or 1
	elseif id == "ticket" then
		if i.ticket then
			return false
		end
		i.ticket = true
	elseif id == "film" then
		i.film += Tuning.PolaroidFilm
	elseif id == "flashlight" then
		i.battery = Tuning.BatteryRefill
	else
		local at = freeRun(i, def.slots)
		if not at then
			return false
		end
		i.slots[at] = id
		for k = at + 1, at + def.slots - 1 do
			i.slots[k] = "+"
		end
		i.selected = at
		if id == "polaroid" and i.film <= 0 then
			i.film = Tuning.PolaroidFilm
		end
	end
	mirror(player)
	return true
end

local function clearAt(i: Inv, at: number)
	i.slots[at] = ""
	local k = at + 1
	while i.slots[k] == "+" do
		i.slots[k] = ""
		k += 1
	end
end

function InventoryService.take(player: Player, id: string): boolean
	local i = inv(player)
	if id == "ticket" then
		if not i.ticket then
			return false
		end
		i.ticket = false
		mirror(player)
		return true
	end
	for n, s in i.slots do
		if s == id then
			clearAt(i, n)
			mirror(player)
			return true
		end
	end
	return false
end

function InventoryService.spendTransfers(player: Player, amount: number): boolean
	local i = inv(player)
	if i.transfers < amount then
		return false
	end
	i.transfers -= amount
	mirror(player)
	return true
end

function InventoryService.refillBattery(player: Player)
	inv(player).battery = Tuning.BatteryRefill
	mirror(player)
end

function InventoryService.addFilm(player: Player, n: number)
	inv(player).film += n
	mirror(player)
end

function InventoryService.useFilm(player: Player): boolean
	local i = inv(player)
	if i.film <= 0 then
		return false
	end
	i.film -= 1
	mirror(player)
	return true
end

function InventoryService.startKit(player: Player)
	local i = newInv()
	i.transfers = Config.Tuning.Run.StartTransfers
	inventories[player] = i
	mirror(player)
end

function InventoryService.clear(player: Player)
	inventories[player] = newInv()
	inventories[player].ticket = false
	mirror(player)
end

-- World items -----------------------------------------------------------------------------

-- Spawn a world item. `id` may be "water_can" (shown as a fuel can).
function InventoryService.spawnItem(id: string, cf: CFrame, parent: Instance?, amount: number?): BasePart?
	local def = ItemDefs[id]
	if not def then
		Log.warn("Items", "Unknown item", id)
		return nil
	end
	local shown = ItemDefs[displayId(id)]
	local part = Build.part(parent or World.Folders.Items, {
		name = shown.name,
		size = shown.size,
		cf = cf * CFrame.new(0, shown.size.Y / 2, 0),
		color = shown.color,
		material = Enum.Material.SmoothPlastic,
		collide = false,
		group = "Items",
		attrs = { Item = displayId(id), Amount = amount },
	})
	if displayId(id) == "fragment" then
		part.Material = Enum.Material.Neon
		part.Color = Color3.fromRGB(255, 240, 200)
		Build.light(part, "Point", Color3.fromRGB(255, 230, 170), 0.8, 8)
	elseif id == "battery" then
		Build.part(part, {
			name = "Cap",
			size = Vector3.new(0.3, 0.1, 0.3),
			cf = part.CFrame * CFrame.new(0, shown.size.Y / 2 + 0.05, 0),
			color = Color3.fromRGB(200, 200, 200),
			collide = false,
		})
	elseif id == "transfers" then
		part.Material = Enum.Material.Neon
		part.Transparency = 0.2
	end
	worldItems[part] = id
	local label = if id == "transfers" and (amount or 1) > 1 then `{amount} transfers` else shown.name
	local prompt = Build.prompt(part, "Pick up", label, 0, Tuning.PickupRange, "PickUp")
	prompt.Triggered:Connect(function(player: Player)
		InventoryService.pickUp(player, part)
	end)
	part.Destroying:Connect(function()
		worldItems[part] = nil
	end)
	return part
end

function InventoryService.itemAt(part: BasePart): string?
	return worldItems[part]
end

function InventoryService.pickUp(player: Player, part: BasePart): boolean
	local id = worldItems[part]
	if not id or not part.Parent then
		return false
	end
	if PlayerState and not PlayerState.isHealthy(player) then
		return false
	end
	local root = rootOf(player)
	if not root or (root.Position - part.Position).Magnitude > Tuning.PickupRange + 3 then
		return false
	end
	if not InventoryService.hasRoomFor(player, id) then
		Net.notify(player, "Toast", { text = if id == "ticket" then "You already have a ticket." else "No room." })
		return false
	end
	local amount = part:GetAttribute("Amount")
	if InventoryService.give(player, id, if typeof(amount) == "number" then amount else nil) then
		worldItems[part] = nil
		part:Destroy()
		InventoryService.PickedUp:Fire(player, id, part)
		return true
	end
	return false
end

local function dropAt(player: Player, id: string): BasePart?
	local root = rootOf(player)
	if not root then
		return nil
	end
	local cf = root.CFrame * CFrame.new(0, -2.8, -2)
	local part = InventoryService.spawnItem(id, CFrame.new(cf.Position), World.Folders.Items)
	if Noise and part then
		Noise.post(part.Position, NoiseTuning.DropRadius, "drop", player)
	end
	return part
end

function InventoryService.dropSlot(player: Player, slot: number): boolean
	local i = inv(player)
	local at = slot
	if i.slots[at] == "+" then
		at -= 1
	end
	local id = i.slots[at]
	if not id or id == "" then
		return false
	end
	clearAt(i, at)
	mirror(player)
	dropAt(player, id)
	return true
end

function InventoryService.dropHeavy(player: Player)
	local i = inv(player)
	for n, id in i.slots do
		if id == "fuel" or id == "water_can" then
			InventoryService.dropSlot(player, n)
		end
	end
end

function InventoryService.dropAll(player: Player)
	local i = inv(player)
	for n, id in i.slots do
		if id ~= "" and id ~= "+" then
			InventoryService.dropSlot(player, n)
		end
	end
	i.light = false
	mirror(player)
end

-- Using items -----------------------------------------------------------------------------

local function setLight(player: Player, on: boolean)
	local i = inv(player)
	local head = headOf(player)
	if not head then
		return
	end
	local light = head:FindFirstChild("Flashlight") :: SpotLight?
	if not light then
		local spot = Instance.new("SpotLight")
		spot.Name = "Flashlight"
		spot.Face = Enum.NormalId.Front
		spot.Range = Tuning.FlashlightRange
		spot.Angle = Tuning.FlashlightAngle
		spot.Brightness = Tuning.FlashlightBrightness
		spot.Color = Color3.fromRGB(255, 244, 220)
		spot.Shadows = true
		spot.Parent = head
		light = spot
	end
	i.light = on;
	(light :: SpotLight).Enabled = on and i.battery > 0
	mirror(player)
end

InventoryService.setLight = setLight

local function useMedkit(player: Player): boolean
	if not PlayerState then
		return false
	end
	local root = rootOf(player)
	if not root then
		return false
	end
	local target: Player? = nil
	for _, other in Players:GetPlayers() do
		local r = rootOf(other)
		if other ~= player and r and PlayerState.state(other) == "Downed" then
			if (r.Position - root.Position).Magnitude <= 7 then
				target = other
				break
			end
		end
	end
	if not target then
		Net.notify(player, "Toast", { text = "Get next to a Downed teammate." })
		return false
	end
	local seconds = Config.Tuning.Player.MedkitSeconds
	Net.notifyList({ player, target }, "Progress", { text = "Using medkit", seconds = seconds })
	task.delay(seconds, function()
		local r1, r2 = rootOf(player), rootOf(target)
		if
			r1
			and r2
			and PlayerState.isHealthy(player)
			and PlayerState.state(target) == "Downed"
			and (r1.Position - r2.Position).Magnitude <= 9
			and InventoryService.take(player, "medkit")
		then
			PlayerState.revive(target)
		end
	end)
	return true
end

local function onUse(player: Player, slot: any)
	if not Net.isInt(slot, 1, Tuning.Slots) then
		return
	end
	local i = inv(player)
	if os.clock() - i.lastUse < Tuning.UseCooldown then
		return
	end
	if PlayerState and not PlayerState.isHealthy(player) then
		return
	end
	i.selected = slot
	local id = InventoryService.selectedId(player)
	if not id then
		return
	end
	i.lastUse = os.clock()
	local def = ItemDefs[id]
	if def.use == "battery" then
		if i.battery >= 99 then
			Net.notify(player, "Toast", { text = "The flashlight is already full." })
			return
		end
		InventoryService.take(player, id)
		i.battery = Tuning.BatteryRefill
		if i.light then
			setLight(player, true)
		end
	elseif def.use == "food" then
		local dread = Registry.find("DreadService")
		InventoryService.take(player, id)
		if dread then
			dread.add(player, Config.Tuning.Dread.Food)
		end
	elseif def.use == "medkit" then
		useMedkit(player)
	elseif def.use == "photo" then
		local photo = Registry.find("PhotoService")
		if photo then
			photo.prompt(player)
		end
	elseif def.use == "radio" then
		i.radio = not i.radio
	elseif def.throwable then
		-- Using a throwable throws it forward.
		local head = headOf(player)
		if head then
			InventoryService.throw(player, slot, head.CFrame.LookVector)
		end
		return
	end
	InventoryService.Used:Fire(player, id)
	mirror(player)
end

-- Throwing ---------------------------------------------------------------------------------

local function land(player: Player, id: string, part: BasePart)
	local at = part.Position
	if id == "bottle" then
		if Noise then
			Noise.post(at, NoiseTuning.BottleRadius, "bottle", player)
		end
		Net.notifyAll("Sound", { key = "BottleBreak", at = at })
		part:Destroy()
	elseif id == "book" then
		if Noise then
			Noise.post(at, NoiseTuning.BookRadius, "book", player)
		end
		part:Destroy()
		InventoryService.spawnItem("book", CFrame.new(at - Vector3.new(0, 0.5, 0)))
	elseif id == "flare" then
		part.Anchored = true
		part.Material = Enum.Material.Neon
		part.Color = Color3.fromRGB(255, 70, 50)
		Build.light(part, "Point", Color3.fromRGB(255, 80, 60), 3, Tuning.FlareLightRange, true)
		local entities = Registry.find("EntityService")
		if entities then
			entities.stunNear(at, Tuning.FlareStunRadius, Tuning.FlareStunSeconds)
		end
		local latecomer = Registry.find("LatecomerService")
		if latecomer then
			latecomer.flare(at)
		end
		Debris:AddItem(part, Tuning.FlareSeconds)
	else
		part:Destroy()
		InventoryService.spawnItem(id, CFrame.new(at))
	end
	InventoryService.Thrown:Fire(player, id, at)
end

function InventoryService.throw(player: Player, slot: number, dir: Vector3)
	local i = inv(player)
	local id = i.slots[slot]
	if not id or id == "" or id == "+" then
		return
	end
	local def = ItemDefs[id]
	if not def.throwable then
		return
	end
	local head = headOf(player)
	if not head then
		return
	end
	-- Rough check that the direction matches where the head can face.
	if dir.Y > 0.98 or dir.Y < -0.98 then
		return
	end
	clearAt(i, slot)
	mirror(player)
	local start = head.Position + dir * 2
	local part = Build.part(World.Folders.Effects, {
		name = "Thrown_" .. id,
		size = def.size,
		cf = CFrame.lookAt(start, start + dir),
		color = def.color,
		anchored = false,
		collide = true,
		touch = true,
		group = "Items",
	})
	part.AssemblyLinearVelocity = dir * Tuning.ThrowSpeed + Vector3.new(0, 8, 0)
	pcall(function()
		part:SetNetworkOwner(nil)
	end)
	local landed = false
	local character = player.Character
	part.Touched:Connect(function(hit: BasePart)
		if landed or (character and hit:IsDescendantOf(character)) then
			return
		end
		landed = true
		task.defer(land, player, id, part)
	end)
	task.delay(3, function()
		if not landed and part.Parent then
			landed = true
			land(player, id, part)
		end
	end)
end

-- Remotes ---------------------------------------------------------------------------------

local function onSelect(player: Player, slot: any)
	if not Net.isInt(slot, 1, Tuning.Slots) then
		return
	end
	local i = inv(player)
	i.selected = slot
	mirror(player)
end

local function onThrow(player: Player, slot: any, dir: any)
	if not Net.isInt(slot, 1, Tuning.Slots) or not Net.isUnit(dir) then
		return
	end
	if PlayerState and not PlayerState.isHealthy(player) then
		return
	end
	InventoryService.throw(player, slot, dir)
end

local function onDrop(player: Player, slot: any)
	if not Net.isInt(slot, 1, Tuning.Slots) then
		return
	end
	if PlayerState and PlayerState.state(player) == "Static" then
		return
	end
	InventoryService.dropSlot(player, slot)
end

local function onFlashlight(player: Player, on: any)
	if typeof(on) ~= "boolean" then
		return
	end
	if PlayerState and PlayerState.state(player) == "Static" then
		on = false
	end
	setLight(player, on)
end

local function drainTick(dt: number)
	for player, i in inventories do
		if not player.Parent then
			inventories[player] = nil
			continue
		end
		local head = headOf(player)
		local light = head and head:FindFirstChild("Flashlight") :: SpotLight?
		if i.light then
			local mult = if player:GetAttribute("NightEyes") then Tuning.NightEyesDrainMultiplier else 1
			i.battery = math.max(0, i.battery - Tuning.FlashlightDrainPerSecond * mult * dt)
		end
		local dreadFlicker = player:GetAttribute("DreadFlicker") == true
		local flicker = i.light and (i.battery <= 0 or dreadFlicker)
		player:SetAttribute("Flicker", flicker)
		if light then
			if flicker then
				light.Enabled = math.random() < (if i.battery <= 0 then 0.25 else 0.6)
			else
				light.Enabled = i.light
			end
		end
		local shown = math.floor(i.battery + 0.5)
		if player:GetAttribute("Battery") ~= shown then
			player:SetAttribute("Battery", shown)
		end
	end
end

function InventoryService:Init()
	World = Registry.get("WorldService")
	PlayerState = Registry.find("PlayerStateService")
	Noise = Registry.find("NoiseService")
end

function InventoryService:Start()
	local function onPlayer(player: Player)
		inventories[player] = newInv()
		mirror(player)
		player.CharacterAdded:Connect(function()
			task.wait(0.1)
			local i = inv(player)
			setLight(player, i.light)
			updateHeld(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		inventories[player] = nil
	end)
	Net.on("SelectSlot", onSelect)
	Net.on("UseItem", onUse)
	Net.on("ThrowItem", onThrow)
	Net.on("DropItem", onDrop)
	Net.on("Flashlight", onFlashlight)
	task.spawn(function()
		while true do
			drainTick(task.wait(0.2))
		end
	end)
end

return InventoryService
