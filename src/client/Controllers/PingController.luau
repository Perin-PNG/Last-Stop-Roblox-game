--!strict
-- The ping wheel. Hold Q, the ping button or d-pad up; point (mouse, right stick, or tap
-- a sector) and let go to ping where you're looking. Every ping shows a marker with its
-- icon, the sender and the distance for 6 seconds, for everyone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Client = script.Parent.Parent
local Gui = require(Client:WaitForChild("Gui"))
local State = require(Client:WaitForChild("State"))
local Notify = require(Client:WaitForChild("Notify"))
local Registry = require(Client:WaitForChild("Registry"))

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))
local Config = require(Shared:WaitForChild("Config"))

local PINGS = Config.Text.Pings
local Tuning = Config.Tuning.Ping

local PingController = {}

local COLORS: { Color3 } = {
	Color3.fromRGB(255, 200, 70), -- Wait
	Color3.fromRGB(255, 110, 60), -- Close the doors
	Color3.fromRGB(240, 70, 70), -- Anomaly
	Color3.fromRGB(190, 110, 255), -- Mimic?
	Color3.fromRGB(110, 210, 255), -- Help
	Color3.fromRGB(120, 230, 120), -- Loot
	Color3.fromRGB(240, 240, 240), -- Follow
	Color3.fromRGB(200, 200, 160), -- Yes / No
}

local wheel: Frame
local sectors: { TextButton } = {}
local modal: TextButton
local hovered: number? = nil
local openSince = 0
local markers: Folder

local function aimPoint(): Vector3
	local camera = workspace.CurrentCamera
	local origin = camera.CFrame.Position
	local dir = camera.CFrame.LookVector
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { markers }
	local character = State.character()
	if character then
		table.insert(ignore, character)
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(origin, dir * Tuning.MaxDistance, params)
	return if hit then hit.Position else origin + dir * 40
end

local function setHover(n: number?)
	hovered = n
	for i, b in sectors do
		b.BackgroundTransparency = if i == n then 0.05 else 0.4
		local stroke = b:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Thickness = if i == n then 3 else 1
		end
	end
end

local function open()
	openSince = os.clock()
	wheel.Visible = true
	modal.Visible = true
	setHover(nil)
end

local function close(send: boolean)
	if not wheel.Visible then
		return
	end
	wheel.Visible = false
	modal.Visible = false
	local id = hovered
	setHover(nil)
	if send and id then
		Net.event("Ping"):FireServer(id, aimPoint())
	end
end

-- Pick a sector from a direction (screen space, y down).
local function pickFrom(v: Vector2)
	if v.Magnitude < 0.35 then
		return
	end
	local angle = math.deg(math.atan2(v.X, -v.Y)) % 360 -- 0 = up, clockwise
	local n = math.floor((angle + 22.5) / 45) % 8 + 1
	setHover(n)
end

local function buildWheel()
	local sg = Gui.screen("PingWheel", 30, true)
	modal = Instance.new("TextButton")
	modal.Name = "Modal"
	modal.Size = UDim2.fromScale(1, 1)
	modal.BackgroundTransparency = 1
	modal.Text = ""
	modal.Modal = true -- frees the mouse in first person while the wheel is open
	modal.Visible = false
	modal.Parent = sg
	wheel = Gui.frame(sg, {
		Name = "Wheel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(320, 320),
		BackgroundTransparency = 1,
		Visible = false,
	})
	local center = Gui.frame(wheel, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(70, 70),
		BackgroundTransparency = 0.3,
	})
	Gui.corner(center, 35)
	Gui.label(center, "PING", { Font = Gui.FontBold, MaxText = 16 })
	for i, ping in PINGS do
		local angle = math.rad((i - 1) * 45)
		local x, y = math.sin(angle) * 118, -math.cos(angle) * 118
		local b = Gui.button(wheel, ping.icon .. "\n" .. ping.text, function()
			setHover(i)
			close(true)
		end, {
			Size = UDim2.fromOffset(92, 64),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, x, 0.5, y),
			BackgroundColor3 = Color3.fromRGB(16, 16, 22),
			BackgroundTransparency = 0.4,
			TextColor3 = COLORS[i],
			MaxText = 15,
		})
		Gui.stroke(b, COLORS[i], 1)
		b.MouseEnter:Connect(function()
			setHover(i)
		end)
		table.insert(sectors, b)
	end
end

-- Markers ----------------------------------------------------------------------------------

local function nameOf(userId: number): string
	local p = Players:GetPlayerByUserId(userId)
	return if p then p.DisplayName else "Someone"
end

local function showMarker(userId: number, id: number, pos: Vector3, ghost: boolean)
	local ping = PINGS[id]
	if not ping then
		return
	end
	local color = if ghost then Color3.fromRGB(170, 190, 210) else COLORS[id]
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(pos + Vector3.new(0, 1.5, 0))
	anchor.Parent = markers
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(120, 74)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 400
	bb.Adornee = anchor
	bb.Parent = anchor
	local icon = Gui.frame(bb, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = color,
		BackgroundTransparency = if ghost then 0.5 else 0.1,
	})
	-- Each ping has its own marker shape as well as its icon, so colour is never the
	-- only difference (plan, accessibility).
	local shape = (ping :: any).shape
	local glyph = Gui.label(icon, ping.icon, { Font = Gui.FontBold, TextColor3 = Color3.new(0, 0, 0), MaxText = 24 })
	if shape == "circle" then
		Gui.corner(icon, 20)
	elseif shape == "diamond" then
		icon.Rotation = 45
		icon.Size = UDim2.fromOffset(34, 34)
		glyph.Rotation = -45
	elseif shape == "hex" or shape == "split" then
		Gui.corner(icon, 10)
	elseif shape == "triangle" or shape == "arrow" then
		Gui.corner(icon, 4)
		local edge = Instance.new("UIStroke")
		edge.Thickness = 3
		edge.Color = Color3.new(0, 0, 0)
		edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		edge.Parent = icon
	elseif shape == "cross" then
		Gui.corner(icon, 2)
		icon.Size = UDim2.fromOffset(40, 28)
	end -- square: no rounding
	local text = Gui.label(bb, ping.text, {
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.fromOffset(0, 42),
		Font = Gui.FontBold,
		TextColor3 = color,
		TextStrokeTransparency = 0.4,
		MaxText = 16,
	})
	local _ = text
	local sub = Gui.label(bb, "", {
		Size = UDim2.new(1, 0, 0, 14),
		Position = UDim2.fromOffset(0, 60),
		TextColor3 = Gui.Colors.Dim,
		TextStrokeTransparency = 0.5,
		MaxText = 12,
	})
	local who = nameOf(userId)
	local born = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local age = os.clock() - born
		if age > Tuning.Lifetime or not anchor.Parent then
			conn:Disconnect()
			anchor:Destroy()
			return
		end
		local root = State.root()
		local d = if root then (root.Position - pos).Magnitude else 0
		sub.Text = string.format("%s  %dm", who, math.floor(d / 3.5))
		-- Fade out over the last second.
		local fade = math.clamp(age - (Tuning.Lifetime - 1), 0, 1)
		icon.BackgroundTransparency = (if ghost then 0.5 else 0.1) + fade * 0.8
	end)
	local audio = Registry.find("AudioController")
	if audio then
		audio.play("PingBlip", nil, pos)
	end
	Notify.emit("PingFeed", { name = who, text = ping.text, color = color, ghost = ghost })
end

function PingController:Init()
	markers = Instance.new("Folder")
	markers.Name = "PingMarkers"
	markers.Parent = workspace
	buildWheel()
end

function PingController:Start()
	local Input = Registry.get("InputController")
	Input.on("Ping", open, function()
		-- On touch the wheel stays open after a short tap so a sector can be tapped.
		if Input.isTouch() and os.clock() - openSince < 0.35 then
			return
		end
		close(true)
	end)
	RunService.RenderStepped:Connect(function()
		if not wheel.Visible then
			return
		end
		local mouse = UserInputService:GetMouseLocation()
		local c = wheel.AbsolutePosition + wheel.AbsoluteSize / 2
		local v = (mouse - c) / 80 -- the wheel's screen ignores the top-bar inset, like the mouse
		if UserInputService.MouseEnabled and v.Magnitude > 0.35 then
			pickFrom(v)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if wheel.Visible and input.KeyCode == Enum.KeyCode.Thumbstick2 then
			pickFrom(Vector2.new(input.Position.X, -input.Position.Y))
		end
	end)
	UserInputService.InputBegan:Connect(function(input)
		if wheel.Visible and input.KeyCode == Enum.KeyCode.ButtonB then
			hovered = nil
			close(false)
		end
	end)
	Net.event("PingShown").OnClientEvent:Connect(function(userId: number, id: number, pos: Vector3, ghost: boolean?)
		showMarker(userId, id, pos, ghost == true)
	end)
end

return PingController
