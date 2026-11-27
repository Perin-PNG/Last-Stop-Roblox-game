--!strict
-- Client side of the bus: screen fades (Stationary mode moves), the "bus pulling away"
-- view for anyone left outside, and a fallback stand-up from seats.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Client = script.Parent.Parent
local Notify = require(Client:WaitForChild("Notify"))
local Gui = require(Client:WaitForChild("Gui"))
local State = require(Client:WaitForChild("State"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local BusController = {}

local fade: Frame

function BusController.fade(seconds: number, hold: number?)
	fade.Visible = true
	fade.BackgroundTransparency = 1
	TweenService:Create(fade, TweenInfo.new(seconds * 0.5), { BackgroundTransparency = 0 }):Play()
	task.delay(seconds * 0.5 + (hold or 0.3), function()
		TweenService:Create(fade, TweenInfo.new(seconds), { BackgroundTransparency = 1 }):Play()
		task.delay(seconds, function()
			if fade.BackgroundTransparency >= 0.99 then
				fade.Visible = false
			end
		end)
	end)
end

-- Clone the bus locally and drive the clone away down the road (Stationary mode).
local function pullAway()
	local bus = State.bus()
	if not bus then
		return
	end
	local clone = bus:Clone()
	for _, d in clone:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
		elseif d:IsA("Script") or d:IsA("LocalScript") or d:IsA("Constraint") or d:IsA("JointInstance") then
			d:Destroy()
		end
	end
	clone.Name = "LeavingBus"
	clone.Parent = workspace
	local start = clone:GetPivot()
	local t = 0
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function(dt: number)
		t += dt
		local distance = 0.5 * 9 * t * t
		clone:PivotTo(start * CFrame.new(0, 0, -distance))
		if t > 9 then
			conn:Disconnect()
			clone:Destroy()
		end
	end)
end

-- Keep riders with the bus while they are in the air. On the ground, floor friction carries
-- a player along with the moving bus; in a jump the Humanoid's air control steers toward
-- a world-space speed and bleeds off the bus's speed, so the bus drives on without them.
-- While airborne inside the cabin we move the character with the bus's own motion each
-- frame and keep their physical velocity relative to the bus, then hand the bus's
-- velocity back when they land (or leave the cabin mid-air).
local lastBusCf: CFrame? = nil
local carried = false

local function rideStep()
	local floor = State.busPart("Floor")
	local character = State.character()
	local root = State.root()
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not floor or not root or not humanoid or root.Anchored then
		lastBusCf = nil
		carried = false
		return
	end
	local busCf = floor.CFrame
	local busVel = floor.AssemblyLinearVelocity
	local flat = Vector3.new(busVel.X, 0, busVel.Z)
	local inside = State.insideBus(root.Position)
	local airborne = humanoid.FloorMaterial == Enum.Material.Air
		and not humanoid.Sit
		and humanoid:GetState() ~= Enum.HumanoidStateType.Climbing
	if inside and airborne and lastBusCf then
		if not carried then
			-- Take-off: make the velocity relative to the bus.
			root.AssemblyLinearVelocity -= flat
			carried = true
		end
		-- Move (and turn) the character exactly as the bus moved since last frame.
		local delta = busCf * (lastBusCf :: CFrame):Inverse()
		root.CFrame = delta * root.CFrame
	elseif carried then
		-- Landed, or left the cabin in the air: give the bus's speed back.
		root.AssemblyLinearVelocity += flat
		carried = false
	end
	lastBusCf = busCf
end

function BusController:Init()
	local sg = Gui.screen("Fade", 50, true)
	fade = Gui.frame(sg, {
		Name = "Black",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 1,
		Visible = false,
		ZIndex = 10,
	})
end

function BusController:Start()
	Notify.on("Fade", function(payload: any)
		BusController.fade(if type(payload) == "table" and payload.seconds then payload.seconds else 0.6)
	end)
	Notify.on("BusLeaving", function()
		pullAway()
	end)
	RunService.PreSimulation:Connect(rideStep)
	-- If a seat in the moving bus won't let go, jumping asks the server to stand us up.
	local UserInputService = game:GetService("UserInputService")
	UserInputService.JumpRequest:Connect(function()
		local character = State.character()
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Sit then
			task.delay(0.25, function()
				if humanoid.Sit then
					Net.event("Move"):FireServer("stand")
				end
			end)
		end
	end)
end

return BusController
