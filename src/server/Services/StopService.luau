--!strict
-- Builds stop prefabs at the curb point a stop chunk gives it and tears them down once
-- nobody is left there. A stop builder lives in Builders/Stops/<id>.luau and returns
-- StopRefs; a stop with no builder gets the generic one. A model in
-- ServerStorage.Assets.Stops.<id> is used instead when present (art pass).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Seed = require(Shared.Util.Seed)
local Log = require(Shared.Log)

local Builders = script.Parent.Parent:WaitForChild("Builders")
local StopKit = require(Builders:WaitForChild("StopKit"))
local StopBuilders = Builders:WaitForChild("Stops")
local Registry = require(script.Parent.Parent:WaitForChild("Registry"))

local StopService = {}

export type BuiltStop = {
	id: string,
	refs: StopKit.StopRefs,
	index: number,
	tier: number,
	loopCheck: number?,
	chunk: any?,
	builtAt: number,
	active: boolean,
}

StopService.current = nil :: BuiltStop?
StopService.stops = {} :: { BuiltStop }

local World: any

local function curbFrameFromRoad(road: CFrame): CFrame
	-- The road builder's curb sits at +20 from the centreline.
	return road * CFrame.new(20, 0, 0)
end

StopService.curbFrameFromRoad = curbFrameFromRoad

local function builderFor(id: string): any
	local module = StopBuilders:FindFirstChild(id)
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok then
			return result
		end
		Log.warn("Stops", "Builder failed to load", id, result)
	end
	return require(StopBuilders:WaitForChild("generic"))
end

function StopService.hasBuilder(id: string): boolean
	local module = StopBuilders:FindFirstChild(id)
	return module ~= nil and module:IsA("ModuleScript")
end

-- Build the stop `id` with its curb at the road frame `road`.
function StopService.build(
	id: string,
	road: CFrame,
	index: number,
	tier: number,
	seed: number,
	loopCheck: number?
): BuiltStop
	local def = Config.Stops.Stops[id]
	local title = if def then def.name else id
	local frame = curbFrameFromRoad(road)
	local ctx: StopKit.Ctx = {
		rng = Seed.new(seed):child("stop" .. index .. id),
		tier = tier,
		loopCheck = loopCheck,
		stopIndex = index,
		id = id,
	}
	local refs: StopKit.StopRefs
	local assets = ServerStorage:FindFirstChild("Assets")
	local stopAssets = assets and assets:FindFirstChild("Stops")
	local custom = stopAssets and stopAssets:FindFirstChild(id)
	local builder = builderFor(id)
	local ok, result = pcall(builder, World.Folders.Stops, frame, ctx, title)
	if ok then
		refs = result
	else
		Log.warn("Stops", "Builder error for", id, result)
		refs = require(StopBuilders:WaitForChild("generic"))(World.Folders.Stops, frame, ctx, title)
	end
	if custom and custom:IsA("Model") then
		-- Art model: placed by its PrimaryPart at the curb point, on top of the blockout.
		local art = custom:Clone()
		art:PivotTo(frame)
		art.Parent = refs.model
	end
	refs.model:SetAttribute("StopIndex", index)
	local built: BuiltStop = {
		id = id,
		refs = refs,
		index = index,
		tier = tier,
		loopCheck = loopCheck,
		chunk = nil,
		builtAt = os.clock(),
		active = true,
	}
	table.insert(StopService.stops, built)
	StopService.current = built
	Log.info("Stops", "Built", id, "as stop", index)
	return built
end

local function anyoneNear(stop: BuiltStop): boolean
	local centre = stop.refs.frame * Vector3.new(60, 0, 0)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - centre).Magnitude < 400 then
			return true
		end
	end
	return false
end

-- Destroy every old stop that nobody is standing near (never the current one).
function StopService.cleanup()
	local keep = {}
	for _, stop in StopService.stops do
		if stop ~= StopService.current and not stop.active and not anyoneNear(stop) then
			stop.refs.model:Destroy()
			if stop.chunk then
				Registry.get("ChunkService").unpin(stop.chunk)
			end
		else
			table.insert(keep, stop)
		end
	end
	StopService.stops = keep
end

-- Put loot out at a stop. Loot points come from the stop's range, one more for each
-- player past two. Gas & Go always has fuel and a battery; a stalled bus always finds at
-- least one fuel can. Fragment sites each hold a route fragment.
function StopService.stock(stop: BuiltStop, players: number, stalled: boolean?)
	local def = Config.Stops.Stops[stop.id]
	if not def then
		return
	end
	local Inventory = Registry.find("InventoryService")
	if not Inventory then
		return
	end
	local rng = Seed.new(stop.index * 7919 + #stop.id):child("loot" .. stop.id)
	local points = rng:shuffle(table.clone(stop.refs.lootPoints))
	local want = rng:int(def.lootPoints[1], def.lootPoints[2]) + math.max(0, players - 2)
	want = math.min(want, #points)
	local table_ = Config.Items.LootTables[def.loot] or {}
	local forced: { string } = {}
	if stop.id == "gas_and_go" then
		table.insert(forced, "fuel")
		table.insert(forced, "battery")
	end
	if stalled then
		for _ = 1, Config.Tuning.Stop.StalledMinCans do
			table.insert(forced, "fuel")
		end
	end
	local folder: Instance? = stop.refs.model:FindFirstChild("Loot")
	if not folder then
		local f = Instance.new("Folder")
		f.Name = "Loot"
		f.Parent = stop.refs.model
		folder = f
	end
	for i = 1, want do
		local point = points[i]
		local id = forced[i]
		local tag = point:GetAttribute("Loot")
		if not id and type(tag) == "string" and tag ~= "" then
			id = tag
		end
		if not id and next(table_) then
			id = rng:weighted(table_)
		end
		if id then
			local amount = if id == "transfers" then rng:int(1, 3) else nil
			Inventory.spawnItem(id, point.CFrame, folder, amount)
		end
	end
	for _, site in stop.refs.fragmentSites do
		Inventory.spawnItem("fragment", site.CFrame, folder)
	end
end

function StopService.deactivate(stop: BuiltStop)
	stop.active = false
end

function StopService.clearAll()
	for _, stop in StopService.stops do
		stop.refs.model:Destroy()
	end
	table.clear(StopService.stops)
	StopService.current = nil
end

function StopService:Init()
	World = Registry.get("WorldService")
end

function StopService:Start()
	task.spawn(function()
		while true do
			task.wait(5)
			StopService.cleanup()
		end
	end)
end

return StopService
