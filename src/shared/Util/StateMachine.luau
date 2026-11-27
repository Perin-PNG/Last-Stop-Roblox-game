--!strict
-- A small finite state machine. Each state may define enter, update and exit.
-- Entities and the run director are built on it.

export type State<C> = {
	enter: ((ctx: C, from: string?) -> ())?,
	update: ((ctx: C, dt: number) -> string?)?, -- return a state name to switch
	exit: ((ctx: C, to: string) -> ())?,
}

export type Machine<C> = {
	ctx: C,
	current: string,
	elapsed: number, -- seconds in the current state
	states: { [string]: State<C> },
	set: (self: Machine<C>, name: string) -> (),
	step: (self: Machine<C>, dt: number) -> (),
	is: (self: Machine<C>, name: string) -> boolean,
	onChanged: ((from: string, to: string) -> ())?,
}

local StateMachine = {}
StateMachine.__index = StateMachine

function StateMachine.new<C>(ctx: C, states: { [string]: State<C> }, initial: string): Machine<C>
	local self = setmetatable({
		ctx = ctx,
		states = states,
		current = initial,
		elapsed = 0,
	}, StateMachine)
	local first = states[initial]
	if first and first.enter then
		first.enter(ctx, nil)
	end
	return (self :: any) :: Machine<C>
end

function StateMachine.set(self: any, name: string)
	if name == self.current then
		return
	end
	local nextState = self.states[name]
	if not nextState then
		warn("[StateMachine] unknown state", name)
		return
	end
	local from = self.current
	local old = self.states[from]
	if old and old.exit then
		old.exit(self.ctx, name)
	end
	self.current = name
	self.elapsed = 0
	if nextState.enter then
		nextState.enter(self.ctx, from)
	end
	if self.onChanged then
		self.onChanged(from, name)
	end
end

function StateMachine.step(self: any, dt: number)
	self.elapsed += dt
	local state = self.states[self.current]
	if state and state.update then
		local nextName = state.update(self.ctx, dt)
		if nextName and nextName ~= self.current then
			self:set(nextName)
		end
	end
end

function StateMachine.is(self: any, name: string): boolean
	return self.current == name
end

return StateMachine
