--!strict
-- Server entry point. Loads every ModuleScript in Services, calls Init on all,
-- then Start on all. Add a new service by adding a file to Services/.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Log = require(Shared:WaitForChild("Log"))

Net.setup()

type Service = {
	Init: ((self: any) -> ())?,
	Start: ((self: any) -> ())?,
}

local services: { [string]: Service } = {}
for _, module in script.Parent:WaitForChild("Services"):GetChildren() do
	if module:IsA("ModuleScript") then
		services[module.Name] = require(module) :: any
	end
end

for name, service in services do
	if service.Init then
		service:Init()
		Log.info("Server", "Init", name)
	end
end

for name, service in services do
	if service.Start then
		task.spawn(function()
			service:Start()
		end)
		Log.info("Server", "Start", name)
	end
end

Log.info("Server", "Ready")
