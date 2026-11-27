--!strict
-- The Polaroid. Using it spends a shot of film and photographs what the player is aiming
-- at. The server decides what's in the shot; the client develops it (3 seconds, or at
-- once with Steady Hands) from a clone of the subject.
--   An active anomaly: Evidence. Pays transfers the first time anyone photographs that
--   anomaly this run, and fires Photographed for the Anomaly Catalog and rewards.
--   A passenger: a portrait. A mimic with the photo_blurred tell comes out smeared.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Log = require(Shared.Log)
local Signal = require(Shared.Util.Signal)

local Registry = require(script.Parent.Parent:WaitForChild("Registry"))

local Tuning = Config.Tuning.Items
local Anomalies = Config.Anomalies

local PhotoService = {}

PhotoService.Photographed = Signal.new() :: Signal.Signal<Player, string> -- (player, anomalyId)
PhotoService.Portrait = Signal.new() :: Signal.Signal<Player, boolean> -- (player, wasMimic)

local Inventory: any
local Gaze: any
local Stops: any
local PlayerState: any
local Passengers: any
local Run: any

local evidence: { [string]: boolean } = {} -- anomaly ids photographed this run
local lastShot: { [Player]: number } = {}

local function partOf(inst: Instance): BasePart?
	if inst:IsA("BasePart") then
		return inst
	end
	if inst:IsA("Model") and inst.PrimaryPart then
		return inst.PrimaryPart
	end
	return inst:FindFirstChildWhichIsA("BasePart", true)
end

local function shownPart(inst: Instance): BasePart?
	-- The first visible part of an object (variants start hidden and are shown by apply).
	if inst:IsA("BasePart") then
		return if inst.Transparency < 1 then inst else nil
	end
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			return d
		end
	end
	return nil
end

type Candidate = { subject: Instance, angle: number, anomaly: string?, passenger: any? }

-- How far off the aim line `pos` is, in degrees, or nil when out of range.
local function aimAngle(eye: Vector3, dir: Vector3, pos: Vector3): number?
	local to = pos - eye
	local dist = to.Magnitude
	if dist > Tuning.PhotoRange or dist < 0.5 then
		return nil
	end
	local cos = math.clamp(dir:Dot(to / dist), -1, 1)
	local angle = math.deg(math.acos(cos))
	if angle > Tuning.PhotoConeDegrees then
		return nil
	end
	return angle
end

local function candidates(eye: Vector3, dir: Vector3): { Candidate }
	local out: { Candidate } = {}
	-- Passengers (waiting, aboard, revealed).
	if Passengers then
		for _, p in Passengers.list() do
			local m = p.model
			local head = m and m:FindFirstChild("Head") :: BasePart?
			if m and head then
				local a = aimAngle(eye, dir, head.Position)
				if a then
					table.insert(out, { subject = m, angle = a, passenger = p })
				end
			end
		end
	end
	-- Active anomalies at the current stop: the object in the anomaly's slot, or its
	-- shown variant.
	local built = Stops and Stops.current
	if built and built.refs and built.anomalies and built.active ~= false then
		for _, id in built.anomalies :: { string } do
			local def = Anomalies.ById[id]
			if not def then
				continue
			end
			local target: Instance? = nil
			for _, d in built.refs.model:GetDescendants() do
				if d:GetAttribute("AnomalyVariant") == id and shownPart(d) then
					target = d
					break
				end
			end
			target = target or built.refs.slots[def.slot]
			local part = target and partOf(target)
			if target and part then
				local a = aimAngle(eye, dir, part.Position)
				if a then
					-- Anomalies get a little slack, so they win over a passenger at the edge.
					table.insert(out, { subject = target, angle = a * 0.8, anomaly = id })
				end
			end
		end
	end
	table.sort(out, function(a, b)
		return a.angle < b.angle
	end)
	return out
end

function PhotoService.prompt(player: Player)
	if not PlayerState.isHealthy(player) then
		return
	end
	local t = os.clock()
	if t - (lastShot[player] or 0) < 1.5 then
		return
	end
	local eye, dir = Gaze.look(player)
	if not eye or not dir then
		return
	end
	if not Inventory.useFilm(player) then
		Net.notify(player, "Toast", { text = "Out of film." })
		return
	end
	lastShot[player] = t
	Net.notifyAll("Sound", { key = "Camera", at = eye })
	local develop = if player:GetAttribute("Perk") == "steady_hands" then 0 else Tuning.PhotoDevelopSeconds
	local best = candidates(eye, dir)[1]
	local payload: { [string]: any } = { develop = develop, eye = eye, dir = dir }
	if best and best.anomaly then
		local def = Anomalies.ById[best.anomaly]
		payload.subject = best.subject
		payload.caption = `EVIDENCE: {def.name}`
		payload.report = def.report
		if not evidence[best.anomaly] then
			evidence[best.anomaly] = true
			Inventory.give(player, "transfers", Config.Tuning.Rewards.EvidenceTransfers)
			payload.paid = Config.Tuning.Rewards.EvidenceTransfers
		end
		PhotoService.Photographed:Fire(player, best.anomaly)
		Log.info("Photo", player.Name, "photographed", best.anomaly)
	elseif best and best.passenger then
		local p = best.passenger
		payload.subject = best.subject
		payload.caption = p.def.name
		payload.blurred = Passengers.photoBlurred(p)
		PhotoService.Portrait:Fire(player, p.mimic == true)
	else
		payload.caption = "Nothing but the dark."
	end
	Net.notify(player, "Photo", payload)
end

function PhotoService:Init()
	Inventory = Registry.get("InventoryService")
	Gaze = Registry.get("GazeService")
	Stops = Registry.find("StopService")
	PlayerState = Registry.get("PlayerStateService")
	Passengers = Registry.find("PassengerService")
	Run = Registry.get("RunDirector")
end

function PhotoService:Start()
	Run.RunStarted:Connect(function()
		table.clear(evidence)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastShot[player] = nil
	end)
end

return PhotoService
