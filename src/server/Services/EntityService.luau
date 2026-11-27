--!strict
-- Stop threats. Each stop has one local threat (Config.Stops.<id>.threat) running one of
-- the shared behaviors from Config.Entities on one server-side state machine:
--
--   Hunter     sees in a cone and hears noise; patrols, investigates, chases.
--   Listener   noise only; walks to the loudest recent noise, fast when it's loud.
--   Watcher    moves only while nobody is looking at it (a flickering light counts as
--              looking away). Usually a group (mannequins, scarecrows).
--   Sentry     stands at its post with a fixed cone; after seeing someone for two seconds
--              it hunts, then goes back to its post. Lit buildings marked Shelter are safe.
--   Headlights a car that patrols a lot along a route and runs down whoever its beams
--              catch. It can't leave the lot bounds and it ignores flares.
--
-- Ambushers (the Dryer, the Guest in Room 6) live in their stop builders because they are
-- the stop's own objects.
--
-- States: Dormant, Telegraph, Patrol, Investigate, Chase, Recover, Stunned, plus Frozen
-- (Watcher), Watching and Return (Sentry). Every threat telegraphs for at least two
-- seconds before it can touch anyone, and contact downs, it never kills.
--
-- Entities are server-moved anchored rigs: PathfindingService plans, the Heartbeat steps
-- the root along the waypoints. They never enter the bus.

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
local GazeTuning = Config.Tuning.Gaze

local EntityService = {}

export type Entity = {
	id: string,
	def: any,
	behavior: string,
	built: any,
	model: Model,
	root: BasePart,
	state: string,
	target: Player?,
	lastSeen: number,
	goal: Vector3?,
	waypoints: { Vector3 },
	wp: number,
	pathBusy: boolean,
	nextPath: number,
	stunUntil: number,
	recoverUntil: number,
	alertUntil: number,
	hipHeight: number,
	active: boolean,
	home: CFrame,
	spotFor: number,
	lastCreak: number,
	observed: boolean,
	nextObserve: number,
	route: { Vector3 },
	routeIndex: number,
}

local entities: { Entity } = {}
local dormant: { [any]: { [string]: boolean } } = {} -- built -> threat ids ready to wake

-- Behaviors that wake by themselves a little after the doors open.
local WAKES: { [string]: boolean } = {
	Hunter = true,
	Listener = true,
	Watcher = true,
	Sentry = true,
	Headlights = true,
}

local PlayerState: any
local Bus: any
local Noise: any
local World: any
local Gaze: any

local function now(): number
	return workspace:GetServerTimeNow()
end

-- Rigs ------------------------------------------------------------------------------------

type Limb = (name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?) -> Part

local function rigBase(def: any, at: CFrame, rootSize: Vector3): (Model, BasePart, Limb)
	local h = def.height or 1
	local model = Build.model(World.Folders.Entities, def.name)
	model:SetAttribute("Entity", def.id)
	local root = Build.part(model, {
		name = "Root",
		size = rootSize,
		cf = at,
		transparency = 1,
		collide = false,
		query = false,
		group = "Entities",
	})
	model.PrimaryPart = root
	local function limb(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?): Part
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
	return model, root, limb
end

-- A tall figure whose proportions are a little wrong: long arms, a narrow chest, the head
-- tipped. Mannequins and scarecrows are variations on it.
local function figureRig(def: any, at: CFrame): (Model, BasePart, number)
	local h = def.height or 1
	local model, root, limb = rigBase(def, at, Vector3.new(2, 2, 1) * h)
	local style = def.rig or "figure"
	local skin = Color3.fromRGB(210, 200, 186)
	local body = def.color or Color3.fromRGB(40, 40, 44)
	local legs = Color3.fromRGB(30, 30, 34)
	local mat = Enum.Material.Fabric
	if style == "mannequin" then
		skin = body
		legs = body
		mat = Enum.Material.SmoothPlastic
	elseif style == "scarecrow" then
		skin = Color3.fromRGB(170, 145, 100)
		legs = Color3.fromRGB(60, 70, 90)
	end
	for _, side in { -0.5, 0.5 } do
		limb("Leg", Vector3.new(0.8, 3.2, 0.8), CFrame.new(side, -1.6, 0), legs, mat)
		if style == "scarecrow" then
			-- Arms out on a crossbar.
			limb("Arm", Vector3.new(3.4, 0.6, 0.6), CFrame.new(side * 4.4, 2.3, 0), body)
			limb("Straw", Vector3.new(0.6, 0.6, 0.6), CFrame.new(side * 6.3, 2.2, 0), skin, Enum.Material.Grass)
		else
			limb(
				"Arm",
				Vector3.new(0.6, 3.6, 0.6),
				CFrame.new(side * 3.2, 0.3, 0) * CFrame.Angles(0, 0, side * 0.08),
				body,
				mat
			)
			limb(
				"Hand",
				Vector3.new(0.5, 0.9, 0.5),
				CFrame.new(side * 3.35, -1.85, 0),
				skin,
				Enum.Material.SmoothPlastic
			)
		end
		if style == "mannequin" then
			local joint = limb("Joint", Vector3.new(0.7, 0.7, 0.7), CFrame.new(side * 3.2, 2.1, 0), body, mat)
			joint.Shape = Enum.PartType.Ball
		end
	end
	limb("Torso", Vector3.new(1.9, 2.8, 1), CFrame.new(0, 1.4, 0), body, mat)
	limb("Neck", Vector3.new(0.5, 0.7, 0.5), CFrame.new(0, 3.1, 0), skin, Enum.Material.SmoothPlastic)
	local tilt = if style == "mannequin" then 0 else math.rad(-18)
	local head = limb(
		"Head",
		Vector3.new(1.3, 1.6, 1.3),
		CFrame.new(0.15, 4.05, 0) * CFrame.Angles(0, 0, tilt),
		skin,
		if style == "scarecrow" then Enum.Material.Fabric else Enum.Material.SmoothPlastic
	)
	if def.coat then
		limb("Coat", Vector3.new(2.1, 3.6, 1.15), CFrame.new(0, -0.4, 0), body)
	end
	if style == "scarecrow" then
		local brim = limb(
			"HatBrim",
			Vector3.new(0.2, 3.4, 3.4),
			CFrame.new(0.2, 4.9, 0) * CFrame.Angles(0, 0, math.rad(90 - 18)),
			Color3.fromRGB(150, 120, 70),
			Enum.Material.Fabric
		)
		brim.Shape = Enum.PartType.Cylinder
		limb(
			"HatTop",
			Vector3.new(1.4, 0.9, 1.4),
			CFrame.new(0.35, 5.4, 0) * CFrame.Angles(0, 0, tilt),
			Color3.fromRGB(150, 120, 70)
		)
		limb(
			"Stitch",
			Vector3.new(0.9, 0.12, 0.05),
			CFrame.new(0.2, 3.7, -0.66) * CFrame.Angles(0, 0, tilt),
			Color3.fromRGB(30, 20, 10)
		)
	elseif def.faceless or def.id == "clerk" then
		limb(
			"Shade",
			Vector3.new(1.32, 0.7, 0.2),
			CFrame.new(0.2, 4.1, -0.6) * CFrame.Angles(0, 0, tilt),
			Color3.fromRGB(10, 10, 12),
			Enum.Material.SmoothPlastic
		)
	end
	if def.id == "clerk" then
		limb("Apron", Vector3.new(1.7, 2.6, 0.1), CFrame.new(0, 0.9, -0.56), Color3.fromRGB(36, 36, 36))
		limb("Cap", Vector3.new(1.4, 0.4, 1.6), CFrame.new(0.3, 4.95, -0.1) * CFrame.Angles(0, 0, tilt), body)
	elseif def.id == "patient" then
		limb("Gown", Vector3.new(2.0, 3.8, 1.1), CFrame.new(0, 0.2, 0), Color3.fromRGB(150, 175, 185))
		local pole = limb(
			"IVPole",
			Vector3.new(0.2, 7, 0.2),
			CFrame.new(2.6, 0.5, -0.8),
			Color3.fromRGB(180, 180, 185),
			Enum.Material.Metal
		)
		local _ = pole
		limb(
			"IVBag",
			Vector3.new(0.7, 1, 0.3),
			CFrame.new(2.6, 3.6, -0.8),
			Color3.fromRGB(220, 230, 230),
			Enum.Material.Glass
		)
	elseif def.id == "mechanic" then
		limb("Overalls", Vector3.new(2.0, 2.0, 1.08), CFrame.new(0, 0.4, 0), Color3.fromRGB(40, 50, 70))
		limb(
			"Wrench",
			Vector3.new(0.3, 1.8, 0.3),
			CFrame.new(1.7, -2.4, -0.3),
			Color3.fromRGB(150, 150, 155),
			Enum.Material.Metal
		)
	elseif def.id == "librarian" then
		limb(
			"Glasses",
			Vector3.new(1.2, 0.25, 0.1),
			CFrame.new(0.15, 4.25, -0.68) * CFrame.Angles(0, 0, tilt),
			Color3.fromRGB(200, 200, 190),
			Enum.Material.Glass
		)
		limb("Bun", Vector3.new(0.8, 0.8, 0.8), CFrame.new(0.4, 4.95, 0.3), Color3.fromRGB(150, 150, 150))
	elseif def.id == "neighbor" then
		limb("Robe", Vector3.new(2.1, 3.4, 1.15), CFrame.new(0, 0.1, 0), Color3.fromRGB(110, 70, 80))
	end
	local _ = head
	return model, root, 3.2 * h + 1 * h
end

-- A dark sedan with its high beams on. Its root sits at axle height; it faces -Z.
local function carRig(def: any, at: CFrame): (Model, BasePart, number)
	local model, root, limb = rigBase(def, at, Vector3.new(6, 2, 14))
	local paint = def.color or Color3.fromRGB(30, 30, 30)
	local body = limb("Body", Vector3.new(6.4, 2.2, 15), CFrame.new(0, 0, 0), paint, Enum.Material.SmoothPlastic)
	body.Reflectance = 0.1
	limb("Cabin", Vector3.new(5.8, 2, 7.4), CFrame.new(0, 2.1, 0.8), paint, Enum.Material.SmoothPlastic)
	limb(
		"Windshield",
		Vector3.new(5.6, 1.8, 0.2),
		CFrame.new(0, 2.1, -3),
		Color3.fromRGB(10, 12, 16),
		Enum.Material.Glass
	)
	for _, side in { -1, 1 } do
		for _, z in { -4.8, 4.6 } do
			local wheel = limb(
				"Wheel",
				Vector3.new(1.1, 2.6, 2.6),
				CFrame.new(side * 2.9, -0.8, z),
				Color3.fromRGB(15, 15, 15),
				Enum.Material.Rubber
			)
			wheel.Shape = Enum.PartType.Cylinder
		end
		local lamp = limb(
			"Headlight",
			Vector3.new(1.4, 0.7, 0.2),
			CFrame.new(side * 2.1, 0.3, -7.6),
			Color3.fromRGB(255, 250, 230),
			Enum.Material.Neon
		)
		local beam = Instance.new("SpotLight")
		beam.Name = "Beam"
		beam.Face = Enum.NormalId.Front
		beam.Angle = 40
		beam.Range = 60
		beam.Brightness = 6
		beam.Color = Color3.fromRGB(255, 248, 225)
		beam.Shadows = true
		beam.Parent = lamp
		limb(
			"Taillight",
			Vector3.new(1.3, 0.5, 0.2),
			CFrame.new(side * 2.1, 0.4, 7.6),
			Color3.fromRGB(140, 20, 20),
			Enum.Material.Neon
		)
	end
	return model, root, 2.1
end

local function buildRig(def: any, at: CFrame): (Model, BasePart, number)
	if def.rig == "car" then
		return carRig(def, at)
	end
	return figureRig(def, at)
end

-- Senses ----------------------------------------------------------------------------------

local function groundAt(pos: Vector3, ignore: { Instance }): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(pos + Vector3.new(0, 6, 0), Vector3.new(0, -30, 0), params)
	return hit and hit.Position
end

-- Crouched beside a hiding spot (under a counter, in a locker, between parked buses).
local function hidden(e: Entity, player: Player, root: BasePart): boolean
	if player:GetAttribute("Stance") ~= "Crouch" then
		return false
	end
	for _, spot in e.built.refs.hidingSpots do
		local d = spot.Position - root.Position
		if Vector3.new(d.X, 0, d.Z).Magnitude <= 3.5 and math.abs(d.Y) < 5 then
			return true
		end
	end
	return false
end

-- Inside a building marked Shelter (Willow Court's houses with the door shut).
local function sheltered(e: Entity, root: BasePart): boolean
	for _, zone in e.built.refs.interior do
		if zone:GetAttribute("Shelter") == true then
			local p = zone.CFrame:PointToObjectSpace(root.Position)
			local half = zone.Size / 2
			if math.abs(p.X) <= half.X and math.abs(p.Y) <= half.Y and math.abs(p.Z) <= half.Z then
				return true
			end
		end
	end
	return false
end

local sightParams = RaycastParams.new()
sightParams.FilterType = Enum.RaycastFilterType.Exclude

local function visible(e: Entity, player: Player): boolean
	local root = PlayerState.rootOf(player)
	if not root then
		return false
	end
	local eye = e.root.Position + Vector3.new(0, if e.behavior == "Headlights" then 0.5 else 2.5, 0)
	local offset = root.Position - eye
	local dist = offset.Magnitude
	local sight = e.def.sight or Tuning.SightRange
	if dist > sight then
		return false
	end
	if dist > 4 and hidden(e, player, root) then
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
	sightParams.FilterDescendantsInstances = { World.Folders.Entities, player.Character :: any }
	local hit = workspace:Raycast(eye, offset, sightParams)
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

local function nearestHuntable(e: Entity, range: number): Player?
	local best: Player? = nil
	local bestDist = range
	for _, player in Players:GetPlayers() do
		if huntable(player) then
			local root = PlayerState.rootOf(player)
			if root then
				local d = (root.Position - e.root.Position).Magnitude
				if d < bestDist then
					best, bestDist = player, d
				end
			end
		end
	end
	return best
end

local function isObserved(e: Entity): boolean
	if not Gaze then
		return false
	end
	local cone = GazeTuning.WatcherConeDegrees
	local range = GazeTuning.WatcherRange
	local ignore = { World.Folders.Entities }
	for _, part in { "Head", "Torso" } do
		local p = e.model:FindFirstChild(part) :: BasePart?
		if p and Gaze.anyoneLooking(p.Position, cone, range, true, ignore) then
			return true
		end
	end
	return false
end

-- Movement --------------------------------------------------------------------------------

local function speedFor(e: Entity, state: string): number
	local tier = math.clamp(e.built.tier or 1, 1, 3)
	local mult = Tuning.TierSpeedMultiplier[tier]
	if #PlayerState.living() <= 1 then
		mult *= Tuning.SoloSpeedMultiplier
	end
	local b = e.behavior
	if b == "Watcher" then
		return (e.def.speed or Tuning.WatcherSpeed) * mult
	elseif b == "Headlights" then
		return (if state == "Chase" then e.def.speed else (e.def.patrolSpeed or 14)) * mult
	elseif b == "Listener" then
		if state == "Investigate" or state == "Chase" then
			return (if now() < e.alertUntil then e.def.speed else Tuning.ListenerSpeed) * mult
		end
		return (e.def.patrolSpeed or 5) * mult
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
	-- Cars drive straight; walls and cars stop them.
	if e.behavior == "Headlights" then
		e.goal = goal
		e.waypoints = { goal }
		e.wp = 1
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
		if e.active then
			e.waypoints = points
			e.wp = 1
		end
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
	local range = Config.Tuning.Player.CatchRange + (if e.behavior == "Headlights" then 4 else 1)
	for _, player in Players:GetPlayers() do
		if huntable(player) then
			local root = PlayerState.rootOf(player)
			local flat = root
				and Vector3.new(root.Position.X - e.root.Position.X, 0, root.Position.Z - e.root.Position.Z)
			if root and flat and flat.Magnitude <= range and math.abs(root.Position.Y - e.root.Position.Y) < 6 then
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

local function insideBounds(e: Entity, pos: Vector3): boolean
	local bounds = e.built.refs.extras.headlightBounds
	if not bounds then
		return true
	end
	local p = e.built.refs.frame:PointToObjectSpace(pos)
	return p.X >= bounds.min.X and p.X <= bounds.max.X and p.Z >= bounds.min.Z and p.Z <= bounds.max.Z
end

-- Thinking (5 times a second) ---------------------------------------------------------------

local function nextRoutePoint(e: Entity)
	if #e.route == 0 then
		plan(e, randomPatrolPoint(e))
		return
	end
	e.routeIndex = (e.routeIndex % #e.route) + 1
	plan(e, e.route[e.routeIndex])
end

local function afterLost(e: Entity)
	e.target = nil
	if e.behavior == "Sentry" then
		e.state = "Return"
		plan(e, e.home.Position - Vector3.new(0, e.hipHeight, 0))
	elseif e.behavior == "Headlights" then
		e.state = "Patrol"
		nextRoutePoint(e)
	else
		e.state = "Patrol"
	end
end

local function hear(e: Entity, t: number)
	if not Noise then
		return
	end
	local heard = Noise.loudestHeard(e.root.Position, e.def.hearing or 1, t - 1.5)
	if heard then
		e.state = "Investigate"
		if e.behavior == "Listener" and heard.radius >= Config.Tuning.Noise.WalkRadius * 2 then
			e.alertUntil = t + 3
		end
		if not e.goal or (e.goal - heard.position).Magnitude > 6 then
			plan(e, heard.position)
		end
	end
end

local function thinkWatcher(e: Entity, t: number)
	-- Observation is checked every step; here it picks a target to creep toward.
	if e.observed then
		return
	end
	local target = nearestHuntable(e, 160)
	if not target then
		e.state = "Frozen"
		e.waypoints = {}
		return
	end
	if e.state == "Frozen" then
		e.state = "Chase"
		if t - e.lastCreak > 2.5 then
			e.lastCreak = t
			Net.notifyAll("Sound", { key = e.def.telegraphSound or "PlasticCreak", part = e.root })
		end
	end
	e.target = target
	local root = PlayerState.rootOf(target)
	if root and t >= e.nextPath then
		e.nextPath = t + Tuning.RepathSeconds
		plan(e, root.Position)
	end
end

local function thinkSentryPost(e: Entity, t: number)
	local seen = nearestSeen(e)
	if seen then
		if e.spotFor == 0 then
			Net.notifyAll("Sound", { key = e.def.telegraphSound or "CurtainRustle", part = e.root })
		end
		e.spotFor += 0.2
		if e.spotFor >= Tuning.SentrySpotSeconds then
			e.state = "Chase"
			e.target = seen
			e.lastSeen = t
			e.spotFor = 0
			Net.notifyAll("Sound", { key = "EntitySpotted", part = e.root })
		end
	else
		e.spotFor = math.max(0, e.spotFor - 0.1)
	end
end

local function think(e: Entity)
	local t = now()
	if e.state == "Stunned" then
		if t >= e.stunUntil then
			afterLost(e)
		end
		return
	end
	if e.state == "Recover" then
		if t >= e.recoverUntil then
			if e.behavior == "Watcher" then
				e.state = "Frozen"
			else
				afterLost(e)
			end
		end
		return
	end
	if e.state == "Telegraph" or e.state == "Dormant" then
		return
	end
	local b = e.behavior
	if b == "Watcher" then
		thinkWatcher(e, t)
		return
	end
	if e.state == "Watching" then
		thinkSentryPost(e, t)
		return
	end
	if e.state == "Return" then
		if (#e.waypoints == 0 or e.wp > #e.waypoints) and not e.pathBusy then
			e.state = "Watching"
			e.root.CFrame = e.home
		end
		return
	end
	-- Hunter, Listener, Headlights and a hunting Sentry.
	local seen = if b == "Listener" then nil else nearestSeen(e)
	if seen then
		if e.state ~= "Chase" then
			Net.notifyAll("Sound", { key = if b == "Headlights" then "EngineRev" else "EntitySpotted", part = e.root })
		end
		e.state = "Chase"
		e.target = seen
		e.lastSeen = t
	elseif e.state == "Chase" and t - e.lastSeen > Tuning.LoseTargetSeconds then
		local root = e.target and PlayerState.rootOf(e.target)
		if b == "Hunter" then
			e.state = "Investigate"
			e.goal = root and root.Position or e.goal
			e.target = nil
		else
			afterLost(e)
		end
	end
	if e.state ~= "Chase" and b ~= "Headlights" then
		hear(e, t)
	end
	if e.state == "Chase" and e.target then
		local root = PlayerState.rootOf(e.target)
		if not huntable(e.target) or (e.def.respectsShelter and root and sheltered(e, root)) then
			afterLost(e)
			return
		end
		if root and t >= e.nextPath then
			e.nextPath = t + Tuning.RepathSeconds
			plan(e, root.Position)
		end
	elseif e.state == "Investigate" then
		if #e.waypoints == 0 or e.wp > #e.waypoints then
			afterLost(e)
		end
	elseif e.state == "Patrol" then
		if (#e.waypoints == 0 or e.wp > #e.waypoints) and not e.pathBusy then
			if b == "Headlights" then
				nextRoutePoint(e)
			else
				plan(e, randomPatrolPoint(e))
			end
		end
	end
end

-- Stepping (every frame) ------------------------------------------------------------------

local moveParams = RaycastParams.new()
moveParams.FilterType = Enum.RaycastFilterType.Exclude

local function step(e: Entity, dt: number)
	if e.behavior == "Watcher" then
		local t = now()
		if t >= e.nextObserve then
			e.nextObserve = t + 0.1
			local was = e.observed
			e.observed = isObserved(e)
			if e.observed and not was then
				e.state = if e.state == "Recover" then e.state else "Frozen"
				e.waypoints = {}
			end
		end
		if e.observed then
			return
		end
	end
	local s = e.state
	if s ~= "Patrol" and s ~= "Investigate" and s ~= "Chase" and s ~= "Return" then
		return
	end
	local target = e.waypoints[e.wp]
	if s == "Chase" and e.target and e.wp >= #e.waypoints then
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
	if dist < (if e.behavior == "Headlights" then 3 else 0.8) then
		e.wp += 1
		return
	end
	local speed = speedFor(e, s)
	local move = flat.Unit * math.min(dist, speed * dt)
	local nextFeet = feet + move
	-- Never step into the bus.
	if Bus.isInside(nextFeet + Vector3.new(0, 3, 0)) then
		e.waypoints = {}
		if s == "Chase" then
			afterLost(e)
		end
		return
	end
	if e.behavior == "Headlights" then
		-- Stay in the lot, and stop for walls rather than driving through them.
		if not insideBounds(e, nextFeet) then
			e.waypoints = {}
			if s == "Chase" then
				afterLost(e)
			else
				nextRoutePoint(e)
			end
			return
		end
		moveParams.FilterDescendantsInstances = { World.Folders.Entities, World.Folders.Items }
		local ahead = workspace:Raycast(pos + Vector3.new(0, 0.6, 0), flat.Unit * 9, moveParams)
		if ahead and not (ahead.Instance.Parent and ahead.Instance.Parent:FindFirstChildOfClass("Humanoid")) then
			e.waypoints = {}
			nextRoutePoint(e)
			return
		end
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

-- Spawning --------------------------------------------------------------------------------

local function routeFor(built: any): { Vector3 }
	local out: { Vector3 } = {}
	local frame: CFrame = built.refs.frame
	local route = built.refs.extras.headlightRoute
	if type(route) == "table" then
		for _, p in route do
			table.insert(out, frame * p)
		end
	end
	return out
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
		behavior = def.behavior,
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
		alertUntil = 0,
		hipHeight = hip,
		active = true,
		home = spawn,
		spotFor = 0,
		lastCreak = 0,
		observed = false,
		nextObserve = 0,
		route = if def.behavior == "Headlights" then routeFor(built) else {},
		routeIndex = 0,
	}
	local ground = groundAt(spawn.Position, { model, World.Folders.Entities })
	if ground then
		root.CFrame = CFrame.new(ground + Vector3.new(0, hip, 0)) * spawn.Rotation
	else
		root.CFrame = CFrame.new(spawn.Position) * spawn.Rotation
	end
	e.home = root.CFrame
	table.insert(entities, e)
	return e
end

local function firstState(e: Entity): string
	if e.behavior == "Watcher" then
		return "Frozen"
	elseif e.behavior == "Sentry" then
		return "Watching"
	end
	return "Patrol"
end

-- Spawn a stop's threat (def.count of them for groups), telegraph, then let it loose.
local function spawnGroup(built: any, threatId: string, at: CFrame?, telegraph: boolean): { Entity }
	local def = Config.Entities[threatId]
	if not def then
		return {}
	end
	local spawns = built.refs.entitySpawns
	local count = math.max(1, def.count or 1)
	if def.countByTier then
		count = def.countByTier[math.clamp(built.tier or 1, 1, 3)] or count
	end
	local out: { Entity } = {}
	for i = 1, count do
		local cf = at
		if not cf and #spawns > 0 then
			cf = spawns[((i - 1) % #spawns) + 1].CFrame
		end
		local e = spawnEntity(built, threatId, cf)
		if e then
			table.insert(out, e)
		end
	end
	if #out == 0 then
		return out
	end
	if telegraph then
		Net.notifyAll("Sound", { key = def.telegraphSound or "Sting", part = out[1].root })
		task.delay(Tuning.TelegraphSeconds, function()
			for _, e in out do
				if e.active and e.state == "Telegraph" then
					e.state = firstState(e)
				end
			end
		end)
	else
		for _, e in out do
			e.state = firstState(e)
		end
	end
	return out
end

-- A stop was built: note its threat.
function EntityService.setupStop(built: any)
	local def = Config.Stops.Stops[built.id]
	if not def or not def.threat then
		return
	end
	dormant[built] = { [def.threat] = true }
end

-- The doors opened: wake the stop's own threat a little later, so the first players off
-- have a few seconds to get their bearings. The Clerk only wakes on a wrong call.
function EntityService.wakeStop(built: any)
	local def = Config.Stops.Stops[built.id]
	if not def or not def.threat or def.threat == "clerk" then
		return
	end
	local edef = Config.Entities[def.threat]
	if not edef or not WAKES[edef.behavior] then
		return
	end
	local ready = dormant[built]
	if not ready or not ready[def.threat] then
		return
	end
	ready[def.threat] = nil
	local delay = Tuning.WakeDelay[math.clamp(built.tier or 1, 1, 3)]
	task.delay(delay, function()
		if built.active == false or not dormant[built] then
			return
		end
		spawnGroup(built, def.threat, nil, true)
		Log.info("Entity", "Woke", def.threat, "at", built.id)
	end)
end

-- Wake a stop's threat on demand (the Clerk after a wrong call at a changed Gas & Go).
function EntityService.activate(built: any, threatId: string)
	local ready = dormant[built]
	if not ready or not ready[threatId] then
		return
	end
	ready[threatId] = nil
	local def = Config.Entities[threatId]
	if not def or not WAKES[def.behavior] then
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
	spawnGroup(built, threatId, at, true)
	Net.notifyAll("Toast", { text = def.telegraph })
	Log.info("Entity", "Woke", threatId, "at", built.id)
end

function EntityService.spawnDebug(built: any, threatId: string): boolean
	return #spawnGroup(built, threatId, nil, false) > 0
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

-- Is any entity hunting someone right now (for Dread and the music)?
function EntityService.chasing(player: Player): boolean
	for _, e in entities do
		if e.active and e.state == "Chase" and e.target == player then
			return true
		end
	end
	return false
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
	Gaze = Registry.find("GazeService")
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
