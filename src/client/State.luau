--!strict
-- Client helpers for replicated state: RunState attributes and the local player's
-- attributes, with change listeners.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local State = {}

State.player = Players.LocalPlayer

local runState: Instance? = nil

function State.runState(): Instance
	if not runState then
		runState = ReplicatedStorage:WaitForChild("RunState")
	end
	return runState :: Instance
end

function State.get(name: string): any
	return State.runState():GetAttribute(name)
end

function State.on(name: string, fn: (value: any) -> ()): RBXScriptConnection
	local rs = State.runState()
	return rs:GetAttributeChangedSignal(name):Connect(function()
		fn(rs:GetAttribute(name))
	end)
end

-- Calls fn now and on every change.
function State.watch(name: string, fn: (value: any) -> ()): RBXScriptConnection
	task.spawn(fn, State.get(name))
	return State.on(name, fn)
end

function State.mine(name: string): any
	return State.player:GetAttribute(name)
end

function State.watchMine(name: string, fn: (value: any) -> ()): RBXScriptConnection
	task.spawn(fn, State.player:GetAttribute(name))
	return State.player:GetAttributeChangedSignal(name):Connect(function()
		fn(State.player:GetAttribute(name))
	end)
end

function State.now(): number
	return workspace:GetServerTimeNow()
end

-- The current bus model (or nil between runs).
function State.bus(): Model?
	local folder = workspace:FindFirstChild("Bus")
	local bus = folder and folder:FindFirstChild("Bus")
	if bus and bus:IsA("Model") then
		return bus
	end
	return nil
end

function State.busPart(name: string): BasePart?
	local bus = State.bus()
	local part = bus and bus:FindFirstChild(name, true)
	if part and part:IsA("BasePart") then
		return part
	end
	return nil
end

function State.character(): Model?
	return State.player.Character
end

function State.root(): BasePart?
	local character = State.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

-- Is a world position inside the bus cabin (client copy of the server check)?
function State.insideBus(pos: Vector3): boolean
	local interior = State.busPart("Interior")
	if not interior then
		return false
	end
	local rel = interior.CFrame:PointToObjectSpace(pos)
	local size = interior.Size
	return math.abs(rel.X) <= size.X / 2 + 0.3
		and rel.Y >= -size.Y / 2 - 1.5
		and rel.Y <= size.Y / 2 + 1
		and math.abs(rel.Z) <= size.Z / 2 + 0.3
end

function State.aboard(): boolean
	local root = State.root()
	return root ~= nil and State.insideBus(root.Position)
end

return State
