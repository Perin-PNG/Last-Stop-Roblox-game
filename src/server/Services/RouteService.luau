--!strict
-- The route: which stop comes next. The plan (Config.Stops.Plan, or SlicePlan for the
-- vertical slice) says what each stop index is: a fixed stop, a vote between two pool
-- stops, or the Terminal. Votes happen on the ride before the stop. No stop repeats
-- except Gas & Go. Past the plan, the bus loops into Tier 3 (overtime) until it ends.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Seed = require(Shared.Util.Seed)
local Net = require(Shared.Net)
local Log = require(Shared.Log)

local Registry = require(script.Parent.Parent:WaitForChild("Registry"))

local StopsConfig = Config.Stops

local RouteService = {}

export type Entry = {
	kind: string, -- "fixed" | "vote" | "terminal"
	tier: number,
	stop: string?,
	loopCheck: number?,
}

export type Next = {
	id: string,
	tier: number,
	loopCheck: number?,
	terminal: boolean,
	overtime: number,
}

RouteService.plan = {} :: { Entry }
RouteService.used = {} :: { [string]: boolean }
RouteService.gasVisits = 0
RouteService.overtime = 0
RouteService.rng = Seed.new(1)
RouteService.ballot = nil :: { string }?
RouteService.votes = {} :: { [Player]: number }
RouteService.next = nil :: Next?

local RunState: Folder
local Stops: any
local Driver: any

local function planFor(mode: string?): { Entry }
	if mode == "Tutorial" then
		return StopsConfig.TutorialPlan :: any
	end
	if Config.Tuning.Run.Plan == "Slice" then
		return StopsConfig.SlicePlan :: any
	elseif Config.Tuning.Run.Plan == "Core" then
		return StopsConfig.CorePlan :: any
	end
	return StopsConfig.Plan :: any
end

function RouteService.fragmentsNeeded(): number
	if Config.Tuning.Run.Plan == "Slice" then
		return Config.Tuning.Run.SliceFragmentsToWin
	elseif Config.Tuning.Run.Plan == "Core" then
		return Config.Tuning.Run.CoreFragmentsToWin
	end
	return Config.Tuning.Run.FragmentsToWin
end

function RouteService.build(seed: number, mode: string?)
	RouteService.plan = planFor(mode)
	RouteService.used = {}
	RouteService.gasVisits = 0
	RouteService.overtime = 0
	RouteService.rng = Seed.new(seed):child("route")
	RouteService.ballot = nil
	RouteService.next = nil
	table.clear(RouteService.votes)
	RunState:SetAttribute("FragmentsNeeded", RouteService.fragmentsNeeded())
	RunState:SetAttribute("Overtime", 0)
	RunState:SetAttribute("VoteOpen", false)
end

-- Pool stops for a tier that haven't been used. Built stops come first; if none are
-- built, any pool stop (the generic builder stands in).
local function options(tier: number): { string }
	local pool: { string } = StopsConfig.Pools[math.clamp(tier, 1, 3)] or {}
	local built, any = {}, {}
	for _, id in pool do
		if not RouteService.used[id] then
			table.insert(any, id)
			if Stops.hasBuilder(id) then
				table.insert(built, id)
			end
		end
	end
	if #built > 0 then
		return built
	end
	if #any == 0 then
		-- Every stop in the tier was used: overtime laps may repeat them.
		for _, id in pool do
			if Stops.hasBuilder(id) then
				table.insert(any, id)
			end
		end
		if #any == 0 then
			any = table.clone(pool)
		end
	end
	return any
end

-- The plan entry for a stop index (1-based), with overtime past the plan.
function RouteService.entry(index: number): Entry?
	local entry = RouteService.plan[index]
	if entry then
		return entry
	end
	if Config.Tuning.Run.Plan ~= "Full" or RunState:GetAttribute("Mode") == "Tutorial" then
		return nil
	end
	-- After stop 11: the Terminal with enough fragments, otherwise overtime.
	local fragments = (RunState:GetAttribute("Fragments") :: number?) or 0
	if fragments >= RouteService.fragmentsNeeded() then
		return { kind = "terminal", tier = 4, stop = "terminal" }
	end
	return { kind = "vote", tier = 3 }
end

-- Before the ride: work out the next stop, or open a vote for it.
function RouteService.prepare(index: number): Entry?
	local entry = RouteService.entry(index)
	RouteService.ballot = nil
	table.clear(RouteService.votes)
	if not entry then
		return nil
	end
	if index > #RouteService.plan and entry.kind == "vote" then
		local lap = math.floor((index - #RouteService.plan - 1) / Config.Tuning.Run.OvertimeStopsPerLap) + 1
		RouteService.overtime = lap
		RunState:SetAttribute("Overtime", lap)
	end
	if entry.kind == "vote" then
		local opts = RouteService.rng:shuffle(options(entry.tier))
		if #opts >= 2 then
			RouteService.ballot = { opts[1], opts[2] }
			RunState:SetAttribute("VoteA", opts[1])
			RunState:SetAttribute("VoteB", opts[2])
			RunState:SetAttribute("VoteIconA", StopsConfig.Stops[opts[1]].icon)
			RunState:SetAttribute("VoteIconB", StopsConfig.Stops[opts[2]].icon)
			RunState:SetAttribute("VoteCountA", 0)
			RunState:SetAttribute("VoteCountB", 0)
			RunState:SetAttribute("NextStopName", "Vote")
		else
			-- Only one option left: no vote.
			local id = opts[1] or "generic"
			RouteService.next = {
				id = id,
				tier = entry.tier,
				loopCheck = nil,
				terminal = false,
				overtime = RouteService.overtime,
			}
			RunState:SetAttribute("NextStopName", StopsConfig.Stops[id] and StopsConfig.Stops[id].name or id)
		end
	else
		local id = entry.stop or "generic"
		RouteService.next = {
			id = id,
			tier = entry.tier,
			loopCheck = entry.loopCheck,
			terminal = entry.kind == "terminal",
			overtime = RouteService.overtime,
		}
		RunState:SetAttribute("NextStopName", StopsConfig.Stops[id] and StopsConfig.Stops[id].name or id)
	end
	return entry
end

function RouteService.openVote(seconds: number)
	if not RouteService.ballot then
		return
	end
	RunState:SetAttribute("VoteDeadline", workspace:GetServerTimeNow() + seconds)
	RunState:SetAttribute("VoteOpen", true)
	Net.notifyAll("Hint", { id = "vote" })
end

function RouteService.vote(player: Player, option: number)
	if not RunState:GetAttribute("VoteOpen") or not RouteService.ballot then
		return
	end
	if option ~= 1 and option ~= 2 then
		return
	end
	if RouteService.votes[player] then
		return
	end
	RouteService.votes[player] = option
	local a, b = 0, 0
	for p, o in RouteService.votes do
		if p.Parent then
			if o == 1 then
				a += 1
			else
				b += 1
			end
		end
	end
	RunState:SetAttribute("VoteCountA", a)
	RunState:SetAttribute("VoteCountB", b)
	Net.notify(player, "Toast", { text = "Vote counted." })
end

-- Close the vote and fix the next stop. Patience at 50 or below makes the Driver pick
-- the worse option (the one fewer riders wanted).
function RouteService.closeVote(): Next?
	local entry = RouteService.entry((RunState:GetAttribute("StopIndex") :: number? or 0) + 1)
	if RouteService.ballot and entry then
		local a = (RunState:GetAttribute("VoteCountA") :: number?) or 0
		local b = (RunState:GetAttribute("VoteCountB") :: number?) or 0
		local pick: number
		if a == b then
			pick = RouteService.rng:int(1, 2)
		else
			pick = if a > b then 1 else 2
		end
		if Driver and Driver.overrideNextVote then
			Driver.overrideNextVote = false
			pick = if a == b then pick else (if pick == 1 then 2 else 1)
			Driver.say("The Driver has chosen.", "distorted")
		end
		local id = RouteService.ballot[pick]
		RouteService.next = {
			id = id,
			tier = entry.tier,
			loopCheck = nil,
			terminal = false,
			overtime = RouteService.overtime,
		}
		RunState:SetAttribute("NextStopName", StopsConfig.Stops[id].name)
		Log.info("Route", "Vote picked", id, a, b)
	end
	RouteService.ballot = nil
	RunState:SetAttribute("VoteOpen", false)
	return RouteService.next
end

-- The stop is being built: remember it.
function RouteService.commit(id: string)
	RouteService.used[id] = true
	if id == "gas_and_go" then
		RouteService.gasVisits += 1
	end
end

function RouteService:Init()
	RunState = Registry.get("WorldService").RunState
	Stops = Registry.get("StopService")
	Driver = Registry.find("DriverService")
end

function RouteService:Start()
	Players.PlayerRemoving:Connect(function(player)
		RouteService.votes[player] = nil
	end)
end

return RouteService
