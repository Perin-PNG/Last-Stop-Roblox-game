--!strict
-- A tiny signal. Connect returns a connection with Disconnect().

export type Connection = {
	Connected: boolean,
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
	Wait: (self: Signal<T...>) -> T...,
	DisconnectAll: (self: Signal<T...>) -> (),
}

local Signal = {}
Signal.__index = Signal

function Signal.new<T...>(): Signal<T...>
	local self = setmetatable({ _handlers = {} :: { any } }, Signal)
	return (self :: any) :: Signal<T...>
end

function Signal.Connect(self: any, fn: (...any) -> ()): Connection
	local handlers = self._handlers
	local connection
	connection = {
		Connected = true,
		Disconnect = function(c: any)
			if not c.Connected then
				return
			end
			c.Connected = false
			local index = table.find(handlers, connection)
			if index then
				table.remove(handlers, index)
			end
		end,
		_fn = fn,
	}
	table.insert(handlers, connection)
	return connection :: any
end

function Signal.Once(self: any, fn: (...any) -> ()): Connection
	local connection: any
	connection = self:Connect(function(...)
		connection:Disconnect()
		fn(...)
	end)
	return connection
end

function Signal.Fire(self: any, ...: any)
	-- Copy so handlers can disconnect while we iterate.
	for _, connection: any in table.clone(self._handlers) :: { any } do
		if connection.Connected then
			task.spawn(connection._fn, ...)
		end
	end
end

function Signal.Wait(self: any): ...any
	local thread = coroutine.running()
	self:Once(function(...)
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

function Signal.DisconnectAll(self: any)
	for _, connection: any in table.clone(self._handlers) :: { any } do
		connection.Connected = false
	end
	table.clear(self._handlers)
end

return Signal
