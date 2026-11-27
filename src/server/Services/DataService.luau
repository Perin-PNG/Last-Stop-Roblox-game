--!strict
-- Saved player data: Tokens, XP and Rank, Perks, cosmetics, the Anomaly Catalog, stops
-- visited, endings, stats and settings. One DataStore key per player, written with
-- UpdateAsync under a session lock (in the style of ProfileStore): a server takes the lock
-- when it loads a player, keeps it fresh with autosaves, and releases it on leave. Another
-- server that finds a fresh lock waits for it to clear, then takes it over if it's stale.
--
-- Studio needs "Enable Studio Access to API Services" to save. Without it, data lives in
-- memory for the session and a warning says so.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Log = require(Shared.Log)
local Signal = require(Shared.Util.Signal)

local DataService = {}

DataService.Loaded = Signal.new() :: Signal.Signal<Player, any> -- (player, data)
DataService.Changed = Signal.new() :: Signal.Signal<Player, any> -- (player, data)

local STORE_NAME = "PlayerData_v1"
local VERSION = 1
local AUTOSAVE_SECONDS = 120
local LOCK_STALE_SECONDS = 600
local LOAD_ATTEMPTS = 6
local RANKS = Config.Tuning.Ranks

export type PlayerData = {
	version: number,
	tokens: number,
	xp: number,
	rank: number,
	perks: { unlocked: { string }, equipped: { string } },
	cosmetics: { owned: { [string]: boolean }, equipped: { [string]: string } },
	journal: { [string]: boolean },
	catalog: { [string]: number },
	stopsVisited: { [string]: boolean },
	endings: { [string]: number },
	stats: { runs: number, stopsSurvived: number, timesLeftBehind: number, mimicsEscorted: number },
	weekly: { weekId: string, progress: { [string]: number }, claimed: boolean },
	lastDailyBonus: number,
	purchases: { [string]: number },
	settings: { [string]: any },
	tutorialDone: boolean,
	hints: { [string]: boolean },
	offDutyTalks: number,
}

local function template(): PlayerData
	return {
		version = VERSION,
		tokens = 0,
		xp = 0,
		rank = 1,
		perks = { unlocked = {}, equipped = {} },
		cosmetics = { owned = {}, equipped = {} },
		journal = {},
		catalog = {},
		stopsVisited = {},
		endings = {},
		stats = { runs = 0, stopsSurvived = 0, timesLeftBehind = 0, mimicsEscorted = 0 },
		weekly = { weekId = "", progress = {}, claimed = false },
		lastDailyBonus = 0,
		purchases = {},
		settings = {},
		tutorialDone = false,
		hints = {},
		offDutyTalks = 0,
	}
end

type Session = {
	data: PlayerData,
	key: string,
	lockId: string?,
	saving: boolean,
	released: boolean,
}

local sessions: { [Player]: Session } = {}
local store: DataStore? = nil
local memoryOnly = false

-- Helpers ------------------------------------------------------------------------------

-- Fill in anything the template has that `data` is missing (new fields after an update).
local function reconcile(data: { [string]: any }, base: { [string]: any })
	for k, v in base do
		if data[k] == nil then
			data[k] = if type(v) == "table" then table.clone(v) else v
		elseif type(v) == "table" and type(data[k]) == "table" and next(v) ~= nil then
			reconcile(data[k], v)
		end
	end
end

local function migrate(data: any): PlayerData
	-- Future schema changes go here, keyed by data.version.
	data.version = VERSION
	return data
end

local function retry<T>(label: string, fn: () -> T): (boolean, T?)
	local wait = 1
	for attempt = 1, 4 do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		Log.warn("Data", label, "attempt", attempt, "failed:", result)
		task.wait(wait)
		wait *= 2
	end
	return false, nil
end

function DataService.xpForRank(rank: number): number
	if rank <= 1 then
		return 0
	end
	return math.floor(RANKS.Base * (rank - 1) ^ RANKS.Exponent)
end

function DataService.rankFor(xp: number): number
	local rank = 1
	while rank < RANKS.MaxRank and xp >= DataService.xpForRank(rank + 1) do
		rank += 1
	end
	return rank
end

function DataService.titleFor(rank: number): string
	local title = RANKS.Titles[1].title
	for _, t in RANKS.Titles do
		if rank >= t.from then
			title = t.title
		end
	end
	return title
end

-- Perks unlock by rank; nobody buys them.
local function unlockPerks(data: PlayerData)
	for _, perk in Config.Meta.Perks do
		if data.rank >= perk.rank and not table.find(data.perks.unlocked, perk.id) then
			table.insert(data.perks.unlocked, perk.id)
		end
	end
	local slots = if data.rank >= RANKS.SecondPerkAt then 2 else 1
	while #data.perks.equipped > slots do
		table.remove(data.perks.equipped)
	end
end

-- Mirror what the client and other services need onto Player attributes.
local function publish(player: Player, data: PlayerData)
	player:SetAttribute("Tokens", data.tokens)
	player:SetAttribute("XP", data.xp)
	player:SetAttribute("Rank", data.rank)
	player:SetAttribute("RankTitle", DataService.titleFor(data.rank))
	player:SetAttribute("NextRankXP", DataService.xpForRank(data.rank + 1))
	player:SetAttribute("Perk", data.perks.equipped[1])
	player:SetAttribute("Perk2", data.perks.equipped[2])
	player:SetAttribute("PerksUnlocked", table.concat(data.perks.unlocked, ","))
	player:SetAttribute(
		"CosmeticsOwned",
		table.concat(
			(function()
				local ids = {}
				for id, owned in data.cosmetics.owned do
					if owned then
						table.insert(ids, id)
					end
				end
				table.sort(ids)
				return ids
			end)(),
			","
		)
	)
	for _, def in Config.Meta.Cosmetics do
		player:SetAttribute("Wear_" .. def.slot, data.cosmetics.equipped[def.slot])
	end
	player:SetAttribute(
		"CatalogCount",
		(function()
			local n = 0
			for _ in data.catalog do
				n += 1
			end
			return n
		end)()
	)
	local visited = 0
	for _ in data.stopsVisited do
		visited += 1
	end
	player:SetAttribute("StopsVisited", visited)
	local endings = {}
	for id in data.endings do
		table.insert(endings, id)
	end
	table.sort(endings)
	player:SetAttribute("EndingsSeen", table.concat(endings, ","))
	player:SetAttribute("DataSaved", not memoryOnly)
	player:SetAttribute("ReduceFlashing", data.settings.reduceFlashing == true)
	player:SetAttribute("DataLoaded", true)
end

-- Store access ------------------------------------------------------------------------

local function openStore()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		memoryOnly = true
		Log.warn("Data", "No DataStore access, so progress won't save this session:", result)
	end
end

local function keyFor(player: Player): string
	return "player_" .. player.UserId
end

-- Load and lock. Returns nil if the data couldn't be loaded safely (the player is kicked
-- rather than playing on a copy that would overwrite their real data).
local function load(player: Player): (PlayerData?, string?)
	if memoryOnly or not store then
		return template(), nil
	end
	local key = keyFor(player)
	local jobId = if game.JobId ~= "" then game.JobId else "studio-" .. HttpService:GenerateGUID(false)
	for attempt = 1, LOAD_ATTEMPTS do
		local lockedElsewhere = false
		local ok, result = pcall(function()
			return (store :: DataStore):UpdateAsync(key, function(old: any)
				local now = os.time()
				if type(old) ~= "table" then
					old = { data = template(), lock = nil }
				end
				local lock = old.lock
				if
					type(lock) == "table"
					and lock.jobId ~= jobId
					and now - (lock.at or 0) < LOCK_STALE_SECONDS
					and attempt < LOAD_ATTEMPTS
				then
					lockedElsewhere = true
					return nil -- leave it alone, try again shortly
				end
				old.lock = { jobId = jobId, at = now }
				return old
			end)
		end)
		if ok and not lockedElsewhere and type(result) == "table" then
			local data = result.data
			if type(data) ~= "table" then
				data = template()
			end
			data = migrate(data)
			reconcile(data :: any, template() :: any)
			return data, jobId
		end
		if not ok then
			Log.warn("Data", "load attempt", attempt, "for", player.Name, "failed:", result)
			if RunService:IsStudio() then
				-- Usually "Enable Studio Access to API Services" is off. Play on in memory.
				memoryOnly = true
				Log.warn("Data", "Studio has no DataStore access, so progress won't save this session")
				return template(), nil
			end
		else
			Log.info("Data", player.Name, "is still locked by another server; waiting")
		end
		task.wait(if lockedElsewhere then 6 else 2 * attempt)
		if not player.Parent then
			return nil, nil
		end
	end
	return nil, nil
end

local function save(player: Player, release: boolean)
	local session = sessions[player]
	if not session or memoryOnly or not store or session.released then
		return
	end
	if session.saving and not release then
		return
	end
	session.saving = true
	local data = session.data
	local lockId = session.lockId
	retry("save " .. player.Name, function()
		return (store :: DataStore):UpdateAsync(session.key, function(old: any)
			if type(old) == "table" and type(old.lock) == "table" and old.lock.jobId ~= lockId then
				-- Another server took the session over; don't clobber its data.
				Log.warn("Data", "lost the session lock for", player.Name)
				return nil
			end
			return { data = data, lock = if release then nil else { jobId = lockId, at = os.time() } }
		end)
	end)
	session.saving = false
	if release then
		session.released = true
	end
end

-- API ---------------------------------------------------------------------------------

function DataService.get(player: Player): PlayerData?
	local session = sessions[player]
	return if session and session.data then session.data else nil
end

-- Change a player's data. `fn` edits it in place. Rank, Perks and attributes follow.
function DataService.update(player: Player, fn: (data: PlayerData) -> ())
	local data = DataService.get(player)
	if not data then
		return
	end
	fn(data)
	data.rank = DataService.rankFor(data.xp)
	unlockPerks(data)
	publish(player, data)
	DataService.Changed:Fire(player, data)
end

function DataService.addTokens(player: Player, amount: number, reason: string)
	if amount <= 0 then
		return
	end
	local before = (DataService.get(player) or { rank = 1 } :: any).rank
	DataService.update(player, function(data)
		data.tokens += amount
		data.xp += amount -- XP equals Tokens earned, one for one
	end)
	local data = DataService.get(player)
	if data and data.rank > before then
		local Net = require(Shared.Net)
		Net.notify(player, "RankUp", { rank = data.rank, title = DataService.titleFor(data.rank) })
	end
	Log.info("Data", player.Name, "+", amount, "Tokens for", reason)
end

function DataService.isMemoryOnly(): boolean
	return memoryOnly
end

local function onPlayerAdded(player: Player)
	local data, lockId = load(player)
	if not player.Parent then
		return
	end
	if not data then
		player:Kick("Couldn't load your progress safely. Please rejoin in a minute.")
		return
	end
	sessions[player] = { data = data, key = keyFor(player), lockId = lockId, saving = false, released = false }
	data.rank = DataService.rankFor(data.xp)
	unlockPerks(data)
	publish(player, data)
	DataService.Loaded:Fire(player, data)
	Log.info("Data", "loaded", player.Name, "rank", data.rank, "tokens", data.tokens)
end

function DataService:Init()
	openStore()
end

function DataService:Start()
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player: Player)
		save(player, true)
		sessions[player] = nil
	end)
	game:BindToClose(function()
		if RunService:IsStudio() and memoryOnly then
			return
		end
		local pending = 0
		for player in sessions do
			pending += 1
			task.spawn(function()
				save(player, true)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.2)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for player in sessions do
				task.spawn(save, player, false)
			end
		end
	end)
end

return DataService
