--!strict
-- Badges. Each id in Config.Products.Badges is 0 until Perin creates the badge in Creator
-- Hub, and a badge with id 0 is skipped, so this is safe to call from anywhere.

local BadgeServiceRoblox = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Log)

local Registry = require(script.Parent.Parent:WaitForChild("Registry"))

local BadgeService = {}

local awarded: { [Player]: { [string]: boolean } } = {}

-- Award the badge named `key` (a key of Config.Products.Badges) to `player`.
function BadgeService.award(player: Player, key: string)
	local id = (Config.Products.Badges :: any)[key]
	if type(id) ~= "number" or id == 0 or not player.Parent then
		return
	end
	local mine = awarded[player]
	if not mine then
		mine = {}
		awarded[player] = mine
	end
	if mine[key] then
		return
	end
	mine[key] = true
	task.spawn(function()
		local okOwns, owns = pcall(function()
			return BadgeServiceRoblox:UserHasBadgeAsync(player.UserId, id)
		end)
		if okOwns and owns then
			return
		end
		for attempt = 1, 3 do
			local ok, err = pcall(function()
				BadgeServiceRoblox:AwardBadge(player.UserId, id)
			end)
			if ok then
				Log.info("Badge", player.Name, key)
				return
			end
			Log.warn("Badge", "Award failed", key, attempt, err)
			task.wait(attempt * 2)
		end
		mine[key] = nil
	end)
end

local ENDING_BADGES = {
	Home = "Home",
	Transfer = "Transfer",
	LastStop = "LastStop",
	DriversSeat = "DriversSeat",
	Tutorial = "FirstRide",
}

function BadgeService:Init() end

function BadgeService:Start()
	Players.PlayerRemoving:Connect(function(player: Player)
		awarded[player] = nil
	end)
	local director = Registry.find("RunDirector")
	if director then
		director.RunEnded:Connect(function(ending: string)
			local key = ENDING_BADGES[ending]
			if not key then
				return
			end
			for _, player in director.runPlayers() do
				BadgeService.award(player, key)
			end
		end)
	end
	local data = Registry.find("DataService")
	if data then
		-- Lifer: Rank 20.
		data.Changed:Connect(function(player: Player, d: any)
			if type(d) == "table" and type(d.rank) == "number" and d.rank >= 20 then
				BadgeService.award(player, "Lifer")
			end
		end)
	end
end

return BadgeService
