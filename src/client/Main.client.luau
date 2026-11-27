--!strict
-- Client entry point. Same Init/Start pattern as the server, for Controllers/.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared:WaitForChild("Log"))

type Controller = {
	Init: ((self: any) -> ())?,
	Start: ((self: any) -> ())?,
}

local controllers: { [string]: Controller } = {}
for _, module in script.Parent:WaitForChild("Controllers"):GetChildren() do
	if module:IsA("ModuleScript") then
		controllers[module.Name] = require(module) :: any
	end
end

for _, controller in controllers do
	if controller.Init then
		controller:Init()
	end
end

for _, controller in controllers do
	if controller.Start then
		task.spawn(function()
			controller:Start()
		end)
	end
end

Log.info("Client", "Ready")
