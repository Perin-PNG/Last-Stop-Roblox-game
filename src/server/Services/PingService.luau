--!strict
-- The ping wheel's server side: the game's language for players without chat or voice.
-- A ping is an id (1-8, see Config.Text.Pings) and a world point the player aimed at. The
-- server checks both and the rate, then shows it to everyone for 6 seconds.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local Log = require(Shared.Log)

local Registry = require(script.Parent.Parent:WaitForChild("Registry"))

local PingService = {}

PingService.Pinged = Signal.new() -- (player, id, pos)

local PlayerState: any

local counts: { [Player]: number } = {}
local lastAt: { [Player]: number } = {}

function PingService.count(player: Player): number
	return counts[player] or 0
end

function PingService:Init()
	PlayerState = Registry.get("PlayerStateService")
end

function PingService:Start()
	local shown = Net.event("PingShown")
	Net.on("Ping", function(player: Player, id: any, pos: any)
		if not Net.isInt(id, 1, #Config.Text.Pings) or not Net.isVector3(pos) then
			Net.drop(player)
			return
		end
		local root = PlayerState.rootOf(player)
		if not root then
			return
		end
		local p = pos :: Vector3
		if (p - root.Position).Magnitude > Config.Tuning.Ping.MaxDistance then
			p = root.Position + (p - root.Position).Unit * Config.Tuning.Ping.MaxDistance
		end
		local t = os.clock()
		if t - (lastAt[player] or 0) < Config.Tuning.Ping.Cooldown then
			return
		end
		lastAt[player] = t
		local ghost = PlayerState.state(player) == "Static"
		counts[player] = (counts[player] or 0) + 1
		PingService.Pinged:Fire(player, id, p)
		shown:FireAllClients(player.UserId, id, p, ghost)
		Log.info("Ping", player.Name, id)
	end)
	Players.PlayerRemoving:Connect(function(player)
		counts[player] = nil
		lastAt[player] = nil
	end)
end

return PingService
