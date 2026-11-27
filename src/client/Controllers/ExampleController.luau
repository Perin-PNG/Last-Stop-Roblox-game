--!strict
-- Example controller. Copy this file to make a new one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local ExampleController = {}

function ExampleController:Init() end

function ExampleController:Start()
	Net.event("Example"):FireServer("hello from the client")
end

return ExampleController
