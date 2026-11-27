--!strict
-- Polaroid photos, client side. The server says what's in the shot; this clones it into a
-- ViewportFrame on a small Polaroid card, lets it develop out of white, then puts the
-- caption under it. A blurred mimic's face is smeared in the clone.

local TweenService = game:GetService("TweenService")

local Client = script.Parent.Parent
local Notify = require(Client:WaitForChild("Notify"))
local Gui = require(Client:WaitForChild("Gui"))

local PhotoController = {}

local screen: ScreenGui
local card: Frame
local viewport: ViewportFrame
local milk: Frame
local caption: TextLabel
local detail: TextLabel
local token = 0

local FACE = { EyeL = true, EyeR = true, LidL = true, LidR = true, Mouth = true, Eye = true }

local function smear(clone: Instance)
	for _, d in clone:GetDescendants() do
		if d:IsA("BasePart") then
			if FACE[d.Name] then
				d.Transparency = 1
			elseif d.Name == "Head" then
				d.Color = d.Color:Lerp(Color3.fromRGB(200, 200, 200), 0.5)
				local streak = Instance.new("Part")
				streak.Size = d.Size * Vector3.new(1.6, 0.7, 1.4)
				streak.CFrame = d.CFrame * CFrame.Angles(0, 0, math.rad(12))
				streak.Color = Color3.fromRGB(235, 235, 230)
				streak.Material = Enum.Material.SmoothPlastic
				streak.Transparency = 0.35
				streak.Anchored = true
				streak.Parent = clone
			end
		end
	end
end

local function center(inst: Instance): Vector3?
	if inst:IsA("BasePart") then
		return inst.Position
	elseif inst:IsA("Model") then
		local cf = inst:GetBoundingBox()
		return cf.Position
	end
	local part = inst:FindFirstChildWhichIsA("BasePart", true)
	return if part then part.Position else nil
end

local function show(p: any)
	if type(p) ~= "table" then
		return
	end
	token += 1
	local mine = token
	viewport:ClearAllChildren()
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.Parent = viewport
	viewport.CurrentCamera = cam
	local subject = p.subject
	local eye: Vector3 = if typeof(p.eye) == "Vector3" then p.eye else Vector3.zero
	if typeof(subject) == "Instance" and subject.Parent then
		local ok, clone = pcall(function()
			local was = subject.Archivable
			subject.Archivable = true
			local c = subject:Clone()
			subject.Archivable = was
			return c
		end)
		if ok and clone then
			for _, d in clone:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
				elseif d:IsA("ProximityPrompt") or d:IsA("BillboardGui") or d:IsA("Script") or d:IsA("LocalScript") then
					d:Destroy()
				end
			end
			if p.blurred then
				smear(clone)
			end
			clone.Parent = viewport
			local at = center(clone)
			if at then
				local away = (eye - at)
				local dist = math.clamp(away.Magnitude, 6, 18)
				local from = at + (if away.Magnitude > 0.1 then away.Unit else Vector3.new(0, 0, 1)) * dist
				cam.CFrame = CFrame.lookAt(from, at)
			end
		end
	end
	caption.Text = ""
	detail.Text = ""
	card.Visible = true
	card.Position = UDim2.new(1, -24, 0.5, 0)
	milk.BackgroundTransparency = 0
	local develop = if type(p.develop) == "number" then p.develop else 3
	local fade = TweenService:Create(milk, TweenInfo.new(math.max(develop, 0.05)), { BackgroundTransparency = 1 })
	fade:Play()
	task.delay(develop, function()
		if token ~= mine then
			return
		end
		caption.Text = if type(p.caption) == "string" then p.caption else ""
		local lines = {}
		if type(p.report) == "string" then
			table.insert(lines, p.report)
		end
		if type(p.paid) == "number" then
			table.insert(lines, `+{p.paid} transfers`)
		end
		detail.Text = table.concat(lines, "  ")
	end)
	task.delay(develop + 7, function()
		if token ~= mine then
			return
		end
		card.Visible = false
	end)
end

function PhotoController:Init()
	screen = Gui.screen("Photo", 30)
	card = Gui.frame(screen, {
		Name = "Polaroid",
		AnchorPoint = Vector2.new(1, 0.5),
		Size = UDim2.fromOffset(220, 262),
		BackgroundColor3 = Color3.fromRGB(240, 238, 228),
		BackgroundTransparency = 0,
		Rotation = 3,
		Visible = false,
	})
	Gui.corner(card, 4)
	viewport = Instance.new("ViewportFrame")
	viewport.Name = "Shot"
	viewport.Position = UDim2.fromOffset(12, 12)
	viewport.Size = UDim2.new(1, -24, 0, 196)
	viewport.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
	viewport.BorderSizePixel = 0
	viewport.Ambient = Color3.fromRGB(150, 150, 140)
	viewport.LightColor = Color3.fromRGB(255, 250, 235)
	viewport.LightDirection = Vector3.new(-0.3, -1, -0.5)
	viewport.Parent = card
	milk = Gui.frame(viewport, {
		Name = "Developing",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(235, 235, 228),
		BackgroundTransparency = 0,
		ZIndex = 5,
	})
	caption = Gui.label(card, "", {
		Position = UDim2.fromOffset(12, 212),
		Size = UDim2.new(1, -24, 0, 22),
		TextColor3 = Color3.fromRGB(30, 30, 34),
		Font = Gui.FontBold,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	detail = Gui.label(card, "", {
		Position = UDim2.fromOffset(12, 234),
		Size = UDim2.new(1, -24, 0, 22),
		TextColor3 = Color3.fromRGB(80, 80, 86),
		TextSize = 11,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

function PhotoController:Start()
	Notify.on("Photo", show)
end

return PhotoController
