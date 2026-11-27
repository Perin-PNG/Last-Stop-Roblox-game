--!strict
-- Trove: collects things that need cleaning up (connections, instances, threads,
-- functions) and cleans them all at once.

export type Trove = {
	Add: <T>(self: Trove, item: T) -> T,
	Connect: (self: Trove, signal: RBXScriptSignal, fn: (...any) -> ()) -> RBXScriptConnection,
	Extend: (self: Trove) -> Trove,
	Clean: (self: Trove) -> (),
	Destroy: (self: Trove) -> (),
}

local Trove = {}
Trove.__index = Trove

function Trove.new(): Trove
	return (setmetatable({ _items = {} :: { any } }, Trove) :: any) :: Trove
end

local function cleanItem(item: any)
	local kind = typeof(item)
	if kind == "RBXScriptConnection" then
		item:Disconnect()
	elseif kind == "Instance" then
		item:Destroy()
	elseif kind == "function" then
		item()
	elseif kind == "thread" then
		if coroutine.status(item) ~= "dead" then
			pcall(task.cancel, item)
		end
	elseif kind == "table" then
		if type(item.Destroy) == "function" then
			item:Destroy()
		elseif type(item.Disconnect) == "function" then
			item:Disconnect()
		elseif type(item.Clean) == "function" then
			item:Clean()
		end
	end
end

function Trove.Add(self: any, item: any): any
	table.insert(self._items, item)
	return item
end

function Trove.Connect(self: any, signal: RBXScriptSignal, fn: (...any) -> ()): RBXScriptConnection
	local connection = signal:Connect(fn)
	table.insert(self._items, connection)
	return connection
end

function Trove.Extend(self: any): Trove
	local child = Trove.new()
	table.insert(self._items, child)
	return child
end

function Trove.Clean(self: any)
	local items = self._items
	self._items = {}
	for i = #items, 1, -1 do
		local ok, err = pcall(cleanItem :: any, items[i])
		if not ok then
			warn("[Trove] cleanup error:", err)
		end
	end
end

function Trove.Destroy(self: any)
	self:Clean()
end

return Trove
