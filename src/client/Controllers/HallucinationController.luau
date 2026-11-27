--!strict
-- Hallucinations: what high Dread shows only you. The server says what and where (the
-- Hallucinate remote); everything here is local, can't be touched and can't hurt anyone.
-- A figure or a pair of eyes vanishes once you look straight at it; footsteps and whispers
-- just play; a passenger only you can see sits in an empty bus seat.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Client = script.Parent.Parent
local Registry = require(Client:WaitForChild("Registry"))
local State = require(Client:WaitForChild("State"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local HallucinationController = {}

local folder: Folder
local player = Players.LocalPlayer

local function ground(at: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { folder }
	if player.Character then
		table.insert(exclude, player.Character)
	end
	params.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(at + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0), params)
	return if hit then hit.Position else at
end

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = folder
	return p
end

-- A dark, faceless standing figure at a floor point, facing the player.
local function figure(at: Vector3, facing: Vector3, scale: number?): Model
	local s = scale or 1
	local m = Instance.new("Model")
	m.Name = "Figure"
	m.Parent = folder
	local base = CFrame.lookAt(at, Vector3.new(facing.X, at.Y, facing.Z))
	local dark = Color3.fromRGB(14, 14, 16)
	local function add(name: string, size: Vector3, offset: Vector3)
		local p = part(name, size * s, base * CFrame.new(offset * s), dark, Enum.Material.Fabric)
		p.Parent = m
	end
	add("Legs", Vector3.new(1.6, 3, 0.8), Vector3.new(0, 1.5, 0))
	add("Torso", Vector3.new(2, 2.8, 1), Vector3.new(0, 4.4, 0))
	add("Head", Vector3.new(1.2, 1.4, 1.2), Vector3.new(0, 6.5, 0))
	for _, side in { -1, 1 } do
		add("Arm", Vector3.new(0.6, 3.2, 0.6), Vector3.new(side * 1.35, 4.1, 0))
	end
	return m
end

local function eyes(at: Vector3, facing: Vector3): Model
	local m = Instance.new("Model")
	m.Name = "Eyes"
	m.Parent = folder
	local base = CFrame.lookAt(at + Vector3.new(0, 6, 0), facing)
	for _, side in { -0.35, 0.35 } do
		local p = part(
			"Eye",
			Vector3.new(0.18, 0.12, 0.05),
			base * CFrame.new(side, 0, 0),
			Color3.fromRGB(255, 240, 200),
			Enum.Material.Neon
		)
		p.Parent = m
	end
	return m
end

-- Is the camera pointed at this point (within a narrow cone)?
local function lookedAt(pos: Vector3, cone: number): boolean
	local cam = workspace.CurrentCamera
	if not cam then
		return false
	end
	local to = pos - cam.CFrame.Position
	if to.Magnitude < 0.1 then
		return true
	end
	return cam.CFrame.LookVector:Dot(to.Unit) >= math.cos(math.rad(cone))
end

-- Keep `m` until the player looks straight at it, or `life` seconds pass.
local function vanishWhenSeen(m: Model, life: number)
	local born = os.clock()
	local seenFor = 0
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function(dt: number)
		local pivot = m:GetPivot().Position
		if lookedAt(pivot, 9) then
			seenFor += dt
		end
		if seenFor > 0.15 or os.clock() - born > life or not m.Parent then
			if conn then
				conn:Disconnect()
			end
			m:Destroy()
		end
	end)
end

local function myRoot(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function emptySeat(): Seat?
	local bus = State.bus()
	if not bus then
		return nil
	end
	local free: { Seat } = {}
	for _, d in bus:GetDescendants() do
		if d:IsA("Seat") and d.Occupant == nil then
			table.insert(free, d)
		end
	end
	if #free == 0 then
		return nil
	end
	return free[math.random(1, #free)]
end

local function show(kind: string, at: Vector3)
	local audio = Registry.find("AudioController")
	local root = myRoot()
	if not root then
		return
	end
	if kind == "footsteps" then
		if audio then
			audio.play("Footsteps", nil, at)
		end
	elseif kind == "whisper" then
		if audio then
			audio.play("Whisper", nil, root.Position + (at - root.Position).Unit * 4)
		end
	elseif kind == "figure" then
		local m = figure(ground(at), root.Position)
		vanishWhenSeen(m, 7)
	elseif kind == "anomaly" then
		local m = eyes(ground(at), root.Position)
		vanishWhenSeen(m, 9)
	elseif kind == "passenger" then
		local seat = if State.mine("State") == "Aboard" then emptySeat() else nil
		if seat then
			-- A passenger sits where nobody is. Look away and back and it's gone.
			local m = figure((seat.CFrame * CFrame.new(0, -seat.Size.Y / 2 - 1.2, 0)).Position, root.Position, 0.9)
			vanishWhenSeen(m, 10)
		else
			local m = figure(ground(at), root.Position)
			vanishWhenSeen(m, 7)
		end
	end
end

function HallucinationController:Init()
	folder = Instance.new("Folder")
	folder.Name = "Hallucinations"
	folder.Parent = workspace
end

function HallucinationController:Start()
	Net.event("Hallucinate").OnClientEvent:Connect(function(payload: any)
		if type(payload) ~= "table" or type(payload.kind) ~= "string" or typeof(payload.at) ~= "Vector3" then
			return
		end
		show(payload.kind, payload.at)
	end)
	State.watchMine("State", function(state: any)
		if state == "Lobby" or state == "Lost" or state == "Static" then
			folder:ClearAllChildren()
		end
	end)
end

return HallucinationController
