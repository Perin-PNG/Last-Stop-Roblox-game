--!strict
-- The Latecomer: the reason the doors close on time. Part way through each stop's timer a
-- far-off bus-stop bell rings and the streetlights start going out, far to near. A tall
-- figure in a long coat walks in along the sidewalk, timed to reach the doors right at
-- the deadline. Anyone in its way goes Down. A flare stalls it for 3 seconds.
--
-- If the doors are still open when it arrives (someone held them), it boards: the cabin
-- lights go red and it downs one rider every 8 seconds until the next stop.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Build = require(Shared.Util.Build)
local Net = require(Shared.Net)
local Log = require(Shared.Log)

local Registry = require(script.Parent.Parent:WaitForChild("Registry"))

local Tuning = Config.Tuning.Latecomer
local StopTuning = Config.Tuning.Stop

local LatecomerService = {}

type Walk = {
	built: any,
	startAt: number,
	arriveAt: number,
	from: CFrame,
	to: CFrame,
	pausedUntil: number,
	delay: number, -- seconds of flare stall so far
	model: Model?,
	root: BasePart?,
	lightsOut: number,
	state: string, -- Waiting | Walking | AtDoor | Boarded | Gone
	token: number,
}

local walk: Walk? = nil
local token = 0
local boardedSince: number? = nil
local nextDown = 0

local Bus: any
local PlayerState: any
local World: any
local RunState: Folder

local function now(): number
	return workspace:GetServerTimeNow()
end

local function rig(at: CFrame): (Model, BasePart)
	local def = Config.Entities.latecomer
	local h = def.height or 1.25
	local model = Build.model(World.Folders.Entities, "Latecomer")
	model:SetAttribute("Entity", "latecomer")
	local root = Build.part(model, {
		name = "Root",
		size = Vector3.new(2, 2, 1),
		cf = at,
		transparency = 1,
		collide = false,
		query = false,
		group = "Entities",
	})
	model.PrimaryPart = root
	local coat = Color3.fromRGB(16, 16, 20)
	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?)
		local p = Build.part(model, {
			name = name,
			size = size * h,
			cf = at * CFrame.new(offset.Position * h) * offset.Rotation,
			color = color,
			material = material or Enum.Material.Fabric,
			anchored = false,
			collide = false,
			group = "Entities",
		})
		p.Massless = true
		Build.weld(root, p)
		return p
	end
	-- A long coat to the ankles, a hat brim, nothing where the face should be.
	piece("Coat", Vector3.new(2.4, 5.2, 1.4), CFrame.new(0, -0.4, 0), coat)
	piece("CoatHem", Vector3.new(2.8, 1.2, 1.7), CFrame.new(0, -2.6, 0), coat)
	piece("Shoulders", Vector3.new(3, 0.8, 1.4), CFrame.new(0, 2.1, 0), coat)
	for _, side in { -1, 1 } do
		piece("Arm", Vector3.new(0.6, 4.6, 0.6), CFrame.new(side * 1.7, -0.1, 0), coat)
		piece(
			"Hand",
			Vector3.new(0.5, 1.2, 0.4),
			CFrame.new(side * 1.75, -2.9, 0),
			Color3.fromRGB(200, 196, 186),
			Enum.Material.SmoothPlastic
		)
	end
	piece(
		"Head",
		Vector3.new(1.2, 1.5, 1.2),
		CFrame.new(0, 3.3, 0),
		Color3.fromRGB(8, 8, 10),
		Enum.Material.SmoothPlastic
	)
	piece("Brim", Vector3.new(2.4, 0.15, 2.4), CFrame.new(0, 4.0, 0), coat)
	piece("Crown", Vector3.new(1.4, 1, 1.4), CFrame.new(0, 4.55, 0), coat)
	return model, root
end

local function clearRig(w: Walk)
	if w.model then
		w.model:Destroy()
	end
	w.model = nil
	w.root = nil
end

-- The share of the timer at which it sets off.
local function startShare(tier: number, overtime: number): number
	if overtime > 0 then
		return StopTuning.OvertimeLatecomerAt
	end
	return StopTuning.LatecomerAt[math.clamp(tier, 1, 3)]
end

function LatecomerService.schedule(built: any, deadline: number, tier: number, timer: number, overtime: number)
	token += 1
	local share = startShare(tier, overtime)
	local startAt = deadline - timer * (1 - share) - Tuning.BellLead
	local frame: CFrame = built.refs.frame
	walk = {
		built = built,
		startAt = math.max(now() + 8, startAt),
		arriveAt = deadline + 2.5, -- a breath after the doors would normally shut
		from = frame * CFrame.new(5, 0, Tuning.StartDistance) * CFrame.Angles(0, 0, 0),
		to = frame * CFrame.new(5, 0, 6),
		pausedUntil = 0,
		delay = 0,
		model = nil,
		root = nil,
		lightsOut = 0,
		state = "Waiting",
		token = token,
	}
	RunState:SetAttribute("LatecomerDistance", nil)
end

-- A flare landed: stall it if it's close.
function LatecomerService.flare(pos: Vector3)
	local w = walk
	if not w or w.state ~= "Walking" or not w.root then
		return
	end
	if (w.root.Position - pos).Magnitude <= Config.Tuning.Items.FlareStunRadius + 6 then
		local t = now()
		local stall = Config.Tuning.Items.FlareStunSeconds
		w.pausedUntil = math.max(w.pausedUntil, t) + stall
		w.delay += stall
		Net.notifyAll("Sound", { key = "LatecomerHiss", part = w.root })
	end
end

-- The doors shut. If it never made it aboard, it stands at the door as the bus pulls away.
function LatecomerService.doorsClosed()
	local w = walk
	if not w or w.state == "Boarded" then
		return
	end
	if w.root and w.state ~= "Waiting" then
		Net.notifyAll("Sound", { key = "Knock", part = w.root })
		task.delay(4, function()
			if walk == w then
				clearRig(w)
				w.state = "Gone"
			end
		end)
	else
		w.state = "Gone"
	end
	RunState:SetAttribute("LatecomerDistance", nil)
end

local function board(w: Walk)
	w.state = "Boarded"
	clearRig(w)
	boardedSince = now()
	nextDown = now() + Tuning.BoardedDownEvery
	RunState:SetAttribute("LatecomerAboard", true)
	Net.notifyAll("Sound", { key = "LatecomerBoard" })
	Net.notifyAll("Toast", { text = "Something got on." })
	local refs = Bus.refs
	if refs then
		for _, bank in refs.lightBanks do
			for _, light in bank do
				light.Color = Color3.fromRGB(255, 40, 30)
			end
		end
		for _, tube in refs.lightTubes do
			tube.Color = Color3.fromRGB(255, 60, 50)
		end
	end
	Log.info("Latecomer", "Boarded")
end

local function unboard()
	if not boardedSince then
		return
	end
	boardedSince = nil
	RunState:SetAttribute("LatecomerAboard", false)
	local refs = Bus.refs
	if refs then
		local normal = Build.Colors.Fluor
		for _, bank in refs.lightBanks do
			for _, light in bank do
				light.Color = normal
			end
		end
		for _, tube in refs.lightTubes do
			tube.Color = normal
		end
	end
end

function LatecomerService.reset()
	token += 1
	if walk then
		clearRig(walk)
	end
	walk = nil
	unboard()
	RunState:SetAttribute("LatecomerDistance", nil)
end

local function step()
	local t = now()
	-- Aboard: down one rider at a time.
	if boardedSince and t >= nextDown then
		nextDown = t + Tuning.BoardedDownEvery
		local riders = {}
		for _, player in Players:GetPlayers() do
			if PlayerState.state(player) == "Aboard" and Bus.isAboard(player) then
				table.insert(riders, player)
			end
		end
		if #riders > 0 then
			local victim = riders[math.random(1, #riders)]
			PlayerState.down(victim, "latecomer")
			Net.notifyAll("Sound", { key = "Caught" })
		end
	end
	local w = walk
	if not w or w.token ~= token then
		return
	end
	if w.state == "Waiting" then
		if t >= w.startAt then
			w.state = "Walking"
			local model, root = rig(w.from)
			w.model, w.root = model, root
			Net.notifyAll("Sound", { key = "FarBell" })
			Net.notifyAll("Hint", { id = "latecomer" })
			RunState:SetAttribute("LatecomerStart", t)
		end
		return
	end
	if w.state ~= "Walking" or not w.root then
		return
	end
	local duration = math.max(1, w.arriveAt - w.startAt)
	local elapsed = math.max(0, t - w.startAt - w.delay)
	if t < w.pausedUntil then
		elapsed = math.max(0, w.pausedUntil - w.startAt - w.delay)
	end
	local alpha = math.clamp(elapsed / duration, 0, 1)
	local pos = w.from.Position:Lerp(w.to.Position, alpha)
	-- A slight sway: it doesn't walk like a person.
	local sway = math.sin(t * 2.3) * 0.25
	local look = (w.to.Position - w.from.Position).Unit
	local right = look:Cross(Vector3.yAxis)
	local feet = pos + right * sway
	w.root.CFrame = CFrame.lookAt(feet + Vector3.new(0, 4.2, 0), feet + Vector3.new(0, 4.2, 0) + look)
	local remaining = (w.to.Position - pos).Magnitude
	RunState:SetAttribute("LatecomerDistance", math.floor(remaining))
	-- Streetlights go out as it passes under them, far to near.
	local lights: { BasePart } = w.built.refs.streetlights
	local frame: CFrame = w.built.refs.frame
	local z = frame:PointToObjectSpace(pos).Z
	while w.lightsOut < #lights do
		local lamp = lights[w.lightsOut + 1]
		if frame:PointToObjectSpace(lamp.Position).Z + 20 >= z then
			w.lightsOut += 1
			lamp.Color = Color3.fromRGB(30, 26, 20)
			for _, d in lamp:GetChildren() do
				if d:IsA("Light") then
					d.Enabled = false
				end
			end
			Net.notifyAll("Sound", { key = "LightPop", part = lamp })
		else
			break
		end
	end
	-- Anyone in the way.
	for _, player in Players:GetPlayers() do
		local root = PlayerState.rootOf(player)
		if root and PlayerState.isHealthy(player) and not Bus.isAboard(player) then
			local d = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(feet.X, 0, feet.Z)).Magnitude
			if d <= Tuning.KnockRadius and math.abs(root.Position.Y - feet.Y) < 8 then
				PlayerState.down(player, "latecomer")
			end
		end
	end
	if alpha >= 1 then
		if Bus.doorsOpen then
			board(w)
		else
			w.state = "AtDoor"
		end
	end
end

function LatecomerService.isAboard(): boolean
	return boardedSince ~= nil
end

function LatecomerService:Init()
	Bus = Registry.get("BusService")
	PlayerState = Registry.get("PlayerStateService")
	World = Registry.get("WorldService")
	RunState = World.RunState
end

function LatecomerService:Start()
	RunService.Heartbeat:Connect(step)
	local director = Registry.find("RunDirector")
	if director then
		-- It gets off at the next stop.
		director.StopOpened:Connect(function()
			unboard()
		end)
	end
	-- Held doors at the door: it waits there and boards the moment they're still open.
	task.spawn(function()
		while true do
			task.wait(0.25)
			local w = walk
			if w and w.state == "AtDoor" and Bus.doorsOpen then
				board(w)
			end
		end
	end)
end

return LatecomerService
