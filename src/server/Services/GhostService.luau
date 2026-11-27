--!strict
-- What Static (Lost) players can still do. Once per stop, a Lost player may:
--   flicker   flicker the light nearest the teammate they're watching
--   word      make the radio say one word: WAIT, LEFT, BEHIND or NO
--   reveal    flash every mimic aboard in its true colours for one second
-- The client asks with the GhostAction remote; the server checks state, the once-per-stop
-- budget and the arguments.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Log = require(Shared.Log)

local Registry = require(script.Parent.Parent:WaitForChild("Registry"))

local GhostService = {}

GhostService.Words = { "WAIT", "LEFT", "BEHIND", "NO" }

local PlayerState: any
local Bus: any
local Stops: any
local Passengers: any
local Run: any

local used: { [Player]: number } = {}

local function lights(): { Light }
	local out: { Light } = {}
	local refs = Bus.refs
	if refs then
		for _, bank in refs.lightBanks do
			for _, light in bank do
				table.insert(out, light)
			end
		end
	end
	local built = Stops and Stops.current
	if built and built.refs and built.refs.model.Parent then
		for _, d in built.refs.model:GetDescendants() do
			if d:IsA("Light") and d.Enabled then
				table.insert(out, d)
			end
		end
	end
	return out
end

local function flicker(target: Player): boolean
	local root = PlayerState.rootOf(target)
	if not root then
		return false
	end
	local best: Light? = nil
	local bestDist = 45
	for _, light in lights() do
		local p = light.Parent
		if p and p:IsA("BasePart") then
			local d = (p.Position - root.Position).Magnitude
			if d < bestDist then
				best, bestDist = light, d
			end
		end
	end
	if not best then
		return false
	end
	local light = best
	local was = light.Enabled
	task.spawn(function()
		for i = 1, 6 do
			light.Enabled = i % 2 == 0
			task.wait(0.12 + math.random() * 0.1)
		end
		light.Enabled = was
	end)
	return true
end

local function reveal(): boolean
	if not Passengers then
		return false
	end
	local models: { Model } = {}
	for _, p in Passengers.list() do
		if p.mimic and p.state == "Aboard" and p.model then
			table.insert(models, p.model)
		end
	end
	if #models == 0 then
		return false
	end
	Net.notifyAll("MimicFlash", { models = models, seconds = 1 })
	return true
end

local function onAction(player: Player, kind: any, arg: any)
	if PlayerState.state(player) ~= "Static" or not Run.running then
		return
	end
	if type(kind) ~= "string" then
		Net.drop(player)
		return
	end
	local stop = Run.stopIndex or 0
	if used[player] == stop then
		Net.notify(player, "Toast", { text = "You've already reached through once this stop." })
		return
	end
	local ok = false
	if kind == "flicker" then
		if not Net.isInt(arg, 1, 2 ^ 53) then
			return
		end
		local target = Players:GetPlayerByUserId(arg :: number)
		if target and PlayerState.isActive(target) then
			ok = flicker(target)
		end
		if not ok then
			Net.notify(player, "Toast", { text = "No light close enough to them." })
		end
	elseif kind == "word" then
		if not Net.isInt(arg, 1, #GhostService.Words) then
			Net.drop(player)
			return
		end
		Net.notifyAll("Sound", { key = "RadioStatic" })
		Net.notifyAll("Radio", { text = GhostService.Words[arg :: number], channel = "true" })
		ok = true
	elseif kind == "reveal" then
		ok = reveal()
		if not ok then
			Net.notify(player, "Toast", { text = "Nothing on the bus is pretending." })
		end
	else
		Net.drop(player)
		return
	end
	if ok then
		used[player] = stop
		Log.info("Ghost", player.Name, kind)
	end
end

function GhostService:Init()
	PlayerState = Registry.get("PlayerStateService")
	Bus = Registry.get("BusService")
	Stops = Registry.find("StopService")
	Passengers = Registry.find("PassengerService")
	Run = Registry.get("RunDirector")
end

function GhostService:Start()
	Net.on("GhostAction", onAction)
	Run.RunStarted:Connect(function()
		table.clear(used)
	end)
	Players.PlayerRemoving:Connect(function(player: Player)
		used[player] = nil
	end)
end

return GhostService
