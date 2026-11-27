--!strict
-- Builds the road ahead of the bus chunk by chunk and deletes it behind. All chunks share
-- one Path (the road centreline) that the bus follows. Distances along the path are
-- absolute: they keep growing for the whole run.
--
-- Fillers (straight, curve, hill, bridge, tunnel, overpass) keep about Tuning.Chunks.Ahead
-- chunks in front of the bus. A stop is a special straight chunk whose curb point is
-- returned so StopService can build the stop prefab there and BusService can pull in.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Path = require(Shared.Util.Path)
local Seed = require(Shared.Util.Seed)
local Build = require(Shared.Util.Build)
local Log = require(Shared.Log)

local Builders = script.Parent.Parent:WaitForChild("Builders")
local RoadBuilder = require(Builders:WaitForChild("RoadBuilder"))

local Registry = require(script.Parent.Parent:WaitForChild("Registry"))

local Tuning = Config.Tuning.Chunks

export type ChunkKind = "straight" | "curve" | "hill" | "bridge" | "tunnel" | "overpass" | "stop" | "terminal" | "start"

export type Chunk = {
	id: number,
	kind: ChunkKind,
	startS: number,
	endS: number,
	model: Model,
	centre: Vector3,
	radius: number,
	pinned: boolean,
	curbS: number?, -- stop chunks: distance of the curb point
	curbCf: CFrame?, -- stop chunks: road centreline frame at the curb point
}

local ChunkService = {}

ChunkService.path = Path.new()
ChunkService.chunks = {} :: { Chunk }
ChunkService.rng = Seed.new(1)
ChunkService.theme = "woods"

local nextId = 0
local folder: Folder
local lastKind: ChunkKind = "start"
local sinceLight = 0

local OVERPASS_LABELS = {
	"HOLLOW COUNTY LINE",
	"EXIT 9  WESTBROOK",
	"RT 9 NORTH",
	"NO OUTLET",
	"TRI-COUNTY DEPOT  2 MI",
	"YOU ARE ON ROUTE 9N",
	"LAST EXIT",
}

local function endFrame(): CFrame
	local last = ChunkService.path:last()
	return last or CFrame.identity
end

local function boundsOf(points: { CFrame }): (Vector3, number)
	local sum = Vector3.zero
	for _, cf in points do
		sum += cf.Position
	end
	local centre = sum / math.max(1, #points)
	local radius = 0
	for _, cf in points do
		radius = math.max(radius, (cf.Position - centre).Magnitude)
	end
	return centre, radius + 200
end

local function newChunk(kind: ChunkKind, points: { CFrame }): Chunk
	nextId += 1
	local startS = ChunkService.path:length()
	ChunkService.path:append(points)
	local model = Build.model(folder, string.format("Chunk%03d_%s", nextId, kind))
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local centre, radius = boundsOf(points)
	local chunk: Chunk = {
		id = nextId,
		kind = kind,
		startS = startS,
		endS = ChunkService.path:length(),
		model = model,
		centre = centre,
		radius = radius,
		pinned = false,
	}
	table.insert(ChunkService.chunks, chunk)
	lastKind = kind
	return chunk
end

-- Turn direction for curves: random, but steer home when far from the origin.
local function turnSign(): number
	local cf = endFrame()
	local pos = Vector3.new(cf.Position.X, 0, cf.Position.Z)
	if pos.Magnitude > Tuning.WorldRadius then
		local toHome = -pos.Unit
		local right = cf.RightVector
		return if right:Dot(toHome) >= 0 then 1 else -1
	end
	return if ChunkService.rng:chance(0.5) then 1 else -1
end

local function decorate(chunk: Chunk, points: { CFrame }, sides: { number }?)
	RoadBuilder.scenery(chunk.model, points, ChunkService.rng, ChunkService.theme, sides)
	RoadBuilder.streetlights(chunk.model, points, Tuning.StreetlightSpacing * 2, sinceLight)
end

local builders: { [string]: () -> Chunk } = {}

function builders.straight(): Chunk
	local points = Path.straight(endFrame(), Tuning.StraightLength)
	local chunk = newChunk("straight", points)
	RoadBuilder.surface(chunk.model, points)
	decorate(chunk, points)
	return chunk
end

function builders.curve(): Chunk
	local angle = math.rad(Tuning.CurveAngleDegrees * ChunkService.rng:float(0.8, 1.2)) * turnSign()
	local points = Path.arc(endFrame(), Tuning.CurveRadius, angle)
	local chunk = newChunk("curve", points)
	RoadBuilder.surface(chunk.model, points)
	decorate(chunk, points)
	return chunk
end

function builders.hill(): Chunk
	local points = Path.hill(endFrame(), Tuning.HillLength, Tuning.HillHeight * ChunkService.rng:float(0.7, 1.1))
	local chunk = newChunk("hill", points)
	RoadBuilder.surface(chunk.model, points)
	decorate(chunk, points)
	return chunk
end

function builders.bridge(): Chunk
	local start = endFrame()
	local lead = Path.straight(start, 60)
	local span = Path.straight(lead[#lead], Tuning.BridgeLength - 120)
	local tail = Path.straight(span[#span], 60)
	local points = table.clone(lead)
	for i = 2, #span do
		table.insert(points, span[i])
	end
	for i = 2, #tail do
		table.insert(points, tail[i])
	end
	local chunk = newChunk("bridge", points)
	RoadBuilder.surface(chunk.model, lead)
	RoadBuilder.surface(chunk.model, span, {
		groundLeft = false,
		groundRight = false,
		sidewalk = false,
		shoulder = false,
		thick = 3,
		railings = true,
	})
	RoadBuilder.bridge(chunk.model, span)
	RoadBuilder.surface(chunk.model, tail)
	return chunk
end

function builders.tunnel(): Chunk
	local points = Path.straight(endFrame(), Tuning.TunnelLength)
	local chunk = newChunk("tunnel", points)
	RoadBuilder.surface(chunk.model, points, { groundLeft = false, groundRight = false })
	RoadBuilder.tunnel(chunk.model, points)
	chunk.model:SetAttribute("Tunnel", true)
	return chunk
end

function builders.overpass(): Chunk
	local points = Path.straight(endFrame(), Tuning.StraightLength)
	local chunk = newChunk("overpass", points)
	RoadBuilder.surface(chunk.model, points)
	RoadBuilder.overpass(chunk.model, points[math.floor(#points / 2)], ChunkService.rng:pick(OVERPASS_LABELS))
	decorate(chunk, points)
	return chunk
end

local FILLER_WEIGHTS: { [string]: number } = {
	straight = 4,
	curve = 4,
	hill = 2,
	bridge = 1,
	tunnel = 1,
	overpass = 1,
}

local function pickFiller(): string
	local weights: { [string]: number } = {}
	for kind, weight in FILLER_WEIGHTS do
		local blocked = (kind == "tunnel" or kind == "bridge") and (lastKind == "tunnel" or lastKind == "bridge")
		if not blocked then
			weights[kind] = if kind == "curve" and lastKind == "curve" then 2 else weight
		end
	end
	return ChunkService.rng:weighted(weights)
end

function ChunkService.appendFiller(kind: string?): Chunk
	local choice = kind or pickFiller()
	local builder = builders[choice] or builders.straight
	return builder()
end

-- A stop chunk: a straight with the curb point StopCurbFromEntry in. The right-hand
-- ground is left out so the stop's own lot can go there.
function ChunkService.appendStop(stopId: string): Chunk
	local points = Path.straight(endFrame(), Tuning.StopRoadLength)
	local chunk = newChunk("stop", points)
	chunk.model.Name = string.format("Chunk%03d_stop_%s", chunk.id, stopId)
	RoadBuilder.surface(chunk.model, points, { groundRight = false })
	RoadBuilder.scenery(chunk.model, points, ChunkService.rng, ChunkService.theme, { -1 })
	local curbS = chunk.startS + Tuning.StopCurbFromEntry
	chunk.curbS = curbS
	chunk.curbCf = ChunkService.path:sample(curbS)
	chunk.pinned = true
	return chunk
end

-- The Terminal: a long straight that ends at the depot. The curb is near the end.
function ChunkService.appendTerminal(): Chunk
	local points = Path.straight(endFrame(), Tuning.TerminalLength)
	local chunk = newChunk("terminal", points)
	RoadBuilder.surface(chunk.model, points, { groundRight = false })
	RoadBuilder.scenery(chunk.model, points, ChunkService.rng, "woods", { -1 })
	local curbS = chunk.endS - 160
	chunk.curbS = curbS
	chunk.curbCf = ChunkService.path:sample(curbS)
	chunk.pinned = true
	return chunk
end

-- Start fresh at `origin` (a road centreline frame).
function ChunkService.reset(seed: number, origin: CFrame)
	for _, chunk in ChunkService.chunks do
		chunk.model:Destroy()
	end
	table.clear(ChunkService.chunks)
	ChunkService.path = Path.new()
	ChunkService.rng = Seed.new(seed):child("road")
	ChunkService.path:append({ origin })
	lastKind = "start"
	sinceLight = 0
	nextId = 0
end

-- Start a new path at `origin` but keep the chunks already built (Stationary mode builds
-- each stop in its own yard; old yards are cleaned up once nobody is there).
function ChunkService.newPath(seed: number, origin: CFrame)
	ChunkService.path = Path.new()
	ChunkService.rng = Seed.new(seed):child("road")
	ChunkService.path:append({ origin })
	lastKind = "start"
end

-- A short stretch of road before the first stop, so the bus has room to pull in.
function ChunkService.appendLeadIn(length: number): Chunk
	local points = Path.straight(endFrame(), length)
	local chunk = newChunk("straight", points)
	RoadBuilder.surface(chunk.model, points)
	decorate(chunk, points)
	return chunk
end

function ChunkService.setTheme(theme: string)
	ChunkService.theme = theme
end

function ChunkService.ensureAhead(s: number)
	local want = s + Tuning.Ahead * Tuning.StraightLength
	local guard = 0
	while ChunkService.path:length() < want and guard < 8 do
		ChunkService.appendFiller()
		guard += 1
	end
end

local function anyPlayerNear(chunk: Chunk): boolean
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and (root.Position - chunk.centre).Magnitude < chunk.radius then
			return true
		end
	end
	return false
end

-- Delete chunks well behind `s` that nobody is standing in.
function ChunkService.cleanup(s: number)
	local behind = Tuning.Behind * Tuning.StraightLength + 200
	local keep = {}
	for _, chunk in ChunkService.chunks do
		if chunk.endS < s - behind and not chunk.pinned and not anyPlayerNear(chunk) then
			chunk.model:Destroy()
		else
			table.insert(keep, chunk)
		end
	end
	ChunkService.chunks = keep
	ChunkService.path:trimBefore(s - behind - 400)
end

function ChunkService.unpin(chunk: Chunk)
	chunk.pinned = false
end

function ChunkService.chunkAt(s: number): Chunk?
	for _, chunk in ChunkService.chunks do
		if s >= chunk.startS and s <= chunk.endS then
			return chunk
		end
	end
	return nil
end

function ChunkService.inTunnel(s: number): boolean
	local chunk = ChunkService.chunkAt(s)
	return chunk ~= nil and chunk.kind == "tunnel"
end

function ChunkService.clear()
	for _, chunk in ChunkService.chunks do
		chunk.model:Destroy()
	end
	table.clear(ChunkService.chunks)
end

function ChunkService:Init()
	local World = Registry.get("WorldService")
	folder = World.Folders.Road
end

function ChunkService:Start()
	Log.info("Chunks", "Ready")
end

return ChunkService
