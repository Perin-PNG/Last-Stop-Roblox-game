--!strict
-- Every remote in the game, defined in one place. The server creates them; clients wait
-- for them. Never trust what a client sends: Net.on checks the rate for you, and each
-- handler checks types, ranges and distances.
--
-- Most interactions (pick up, pour, bank, carry, escort, vote, cord, hold) use
-- ProximityPrompt.Triggered on the server and need no remote.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RateLimiter = require(script.Parent.Util.RateLimiter)

-- name -> { kind, rate per second, burst }
local REMOTES: { [string]: { kind: "Event" | "Unreliable", rate: number, burst: number } } = {
	-- client -> server
	Gaze = { kind = "Unreliable", rate = 12, burst = 14 },
	VoiceLevel = { kind = "Unreliable", rate = 12, burst = 14 },
	Move = { kind = "Event", rate = 8, burst = 10 }, -- stance: walk, sprint, crouch
	Flashlight = { kind = "Event", rate = 4, burst = 6 },
	SelectSlot = { kind = "Event", rate = 8, burst = 10 },
	UseItem = { kind = "Event", rate = 3, burst = 4 },
	ThrowItem = { kind = "Event", rate = 2, burst = 3 },
	DropItem = { kind = "Event", rate = 3, burst = 4 },
	Ping = { kind = "Event", rate = 1, burst = 2 },
	TakePhoto = { kind = "Event", rate = 1, burst = 2 },
	GhostAction = { kind = "Event", rate = 1, burst = 2 },
	Settings = { kind = "Event", rate = 1, burst = 3 },
	Kiosk = { kind = "Event", rate = 2, burst = 4 },
	Lobby = { kind = "Event", rate = 1, burst = 3 },
	Tutorial = { kind = "Event", rate = 2, burst = 4 },
	Drive = { kind = "Unreliable", rate = 14, burst = 16 }, -- finale: throttle and steer
	Debug = { kind = "Event", rate = 5, burst = 10 }, -- Studio only
	-- server -> client
	Notify = { kind = "Event", rate = 0, burst = 0 },
	Hallucinate = { kind = "Event", rate = 0, burst = 0 },
	PingShown = { kind = "Event", rate = 0, burst = 0 },
}

local FOLDER_NAME = "Remotes"

local Net = {}

-- Counts of dropped calls per player, for kicking only extreme abusers.
local dropped: { [Player]: number } = {}
Net.KickAfterDropped = 600

local function getFolder(): Folder
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		if not folder then
			folder = Instance.new("Folder")
			folder.Name = FOLDER_NAME
			folder.Parent = ReplicatedStorage
		end
		return folder :: Folder
	end
	return ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

-- Server only: create all remotes once at startup.
function Net.setup()
	assert(RunService:IsServer(), "Net.setup() is server only")
	local folder = getFolder()
	for name, def in REMOTES do
		if not folder:FindFirstChild(name) then
			local remote: Instance
			if def.kind == "Unreliable" then
				remote = Instance.new("UnreliableRemoteEvent")
			else
				remote = Instance.new("RemoteEvent")
			end
			remote.Name = name
			remote.Parent = folder
		end
	end
end

function Net.event(name: string): RemoteEvent
	assert(REMOTES[name], "Unknown remote " .. name)
	return getFolder():WaitForChild(name) :: RemoteEvent
end

function Net.unreliable(name: string): UnreliableRemoteEvent
	assert(REMOTES[name], "Unknown remote " .. name)
	return getFolder():WaitForChild(name) :: UnreliableRemoteEvent
end

-- Server: listen to a client remote with a per-player token bucket. Calls over the limit
-- are dropped silently and counted.
function Net.on(name: string, handler: (player: Player, ...any) -> ()): RBXScriptConnection
	local def = REMOTES[name]
	assert(def, "Unknown remote " .. name)
	local limiter = RateLimiter.new(def.rate, def.burst)
	local remote = getFolder():WaitForChild(name)
	local signal: RBXScriptSignal = (remote :: any).OnServerEvent
	return signal:Connect(function(player: Player, ...)
		if not limiter:allow(player) then
			Net.drop(player)
			return
		end
		local ok, err = pcall(handler :: any, player, ...)
		if not ok then
			warn(`[Net] {name} handler error: {err}`)
		end
	end)
end

function Net.drop(player: Player)
	local count = (dropped[player] or 0) + 1
	dropped[player] = count
	if count >= Net.KickAfterDropped then
		player:Kick("Too many invalid requests.")
	end
end

function Net.forget(player: Player)
	dropped[player] = nil
end

-- Server -> client helpers.
function Net.notify(player: Player, kind: string, payload: any?)
	(Net.event("Notify") :: RemoteEvent):FireClient(player, kind, payload)
end

function Net.notifyAll(kind: string, payload: any?)
	(Net.event("Notify") :: RemoteEvent):FireAllClients(kind, payload)
end

function Net.notifyList(players: { Player }, kind: string, payload: any?)
	local remote = Net.event("Notify")
	for _, player in players do
		if player.Parent then
			remote:FireClient(player, kind, payload)
		end
	end
end

-- Validation helpers for handlers.
function Net.isFiniteNumber(v: any): boolean
	return typeof(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge
end

function Net.isVector3(v: any): boolean
	return typeof(v) == "Vector3"
		and Net.isFiniteNumber((v :: Vector3).X)
		and Net.isFiniteNumber((v :: Vector3).Y)
		and Net.isFiniteNumber((v :: Vector3).Z)
end

function Net.isUnit(v: any): boolean
	return Net.isVector3(v) and math.abs((v :: Vector3).Magnitude - 1) < 0.05
end

function Net.isInt(v: any, min: number, max: number): boolean
	return Net.isFiniteNumber(v) and v % 1 == 0 and v >= min and v <= max
end

return Net
