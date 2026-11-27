--!strict
-- Each player's state: Aboard, Outside, Downed, LeftBehind, Static (Lost), or Lobby.
-- Owns health, the Downed rules (crawl, bleed-out, carrying, the Recovery bay), movement
-- speeds and stamina, and turning Lost players into Static spectators. Nothing kills a
-- player outright: damage and threats go through down().

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Signal = require(Shared.Util.Signal)
local Build = require(Shared.Util.Build)
local Net = require(Shared.Net)
local Perks = require(Shared.Perks)
local Log = require(Shared.Log)

local Registry = require(script.Parent.Parent:WaitForChild("Registry"))

local PlayerTuning = Config.Tuning.Player
local MoveTuning = Config.Tuning.Movement

local PlayerStateService = {}

PlayerStateService.inRun = false
PlayerStateService.Downed = Signal.new() -- (player, cause)
PlayerStateService.Lost = Signal.new() -- (player, reason)
PlayerStateService.Revived = Signal.new() -- (player)
PlayerStateService.StateChanged = Signal.new() -- (player, state)

-- The holding spot for Static players' bodies: anchored, far above the map.
PlayerStateService.StaticRoom = CFrame.new(0, 3000, 0)

local Bus: any
local World: any
local Inventory: any

type Info = {
	stamina: number,
	sprinting: boolean,
	crouching: boolean,
	bleedLeft: number,
	carrying: Player?,
	carriedBy: Player?,
	carryWeld: Weld?,
	inBay: boolean,
	bayWeld: Weld?,
	recoverLeft: number,
	fallStartY: number?,
	lastOffence: number,
}

local info: { [Player]: Info } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function get(player: Player): Info
	local i = info[player]
	if not i then
		i = {
			stamina = MoveTuning.StaminaSeconds,
			sprinting = false,
			crouching = false,
			bleedLeft = PlayerTuning.BleedOutSeconds,
			carrying = nil,
			carriedBy = nil,
			carryWeld = nil,
			inBay = false,
			bayWeld = nil,
			recoverLeft = Config.Tuning.Bus.RecoveryBaySeconds,
			fallStartY = nil,
			lastOffence = 0,
		}
		info[player] = i
	end
	return i
end

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

PlayerStateService.rootOf = rootOf
PlayerStateService.humanoidOf = humanoidOf

function PlayerStateService.state(player: Player): string
	return (player:GetAttribute("State") :: string?) or "Lobby"
end

-- Healthy means Aboard or Outside: able to act normally.
function PlayerStateService.isHealthy(player: Player): boolean
	local s = PlayerStateService.state(player)
	return s == "Aboard" or s == "Outside"
end

function PlayerStateService.isActive(player: Player): boolean
	local s = PlayerStateService.state(player)
	return s == "Aboard" or s == "Outside" or s == "Downed" or s == "LeftBehind"
end

local function setState(player: Player, state: string)
	if player:GetAttribute("State") == state then
		return
	end
	player:SetAttribute("State", state)
	PlayerStateService.StateChanged:Fire(player, state)
end

PlayerStateService.setState = setState

-- Movement ------------------------------------------------------------------------------

function PlayerStateService.applySpeed(player: Player)
	local humanoid = humanoidOf(player)
	if not humanoid then
		return
	end
	local i = get(player)
	local s = PlayerStateService.state(player)
	local speed = MoveTuning.Walk
	local stance = "Walk"
	if s == "Downed" then
		speed = MoveTuning.Downed
		stance = "Crouch"
	elseif s == "Static" or s == "Lobby" then
		speed = 16
	else
		local heavy = Inventory and Inventory.carryingHeavy(player)
		if i.carrying then
			speed = MoveTuning.Carrying
		elseif i.crouching then
			speed = MoveTuning.Crouch
			stance = "Crouch"
		elseif i.sprinting and i.stamina > 0 and not heavy then
			speed = MoveTuning.Sprint
			stance = "Sprint"
		elseif heavy and i.sprinting and i.stamina > 0 and Perks.has(player, "pack_mule") then
			-- Pack Mule: sprint at 70% speed while carrying fuel.
			speed = math.max(MoveTuning.FuelCarry, MoveTuning.Sprint * MoveTuning.PackMuleSprintShare)
			stance = "Sprint"
		elseif heavy then
			speed = MoveTuning.FuelCarry
		end
	end
	-- Wading (Low Water Station's flood) slows everything but Static and the lobby.
	local wading = player:GetAttribute("Wading")
	if type(wading) == "number" and s ~= "Static" and s ~= "Lobby" then
		speed *= math.clamp(wading, 0.3, 1)
	end
	humanoid.WalkSpeed = speed
	humanoid.JumpPower = if s == "Downed" or i.carrying then 0 else MoveTuning.JumpPower
	player:SetAttribute("Stance", stance)
end

local function onMove(player: Player, action: any)
	if typeof(action) ~= "string" then
		return
	end
	local i = get(player)
	if action == "sprint" then
		i.sprinting = true
		i.crouching = false
	elseif action == "walk" then
		i.sprinting = false
		i.crouching = false
	elseif action == "crouch" then
		i.crouching = true
		i.sprinting = false
	elseif action == "putdown" then
		PlayerStateService.stopCarrying(player)
	else
		return
	end
	PlayerStateService.applySpeed(player)
end

-- Carrying ------------------------------------------------------------------------------

function PlayerStateService.stopCarrying(carrier: Player)
	local i = get(carrier)
	local carried = i.carrying
	if not carried then
		return
	end
	local ci = get(carried)
	if i.carryWeld then
		i.carryWeld:Destroy()
	end
	i.carryWeld = nil
	i.carrying = nil
	ci.carriedBy = nil
	carrier:SetAttribute("Carrying", nil)
	carried:SetAttribute("CarriedBy", nil)
	local humanoid = humanoidOf(carried)
	local root = rootOf(carried)
	local carrierRoot = rootOf(carrier)
	if humanoid then
		humanoid.PlatformStand = false
	end
	if root and carrierRoot then
		root.CFrame = carrierRoot.CFrame * CFrame.new(0, 0, -2.5)
	end
	PlayerStateService.applySpeed(carrier)
end

function PlayerStateService.startCarrying(carrier: Player, carried: Player): boolean
	if not PlayerStateService.isHealthy(carrier) or PlayerStateService.state(carried) ~= "Downed" then
		return false
	end
	local i, ci = get(carrier), get(carried)
	if i.carrying or ci.carriedBy or ci.inBay then
		return false
	end
	local root, carrierRoot = rootOf(carried), rootOf(carrier)
	local humanoid = humanoidOf(carried)
	if not root or not carrierRoot or not humanoid then
		return false
	end
	if (root.Position - carrierRoot.Position).Magnitude > PlayerTuning.CarryPromptRange + 2 then
		return false
	end
	if Inventory then
		Inventory.dropHeavy(carrier)
	end
	humanoid.PlatformStand = true
	local weld = Instance.new("Weld")
	weld.Name = "CarryWeld"
	weld.Part0 = carrierRoot
	weld.Part1 = root
	weld.C0 = CFrame.new(0, 0.6, 1.1) * CFrame.Angles(math.rad(90), 0, math.rad(90))
	weld.Parent = carrierRoot
	i.carrying = carried
	i.carryWeld = weld
	ci.carriedBy = carrier
	carrier:SetAttribute("Carrying", carried.UserId)
	carried:SetAttribute("CarriedBy", carrier.UserId)
	i.sprinting = false
	PlayerStateService.applySpeed(carrier)
	return true
end

local function addCarryPrompt(player: Player)
	local root = rootOf(player)
	if not root or root:FindFirstChild("CarryPrompt") then
		return
	end
	local prompt = Build.prompt(root, "Carry", player.DisplayName, 0.6, PlayerTuning.CarryPromptRange, "CarryPrompt")
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(by: Player)
		if by ~= player then
			PlayerStateService.startCarrying(by, player)
		end
	end)
end

local function removeCarryPrompt(player: Player)
	local root = rootOf(player)
	local prompt = root and root:FindFirstChild("CarryPrompt")
	if prompt then
		prompt:Destroy()
	end
end

-- The Recovery bay -----------------------------------------------------------------------

local function leaveBay(player: Player)
	local i = get(player)
	if i.bayWeld then
		i.bayWeld:Destroy()
	end
	i.bayWeld = nil
	i.inBay = false
	player:SetAttribute("Recovering", nil)
	local humanoid = humanoidOf(player)
	if humanoid then
		humanoid.PlatformStand = false
	end
end

-- Lay a Downed player in the bay (by a carrier, or crawling in themselves).
function PlayerStateService.layInBay(downed: Player): boolean
	local refs = Bus.refs
	if not refs or PlayerStateService.state(downed) ~= "Downed" then
		return false
	end
	local i = get(downed)
	if i.inBay then
		return false
	end
	if i.carriedBy then
		PlayerStateService.stopCarrying(i.carriedBy)
	end
	local root = rootOf(downed)
	local humanoid = humanoidOf(downed)
	if not root or not humanoid then
		return false
	end
	humanoid.PlatformStand = true
	local bay: BasePart = refs.recoveryBay
	root.CFrame = bay.CFrame * CFrame.new(0, 1.4, 0) * CFrame.Angles(0, 0, math.rad(90))
	local weld = Instance.new("Weld")
	weld.Name = "BayWeld"
	weld.Part0 = bay
	weld.Part1 = root
	weld.C0 = CFrame.new(0, 1.4, 0) * CFrame.Angles(0, 0, math.rad(90))
	weld.Parent = bay
	i.bayWeld = weld
	i.inBay = true
	i.recoverLeft = Config.Tuning.Bus.RecoveryBaySeconds
	downed:SetAttribute("Recovering", now() + i.recoverLeft)
	return true
end

function PlayerStateService.hookBus(refs: any)
	local bay: BasePart = refs.recoveryBay
	local prompt = Build.prompt(bay, "Lay in the Recovery bay", "Recovery bay", 0.5, 7, "BayPrompt")
	prompt.Triggered:Connect(function(by: Player)
		local i = get(by)
		if i.carrying then
			PlayerStateService.layInBay(i.carrying)
		elseif PlayerStateService.state(by) == "Downed" then
			PlayerStateService.layInBay(by)
		end
	end)
end

-- Downed, Lost, revived -------------------------------------------------------------------

function PlayerStateService.revive(player: Player)
	if PlayerStateService.state(player) ~= "Downed" then
		return
	end
	local i = get(player)
	leaveBay(player)
	if i.carriedBy then
		PlayerStateService.stopCarrying(i.carriedBy)
	end
	removeCarryPrompt(player)
	player:SetAttribute("BleedDeadline", nil)
	local humanoid = humanoidOf(player)
	if humanoid then
		humanoid.Health = PlayerTuning.Health
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
	setState(player, if Bus.isAboard(player) then "Aboard" else "Outside")
	PlayerStateService.applySpeed(player)
	PlayerStateService.Revived:Fire(player)
	Net.notifyAll("Revived", { userId = player.UserId })
end

function PlayerStateService.lose(player: Player, reason: string)
	local s = PlayerStateService.state(player)
	if s == "Static" or s == "Lobby" then
		return
	end
	-- The First Ride can't be failed: instead of Lost, back to a seat with a word on
	-- what would have happened.
	local director = Registry.find("RunDirector")
	if director and director.mode == "Tutorial" and director.running then
		local between = Registry.find("BetweenService")
		if between and between.cancel then
			between.cancel(player)
		end
		PlayerStateService.restore(player)
		if player.Character then
			director.placeInBus(player.Character)
		end
		setState(player, "Aboard")
		Net.notify(player, "Fade", { seconds = 1 })
		Net.notify(player, "Toast", {
			text = "On a real ride you'd be Lost now. This time the Driver let you back on.",
		})
		return
	end
	local i = get(player)
	if i.carrying then
		PlayerStateService.stopCarrying(player)
	end
	if i.carriedBy then
		PlayerStateService.stopCarrying(i.carriedBy)
	end
	leaveBay(player)
	removeCarryPrompt(player)
	player:SetAttribute("BleedDeadline", nil)
	if Inventory then
		Inventory.dropAll(player)
	end
	setState(player, "Static")
	local character = player.Character
	local root = rootOf(player)
	if character then
		World.setGhost(character, true)
		for _, d in character:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then
				(d :: any).Transparency = 1
			end
		end
	end
	if root then
		root.Anchored = true
		root.CFrame = PlayerStateService.StaticRoom * CFrame.new(math.random(-20, 20), 0, math.random(-20, 20))
	end
	PlayerStateService.applySpeed(player)
	PlayerStateService.Lost:Fire(player, reason)
	Net.notifyAll("Lost", { userId = player.UserId, reason = reason })
	Log.info("Players", player.Name, "is Lost:", reason)
end

-- Knock a player Down. A second hit while Downed makes them Lost.
function PlayerStateService.down(player: Player, cause: string)
	local s = PlayerStateService.state(player)
	if s == "Static" or s == "Lobby" then
		return
	end
	if s == "Downed" or s == "LeftBehind" then
		PlayerStateService.lose(player, cause)
		return
	end
	local i = get(player)
	if i.carrying then
		PlayerStateService.stopCarrying(player)
	end
	if Inventory then
		Inventory.dropHeavy(player)
	end
	i.sprinting = false
	i.crouching = false
	i.bleedLeft = PlayerTuning.BleedOutSeconds
	setState(player, "Downed")
	player:SetAttribute("BleedDeadline", now() + i.bleedLeft)
	local humanoid = humanoidOf(player)
	if humanoid then
		humanoid.Health = PlayerTuning.DownedHealth
	end
	addCarryPrompt(player)
	PlayerStateService.applySpeed(player)
	PlayerStateService.Downed:Fire(player, cause)
	Net.notify(player, "Caught", { cause = cause })
	Net.notifyAll("Downed", { userId = player.UserId, cause = cause })
	Log.info("Players", player.Name, "is Down:", cause)
end

function PlayerStateService.damage(player: Player, amount: number, cause: string)
	if not PlayerStateService.isHealthy(player) then
		return
	end
	local humanoid = humanoidOf(player)
	if not humanoid then
		return
	end
	local health = humanoid.Health - amount
	if health <= PlayerTuning.DownedHealth then
		PlayerStateService.down(player, cause)
	else
		humanoid.Health = health
	end
end

-- Left Behind: outside when the doors close. Downed players outside are Lost instead.
function PlayerStateService.leaveBehind(player: Player)
	local s = PlayerStateService.state(player)
	if s == "Downed" then
		PlayerStateService.lose(player, "left")
		return
	end
	if s ~= "Outside" then
		return
	end
	local i = get(player)
	if i.carrying then
		PlayerStateService.stopCarrying(player)
	end
	setState(player, "LeftBehind")
	PlayerStateService.applySpeed(player)
end

-- Back from The Between (or rescued): a normal, healthy rider again.
function PlayerStateService.restore(player: Player)
	local character = player.Character
	if character then
		World.setGhost(character, false)
		for _, d in character:GetDescendants() do
			if (d:IsA("BasePart") and d.Name ~= "HumanoidRootPart") or d:IsA("Decal") then
				(d :: any).Transparency = 0
			end
		end
	end
	local root = rootOf(player)
	if root then
		root.Anchored = false
	end
	local humanoid = humanoidOf(player)
	if humanoid then
		humanoid.Health = PlayerTuning.Health
		humanoid.PlatformStand = false
	end
	leaveBay(player)
	removeCarryPrompt(player)
	player:SetAttribute("BleedDeadline", nil)
	setState(player, if Bus.isAboard(player) then "Aboard" else "Outside")
	PlayerStateService.applySpeed(player)
end

-- Run lifecycle ----------------------------------------------------------------------------

function PlayerStateService.beginRun(player: Player)
	info[player] = nil
	PlayerStateService.restore(player)
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	player.CameraMaxZoomDistance = 0.5
end

function PlayerStateService.toLobby(player: Player)
	PlayerStateService.restore(player)
	setState(player, "Lobby")
	player.CameraMode = Enum.CameraMode.Classic
	player.CameraMaxZoomDistance = 14
	PlayerStateService.applySpeed(player)
end

-- Every player who is not Static, Lobby or LeftBehind.
function PlayerStateService.living(): { Player }
	local out = {}
	for _, player in Players:GetPlayers() do
		local s = PlayerStateService.state(player)
		if s == "Aboard" or s == "Outside" or s == "Downed" then
			table.insert(out, player)
		end
	end
	return out
end

function PlayerStateService.allLost(): boolean
	local any = false
	for _, player in Players:GetPlayers() do
		local s = PlayerStateService.state(player)
		if s ~= "Lobby" then
			any = true
			if s ~= "Static" then
				return false
			end
		end
	end
	return any
end

local function setupCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	humanoid.BreakJointsOnDeath = false
	humanoid.UseJumpPower = true
	humanoid.MaxHealth = PlayerTuning.Health
	humanoid.Health = PlayerTuning.Health
	info[player] = nil
	PlayerStateService.applySpeed(player)
	-- Fall damage (the server measures the drop).
	humanoid.StateChanged:Connect(function(_, new)
		local i = get(player)
		local root = rootOf(player)
		if not root then
			return
		end
		if new == Enum.HumanoidStateType.Freefall then
			i.fallStartY = root.Position.Y
		elseif new == Enum.HumanoidStateType.Landed and i.fallStartY then
			local drop = i.fallStartY - root.Position.Y
			i.fallStartY = nil
			if drop > PlayerTuning.FallDamageMinHeight then
				PlayerStateService.damage(
					player,
					(drop - PlayerTuning.FallDamageMinHeight) * PlayerTuning.FallDamagePerStud,
					"fall"
				)
			end
		end
	end)
end

local accumulator = 0

-- Deadlines move every frame while paused; only replicate when they drift noticeably.
local function setTime(player: Player, name: string, value: number)
	local old = player:GetAttribute(name)
	if type(old) ~= "number" or math.abs(old - value) > 0.5 then
		player:SetAttribute(name, value)
	end
end

local function tick(dt: number)
	local t = now()
	for _, player in Players:GetPlayers() do
		local i = get(player)
		local s = PlayerStateService.state(player)
		-- Aboard or outside.
		if s == "Aboard" or s == "Outside" then
			local aboard = Bus.refs ~= nil and Bus.isAboard(player)
			setState(player, if aboard then "Aboard" else "Outside")
			-- Stamina
			local humanoid = humanoidOf(player)
			local moving = humanoid ~= nil and humanoid.MoveDirection.Magnitude > 0.1
			if player:GetAttribute("Stance") == "Sprint" and moving then
				i.stamina = math.max(0, i.stamina - dt)
				if i.stamina <= 0 then
					i.sprinting = false
					PlayerStateService.applySpeed(player)
				end
			else
				local regen = MoveTuning.StaminaRegenPerSecond
					* (if Perks.has(player, "pack_mule") then MoveTuning.PackMuleRegenMultiplier else 1)
				i.stamina = math.min(MoveTuning.StaminaSeconds, i.stamina + regen * dt)
			end
			player:SetAttribute("Stamina", math.floor(i.stamina / MoveTuning.StaminaSeconds * 100))
		elseif s == "Downed" then
			if i.inBay then
				if Bus.lightsOn then
					i.recoverLeft -= dt
				end
				setTime(player, "Recovering", t + i.recoverLeft)
				if i.recoverLeft <= 0 then
					PlayerStateService.revive(player)
				end
			elseif Bus.refs and Bus.isAboard(player) then
				-- Bleed-out pauses on the bus.
				setTime(player, "BleedDeadline", t + i.bleedLeft)
				player:SetAttribute("BleedPaused", true)
			else
				i.bleedLeft -= dt
				player:SetAttribute("BleedPaused", false)
				setTime(player, "BleedDeadline", t + i.bleedLeft)
				if i.bleedLeft <= 0 then
					PlayerStateService.lose(player, "bled")
				end
			end
		end
	end
end

function PlayerStateService:Init()
	Bus = Registry.get("BusService")
	World = Registry.get("WorldService")
	Inventory = Registry.find("InventoryService")
end

function PlayerStateService:Start()
	local function onPlayer(player: Player)
		player:SetAttribute("State", "Lobby")
		player.CharacterAdded:Connect(function(character)
			setupCharacter(player, character)
		end)
		if player.Character then
			task.spawn(setupCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local i = info[player]
		if i then
			if i.carrying then
				PlayerStateService.stopCarrying(player)
			end
			if i.carriedBy then
				PlayerStateService.stopCarrying(i.carriedBy)
			end
		end
		info[player] = nil
	end)
	Bus.Spawned:Connect(PlayerStateService.hookBus)
	if Bus.refs then
		PlayerStateService.hookBus(Bus.refs)
	end
	Net.on("Move", onMove)
	task.spawn(function()
		while true do
			local dt = task.wait(0.1)
			accumulator += dt
			tick(dt)
		end
	end)
end

return PlayerStateService
