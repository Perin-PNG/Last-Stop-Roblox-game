--!strict
-- Dread: each player's fear, 0 to 100, kept as the player's "Dread" attribute. It rises in
-- the dark, near Ambient anomalies and when you're alone, and falls on the lit bus, near
-- teammates and with food. Its effects:
--   40  vignette and heartbeat (client, DreadController)
--   60  hallucinations: fakes only this player sees (HallucinationController); 70 with Calm
--   80  the flashlight flickers, which counts as looking away for Watchers
--   100 you drop what you're holding, hallucinations peak for 10 s, then Dread falls to 70
-- Hallucinations are cosmetic: the server only says what to show and where; they can
-- never hurt anyone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Perks = require(Shared.Perks)
local Log = require(Shared.Log)
local Registry = require(script.Parent.Parent:WaitForChild("Registry"))

local Tuning = Config.Tuning.Dread

local DreadService = {}

type Info = {
	value: number,
	peakUntil: number,
	nextHallucination: number,
	wasDowned: boolean,
}

local info: { [Player]: Info } = {}
local PlayerState: any
local Inventory: any
local Bus: any
local Stops: any
local RunState: Folder

-- Lights and Ambient anomalies near the current stop, refreshed every couple of seconds
-- rather than walked every tick.
local lights: { { pos: Vector3, light: Light } } = {}
local ambient: { Vector3 } = {}
local lastScan = 0

local HALLUCINATIONS = { "footsteps", "figure", "anomaly", "whisper", "passenger" }

local function now(): number
	return workspace:GetServerTimeNow()
end

local function infoOf(player: Player): Info
	local i = info[player]
	if not i then
		i = { value = 0, peakUntil = 0, nextHallucination = 0, wasDowned = false }
		info[player] = i
	end
	return i
end

local function partOf(inst: Instance): BasePart?
	if inst:IsA("BasePart") then
		return inst
	end
	return inst:FindFirstChildWhichIsA("BasePart", true)
end

local function scan()
	table.clear(lights)
	table.clear(ambient)
	local stop = Stops and Stops.current
	local roots: { Instance } = {}
	if stop and stop.refs and stop.refs.model.Parent then
		table.insert(roots, stop.refs.model)
	end
	for _, root in roots do
		for _, d in root:GetDescendants() do
			if d:IsA("Light") then
				local p = d.Parent
				if p and p:IsA("BasePart") then
					table.insert(lights, { pos = p.Position, light = d })
				end
			elseif d:GetAttribute("AnomalySeverity") == "Ambient" then
				local part = partOf(d)
				if part then
					table.insert(ambient, part.Position)
				end
			end
		end
	end
end

local function rootOf(player: Player): BasePart?
	return PlayerState.rootOf(player)
end

local function litNear(player: Player, pos: Vector3): boolean
	-- Your own flashlight counts, and so does a teammate's beam nearby.
	if player:GetAttribute("Light") == true and player:GetAttribute("Flicker") ~= true then
		return true
	end
	for _, other in Players:GetPlayers() do
		if other ~= player and other:GetAttribute("Light") == true then
			local r = rootOf(other)
			if r and (r.Position - pos).Magnitude <= Tuning.NoLightRadius then
				return true
			end
		end
	end
	for _, l in lights do
		local light = l.light
		if light.Enabled and light.Brightness > 0.2 then
			local reach = math.max(Tuning.NoLightRadius, ((light :: any).Range :: number) * 0.6)
			if (l.pos - pos).Magnitude <= reach then
				return true
			end
		end
	end
	return false
end

local function teammateNear(player: Player, pos: Vector3): boolean
	for _, other in Players:GetPlayers() do
		if other ~= player and PlayerState.isActive(other) then
			local r = rootOf(other)
			if r and (r.Position - pos).Magnitude <= Tuning.TeammateRadius then
				return true
			end
		end
	end
	return false
end

local function seated(player: Player): boolean
	local hum = PlayerState.humanoidOf(player)
	return hum ~= nil and hum.Sit
end

local function gainMultiplier(): number
	local tier = (RunState:GetAttribute("Tier") :: number?) or 1
	local mult = Tuning.TierMultiplier[math.clamp(tier, 1, #Tuning.TierMultiplier)] or 1
	local overtime = (RunState:GetAttribute("Overtime") :: number?) or 0
	if overtime > 0 then
		mult = math.max(mult, Tuning.OvertimeMultiplier)
	end
	if RunState:GetAttribute("Mode") == "Graveyard" then
		mult *= Tuning.GraveyardMultiplier
	end
	return mult
end

local function hallucinateAt(player: Player): number
	return if Perks.has(player, "calm") then Tuning.CalmHallucinateAt else Tuning.HallucinateAt
end

local function sendHallucination(player: Player, kind: string?)
	local root = rootOf(player)
	if not root then
		return
	end
	local pick = kind or HALLUCINATIONS[math.random(1, #HALLUCINATIONS)]
	-- Somewhere behind or beside the player, 12 to 30 studs out.
	local angle = math.rad(math.random(110, 250))
	local look = root.CFrame.LookVector
	local dir = (CFrame.Angles(0, angle, 0) * Vector3.new(look.X, 0, look.Z)).Unit
	local at = root.Position + dir * math.random(12, 30)
	Net.event("Hallucinate"):FireClient(player, { kind = pick, at = at })
end

local function setValue(player: Player, i: Info, value: number)
	i.value = math.clamp(value, 0, Tuning.Max)
	local shown = math.floor(i.value + 0.5)
	if player:GetAttribute("Dread") ~= shown then
		player:SetAttribute("Dread", shown)
	end
	local flicker = i.value >= Tuning.FlickerAt
	if player:GetAttribute("DreadFlicker") ~= flicker then
		player:SetAttribute("DreadFlicker", flicker)
	end
end

local function peak(player: Player, i: Info)
	i.peakUntil = now() + Tuning.PeakSeconds
	if Inventory then
		Inventory.dropSelected(player)
	end
	Net.notify(player, "Toast", { text = "Your hands won't stop shaking." })
	for _ = 1, 3 do
		sendHallucination(player)
	end
	Log.info("Dread", player.Name, "peaked")
end

-- Add (or with a negative amount, remove) Dread at once.
function DreadService.add(player: Player, amount: number)
	local i = infoOf(player)
	if i.peakUntil > now() and amount > 0 then
		return
	end
	setValue(player, i, i.value + amount)
	if i.value >= Tuning.Max and i.peakUntil <= now() then
		peak(player, i)
	end
end

function DreadService.get(player: Player): number
	return infoOf(player).value
end

function DreadService.reset(player: Player)
	local i = infoOf(player)
	i.peakUntil = 0
	i.wasDowned = false
	setValue(player, i, 0)
end

function DreadService.resetAll()
	for _, player in Players:GetPlayers() do
		DreadService.reset(player)
	end
end

local function tick(dt: number)
	local t = now()
	if t - lastScan > 2 then
		lastScan = t
		scan()
	end
	local mult = gainMultiplier()
	for _, player in Players:GetPlayers() do
		local i = infoOf(player)
		local state = PlayerState.state(player)
		if state ~= "Aboard" and state ~= "Outside" then
			continue
		end
		local root = rootOf(player)
		if not root then
			continue
		end
		local pos = root.Position
		local rate = 0
		if state == "Aboard" and Bus and Bus.lightsOn then
			rate += if seated(player) then Tuning.BusLitSeated else Tuning.BusLit
		elseif not litNear(player, pos) then
			rate += Tuning.NoLight * mult
		end
		for _, a in ambient do
			if (a - pos).Magnitude <= Tuning.AmbientRadius then
				rate += Tuning.AmbientAnomaly * mult
				break
			end
		end
		if #Players:GetPlayers() > 1 then
			if teammateNear(player, pos) then
				rate += Tuning.TeammateNear
			elseif state == "Outside" then
				rate += Tuning.Alone * mult
			end
		end
		if i.peakUntil > t then
			-- The peak: hold at 100, then drop back.
			setValue(player, i, Tuning.Max)
			continue
		elseif i.peakUntil > 0 then
			i.peakUntil = 0
			setValue(player, i, Tuning.AfterPeak)
		end
		setValue(player, i, i.value + rate * dt)
		if i.value >= Tuning.Max then
			peak(player, i)
		elseif i.value >= hallucinateAt(player) then
			if i.nextHallucination == 0 then
				i.nextHallucination = t + math.random(4, 9)
			elseif t >= i.nextHallucination then
				sendHallucination(player)
				local range = Tuning.HallucinationEvery
				i.nextHallucination = t + math.random(range[1], range[2])
			end
		else
			i.nextHallucination = 0
		end
	end
end

function DreadService:Init()
	PlayerState = Registry.get("PlayerStateService")
	Inventory = Registry.find("InventoryService")
	Bus = Registry.find("BusService")
	Stops = Registry.find("StopService")
	RunState = Registry.get("WorldService").RunState
end

function DreadService:Start()
	-- Seeing a teammate go down: +15 for everyone close enough to have seen it.
	PlayerState.Downed:Connect(function(downed: Player)
		local root = rootOf(downed)
		if not root then
			return
		end
		for _, player in Players:GetPlayers() do
			if player ~= downed and PlayerState.isHealthy(player) then
				local r = rootOf(player)
				if r and (r.Position - root.Position).Magnitude <= 60 then
					DreadService.add(player, Tuning.SeeTeammateDown)
				end
			end
		end
	end)
	PlayerState.StateChanged:Connect(function(player: Player, state: string)
		if state == "Lobby" or state == "Lost" then
			DreadService.reset(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		info[player] = nil
	end)
	task.spawn(function()
		while true do
			local dt = task.wait(Tuning.TickSeconds)
			local ok, err = pcall(function()
				tick(dt)
			end)
			if not ok then
				Log.warn("Dread", "tick failed", err)
			end
		end
	end)
end

return DreadService
