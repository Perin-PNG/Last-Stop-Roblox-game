--!strict
-- Anomalies: something at a stop that is wrong. Each one swaps, hides, turns, relabels,
-- lights or sounds an anomaly slot the stop builder tagged (see Config.Anomalies).
--
-- Gas & Go is special: the first visit is the baseline and has none. On loop-check visits
-- there is a 50% (then 60%) chance that exactly one thing changed. Every other stop rolls
-- its count from the tier, with a share of Hazards and Lures.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Seed = require(Shared.Util.Seed)
local Net = require(Shared.Net)
local Log = require(Shared.Log)

local Builders = script.Parent.Parent:WaitForChild("Builders")
local StopKit = require(Builders:WaitForChild("StopKit"))
local Registry = require(script.Parent.Parent:WaitForChild("Registry"))

local Defs = Config.Anomalies

type AnomalyDef = typeof(Config.Anomalies.List[1])

local AnomalyService = {}

type Active = {
	built: any,
	def: AnomalyDef,
	target: Instance,
	token: number,
}

local active: { Active } = {}
local token = 0
local seed = 0

local function variantsOf(model: Instance, id: string): { Instance }
	local out = {}
	for _, d in model:GetDescendants() do
		if d:GetAttribute("AnomalyVariant") == id then
			table.insert(out, d)
		end
	end
	return out
end

local function labelsIn(inst: Instance): { TextLabel }
	local out = {}
	if inst:IsA("TextLabel") then
		table.insert(out, inst)
	end
	for _, d in inst:GetDescendants() do
		if d:IsA("TextLabel") then
			table.insert(out, d)
		end
	end
	return out
end

local function lightsIn(inst: Instance): { Light }
	local out = {}
	for _, d in inst:GetDescendants() do
		if d:IsA("Light") then
			table.insert(out, d)
		end
	end
	return out
end

local function neonIn(inst: Instance): { BasePart }
	local out = {}
	local list = inst:GetDescendants()
	table.insert(list, inst)
	for _, d in list do
		if d:IsA("BasePart") and d.Material == Enum.Material.Neon then
			table.insert(out, d)
		end
	end
	return out
end

local function pivotOf(inst: Instance): CFrame?
	if inst:IsA("BasePart") then
		return inst.CFrame
	elseif inst:IsA("Model") then
		return inst:GetPivot()
	end
	return nil
end

local function setPivot(inst: Instance, cf: CFrame)
	if inst:IsA("BasePart") then
		inst.CFrame = cf
	elseif inst:IsA("Model") then
		inst:PivotTo(cf)
	end
end

local function positionOf(inst: Instance): Vector3?
	local cf = pivotOf(inst)
	return cf and cf.Position
end

local function setLights(inst: Instance, on: boolean)
	for _, light in lightsIn(inst) do
		light.Enabled = on
	end
	for _, part in neonIn(inst) do
		if part:GetAttribute("LitColor") == nil then
			part:SetAttribute("LitColor", part.Color)
		end
		part.Color = if on then part:GetAttribute("LitColor") :: Color3 else Color3.fromRGB(30, 30, 32)
	end
end

local function running(a: Active): boolean
	return a.token == token and a.built.active ~= false
end

-- Apply one anomaly to a built stop. Returns false if the stop has no slot for it.
local function applyOne(built: any, def: AnomalyDef): boolean
	local refs = built.refs
	local target = refs.slots[def.slot]
	if not target and def.op ~= "custom" then
		return false
	end
	local a: Active = { built = built, def = def, target = target or refs.model, token = token }
	local params: { [string]: any } = def.params or {}
	local op = def.op
	if op == "variant" then
		local variants = variantsOf(refs.model, def.id)
		if #variants == 0 then
			return false
		end
		for _, v in variants do
			StopKit.setShown(v, true)
		end
	elseif op == "swap" then
		local variants = variantsOf(refs.model, def.id)
		StopKit.setShown(target, false)
		for _, v in variants do
			StopKit.setShown(v, true)
		end
	elseif op == "rotate" then
		local cf = pivotOf(target)
		if not cf then
			return false
		end
		setPivot(target, cf * CFrame.Angles(0, math.rad(params.degrees or 180), 0))
	elseif op == "text" then
		local labels = labelsIn(target)
		if #labels == 0 then
			return false
		end
		for _, label in labels do
			label.Text = params.text or "?"
		end
	elseif op == "names" then
		local names = {}
		for _, player in Players:GetPlayers() do
			table.insert(names, string.upper(player.DisplayName))
		end
		local format = if type(params.format) == "string" then params.format else "%s"
		for i, label in labelsIn(target) do
			label.Text = string.format(format, names[((i - 1) % math.max(1, #names)) + 1] or "UNIT 9")
		end
	elseif op == "lightOn" then
		setLights(target, true)
	elseif op == "lightOff" then
		setLights(target, false)
	elseif op == "lightBlink" then
		task.spawn(function()
			local on = true
			while running(a) do
				on = not on
				setLights(target, on)
				task.wait(if on then 0.08 + math.random() * 0.3 else 0.05 + math.random() * 0.15)
			end
		end)
	elseif op == "spin" then
		local base = pivotOf(target)
		if not base then
			return false
		end
		task.spawn(function()
			local angle = 0
			while running(a) do
				angle += (params.speed or 1) * 0.1
				setPivot(target, base * CFrame.Angles(angle, 0, 0))
				task.wait(0.1)
			end
		end)
	elseif op == "counter" then
		local labels = labelsIn(target)
		task.spawn(function()
			local n = 0
			while running(a) do
				n += 0.07
				for _, label in labels do
					label.Text = string.format("%.2f", n)
				end
				task.wait(0.1)
			end
		end)
	elseif op == "breathe" then
		local base = pivotOf(target)
		if not base then
			return false
		end
		task.spawn(function()
			local t = 0
			while running(a) do
				t += 0.1
				setPivot(target, base * CFrame.new(0, math.max(0, math.sin(t * 1.6)) * 0.5, 0))
				task.wait(0.1)
			end
		end)
	elseif op == "custom" then
		local custom = refs.extras.custom and refs.extras.custom[def.id]
		if not custom then
			return false
		end
		local ok, err = pcall(custom, built)
		if not ok then
			Log.warn("Anomaly", "custom failed", def.id, err)
			return false
		end
	elseif op == "bus" then
		return false
	end
	-- "sound": nothing moves; clients play the sound at the slot and caption it.
	if params.sound and target then
		local part = if target:IsA("BasePart") then target else (target:FindFirstChildWhichIsA("BasePart", true))
		if part then
			target:SetAttribute("AnomalySound", params.sound)
			Net.notifyAll("Sound", { key = params.sound, part = part, loop = true })
		end
	end
	if target then
		target:SetAttribute("Anomaly", def.id)
		target:SetAttribute("AnomalySeverity", def.severity)
	end
	table.insert(active, a)
	built.anomalies = built.anomalies or {}
	table.insert(built.anomalies, def.id)
	refs.model:SetAttribute("Anomalies", table.concat(built.anomalies, ","))
	return true
end

local function candidates(stopId: string, tier: number): { AnomalyDef }
	local out = {}
	local list: { AnomalyDef } = Defs.ByStop[stopId] or {}
	for _, def in list do
		local minTier = def.minTier or (if def.severity == "Lure" then 2 else 1)
		if tier >= minTier then
			table.insert(out, def)
		end
	end
	return out
end

-- Roll and apply a stop's anomalies.
function AnomalyService.apply(built: any, gasVisits: number)
	built.anomalies = {}
	local rng = Seed.new(seed):child("anomaly" .. built.index .. built.id)
	local pool = candidates(built.id, built.tier)
	if #pool == 0 then
		return
	end
	if built.id == "gas_and_go" then
		built.loopAnomalous = false
		if not built.loopCheck then
			return -- the baseline visit
		end
		-- First Ride: one obvious change, the clerk facing the wall.
		local director = Registry.find("RunDirector")
		if director and director.mode == "Tutorial" then
			local def = Defs.ById.clerk_facing_wall
			if def and applyOne(built, def) then
				built.loopAnomalous = true
			end
			return
		end
		local chance = Config.Stops.LoopCheckAnomalyChance[math.clamp(built.loopCheck, 1, 2)]
		if rng:chance(chance) then
			for _, def in rng:shuffle(pool) do
				if applyOne(built, def) then
					built.loopAnomalous = true
					break
				end
			end
		end
		Log.info("Anomaly", "Loop check", built.loopCheck, "visit", gasVisits, "changed:", built.loopAnomalous)
		return
	end
	local tier = math.clamp(built.tier, 1, 3)
	local range = Defs.PerStop[tier]
	local want = rng:int(range[1], range[2])
	local overtime = (built.overtime or 0) :: number
	want += overtime * Defs.OvertimeExtraPerLap
	local danger, calm = {}, {}
	for _, def in pool do
		if def.severity == "Hazard" or def.severity == "Lure" then
			table.insert(danger, def)
		else
			table.insert(calm, def)
		end
	end
	danger = rng:shuffle(danger)
	calm = rng:shuffle(calm)
	local usedSlots: { [string]: boolean } = {}
	local placed = 0
	local guard = 0
	while placed < want and guard < 40 do
		guard += 1
		local list = if rng:chance(Defs.DangerShare[tier]) and #danger > 0 then danger else calm
		if #list == 0 then
			list = danger
		end
		local def = table.remove(list, 1)
		if not def then
			break
		end
		if not usedSlots[def.slot] and applyOne(built, def) then
			usedSlots[def.slot] = true
			placed += 1
		end
	end
	Log.info("Anomaly", built.id, "has", table.concat(built.anomalies, ", "))
end

-- Did this Gas & Go visit change?
function AnomalyService.loopAnomalous(built: any): boolean
	return built.loopAnomalous == true
end

-- Force one more anomaly on the current stop (debug).
function AnomalyService.force(built: any, id: string?): string?
	local pool = candidates(built.id, 3)
	for _, def in pool do
		if (id == nil or def.id == id) and not table.find(built.anomalies or {}, def.id) then
			if applyOne(built, def) then
				if built.id == "gas_and_go" then
					built.loopAnomalous = true
				end
				return def.id
			end
		end
	end
	return nil
end

function AnomalyService.clearStop(built: any)
	local keep = {}
	for _, a in active do
		if a.built ~= built then
			table.insert(keep, a)
		end
	end
	active = keep
end

function AnomalyService.reset(newSeed: number)
	token += 1
	seed = newSeed
	table.clear(active)
end

local PlayerState: any

-- Hazards down whoever comes within their radius.
local function hazardTick()
	for _, a in active do
		local radius = a.def.hazardRadius
		if a.def.severity == "Hazard" and radius and a.built.active ~= false then
			local pos = positionOf(a.target)
			if pos then
				for _, player in Players:GetPlayers() do
					local root = PlayerState.rootOf(player)
					if root and PlayerState.isHealthy(player) and (root.Position - pos).Magnitude <= radius then
						PlayerState.down(player, a.def.id)
					end
				end
			end
		end
	end
end

function AnomalyService:Init()
	PlayerState = Registry.get("PlayerStateService")
end

function AnomalyService:Start()
	local director = Registry.find("RunDirector")
	if director then
		director.RunStarted:Connect(function()
			AnomalyService.reset(director.seed)
		end)
		director.StopClosed:Connect(function(built: any)
			AnomalyService.clearStop(built)
		end)
	end
	task.spawn(function()
		while true do
			task.wait(0.25)
			hazardTick()
		end
	end)
	local debug = Registry.find("DebugService")
	if debug and director then
		debug.register("anomaly", function(player: Player, id: any)
			local built = director.current
			if not built then
				return
			end
			local placed = AnomalyService.force(built, if type(id) == "string" then id else nil)
			Net.notify(player, "Toast", { text = "Anomaly: " .. tostring(placed or "none left") })
		end)
	end
end

return AnomalyService
