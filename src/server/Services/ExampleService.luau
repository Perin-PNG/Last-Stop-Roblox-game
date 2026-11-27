--!strict
-- Example service. Copy this file to make a new one.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Log = require(Shared:WaitForChild("Log"))

local ExampleService = {}

function ExampleService:Init()
	-- Set up state. Don't yield here.
end

function ExampleService:Start()
	Players.PlayerAdded:Connect(function(player)
		Log.info("ExampleService", player.Name, "joined")
	end)

	Net.event("Example").OnServerEvent:Connect(function(player, message: unknown)
		-- Validate everything a client sends.
		if typeof(message) ~= "string" or #message > 200 then
			return
		end
		Log.info("ExampleService", player.Name, "says", message)
	end)
end

return ExampleService
