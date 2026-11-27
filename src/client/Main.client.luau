--!strict
-- Client entry point. Same Init/Start pattern as the server, for Controllers/.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Log = require(Shared:WaitForChild("Log"))
local Registry = require(script.Parent:WaitForChild("Registry"))

local folder = script.Parent:WaitForChild("Controllers")
local loaded: { { name: string, controller: any } } = {}

local function load(module: Instance)
	if module:IsA("ModuleScript") and not Registry.find(module.Name) then
		local ok, result = pcall(require, module)
		if ok then
			Registry.add(module.Name, result)
			table.insert(loaded, { name = module.Name, controller = result })
		else
			Log.warn("Client", "Failed to load", module.Name, result)
		end
	end
end

for _, name in Registry.Order do
	local module = folder:FindFirstChild(name)
	if module then
		load(module)
	end
end
for _, module in folder:GetChildren() do
	load(module)
end

for _, entry in loaded do
	local controller = entry.controller
	if type(controller) == "table" and controller.Init then
		local ok, err = pcall(controller.Init, controller)
		if not ok then
			Log.warn("Client", "Init failed", entry.name, err)
		end
	end
end

for _, entry in loaded do
	local controller = entry.controller
	if type(controller) == "table" and controller.Start then
		task.spawn(function()
			local ok, err = pcall(controller.Start, controller)
			if not ok then
				Log.warn("Client", "Start failed", entry.name, err)
			end
		end)
	end
end

Log.info("Client", "Ready", #loaded, "controllers")
