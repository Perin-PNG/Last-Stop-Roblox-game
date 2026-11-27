--!strict
-- Collects noise events (position, radius, source) for Listener and Hunter entities.
-- Footsteps are sampled from each character's movement and stance; landings, dropped
-- items, doors, thrown decoys and voice post their own events.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local Tuning = Config.Tuning.Noise

local NoiseService = {}

export type Noise = {
	position: Vector3,
	radius: number,
	source: string,
	player: Player?,
	at: number,
}

NoiseService.events = {} :: { Noise }

local function now(): number
	return os.clock()
end

local function prune()
	local cutoff = now() - Tuning.Lifetime
	local keep = {}
	for _, e in NoiseService.events do
		if e.at >= cutoff then
			table.insert(keep, e)
		end
	end
	NoiseService.events = keep
end

function NoiseService.post(position: Vector3, radius: number, source: string, player: Player?)
	if radius <= 0 then
		return
	end
	table.insert(NoiseService.events, {
		position = position,
		radius = radius,
		source = source,
		player = player,
		at = now(),
	})
	if #NoiseService.events > 200 then
		prune()
	end
end

-- The loudest recent noise a listener at `pos` can hear. Loudness is how far inside the
-- noise radius the listener is; `hearing` scales every radius.
function NoiseService.loudestHeard(pos: Vector3, hearing: number?, since: number?): Noise?
	local mult = hearing or 1
	local cutoff = now() - (since or Tuning.Lifetime)
	local best: Noise? = nil
	local bestScore = 0
	for _, e in NoiseService.events do
		if e.at >= cutoff then
			local reach = e.radius * mult
			local d = (e.position - pos).Magnitude
			if d <= reach then
				local score = (reach - d) / reach + (e.at - cutoff) * 0.01
				if score > bestScore then
					bestScore = score
					best = e
				end
			end
		end
	end
	return best
end

local lastPos: { [Player]: Vector3 } = {}

local function sampleFootsteps()
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if humanoid and root and humanoid.Health > 0 then
			local state = player:GetAttribute("State")
			if state == "Static" or state == "Lobby" then
				continue
			end
			local prev = lastPos[player]
			lastPos[player] = root.Position
			if prev then
				local moved = Vector3.new(root.Position.X - prev.X, 0, root.Position.Z - prev.Z).Magnitude
				-- Riders move with the bus; only count movement relative to the floor.
				local floor = humanoid.FloorMaterial ~= Enum.Material.Air
				local relative = root.AssemblyLinearVelocity
					- (if humanoid.SeatPart then humanoid.SeatPart.AssemblyLinearVelocity else Vector3.zero)
				if floor and moved > 0.5 and humanoid.MoveDirection.Magnitude > 0.1 then
					local stance = player:GetAttribute("Stance")
					local radius = Tuning.WalkRadius
					if stance == "Sprint" then
						radius = Tuning.SprintRadius
					elseif stance == "Crouch" or state == "Downed" then
						radius = Tuning.CrouchRadius
					end
					if relative.Magnitude < 2 and stance ~= "Sprint" then
						radius = math.min(radius, Tuning.WalkRadius)
					end
					NoiseService.post(root.Position, radius, "steps", player)
				end
			end
		else
			lastPos[player] = nil
		end
	end
end

local function watchLanding(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	humanoid.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Landed then
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and player:GetAttribute("Stance") ~= "Crouch" then
				NoiseService.post(root.Position, Tuning.LandRadius, "land", player)
			end
		end
	end)
end

function NoiseService:Init() end

function NoiseService:Start()
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			watchLanding(player, character)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function(character)
			watchLanding(player, character)
		end)
		if player.Character then
			task.spawn(watchLanding, player, player.Character)
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		lastPos[player] = nil
	end)
	-- Voice: each client reports its own microphone level (0..1).
	Net.on("VoiceLevel", function(player: Player, level: any)
		if not Net.isFiniteNumber(level) then
			return
		end
		level = math.clamp(level, 0, 1)
		if level < Tuning.VoiceThreshold then
			return
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and player:GetAttribute("State") ~= "Static" then
			NoiseService.post(root.Position, Tuning.VoiceRadiusAtMax * level, "voice", player)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1 / Tuning.SampleHz)
			sampleFootsteps()
			prune()
		end
	end)
end

return NoiseService
