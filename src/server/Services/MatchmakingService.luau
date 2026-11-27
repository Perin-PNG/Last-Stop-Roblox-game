--!strict
-- Lobby place to Route place. The lobby reserves a private Route server for each group and
-- teleports them with the run options. The Route server waits up to RouteJoinWait seconds
-- for the whole group, then starts. Unused while the real PlaceIds are 0 (Combined mode).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Place = require(Shared.Place)
local Net = require(Shared.Net)
local Log = require(Shared.Log)

local Registry = require(script.Parent.Parent:WaitForChild("Registry"))

local MatchmakingService = {}

export type Options = { mode: string?, party: boolean?, seed: number? }

-- Lobby: send a group to a fresh Route server.
function MatchmakingService.send(group: { Player }, opts: Options)
	local routeId = Config.Products.Places.Route
	if routeId == 0 or #group == 0 then
		return
	end
	task.spawn(function()
		local okReserve, code = pcall(function()
			return TeleportService:ReserveServer(routeId)
		end)
		if not okReserve then
			Log.warn("Match", "ReserveServer failed", code)
			Net.notifyList(group, "Toast", { text = "Couldn't reach the route. Try again." })
			return
		end
		local options = Instance.new("TeleportOptions")
		local raw: any = options
		raw.ReservedServerAccessCode = code
		options:SetTeleportData({
			mode = opts.mode or "Standard",
			party = opts.party == true,
			seed = opts.seed,
			size = #group,
		})
		for attempt = 1, 3 do
			local ok, err = pcall(function()
				TeleportService:TeleportAsync(routeId, group, options)
			end)
			if ok then
				return
			end
			Log.warn("Match", "Teleport failed, attempt", attempt, err)
			task.wait(attempt * 2)
		end
		Net.notifyList(group, "Toast", { text = "Couldn't reach the route. Try again." })
	end)
end

-- Route: wait for the group, then start.
local function routeServer()
	local director = Registry.get("RunDirector")
	local expected = 1
	local opts: Options = {}
	local first = Players.PlayerAdded:Wait()
	local data = first:GetJoinData().TeleportData
	if type(data) == "table" then
		local d = data :: any
		expected = math.clamp(tonumber(d.size) or 1, 1, Config.Tuning.Run.MaxPlayers)
		-- Teleport data comes through the client: only known modes.
		local modes = { Standard = true, Tutorial = true, Daily = true, Graveyard = true }
		opts.mode = if type(d.mode) == "string" and modes[d.mode] then d.mode else "Standard"
		opts.party = d.party == true
		opts.seed = if type(d.seed) == "number" then d.seed else nil
	end
	local waitUntil = os.clock() + Config.Tuning.Run.RouteJoinWait
	while #Players:GetPlayers() < expected and os.clock() < waitUntil do
		task.wait(0.5)
	end
	director.startRun(Players:GetPlayers(), { mode = opts.mode, party = opts.party, seed = opts.seed })
end

function MatchmakingService:Init() end

function MatchmakingService:Start()
	if Place.role() == "Route" then
		task.spawn(routeServer)
	end
end

return MatchmakingService
