--!strict
-- Who is looking at what. Each client sends its camera look direction about 10 times a
-- second; the server keeps the latest one and answers "is this player looking at that
-- point" for the mirror rule and for Watchers. A flickering flashlight counts as looking
-- away, and so does a stale report.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local Tuning = Config.Tuning.Gaze

local GazeService = {}

type Report = { dir: Vector3, at: number }

local reports: { [Player]: Report } = {}

local function head(player: Player): BasePart?
	local character = player.Character
	local part = character and character:FindFirstChild("Head")
	if part and part:IsA("BasePart") then
		return part
	end
	return nil
end

-- The player's eye position and look direction, or nil when the report is stale.
function GazeService.look(player: Player): (Vector3?, Vector3?)
	local report = reports[player]
	local h = head(player)
	if not report or not h then
		return nil, nil
	end
	if os.clock() - report.at > Tuning.StaleAfter then
		return nil, nil
	end
	return h.Position, report.dir
end

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true

-- Is `player` looking at `target` within `coneDegrees` and `range`? With `clear`, the line
-- of sight must be unblocked (ignoring the ignore list).
function GazeService.isLookingAt(
	player: Player,
	target: Vector3,
	coneDegrees: number,
	range: number,
	clear: boolean?,
	ignore: { Instance }?
): boolean
	if player:GetAttribute("Flicker") == true then
		return false
	end
	local state = player:GetAttribute("State")
	if state == "Static" or state == "Lobby" then
		return false
	end
	local eye, dir = GazeService.look(player)
	if not eye or not dir then
		return false
	end
	local to = target - eye
	local dist = to.Magnitude
	if dist > range or dist < 0.01 then
		return false
	end
	local cos = dir:Dot(to / dist)
	if cos < math.cos(math.rad(coneDegrees)) then
		return false
	end
	if clear then
		local list: { Instance } = { (player.Character :: any) :: Instance }
		if ignore then
			for _, i in ignore do
				table.insert(list, i)
			end
		end
		params.FilterDescendantsInstances = list
		local hit = workspace:Raycast(eye, to * 0.98, params)
		if hit then
			return false
		end
	end
	return true
end

-- Is anyone (optionally from `players`) looking at `target`?
function GazeService.anyoneLooking(
	target: Vector3,
	coneDegrees: number,
	range: number,
	clear: boolean?,
	ignore: { Instance }?
): boolean
	for _, player in Players:GetPlayers() do
		if GazeService.isLookingAt(player, target, coneDegrees, range, clear, ignore) then
			return true
		end
	end
	return false
end

function GazeService:Init() end

function GazeService:Start()
	Net.on("Gaze", function(player: Player, dir: any)
		if not Net.isVector3(dir) then
			return
		end
		local v = dir :: Vector3
		local m = v.Magnitude
		if m < 0.5 or m > 1.5 then
			Net.drop(player)
			return
		end
		reports[player] = { dir = v.Unit, at = os.clock() }
	end)
	Players.PlayerRemoving:Connect(function(player)
		reports[player] = nil
	end)
end

return GazeService
