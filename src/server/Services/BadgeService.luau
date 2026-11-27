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

local LIFER_RANK = 31

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
		local catalogTotal = 0
		for _ in Config.Anomalies.ById do
			catalogTotal += 1
		end
		data.Changed:Connect(function(player: Player, d: any)
			if type(d) ~= "table" then
				return
			end
			-- Lifer: Rank 31.
			if type(d.rank) == "number" and d.rank >= LIFER_RANK then
				BadgeService.award(player, "Lifer")
			end
			-- Inspector: half the Anomaly Catalog photographed.
			if type(d.catalog) == "table" and catalogTotal > 0 then
				local n = 0
				for _ in d.catalog do
					n += 1
				end
				if n >= math.ceil(catalogTotal * 0.5) then
					BadgeService.award(player, "Inspector")
				end
			end
		end)
	end
	-- Eyes Front: a whole run (not the First Ride) without a mirror violation.
	local mirrorBreakers: { [Player]: boolean } = {}
	local driver = Registry.find("DriverService")
	if driver then
		driver.Violation:Connect(function(player: Player, reason: string)
			if reason == "mirror" then
				mirrorBreakers[player] = true
			end
		end)
	end
	local playerState = Registry.find("PlayerStateService")
	if director then
		director.RunStarted:Connect(function()
			table.clear(mirrorBreakers)
		end)
		director.RunEnded:Connect(function(ending: string)
			if ending == "Tutorial" then
				return
			end
			for _, player in director.runPlayers() do
				local lost = playerState and playerState.state(player) == "Static"
				if not mirrorBreakers[player] and not lost then
					BadgeService.award(player, "EyesFront")
				end
			end
		end)
	end
	-- Back From The Between: made it back after being Left Behind.
	local between = Registry.find("BetweenService")
	if between then
		between.Returned:Connect(function(player: Player)
			BadgeService.award(player, "BackFromTheBetween")
		end)
	end
	-- Not On My Bus: escorted a mimic off.
	local passengers = Registry.find("PassengerService")
	if passengers then
		passengers.Escorted:Connect(function(player: Player, wasMimic: boolean)
			if wasMimic then
				BadgeService.award(player, "NotOnMyBus")
			end
		end)
	end
	-- Late Fee: the Latecomer rode and got off with nobody Lost.
	local latecomer = Registry.find("LatecomerService")
	if latecomer and director then
		latecomer.Survived:Connect(function()
			for _, player in director.runPlayers() do
				if not (playerState and playerState.state(player) == "Static") then
					BadgeService.award(player, "LateFee")
				end
			end
		end)
	end
	Players.PlayerRemoving:Connect(function(player: Player)
		mirrorBreakers[player] = nil
	end)
end

return BadgeService
