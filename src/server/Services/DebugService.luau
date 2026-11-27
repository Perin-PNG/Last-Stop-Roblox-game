--!strict
-- Studio-only debug commands: skip the stop, set the seed, force an anomaly, spawn an
-- entity, god mode, fill fuel and fragments. The server checks RunService:IsStudio() for
-- every call; outside Studio every Debug call is dropped.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Log = require(Shared.Log)

local Registry = require(script.Parent.Parent:WaitForChild("Registry"))

local DebugService = {}

-- Handlers registered by other services: action -> fn(player, arg)
local handlers: { [string]: (Player, any) -> () } = {}

function DebugService.register(action: string, fn: (Player, any) -> ())
	handlers[action] = fn
end

function DebugService:Init()
	DebugService.register("god", function(player: Player)
		local on = not player:GetAttribute("God")
		player:SetAttribute("God", on)
		Net.notify(player, "Toast", { text = if on then "God mode on" else "God mode off" })
	end)
	DebugService.register("skip", function()
		local director = Registry.find("RunDirector")
		if director and director.requestSkip then
			director.requestSkip()
		end
	end)
	DebugService.register("seed", function(_player: Player, arg: any)
		local seed = tonumber(arg)
		local director = Registry.find("RunDirector")
		if seed and director and director.restartWithSeed then
			director.restartWithSeed(math.floor(seed))
		end
	end)
	DebugService.register("tokens", function(player: Player)
		local data = Registry.find("DataService")
		if data then
			data.addTokens(player, 500, "debug")
		end
	end)
	DebugService.register("firstride", function(player: Player)
		local data = Registry.find("DataService")
		if not data then
			return
		end
		data.update(player, function(d: any)
			d.tutorialDone = false
			d.hints = {}
		end)
		Net.notify(player, "HintsSeen", { ids = {} })
		Net.notify(player, "OfferFirstRide", {})
	end)
	DebugService.register("tobus", function(player: Player)
		local director = Registry.find("RunDirector")
		if director and player.Character then
			director.placeInBus(player.Character)
		end
	end)
end

function DebugService:Start()
	if not RunService:IsStudio() then
		return
	end
	ReplicatedStorage:SetAttribute("DebugEnabled", true)
	Net.on("Debug", function(player: Player, action: any, arg: any)
		if not RunService:IsStudio() or type(action) ~= "string" then
			return
		end
		local fn = handlers[action]
		if fn then
			Log.info("Debug", player.Name, action, arg)
			fn(player, arg)
		end
	end)
	local _ = Players
end

return DebugService
