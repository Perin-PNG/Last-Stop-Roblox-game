--!strict
-- Stop threats. Each stop has one local threat (Config.Stops.<id>.threat) with a behavior
-- from Config.Entities. M1 has the Hunter (the Gas & Go Clerk); the Dryer's Ambusher lives
-- in the laundromat builder because it is the dryers themselves.
--
-- Entities are server-moved anchored rigs: PathfindingService plans, the Heartbeat steps
-- the root along the waypoints. They never enter the bus.
--
-- Hunter: telegraphs, then patrols. It sees players in a cone with line of sight and hears
-- noise events; it chases what it sees, investigates what it hears, and downs on contact.
-- Flares stun it.

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Build = require(Shared.Util.Build)
local Net = require(Shared.Net)
local Log = require(Shared.Log)

local Registry = require(script.Parent.Parent:WaitForChild("Registry"))

local Tuning = Config.Tuning.Entities

local EntityService = {}

export type Entity = {
	id: string,
	def: any,
	built: any,
	model: Model,
	root: BasePart,
	state: string, -- Dormant | Telegraph | Patrol | Investigate | Chase | Stunned | Recover
	target: Player?,
	lastSeen: number,
	goal: Vector3?,
	waypoints: { Vector3 },
	wp: number,
	pathBusy: boolean,
	nextPath: number,
	stunUntil: number,
	recoverUntil: number,
	speed: number,
	hipHeight: number,
	active: boolean,
}

local entities: { Entity } = {}
local dormant: { [any]: { [string]: boolean } } = {} -- built -> threat ids ready to wake

local PlayerState: any
local Bus: any
local Noise: any
local World: any

local function now(): number
	return workspace:GetServerTimeNow()
end

local function buildRig(def: any, at: CFrame): (Model, BasePart, number)
	local h = def.height or 1
	local model = Build.model(World.Folders.Entities, def.name)
	model:SetAttribute("Entity", def.id)
	local root = Build.part(model, {
		name = "Root",
		size = Vector3.new(2, 2, 1) * h,
		cf = at,
		transparency = 1,
		collide = false,
		query = false,
		group = "Entities",
	})
	model.PrimaryPart = root
	local skin = Color3.fromRGB(210, 200, 186)
	local function limb(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?)
		local p = Build.part(model, {
			name = name,
			size = size * h,
			cf = at * CFrame.new(offset.Position * h) * offset.Rotation,
			color = color,
			material = material or Enum.Material.Fabric,
			anchored = false,
			collide = false,
			query = true,
			group = "Entities",
		})
		p.Massless = true
		Build.weld(root, p)
		return p
	end
	local body = def.color or Color3.fromRGB(40, 40, 44)
	-- Proportions are a little wrong: long arms, a narrow chest, the head tipped.
	for _, side in { -0.5, 0.5 } do
		limb("Leg", Vector3.new(0.8, 3.2, 0.8), CFrame.new(side, -1.6, 0), Color3.fromRGB(30, 30, 34))
		limb("Arm", Vector3.new(0.6, 3.6, 0.6), CFrame.new(side * 3.2, 0.3, 0) * CFrame.Angles(0, 0, side * 0.08), body)
		limb("Hand", Vector3.new(0.5, 0.9, 0.5), CFrame.new(side * 3.35, -1.85, 0), skin, Enum.Material.SmoothPlastic)
	end
	limb("Torso", Vector3.new(1.9, 2.8, 1), CFrame.new(0, 1.4, 0), body)
	limb("Neck", Vector3.new(0.5, 0.7, 0.5), CFrame.new(0, 3.1, 0), skin, Enum.Material.SmoothPlastic)
	local head = limb(
		"Head",
		Vector3.new(1.3, 1.6, 1.3),
		CFrame.new(0.15, 4.05, 0) * CFrame.Angles(0, 0, math.rad(-18)),
		skin,
		Enum.Material.SmoothPlastic
	)
	if def.faceless or def.id == "clerk" then
		local shade = limb(
			"Shade",
			Vector3.new(1.32, 0.7, 0.2),
			CFrame.new(0.2, 4.1, -0.6) * CFrame.Angles(0, 0, math.rad(-18)),
			Color3.fromRGB(10, 10, 12),
			Enum.Material.SmoothPlastic
		)
		local _ = shade
	end
	if def.id == "clerk" then
		limb("Apron", Vector3.new(1.7, 2.6, 0.1), CFrame.new(0, 0.9, -0.56), Color3.fromRGB(36, 36, 36))
		limb("Cap", Vector3.new(1.4, 0.4, 1.6), CFrame.new(0.3, 4.95, -0.1) * CFrame.Angles(0, 0, math.rad(-18)), body)
	end
	local _ = head
	return model, root, 3.2 * h + 1 * h
end

local function groundAt(pos: Vector3, ignore: { Instance }): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(pos + Vector3.new(0, 6, 0), Vector3.new(0, -30, 0), params)
	return hit and hit.Position
end

local function visible(e: Entity, player: Player): boolean
	local root = PlayerState.rootOf(player)
	if not root then
		return false
	end
	local eye = e.root.Position + Vector3.new(0, 2.5, 0)
	local offset = root.Position - eye
	local dist = offset.Magnitude
	local sight = e.def.sight or Tuning.SightRange
	if dist > sight then
		return false
	end
	-- Close enough to feel: always noticed.
	if dist > 6 then
		local cone = math.rad((e.def.cone or Tuning.SightConeDegrees) / 2)
		local facing = e.root.CFrame.LookVector
		if facing:Dot(offset.Unit) < math.cos(cone) then
			return false
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { e.model, player.Character :: any }
	local hit = workspace:Raycast(eye, offset, params)
	return hit == nil
end

local function huntable(player: Player): boolean
	return PlayerState.isHealthy(player) and not Bus.isAboard(player)
end

local function nearestSeen(e: Entity): Player?
	local best: Player? = nil
	local bestDist = math.huge
	for _, player in Players:GetPlayers() do
		if huntable(player) and visible(e, player) then
			local root = PlayerState.rootOf(player)
			local d = root and (root.Position - e.root.Position).Magnitude or math.huge
			if d < bestDist then
				best, bestDist = player, d
			end
		end
	end
	return best
end

local function speedFor(e: Entity, state: string): number
	local tier = math.clamp(e.built.tier or 1, 1, 3)
	local mult = Tuning.TierSpeedMultiplier[tier]
	if #PlayerState.living() <= 1 then
		mult *= Tuning.SoloSpeedMultiplier
	end
	if state == "Chase" then
		return Tuning.HunterChaseSpeed[tier] * mult
	elseif state == "Investigate" then
		return Tuning.InvestigateSpeed * mult
	end
	return (e.def.patrolSpeed or Tuning.PatrolSpeed) * mult
end

local function plan(e: Entity, goal: Vector3)
	if e.pathBusy then
		return
	end
	e.pathBusy = true
	e.goal = goal
	task.spawn(function()
		local path = PathfindingService:CreatePath({
			AgentRadius = 1.6,
			AgentHeight = 7,
			AgentCanJump = false,
			WaypointSpacing = 4,
		})
		local start = e.root.Position - Vector3.new(0, e.hipHeight, 0)
		local ok = pcall(function()
			path:ComputeAsync(start, goal)
		end)
		local points: { Vector3 } = {}
		if ok and path.Status == Enum.PathStatus.Success then
			for _, w in path:GetWaypoints() do
				table.insert(points, w.Position)
			end
			table.remove(points, 1)
		else
			-- No path: walk straight at it; walls stop us, which is fine.
			table.insert(points, goal)
		end
		e.waypoints = points
		e.wp = 1
		e.pathBusy = false
	end)
end

local function randomPatrolPoint(e: Entity): Vector3
	local refs = e.built.refs
	local frame: CFrame = refs.frame
	local local_ = Vector3.new(math.random(20, 90), 0, math.random(-50, 50))
	return frame * local_
end

local function catchCheck(e: Entity): boolean
	for _, player in Players:GetPlayers() do
		if huntable(player) then
			local root = PlayerState.rootOf(player)
			local flat = root
				and Vector3.new(root.Position.X - e.root.Position.X, 0, root.Position.Z - e.root.Position.Z)
			if
				root
				and flat
				and flat.Magnitude <= Config.Tuning.Player.CatchRange + 1
				and math.abs(root.Position.Y - e.root.Position.Y) < 6
			then
				PlayerState.down(player, e.id)
				Net.notifyAll("Sound", { key = "Caught", part = e.root })
				e.state = "Recover"
				e.recoverUntil = now() + Tuning.RecoverSeconds
				e.target = nil
				e.waypoints = {}
				return true
			end
		end
	end
	return false
end

local function think(e: Entity)
	local t = now()
	if e.state == "Stunned" then
		if t >= e.stunUntil then
			e.state = "Patrol"
		end
		return
	end
	if e.state == "Recover" then
		if t >= e.recoverUntil then
			e.state = "Patrol"
		end
		return
	end
	if e.state == "Telegraph" or e.state == "Dormant" then
		return
	end
	local seen = nearestSeen(e)
	if seen then
		if e.state ~= "Chase" then
			Net.notifyAll("Sound", { key = "EntitySpotted", part = e.root })
		end
		e.state = "Chase"
		e.target = seen
		e.lastSeen = t
	elseif e.state == "Chase" and t - e.lastSeen > Tuning.LoseTargetSeconds then
		e.state = "Investigate"
		local root = e.target and PlayerState.rootOf(e.target)
		e.goal = root and root.Position or e.goal
		e.target = nil
	end
	if e.state ~= "Chase" and Noise then
		local heard = Noise.loudestHeard(e.root.Position, e.def.hearing or 1, t - 1.5)
		if heard then
			e.state = "Investigate"
			if not e.goal or (e.goal - heard.position).Magnitude > 6 then
				plan(e, heard.position)
			end
		end
	end
	if e.state == "Chase" and e.target then
		if not huntable(e.target) then
			e.target = nil
			e.state = "Patrol"
			return
		end
		local root = PlayerState.rootOf(e.target)
		if root and t >= e.nextPath then
			e.nextPath = t + Tuning.RepathSeconds
			plan(e, root.Position)
		end
	elseif e.state == "Investigate" then
		if #e.waypoints == 0 or e.wp > #e.waypoints then
			e.state = "Patrol"
		end
	elseif e.state == "Patrol" then
		if (#e.waypoints == 0 or e.wp > #e.waypoints) and not e.pathBusy then
			plan(e, randomPatrolPoint(e))
		end
	end
end

local function step(e: Entity, dt: number)
	if e.state == "Stunned" or e.state == "Recover" or e.state == "Telegraph" or e.state == "Dormant" then
		return
	end
	local target = e.waypoints[e.wp]
	if e.state == "Chase" and e.target and e.wp >= #e.waypoints then
		local root = PlayerState.rootOf(e.target)
		if root then
			target = root.Position
		end
	end
	if not target then
		return
	end
	local pos = e.root.Position
	local feet = pos - Vector3.new(0, e.hipHeight, 0)
	local flat = Vector3.new(target.X - feet.X, 0, target.Z - feet.Z)
	local dist = flat.Magnitude
	if dist < 0.8 then
		e.wp += 1
		return
	end
	local speed = speedFor(e, e.state)
	local move = flat.Unit * math.min(dist, speed * dt)
	local nextFeet = feet + move
	-- Never step into the bus.
	if Bus.isInside(nextFeet + Vector3.new(0, 3, 0)) then
		e.waypoints = {}
		if e.state == "Chase" then
			e.state = "Investigate"
			e.target = nil
		end
		return
	end
	local ground = groundAt(nextFeet, { e.model, World.Folders.Entities })
	local y = if ground then ground.Y else nextFeet.Y
	if math.abs(y - feet.Y) > 4 then
		y = feet.Y
	end
	local newPos = Vector3.new(nextFeet.X, y + e.hipHeight, nextFeet.Z)
	e.root.CFrame = CFrame.lookAt(newPos, newPos + Vector3.new(move.X, 0, move.Z))
	catchCheck(e)
end

local function spawnEntity(built: any, threatId: string, at: CFrame?): Entity?
	local def = Config.Entities[threatId]
	if not def then
		return nil
	end
	local spawn: CFrame = at
		or (built.refs.entitySpawns[1] and built.refs.entitySpawns[1].CFrame)
		or built.refs.frame * CFrame.new(60, 4, 0)
	local model, root, hip = buildRig(def, spawn)
	local e: Entity = {
		id = threatId,
		def = def,
		built = built,
		model = model,
		root = root,
		state = "Telegraph",
		target = nil,
		lastSeen = 0,
		goal = nil,
		waypoints = {},
		wp = 1,
		pathBusy = false,
		nextPath = 0,
		stunUntil = 0,
		recoverUntil = 0,
		speed = 0,
		hipHeight = hip,
		active = true,
	}
	root.CFrame = CFrame.new(spawn.Position) * spawn.Rotation
	local ground = groundAt(spawn.Position, { model })
	if ground then
		root.CFrame = CFrame.new(ground + Vector3.new(0, hip, 0)) * spawn.Rotation
	end
	table.insert(entities, e)
	return e
end

-- A stop was built: note its threat. Hunters wake on activate().
function EntityService.setupStop(built: any)
	local def = Config.Stops.Stops[built.id]
	if not def or not def.threat then
		return
	end
	dormant[built] = { [def.threat] = true }
end

-- Wake a stop's threat (the Clerk after a wrong call at a changed Gas & Go).
function EntityService.activate(built: any, threatId: string)
	local ready = dormant[built]
	if not ready or not ready[threatId] then
		return
	end
	ready[threatId] = nil
	local def = Config.Entities[threatId]
	if not def or def.behavior ~= "Hunter" then
		return
	end
	-- The clerk behind the counter is gone.
	local static = built.refs.extras.clerk
	local at: CFrame? = nil
	if static and static:IsA("Model") then
		at = static:GetPivot() * CFrame.new(0, 3.5, 0)
		static:Destroy()
		built.refs.extras.clerk = nil
	end
	local e = spawnEntity(built, threatId, at)
	if not e then
		return
	end
	Net.notifyAll("Sound", { key = def.telegraphSound or "DoorChime", part = e.root })
	Net.notifyAll("Toast", { text = def.telegraph })
	task.delay(Tuning.TelegraphSeconds, function()
		if e.active and e.state == "Telegraph" then
			e.state = "Patrol"
		end
	end)
	Log.info("Entity", "Woke", threatId, "at", built.id)
end

function EntityService.spawnDebug(built: any, threatId: string): boolean
	local e = spawnEntity(built, threatId, nil)
	if e then
		e.state = "Patrol"
		return true
	end
	return false
end

-- Flares: stun every entity (and the Latecomer, via its own service) near a point.
function EntityService.stunNear(pos: Vector3, radius: number, seconds: number)
	for _, e in entities do
		if e.active and (e.root.Position - pos).Magnitude <= radius and e.def.flareStuns ~= false then
			e.state = "Stunned"
			e.stunUntil = now() + seconds
			e.waypoints = {}
			e.target = nil
			Net.notifyAll("Sound", { key = "EntityStunned", part = e.root })
		end
	end
end

local function remove(e: Entity)
	e.active = false
	e.model:Destroy()
end

function EntityService.clearStop(built: any)
	dormant[built] = nil
	local keep = {}
	for _, e in entities do
		if e.built == built then
			remove(e)
		else
			table.insert(keep, e)
		end
	end
	entities = keep
end

function EntityService.clearAll()
	for _, e in entities do
		remove(e)
	end
	table.clear(entities)
	table.clear(dormant)
end

function EntityService.list(): { Entity }
	return entities
end

function EntityService:Init()
	PlayerState = Registry.get("PlayerStateService")
	Bus = Registry.get("BusService")
	Noise = Registry.find("NoiseService")
	World = Registry.get("WorldService")
end

function EntityService:Start()
	local thinkAcc = 0
	RunService.Heartbeat:Connect(function(dt)
		thinkAcc += dt
		local doThink = thinkAcc >= 0.2
		if doThink then
			thinkAcc = 0
		end
		for _, e in entities do
			if e.active then
				if doThink then
					think(e)
				end
				step(e, dt)
			end
		end
	end)
	local debug = Registry.find("DebugService")
	local director = Registry.find("RunDirector")
	if debug and director then
		debug.register("entity", function(player: Player, id: any)
			local built = director.current
			local threat = if type(id) == "string" then id else "clerk"
			if built then
				local ok = EntityService.spawnDebug(built, threat)
				Net.notify(player, "Toast", { text = if ok then "Spawned " .. threat else "No such entity" })
			end
		end)
	end
end

return EntityService
