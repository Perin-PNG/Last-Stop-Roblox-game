--!strict
-- The Rules plaque. Each run posts five Rules: the two fixed ones plus three from the
-- pool. From Tier 2 the plaque may carry one fake Rule on a sticker. The plaque is
-- reposted when the tier changes so a fake can appear later in the run.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Seed = require(Shared.Util.Seed)
local Log = require(Shared.Log)

local Registry = require(script.Parent.Parent:WaitForChild("Registry"))

local RulesConfig = Config.Rules

local RulesService = {}

RulesService.posted = {} :: { string }
RulesService.fake = nil :: string?

local RunState: Folder
local Cabin: any
local Bus: any

function RulesService.has(id: string): boolean
	return table.find(RulesService.posted, id) ~= nil
end

local function publish()
	RunState:SetAttribute("Rules", table.concat(RulesService.posted, ","))
	if Cabin then
		Cabin.refreshPlaque(RulesService.posted)
	end
end

-- Post a fresh plaque for a run.
function RulesService.post(seed: number, tier: number)
	local rng = Seed.new(seed):child("rules")
	local posted = table.clone(RulesConfig.Fixed)
	for _, id in rng:sample(RulesConfig.Pool, RulesConfig.PoolCount) do
		table.insert(posted, id)
	end
	RulesService.posted = posted
	RulesService.fake = nil
	RulesService.maybeAddFake(seed, tier)
	publish()
	Log.info("Rules", "Posted", table.concat(posted, ", "))
end

-- On entering a new tier, the plaque may gain one fake Rule (never more than one).
function RulesService.maybeAddFake(seed: number, tier: number)
	if RulesService.fake then
		return
	end
	local chance = RulesConfig.FakeChance[math.clamp(tier, 1, 3)] or 0
	local rng = Seed.new(seed):child("fake" .. tier)
	if rng:chance(chance) then
		local fake = rng:pick(RulesConfig.Fakes)
		RulesService.fake = fake
		table.insert(RulesService.posted, rng:int(3, #RulesService.posted + 1), fake)
		publish()
	end
end

function RulesService:Init()
	RunState = Registry.get("WorldService").RunState
	Cabin = Registry.find("CabinService")
	Bus = Registry.get("BusService")
end

function RulesService:Start()
	Bus.Spawned:Connect(function()
		task.defer(publish)
	end)
end

return RulesService
