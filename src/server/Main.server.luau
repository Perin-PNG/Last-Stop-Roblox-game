--!strict
-- Server entry point. Requires every service listed in Registry.Order that exists in
-- Services/, calls Init on all of them in order, then Start on all of them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Log = require(Shared:WaitForChild("Log"))
local Registry = require(script.Parent:WaitForChild("Registry"))

Net.setup()

local folder = script.Parent:WaitForChild("Services")
local loaded: { { name: string, service: any } } = {}

for _, name in Registry.Order do
	local module = folder:FindFirstChild(name)
	if module and module:IsA("ModuleScript") then
		local ok, result = pcall(require, module)
		if ok then
			Registry.add(name, result)
			table.insert(loaded, { name = name, service = result })
		else
			Log.warn("Server", "Failed to load", name, result)
		end
	end
end

-- Any extra module in Services that is not in the list still loads, last.
for _, module in folder:GetChildren() do
	if module:IsA("ModuleScript") and not Registry.find(module.Name) then
		local ok, result = pcall(require, module)
		if ok then
			Registry.add(module.Name, result)
			table.insert(loaded, { name = module.Name, service = result })
		else
			Log.warn("Server", "Failed to load", module.Name, result)
		end
	end
end

for _, entry in loaded do
	local service = entry.service
	if type(service) == "table" and service.Init then
		local ok, err = pcall(service.Init, service)
		if not ok then
			Log.warn("Server", "Init failed", entry.name, err)
		end
	end
end

for _, entry in loaded do
	local service = entry.service
	if type(service) == "table" and service.Start then
		task.spawn(function()
			local ok, err = pcall(service.Start, service)
			if not ok then
				Log.warn("Server", "Start failed", entry.name, err)
			end
		end)
	end
end

Log.info("Server", "Ready", #loaded, "services")
