--!strict
-- Client-side router for the Notify remote: controllers subscribe to a kind.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local Notify = {}

local listeners: { [string]: { (any) -> () } } = {}
local connected = false

local function connect()
	if connected then
		return
	end
	connected = true
	Net.event("Notify").OnClientEvent:Connect(function(kind: string, payload: any)
		local list = listeners[kind]
		if list then
			for _, fn in list do
				task.spawn(fn, payload)
			end
		end
	end)
end

function Notify.on(kind: string, fn: (payload: any) -> ())
	connect()
	local list = listeners[kind]
	if not list then
		list = {}
		listeners[kind] = list
	end
	table.insert(list, fn)
end

-- Fire a notify locally (for client-only events).
function Notify.emit(kind: string, payload: any?)
	local list = listeners[kind]
	if list then
		for _, fn in list do
			task.spawn(fn, payload)
		end
	end
end

return Notify
