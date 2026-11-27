--!strict
-- Tokens and XP at the end of a run, from the plan's table:
--   each stop survived 10, each anomaly photographed 5, each fragment banked 20,
--   Home 50, Transfer 30, Last Stop 10.
-- Then first run of the day doubles everything, each friend in the run adds 10% (up to
-- 30%), and the Commuter Pass adds 25%. Everyone who started the run is paid, Lost or
-- not, so even a loss moves progression forward.
-- Also keeps the saved stats: runs, stops survived, times Left Behind, mimics escorted,
-- endings seen, stops visited (the Route Map) and the Anomaly Catalog.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Log = require(Shared.Log)

local Registry = require(script.Parent.Parent:WaitForChild("Registry"))

local Tuning = Config.Tuning.Rewards

local RewardService = {}

local Data: any
local Run: any
local PlayerState: any

type Ledger = { photos: { [string]: boolean }, photoCount: number }
local ledgers: { [Player]: Ledger } = {}
local friendCache: { [string]: boolean } = {}

local function ledger(player: Player): Ledger
	local l = ledgers[player]
	if not l then
		l = { photos = {}, photoCount = 0 }
		ledgers[player] = l
	end
	return l
end

local function areFriends(a: Player, b: Player): boolean
	local key = if a.UserId < b.UserId then `{a.UserId}:{b.UserId}` else `{b.UserId}:{a.UserId}`
	local cached = friendCache[key]
	if cached ~= nil then
		return cached
	end
	local ok, result = pcall(function()
		return a:IsFriendsWith(b.UserId)
	end)
	local friends = ok and result == true
	friendCache[key] = friends
	return friends
end

local function dayOf(t: number): number
	return math.floor(t / 86400) -- UTC days
end

local function catalogSize(): number
	local n = 0
	for _ in Config.Anomalies.ById do
		n += 1
	end
	return n
end

-- Anomaly Catalog: count the photo, and pay a bonus the first time a player passes 25%,
-- 50% and 100% of it.
local function catalogPhoto(player: Player, id: string)
	local total = catalogSize()
	local before, after = 0, 0
	Data.update(player, function(data: any)
		for _ in data.catalog do
			before += 1
		end
		data.catalog[id] = (data.catalog[id] or 0) + 1
		for _ in data.catalog do
			after += 1
		end
	end)
	if after == before or total == 0 then
		return
	end
	Net.notify(player, "Toast", { text = `New Anomaly Catalog entry: {Config.Anomalies.ById[id].name}` })
	for i, share in Config.Meta.CatalogRewardsAt do
		local need = math.ceil(total * share)
		if before < need and after >= need then
			local bonus = Tuning.CatalogBonus[i] or 0
			Data.addTokens(player, bonus, "catalog " .. math.floor(share * 100) .. "%")
			Net.notify(player, "Toast", {
				text = `Anomaly Catalog {math.floor(share * 100)}% complete. +{bonus} Tokens.`,
			})
		end
	end
end

local function payout(player: Player, ending: string, summary: any, players: { Player })
	local data = Data.get(player)
	if not data then
		return
	end
	local l = ledger(player)
	local lines: { { label: string, amount: number } } = {}
	local base = 0
	local function add(label: string, amount: number)
		if amount > 0 then
			table.insert(lines, { label = label, amount = amount })
			base += amount
		end
	end
	local stops = tonumber(summary.stops) or 0
	local fragments = tonumber(summary.fragments) or 0
	add(`Stops survived x{stops}`, stops * Tuning.PerStop)
	add(`Anomalies photographed x{l.photoCount}`, l.photoCount * Tuning.PerPhoto)
	add(`Fragments banked x{fragments}`, fragments * Tuning.PerFragment)
	local endingDef = Config.Meta.Endings[ending]
	add(`{if endingDef then endingDef.name else ending} ending`, Tuning.Endings[ending] or 0)

	-- Multipliers.
	local mult = 1
	local notes: { string } = {}
	local now = os.time()
	local firstToday = dayOf(data.lastDailyBonus or 0) ~= dayOf(now)
	if firstToday and base > 0 then
		mult *= Tuning.FirstRunOfDayMultiplier
		table.insert(notes, "First run of the day x2")
	end
	local friends = 0
	for _, other in players do
		if other ~= player and other.Parent and areFriends(player, other) then
			friends += 1
		end
	end
	local friendBonus = math.min(friends * Tuning.FriendBonusEach, Tuning.FriendBonusMax)
	if friendBonus > 0 then
		table.insert(notes, `Friends +{math.floor(friendBonus * 100 + 0.5)}%`)
	end
	local passBonus = if player:GetAttribute("CommuterPass") == true then Tuning.CommuterPassBonus else 0
	if passBonus > 0 then
		table.insert(notes, `Commuter Pass +{math.floor(passBonus * 100 + 0.5)}%`)
	end
	local total = math.floor(base * mult * (1 + friendBonus + passBonus) + 0.5)

	local lost = PlayerState.state(player) == "Static"
	Data.update(player, function(d: any)
		d.stats.runs += 1
		d.stats.stopsSurvived += stops
		if lost then
			d.stats.timesLeftBehind += 1
		end
		d.endings[ending] = (d.endings[ending] or 0) + 1
		if firstToday and base > 0 then
			d.lastDailyBonus = now
		end
	end)
	Data.addTokens(player, total, "run")
	local after = Data.get(player)
	Net.notify(player, "Rewards", {
		lines = lines,
		notes = notes,
		total = total,
		tokens = after and after.tokens or 0,
		rank = after and after.rank or 1,
		title = Data.titleFor(after and after.rank or 1),
		xp = after and after.xp or 0,
		thisRankXP = Data.xpForRank(after and after.rank or 1),
		nextRankXP = Data.xpForRank((after and after.rank or 1) + 1),
	})
	Log.info("Reward", player.Name, "earned", total, "Tokens (base", base, ")")
end

function RewardService:Init()
	Data = Registry.get("DataService")
	Run = Registry.get("RunDirector")
	PlayerState = Registry.get("PlayerStateService")
end

function RewardService:Start()
	Run.RunStarted:Connect(function()
		table.clear(ledgers)
	end)
	Run.StopClosed:Connect(function(built: any)
		if type(built) ~= "table" or type(built.id) ~= "string" then
			return
		end
		for _, player in Run.runPlayers() do
			Data.update(player, function(data: any)
				data.stopsVisited[built.id] = true
			end)
		end
	end)
	local photo = Registry.find("PhotoService")
	if photo then
		photo.Photographed:Connect(function(player: Player, id: string)
			local l = ledger(player)
			if not l.photos[id] then
				l.photos[id] = true
				l.photoCount += 1
			end
			catalogPhoto(player, id)
		end)
	end
	local passengers = Registry.find("PassengerService")
	if passengers then
		passengers.Escorted:Connect(function(player: Player, wasMimic: boolean)
			if wasMimic then
				Data.update(player, function(data: any)
					data.stats.mimicsEscorted += 1
				end)
			end
		end)
	end
	Run.RunEnded:Connect(function(ending: string, summary: any)
		local players = Run.runPlayers()
		for _, player in players do
			task.spawn(payout, player, ending, summary, players)
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		ledgers[player] = nil
	end)
end

return RewardService
